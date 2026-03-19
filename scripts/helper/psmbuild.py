#!/usr/bin/env python3

"""
PSM Builder form the PSBBN Definitive Project
Copyright (C) 2024-2026 CosmicScale

<https://github.com/CosmicScale/PSBBN-Definitive-English-Patch>

SPDX-License-Identifier: GPL-3.0-or-later

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
"""

import sys
import struct
import os
from PIL import Image

# ------------------------------
# Constants for TM2 thumbnail
# ------------------------------
WIDTH = 256
HEIGHT = 256
IMAGE_SIZE = WIDTH * HEIGHT
CLUT_SIZE = 256 * 4  # 256 RGBA entries

# Hardcoded GS TEX registers
GS_TEX0 = bytes([0x00, 0x00, 0x30, 0x21, 0x02, 0x00, 0x00, 0x00])
GS_TEX1 = bytes([0x6c, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])

# ------------------------------
# Constants for PSM header
# ------------------------------
PS2S_HEADER_SIZE        = 0x70
OFFSET_MAGIC            = 0x00  # 4 bytes  - "PS2S"
OFFSET_VERSION          = 0x04  # 2 bytes  - Format version
OFFSET_FLAGS            = 0x06  # 2 bytes  - Flags (usually 0)
OFFSET_DATA_OFFSET      = 0x08  # 4 bytes  - Offset to MPEG stream
OFFSET_FIELD_COUNT      = 0x0C  # 4 bytes  - Observed constant (0x04)
OFFSET_INTERNAL_OFFSET  = 0x10  # 4 bytes  - Observed constant (0x18)
OFFSET_TITLE_POINTER    = 0x14  # 4 bytes  - Offset to title (0x50)
OFFSET_THUMB_SIZE       = 0x40  # 4 bytes  - Thumbnail size
OFFSET_THUMB_OFFSET     = 0x44  # 4 bytes  - Thumbnail offset
OFFSET_TITLE            = 0x50  # 32 bytes - Title (Shift-JIS)

TITLE_MAX_LEN           = 0x20

PS2S_VERSION            = 0x0100
PS2S_FLAGS              = 0x0000
PS2S_FIELD_COUNT        = 0x00000004
PS2S_INTERNAL_OFFSET    = 0x00000018
PS2S_TITLE_POINTER      = OFFSET_TITLE

# ==============================
# TM2 functions
# ==============================
def build_tim2_file_header():
    header = bytearray(0x10)
    header[0:4] = b"TIM2"                   # Magic
    header[4] = 4                           # Version
    header[5] = 0                           # Format
    struct.pack_into("<H", header, 6, 1)    # Picture count
    return header

def build_tim2_picture_header(image_size, clut_size, width, height):
    header = bytearray(0x30)
    total_size = 0x30 + image_size + clut_size          # Total picture size = header + image + palette
    struct.pack_into("<I", header, 0x00, total_size)    # Total size
    struct.pack_into("<I", header, 0x04, clut_size)     # CLUT size
    struct.pack_into("<I", header, 0x08, image_size)    # Image size
    struct.pack_into("<H", header, 0x0C, 0x30)          # Header size
    struct.pack_into("<H", header, 0x0E, 256)           # CLUT color count
    header[0x10] = 0                                    # Picture format
    header[0x11] = 1                                    # Mipmap count
    header[0x12] = 3                                    # CLUT color type (RGBA8888)
    header[0x13] = 5                                    # Image color type (8-bit indexed)
    struct.pack_into("<H", header, 0x14, width)         # Width
    struct.pack_into("<H", header, 0x16, height)        # Height
    header[0x18:0x20] = GS_TEX0                         # GS TEX register
    header[0x20:0x28] = GS_TEX1                         # GS TEX register
    return header

def swizzle_palette_256(pal):
    result = [None] * 256
    for block in range(8):
        base = block * 32
        block_colors = pal[base:base + 32]
        result[base + 0:base + 8] = block_colors[0:8]
        result[base + 8:base + 16] = block_colors[16:24]
        result[base + 16:base + 24] = block_colors[8:16]
        result[base + 24:base + 32] = block_colors[24:32]
    return result

def apply_palette_alpha(palette, alpha_value=128):
    return [(r, g, b, alpha_value) for r, g, b in palette]

