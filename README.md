# RinkGM

Experimenting with a hockey game/rink management sim.

## Playable demo (Godot 4.3+)

Open the folder in Godot 4.3 or newer and press Play. It's a 3-on-3 game with
goalies on an NHL-size rink, five-minute clock, in the voxel style of the
reference renders in `art/reference/`. You play the red team; the yellow ring
marks the skater you control.

### Controls

You play one skater (no player switching). The scheme follows Slapshot
Rebound's physical stick; the keyboard + mouse layout turns the mouse into a
virtual right stick, so both devices drive the same stick model.

| Action | Gamepad | Keyboard + mouse |
| --- | --- | --- |
| Skate | Left stick | WASD |
| Dash (push-off burst) | L3 (click left stick) | Shift |
| Hockey stop | R3 (click right stick) | Space |
| Stick blade (220 degree arc around you) | Right stick | Mouse (cursor is captured; Esc frees it) |
| Stickhandle | Right stick side to side | Mouse side to side |
| Quick shot (instant) | Flick the right stick forward | Flick the mouse forward |
| Wrist shot | Draw the stick back behind your forehand hip, then sweep it forward | Same with the mouse |
| Backhand | Draw back behind your backhand hip, then sweep forward | Same with the mouse |
| Learned moves (snapshot, dekes, toe drag...) | Stick patterns, see below | Same with the mouse |
| Lift stick (offense: over the puck; defense: lift their stick) | LT | Right click |
| Tilt blade (raises shots and passes) | RT (analog) | Left click (hold longer for more) |
| Aim at the near or far post | Lean the left stick | Lean with W / S |
| Pass, or call for a pass without the puck | A or RB | E |
| Body check | B | F |
| Mouse sensitivity | | [ and ] |
| Physics mode (Sim / Hybrid / Arcade) | Back | F1 |
| Camera (broadcast / isometric) | D-pad up | C |
| Restart | Start | R |
| Show/hide controls | | H |
| Developer menu | D-pad down | ` (tilde key) |

"Forward" and "behind" are relative to the way your skater faces; the stick
itself is camera-relative, like the left stick. A faint arc on the ice shows
where the blade can reach. Device reading lives in `scripts/input/`
(`PlayerInput` reads devices, `HumanController` fills `Skater.Controls`).
Both hands stay on the stick in the front 90 degrees; past that the bottom
hand lets go and the top hand reaches.

#### Shots and stick moves

Shots and dekes are patterns you trace with the right stick. The catalog is
`scripts/core/moves.gd`; `StickGestures` (`scripts/input/`) recognises the
pattern and asks for the move, physics (`MovePhysics`) runs it, and which
moves a player has learned is up to progression (`Skater.knows`).

| Move | Pattern | |
| --- | --- | --- |
| Quick shot | Flick forward from neutral | Starter |
| Wrist shot | Draw back past the forehand hip, sweep forward | Starter |
| Backhand | Draw back past the backhand hip, sweep forward | Starter |
| Slapshot | Hold LT and draw back on the forehand, then forward | Learned |
| One-timer | Slapshot wind-up without the puck, fire as the pass arrives | Learned |
| Snapshot | Pull out to the forehand side (30 to 70 degrees), hold a beat, snap all the way forward | Learned |
| Backhand snap | The same on the backhand side | Learned |
| Quick deke | Whip the stick forehand, backhand, forehand | Learned |
| Toe drag | Hold RT, stick out front, pull it back across to the backhand | Learned |
| Toe drag shot | Hold LT and RT, stick out front, pull it back across | Learned |
| Lacrosse | Hold RT, sweep from the backhand round to the forehand, push forward | Proposed |

### Physics and player ratings

Each skater has `Skills` (`scripts/career/skills.gd`, ratings 1 to 100: speed, agility, stick handling,
shot accuracy, shot power, shot release, pass quality, hitting, toughness).
`PhysicsProfile` turns those ratings into physical numbers, so every
rating-to-physics curve is in one file. Everything is simulated, and
`Tuning.blend` (0 = SIM, 0.5 = HYBRID, 1 = ARCADE, cycled with F1) adds
assistance on top.

- **Skating** (`scripts/game/skater.gd`): you only push along your skates, so
  turning is carving, and turns get wider at speed. Top speed runs from
  15 mph (speed 1) to 25 mph (speed 100), an absolute ceiling. A dash is a
  burst stride that gets you to top speed faster and costs stamina. The hockey stop scrapes speed off
  sideways; agility sets how fast you turn, how hard your edges grip, and how
  short you stop. Carving never adds speed past top speed.
- **Stick and puck** (`scripts/game/stick_puck.gd`): the blade swings around
  the body inside a 220 degree arc, with a speed and acceleration set by stick
  handling. Both hands are on the stick in the front 90 degrees; beyond that
  it's one hand: more reach, but a weaker hold on the puck and weaker, wilder
  shots. Pulling the stick back past 95 degrees winds up a shot. The puck
  follows it on a spring, but the blade can only push the puck so hard (grip,
  also from stick handling). Stickhandle faster than your rating, or cut harder
  than you can hold (agility turns you faster, which is harder to hold), and
  the puck slides off. Lifting your stick takes the blade off the puck for
  moves; on defense it lifts the carrier's stick if you're close, with odds
  from both players' ratings.
- **Stick moves** (`scripts/game/move_physics.gd`): unlockable shots and dekes
  (snap shot, backhand, quick deke, toe drag, toe-drag shot) run as blade paths
  around the body. Gesture recognition sets `Controls.move_id`; the path still
  runs under the skater's own blade limits, so weak hands run it slower and can
  lose the puck.
- **Shooting**: one wind-up model for all shots. A shot with no wind-up comes
  off instantly but weak and wild; shot release sets how good that instant
  shot is and how fast you reach full power. Shot power sets the top speed
  (a full slapshot is about 60 mph at 1, 98 mph at 100), shot accuracy the aim
  error. Skating fast or carving hard costs accuracy. Tilting the blade raises
  the shot. Arcade adds aim assist toward the inside of the posts.
- **Passing**: pass quality sets pass accuracy, how soft a pass arrives for its
  intended target, and how fast a puck you can trap. At 100 the target almost
  always gets clean control.
- **Hits**: `Game.hit_landed(hitter, victim, impulse, knocked_down)` fires on
  every contact between opponents. Impulse comes from closing speed and the
  hitter's rating, much more for a shoulder check. It knocks the victim down if
  it beats their balance (toughness, lowered while they carve hard, stop or
  dash), and a smaller hit can still jar the puck loose.
- **Goalies** (`scripts/game/goalie.gd`) play the angle, read the shot after a
  reaction delay, reach toward where the puck will cross, drop to the butterfly
  for low shots, and either hold the puck (whistle) or give up a rebound.

`tools/physics_bench.sh` drives skaters through scripted tests headless (including
the right-stick gestures: flick, pull back and push, lift for a slapshot) and
prints what each rating produces (acceleration, stops, turns, puck control in
cuts and while stickhandling, shot speed and accuracy, pass reception, hit
strength) as Markdown tables. Run it after changing `PhysicsProfile`.

### Voxel models and oriented voxels

- `VoxelModel` is a sparse colored voxel grid that meshes to an `ArrayMesh` with
  hidden faces culled and a little per-voxel color noise for the speckled look.
- `VoxelPart` is a posable mesh instance. Characters are hierarchies of parts
  (pants, legs, torso, head, arms, stick) posed procedurally each frame by
  `SkaterRig`: skating stride, leaning into turns, falls, and two-handed stick IK
  that follows the simulated blade.
- Oriented voxels: `VoxelMeshBuilder.add_box(transform, color)` emits a voxel
  with any rotation or scale, and `VoxelModel.append_to(builder, transform)`
  bakes a whole model at any orientation. The rounded rink boards are built this
  way, one rotated column every 15 cm.
- `VoxLoader.load_vox()` reads MagicaVoxel `.vox` files into a `VoxelModel`, so
  models can be authored in MagicaVoxel and swapped in for the procedural ones
  in `scripts/art/models.gd`.

### Layout

```
project.godot            autoloads: Tuning (feel), InputSetup (input map)
scenes/main.tscn         root node -> scripts/game/game.gd
scripts/voxel/           VoxelModel, VoxelMeshBuilder, VoxelPart, VoxLoader
scripts/art/models.gd    procedural players, goalies, sticks, puck, net
scripts/rink/rink.gd     rink geometry (board SDF, nets) + ice/boards visuals
scripts/career/skills.gd player ratings (1 to 100); injuries/fatigue as modifiers
scripts/game/            game rules, skater, goalie, puck, stick-puck contact,
                         PhysicsProfile (ratings to physics), AI, rig, camera
