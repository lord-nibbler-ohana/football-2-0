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

Sprites are extracted in reading order (top-to-bottom, left-to-right) from the original sheets.

| Cell | Source Position | Size | Notes |
|------|----------------|------|-------|
|  0 | (0,0) | 12×31 | top |
|  1 | (16,0) | 13×31 | top |
|  2 | (32,0) | 11×31 | top |
|  3 | (48,0) | 12×31 | top |
|  4 | (64,0) | 11×31 | top |
|  5 | (80,0) | 12×31 | top |
|  6 | (96,0) | 10×31 | top |
|  7 | (112,0) | 11×31 | top |
|  8 | (128,0) | 10×31 | top |
|  9 | (144,0) | 11×31 | top |
| 10 | (160,0) | 9×31 | top |
| 11 | (176,0) | 11×31 | top |
| 12 | (192,0) | 10×31 | top |
| 13 | (208,0) | 12×31 | top |
| 14 | (224,0) | 15×25 | top |
| 15 | (240,0) | 15×26 | top |
| 16 | (256,0) | 14×28 | top |
| 17 | (272,0) | 14×29 | top |
| 18 | (288,0) | 14×29 | top |
| 19 | (304,0) | 14×28 | top |
| 20 | (0,32) | 15×15 | band1 |
| 21 | (16,32) | 15×17 | band1 |
| 22 | (32,32) | 16×18 | band1 |
| 23 | (64,32) | 11×18 | band1 |
| 24 | (80,32) | 11×19 | band1 |
| 25 | (96,32) | 11×15 | band1 |
| 26 | (112,32) | 12×12 | band1 |
| 27 | (128,32) | 13×12 | band1 |
| 28 | (144,32) | 12×12 | band1 |
| 29 | (160,32) | 13×12 | band1 |
| 30 | (0,56) | 15×15 | band2 |
| 31 | (16,56) | 15×17 | band2 |
| 32 | (32,56) | 16×18 | band2 |
| 33 | (64,56) | 11×18 | band2 |
| 34 | (80,56) | 11×19 | band2 |
| 35 | (96,56) | 11×14 | band2 |
| 36 | (0,80) | 9×16 | band3 |
| 37 | (16,80) | 11×18 | band3 |
| 38 | (32,80) | 14×19 | band3 |
| 39 | (64,80) | 10×18 | band3 |
| 40 | (80,80) | 9×19 | band3 |
| 41 | (96,80) | 8×15 | band3 |
| 42 | (0,104) | 10×16 | band4 |
| 43 | (16,104) | 11×18 | band4 |
| 44 | (32,104) | 15×19 | band4 |
| 45 | (64,104) | 9×18 | band4 |
| 46 | (80,104) | 10×19 | band4 |
| 47 | (96,104) | 11×15 | band4 |
| 48 | (0,128) | 11×16 | band5 |
| 49 | (16,128) | 13×18 | band5 |
| 50 | (32,128) | 16×19 | band5 |
| 51 | (64,128) | 8×18 | band5 |
| 52 | (80,128) | 9×19 | band5 |
| 53 | (96,128) | 11×15 | band5 |
| 54 | (0,152) | 12×16 | band6 |
| 55 | (16,152) | 14×18 | band6 |
| 56 | (32,152) | 16×19 | band6 |
| 57 | (64,152) | 10×18 | band6 |
| 58 | (80,152) | 9×19 | band6 |
| 59 | (96,152) | 8×15 | band6 |
| 60 | (0,176) | 11×16 | band7 |
| 61 | (16,176) | 13×18 | band7 |
| 62 | (32,176) | 16×19 | band7 |
| 63 | (64,176) | 8×18 | band7 |
| 64 | (80,176) | 9×19 | band7 |
| 65 | (96,176) | 11×15 | band7 |
| 66 | (0,200) | 12×16 | band8 |
| 67 | (16,200) | 14×18 | band8 |
| 68 | (32,200) | 16×19 | band8 |
| 69 | (64,200) | 10×18 | band8 |
| 70 | (80,200) | 9×19 | band8 |
| 71 | (96,200) | 8×15 | band8 |

## Ball Sprites

`ball/ball.png` — 4 cells of 8×8:
- Cell 0-2: Ball rotation frames (white with panel lines)
- Cell 3: Ball shadow (semi-transparent ellipse)

`ball/ball_shadow.png` — Single 8×8 shadow sprite.

## Pitch

`pitch/pitch.png` — 320×240 horizontal pitch with goals on left/right edges,
two-tone grass stripes, penalty areas, 6-yard boxes, center circle, penalty spots.

`pitch/goal_left.png` — 12×52 left goal (posts + semi-transparent net, extending left).
`pitch/goal_right.png` — 12×52 right goal (mirrored).

## Palette Swap Shader

The shader should replace these marker colors:

| Marker Color | Hex | Shader Uniform |
|-------------|-----|----------------|
| Kit A (red) | #FF0000 | `kit_primary` |
| Kit B (blue) | #0000FF | `kit_secondary` |
| White | #FFFFFF | `socks_color` |
| Golden | #CC8800 | `hair_color` |
