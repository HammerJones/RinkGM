# RinkGM

Experimenting with a hockey game/rink management sim.

## Playable demo (Godot 4.3+)

Open the folder in Godot 4.3 or newer and press Play. It's a 5-on-5 game with
goalies on an NHL-size rink, three 5-minute periods with rotating lines, in the voxel style of the
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

### Career mode and game mechanics

Run with `-- --career` (or open `scenes/career_hub.tscn`) to start a career.
You create one skater (C, LW, RW or D) in the beginner beer league and play
that one player: no switching, and when your line is on the bench you watch
(hold Tab / Y to fast-forward). Exhibition games (the default `main.tscn`) use
the same rules with you on the centre's body, always on the ice.

- **Ratings** (`scripts/career/skills.gd`): speed, agility, stick handling,
  shot accuracy, shot power, shot release, passing, hitting and toughness, each
  1-100. `Skills` is the only place a rating becomes a physics number, so the
  physics reads `skater.skills` and balance is tuned there:
  - speed: sprint top speed 14 mph at 1, **25 mph at 100**, and acceleration
  - agility: turn rate, edge grip, and a safe turn rate above which the puck
    works loose and the skater is easier to knock over
  - stick handling: blade speed and how tightly the puck stays on it
  - shot release: wind-up time for a full-quality shot (0.5 s down to 0.14 s)
    and how good an instant shot is (20% quality at 1, 75% at 100)
  - shot accuracy / power: aim error and puck speed, scaled by that quality
  - passing: pass aim error, how hot a pass the skater can trap, and a
    tape-to-tape bonus for the intended target (near-certain at 100)
  - hitting / toughness: check strength vs. balance, and injury risk
- **Injuries** (`injury.gd`): hard hits roll for an injury (harder hits,
  tired players and low toughness raise the odds). Severity runs day-to-day,
  minor, moderate, major; each hits the skills tied to the body part while it
  heals, and some majors leave a permanent loss.
- **Progression** (`progression.gd`): game XP goes to the skills you used
  (shots train shooting, hits train hitting, ice time trains skating), plus
  practice with a chosen training focus. Growth slows near your potential and
  with age; from 30 the physical skills decline, and missed games add rust.
- **Seasons** (`season.gd`, `league_tiers.gd`): 12-16 game double round-robin
  by tier, 2 points a win and 1 for an OT/shootout loss, then a top-4 playoff
  bracket (single games in the beer leagues, series higher up). Games you
  don't play are quick-simmed from team strength (`quick_sim.gd`).
- **Games** (`game_settings.gd`, `scripts/game/bench.gd`): always 3 periods,
  period length adjustable in the hub (2-20 min). Three forward lines and two
  defence pairs change on shift clocks; regular-season ties get sudden-death OT
  then a shootout, playoff OT runs until someone scores.
- **The ladder**: Beer League D, C, A, Senior AAA, Semi-Pro, Minor League Pro.
  After each season scouts weigh your rating and production; invitations lead
  to tryout camps. Fall too far below your level and you get released down a tier.
- The career keeps a calendar `day` and saves to `user://career.json`, so
  open-world rink time can hang off the same clock later.

`godot --headless --path . --script tools/tests/test_career.gd -- --seasons=10`
quick-sims a whole career and checks schedules, standings and save/load.
`godot --headless --path . --fixed-fps 120 -- --career --career-new --autoplay --period=1 --seasons=1`
plays a full season of live engine games with the AI driving you.

### Command-line helpers

Arguments after `--` are read by the game:

- `--autoplay` lets the AI drive your skater too (prints stats and a box score on exit).
- `--period=N` plays N-minute periods (exhibition default is 5).
- `--career` opens the career hub; `--career-new` discards the saved career.
- `--mode=sim|hybrid|arcade` picks the physics mode at startup.
- `--test=controls` runs the scripted control checks in `tests/controls_test.gd` and exits non-zero on failure.
- `--screenshot=out.png --shot-after=6 [--iso] [--zoom=10] [--focus=x,z]` saves a frame and quits.

For example, to simulate a full game headless in a few seconds:

```
godot --headless --path . --fixed-fps 120 --quit-after 36000 -- --autoplay --mode=hybrid --period=1
```

`tools/check.sh` re-imports the project and runs it headless to surface script errors.
