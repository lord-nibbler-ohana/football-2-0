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


def extract_player_sprites(filename):
    """Extract all player sprites from a team sprite sheet.

    Returns a list of (x, y, w, h) bounding boxes for each sprite found.
    """
    img = Image.open(os.path.join(ORIGINAL_DIR, filename))
    data = np.array(img)

    all_sprites = []

    # Band 0 (y=0-30): Upright sprites (running, standing, kicking)
    # These are in 16px-wide columns
    sprites_band0 = find_sprites_in_region(data, 0, 0, 320, 31, BG_INDEX)
    all_sprites.extend(sprites_band0)

    # Bands 1-8 (y=32,56,80,...,200): Direction-specific sprites
    # Each at 24px intervals, ~19px tall
    for band_idx in range(8):
        y_start = 32 + band_idx * 24
        band_sprites = find_sprites_in_region(data, 0, y_start, 320, 19, BG_INDEX)
        all_sprites.extend(band_sprites)

    return all_sprites, img


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
    sprites, img = extract_player_sprites(filename)
    print(f"  {filename}: found {len(sprites)} sprites")

    # Sort sprites: by y first, then x (reading order)
    sprites.sort(key=lambda s: (s[1], s[0]))

    for i, (x, y, w, h) in enumerate(sprites):
        print(f"    [{i:2d}] x={x:3d} y={y:3d} w={w:2d} h={h:2d}")

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

    sprites_solid = extract_and_pack_team(
        "cjcteam1.png", "player_solid.png", cell_w, cell_h, cols
    )
    extract_and_pack_team(
        "cjcteam2.png", "player_vstripes.png", cell_w, cell_h, cols
    )
    extract_and_pack_team(
        "cjcteam3.png", "player_hstripes.png", cell_w, cell_h, cols
    )
    # Goalkeeper needs wider cells for diving sprites (up to 63px wide)
    extract_and_pack_team(
        "cjcteamg1.png", "goalkeeper.png", 32, 32, 8
    )

    print("\n=== Creating ball sprites ===")
    ball_sheet = create_ball_sprites()
    ball_path = os.path.join(BALL_DIR, "ball.png")
    ball_sheet.save(ball_path)
    print(f"  → Saved {ball_path} ({ball_sheet.size[0]}x{ball_sheet.size[1]})")

    ball_shadow = create_ball_shadow()
    shadow_path = os.path.join(BALL_DIR, "ball_shadow.png")
    ball_shadow.save(shadow_path)
    print(f"  → Saved {shadow_path} ({ball_shadow.size[0]}x{ball_shadow.size[1]})")

    print("\n=== Creating goal sprites ===")
    goal_left, goal_right = create_goal_sprites()
    goal_left_path = os.path.join(PITCH_DIR, "goal_left.png")
    goal_right_path = os.path.join(PITCH_DIR, "goal_right.png")
    goal_left.save(goal_left_path)
    goal_right.save(goal_right_path)
    print(f"  → Saved {goal_left_path} ({goal_left.size[0]}x{goal_left.size[1]})")
    print(f"  → Saved {goal_right_path} ({goal_right.size[0]}x{goal_right.size[1]})")

    print("\n=== Creating pitch background ===")
    pitch = create_pitch_background()
    pitch_path = os.path.join(PITCH_DIR, "pitch.png")
    pitch.save(pitch_path)
    print(f"  → Saved {pitch_path} ({pitch.size[0]}x{pitch.size[1]})")

    # Write sprite layout documentation
    write_layout_docs(sprites_solid)

    print("\n=== Done! ===")


