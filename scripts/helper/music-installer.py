import os
import sys
import csv
import re
import datetime
import subprocess
import logging
import shutil
from io import StringIO
from collections import defaultdict
from mutagen import File
from mutagen.easyid3 import EasyID3
from mutagen.mp4 import MP4
from mutagen.flac import FLAC
from tqdm import tqdm

MUSIC_DIR = "media/music"
SQL_PATH = "scripts/tmp/music_dump.sql"
MUSIC_DATA_TXT = "scripts/tmp/music_data.txt"
MUSIC_FAV_TXT = "scripts/tmp/music_fav.txt"
MUSIC_METADATA_TXT = "scripts/tmp/music_metadata.txt"
CONVERTED_DIR = "scripts/storage/__linux.8/MusicCh/contents"
SUPPORTED_EXTENSIONS = ('.mp3', '.m4a', '.flac', '.ogg')
OUTPUT_PATH = "scripts/tmp/music_reconstructed.sql"
BITRATE_FILE = "scripts/assets/music/bitrate"
LOG_PATH = "logs/media.log"

if len(sys.argv) > 1:
    MUSIC_DIR = sys.argv[1]

# SQL headers and footer
header_music = """BEGIN TRANSACTION;
CREATE TABLE SCEI_Jukebox (    version         INT2 DEFAULT 1,     url             VARCHAR,     trackno         INTEGER,     discid          CHAR(8),     language        INT2 DEFAULT 0,     albumname       VARCHAR DEFAULT 'Unknown title',     albumname2      VARCHAR DEFAULT 'Unknown title',     songname        VARCHAR DEFAULT 'Unknown title',     songname2       VARCHAR DEFAULT 'Unknown title',     artistname      VARCHAR DEFAULT 'Unknown Artist',     artistname2     VARCHAR DEFAULT 'Unknown Artist',     length          TIME,     datasize        INTEGER,     playtimes       INTEGER DEFAULT 0,     checkouttimes   INTEGER DEFAULT 0,     importdate      TIMESTAMP,     lastplaydate    TIMESTAMP,     genre           VARCHAR,     format          INT2,     usagerule       VARCHAR,     album_no        INTEGER   );
"""

header_fav = """CREATE TABLE SCEI_Jukebox_pd (    version         INT2 DEFAULT 1,    pdtype          INT2,     contenturi      VARCHAR,     usageruleuri    VARCHAR,     mgid            CHAR(32),     fileno          INTEGER,     hashid          CHAR(16),     contentid       CHAR(40)   );
CREATE TABLE SCEI_Jukebox_favorite_color ( 	  version         INT2 DEFAULT 1, 	  url             VARCHAR, 	  favorite        INT2, 	  entrydate       TIMESTAMP 	  );
"""

footer = """COMMIT;
"""

logging.basicConfig(
    filename=LOG_PATH,
    level=logging.INFO,
    format='[%(levelname)s] %(message)s'
)

# Extract data from original SQL file and convert to plain text:
def extract_music_data():
    insert_pattern = re.compile(r"INSERT INTO (\w+) VALUES\s*\((.+)\);", re.IGNORECASE | re.DOTALL)

    first_jukebox_written_to_fav = False
    jukebox_rows = []
    favorite_rows = []

    with open(SQL_PATH, "rb") as f:
        for line in f:
            decoded_line = line.decode("utf-8", errors="replace")
            match = insert_pattern.search(decoded_line.strip())
            if match:
                table = match.group(1)
                values_str = match.group(2)
                try:
                    reader = csv.reader(StringIO(values_str), delimiter=",", quotechar="'", escapechar="\\")
                    values = next(reader)
                    clean_values = []
                    for v in values:
                        if v.upper() == "NULL":
                            clean_values.append("NULL")
                        elif "�" in v:
                            clean_values.append("")  # Clear unreadable fields
                        else:
                            clean_values.append(v.replace("''", "'"))

                    if table == "SCEI_Jukebox":
                        if not first_jukebox_written_to_fav:
                            favorite_rows.append(clean_values)
                            first_jukebox_written_to_fav = True
                        else:
                            url = clean_values[1]
                            if not url.endswith(".pcm"):
                                continue  # Skip album summary rows after the first
                            jukebox_rows.append(clean_values)

                    elif table == "SCEI_Jukebox_favorite_color":
                        favorite_rows.append(clean_values)

                except Exception as e:
                    error_message = f"Error: Skipping problematic row: {values_str}\nReason: {e}\n"
                    with open(LOG_PATH, "a", encoding="utf-8") as log_file:
                        log_file.write(error_message)
                        print(error_message, file=sys.stderr)
                    sys.exit(1)

    # Write main music data
    with open(MUSIC_DATA_TXT, "w", encoding="utf-8") as out:
        for row in jukebox_rows:
            out.write("|".join(row) + "\n")

    # Write favorite data
    with open(MUSIC_FAV_TXT, "w", encoding="utf-8") as fav_out:
        for row in favorite_rows:
            fav_out.write("|".join(row) + "\n")


