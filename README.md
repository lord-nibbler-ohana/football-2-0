# Football 2.0

A retro football game built in **Godot 4** that recreates the core mechanics of Sensible Soccer — then adds chaos.

Two players. Two arcade sticks. One fire button each. Aftertouch on every kick. And occasionally, an exploding ball.

## What is this?

Football 2.0 takes the tight, responsive gameplay of Sensible Soccer (1992) — the aftertouch system, invisible aim assist, box-based AI positioning, and 3-frame pixel art — and layers on expansion modes that turn a football match into controlled mayhem:

- **Multiball** — Extra balls spawn on the pitch. Every ball can score. Chaos ensues.
- **Double Corner** — Both teams take corner kicks simultaneously from opposite ends. Attack and defend at the same time.
- **Exploding Grenade Ball** — The ball becomes a ticking bomb. Whoever holds it when it explodes concedes a goal. Possession becomes a liability.

## Core Mechanics (from Sensible Soccer)

| Mechanic | How it works |
|----------|-------------|
| **Aftertouch** | After any kick, joystick input curls, lofts, or dips the ball. Strength decays over 12 frames — the sooner you input, the more dramatic the effect. |
| **One-button controls** | Tap fire = auto-targeted pass. Hold fire = power shot. On defense: fire near ball = tackle, fire far = switch player. |
| **Invisible aim assist** | A hidden 15° correction steers players toward the ball. You think you're in full control. You're not. And that's why it feels good. |
| **Box-based AI** | Each AI player has a zone on a 7×5 pitch grid. Position within the zone shifts based on ball location and possession state. |
| **Implicit possession** | No one "picks up" the ball. Proximity determines control every frame. The ball is tethered to feet, not glued. |
| **50 Hz physics** | Locked to PAL Amiga framerate. All constants (friction 0.98, aftertouch decay 0.85) are tuned for exactly 50 ticks/sec. |

## Controls

```
8-way joystick    Move player
Tap fire          Pass (auto-targeted to nearest teammate in cone)
Hold fire         Power shot in joystick direction (power scales with hold time)
After kick        Joystick = aftertouch (curl / loft / dip)
Defense + fire    Tackle (near ball) or switch player (far from ball)
```

Designed for dual arcade sticks presenting as Xbox controllers. Keyboard fallback for development.

## Tech Stack

- **Engine:** Godot 4.x
- **Language:** GDScript
- **Resolution:** 320×240 viewport, 4× integer scaled to 1280×960
- **Rendering:** Pixel-perfect, NEAREST filtering, no smoothing
- **Testing:** GUT (Godot Unit Test) with pure logic classes for headless testing

## Project Status

Active development. Tracking progress on the [project board](https://github.com/users/lord-nibbler-ohana/projects/2).

### Milestones

**Foundation**
- [ ] Godot 4 project setup with correct architecture (#1)
- [ ] Ball physics — friction, gravity, bounce, 3D height (#2)
- [ ] Dual arcade stick input with 8-way quantisation (#4)
- [ ] Testing infrastructure with GUT (#16)

**Core Gameplay**
- [ ] Aftertouch — curl, loft, dip (#3)
- [ ] Offense controls — pass/shot state machine (#5)
- [ ] Auto-targeted passing with aim assist (#6)
- [ ] Defense — tackling and player switching (#7)
- [ ] Ball possession — pickup, dribble, contested balls (#8)
- [ ] AI box-based positioning (#9)

**Match Flow**
- [ ] Goal detection with crossbar and goalposts (#10)
- [ ] Out-of-bounds — throw-in, corner, goal kick (#11)
- [ ] Set pieces with extended aftertouch (#12)
- [ ] Match orchestrator — state machine, clock, scoreboard (#15)

**Polish**
- [ ] Player sprites with palette swap shader (#13)
- [ ] Camera follow with smooth tracking (#14)
- [ ] Team data, stats, formations (#22)

**Expansion: Football 2.0**
- [ ] BallManager for multi-ball support (#17)
- [ ] Multiball mode (#18)
- [ ] Double Corner (#19)
- [ ] Exploding Grenade Ball (#20)
- [ ] Power-up spawner and pickups (#21)

## Architecture

```
Main (Node2D) ← match.gd
├── Camera2D                     Smooth ball-follow with velocity lead
├── Pitch (Node2D)               Pitch sprite + boundary/goal areas
├── BallManager (Node2D)         Owns all balls (supports multiball)
│   └── Ball (CharacterBody2D)   Physics, aftertouch, shadow
├── TeamHome / TeamAway          11 players each (CharacterBody2D)
├── PossessionManager            Central possession authority
├── PowerUpSpawner               Expansion feature triggers
└── UI (CanvasLayer)             Scoreboard, clock, effects bar
```

Key design decisions:
- **CharacterBody2D** (not RigidBody2D) — direct velocity control, no physics simulation fighting you
- **Pure logic classes** (`*_pure.gd`) — game math with zero Node dependencies, fully testable headless
- **No player-player collision** — players overlap freely, faithful to the original
- **50 Hz physics tick** — matches PAL Amiga exactly; changing this breaks all tuned constants

## Building & Running

```bash
# Open in Godot editor
godot --path . --editor

# Run the game
godot --path .

# Run tests headless
godot --headless --path . -d -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests -ginclude_subdirs -gexit
```

## Inspirations & References

- **Sensible Soccer** (1992) / **Sensible World of Soccer** (1994) by Sensible Software
- [swos-port](https://github.com/zlatkok/swos-port) — disassembly-to-C++ conversion of DOS SWOS
- [YSoccer](https://sourceforge.net/projects/yodasoccer/) — GPL Sensible Soccer clone (sprite reference)
- Jon Hare & Chris Chapman interviews on aftertouch, aim assist, and the "bread and butter" engine

## License

TBD
