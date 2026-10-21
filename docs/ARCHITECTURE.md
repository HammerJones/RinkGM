# RinkGM architecture and team rules

RinkGM is built by several parallel workstreams (Claude threads plus Sean). This
file is the contract between them: who owns which files, the interfaces they
meet at, and the bar a change has to clear. If you need to break a rule here,
change this file in the same PR and say why.

## Workstreams and file ownership

| Workstream | Owns |
| --- | --- |
| Physics | `scripts/game/skater.gd` (skating, blade, puck handling, shots, passes, checks), `puck.gd`, `goalie.gd`, on-ice AI (`skater_ai.gd`, goalie decisions), rink collision in `rink.gd`, `scripts/core/tuning.gd`, the fixed-step sim loop in `game.gd` (`_physics_process`, body and puck contact) |
| Game mechanics | `scripts/career/` (player attributes, progression, injuries, season, playoffs, league tiers, saves), match rules in `game.gd` (periods, lineups, line changes, game length), stats, the match event hub |
| Controls | `scripts/core/input_setup.gd`, `scripts/input/` (human controller, device handling, bindings), the move catalog `scripts/core/moves.gd`, and how players swing the stick (the stick model's look is World and asset design's; its on-screen size and how the hands hold it are Animations'). Only `scripts/input/` reads `Input` |
| UI and styling | `scripts/ui/`, `assets/ui/` (the project-wide RinkOS theme `assets/ui/rinkos_theme.tres`, fonts with their licences). **Every screen follows `assets/ui/STYLE.md`**: use the RinkOS constants, type variations and helpers, never hard-coded fonts or colours |
| Project manager | `docs/`, `tools/`, `.github/`, `README.md`, the developer menu in `scripts/dev/` |
| World and asset design | The look and the asset library: art direction and the voxel style guide (`docs/ART.md`), palettes and materials, `scripts/art/` (characters, goalies, equipment, puck, nets, and a props kit of seats, doors, benches, glass, signage, Zamboni and so on), `scripts/voxel/`, `art/` (MagicaVoxel sources). Later, the open-world map and town around the rink (`scenes/world/`, `scripts/world/`) |
| Rink environment | The building around the ice: `scenes/venue/` and `scripts/venue/`, laid out from the asset kit, plus room layout, collision, walkable floors and doors, lighting, crowd placement, and renovation states (worn, repaired, renovated). `rink.gd` keeps the playing surface, boards and nets |
| Framework | The layer under the world: `framework/` (`VoxMesher`, `VoxWriter`, `PropField`, `PropRow`, `ChunkStreamer`, `ObjectCatalog`, `WorldObjects`, `Interactor`, `PropMaterial`, `Quality`, `Occluders`, `Layers`, `World`, `WorldChunk`, `ContactAudio`, `VoxelSurface`, the prop studio, the objects demo and the render benchmark), `addons/vox_import/` (the `.vox` import plugin and `VoxAsset`), `tools/lint.sh`, `.gdlintrc`, `tests/unit/`, `docs/FRAMEWORK.md`. Owns no game rules: it gives the other workstreams the pipeline, the tiers and the budgets, and they build on it |
| Animations | How every skater moves: the body poses in `scripts/game/skater_rig.gd` (stride, crossovers, stops, shot and pass follow-throughs, checks, falls, celebrations, and how the hands hold the stick: top hand fixed on the knob, bottom hand sliding, per Sean 2026-10-18), the stick's on-screen size (its real length and reach still come from Physics: `PhysicsProfile`, the 220° arc and `one_hand()`; a longer drawn stick needs Physics' reach to grow with it), every animation number in `scripts/anim/anim_tuning.gd` and its saved values `assets/anim/anim_tuning.tres`, and the animation studio (`scenes/anim/`, `scripts/anim/`). See `docs/ANIMATION.md` |

Editing a file you don't own is fine for a small, clearly commented hook. Tell
the owner, and keep the hook to a call into code that lives in your own area.

## Shared interfaces

### 1. Player skills: one store, one converter

There is exactly one place skills are stored and one place they become physics.

**Store: `Skills` (`scripts/career/skills.gd`, owned by Game mechanics).**
Ratings on a **1-100** scale under these exact keys: `speed`, `agility`,
`stick_handling`, `shot_accuracy`, `shot_power`, `shot_release`,
`pass_quality`, `hitting`, `toughness` (goalies: `reflexes`, `positioning`,
`rebound_control`, `glove`, `toughness`). `values` are trained ratings and
`modifiers` are temporary changes; injuries and fatigue are applied as
modifiers, so physics never needs its own "condition" input. `n(key)` gives the
effective rating as 0..1. `Skills` holds no physical curves: no speeds, turn
rates, error angles or shot speeds. Career-only formulas (overall rating,
injury risk, the quick-sim goalie number) stay in `Skills`.

