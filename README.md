# RinkGM

Experimenting with a hockey game/rink management sim.

Working on RinkGM? Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (who owns
what, shared interfaces, the CI gate) and [docs/ROADMAP.md](docs/ROADMAP.md).

## Playable demo (Godot 4.3+)

Open the folder in Godot 4.3 or newer and press Play. It's a 3-on-3 game with
goalies on an NHL-size rink, five-minute clock, in the voxel style of the
reference renders in `art/reference/`. You play the red team; the yellow ring
marks the skater you control.

### Controls

| Action | Keyboard + mouse | Gamepad |
| --- | --- | --- |
| Skate | WASD | Left stick |
| Stick blade (stickhandle) | Mouse position on the ice | Right stick |
| Shoot | Left click (hold for slapshot) | RT or X (hold for slapshot), or pull the right stick back then flick it forward |
| Pass (with puck) / switch player (without) | Right click or E | A |
| Sprint | Shift | LB or L3 |
| Hockey stop | Space | LT |
| Body check | F | B |
| Switch player | Q / Tab | Y |
| Physics mode (Sim / Hybrid / Arcade) | F1 | Back |
| Camera (broadcast / isometric) | C | D-pad up |
| Restart | R | Start |
| Show/hide controls | H | |

With the mouse, the blade goes where you point (inside the stick's reach), and
shots and passes go toward the cursor. On a gamepad, the left stick picks the
near or far side of the net for shots.

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
scripts/ui/hud.gd        scoreboard, bars, messages, controls card
art/reference/           the reference renders
```

### Command-line helpers

Arguments after `--` are read by the game:

- `--autoplay` lets the AI drive your skater too (prints stats on exit).
- `--mode=sim|hybrid|arcade` picks the physics mode at startup.
- `--screenshot=out.png --shot-after=6 [--iso] [--zoom=10] [--focus=x,z]` saves a frame and quits.

For example, to simulate a full game headless in a few seconds:

```
godot --headless --path . --fixed-fps 120 --quit-after 36000 -- --autoplay --mode=hybrid
```

`tools/check.sh` re-imports the project and runs it headless to surface script errors.
`tools/ci.sh` is the full gate CI runs on every PR: import, a headless autoplay
game and the `tools/tests/` scripts.
