#!/usr/bin/env python3
"""
Extract and repack Sensible Soccer sprites into Godot-friendly sprite sheets.

Source: sprites/original/ (Codetapper Amiga rips, 320x256 indexed PNGs)
Output: sprites/players/, sprites/ball/, sprites/pitch/

Usage:
    python3 tools/extract_sprites.py
"""

from PIL import Image
import numpy as np
import os

# --- Configuration ---

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ORIGINAL_DIR = os.path.join(PROJECT_ROOT, "sprites", "original")
PLAYERS_DIR = os.path.join(PROJECT_ROOT, "sprites", "players")
BALL_DIR = os.path.join(PROJECT_ROOT, "sprites", "ball")
PITCH_DIR = os.path.join(PROJECT_ROOT, "sprites", "pitch")

# Palette for player sprites (shared across all team variants)
# Index: (R, G, B) — from the original Amiga palette
PLAYER_PALETTE = {
    0: (0x33, 0x66, 0x00),  # grass background
    1: (0x99, 0x99, 0x99),  # gray
    2: (0xFF, 0xFF, 0xFF),  # white (socks/highlights)
    3: (0x00, 0x00, 0x00),  # black (boots/outlines)
    4: (0x77, 0x22, 0x11),  # dark skin
    5: (0xAA, 0x44, 0x00),  # medium skin
    6: (0xFF, 0x77, 0x11),  # light skin
    7: (0x22, 0x55, 0x00),  # dark green (unused)
    8: (0x00, 0x33, 0x00),  # shadow on grass
    9: (0xCC, 0x88, 0x00),  # hair (golden)
    10: (0xFF, 0x00, 0x00),  # KIT COLOR A (red)
    11: (0x00, 0x00, 0xFF),  # KIT COLOR B (blue)
    12: (0x88, 0x44, 0x00),  # dark brown (hair variant)
    13: (0xFF, 0xBB, 0x00),  # amber (hair variant)
    14: (0x00, 0xDD, 0x00),  # bright green (anti-alias)
    15: (0xFF, 0xFF, 0x00),  # yellow
}

# Background and shadow indices
BG_INDEX = 0
SHADOW_INDEX = 8
ANTIALIAS_INDEX = 14

# Marker colors for palette swap shader (visually distinct)
MARKER_KIT_A = (0xFF, 0x00, 0x00)     # red — maps to kit primary
MARKER_KIT_B = (0x00, 0x00, 0xFF)     # blue — maps to kit secondary
MARKER_SOCKS = (0xFF, 0xFF, 0xFF)     # white — maps to socks
MARKER_HAIR = (0xCC, 0x88, 0x00)      # golden — maps to hair


def indexed_to_rgba(img):
    """Convert indexed PNG to RGBA, making background transparent."""
    data = np.array(img)
    palette = img.getpalette()
    h, w = data.shape
    rgba = np.zeros((h, w, 4), dtype=np.uint8)

    for idx in range(16):
        if palette is None:
            break
        r, g, b = palette[idx * 3], palette[idx * 3 + 1], palette[idx * 3 + 2]
        mask = data == idx

        if idx == BG_INDEX:
            # Background → fully transparent
            rgba[mask] = [0, 0, 0, 0]
        elif idx == SHADOW_INDEX:
            # Shadow on grass → semi-transparent black
            rgba[mask] = [0, 0, 0, 128]
        elif idx == ANTIALIAS_INDEX:
            # Anti-alias green → semi-transparent green
            rgba[mask] = [0, g, 0, 96]
        else:
            rgba[mask] = [r, g, b, 255]

    return rgba


