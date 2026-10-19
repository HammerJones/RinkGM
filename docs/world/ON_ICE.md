# On the ice: what's happening out there right now

Sean, canvas "On-ice activities": "4 different kinds of events: public
skate, broomball, figure skating, hockey." Identifiable, real, rink-related
events at any time of day, all physical and organic.

Code: `scripts/world/events/`. Data: `data/world/on_ice.json` (rosters,
pee-wee groups, demand, the rental counter, the racks) and
`data/world/drills.json` (29 drills). Test: `tools/tests/test_on_ice.gd`.
Walk it: `scenes/world/on_ice_walk.tscn -- --free-walk --event=<kind>`.

## 1. The controller

`OnIceSession.create(kind, ctx)` picks the controller for an event kind
(`on_ice.json` "controllers") and spawns its people and gear;
`OnIceSession.for_sim(sim, venue)` does it for `RinkSim.session_now()`.
Add it under the venue (venue space, rink centred on the origin) and it
runs itself (`auto_run`), or call `step(dt)` / `run_for(seconds)`.

| Kind | Controller | What you see |
| --- | --- | --- |
| `public_skate`, `special` | `OnIcePublicSkate` | the crowd demand brings, counter-clockwise, the rental line |
| `figure_practice` | `OnIceFigure` | before 09:00 private coaching (programmes); later, classes |
| `learn_to_skate` | `OnIceFigure` (class) | groups by skill crossing the ice with a coach |
| `figure_show` | `OnIceFigure` (show) | one skater at a time, the rest by the gate |
| `broomball` | `OnIceBroomball` | sneakers, brooms, an orange ball, 6 a side, one ref |
| `minor_hockey` | `OnIcePractice` (pee-wee) | 3 groups, 3 zones, divider pads, stations |
| `high_school`, `pro_practice` | `OnIcePractice` (team) | full ice, one team drill after another |
| `stick_and_puck` | `OnIcePractice` | everyone with their own puck |
| `beer_league`, `senior_hockey`, `tournament` | `OnIceGame` | warm-up, then ambient 5-on-5 with two refs |

Every body is an `IceSkater` (`ice_skater.gd`) moved by `OnIceMotion`:
momentum, a top speed, quicker stops than starts, steering round each other
(separation plus a sidestep round whoever is ahead), the boards
(`Rink.sdf`), the nets and any zone they're kept in. After each step a
positional pass pushes apart any two bodies that still overlap, so nobody
clips through anybody. A hard knock can put a shaky skater down; beginners
fall on their own now and then; a fallen skater slides, lies there, crouches
and gets up. Drawn with PeopleArt MultiMeshes (`OnIceDraw`), the same way
RinkPeople draws the stands.

Pucks, pylons, nets and pads are `IceGear`: pucks slide (about 0.35 m/s²),
bounce off the boards, posts, pads, pylons and skates, and stop in the
twine; a puck or a skate tips a pylon and it slides until it stops.

## 2. Public skate demand (`SkateDemand`)

```
expected = base(day type, hour) x season(month) x holiday x weather x price x reputation x line
```

- **base**: three hour curves in `on_ice.json`: school days (a handful at
  06:00, a few dozen after school), Friday (busy evening), weekend (150-165
  in the afternoon). School holidays use the weekend curve.
- **season**: by month, 1.35 in January down to 0.3 in June and July.
- **holiday**: Christmas (23-27 Dec) and New Year are **at capacity** from
  09:00 to 22:00; the Christmas break x2.4 (the schedule is cleared for
  public skates); March break x1.6, Family Day x1.8, Thanksgiving x1.4, the
  November PA day x1.3.
- **weather**: rain x1.2 and snow x1.1 drive people indoors; a cold snap
  (-15 C) x1.15; a blizzard x0.35; a warm day (15 C+) x0.75; a clear cold
  January or February day x0.85 (the pond and the park rink are open).
- **price**: (price / $4.00) ^ -0.9.
- **reputation**: 0.6 + 0.8 x ice_rep / 100.
- **line**: a rental line over 5 minutes puts walk-ups off, down to x0.5.
- capped at capacity (260).

