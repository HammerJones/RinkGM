# RinkGM open world: the region

Owned by the World and asset design workstream (see `ARCHITECTURE.md`). Sean
chose region scale on 2026-10-17: several towns, each with its own rink,
joined by a road map, growing out from the home rink. This is the plan; the
code will live in `scripts/world/` and `scenes/world/`.

## The idea in one line

A snowy valley of small hockey towns. You start at the tired community rink in
your home town, and climbing the league ladder takes you further down the
road, to bigger towns with better rinks, while you renovate your own.

## The map

Five towns on one valley road, one per step of the ladder, so the career and
the map grow together. Names are placeholders.

| Town | Size | Rink | Tiers played there | Unlocks |
| --- | --- | --- | --- | --- |
| Millbrook (home) | Village, one main street | Millbrook Community Arena, the 1970s rink you renovate | Beer League D and C | Start |
| Harlow Falls | Small town | Twin-pad municipal rink, 1990s, tidy but plain | Beer League A | First away game |
| Kessler | Mill town | The old barn: wooden roof trusses, standing room, loud | Senior AAA | Tryout invite to Senior AAA |
| Port Ainsley | Lake town | Lakeside arena, plus an outdoor pond rink on the frozen lake | Semi-Pro | Tryout invite to Semi-Pro |
| Duncannon | Small city | A modern 5,000-seat arena, the benchmark for "renovated" | Minor League Pro | Tryout invite to Minor League Pro |

Each league's other teams are based in these towns too, so away games really
are away: a Beer League C road game in Harlow Falls is played in Harlow
Falls' rink. Distances run about 10 to 25 km between neighbours, roughly 80 km
end to end.

## Two layers

The region is too big to walk at 1:1 and stay buildable, so it has two layers.

1. **Region map.** A top-down map of the valley in the Mission Control pixel
   terminal style: towns as nodes, the road as lines, your car's position, the
   date and the next fixture. You pick a town and travel; the trip costs time
   on the career's calendar `day` (`CareerState`), so a road game eats an
   evening. Later this can become a drivable road.
2. **Towns.** Each town is a walkable scene about 200 x 200 m around its rink:
   the rink building's outside, its parking lot, a short main street (diner,
   pro shop, gas station, a few houses), snowbanks, street lights and trees.
   Walk in the front door and you're in the rink, which Rink environment
   builds.

## Data

`scripts/world/region.gd` holds the map as data, the same way `Rink` holds the
rink's numbers:

- `towns`: id, name, map position, size, palette accent, the rinks in it.
- `roads`: pairs of town ids with a length in km.
- `rinks`: id, name, town, venue id (Rink environment's layout), capacity,
  and its starting age (`Wear.WORN`, `REPAIRED` or `RENOVATED`). Only
  Millbrook starts worn; the others are fixed at the age that fits their story.
- Teams in `league_tiers.gd` get a `home_rink` id, so a fixture knows where
  it is played.

What changes during a career (unlocked towns, Millbrook's renovation state,
where you are) goes in the career save under a `world` key. Mechanics owns the
save format, so that key is agreed with them first.

## The look

- The same voxel style as the rink (see `docs/ART.md`), deep winter: snow on
  roofs and verges, ploughed roads, early dark with sodium street light.
- Buildings use 0.25 m voxels so a town stays cheap; street props (benches,
  bins, signs, cars, mailboxes) use the props' 0.065 m voxels and come from
  the props kit, aged with `Wear` like everything else.
- Each town gets one accent colour from its rink's team colours on signs and
  awnings, so towns are easy to tell apart at a glance.
- The far view (hills, pine forest, the lake) is low-detail backdrop meshes
  built with `build_mesh_merged`.

## Who does what

| Piece | Owner |
| --- | --- |
| Region data, town scenes, building and street kit, rink exteriors, backdrop | World and asset design |
| Rink interiors for every venue, placement inside, switching ages | Rink environment |
| Calendar, travel time, home rinks on teams, the save's `world` key | Game mechanics, with this thread |
| Region map screen (RinkOS panel) | UI, from this thread's map data |
| Walking controls in towns | Controls |

## Build order

1. **W1 Data and map.** `region.gd`, home rinks on teams, a first region map
   that lists towns and loads the match at the right town's rink.
2. **W2 Millbrook.** The home rink's outside at all three ages, the parking
   lot and main street, walking in through the front door.
3. **W3 The other four towns,** built from the W2 kit with their own rink
   exteriors and accents.
4. **W4 Extras.** The outdoor pond rink at Port Ainsley, the drivable road,
   day and night.

## Open questions

- Are five towns right, or should some tiers share a town?
- Fictional valley (the default here) or loosely based on a real region?