# Convert music files and extract meta data:
def sanitize_folder_name(name):
    name = name.lower().replace(' ', '')
    sanitized = re.sub(r'[^a-z0-9]', '', name)
    return sanitized[:8]

def clean_track_number(raw):
    return raw.split('/')[0].strip() if raw else ''

def format_seconds(seconds):
    try:
        seconds = int(round(seconds))
        return f"{seconds // 3600:02}:{(seconds % 3600) // 60:02}:{seconds % 60:02}"
    except Exception:
        return "00:00:00"

def extract_metadata(filepath):
    ext = os.path.splitext(filepath)[1].lower()
    audio = File(filepath)
    if not audio:
        return None

    metadata = {
        'path': os.path.abspath(filepath),
        'album': '',
        'tracknumber': '',
        'title': '',
        'artist': '',
        'length': round(audio.info.length, 2) if audio.info else 0
    }

    try:
        if ext == '.mp3':
            try:
                audio = EasyID3(filepath)
                metadata['album'] = audio.get('album', [''])[0]
                metadata['tracknumber'] = audio.get('tracknumber', [''])[0]
                metadata['title'] = audio.get('title', [''])[0]
                metadata['artist'] = audio.get('artist', [''])[0]
            except:
                id3 = audio.tags
                if id3:
                    metadata['album'] = str(id3.get('TALB', ''))
                    metadata['tracknumber'] = str(id3.get('TRCK', ''))
                    metadata['title'] = str(id3.get('TIT2', ''))
                    metadata['artist'] = str(id3.get('TPE1', ''))
        elif ext == '.m4a' and isinstance(audio, MP4):
            metadata['album'] = audio.tags.get('\xa9alb', [''])[0]
            metadata['tracknumber'] = str(audio.tags.get('trkn', [(0,)])[0][0])
            metadata['title'] = audio.tags.get('\xa9nam', [''])[0]
            metadata['artist'] = audio.tags.get('\xa9ART', [''])[0]
        elif ext == '.flac' and isinstance(audio, FLAC):
            metadata['album'] = audio.get('album', [''])[0]
            metadata['tracknumber'] = audio.get('tracknumber', [''])[0]
            metadata['title'] = audio.get('title', [''])[0]
            metadata['artist'] = audio.get('artist', [''])[0]
        elif ext == '.ogg':
            metadata['album'] = audio.get('album', [''])[0]
            metadata['tracknumber'] = audio.get('tracknumber', [''])[0]
            metadata['title'] = audio.get('title', [''])[0]
            metadata['artist'] = audio.get('artist', [''])[0]
    except:
        return None

    return metadata if metadata['album'] else None