Saturday 14:00 in October: about 120. Tuesday 06:00: 4. Christmas: 260.
`SkateDemand.from_sim(sim)` fills the context from a RinkSim (it also reads
`weather`, `temp_c` and `skate_price` if the sim ever has them).

## 3. Public skate

Mix (data): wobbly beginners hug the boards and sometimes just hang on to
them; kids zig-zag and a few play in the middle; couples skate hand in hand
(the follower holds the leader's outside hand); a speedy teen weaves through
at 7 m/s; regulars do laps. Everyone follows a counter-clockwise track a
lane's width in from the boards (`OnIcePublicSkate.flow()`).

About 45% rent skates. **The rental counter** (`SkateRental`) sits at the
ticket booth window, laid out from `Venue.places()["skate_rental"]` (the
customer's spot at the window) with `into` and `along` from the data:
cubbies by size on the booth's back wall (adult 1-13) and side wall (kids
Y8-Y13), a finite stock. Customers line up; a clerk asks the size, walks to
the cubby, grabs the pair, walks back and hands it over while the line
builds. Two windows; a third clerk works from behind. Clerks share the
booth without walking through each other. The wrong size (a size off: a
little unhappy; two off: unhappy, maybe a refund) or none left (unhappy,
likely a refund demand, they go home) lowers `happy`. Each use dulls and
dirties a pair a little.

Returned skates pile up on the counter until a free clerk (or the owner,
`player_put_away()`) puts them back in their cubbies. The **return rack**
upgrade (`buy_return_rack()`, or `sim.return_rack = true`) puts a sorted
rack on the counter: customers drop pairs on it and the clerks rent straight
from it, so there's no pile.

The owner serves too: `player_begin()` (the customer says their size),
`player_grab(size)`, `player_hand()`; `shelf_spot(size)` is where to stand.

**Gus** works the window at the very first public skate (no earlier public
skate in `sim.session_log`, or no `first_public_skate_done` flag).

**Marketing**: on the way out each skater rates the night: 0.45 x ice
rating + 0.3 x rental quality (sharpness and cleanliness; own skates count
0.75) + 0.25 x happiness. Above 0.6 some get hooked: `skater_hooked({name,
age, wants: "skates" | "hockey_gear", experience})`, and with a StoryWorld,
flags `pro_shop_leads`, `hooked_skates`, `hooked_hockey_gear`.

## 4. Hockey practices and the drills

`data/world/drills.json`, each with its layout (nets, pylons, a puck pile,
a feeder coach), its paths and its timing. Coordinates are in the drill's
area (u along, v across), so the same drill runs full ice, in an end zone,
or in a pee-wee station. Types: `lanes` (waves along paths: passes, shots,
stops, pivots, mohawks, back to the end of the line), `battle`, `game`
(small-area games, 4-net cross-ice), `tag`, `signal`, `circles`.

2-on-1 rushes, 3-on-2 rushes, 3-man weave, Hartford drill, breakouts,
overspeed, horseshoe, Oklahoma drill, corner battles, small-area game,
cross-ice games (4 nets), edge work (C-cuts), mohawk turns, figure eights,
pivots, stops and starts (Canadas), shooting gallery, down-low cycle,
goalie warm-up, tight turns, puck-handling slalom, give-and-go, backward
skating, sharks and minnows, red light green light, Russian circles,
crossovers round the circles, wide drive and net drive, pass and follow.

A `DrillRun`'s coach walks to the gear rack by the Zamboni doors, carries
the stack of pylons out and sets each one, then a bucket of pucks. When a
puck or skate knocks a pylon over the coach blows the whistle, the drill
stops, the coach skates over and fixes it, whistle, carry on.

**Pee-wee** (`minor_hockey`): the Puck Pups (5-7), the Sawdust Squirts
(8-11) and the Lumber Cubs (12-14) share the ice in three zones split by
black divider pads at the blue lines. The pads start on the rack by the
Zamboni room: a coach from each of the two younger groups and any rink
hands (`ctx.staff`) carry them out one at a time, far line first; the owner
can take a pad job with `claim_setup()` / `complete_setup()`
(`setup_needed(task)` fires for each). Kids warm up with laps of their own
zone meanwhile. Puck Pups: mini nets and light blue pucks only, 4 stations;
Squirts: one full net and minis, mixed pucks, 3 stations; Cubs: full nets,
one team drill. Stations rotate on the whistle every 7 minutes. The rink
owns 4 full-size and 8 mini nets; no group takes more.

**High school** (and the Dukes): full ice, the plan in `on_ice.json`; a zone
drill runs in both ends at once with half the team each; the 4-net drill
runs only when 4 nets are out; between drills everyone gathers round the
coach at centre ice. The Mallards are the in-house team; the Harlow Falls
Hawks and St. Brendan's Saints rent the ice.

**Nets** are Mechanics' nets job: `nets_out()` reads `sim.get("nets_on_ice")`
(a count of full-size nets, `{"full", "mini"}`, or a list of `{"size"}`)
and assumes everything's out when the sim doesn't say. A practice short of
nets has its coach at the Zamboni gate waving (`nets_needed(full, mini)`).

## 5. Figure skating and broomball

05:00 figure: 4-8 strong skaters with 2-3 coaches: footwork across the ice,
jumps (backward approach, take-off, air time with rotations, a landing glide
or a fall), scratch spins, spirals, a word with the coach at the boards.
Afternoon and learn to skate: three levels (Snowflakes, Stage 2, STAR 1),
each in its own third with a coach, crossing on the whistle.

`OnIceFigure.ice_satisfaction(ice)`: warm (-3.5 C) and thick (36-50 mm)
ice; hard cold ice is worse than a touch warm. `flood_request()`: the heavy
flood at 04:45 they want before 05:00 (for the ice sim and the schedule).

Broomball: after the beer league, college and community teams in sneakers.
`grip()` is snow on the ice (0.25 or more is good) times dryness; on a
fresh, wet flood they slip all night.

## 6. Hockey games (ambient)

For games the player isn't in. Teams wait on their benches until the nets
are out, a player carries a bucket of pucks out to centre and the Zamboni
doors are shut (`Bay rink door`, or `sim.zamboni_doors_closed`); then a
5-minute warm-up (laps of their half, shots on their own goalie), then
5-on-5 with goalies: faceoffs, carries, passes, shots, saves, goals, line
changes on the fly through the bench gates, two refs following the play.
PLACEHOLDER(Mechanics): the clock and rules come from a `LeagueRules`
global class with `for_event(kind)` when it exists; until then 20-minute
running-clock periods. The real match engine is untouched.

## 7. Signals

| Signal | When |
| --- | --- |
| `blade_carve(pos, speed)` | each skating stride (only emitted when connected), turns, landings |
| `stop_spray(pos, speed)` | a hockey stop, a jump landing |
| `puck_hit(pos, what, speed)` | `boards`, `post`, `pylon`, `pad`, `net`, `skate`, `stick`, `goalie` |
| `whistle(pos)` | a ref: faceoffs, goals, a covered puck, period ends |
| `coach_whistle(pos)` | drill starts, pauses for a pylon, station rotations |
| `crowd_reaction(kind, strength)` | `goal`, `save`, `ooh`, `hit`, `applause`, `giggle`, `period_end`, `final` |
| `skater_fell(pos, role)` | anybody down |
| `nets_needed(full, mini)` | a practice or game waiting on nets |
| `setup_needed(task)` | a divider pad to carry out |
| `skater_hooked(info)` | a public skater wants skates or gear |
| `refund_demanded(info)` | a rental customer wants their money back |

Ice wear: every half second each skater calls `ice.wear(pos, amount)` when
the ice has it: metres skated x 0.01, plus 0.05 for a hockey stop, 0.04 for
a jump landing and 0.02 for a fall.