**Converter: `PhysicsProfile` (`scripts/game/physics_profile.gd`, owned by
Physics).** `PhysicsProfile.from_skills(skills)` reads `skills.n(key)` and
produces every number the simulation uses (top speed, accel, turn and edge
grip, puck loss on hard turns, blade speed, trap speed, shot speed, release
time, instant-shot quality, aim and pass error, tape-to-tape bonus, hit power,
balance, stick-lift strength). It is rebuilt when `Skills` changes (line change,
injury). `skater.gd`, `stick_control.gd`, `puck.gd` and the goalie read the
profile, never raw ratings.

**Accessor for everyone else:** `Skater.skill(key)` returns `skills.n(key)`
(0..1) for AI decisions and UI. It uses the canonical key, with no aliases such
as `stickhandling`. An unknown key is a bug and should `push_error`, not
quietly return 0.5.

Fixed anchors from Sean's design:

- `speed` 100 is 25 mph (11.2 m/s) and that is the absolute ceiling: no dash or
  sprint pushes anyone past 25 mph. `speed` 1 is 15 mph. Physics owns the curve
  in between.
- `shot_release`: an instant shot is always possible; at low skill it is weak
  and inaccurate, and it gets stronger and more accurate as the skill rises.
- `pass_quality` near 100 makes it almost certain the intended teammate gains
  control.
- `agility`: sharp turns can work the puck loose and weaken hits.
- `stick_handling`: how fast the stick moves across the stick arc and how likely
  the puck stays on the blade.
- `toughness`: how hard the player hits and how likely they are to be injured.

### 2. Input intent: `Skater.Controls` (fields owned by Controls)

The one struct a human controller and the AI both fill each tick. Controls owns
its fields (stick position in the arc, stick lift, stick tilt, dash, stop,
...). Physics owns what the skater does with them. Skill-based limits (how fast
the stick can move) are applied in physics from attributes, never in the input
layer. The AI must drive skaters through the same struct, so anything a player
can do the AI can do.

### 3. Moves: shot types and dekes as learned gestures

Sean wants shot types and stick moves to be skills the player unlocks and then
performs by tracing a pattern with the right stick or mouse. Three owners, one
shared list:

- **Move catalog** (`scripts/core/moves.gd`, owned by Controls): one entry per
  move with its id, display name, the gesture pattern that triggers it, and its
  gamepad and mouse descriptions. Every system refers to a move by its catalog id, a `StringName` such as `&"snap_shot"` (saves store it as a string).
- **Recognising gestures** (`scripts/input/`, Controls) turns stick or mouse
  paths into a move id on `Skater.Controls` (for example `move_request`). The
  AI requests moves through the same field.
- **Doing the move** (Physics): the blade path, puck behaviour, shot speed and
  accuracy for each move id, read from `PhysicsProfile`, plus the ~220° arc
  limit and how grip changes it. Two hands on the stick in the front ~90° of
  travel and one hand beyond that, which trades control for reach.
- **Knowing the move** (Mechanics): which move ids a player has unlocked and
  how they unlock (`PlayerProfile`), exposed as `Skater.knows(move_id)`. A
  move the skater hasn't learned is not performed; the gesture falls back to
  a basic stickhandle or shot.

### 4. Match events (owned by Game mechanics)

Not built yet; `game.gd` calls `BoxScore` directly until it is. Gameplay code
will report what happened (shot, goal, save, pass completed,
giveaway, takeaway, hit, penalty, injury) through one signal hub. Stats,
progression and the HUD subscribe to it rather than calling into each other or
reading `game.gd` internals.

## Demo seasons (current goal)

Sean asked for a playtestable build: one season in a low tier and one in a mid
tier, crisp gameplay, AI that plays like the tier you're in, a developer menu
on the tilde key, and a full rink environment that can be explored later.

- **Mechanics leads the build.** That covers the two seasons start to finish
  (hub, schedule, games, standings, playoffs, tryout into the next tier) and
  the tier definitions in `league_tiers.gd`. Each tier sets its rating ranges
  and a `TierAI` set of AI parameters.
- **Tier-adaptive AI (Physics).** On-ice AI reads `TierAI` values such as
  reaction time, read and anticipation, passing vision, positional discipline,
  aggression, and goalie reaction and positioning. A beer-league game should
  look scrambly and a mid-tier one structured. These knobs are separate from
  ratings, so a skilled player can still be in a disorganised league.
- **Developer menu (PM), `scripts/dev/dev_menu.gd`, autoload `DevMenu`.**
  Built: Player (ratings, injury, fatigue, move unlocks), Match (score,
  clock, period, game speed, physics mode, autoplay), Career (tier, invites,
  save) and Sim (rounds, regular season, full season, next season) tabs, plus a
  `-- --test=devmenu` CI self-test. Tilde (`~`) toggles an overlay in
  any build. It can edit the controlled player's ratings, the score, the
  clock and period, the tier and the season day; it can sim to the end of the
  game or the season, give injuries, unlock moves, show AI debug and change
  game speed. It changes game state only through the owners' public functions,
  and it never saves those edits into the career unless asked to.
- **World and asset design** makes the meshes and the props kit, and Rink
  environment places them. Asset design owns how a thing looks; Rink
  environment owns where it goes and how it behaves. Rink environment can
  make venue-only pieces itself; anything reusable moves into the library. Renovation variants
  (worn, repaired, renovated) of a prop are made by Asset design and switched
  by Rink environment.