def write_layout_docs(sprites):
    """Write sprite sheet layout documentation."""
    doc_path = os.path.join(PROJECT_ROOT, "sprites", "SPRITE_LAYOUT.md")
    with open(doc_path, "w") as f:
        f.write("# Sprite Sheet Layout Documentation\n\n")
        f.write("## Source Files\n\n")
        f.write("Original sprites from `sprites/original/` (Codetapper Amiga rips).\n")
        f.write("**Copyright:** These are copyrighted Sensible Soccer sprites. ")
        f.write("For development/prototyping only.\n\n")

        f.write("## Player Palette (16 colors)\n\n")
        f.write("| Index | Hex | Role | Swappable |\n")
        f.write("|-------|-----|------|-----------|\n")
        palette_roles = {
            0: ("Background (grass)", False),
            1: ("Gray", False),
            2: ("White (socks/highlights)", True),
            3: ("Black (boots/outlines)", False),
            4: ("Dark skin tone", False),
            5: ("Medium skin tone", False),
            6: ("Light skin tone", False),
            7: ("Dark green (unused)", False),
            8: ("Shadow on grass", False),
            9: ("Hair (golden)", True),
            10: ("**Kit color A** (red)", True),
            11: ("**Kit color B** (blue)", True),
            12: ("Dark brown (hair)", True),
            13: ("Amber (hair variant)", True),
            14: ("Anti-alias green", False),
            15: ("Yellow", False),
        }
        for idx, (role, swap) in palette_roles.items():
            r, g, b = PLAYER_PALETTE[idx]
            f.write(f"| {idx:2d} | #{r:02X}{g:02X}{b:02X} | {role} | "
                    f"{'Yes' if swap else 'No'} |\n")

        f.write("\n## Kit Variants\n\n")
        f.write("Three sprite sheets with identical layouts but different pixel patterns:\n\n")
        f.write("- `player_solid.png` — Solid color kit (from `cjcteam1.png`)\n")
        f.write("- `player_vstripes.png` — Vertical stripes (from `cjcteam2.png`)\n")
        f.write("- `player_hstripes.png` — Horizontal stripes (from `cjcteam3.png`)\n")
        f.write("- `goalkeeper.png` — Goalkeeper sprites (from `cjcteamg1.png`)\n\n")
        f.write("Kit colors A (#FF0000) and B (#0000FF) are swapped between variants ")
        f.write("to create stripe patterns. The palette swap shader replaces these ")
        f.write("marker colors with team-specific colors at runtime.\n\n")

        f.write("## Player Sprite Sheet Layout\n\n")
        f.write(f"Cell size: 16×32 pixels, 10 columns per row.\n\n")
        f.write("Sprites are extracted in reading order (top-to-bottom, left-to-right) ")
        f.write("from the original sheets.\n\n")
        f.write("| Cell | Source Position | Size | Notes |\n")
        f.write("|------|----------------|------|-------|\n")
        for i, (x, y, w, h) in enumerate(sprites):
            band = "top" if y < 31 else f"band{(y - 32) // 24 + 1}"
            f.write(f"| {i:2d} | ({x},{y}) | {w}×{h} | {band} |\n")

        f.write("\n## Ball Sprites\n\n")
        f.write("`ball/ball.png` — 4 cells of 8×8:\n")
        f.write("- Cell 0-2: Ball rotation frames (white with panel lines)\n")
        f.write("- Cell 3: Ball shadow (semi-transparent ellipse)\n\n")
        f.write("`ball/ball_shadow.png` — Single 8×8 shadow sprite.\n\n")

        f.write("## Pitch\n\n")
        f.write("`pitch/pitch.png` — 320×480 full pitch with markings, ")
        f.write("two-tone grass stripes, penalty areas, center circle.\n\n")
        f.write("`pitch/goal_net.png` — 32×40 goal with white posts and ")
        f.write("semi-transparent net pattern.\n\n")

        f.write("## Palette Swap Shader\n\n")
        f.write("The shader should replace these marker colors:\n\n")
        f.write("| Marker Color | Hex | Shader Uniform |\n")
        f.write("|-------------|-----|----------------|\n")
        f.write("| Kit A (red) | #FF0000 | `kit_primary` |\n")
        f.write("| Kit B (blue) | #0000FF | `kit_secondary` |\n")
        f.write("| White | #FFFFFF | `socks_color` |\n")
        f.write("| Golden | #CC8800 | `hair_color` |\n")

    print(f"  → Saved {doc_path}")


if __name__ == "__main__":
    main()
