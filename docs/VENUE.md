# Venue: the building around the ice

`scenes/venue/venue.tscn` (script `scripts/venue/venue.gd`, class `Venue`) is
the rink building: stands, player benches, penalty boxes, rink glass, lobby,
the manager's office, both dressing rooms, the resurfacer bay, roof, lighting,
scoreboard and crowd. The ice, boards and nets stay in `scripts/rink/rink.gd`
(Hockey physics). The Rink thread for the venue owns `scenes/venue/` and
`scripts/venue/`.

## Using it

The match scene instances it around the Rink (already wired in `game.gd`):

```gdscript
venue = Venue.instantiate_for(fixture)   # colours, name, tier, crowd from the fixture
add_child(venue)
venue.bind_game(self)                    # scoreboard, goal cheers, lighting
```

`bind_game` reads `score`, `clock`, `period`, `overtime`, `shootout` and
`fixture` from the game and listens to `events.goal` (MatchEvents), and sets the sun and ambient
of the game's `WorldEnvironment` / `DirectionalLight3D` to suit the rink's
lighting. Nothing in the hockey simulation reads the venue.

Command-line switches (any scene that has a venue):

| Switch | Effect |
| --- | --- |
| `--no-venue` | leave the building out (A/B the frame cost) |
| `--venue-age=worn\|repaired\|renovated` | force every room's age |
| `--venue-crowd=0..1` | force attendance |
| `--venue-cam=x,y,z,lx,ly,lz` | view from a fixed camera (screenshots) |
| `--venue-stats` | print build time and the geometry budget |
| `--venue-walk` | explore the building on foot instead of playing |

The walk-around playtest is also `scenes/venue/venue_walk.tscn`
(`-- --tier=N` picks the league). WASD or left stick walk, mouse or right
stick look, Shift/L3 sprint, Space jump, Ctrl or C (held) crouch, E/A open a
door or use a spot (A jumps when nothing is in reach, B held crouches when no
panel is open), 1 2 3 or the D-pad set the age of the room you're standing
in, F/Y fly (Space and Ctrl then fly up and down).

Floor plans: `tools/venue_plan.gd` renders straight-down views of the
building cut at 2.6 m and 8.5 m, plus a JSON list of room bounds and doors.
It needs a renderer, so run it under xvfb (lavapipe is fine):
`godot --path . --script res://tools/venue_plan.gd -- --out=plan --age=repaired`.

## Layout (metres, rink centre is the origin, rink runs along X)

- Building: x ±46, z ±30, roof at 16 m. Rubber floor at y = 0 around the ice.
- Bench side (−Z): home bench x −11.4..−2.6, visitors 2.6..11.4, back wall
  at z −15.2 with gates; walkway; grandstand from z −17.5 (10 rows, 0.85 m
  deep, 0.42 m rise, seven sections with aisles); concourse on top at 5.1 m.
- Penalty-box side (+Z): home box, timekeeper, away box between x ±5.8, then
  the same walkway and grandstand mirrored.
- −X end: lobby (front doors, tickets, snack bar, trophies, viewing window,
  stairs) under a mezzanine at 4.5 m with the manager's office.
- +X end: home dressing room (z −14..−5), resurfacer bay (z ±5, roll-up doors
  to the rink and outside), visitors' dressing room (z 5..14). The old
  scoreboard hangs on this wall until it is renovated.
- +X/+Z corner: the ice plant room (x 36.7..45.5, z 14.3..28.1), door at
  z 23.7 facing the rink end, with the header in a 0.72 m floor trench
  (`plant_room.gd` places the kit's plant props in the layout of
  `art/tools/plant_room_preview.gd`; the shell leaves the trench out of its
  floor).
- Corners: open floor with fire exits; clutter changes with the shell's age.

## Rooms and renovation

Each room is a `VenueRoom` child of the venue with a stable `room_id` and an
`age` (`WORN`, `REPAIRED`, `RENOVATED`). Changing it rebuilds only that room:

```gdscript
venue.set_room_age("lobby", VenueRoom.Age.RENOVATED)
var save := venue.get_state()     # {room_id: age}; store it with the career
venue.apply_state(save)
venue.room_at(position)           # which room a point is in (smallest wins)
```

Room ids: `shell`, `roof`, `stands_bench`, `stands_box`, `benches`,
`penalty_boxes`, `glass`, `lobby`, `office`, `locker_home`, `locker_away`,
`zamboni_bay`, `plant_room`, `lighting`, `scoreboard`.

Default age comes from the home club's tier: beer league rinks are worn,
Senior AAA and Semi-Pro repaired, Minor Pro renovated, with a few rooms one
step off per club so rinks differ. Attendance also follows tier
(3% of seats at the bottom, about 72% in Minor Pro, more in the playoffs).

To add a room: make a script that `extends VenueRoom`, set `room_id`,
`bounds` and `spawn` in `_ready()`, draw it in `build(kit)` with
`VenueKit` (`block`, `aged_block`, `slab`, `wall_x`/`wall_z` with
openings, `stairs`, `glass`, `glow`, `sign`, `add_door`), branch on
`kit.age` / `kit.by_age(worn, repaired, renovated)`, and add a node for it to
`venue.tscn`.

## The recreation centre wing

The rink was once part of a community athletic centre, and the rest of that
complex sits north of the arena (z -30 to -60). `RecPlan`
(`scripts/venue/rec/rec_plan.gd`) is the floor plan: 18 rooms as rectangles
and every door, opening and window as data. Each room is a `RecRoom` script
in `scripts/venue/rec/` that reads its rectangle and builds walls, doors,
lights and furniture in code, in all three ages.

- Layout: the front lobby and desk at the west end (main entrance from the
  parking lot), a long hall running east, with the pro shop, washrooms,
  officials and first aid, storage, dressing rooms 3 to 6, the electrical and
  boiler rooms on its south side, and the offices and meeting room, gym,
  weight room, community hall and workshop with the loading bay on its north
  side. A short link at x 40 joins the hall to the arena concourse. `RecSite`
  lays the parking lot, sidewalks, light poles and the entrance canopy.
- Matches leave the wing out (`Venue.instantiate_for(fixture)`); walking and
  the tools build it (`instantiate_for(fixture, true)`, `has_wings()`), so the
  match budget is unchanged.
- Walls in the wing add occluders (`kit.occlude_walls`), and the project turns
  occlusion culling on, so a walker draws the room they are in, not the wing.
- World's detail pass (`scripts/world/rec_detail.gd`) adds the small things to
  the community hall, offices, lobby, officials' rooms, washrooms and hall,
  one `# World:` call per room. The weight room's mirror is a `PlanarMirror`
  (`scripts/world/planar_mirror.gd`): a SubViewport camera mirrored across
  the glass, rendering only while someone near is looking at it.
  `tools/rec_room_stats.gd` prints draws and triangles per wing room.
- `tools/tests/test_rec_centre.gd` checks the rooms, door sizes, budget
  (1.4M triangles, 700 draws with the arena) and walks eight short routes.
- `tools/venue_shots.gd -- --out=x --wings [--age=..] [--view=name:x,y,z,lx,ly,lz]`
  renders eye-level views; `tools/venue_plan.gd --wings` renders the plan with
  walls drawn where the cut crosses them.

## The puck and the building

The glass is real: 1.2 m above the boards along the sides, 1.4 m in front
of the penalty boxes, 2.4 m at the ends and corners, and open over the
player benches. `VenuePhysics` holds those heights, and the glass you see
and the board colliders both use them. Kit props collide with their
shape-following boxes (`Props.collision_boxes`), and fans get one box per run
of neighbours in a row (`VenueCrowd`, about 140 boxes for a full house), all
on physics layer 2.

