#!/usr/bin/env python3
"""Verify heading and throw-in sprites from the original Sensible Soccer sprite sheet.

Extracts rows 4-10 from cjcteam1.png and creates a labeled composite image
showing all 7 directions with 3 heading frames + 3 throw-in frames each.

Usage:
    python3 tools/verify_heading_throwin.py

Output:
    /tmp/heading_throwin_verify.png
"""

from PIL import Image, ImageDraw, ImageFont
import numpy as np
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from tools.extract_sprites import indexed_to_rgba, BG_INDEX

SHEET_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "sprites", "original", "cjcteam1.png"
)
OUTPUT_PATH = "/tmp/heading_throwin_verify.png"

SCALE = 4
CELL_W = 16
BAND_H = 24
LABEL_W = 60
SPRITE_GAP = 4
GROUP_GAP = 30
ROW_GAP = 10
HEADER_H = 30

# Rows 4-10: direction -> y_start
BANDS = [
    ("S",  56),
    ("E",  80),
    ("W",  104),
    ("SW", 128),
    ("SE", 152),
    ("NW", 176),
    ("NE", 200),
]

# Heading: columns 0,1,2 (x=0,16,32)
# Throw-in: columns 4,5,6 (x=64,80,96)
HEADING_COLS = [0, 16, 32]
THROWIN_COLS = [64, 80, 96]


def extract_sprite_rgba(rgba, x, y, w, h):
    """Extract a region from the RGBA array and return as PIL Image."""
    region = rgba[y:y + h, x:x + w]
    return Image.fromarray(region, "RGBA")


def main():
    img = Image.open(SHEET_PATH)
    rgba = indexed_to_rgba(img)

    # Calculate canvas size
    sprite_scaled_w = CELL_W * SCALE
    sprite_scaled_h = BAND_H * SCALE
    row_w = LABEL_W + 3 * (sprite_scaled_w + SPRITE_GAP) + GROUP_GAP + 3 * (sprite_scaled_w + SPRITE_GAP) + 40
    row_h = sprite_scaled_h + ROW_GAP
    canvas_w = max(row_w, 700)
    canvas_h = HEADER_H + 20 + len(BANDS) * row_h + 20

    canvas = Image.new("RGBA", (canvas_w, canvas_h), (40, 40, 40, 255))
    draw = ImageDraw.Draw(canvas)

    # Header
    draw.text((10, 5), "HEADING (3 frames)", fill=(255, 200, 100, 255))
    heading_x_start = LABEL_W
    throwin_x_start = LABEL_W + 3 * (sprite_scaled_w + SPRITE_GAP) + GROUP_GAP
    draw.text((heading_x_start, 5), "Frame 1    Frame 2    Frame 3", fill=(200, 200, 200, 255))
    draw.text((throwin_x_start, 5), "THROW-IN (3 frames)", fill=(100, 200, 255, 255))
    draw.text((throwin_x_start, 17), "Frame 1    Frame 2    Frame 3*", fill=(200, 200, 200, 255))

    y_pos = HEADER_H + 10

    for dir_name, y_start in BANDS:
        # Direction label
        draw.text((10, y_pos + sprite_scaled_h // 2 - 8), dir_name, fill=(255, 255, 0, 255))

        # Heading frames
        x_pos = heading_x_start
        for col_x in HEADING_COLS:
            sprite = extract_sprite_rgba(rgba, col_x, y_start, CELL_W, BAND_H)
            scaled = sprite.resize((sprite_scaled_w, sprite_scaled_h), Image.NEAREST)
            canvas.paste(scaled, (x_pos, y_pos), scaled)
            x_pos += sprite_scaled_w + SPRITE_GAP

        # Throw-in frames
        x_pos = throwin_x_start
        for i, col_x in enumerate(THROWIN_COLS):
            sprite = extract_sprite_rgba(rgba, col_x, y_start, CELL_W, BAND_H)
            scaled = sprite.resize((sprite_scaled_w, sprite_scaled_h), Image.NEAREST)
            canvas.paste(scaled, (x_pos, y_pos), scaled)
            # Mark frame 3 as ball visible
            if i == 2:
                draw.text((x_pos, y_pos + sprite_scaled_h - 12), "BALL", fill=(0, 255, 0, 255))
            x_pos += sprite_scaled_w + SPRITE_GAP

        y_pos += row_h

    canvas.save(OUTPUT_PATH)
    print(f"Saved verification image to {OUTPUT_PATH}")
    print(f"Canvas size: {canvas_w}x{canvas_h}")
    print(f"Directions: {[d for d, _ in BANDS]}")


if __name__ == "__main__":
    main()
