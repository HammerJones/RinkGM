# RinkGM

Experimenting with a hockey game/rink management sim.

Working on RinkGM? Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (who owns
what, shared interfaces, the CI gate), [docs/FRAMEWORK.md](docs/FRAMEWORK.md)
(the engine layer: assets, props, streaming, budgets) and
[docs/ROADMAP.md](docs/ROADMAP.md).

## Playable demo (Godot 4.6+)

Open the folder in Godot 4.6 or newer and press Play. It's a 5-on-5 game with
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
| Hockey stop | R3 (click right stick) | Space, or push back against the way you're going (S skating forwards, W skating backwards) |
| Stick blade (220 degree arc, back past each hip) | Right stick | Mouse (cursor is captured; Esc opens the menu and frees it) |
| Stickhandle | Right stick side to side | Mouse side to side: the blade carries the puck. The HANDS gauge counts how quickly you change direction, against the fastest rhythm your stickhandling allows (2 to 7 changes a second); in the red the puck gets away |
| Shoot | Flick or wind up the right stick (below) | Hold right click and draw a shot pattern, release to shoot (below) |
| Aim | | Hold left click to look around; the centre dot is the aim. Add right click to lock the view and draw. Right click alone aims at the middle of the net |
| Shot pattern guide (wrist, snap, slap, toe drag, off) | | V |
| Learned moves (snapshot, dekes, toe drag...) | Stick patterns, see below | |
| Lift stick (offense: over the puck; defense: lift their stick) | LT | |
| Tilt blade (raises shots and passes) | RT (analog) | |
| Aim at the near or far post | Lean the left stick | Lean with W / S |
| Pass, or call for a pass without the puck | A or RB | E |
| Turn around: skate backwards, again to face forward | X | R |
| Look around (the blade holds still; let go and the view eases back) | Hold LB + right stick | Hold left click + mouse |
| Body check | B | F |
| Mouse sensitivity | | [ and ] |
| Physics mode (Sim / Hybrid / Arcade) | Back | F1 |
| Camera (down the ice / first person / broadcast / isometric) | D-pad up | C |
| Menu: pause, restart, controls, practice, quit (frees the cursor) | Start | Esc |
| Restart (practice: reset the puck) | | Backspace |
| Show/hide controls | | H |
| Developer menu | D-pad down | ` (tilde key) |
| Playtest note (screenshot + note) | | N |

"Forward" and "behind" are relative to the way your skater faces; the stick
itself is camera-relative on the pad, like the left stick; the mouse places
the blade around your body (up is where you face), so turning carries the
puck round with you. A faint arc on the ice shows
where the blade can reach. Device reading lives in `scripts/input/`
(`PlayerInput` reads devices, `HumanController` fills `Skater.Controls`).
Both hands stay on the stick in the front 90 degrees; past that the bottom
hand lets go and the top hand reaches.

**Keyboard + mouse shots** (Sean, 19 Oct). Up the screen is toward the net;
the patterns are drawn for a right shot (forehand on the right):

| Shot | Pattern |
| --- | --- |
| Wrist shot | a short pull back to the forehand, then straight forward |
| Snap shot | across to the forehand, a short drop, then straight forward |
| Slap shot | a curve back to the left, a long drop (the backswing), then all the way forward |
| Toe drag shot | pull it in and across, back and forth, then forward |

How fast the forward stroke goes sets the power (shot power lets a slower
stroke hit as hard). How closely the drawing matches the pattern sets how
far from the aim the puck can land, anywhere inside that circle (shot
accuracy forgives a wobblier pattern). At maxed shooting skills the clock
slows while right click is held. `ShotPatterns` has the templates.

Rink jobs (the M1 mini games) read `JobInput` instead, in three contexts:

| Rink jobs | Gamepad | Keyboard + mouse |
| --- | --- | --- |
| Walk / run / look | Left stick / L3 / right stick | WASD / Shift / mouse |
| Use a door or job spot | A | E |
| Back off, put down | B | X |
| Grab a tool or part (hold) | RT | Left mouse |
| Turn it (while grabbing) | Circle the right stick, or LB / RB a step | Wheel, or drag sideways |
| Pump (while grabbing) | Right stick up and down | Drag up and down |
| Drive Doris: brake, blade lever, water lever | LT, LB, RB | Space, Q, F |

The job scenes feed the frame to the verbs in `scripts/input/jobs/`:
`Fastener` (run down, hand tight, torque or hand tight plus a part turn,
cross-threading), `TorqueWrench` (the click), `HandPump` (oil by the stroke)
and `InteractPicker` (what interact acts on). Each grades a step 0.7 to 1.0
with flags, per RINK_SIM 4.1.

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
| Lacrosse | Hold RT, sweep from the backhand round to the forehand: the puck rides up on the blade; keep RT held and push forward to throw it | Learned |

### Physics and player ratings

Each skater has `Skills` (`scripts/career/skills.gd`, ratings 1 to 100: speed, agility, stick handling,
shot accuracy, shot power, shot release, pass quality, hitting, toughness).
`PhysicsProfile` turns those ratings into physical numbers, so every
rating-to-physics curve is in one file. Everything in play is a simulated
object: every contact (blade on puck, puck on pads, body on body) is an
impulse worked out from the two objects' velocities, with restitution and
friction (`scripts/game/contact.gd`). Ratings shape what a body can do
(how fast it swings, how soft its hands are, how hard it drives its legs),
never the outcome of a contact. Nothing in play is rolled. `Tuning.blend`
(0 = SIM, the default, 0.5 = HYBRID, 1 = ARCADE, cycled with F1) adds
skating and stick-control assistance on top; it never changes contacts.

- **Skating** (`scripts/game/skater.gd`): you only push along your skates, so
  turning is carving, and turns get wider at speed. Top speed runs from
  11 mph (speed 1) to 25 mph (speed 100) (25 mph is the hard ceiling for
  anyone), rising much faster at the top: about 13 mph in a beer league, 15.5
  at senior AAA. Striding alone cruises at 85% of that; a dash is a few hard
  strides, a push over 0.2 s, that takes you the rest of the way and costs
  stamina. A turn redirects your speed but never adds to it. The hockey stop scrapes speed off
  sideways; agility sets how fast you turn, how hard your edges grip, and how
  short you stop. Carving never adds speed past top speed.
- **Stick and puck** (`scripts/game/stick_puck.gd`): the blade swings around
  the body inside a 220 degree arc, with a speed and acceleration set by stick
  handling. Both hands are on the stick in the front 90 degrees; beyond that
  it's one hand: more reach, but a weaker hold on the puck and weaker, wilder
  shots. Pulling the stick back past 95 degrees winds up a shot. The puck is
  a free physical object: the blade is a solid face that pushes it, and a
  loose puck bounces off it. A receiver's soft hands give with the puck (low
  restitution from pass quality and stick handling), so a good receiver
  soaks a pass up and a poor one bobbles it; it's theirs once it sits on the
  face. The curve of the blade cups a carried puck, only as hard as the
  hands can hold it (grip, from stick handling). Stickhandling moves the puck with the
  stick: to bring it back the other way the skater lifts the blade over the
  puck and sets it down on the far side. Stickhandle faster than your rating,
  or cut harder than you can hold (agility turns you faster, which is harder
  to hold), and the puck slides off. Lifting your stick takes the blade off the puck for
  moves; on defense, with your blade under the carrier's shaft, it's a
  strength contest: your lift with the leverage of where you got under it
  (near their blade, easy; near their hands, hopeless) against how hard they
  bear down.
- **Stick moves** (`scripts/game/move_physics.gd`): each learned move from the
  catalog (Shots and stick moves above) runs as a blade path around the body,
  from wherever the blade is, under the skater's own blade limits, so weak
  hands run it slower and can lose the puck. Move shots (snapshot, backhand
  snap, toe drag shot) have their own power, accuracy and loft; the lacrosse
  carries the puck up on the blade until it's thrown.
- **Shooting**: a shot is the blade swung through the puck
  (`StickPuck.strike`): the puck comes off a heavy, springy blade moving at
  the swing speed plus the skater's own skating speed, so a one-timer keeps
  some of the pass's speed and a shot on the move carries the skater's. The
  wind-up loads the shaft's flex. Shot release sets how good a no-wind-up
  shot is and how fast you reach full power; shot power sets the swing (a full
  slapshot is about 60 mph at 1, 98 mph at 100). Where the face points is the
  aim, give or take how steady the hands are (`Skater.hand_shake`, a smooth
  tremor scaled by shot accuracy, skating speed and carving); tilt opens the
  face and raises the shot.
- **Passing**: the same strike, a gentler sweep at the receiver's blade led by
  where they're skating. Who to pass to is the player's or AI's call (the
  AI's choice, or whoever is nearest where you push the stick). Pass quality
  sets how steady the sweep is and how soft your own hands receive.
- **Hits**: `Game.hit_landed(hitter, victim, impulse, knocked_down)` fires on
  every contact between opponents. The bump is a collision of two 85 kg
  bodies from their closing speed; a shoulder check adds the hitter's leg
  drive (hitting). The victim goes down if the jolt beats their balance
  (toughness, lower while carving hard, stopping or dashing, much higher if
  they saw it coming). A carrier who stays up keeps the puck only if their
  blade still holds it. The AI steers round head-on collisions it doesn't
  mean.
- **Goalies** (`scripts/game/goalie.gd`) are bodies with mass that skate the
  crease (they can be bumped), come out to the top of the crease to cut the
  angle, and get set when they see a wind-up. They only react to where the
  shot goes once it leaves the blade (reaction time from skill and tier);
  then the hands accelerate toward it and they drop to the butterfly for low
  shots and in tight. Saves are collisions with pads, body, blocker, stick and
  glove, each as lively as the real thing; the glove holds a puck it can
  squeeze (whistle) and everything else is a rebound off whatever it hit.
  `--only=goalie` in the bench shows how often a lone shooter scores.
- **Nets** (`scripts/game/net_physics.gd`) are solid: iron posts and
  crossbar ring a puck back out, and the frame and netting are boxes from
  the net's own voxel model, so the twine stops a shot (or one from behind
  the net) where you see it. A goal is the whole puck over the line between
  the posts. Over the glass, the puck flies into the building
  (`Puck.left_rink`, whistle).
- **On-ice AI** (`scripts/game/skater_ai.gd`, the goalie) plays to the league
  tier, not just the ratings: each team reads a `TierAI` (`game.ai_for`). A beer
  league reacts late to turnovers, sends two or three skaters after the puck,
  forces passes and shoots from anywhere, and its goalie is slow and off the
  angle. Higher tiers hold support spots and gaps, move the puck early to the
  open man and work it in close before shooting.
- **Positions** (`scripts/game/team_system.gd`): every skater plays the
  position of their bench slot (C, LW, RW, LD, RD), through line changes. The
  team reads the phase of play from who last had the puck under control and
  where it is, and each position has its spot: in their zone the D hold the
  points and move it D to D, the strong-side winger works the wall, the other
  goes to the net front and the C sits high as the safety; breakouts put the D
  on retrievals, the wingers on the boards at the hash marks and the C low;
  the forecheck is a 1-2-2 with the D holding the line; in the D zone it's a
  box +1. The spots follow the play at skating speed. `TierAI.discipline` is
  how tightly players keep to their spots (a beer league drifts toward the
  puck and sends extra chasers; a disciplined side rotates to cover a man
  caught out), `anticipation` how soon they read the phase change.
  `-- --test=positions [--heatmaps=dir]` measures it and draws where each
  position plays.
- **Sticks wear and break** (`scripts/game/stick_wear.gd`). Slapshots and
  one-timers load a stick hardest; blocking a hot puck, hard pokes, stick lifts
  and falls load it too. Each load wears it (`Skater.stick_health`) and may snap
  it, far more often when it's worn and less with a tougher stick
  (`stick_durability`). A stick that snaps on a shot sends the puck dribbling
  off, the pieces fly onto the ice, and the skater can't touch the puck until
  they stop at their bench door or a faceoff comes round. The AI heads to the
  bench, unless it's a disciplined side with the puck in its own end, where it
  stays to block. `Game.stick_broken(skater, stick_id, cause)` reports each
  break. A standard new stick breaks about 2% of the time over 15 minutes on
  the ice; `StickWear.durability_for(break_per_game)` turns a pro shop stick's
  rate into its durability. `-- --test=sticks` checks it.

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
- `--test=positions [--seconds=200] [--heatmaps=dir]` plays both teams at TierAI level 0 and then 3, prints each position's average distance from its spot by phase, fails unless level 3 keeps its positions clearly better, and with `--heatmaps` writes a sheet per tier of where each position plays.
- `--demo=controls` plays a captioned showcase of every move (`tests/controls_demo.gd`). Record it with `godot --path . --write-movie demo.avi --fixed-fps 30 --resolution 1280x720 -- --demo=controls`.
- `--demo=skating` and `--demo=moves` are close-up reels of the skating animation and of the stick arc and every shot and stick move, with the right stick's path drawn on a pad.
- `--autoplay` lets the AI drive your skater too (prints stats and a box score on exit).
- `--period=N` plays N-minute periods (exhibition default is 5).
- `--career` opens the career hub (pick a save: Career, Demo: low tier, Demo: mid tier); `--slot=career|demo_low|demo_mid` skips the picker and `--career-new` discards that slot's save.
- `--mode=sim|hybrid|arcade` picks the physics mode at startup.
- `--ai-levels=0.5,3` sets how organised each team plays (TierAI level, 0 = Beer League D to 5 = Minor League Pro).
- `--seed=N` replays the same game every run.
- `--screenshot=out.png --shot-after=6 [--iso] [--zoom=10] [--focus=x,z]` saves a frame and quits.

For example, to simulate a full game headless in a few seconds:

```
godot --headless --path . --fixed-fps 120 --quit-after 36000 -- --autoplay --mode=hybrid --period=1
```

`tools/check.sh` re-imports the project and runs it headless to surface script errors.
`tools/physics_bench.sh [out.md]` prints the physics bench.
`tools/ci.sh` is the full gate CI runs on every PR: import, a headless autoplay
game and the `tools/tests/` scripts.
`tools/tier_ai_check.sh` plays `GAMES` (default 24; fewer is too noisy at 5-on-5) autoplay games of a Beer League D
side against a Senior AAA side, swapping ends, and fails unless the higher tier
outscores and outwins the lower one. Each game has a fixed seed, so the result
only moves when a change affects how the game plays.
