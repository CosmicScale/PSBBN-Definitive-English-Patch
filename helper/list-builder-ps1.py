import os
import sys
import math
import unicodedata
import re
from natsort import natsorted

done = "Error: No games found."
total = 0
count = 0
pattern_1 = [b'\x01', b'\x0D']
pattern_2 = [b'\x3B', b'\x31']

# Function to count VCD files in the POPS folder
def count_vcd(folder):
    global total
    for image in os.listdir(game_path + folder):
        if image.startswith('.'):  # Skip hidden files
            continue
        if image.lower().endswith(".vcd"):
            total += 1

# Function to process VCD files in the POPS folder
def process_vcd(folder):
    global total
    global count
    global done

    gameid_file_path = "./helper/TitlesDB_PS1_English.csv"

    # Read TitlesDB_PS1_English.csv and create a dictionary of Game IDs to game names
    game_names = {}
    if os.path.isfile(gameid_file_path):
        with open(gameid_file_path, 'r') as gameid_file:
            for line in gameid_file:
                parts = line.strip().split('|')  # Split Game ID and game name
                if len(parts) >= 3:
                    game_names[parts[0]] = (parts[1], parts[2])
    
    # Prepare a list to hold all game list entries
    game_list_entries = []

    for image in os.listdir(game_path + folder):
        if image.startswith('.'):  # Skip hidden files
            continue
        if image.lower().endswith(".vcd"):
            print(math.floor((count * 100) / total), '% complete')
            print('Processing', image)
            index = 0
            string = ""

            # Check the filename condition for all files
            file_name_without_ext = os.path.splitext(image)[0]
            if len(file_name_without_ext) >= 9 and file_name_without_ext[4] == '_' and file_name_without_ext[8] == '.':
                # Filename meets the condition, directly set the game ID
                string = file_name_without_ext[:11].upper()
                print(f"Filename meets condition. Game ID set directly from filename: {string}")
            if not string:  # Only process if the game ID is not set from the filename
                with open(game_path + folder + "/" + image, "rb") as file:
                    while (byte := file.read(1)):
                        if len(string) < 4:
                            if index == 2:
                                string += byte.decode('utf-8', errors='ignore')
                            elif byte == pattern_1[index]:
                                index += 1
                            else:
                                string = ""
                                index = 0
                        elif len(string) == 4:
                            index = 0
                            if byte == b'\x5F':
                                string += byte.decode('utf-8', errors='ignore')
                            else:
                                string = ""
                        elif len(string) < 8:
                            string += byte.decode('utf-8', errors='ignore')
                        elif len(string) == 8:
                            if byte == b'\x2E':
                                string += byte.decode('utf-8', errors='ignore')
                            else:
                                string = ""
                        elif len(string) < 11:
                            string += byte.decode('utf-8', errors='ignore')
                        elif len(string) == 11:
                            if byte == pattern_2[index]:
                                index += 1
                                if index == 2:
                                    break
                            else:
                                string = ""
                                index = 0

                count += 1

            # If no Game ID is found, generate one from filename
            if len(string) != 11:
                # Remove spaces from filename and convert to uppercase
                base_name = os.path.splitext(image)[0]  # Strip the file extension
                string = re.sub(r'[^A-Z0-9]', '', base_name.upper())  # Keep only A-Z and 0-9

                # Trim the string to 9 characters or pad with zeros
                string = string[:9].ljust(9, '0')

                # Insert the underscore at position 5 and the full stop at position 9
                string = string[:4] + '_' + string[4:7] + '.' + string[7:]

                # Ensure the string is exactly 11 characters long
                string = string[:11]

                print(f'No Game ID found. Generating Game ID based on filename: {string}')

            # Determine game name and publisher
            entry = game_names.get(string)

            if entry:
                # If we found a match in the CSV
                game_name = entry[0] if entry[0] else None  # If game name is empty, set to None
                publisher = entry[1] if len(entry) > 1 and entry[1] else ""
                if not game_name:  # If game name is None (i.e., found in CSV but empty)
                    print(f"Game ID '{string}' found in CSV, but title is missing. Using filename logic.")
                    file_name_without_ext = os.path.splitext(image)[0]
                    if len(file_name_without_ext) >= 12 and file_name_without_ext[4] == '_' and file_name_without_ext[8] == '.' and file_name_without_ext[11] == '.':
                        game_name = file_name_without_ext[12:]  # Fallback to part after the game ID
                    else:
                        game_name = file_name_without_ext  # Use the filename as-is
                    publisher = ""  # Publisher will remain empty in this case
                print(f"Match found: ID='{string}' -> Game='{game_name}', Publisher='{publisher}'")
            else:
                # If no match found in CSV, use filename logic for game name
                print(f"No match found for ID '{string}'")
                file_name_without_ext = os.path.splitext(image)[0]
                if len(file_name_without_ext) >= 12 and file_name_without_ext[4] == '_' and file_name_without_ext[8] == '.' and file_name_without_ext[11] == '.':
                    game_name = file_name_without_ext[12:]
                else:
                    game_name = file_name_without_ext
                publisher = ""
                print(f"Default game name from filename: '{game_name}'")

            # Format entry with game name, game ID, publisher, and image info
            folder_image = f"{folder.replace('/', '', 1)}|{image}"
            game_list_entry = f"{game_name}|{string}|{publisher}|{folder_image}"
            game_list_entries.append(game_list_entry)

    if game_list_entries:
        with open(games_list_path, "a") as output:
            for entry in game_list_entries:
                output.write(f"{entry}\n")

    done = "Done!"

