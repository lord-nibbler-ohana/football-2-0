# Sprite Sheet Layout Documentation

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
- `goalkeeper.png` — Goalkeeper (from `cjcteamg1.png`, single variant)

Kit colors A (#FF0000) and B (#0000FF) are replaced by the palette swap shader at runtime.

## Goalkeeper Sprite Sheet (`goalkeeper.png`, 160×224)

Cell size: 16x32 pixels, 10 columns per row.
Cells 0-35 are identical to outfield players. Cells 36-65 contain GK-specific animations
(no heading or throw-in for GKs).

| Cells | Content | Details |
|-------|---------|---------|
| 0-35 | Standard (run, idle, kick, slide, knocked) | Same as outfield |
| 36-38 | GK catch facing N | 3 frames |
| 39-41 | GK catch facing S | 3 frames |
| 42-47 | GK dive E facing S | 6 frames |
| 48-53 | GK dive W facing S | 6 frames (reversed from original) |
| 54-59 | GK dive E facing N | 6 frames |
| 60-65 | GK dive W facing N | 6 frames (reversed from original) |

### GK ANIM_MAP Reference

```
"gk_catch_n": [36,37,38], "gk_catch_s": [39,40,41]
"gk_dive_e_s": [42,43,44,45,46,47], "gk_dive_w_s": [48,49,50,51,52,53]
"gk_dive_e_n": [54,55,56,57,58,59], "gk_dive_w_n": [60,61,62,63,64,65]
```

### Original GK Sheet Layout (cjcteamg1.png, 320×256)

- Rows 1-2 (y=0-31): Standard outfield sprites
- Row 3 (y=32): Jump/catch N — 3 frames in cols 0-2
- Row 4 (y=56): Jump/catch S — 3 frames in cols 0-2
- Row 5 (y=78): Dive E facing S — 6 frames in cols 0-5
- Row 6 (y=104): Dive W facing S — 6 frames in cols 5-0 (right-to-left)
- Row 7 (y=126): Dive E facing N — 6 frames in cols 0-5
- Row 8 (y=152): Dive W facing N — 6 frames in cols 5-0 (right-to-left)
