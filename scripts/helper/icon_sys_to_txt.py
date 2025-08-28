import sys
import struct
import unicodedata
import os

def read_rgb_rgba_block_raw(data, offset):
    # Return native 0–127 values without scaling for PSBBN
    r = data[offset]
    g = data[offset + 4]
    b = data[offset + 8]
    return (r, g, b)

def read_light_rgb_floats_raw(data, offset):
    # Read float32 values and map directly to 0–127
    return tuple(
        max(0, min(127, round(struct.unpack('<f', data[offset + i*4 : offset + i*4 + 4])[0] * 127)))
        for i in range(3)
    )

def read_light_direction(data, offset):
    return struct.unpack('<fff', data[offset:offset+12])

def decode_title_pair(data, title_offset=0xC0, length=68):
    split_offset = struct.unpack("<H", data[0x06:0x08])[0]
    title_block = data[title_offset:title_offset + length]
    title0_bytes = title_block[:split_offset]
    title1_bytes = title_block[split_offset:]
    try:
        title0 = title0_bytes.split(b'\x00')[0].decode('shift_jis', errors='ignore').strip()
        title0 = unicodedata.normalize('NFKC', title0)
    except:
        title0 = "[decode error]"
    try:
        title1 = title1_bytes.split(b'\x00')[0].decode('shift_jis', errors='ignore').strip()
        title1 = unicodedata.normalize('NFKC', title1)
    except:
        title1 = ""
    return title0, title1

def parse_icon_sys(filepath):
    with open(filepath, "rb") as f:
        data = f.read()
    if data[:4] != b"PS2D":
        raise ValueError("This is not a valid icon.sys file (missing PS2D header).")
    title0, title1 = decode_title_pair(data)
    parsed = {
        "title0": title0,
        "title1": title1,
        "bgcola": data[0x0C],
        "bgcol0": read_rgb_rgba_block_raw(data, 0x10),
        "bgcol1": read_rgb_rgba_block_raw(data, 0x20),
        "bgcol2": read_rgb_rgba_block_raw(data, 0x30),
        "bgcol3": read_rgb_rgba_block_raw(data, 0x40),
        "lightdir0": read_light_direction(data, 0x50),
        "lightdir1": read_light_direction(data, 0x60),
        "lightdir2": read_light_direction(data, 0x70),
        "lightcol0": read_light_rgb_floats_raw(data, 0x80),
        "lightcol1": read_light_rgb_floats_raw(data, 0x90),
        "lightcol2": read_light_rgb_floats_raw(data, 0xA0),
        "lightcolamb": read_light_rgb_floats_raw(data, 0xB0),
        "uninstallmes0": "",
        "uninstallmes1": "",
        "uninstallmes2": ""
    }
    return parsed

def write_icon_txt(parsed, output_path):
    lines = [
        "PS2X",
        f"title0={parsed['title0']}",
        f"title1={parsed['title1']}",
        f"bgcola={parsed['bgcola']}",
        f"bgcol0={','.join(map(str, parsed['bgcol0']))}",
        f"bgcol1={','.join(map(str, parsed['bgcol1']))}",
        f"bgcol2={','.join(map(str, parsed['bgcol2']))}",
        f"bgcol3={','.join(map(str, parsed['bgcol3']))}",
        f"lightdir0={','.join(f'{v:.4f}' for v in parsed['lightdir0'])}",
        f"lightdir1={','.join(f'{v:.4f}' for v in parsed['lightdir1'])}",
        f"lightdir2={','.join(f'{v:.4f}' for v in parsed['lightdir2'])}",
        f"lightcolamb={','.join(map(str, parsed['lightcolamb']))}",
        f"lightcol0={','.join(map(str, parsed['lightcol0']))}",
        f"lightcol1={','.join(map(str, parsed['lightcol1']))}",
        f"lightcol2={','.join(map(str, parsed['lightcol2']))}",
        f"uninstallmes0={parsed['uninstallmes0']}",
        f"uninstallmes1={parsed['uninstallmes1']}",
        f"uninstallmes2={parsed['uninstallmes2']}"
    ]
    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"[✓] icon.txt successfully written to: {output_path}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python icon_sys_to_txt.py path/to/icon.sys")
        sys.exit(1)
    icon_sys_path = sys.argv[1]
    out_path = os.path.join(os.path.dirname(icon_sys_path), "icon.txt")
    try:
        parsed_data = parse_icon_sys(icon_sys_path)
        write_icon_txt(parsed_data, out_path)
    except Exception as e:
        print(f"[!] Failed to parse icon.sys: {e}")
