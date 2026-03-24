# Sprite Sheet Layout Documentation

## Source Files

Original sprites from `sprites/original/` (Codetapper Amiga rips).
**Copyright:** These are copyrighted Sensible Soccer sprites. For development/prototyping only.

## Player Palette (16 colors)

| Index | Hex | Role | Swappable |
|-------|-----|------|-----------|
|  0 | #336600 | Background (grass) | No |
|  1 | #999999 | Gray | No |
|  2 | #FFFFFF | White (socks/highlights) | Yes |
|  3 | #000000 | Black (boots/outlines) | No |
|  4 | #772211 | Dark skin tone | No |
|  5 | #AA4400 | Medium skin tone | No |
|  6 | #FF7711 | Light skin tone | No |
|  7 | #225500 | Dark green (unused) | No |
|  8 | #003300 | Shadow on grass | No |
|  9 | #CC8800 | Hair (golden) | Yes |
| 10 | #FF0000 | **Kit color A** (red) | Yes |
| 11 | #0000FF | **Kit color B** (blue) | Yes |
| 12 | #884400 | Dark brown (hair) | Yes |
| 13 | #FFBB00 | Amber (hair variant) | Yes |
| 14 | #00DD00 | Anti-alias green | No |
| 15 | #FFFF00 | Yellow | No |

## Kit Variants

Three sprite sheets with identical layouts but different pixel patterns:

- `player_solid.png` — Solid color kit (from `cjcteam1.png`)
- `player_vstripes.png` — Vertical stripes (from `cjcteam2.png`)
- `player_hstripes.png` — Horizontal stripes (from `cjcteam3.png`)
- `goalkeeper.png` — Goalkeeper sprites (from `cjcteamg1.png`)

Kit colors A (#FF0000) and B (#0000FF) are swapped between variants to create stripe patterns. The palette swap shader replaces these marker colors with team-specific colors at runtime.

## Player Sprite Sheet Layout

Cell size: 16×32 pixels, 10 columns per row.

Sprites are extracted in reading order from the original sheets. The original Amiga
layout organizes sprites as:

- **Row 0 (cells 0-19):** Upright sprites — running and kicking in multiple directions
  (with ground shadows included in the sprite). Cells 0-13 are standard running/standing
  poses (~12px wide). Cells 14-19 are wider kick/header poses (~14-15px wide).
- **Rows 2-8 (cells 20-71):** Slide tackle and ground-level sprites, organized by
  direction. Each band of 6 sprites covers one direction with 3 slide frames (left group)
  and 3 recovering/getting-up frames (right group). Band 1 also has 4 extra small frames
  (cells 26-29) which appear to be celebration/knocked-down sprites.

### Band layout (rows 2-8, 8 directions)

| Band | Cells | Direction | Left group (3) | Right group (3) |
|------|-------|-----------|----------------|-----------------|
| 1 | 20-29 | S (facing down) | Slide frames | Recover + extras |
| 2 | 30-35 | SE | Slide frames | Recover frames |
| 3 | 36-41 | E (facing right) | Slide frames | Recover frames |
| 4 | 42-47 | NE | Slide frames | Recover frames |
| 5 | 48-53 | N (facing up) | Slide frames | Recover frames |
| 6 | 54-59 | NW (mirror of NE) | Slide frames | Recover frames |
| 7 | 60-65 | W (mirror of E) | Slide frames | Recover frames |
| 8 | 66-71 | SW (mirror of SE) | Slide frames | Recover frames |

> **Note:** SW/W/NW directions are stored explicitly in the original sheets but
> can also be generated at runtime by mirroring SE/E/NE with `flip_h = true`.

### Player shadow

`player_shadow.png` — Separate 16×8 semi-transparent ellipse for rendering
under each player independently of the sprite frame.

## Ball Sprites

`ball/ball.png` — 4 cells of 8×8:
- Cell 0-2: Ball rotation frames (white with panel lines)
- Cell 3: Ball shadow (semi-transparent ellipse)

`ball/ball_shadow.png` — Single 8×8 shadow sprite.

## Pitch

`pitch/pitch.png` — 320×480 full pitch with markings, two-tone grass stripes, penalty areas, center circle.

`pitch/goal_net.png` — 32×40 goal with white posts and semi-transparent net pattern.

## Palette Swap Shader

The shader should replace these marker colors:

| Marker Color | Hex | Shader Uniform |
|-------------|-----|----------------|
| Kit A (red) | #FF0000 | `kit_primary` |
| Kit B (blue) | #0000FF | `kit_secondary` |
| White | #FFFFFF | `socks_color` |
| Golden | #CC8800 | `hair_color` |