def png_to_tm2(png_path):
    # Load and resize image
    with Image.open(png_path) as img:
        img = img.convert("RGB").resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)

        # Separate RGB for palette generation
        rgb_img = img.convert("RGB")

        # Build palette using MEDIANCUT
        pal_base = rgb_img.quantize(
            colors=256,
            method=Image.MEDIANCUT,
            dither=Image.FLOYDSTEINBERG
        )

        # Apply palette to image
        pal_img = rgb_img.quantize(
            palette=pal_base,
            dither=Image.FLOYDSTEINBERG
        )
        
        raw_palette = pal_img.getpalette()[:768]

        if len(raw_palette) < 768:
            raw_palette += [0] * (768 - len(raw_palette))
            
        palette_rgb = [(raw_palette[i], raw_palette[i+1], raw_palette[i+2])
                       for i in range(0, len(raw_palette), 3)]
        image_indices = bytearray(pal_img.getdata())

    # Swizzle palette and add alpha
    swizzled_rgba = apply_palette_alpha(swizzle_palette_256(palette_rgb), alpha_value=128)
    palette_bytes = b''.join(struct.pack("<BBBB", r, g, b, a) for r, g, b, a in swizzled_rgba)

    file_header = build_tim2_file_header()
    picture_header = build_tim2_picture_header(len(image_indices), len(palette_bytes), WIDTH, HEIGHT)
    return file_header + picture_header + image_indices + palette_bytes

# ==============================
# PSM functions
# ==============================
def align16(value):
    return (value + 15) & ~15

def truncate_shift_jis_safe(text, max_bytes):
    encoded = bytearray()
    for ch in text:
        ch_bytes = ch.encode("shift_jis", errors="ignore")
        if len(encoded) + len(ch_bytes) > max_bytes:
            break
        encoded.extend(ch_bytes)
    return bytes(encoded)

def build_psm_header(thumb_size, thumb_offset, data_offset, title_text):
    header = bytearray(PS2S_HEADER_SIZE)
    header[OFFSET_MAGIC:OFFSET_MAGIC+4] = b"PS2S"
    struct.pack_into("<H", header, OFFSET_VERSION, PS2S_VERSION)
    struct.pack_into("<H", header, OFFSET_FLAGS, PS2S_FLAGS)
    struct.pack_into("<I", header, OFFSET_DATA_OFFSET, data_offset)
    struct.pack_into("<I", header, OFFSET_FIELD_COUNT, PS2S_FIELD_COUNT)
    struct.pack_into("<I", header, OFFSET_INTERNAL_OFFSET, PS2S_INTERNAL_OFFSET)
    struct.pack_into("<I", header, OFFSET_TITLE_POINTER, PS2S_TITLE_POINTER)
    struct.pack_into("<I", header, OFFSET_THUMB_SIZE, thumb_size)
    struct.pack_into("<I", header, OFFSET_THUMB_OFFSET, thumb_offset)
    safe_title = truncate_shift_jis_safe(title_text, TITLE_MAX_LEN - 1)
    header[OFFSET_TITLE:OFFSET_TITLE + TITLE_MAX_LEN] = b"\x00" * TITLE_MAX_LEN
    header[OFFSET_TITLE:OFFSET_TITLE + len(safe_title)] = safe_title
    return header

def build_psm(pss_file, png_file, output_file, title_text):
    # Convert PNG to TIM2
    tm2_data = png_to_tm2(png_file)
    if tm2_data[0:4] != b"TIM2":
        raise ValueError("Generated TIM2 invalid!")

    # Read MPEG stream
    with open(pss_file, "rb") as f:
        mpeg_data = f.read()
    if mpeg_data[0:4] != b"\x00\x00\x01\xBA":
        raise ValueError("PSS file not valid MPEG-PS!")

    # Compute layout
    thumb_size = len(tm2_data)
    thumb_offset = PS2S_HEADER_SIZE
    raw_end = PS2S_HEADER_SIZE + thumb_size
    aligned_end = align16(raw_end)
    padding_size = aligned_end - raw_end

    header = build_psm_header(
        thumb_size=thumb_size,
        thumb_offset=thumb_offset,
        data_offset=aligned_end,
        title_text=title_text
    )

    # Write output
    with open(output_file, "wb") as f:
        f.write(header)
        f.write(tm2_data)
        f.write(b"\x00" * padding_size)
        f.write(mpeg_data)
    print()
    print(f"[✓] Created PSM: {os.path.basename(output_file)}")

# ------------------------------
# Main entry
# ------------------------------
if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python3 psmbuild.py <input.pss> <input.png> <output.psm>")
        sys.exit(1)

    pss_file = sys.argv[1]
    png_file = sys.argv[2]
    output_file = sys.argv[3]

    print(f"Creating {os.path.basename(output_file)}...", end="", flush=True)
    # Title derived from output filename without extension
    title = output_file.rsplit(".", 1)[0]
    build_psm(pss_file, png_file, output_file, title_text=title)