# Function to normalize text by removing diacritical marks and converting to ASCII
def normalize_text(text):
    """
    Normalize text by removing diacritical marks and converting to ASCII.
    """
    return ''.join(
        c for c in unicodedata.normalize('NFD', text)
        if unicodedata.category(c) != 'Mn'
    )

# Main function to sort the games list
def sort_games_list():
    # Read the ps1.list into a list of lines
    with open(games_list_path, 'r') as file:
        lines = file.readlines()

    # Sort the lines by the first field dynamically
    def sort_key(line):
        # Split the line into fields
        fields = line.strip().split('|')

        # Extract the game title (first field) and game_id (second field, if present)
        first_field = fields[0].strip()
        game_id = fields[1].strip() if len(fields) > 1 else ""
        
        # Check for colon and truncate at the first colon, if exists
        if ':' in first_field:
            first_field = first_field.split(':')[0].strip()

        # Remove leading "The" or "the" for sorting purposes
        if first_field.lower().startswith('the '):
            first_field = first_field[4:].strip()

        # Normalize the title
        normalized_title = normalize_text(first_field)

        # Remove special characters
        normalized_title = ''.join(c for c in normalized_title if c.isalnum() or c.isspace())

        # Check for special cases like Roman numeral endings
        replacements = {
            ' I': ' 1',
            ' II': ' 2',
            ' III': ' 3',
            ' IV': ' 4',
            ' V': ' 5',
            ' VI': ' 6',
            ' VII': ' 7',
            ' VIII': ' 8',
            ' IX': ' 9',
            ' X': ' 10',
            ' XI': ' 11',
            ' XII': ' 12',
            ' XIII': ' 13',
            ' XIV': ' 14',
            ' XV': ' 15',
            ' XVI': ' 16',
            ' XVII': ' 17',
            ' XVIII': ' 18',
            ' XIX': ' 19',
            ' XX': ' 20'
        }
        for roman, digit in replacements.items():
            if normalized_title.endswith(roman):
                normalized_title = normalized_title.replace(roman, digit)
                break

        final_key = normalized_title.lower()
        return (final_key, game_id)

    # Sort the lines by the dynamic key using natsorted
    sorted_lines = natsorted(lines, key=sort_key)

    # Write the sorted lines back to the specified games list path
    with open(games_list_path, 'w') as file:
        file.writelines(sorted_lines)

def main(arg1, arg2):
    if arg1 and arg2:
        global game_path
        global games_list_path
        game_path = arg1
        games_list_path = arg2

        # Remove any existing game list file
        if os.path.isfile(games_list_path):
            os.remove(games_list_path)

        # Count and process files in the DVD and CD folders
        if os.path.isdir(game_path + '/POPS'):
            count_vcd('/POPS')
            if total == 0:  # No VCD files found
                print("No PS1 games found in the POPS folder.")
                sys.exit(0)
            process_vcd('/POPS')
        else:
            print('POPS folder not found at ' + game_path)
            sys.exit(1)

        # Sort the games list after processing
        sort_games_list()

        print(done)
        print('')
    else:
        print('Usage: python3 list_builder-ps1.py <path/to/games> <path/to/ps1.list>')
        sys.exit(1)

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print('Usage: python3 list_builder-ps1.py <path/to/games> <path/to/ps1.list>')
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
