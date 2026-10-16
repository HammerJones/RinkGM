# RinkGM

Experimenting with a hockey game/rink management sim.

## Playable demo (Godot 4.3+)

Open the folder in Godot 4.3 or newer and press Play. It's a 3-on-3 game with
goalies on an NHL-size rink, five-minute clock, in the voxel style of the
reference renders in `art/reference/`. You play the red team; the yellow ring
marks the skater you control.

### Controls

You play one skater (no player switching). The scheme follows Slapshot
Rebound's physical stick with some NHL-style "puck glue" on top; the
keyboard + mouse layout turns the mouse into a virtual right stick.

| Action | Gamepad | Keyboard + mouse |
| --- | --- | --- |
| Skate | Left stick | WASD |
| Dash (push-off burst) | L3 (click left stick) | Shift |
| Hockey stop | R3 (click right stick) | Space |
| Move the stick blade (90 degree arc in front of you) | Right stick | Mouse (cursor is captured; Esc frees it) |
| Stickhandle | Right stick side to side | Mouse side to side |
| Quick shot | Flick the right stick forward | Flick the mouse forward |
| Wind-up shot | Pull the stick behind you, hold, sweep forward | Same with the mouse |
| Slapshot | Hold LT while winding up | Hold RMB while winding up |
| Lift stick: dekes with the puck, stick lift on defense | LT | RMB |
| Tilt blade (raise shots and passes) | RT (analog) | LMB (hold longer for more) |
| Pass, or call for a pass without the puck | A or RB | E |
| Body check | B | F |
| Mouse sensitivity | | [ and ] |
| Physics mode (Sim / Hybrid / Arcade) | Back | F1 |
| Camera (broadcast / isometric) | D-pad up | C |
| Restart | Start | R |
| Show/hide controls | | H |

"Forward" and "behind" are relative to the way your skater faces; the stick
itself is camera-relative, like the left stick. A faint arc on the ice shows
where the blade can reach.

How the skills feed the controls (`scripts/game/stick_control.gd`; ratings
come from `Skater.skill(name)` when it exists, otherwise 0.5):

- **Stickhandling** caps how fast the blade moves, so low ratings stickhandle
  slower, and moving the blade near that cap can fumble the puck (more often
  at low ratings).
- **Shot release**: the instant quick shot is weak and wild at low release and
  gets harder and truer as it improves; wind-ups charge faster too.
- **Shot power / accuracy** set wind-up and slapshot speed and the spread.
- **Pass quality**: pass spread shrinks to almost nothing at the top rating.
- **Hitting** improves defensive stick lifts against the carrier's stickhandling.
- Lifting the stick with the puck lets the puck drift with you while the blade
  goes over it; put it down on the other side and pull for a toe drag.

### How the physics and arcade parts blend

Everything is simulated, and one value, `Tuning.blend` (0 = SIM, 0.5 = HYBRID,
1 = ARCADE, cycled with F1), adds assistance on top of that model:

- **Skating** (`scripts/game/skater.gd`): you only push along your skates, so
  turning is carving. Sideways slide bleeds off through edge grip and part of it
  is kept as forward speed. Turns get wider at speed. The hockey stop slides
  you sideways with a snow spray. Arcade adds more grip, faster turning, some
  direct thrust toward the stick direction, and coasting to a stop when you let go.
- **Puck handling**: the blade is its own point with limited speed and reach.
  The puck is pulled to it by a damped spring, so it lags, can be knocked loose,
  and bounces off the blade if it arrives too fast to trap. Arcade makes the
  spring stiffer and the trap window and blade pocket bigger.
- **Shooting and passing**: shots pick a target height and solve for the lift
  to get there. Accuracy drops when you're skating fast and on slapshots. Arcade
  adds aim assist toward the inside of the posts and a wider pass-target cone
  with more lead on the receiver.
- **Goalies** (`scripts/game/goalie.gd`) play the angle, read the shot after a
  reaction delay, reach toward where the puck will cross, drop to the butterfly
  for low shots, and either hold the puck (whistle) or give up a rebound. Corners
  beat them, so they aren't affected by the blend.

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
scripts/game/            game rules, skater, goalie, puck, AI, rig, camera
scripts/input/           PlayerInput: devices -> one frame of intent (mouse = virtual stick)
scripts/ui/hud.gd        scoreboard, bars, messages, controls card
tests/                   headless control checks (`-- --test=controls`)
art/reference/           the reference renders
```

### Command-line helpers

Arguments after `--` are read by the game:

- `--autoplay` lets the AI drive your skater too (prints stats on exit).
- `--mode=sim|hybrid|arcade` picks the physics mode at startup.
- `--test=controls` runs the scripted control checks in `tests/controls_test.gd` and exits non-zero on failure.
- `--screenshot=out.png --shot-after=6 [--iso] [--zoom=10] [--focus=x,z]` saves a frame and quits.

For example, to simulate a full game headless in a few seconds:

```
godot --headless --path . --fixed-fps 120 --quit-after 36000 -- --autoplay --mode=hybrid
```

`tools/check.sh` re-imports the project and runs it headless to surface script errors.