def find_sprites_in_region(data, x_start, y_start, width, height, bg_index=0):
    """Find individual sprite bounding boxes in a region using connected components."""
    region = data[y_start:y_start + height, x_start:x_start + width]
    mask = region != bg_index

    if not mask.any():
        return []

    # Simple column-gap-based sprite separation
    col_has = np.any(mask, axis=0)
    sprites = []
    in_sprite = False
    sx = 0

    for x in range(width):
        if col_has[x] and not in_sprite:
            sx = x
            in_sprite = True
        elif (not col_has[x] or x == width - 1) and in_sprite:
            ex = x if not col_has[x] else x + 1
            # Find vertical bounds for this column range
            col_mask = mask[:, sx:ex]
            row_has = np.any(col_mask, axis=1)
            rows = np.where(row_has)[0]
            if len(rows) > 0:
                sy = rows[0]
                ey = rows[-1] + 1
                sprites.append((
                    x_start + sx, y_start + sy,
                    ex - sx, ey - sy
                ))
            in_sprite = False

    return sprites


def _extract_column_half(data, col_idx, half, bg_index=0):
    """Extract one sprite from a 16px column, top or bottom half of y=0-31.

    The original Amiga sheet packs TWO sprites per column in the first band:
      top half: y≈0-15  (row 1: cardinal directions + slides)
      bot half: y≈16-31 (row 2: diagonal directions + down sprites)

    Uses vertical gap detection to split, then returns tight bounding box.
    """
    x = col_idx * 16
    col_w = 16
    x_end = min(x + col_w, data.shape[1])
    region = data[0:32, x:x_end]
    mask = region != bg_index

    if not mask.any():
        return None

    # Find vertical sub-sprites by gap detection
    row_has = np.any(mask, axis=1)
    in_sprite = False
    sprites_y = []
    sy = 0
    for y in range(32):
        if row_has[y] and not in_sprite:
            sy = y
            in_sprite = True
        elif not row_has[y] and in_sprite:
            sprites_y.append((sy, y))
            in_sprite = False
    if in_sprite:
        sprites_y.append((sy, 32))

    idx = 0 if half == "top" else 1
    if idx >= len(sprites_y):
        return None

    y0, y1 = sprites_y[idx]
    sub_mask = mask[y0:y1, :]
    cols_any = np.any(sub_mask, axis=0)
    c = np.where(cols_any)[0]
    if len(c) == 0:
        return None

    sx, ex = c[0], c[-1] + 1
    return (x + sx, y0, ex - sx, y1 - y0)


def _extract_band_sprite(data, col_idx, y_start, band_h, bg_index=0):
    """Extract a single sprite from a 16px column in a lower band (y=32+)."""
    x = col_idx * 16
    x_end = min(x + 16, data.shape[1])
    y_end = min(y_start + band_h, data.shape[0])
    region = data[y_start:y_end, x:x_end]
    mask = region != bg_index

    if not mask.any():
        return None

    rows_any = np.any(mask, axis=1)
    cols_any = np.any(mask, axis=0)
    r = np.where(rows_any)[0]
    c = np.where(cols_any)[0]
    return (x + c[0], y_start + r[0], c[-1] - c[0] + 1, r[-1] - r[0] + 1)