def convert_to_pcm(input_path, OUTPUT_PATH):
    if os.path.exists(OUTPUT_PATH):
        return  # Skip if already converted

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    try:
        subprocess.run([
            'ffmpeg', '-y', '-i', input_path,
            '-af', 'dynaudnorm',
            '-f', 's16le', '-acodec', 'pcm_s16le',
            '-ar', '44100', '-ac', '2', OUTPUT_PATH
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    except subprocess.CalledProcessError as e:
        err_output = e.stderr.decode(errors='ignore') if e.stderr else "No stderr captured"
        logging.error(f"ffmpeg failed on {input_path}: {err_output}")
        return False
    return True

def load_music_data_txt():
    entries = []
    if os.path.isfile(MUSIC_DATA_TXT):
        with open(MUSIC_DATA_TXT, 'r', encoding='utf-8') as f:
            for line in f:
                if line.startswith('1|/opt2/MusicCh/contents/'):
                    parts = line.strip().split('|')
                    album = parts[5]
                    tracknumber = parts[2]
                    title = parts[7]
                    artist = parts[10]
                    folder = os.path.basename(os.path.dirname(parts[1]))
                    sort_key = re.sub(r'^the\s+', '', album, flags=re.IGNORECASE).lower()
                    try:
                        track_num_int = int(tracknumber)
                    except:
                        track_num_int = 0
                    entries.append({
                        'album_sort_key': sort_key,
                        'album': album,
                        'artist': artist,
                        'track_num': track_num_int,
                        'line': line.strip(),
                        'length': 0,
                        'size': 0,
                        'folder': folder,
                        'out_folder': os.path.join(CONVERTED_DIR, folder)
                    })
    return entries

def music_installer():
    metadata_entries = load_music_data_txt()

    all_files = [
        os.path.join(root, file)
        for root, _, files in os.walk(MUSIC_DIR)
        for file in files
        if file.lower().endswith(SUPPORTED_EXTENSIONS) and not file.startswith('.')
    ]

    skipped_files = []  # <--- keep track of skipped files

    for filepath in tqdm(all_files, desc="Converting files", unit="file"):
        meta = extract_metadata(filepath)
        if not meta or not meta['album']:
            reason = "failed to extract metadata or album missing"
            logging.info(f"Skipped: {filepath} ({reason})")
            skipped_files.append((filepath, reason))
            continue

        album_folder = sanitize_folder_name(meta['album'])
        track_num = clean_track_number(meta['tracknumber'])
        if not track_num.isdigit():
            reason = f"missing or invalid track number: '{meta['tracknumber']}'"
            logging.info(f"Skipped: {filepath} ({reason})")
            skipped_files.append((filepath, reason))
            continue

        # Fallbacks
        if not meta['artist']:
            meta['artist'] = "Unknown Artist"
        if not meta['title']:
            meta['title'] = f"Track {int(track_num)}"

        padded = f"{int(track_num):02}"
        unpadded = str(int(track_num))
        out_folder = os.path.join(CONVERTED_DIR, album_folder)
        out_file = f"track{padded}.pcm"
        out_path = os.path.join(out_folder, out_file)
        success = convert_to_pcm(filepath, out_path)
        if not success:
            reason = "ffmpeg conversion failed"
            logging.info(f"Skipped: {filepath} ({reason})")
            skipped_files.append((filepath, reason))   # <--- just this new line
            continue

        bitrate_dest = os.path.join(out_folder, 'bitrate')
        if os.path.isfile(BITRATE_FILE) and not os.path.isfile(bitrate_dest):
            shutil.copy(BITRATE_FILE, bitrate_dest)

        pcm_size = os.path.getsize(out_path)
        ctime = os.path.getctime(out_path)
        creation_time = datetime.datetime.fromtimestamp(ctime).strftime("%Y-%m-%d %H:%M:%S")
        rel_path = os.path.join(album_folder, out_file)

        # Remove any existing entry with the same rel_path
        metadata_entries = [
            e for e in metadata_entries
            if not e['line'].startswith(f"1|/opt2/MusicCh/contents/{rel_path}|")
        ]

        line = (
            f"1|/opt2/MusicCh/contents/{rel_path}|{unpadded}|NULL|0|"
            f"{meta['album']}||{meta['title']}||{meta['artist']}||"
            f"{format_seconds(meta['length'])}|{pcm_size}|0|0|{creation_time}|"
            "NULL|NULL|0|/opt0/bn/openmg/ripping.tur|NULL"
        )

        metadata_entries.append({
            'album_sort_key': re.sub(r'^the\s+', '', meta['album'], flags=re.IGNORECASE).lower(),
            'album': meta['album'],
            'artist': meta['artist'],
            'track_num': int(track_num),
            'line': line,
            'length': meta['length'],
            'size': pcm_size,
            'folder': album_folder,
            'out_folder': out_folder
        })

    grouped = defaultdict(list)
    for entry in metadata_entries:
        grouped[entry['album_sort_key']].append(entry)

    sorted_albums = sorted(grouped.items(), key=lambda x: x[0], reverse=True)
    os.makedirs(CONVERTED_DIR, exist_ok=True)
    with open(MUSIC_METADATA_TXT, 'w', encoding='utf-8') as f:
        album_index = 1
        for _, tracks in sorted_albums:
            tracks.sort(key=lambda t: t['track_num'])
            for entry in tracks:
                f.write(entry['line'] + '\n')
            # Get folder directly from first track path
            prefix = "/opt2/MusicCh/contents/"
            pcm_paths = [entry['line'].split('|')[1] for entry in tracks]
            rel_paths = [p[len(prefix):] if p.startswith(prefix) else p for p in pcm_paths]
            common_rel_path = os.path.commonpath(rel_paths)
            folder = prefix + common_rel_path
            total_tracks = len(tracks)
            out_folder = tracks[0]['out_folder']
            ctime_epoch = os.path.getctime(out_folder) if os.path.exists(out_folder) else datetime.datetime.now().timestamp()
            ctime_short = datetime.datetime.fromtimestamp(ctime_epoch).strftime("%Y%m%d")
            ctime_long = datetime.datetime.fromtimestamp(ctime_epoch).strftime("%Y-%m-%d %H:%M:%S")
            album = tracks[0]['album']
            artist = tracks[0]['artist']

            def parse_time_to_seconds(timestr):
                parts = timestr.strip().split(':')
                parts = [int(p) for p in parts]
                if len(parts) == 3:
                    return parts[0]*3600 + parts[1]*60 + parts[2]
                elif len(parts) == 2:
                    return parts[0]*60 + parts[1]
                return 0

            total_length = 0
            total_size = 0
            for entry in tracks:
                fields = entry['line'].split('|')
                if len(fields) >= 13:
                    duration = parse_time_to_seconds(fields[11])
                    try:
                        size = int(fields[12])
                    except ValueError:
                        size = 0
                    total_length += duration
                    total_size += size

            footer = (
                f"1|{folder}|{total_tracks}|{ctime_short}|0|{album}||Unknown title|Unknown title|{artist}||"
                f"{format_seconds(total_length)}|{total_size}|0|0|{ctime_long}|NULL|NULL|-1|NULL|{album_index}"
            )
            f.write(footer + '\n')
            album_index += 1

    # After processing all files, print summary to terminal
    if skipped_files:
        print("\nSkipped files:")
        for f, reason in skipped_files:
            print(f"  - {f} ({reason})")
    else:
        print("\nNo files were skipped.")

# Create new database file:
def format_values(line):
    timestamp_pattern = re.compile(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$")
    number_pattern = re.compile(r"^-?\d+(\.\d+)?$")

    line = line.replace('%', '％')  # Replace percent sign with fullwidth
    line = line.strip()
    if not line:
        return None
    values = [v.replace("'", "''") if v != "NULL" else "NULL" for v in line.split("|")]
    quoted_values = []
    for v in values:
        if v == "NULL":
            quoted_values.append("NULL")
        elif number_pattern.match(v):
            quoted_values.append(v)
        elif v.count(':') == 2 and len(v) == 8:
            quoted_values.append(f"'{v}'")
        elif timestamp_pattern.match(v):
            quoted_values.append(f"'{v}'")
        else:
            quoted_values.append(f"'{v}'")
    return "(" + ",".join(quoted_values) + ")"

def create_db():
    with open(OUTPUT_PATH, "w", encoding="utf-8") as out:
        out.write(header_music)

        fav_lines = []
        if os.path.exists(MUSIC_FAV_TXT):
            with open(MUSIC_FAV_TXT, "r", encoding="utf-8") as f:
                fav_lines = f.readlines()

        if fav_lines:
            first_values = format_values(fav_lines[0])
        else:
            default_first_line = "1|0|NULL|NULL|0|Favorite1||Unknown title|Unknown title|Unknown Artist|Unknown Artist|NULL|NULL|0|0|2023-06-06 12:50:31|NULL|NULL|-2|NULL|NULL"
            first_values = format_values(default_first_line)

        if first_values:
            out.write(f"INSERT INTO SCEI_Jukebox VALUES{first_values};\n")

        # Write lines from music_data.txt
        with open(MUSIC_METADATA_TXT, "r", encoding="utf-8") as f:
            for line in f:
                values = format_values(line)
                if values:
                    out.write(f"INSERT INTO SCEI_Jukebox VALUES{values};\n")

        # Header for favorite_color section
        out.write(header_fav)

        # Remaining lines as SCEI_Jukebox_favorite_color
        for line in fav_lines[1:]:
            values = format_values(line)
            if values:
                out.write(f"INSERT INTO SCEI_Jukebox_favorite_color VALUES{values};\n")

        out.write(footer)

if __name__ == "__main__":
    if os.path.exists(SQL_PATH):
        extract_music_data()
    else:
        error_message = f"No existing database to convert.\n"
        with open(LOG_PATH, "a", encoding="utf-8") as log_file:
            log_file.write(error_message)
        print(error_message, file=sys.stderr)
    
    music_installer()
    create_db()