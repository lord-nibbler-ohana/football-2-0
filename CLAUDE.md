# Football 2.0 — Claude Code Instructions

## Project Overview

Football 2.0 is a Godot 4.x game (GDScript) recreating Sensible Soccer's core mechanics with expansion features (multiball, double corner, exploding grenade ball). Two-player local multiplayer using dual arcade sticks (Xbox controllers).

**Repo:** lord-nibbler-ohana/football-2-0
**Project board:** https://github.com/users/lord-nibbler-ohana/projects/2

## Engine & Runtime

- **Engine:** Godot 4.x (GDScript)
- **Binary:** `godot` on PATH (or set `GODOT_PATH` env var)
- **Physics tick rate:** 50 Hz (PAL Amiga framerate — all physics constants are tuned for this)
- **Viewport:** 320×240, window 1280×960, stretch mode "viewport", texture filter NEAREST
- **Testing:** GUT (addons/gut/) — headless CLI test runner
- **Linting:** gdtoolkit (`gdformat`, `gdlint`) — installed via pip

## Project Structure

```
football-2-0/
├── project.godot
├── CLAUDE.md
├── README.md
├── .gutconfig.json
├── scenes/
│   ├── main.tscn              # Match orchestrator
│   ├── pitch.tscn             # Football pitch
│   ├── player.tscn            # Single player (instanced ×22)
│   ├── ball.tscn              # Ball + shadow
│   ├── goal.tscn              # Goal with collision
│   └── ui/                    # Scoreboard, radar, effects bar
├── scripts/
│   ├── match.gd               # Game state, referee, clock
│   ├── team.gd                # Team logic, formation, switching
│   ├── player_controller.gd   # Human input → player actions
│   ├── player_ai.gd           # AI box positioning + decisions
│   ├── ball.gd                # Physics, aftertouch, passthrough
│   ├── ball_manager.gd        # Multi-ball ownership (expansion)
│   ├── possession.gd          # Central possession authority
│   ├── aftertouch.gd          # Aftertouch state machine
│   ├── input_mapper.gd        # Dual controller, 8-way quantisation
│   ├── formation.gd           # Box grid + tactical positions
│   ├── *_pure.gd              # Pure logic classes (no Node deps)
│   └── expansion/
│       ├── multiball.gd
│       ├── double_corner.gd
│       ├── grenade_ball.gd
│       └── powerup_spawner.gd
├── sprites/
│   ├── players/               # 3-frame anims, palette-swappable
│   ├── ball/                  # Ball + shadow + grenade variant
│   ├── pitch/                 # Pitch texture
│   └── ui/                    # Scoreboard, selection arrow, powerup icons
├── shaders/
│   └── palette_swap.gdshader  # Kit colour swapping
├── resources/
│   ├── teams.tres             # Team data (names, kits, stats)
│   └── formations.tres        # Formation definitions
├── tests/                     # GUT test files
│   ├── test_ball_physics.gd
│   ├── test_aftertouch.gd
│   ├── test_pass_targeting.gd
│   ├── test_possession.gd
│   ├── test_goal_detection.gd
│   └── test_grenade.gd
└── addons/
    └── gut/                   # GUT testing framework
```

## Architecture Principles

- **CharacterBody2D** for ball and players (NOT RigidBody2D) — direct velocity assignment, no physics simulation
- **Pure logic pattern:** game logic in `*_pure.gd` classes with no Node/scene tree dependencies; node scripts delegate to pure classes. This enables headless testing.
- **Players do NOT collide with each other** — faithful to original Sensible Soccer
- **Implicit possession** — no player "picks up" the ball; proximity-based every frame
- **8-way digital input** — analog stick quantised to 8 cardinal/diagonal directions
- **Single fire button** — context-sensitive: tap=pass, hold=shot, defense=tackle/switch

## Key Constants (do not change without understanding impact)

```
Physics tick:           50 Hz (PAL)
Ground friction:        0.98 per frame
Air friction:           0.99 per frame
Gravity:                0.4 px/frame²
Bounce damping:         0.5
Aftertouch window:      12 frames (open play), 18 frames (set pieces)
Aftertouch decay:       0.85 per frame
Aim assist angle:       15°
Pass cone half-angle:   30°
Pickup radius:          10px
Dribble radius:         14px
Tackle range:           24px
```

## Collision Layers

```
Layer 1: pitch_boundary / goalposts (StaticBody2D)
Layer 2: ball (CharacterBody2D)
Layer 3: players (CharacterBody2D)
Layer 4: goals (Area2D)
Layer 5: boundaries (Area2D)
Layer 6: tackle_hitbox (Area2D, toggled)
Layer 7: pickup_zone (Area2D)
```

## Validating Changes

### Syntax check (single file)
```bash
godot --path . --check-only --script scripts/ball.gd
```

### Syntax check (all files)
```bash
find . -name "*.gd" -not -path "./addons/*" -exec godot --path . --check-only --script {} \; 2>&1
```

### Lint
```bash
pip install gdtoolkit
gdformat --check scripts/
gdlint scripts/
```

## Running Tests

### First-time import (run once, or after adding new resources)
```bash
godot --headless --path . --import --quit
```

### Run all tests
```bash
godot --headless --path . -d -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests -ginclude_subdirs -glog=2 -gexit
```
Exit code: 0 = all pass, non-zero = failures.

### Run a specific test file
```bash
godot --headless --path . -d -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/test_ball_physics.gd -gexit
```

## Do NOT

- Modify `.godot/` or `.import/` directories
- Use RigidBody2D for ball or players
- Change physics tick rate from 50 Hz
- Add player-vs-player collision
- Commit `test_screenshots/` to git
- Use `await` in pure logic classes
- Smooth/filter textures (must stay NEAREST for pixel art)

## Issue Labels

| Label | Meaning |
|-------|---------|
| `core` | Project foundation / setup |
| `gameplay` | Core gameplay mechanics |
| `physics` | Ball and player physics |
| `ai` | AI positioning and decisions |
| `input` | Controller and input handling |
| `visual` | Sprites, animations, camera |
| `expansion` | Football 2.0 features (multiball, grenade, double corner) |
| `testing` | Testing infrastructure |
| `set-pieces` | Corners, free kicks, throw-ins |
