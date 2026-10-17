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

`bind_game` reads `score`, `clock`, `period`, `overtime`, `shootout`,
`fixture` and `puck.goal_scored` from the game, and sets the sun and ambient
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
stick look, Shift/L3 run, E/A open a door, 1 2 3 or the D-pad set the age of
the room you're standing in, F/Y fly.

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
`zamboni_bay`, `lighting`, `scoreboard`.

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

## Built for exploring later

- Human scale: doors 0.95–2.6 m wide and 2.2 m+ high (bench and box gates are
  1.25 m half doors), steps 0.18–0.225 m, aisle half steps 0.21 m.
- Every floor, wall, counter, seat row and door leaf has a box collider on
  physics layer 2 (`VenueKit.VENUE_LAYER`). Doors (`VenueDoor`) open and
  close and carry their own colliders. The boards and glass have a walker
  collider with gaps at the bench, box and resurfacer gates.
- `VenueWalker` is a first draft of an on-foot player (1.8 m capsule, steps
  up to 0.32 m). `tools/tests/test_venue.gd` walks it from the lobby to the
  home dressing room, up a grandstand aisle, up the lobby stairs into the
  office and into the resurfacer bay.

## Look and budget

- Voxel style: every block's faces are cut into 0.3–1 m tiles with colour
  jitter; worn rooms add grime, stains and missing pieces.
- Signs (`VenueSign`, `PixelFont`) are the pixel-terminal RINK-OS style in
  full colour: `//` headers, `----` rules, a 5x7 bitmap font drawn with
  nearest filtering, so they stay crisp. Worn screens have dead pixels.
- Budget (checked by the test): about 230–270k triangles in ~55 meshes plus
  ~43 signs, 12 lights with no shadows, no venue mesh casts sun shadows,
  one MultiMesh draw for the whole crowd with cheers animated in the
  shader. Building takes about 0.8 s when the match loads; the live
  scoreboard redraw costs about 0.5 ms once a second.
