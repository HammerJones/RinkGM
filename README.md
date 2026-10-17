# RinkGM

Experimenting with a hockey game/rink management sim.

Working on RinkGM? Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (who owns
what, shared interfaces, the CI gate) and [docs/ROADMAP.md](docs/ROADMAP.md).

## Playable demo (Godot 4.3+)

Open the folder in Godot 4.3 or newer and press Play. It's a 5-on-5 game with
goalies on an NHL-size rink, three 5-minute periods with rotating lines, in the voxel style of the
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
| Wind-up shot | Pull the stick behind you, then push it forward | Same with the mouse |
| Slapshot | Hold LT as you pull back | Hold right click as you pull back |
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

"Forward" and "behind" are relative to the way your skater faces; the stick
itself is camera-relative, like the left stick. A faint arc on the ice shows
where the blade can reach. Device reading lives in `scripts/input/`
(`PlayerInput` reads devices, `HumanController` fills `Skater.Controls`).

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
- **On-ice AI** (`scripts/game/skater_ai.gd`, the goalie) plays to the league
  tier, not just the ratings: each team reads a `TierAI` (`game.ai_for`). A beer
  league reacts late to turnovers, sends two or three skaters after the puck,
  forces passes and shoots from anywhere, and its goalie is slow and off the
  angle. Higher tiers hold support spots and gaps, move the puck early to the
  open man and work it in close before shooting.

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

### Career mode and game mechanics

Run with `-- --career` (or open `scenes/career_hub.tscn`) to start a career.
You create one skater (C, LW, RW or D) in the beginner beer league and play
that one player: no switching, and when your line is on the bench you watch
(hold Tab / Y to fast-forward). Exhibition games (the default `main.tscn`) use
the same rules with you on the centre's body, always on the ice.

- **Ratings** (`scripts/career/skills.gd`): speed, agility, stick handling,
  shot accuracy, shot power, shot release, passing, hitting and toughness, each
  1-100, plus injury/fatigue modifiers. `Skills` is the single store: the
  physics' `PhysicsProfile` turns it into metres and seconds, and everything
  else reads `Skater.skill(key)` (0..1).
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

- `--test=controls` runs the scripted control checks in `tests/controls_test.gd` and exits non-zero on failure.
- `--demo=controls` plays a captioned showcase of every move (`tests/controls_demo.gd`). Record it with `godot --path . --write-movie demo.avi --fixed-fps 30 --resolution 1280x720 -- --demo=controls`.
- `--autoplay` lets the AI drive your skater too (prints stats and a box score on exit).
- `--period=N` plays N-minute periods (exhibition default is 5).
- `--career` opens the career hub (pick a save: Career, Demo: low tier, Demo: mid tier); `--slot=career|demo_low|demo_mid` skips the picker and `--career-new` discards that slot's save.
- `--mode=sim|hybrid|arcade` picks the physics mode at startup.
- `--ai-levels=0.5,3` sets how organised each team plays (TierAI level, 0 = Beer League D to 5 = Minor League Pro).
- `--screenshot=out.png --shot-after=6 [--iso] [--zoom=10] [--focus=x,z]` saves a frame and quits.

For example, to simulate a full game headless in a few seconds:

```
godot --headless --path . --fixed-fps 120 --quit-after 36000 -- --autoplay --mode=hybrid --period=1
```

`tools/check.sh` re-imports the project and runs it headless to surface script errors.
`tools/physics_bench.sh [out.md]` prints the physics bench.
`tools/ci.sh` is the full gate CI runs on every PR: import, a headless autoplay
game and the `tools/tests/` scripts.
`tools/tier_ai_check.sh` plays `GAMES` (default 8) autoplay games of a beer-league
side against a Senior AAA side, swapping ends, and fails unless the higher tier
outscores and outwins the lower one.