def extract_player_sprites_semantic(filename):
    """Extract player sprites using the known layout of cjcteam1/2/3.

    The original Amiga sheet (320×256) packs TWO sprite rows into the first
    32px band (y=0-31), with a 1-2px vertical gap between them:

      Top half (y≈0-15) — Row 1: Cardinal directions + slides
        Col: 0=FN  1=N1  2=N2  3=FS  4=S1  5=S2  6=FE  7=E1  8=E2
             9=FW 10=W1 11=W2 12=SlN 13=SlS 14=SlW 15=SlE
            16=SlSW 17=SlSE 18=SlNW 19=SlNE

      Bot half (y≈16-31) — Row 2: Diagonal directions + down sprites
        Col: 0=FSW  1=SW1  2=SW2  3=FSE  4=SE1  5=SE2  6=FNW  7=NW1  8=NW2
             9=FNE 10=NE1 11=NE2 12=DnN 13=DnS 14=DnW 15=DnE
            16=DnSW 17=DnSE 18=DnNW 19=DnNE

    Lower bands (y=32+) contain throw-in, tackle, and other animations.

    Returns (ordered_sprites, img) for packing into the game sprite sheet.
    """
    img = Image.open(os.path.join(ORIGINAL_DIR, filename))
    data = np.array(img)

    def pick_top(col, label):
        s = _extract_column_half(data, col, "top", BG_INDEX)
        if s:
            print(f"    [{label:12s}] x={s[0]:3d} y={s[1]:3d} w={s[2]:2d} h={s[3]:2d}")
        else:
            print(f"    [{label:12s}] WARNING: empty top col {col}")
            s = (col * 16, 0, 1, 1)
        return s

    def pick_bot(col, label):
        s = _extract_column_half(data, col, "bot", BG_INDEX)
        if s:
            print(f"    [{label:12s}] x={s[0]:3d} y={s[1]:3d} w={s[2]:2d} h={s[3]:2d}")
        else:
            print(f"    [{label:12s}] WARNING: empty bot col {col}")
            s = (col * 16, 16, 1, 1)
        return s

    def pick_band(col, y_start, band_h, label):
        s = _extract_band_sprite(data, col, y_start, band_h, BG_INDEX)
        if s:
            print(f"    [{label:12s}] x={s[0]:3d} y={s[1]:3d} w={s[2]:2d} h={s[3]:2d}")
        else:
            print(f"    [{label:12s}] WARNING: empty band col {col} y={y_start}")
            s = (col * 16, y_start, 1, 1)
        return s

    # Target packing order — cell indices match the ANIM_MAP in player_controller.gd.
    ordered = []

    # --- Running (cells 0-9): 2 frames per direction ---
    # S from row1 (top), SE from row2 (bot), E from row1, NE from row2, N from row1
    ordered.append(pick_top( 4, "S run1"))       # cell 0
    ordered.append(pick_top( 5, "S run2"))       # cell 1
    ordered.append(pick_bot( 4, "SE run1"))      # cell 2
    ordered.append(pick_bot( 5, "SE run2"))      # cell 3
    ordered.append(pick_top( 7, "E run1"))       # cell 4
    ordered.append(pick_top( 8, "E run2"))       # cell 5
    ordered.append(pick_bot(10, "NE run1"))      # cell 6
    ordered.append(pick_bot(11, "NE run2"))      # cell 7
    ordered.append(pick_top( 1, "N run1"))       # cell 8
    ordered.append(pick_top( 2, "N run2"))       # cell 9

    # --- Idle (cells 10-14): 1 frame per direction ---
    ordered.append(pick_top( 3, "S idle"))       # cell 10
    ordered.append(pick_bot( 3, "SE idle"))      # cell 11
    ordered.append(pick_top( 6, "E idle"))       # cell 12
    ordered.append(pick_bot( 9, "NE idle"))      # cell 13
    ordered.append(pick_top( 0, "N idle"))       # cell 14

    # --- Kick (cells 15-19): reuse idle ---
    ordered.append(pick_top( 3, "S kick"))       # cell 15
    ordered.append(pick_bot( 3, "SE kick"))      # cell 16
    ordered.append(pick_top( 6, "E kick"))       # cell 17
    ordered.append(pick_bot( 9, "NE kick"))      # cell 18
    ordered.append(pick_top( 0, "N kick"))       # cell 19

    # --- Slides (cells 20-27): single-frame from row1 top ---
    ordered.append(pick_top(13, "SlideS"))       # cell 20
    ordered.append(pick_top(17, "SlideSE"))      # cell 21
    ordered.append(pick_top(15, "SlideE"))       # cell 22
    ordered.append(pick_top(19, "SlideNE"))      # cell 23
    ordered.append(pick_top(12, "SlideN"))       # cell 24
    ordered.append(pick_top(14, "SlideW"))       # cell 25
    ordered.append(pick_top(16, "SlideSW"))      # cell 26
    ordered.append(pick_top(18, "SlideNW"))      # cell 27

    # --- Down/knocked (cells 28-35): from row2 bot ---
    ordered.append(pick_bot(12, "DownN"))        # cell 28
    ordered.append(pick_bot(13, "DownS"))        # cell 29
    ordered.append(pick_bot(17, "DownSE"))       # cell 30
    ordered.append(pick_bot(19, "DownNE"))       # cell 31
    ordered.append(pick_bot(15, "DownE"))        # cell 32
    ordered.append(pick_bot(14, "DownW"))        # cell 33
    ordered.append(pick_bot(16, "DownSW"))       # cell 34
    ordered.append(pick_bot(18, "DownNW"))       # cell 35

    # --- Heading (cells 36-56): 3 frames per direction, 7 directions ---
    # Rows 4-10 in original sheet: heading in columns 0,1,2
    heading_bands = [
        ("S",  56),
        ("E",  80),
        ("W",  104),
        ("SW", 128),
        ("SE", 152),
        ("NW", 176),
        ("NE", 200),
    ]
    for dir_name, y_start in heading_bands:
        for frame in range(3):
            ordered.append(pick_band(frame, y_start, 24,
                                     f"Head{dir_name} f{frame}"))

    # --- Throw-in (cells 57-77): 3 frames per direction, 7 directions ---
    # Same rows, throw-in in columns 4,5,6 (x=64,80,96)
    for dir_name, y_start in heading_bands:
        for frame in range(3):
            ordered.append(pick_band(4 + frame, y_start, 24,
                                     f"Throw{dir_name} f{frame}"))

    return ordered, img