- **Rink environment.** The building is its own scene,
  `scenes/venue/venue.tscn`, which the match scene instances around the ice.
  Build it at real human scale with walkable floors, doors and collision, so
  an explorable player can be added later without rebuilding it. Rooms are
  modular and each has an `age`/renovation state (worn, repaired, renovated),
  so the renovation story can swap them later. Keep the voxel style, and stay
  within budget: the full 5-on-5 game must still hold 60 fps on a mid-range PC.
- **UI** builds the hub, standings, schedule, box score and HUD screens in the
  chosen pixel-terminal style, and styles the dev menu.
- **Controls** continues with moves and sticks, and makes sure every menu works
  with a gamepad.

## Design decisions already made

- Theme and story: the player is improving and renovating a dated,
  ancient-feeling community rink. Systems, art and writing should support that
  arc: things start worn and old, and the player's work visibly upgrades them.
- UI style (chosen): the pixel-terminal "Mission Control" look in the spirit of
  Kerbal Space Program. Pixel fonts and pixel UI are rendered crisp on a
  high-res display (no glare or bleeding pixels), with terminal signatures such
  as `//` line prefixes and `----` dashed dividers. It is full colour from the
  start: no monochrome green or amber stage that unlocks colour later.
- Godot 4.7 with Jolt physics, GDScript, voxel art with oriented voxels. Physics at 120 Hz.
  New world code builds on the framework layer (`docs/FRAMEWORK.md`): `.vox`
  assets through the import plugin, props through `PropField`, big scenes
  through `ChunkStreamer`.
- One `Tuning.blend` value slides between simulation and arcade assists.
- Controls follow Slapshot Rebound: left stick moves, left-stick press dashes,
  right-stick press stops, right stick places the stick in a ~220° arc around
  the player (enough to reach behind for a wind-up, not a full circle), left trigger lifts the stick (stick lift on defence), right
  trigger tilts it. Keyboard and mouse get an equivalent mapping.
- The player controls one skater for the whole game, RPG style. No player
  switching.
- Full games: 5-on-5 plus goalies, 3 forward lines and 2 defence pairs with line
  changes, 3 periods of adjustable length.
- Career: seasons of 12-16 games plus playoffs. Skills improve and decay, players
  get injured, and good play earns tryout invites up the tiers from beer league
  to semi-pro/minor league.

## Built to grow into a rink sim

RinkGM will become a general rink management sim with open-world elements, so:

- The match is a self-contained scene (`scenes/main.tscn` today) that takes a
  setup (teams, lineups, rules) and reports a result. Something else (a season
  screen today, an open world later) loads it.
- Career, season and league state are saved under `user://` (JSON today,
  `user://career.json`) and never stored on match nodes.
- No autoload may hold live match state. The `CareerState` autoload carries the
  career and the next fixture between the hub and the rink, and that's all.
- Rink geometry stays data driven (`Rink` constants today) so other rink sizes
  and venues can exist later.

## Branches and PRs

- Branch from `main` once the demo (PR #1) is merged; until then branch from
  `claude/godot-hockey-demo-f8heus` and use it as your PR's base.
- One topic per PR, small enough to review. Rebase onto the latest base before
  asking for review.
- Sean reviews and merges. Nothing merges with red CI.
- Current merge order: demo (#1), then Physics (#5), then Controls (#3) and
  Mechanics (#4), which are both built on Physics. CI and docs (#2) is built on
  the demo. Whoever is later in the
  order merges the earlier branch in and resolves conflicts.

## Quality gate

`tools/ci.sh` runs on every PR (`.github/workflows/ci.yml`). It:

0. lints and format-checks the framework layer (`tools/lint.sh`: gdlint and
   gdformat from gdtoolkit, settings in `.gdlintrc`),
1. imports the project and fails on any script or parse error,
2. plays a full AI-vs-AI game headless (`-- --autoplay`) and fails on any
   runtime error, or if the game never prints its end-of-game stats,
3. runs every `tools/tests/test_*.gd` headless; each must exit 0,
   then the gdUnit4 suites in `tests/unit/`,
4. runs each in-game test mode named in `tools/tests/game_tests.txt` (one name
   per line) as `-- --test=<name>` with the full scene and autoloads; each must
   exit 0 and print `<name> test: all passed`.

Run it locally before pushing (`pip install "gdtoolkit==4.*"` once for the lint):

```
GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64 tools/ci.sh
```

Framework code (`framework/`, `addons/vox_import/`) has budget tests too:
`test_framework_props.gd` keeps ten thousand props under a frame budget and
fails when the prop or streaming layer gets slower; `test_framework_world.gd`
walks chunks in and out with their rows, the save, contact audio and the
runtime voxel surface.

Pure logic (season tables, progression, injuries) gets a `tools/tests/test_*.gd`
script. Those run with `--script`, so they have no autoloads; keep logic that
needs testing free of autoload dependencies.

Balance check for physics and AI changes: autoplay games should keep producing
a believable score, about 3-4 goals per 5-minute game in the current 3-on-3
demo. Say in the PR if a change moves that.
