# RinkGM architecture and team rules

RinkGM is built by several parallel workstreams (Claude threads plus Sean). This
file is the contract between them: who owns which files, the interfaces they
meet at, and the bar a change has to clear. If you need to break a rule here,
change this file in the same PR and say why.

## Workstreams and file ownership

| Workstream | Owns |
| --- | --- |
| Physics | `scripts/game/skater.gd` (skating, blade, puck handling, shots, passes, checks), `puck.gd`, `goalie.gd`, rink collision in `rink.gd`, `scripts/core/tuning.gd`, the fixed-step sim loop in `game.gd` (`_physics_process`, body and puck contact) |
| Game mechanics | `scripts/career/` (player attributes, progression, injuries, season, playoffs, league tiers, saves), match rules in `game.gd` (periods, lineups, line changes, game length), stats, the match event hub |
| Controls | `scripts/core/input_setup.gd`, `scripts/input/` (human controller, device handling, bindings). Only `scripts/input/` reads `Input` |
| UI and styling | `scripts/ui/`, `assets/ui/` (Theme resource, fonts with their licences) |
| Project manager | `docs/`, `tools/`, `.github/`, `README.md` |
| Art (shared) | `scripts/art/`, `scripts/voxel/`, `art/` |

Editing a file you don't own is fine for a small, clearly commented hook. Tell
the owner, and keep the hook to a call into code that lives in your own area.

## Shared interfaces

### 1. Player skills: `Skills` (owned by Game mechanics)

`scripts/career/skills.gd` holds 1-100 values:
`speed`, `agility`, `stick_handling`, `shot_accuracy`, `shot_power`,
`shot_release`, `pass_quality`, `hitting`, `toughness` (plus any stamina or
endurance stat mechanics adds). Mechanics decides what a skill means and how it
grows or decays. Gameplay code reads a skill only through
`Skater.skill(name)`, which returns 0..1. Physics owns the **one** place that
turns those into physical numbers; nothing else converts.

Fixed anchors from Sean's design:

- `speed` 100 is a top skating speed of 25 mph (11.2 m/s).
- `shot_release`: an instant shot is always possible; at low skill it is weak
  and inaccurate, and it gets stronger and more accurate as the skill rises.
- `pass_quality` near 100 makes it almost certain the intended teammate gains
  control.
- `agility`: sharp turns can work the puck loose and weaken hits.
- `stick_handling`: how fast the stick moves across the 90° arc and how likely
  the puck stays on the blade.
- `toughness`: how hard the player hits and how likely they are to be injured.

### 2. Input intent: `Skater.Controls` (fields owned by Controls)

The one struct a human controller and the AI both fill each tick. Controls owns
its fields (stick position in the 90° arc, stick lift, stick tilt, dash, stop,
...). Physics owns what the skater does with them. Skill-based limits (how fast
the stick can move) are applied in physics from attributes, never in the input
layer. The AI must drive skaters through the same struct, so anything a player
can do the AI can do.

### 3. Match events (owned by Game mechanics)

Not built yet; `game.gd` calls `BoxScore` directly until it is. Gameplay code
will report what happened (shot, goal, save, pass completed,
giveaway, takeaway, hit, penalty, injury) through one signal hub. Stats,
progression and the HUD subscribe to it rather than calling into each other or
reading `game.gd` internals.

## Design decisions already made

- Godot 4.3, GDScript, voxel art with oriented voxels. Physics at 120 Hz.
- One `Tuning.blend` value slides between simulation and arcade assists.
- Controls follow Slapshot Rebound: left stick moves, left-stick press dashes,
  right-stick press stops, right stick places the stick in a 90° arc in front of
  the player, left trigger lifts the stick (stick lift on defence), right
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

## Quality gate

`tools/ci.sh` runs on every PR (`.github/workflows/ci.yml`). It:

1. imports the project and fails on any script or parse error,
2. plays a full AI-vs-AI game headless (`-- --autoplay`) and fails on any
   runtime error, or if the game never prints its end-of-game stats,
3. runs every `tools/tests/test_*.gd` headless; each must exit 0,
4. runs each in-game test mode named in `tools/tests/game_tests.txt` (one name
   per line) as `-- --test=<name>` with the full scene and autoloads; each must
   exit 0 and print `<name> test: all passed`.

Run it locally before pushing:

```
GODOT=/path/to/Godot_v4.3-stable_linux.x86_64 tools/ci.sh
```

Pure logic (season tables, progression, injuries) gets a `tools/tests/test_*.gd`
script. Those run with `--script`, so they have no autoloads; keep logic that
needs testing free of autoload dependencies.

Balance check for physics and AI changes: autoplay games should keep producing
a believable score, about 3-4 goals per 5-minute game in the current 3-on-3
demo. Say in the PR if a change moves that.