def pack_sprites_to_sheet(img, sprites, cell_w, cell_h, cols):
    """Pack extracted sprites into a grid-based sprite sheet.

    Each sprite is centered in its cell.
    Returns an RGBA PIL Image.
    """
    rgba_full = indexed_to_rgba(img)
    rows = (len(sprites) + cols - 1) // cols
    sheet = np.zeros((rows * cell_h, cols * cell_w, 4), dtype=np.uint8)

    for i, (sx, sy, sw, sh) in enumerate(sprites):
        row = i // cols
        col = i % cols

        # Extract sprite region from RGBA
        sprite_rgba = rgba_full[sy:sy + sh, sx:sx + sw]

        # Center horizontally, bottom-align vertically
        ox = max(0, (cell_w - sw) // 2)
        oy = max(0, cell_h - sh)

        # Crop sprite if larger than cell
        src_x = max(0, (sw - cell_w) // 2)
        src_y = max(0, sh - cell_h)
        paste_w = min(sw - src_x, cell_w - ox)
        paste_h = min(sh - src_y, cell_h - oy)

        if paste_w <= 0 or paste_h <= 0:
            continue

        dest_y = row * cell_h + oy
        dest_x = col * cell_w + ox
        sheet[dest_y:dest_y + paste_h, dest_x:dest_x + paste_w] = \
            sprite_rgba[src_y:src_y + paste_h, src_x:src_x + paste_w]

    return Image.fromarray(sheet, "RGBA")


def create_ball_sprites():
    """Create simple ball sprites at Sensible Soccer scale.

    Ball is ~5x5 pixels with 3 rotation frames.
    """
    cell_size = 8
    # 3 rotation frames + 1 shadow = 4 cells in a row
    sheet = np.zeros((cell_size, cell_size * 4, 4), dtype=np.uint8)

    # Frame 0: ball facing forward (simple circle with highlight)
    ball_0 = [
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 1, 1, 1, 0, 0, 0],
        [0, 1, 2, 2, 1, 1, 0, 0],
        [0, 1, 2, 1, 1, 1, 0, 0],
        [0, 1, 1, 1, 1, 1, 0, 0],
        [0, 0, 1, 1, 1, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
    ]
    # Frame 1: rotated slightly
    ball_1 = [
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 1, 1, 1, 0, 0, 0],
        [0, 1, 1, 2, 2, 1, 0, 0],
        [0, 1, 1, 1, 2, 1, 0, 0],
        [0, 1, 1, 1, 1, 1, 0, 0],
        [0, 0, 1, 1, 1, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
    ]
    # Frame 2: rotated more
    ball_2 = [
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 1, 1, 1, 0, 0, 0],
        [0, 1, 1, 1, 1, 1, 0, 0],
        [0, 1, 2, 1, 1, 1, 0, 0],
        [0, 1, 2, 2, 1, 1, 0, 0],
        [0, 0, 1, 1, 1, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
    ]

    color_map = {
        0: (0, 0, 0, 0),          # transparent
        1: (255, 255, 255, 255),   # white
        2: (200, 200, 200, 255),   # light gray (panel line)
    }

    for frame_idx, frame_data in enumerate([ball_0, ball_1, ball_2]):
        for y, row in enumerate(frame_data):
            for x, val in enumerate(row):
                r, g, b, a = color_map[val]
                sheet[y, frame_idx * cell_size + x] = [r, g, b, a]

    # Shadow frame (frame 3): small dark ellipse
    shadow = [
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 1, 1, 1, 1, 0, 0],
        [0, 1, 1, 1, 1, 1, 1, 0],
        [0, 0, 1, 1, 1, 1, 0, 0],
    ]
    for y, row in enumerate(shadow):
        for x, val in enumerate(row):
            if val == 1:
                sheet[y, 3 * cell_size + x] = [0, 0, 0, 128]

    return Image.fromarray(sheet, "RGBA")


def create_ball_shadow():
    """Create a separate ball shadow sprite."""
    size = 8
    shadow = np.zeros((size, size, 4), dtype=np.uint8)
    # Elliptical shadow
    pixels = [
        (2, 5), (3, 5), (4, 5), (5, 5),
        (1, 6), (2, 6), (3, 6), (4, 6), (5, 6), (6, 6),
        (2, 7), (3, 7), (4, 7), (5, 7),
    ]
    for x, y in pixels:
        shadow[y, x] = [0, 0, 0, 128]
    return Image.fromarray(shadow, "RGBA")


def create_goal_sprites():
    """Create left and right goal sprites.

    Goals are vertical (posts top/bottom, net extending behind goal line).
    Goal mouth spans 48px vertically, depth ~6px.
    Returns (left_goal, right_goal) as PIL Images.
    """
    w, h = 12, 52
    goal = np.zeros((h, w, 4), dtype=np.uint8)

    post_color = [255, 255, 255, 255]
    net_color = [180, 180, 180, 80]

    # Back bar at x=6
    for y in range(2, h - 2):
        goal[y, 6] = post_color

    # Top post (horizontal)
    for x in range(0, 7):
        goal[2, x] = post_color

    # Bottom post (horizontal)
    for x in range(0, 7):
        goal[h - 3, x] = post_color

    # Net pattern
    for y in range(3, h - 3):
        for x in range(0, 6):
            if (x + y) % 3 == 0:
                goal[y, x] = net_color

    left_img = Image.fromarray(goal, "RGBA")
    right_img = left_img.transpose(Image.FLIP_LEFT_RIGHT)
    return left_img, right_img


def create_pitch_background():
    """Create a horizontal pitch background with markings.

    Goals are at left (x=0) and right (x=320) edges.
    Viewport: 320x240.
    """
    import math

    w, h = 320, 240

    pitch = np.zeros((h, w, 4), dtype=np.uint8)
    stripe_w = 20  # vertical stripes for horizontal pitch
    for x in range(w):
        stripe = (x // stripe_w) % 2
        if stripe == 0:
            pitch[:, x] = [51, 102, 0, 255]
        else:
            pitch[:, x] = [58, 115, 0, 255]

    line_color = [255, 255, 255, 255]
    margin_x, margin_y = 8, 8
    px1, py1 = margin_x, margin_y
    px2, py2 = w - margin_x - 1, h - margin_y - 1

    # Boundary lines
    for x in range(px1, px2 + 1):
        pitch[py1, x] = line_color
        pitch[py2, x] = line_color
    for y in range(py1, py2 + 1):
        pitch[y, px1] = line_color
        pitch[y, px2] = line_color

    # Halfway line (vertical, center)
    cx = w // 2
    cy = h // 2
    for y in range(py1, py2 + 1):
        pitch[y, cx] = line_color

    # Center circle (radius ~24px)
    radius = 24
    for angle_deg in range(360):
        rad = math.radians(angle_deg)
        dx = int(round(radius * math.cos(rad)))
        dy = int(round(radius * math.sin(rad)))
        px, py = cx + dx, cy + dy
        if 0 <= px < w and 0 <= py < h:
            pitch[py, px] = line_color

    # Center spot
    for dy in range(-1, 2):
        for dx in range(-1, 2):
            if abs(dx) + abs(dy) <= 1:
                pitch[cy + dy, cx + dx] = line_color

    # Penalty areas (left and right)
    pa_h = 100
    pa_w = 48
    pa_top = cy - pa_h // 2
    pa_bottom = cy + pa_h // 2

    for goal_x, direction in [(px1, 1), (px2, -1)]:
        pa_x_end = goal_x + direction * pa_w
        for x in range(min(goal_x, pa_x_end), max(goal_x, pa_x_end) + 1):
            pitch[pa_top, x] = line_color
            pitch[pa_bottom, x] = line_color
        for y in range(pa_top, pa_bottom + 1):
            pitch[y, pa_x_end] = line_color

        # Goal area (6-yard box)
        ga_h = 48
        ga_w = 20
        ga_top = cy - ga_h // 2
        ga_bottom = cy + ga_h // 2
        ga_x_end = goal_x + direction * ga_w
        for x in range(min(goal_x, ga_x_end), max(goal_x, ga_x_end) + 1):
            pitch[ga_top, x] = line_color
            pitch[ga_bottom, x] = line_color
        for y in range(ga_top, ga_bottom + 1):
            pitch[y, ga_x_end] = line_color

        # Penalty spot
        spot_x = goal_x + direction * 36
        for dy in range(-1, 2):
            for dx in range(-1, 2):
                if abs(dx) + abs(dy) <= 1:
                    pitch[cy + dy, spot_x + dx] = line_color

    return Image.fromarray(pitch, "RGBA")


def extract_and_pack_team(filename, output_name, cell_w=16, cell_h=32, cols=10):
    """Extract sprites from a team sheet and pack into a grid sprite sheet."""
    print(f"  {filename}:")
    sprites, img = extract_player_sprites_semantic(filename)
    print(f"    Total: {len(sprites)} sprites mapped")

    sheet = pack_sprites_to_sheet(img, sprites, cell_w, cell_h, cols)
    output_path = os.path.join(PLAYERS_DIR, output_name)
    sheet.save(output_path)
    print(f"  → Saved {output_path} ({sheet.size[0]}x{sheet.size[1]})")
    return sprites


def main():
    # Ensure output directories exist
    for d in [PLAYERS_DIR, BALL_DIR, PITCH_DIR]:
        os.makedirs(d, exist_ok=True)

    print("=== Extracting player sprites ===")
    cell_w, cell_h = 16, 32
    cols = 10

    extract_and_pack_team(
        "cjcteam1.png", "player_solid.png", cell_w, cell_h, cols
    )
    extract_and_pack_team(
        "cjcteam2.png", "player_vstripes.png", cell_w, cell_h, cols
    )
    extract_and_pack_team(
        "cjcteam3.png", "player_hstripes.png", cell_w, cell_h, cols
    )

    # Write sprite layout documentation
    write_layout_docs()

    print("\n=== Done! ===")


def write_layout_docs():
    """Write sprite sheet layout documentation."""
    doc_path = os.path.join(PROJECT_ROOT, "sprites", "SPRITE_LAYOUT.md")
    with open(doc_path, "w") as f:
        f.write("""# Sprite Sheet Layout Documentation

## Source Files

Original sprites from `sprites/original/` (Codetapper Amiga rips).
**Copyright:** These are copyrighted Sensible Soccer sprites. For development/prototyping only.

## Original Layout (cjcteam1/2/3.png, 320x256)

The first 32px band (y=0-31) contains TWO rows of sprites stacked vertically
with a 1-2px gap between them. Each 16px column holds one sprite per row.

**Row 1 (top half, y~0-15) — Cardinal directions + slides (20 columns):**
FN N1 N2 | FS S1 S2 | FE E1 E2 | FW W1 W2 | SlideN SlideS SlideW SlideE SlideSW SlideSE SlideNW SlideNE

**Row 2 (bottom half, y~16-31) — Diagonal directions + down (20 columns):**
FSW SW1 SW2 | FSE SE1 SE2 | FNW NW1 NW2 | FNE NE1 NE2 | DownN DownS DownW DownE DownSW DownSE DownNW DownNE

Mirror directions: W=flip(E), NW=flip(NE), SW=flip(SE).

## Packed Sprite Sheet Layout

Cell size: 16x32 pixels, 10 columns per row.
5 base directions: S, SE, E, NE, N.

| Cells | Content | Direction order |
|-------|---------|-----------------|
| 0-9 | Running (2 frames each) | S, SE, E, NE, N |
| 10-14 | Idle/facing (1 frame each) | S, SE, E, NE, N |
| 15-19 | Kick (= idle, 1 frame each) | S, SE, E, NE, N |
| 20-27 | Slide (1 frame each) | S, SE, E, NE, N, W, SW, NW |
| 28-35 | Down/knocked (1 frame each) | N, S, SE, NE, E, W, SW, NW |
| 36-56 | Heading (3 frames each) | S, E, W, SW, SE, NW, NE |
| 57-77 | Throw-in (3 frames each) | S, E, W, SW, SE, NW, NE |

## ANIM_MAP Reference

```
"run_s": [0,1], "run_se": [2,3], "run_e": [4,5], "run_ne": [6,7], "run_n": [8,9]
"idle_s": [10], "idle_se": [11], "idle_e": [12], "idle_ne": [13], "idle_n": [14]
"kick_s": [15], "kick_se": [16], "kick_e": [17], "kick_ne": [18], "kick_n": [19]
"slide_s": [20], "slide_se": [21], "slide_e": [22], "slide_ne": [23], "slide_n": [24]
"knocked_down": [28], "getting_up": [28, 29], "celebrate": [10, 14, 12]
"head_s": [36,37,38], "head_e": [39,40,41], "head_w": [42,43,44]
"head_sw": [45,46,47], "head_se": [48,49,50], "head_nw": [51,52,53], "head_ne": [54,55,56]
"throwin_s": [57,58,59], "throwin_e": [60,61,62], "throwin_w": [63,64,65]
"throwin_sw": [66,67,68], "throwin_se": [69,70,71], "throwin_nw": [72,73,74], "throwin_ne": [75,76,77]
```

## Throw-in Ball Visibility

For throw-in animations, the ball should be hidden on frames 1-2 and visible on frame 3 (index 2).
The ball sprite in frame 3 is baked into the player sprite — at runtime, the real ball entity
should be positioned at release on frame 3 and hidden during frames 1-2.

## Kit Variants

- `player_solid.png` — Solid color kit (from `cjcteam1.png`)
- `player_vstripes.png` — Vertical stripes (from `cjcteam2.png`)
- `player_hstripes.png` — Horizontal stripes (from `cjcteam3.png`)

Kit colors A (#FF0000) and B (#0000FF) are replaced by the palette swap shader at runtime.
""")
    print(f"  → Saved {doc_path}")


if __name__ == "__main__":
    main()
