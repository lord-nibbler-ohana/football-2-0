#!/usr/bin/env python3
"""Dump every sprite from cjcteam1.png as individual numbered images.

Scans the entire sheet row-by-row (using generous band heights) and
saves each detected sprite to /tmp/sprites/ for visual inspection.

Usage:
    python3 tools/dump_sprites.py
"""

from PIL import Image
import numpy as np
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from tools.extract_sprites import find_sprites_in_region, indexed_to_rgba, BG_INDEX

OUTPUT_DIR = "/tmp/sprites"
SHEET_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "sprites", "original", "cjcteam1.png"
)


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    img = Image.open(SHEET_PATH)
    data = np.array(img)
    rgba = indexed_to_rgba(img)
    h, w = data.shape
    print(f"Sheet: {w}×{h}")

    # Scan with generous overlapping bands to catch everything
    # Use 32px bands with 24px step (some overlap)
    bands = [
        ("row1", 0, 32),
        ("row2", 32, 24),
        ("row3", 56, 24),
        ("band4", 80, 24),
        ("band5", 104, 24),
        ("band6", 128, 24),
        ("band7", 152, 24),
        ("band8", 176, 24),
        ("band9", 200, 24),
        ("band10", 224, 32),
    ]

    sprite_idx = 0
    for band_name, y_start, band_h in bands:
        sprites = find_sprites_in_region(data, 0, y_start, w, band_h, BG_INDEX)
        sprites.sort(key=lambda s: s[0])

        if not sprites:
            continue

        print(f"\n=== {band_name} (y={y_start}, h={band_h}): {len(sprites)} sprites ===")
        for sx, sy, sw, sh in sprites:
            # Extract RGBA sprite
            sprite_rgba = rgba[sy:sy + sh, sx:sx + sw]
            pil_img = Image.fromarray(sprite_rgba, "RGBA")

            # Save enlarged 8×
            scale = 8
            big = pil_img.resize((sw * scale, sh * scale), Image.NEAREST)
            fname = f"sprite_{sprite_idx:03d}_{band_name}_x{sx:03d}_y{sy:03d}_{sw}x{sh}.png"
            big.save(os.path.join(OUTPUT_DIR, fname))

            print(f"  [{sprite_idx:3d}] x={sx:3d} y={sy:3d} w={sw:2d} h={sh:2d}  → {fname}")
            sprite_idx += 1

    print(f"\nTotal: {sprite_idx} sprites saved to {OUTPUT_DIR}/")
    print(f"\nOpen the folder to inspect: ls {OUTPUT_DIR}/")


if __name__ == "__main__":
    main()