scripts/input/           PlayerInput (devices, mouse = virtual stick), HumanController
scripts/ui/hud.gd        scoreboard, bars, messages, controls card
tests/                   headless control checks (`-- --test=controls`)
art/reference/           the reference renders
tools/bench/             headless physics bench (tools/physics_bench.sh)
```

### Command-line helpers

Arguments after `--` are read by the game:

- `--test=controls` runs the scripted control checks in `tests/controls_test.gd` and exits non-zero on failure.
- `--demo=controls` plays a captioned showcase of every move (`tests/controls_demo.gd`). Record it with `godot --path . --write-movie demo.avi --fixed-fps 30 --resolution 1280x720 -- --demo=controls`.
- `--demo=skating` and `--demo=moves` are close-up reels of the skating animation and of the stick arc and every shot and stick move, with the right stick's path drawn on a pad.
- `--autoplay` lets the AI drive your skater too (prints stats on exit).
- `--mode=sim|hybrid|arcade` picks the physics mode at startup.
- `--screenshot=out.png --shot-after=6 [--iso] [--zoom=10] [--focus=x,z]` saves a frame and quits.

For example, to simulate a full game headless in a few seconds:

```
godot --headless --path . --fixed-fps 120 --quit-after 36000 -- --autoplay --mode=hybrid
```

`tools/check.sh` re-imports the project and runs it headless to surface script errors.
`tools/physics_bench.sh [out.md]` prints the physics bench.