The puck stays Hockey physics' and the whistle stays the game's. The
interface between them and the building is static:

- `VenuePhysics.clears_glass(pos, radius)`: true once a puck touching the
  boards is above the glass there. Below it, `Rink.confine` keeps it in.
- `VenuePhysics.contact(space, pos, vel, radius, dt)`: the first contact of
  this step's move with the building, `{point, normal, fraction,
  restitution, friction}`, or `{}` when clear.
- `VenuePhysics.bounce(vel, contact)`: the velocity after it, if the caller
  has no contact model of its own.

The intended flow: the puck checks `clears_glass`, and once true it flies
under gravity with `contact`/`bounce` and emits an event, and the game blows
the whistle and faces off at the nearest dot. `tools/tests/test_puck_out.gd`
runs that flow with a stand-in integrator.

## The first hour (RINK_SIM M1)

`--venue-walk` starts the first hour at Millbrook (RINK_SIM.md 1.6):
05:00 on Monday in the dark lot, with the front doors locked and the ice
lights off. `--free-walk` gives the old walk from the lobby.

Spots (`VenueSpot`) are the things you can press use on. Rooms place them
with `VenueRoom.add_spot`, so they come back after a renovation rebuild, and
`VenueWalker.nearest_spot` picks the one you are looking at. There are five
kinds:

- **READ** opens a note from `data/venue/notes.json` or a readable from
  `data/world/readables.json`. Examples are Gus's envelope under the mat
  (it gives the keys), the door of notes, the binder, the power bill and the
  manuals.
- **JOB** hands over to a World mini game: the compressors' oil, Doris's
  plugs (she needs them from the parts drawer first) and her blade. The
  glycol thermometers are the plant round, which has no scene and happens
  on the spot.
- **SCREEN** asks UI for a screen: the office phone, the desk, the corkboard
  (Gus's goals), the ice grid and the log book.
- **SWITCH** works a building system: the lighting panel in the lobby turns
  the ice lights on, and the metal halides take about 40 s to warm up.
- **USE** covers anything else by id. The workshop's machines have USE stubs
  (`{"machine": id, "stub": true}`) for their mini games to come. The
  weight room's `train_*` spots (`{"train": machine}`) are one 15-minute set
  each; the machine props stand where they are, listed in the room's
  `MACHINES` with the spot id each one serves, and
  `machine_spots(age)` gives where a player stands at each. The snow pit is a JOB,
  the sim's `dump_snow`, and the pile out back is Mount Doris.

`WalkStory` decides what using a spot does and keeps the RinkSim clock
(about 1.75 sim minutes per real second). The walk scene does what it says:

- Screen spots open UI's rink office (`scenes/ui/rink_office.tscn`) on the
  walk's sim: the ice grid, log book, corkboard (Gus's goals) and the desk
  (jobs). Q, Esc or B leaves it. The phone has no screen yet, so it shows a
  plain panel. `screen_requested(id, sim)` fires for every screen spot.
- A job instances its scene under `scenes/world/jobs/`
  (`compressor_oil_service`, `doris_plugs`, `doris_blade`; the contract is
  World's). The walk calls the root's `begin(ctx)` with
  `{sim, job, target, room, args}`. When its `finished(result)` signal
  fires, `WalkStory.finish_job` runs the job with the args merged with
  `result`, through `RinkLife.job` when the walk has one (`WalkStory.life`),
  else `RinkSim.job`.
- If the scene isn't built yet, the job offers the quick way instead.
- Texts prefer World's readables (`note_door_oil`, `note_screwdriver`,
  `note_doris_dash`) and fall back to `data/venue/notes.json`.
- The sim owns the building's state. The breaker calls `sim.set_lights(on)`,
  the lamps follow `sim.lights_on`, and the pit heap follows `sim.snow_pit`.
  The lamps' glow still warms up over the venue's 40 s, because the sim
  warms them in quarter-hour steps.

Inside an owner career (`CareerState.rink`), the walk uses the career's sim
and clock (`RinkLink.advance`) and leaves its day and minute alone. The
first hour's set-up applies only on the career's first morning. Any other
time, the walk starts in the office with the doors unlocked. The office desk
saves and goes back to the rink office. When the clock stops for the
owner's game, the walk saves and sends the player to the hub. Without a
career, the walk runs a fresh M1 sim (`RinkSim.create_m1`).

`tools/tests/test_first_hour.gd` plays the hour headless.
`tools/venue_shots.gd --first-hour [--lights]` renders it.

## Places for people

`Venue.places()` is for World's RinkPeople. It returns where people go as
`{key: Array[Vector3]}` in venue space. The keys are canteen (the snack bar
line, front first), washroom, glass, pro_shop, skate_rental, bench, entrance,
lobby, office, plant_room, zamboni_bay, dressing_room and penalty_box. The
washroom and pro shop are in the rec wing. A room lists its own with
`places()`, and Venue adds the spawns of the rooms in `PLACE_ROOMS`. The stand
rooms' `seats()` gives `[[position, facing], ...]`. `tools/tests/test_places.gd`
checks that every place has a floor under it and room to stand.

## Built for exploring later

- Human scale: doors 0.95–2.6 m wide and 2.2 m+ high (bench and box gates are
  1.25 m half doors), steps 0.18–0.225 m, aisle half steps 0.21 m.
- Every floor, wall, counter, seat row and door leaf has a box collider on
  physics layer 2 (`VenueKit.VENUE_LAYER`). Doors (`VenueDoor`) open and
  close and carry their own colliders. The boards and glass have a walker
  collider with gaps at the bench, box and resurfacer gates.
- `VenueWalker` is the on-foot player: 1.8 m capsule, steps up to 0.32 m,
  walks at 2.2 m/s and sprints at 6.5 (built up over 0.4 s), jumps 0.45 m
  under real gravity with a little air steering, and crouches to 1.2 m (eyes
  at 1.1 m, 1.0 m/s), staying down while there's no headroom.
  `tools/tests/test_walker_moves.gd` checks those numbers on a test floor. `tools/tests/test_venue.gd` walks it from the lobby to the
  home dressing room, up a grandstand aisle, up the lobby stairs into the
  office and into the resurfacer bay.

## Look and budget

- Voxel style, following `docs/ART.md`: architecture is blocks whose faces
  are cut into 0.3–1 m tiles with colour jitter, in the old-rink palette
  (`Wear`: concrete, institutional mint, harvest gold, burnt orange, wood)
  when worn or repaired, and steel, white, charcoal and the home club's
  colour when renovated. Worn rooms add grime, stains and missing pieces.
- Props come from the World and asset design kit (`Props.mesh(id, age)`,
  `scripts/art/props.gd`) at the room's age, placed with `kit.prop()` and
  drawn as one MultiMesh per prop and room: arena seats (low detail), rink
  glass panels and frames, lockers, player benches, penalty boxes, concession
  counters, scoreboard housings (text placed with `Props.scoreboard_faces`), ceiling lights,
  the resurfacer, vending machines, bins and the old hand-painted rink sign.
  Doors stay venue pieces because they swing and collide.
- Signs (`VenueSign`) use `RinkOS.sign_3d()` per `assets/ui/STYLE.md`:
  Silkscreen for titles, VT323 for numbers, clocks and prices, on a CRT
  panel, crisp and in full colour; only the housing looks worn.
- Budget, about 0.6M triangles and 180-200 draws (checked by `tools/tests/test_venue.gd`, numbers printed per age):
  13 lights with no shadows, no venue geometry casts sun shadows, props and
  the crowd drawn as MultiMeshes (the crowd's cheers run in its shader), and
  the live scoreboard only changes Label3D text.
