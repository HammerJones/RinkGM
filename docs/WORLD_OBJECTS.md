# World objects: the foundation for a dense, interactive rink

**Status:** P0 (pipeline) and P1 (store and picking) built, 2026-10-20;
P2 onward not started. 20 props are assets (`data/props/`, `art/props/`),
every prop a room places has a row, every row has a name on look, handheld
props can be taken and dropped, and rows ride the owner save as `objects`.
**Owner:** the World objects thread (section 6 is the row in
`ARCHITECTURE.md`). The integration branch (PR #4) is the base.

What P0 and P1 built, where it differs from the plan below:

- A prop's three ages can be three `.vox` files (`vox` as a per-age map)
  when the shapes differ, which every prop converted from the coded kit
  needs; new props use one model and a `wear` rule (`weather`,
  `palette:<name>` from `data/props/palettes.json`, `tint:<hex>`).
  Manifests also carry `offset` (the file's shift off the model's grid,
  undone on load so ageing and speckle match the kit), `pivot`,
  `voxel_m` (handhelds use 0.0125 to 0.02 m voxels: a puck is one kit
  voxel across), `mesh` (`merged` for flat-faced shop props),
  `collision_cell` and `tri_cap`. `tools/prop_export.gd` writes all of it
  from a coded builder.
- Rows: `VenueKit.commit()` calls `WorldObjects.bake()` with every prop
  the room drew, so a row knows the MultiMesh instance that draws it and a
  taken thing is hidden without rebuilding the room. Baked rows are named
  `<room>.<prop>.<n>` in build order and come back from the room build;
  the save keeps only rows the player placed, moved, took or changed.
- Picking: the walker's physics ray bounds a segment that
  `WorldObjects.raycast()` tests against the rows' shape boxes along the
  hash cells; a small thing wins a near tie with the big thing it sits on.
- Tiers today: BAKED (the room's MultiMesh, or `ObjectField`'s one merged
  mesh for loose rows without a node) and LIVE (`LiveProp`, a rigid body on
  layers 3 and 4). A dropped thing is LIVE until it sleeps; sleeping bodies
  farther than 24 m from the walker go back to rows, loose rows within 24 m
  get a sleeping body while the cap (64) allows, nearest first.
  `ObjectWalk.status()` is on the dev menu's Walk tab. INSTANCED is P2.
- `take` puts the prop id in the grid bag (`ItemCatalog` reads the shape
  from the manifest); the row stays in the store flagged `held`, so a
  dropped cup is the cup that was taken. G drops the last thing taken.

Sean's direction: the world should feel like it exists and is worth exploring.
Props everywhere, and the things you see are things you can touch. References
are Shadows of Doubt (everything has a name, most things can be picked up,
opened, read or inspected) and Voxile (voxel things are physical). This doc
says why the current code can't get there by adding props, what the
foundation is, and the order to build it in.

## 1. Where we are

What the code does today, and why "more props" on its own won't work.

| | Today | Why it caps us |
| --- | --- | --- |
| **Prop authoring** | Every prop is GDScript: `scripts/art/props.gd`, `shop_props.gd`, `plant_props.gd`, `stick_props.gd`, about 4,200 lines and 135 builder functions, each a block of `add_box` calls, written three times for WORN / REPAIRED / RENOVATED. `VoxLoader` can read MagicaVoxel files but the repo has no `.vox` files. | Prop count is bounded by typing. `docs/world/DECOR.md` plans 110 decor props and 40 readables room by room; the design is far ahead of the pipeline. |
| **Placement** | `VenueKit.prop()` bakes a prop's voxels into the room's one merged mesh and drops a box collider. Rooms are 30 scripts under `scripts/venue/rooms/` and `scripts/venue/rec/`. | A baked prop is wallpaper: no name, no state, can't be looked at, taken, opened or pushed. The only live objects in the building are sticks (`StickProp`) and the gym ball. Layouts as code also means every new rink (five towns in `WORLD.md`) is more code. |
| **Interaction** | `VenueSpot`: a hand-placed point with five kinds (READ, JOB, SCREEN, SWITCH, USE), dispatched by an if-chain in `venue_walk.gd`. Inventory is 15 hand-listed items in `ItemCatalog`. | "Interactable" means "someone wrote a spot for it". The ceiling is what people remember to author. |
| **Saves** | Career, owner rink, settings and notes are separate files under `user://` (`career.json`, `owner_millbrook.json`, `world_settings.cfg`, ...). | Nowhere to record "this cup is now on the bench" that every system agrees on. |
| **Clocks** | `RinkSim.advance()` moves the rink clock; the walk, people and events each read it their own way. | Fine today; with thousands of stateful objects, one clock authority matters. |

What is already right, and should be generalised rather than replaced:

- **`StickField` / `StickProp`.** Resting sticks draw as one mesh; a stick
  becomes a rigid body only when disturbed, then sleeps and goes back into
  the field. That is exactly the tiering every object needs.
- **`RinkPeople`.** 900 people on MultiMeshes, brains that think in slices
  (near 0.25 s, far 1.2 s, at most 90 thoughts a frame). Objects need the
  same interest management.
- **Budget tests.** `test_venue.gd` and `test_rec_detail.gd` fail CI when
  triangles or draws exceed a cap. Keep that discipline and add object caps.
- **`Wear`** (three ages) and **`Look`** (shadow and mesh helpers), the voxel
  mesher, occluders per room, `MatchEvents` as a signal hub, dialogue and
  cast already as JSON under `data/world/`.

## 2. The three layers

### 2.1 Props as assets: `.vox` + manifest

A prop is a MagicaVoxel file plus a JSON record. No new prop is code.

```
art/props/<id>.vox                 the model (MagicaVoxel, 0.065 m voxels)
data/props/<id>.json               one record per prop (or one data/props.json)
```

```json
{
  "id": "coffee_cup",
  "name": "Coffee cup",
  "vox": "art/props/coffee_cup.vox",
  "size_m": [0.08, 0.1, 0.08],
  "mass_kg": 0.25,
  "tags": ["clutter", "canteen", "handheld"],
  "verbs": ["take", "inspect", "push"],
  "wear": {"repaired": "palette:clean", "renovated": "palette:new"},
  "inspect": "Hot Stove mug. Chipped on the handle side.",
  "sound": "ceramic",
  "shape": [[0, 0]]
}
```

- **Ages by palette, not geometry.** One model; WORN / REPAIRED / RENOVATED are
  palette remaps or a per-instance tint, applied by `Wear`. This alone
  removes two thirds of the authoring.
- **`PropLibrary`** loads the manifest once, caches meshes by (id, age, lod),
  builds a collider from the voxel bounds (box) or a simplified hull, and
  reports triangles. Everything that draws a prop goes through it.
- **Existing coded props** stay valid: `PropLibrary` falls back to
  `Props.mesh(id, age)` for an id with no `.vox`. Convert over time; no big
  bang.
- **Tools.** `tools/prop_sheet.gd` renders every manifest prop at three ages
  to one contact sheet. `tools/tests/test_props.gd` extends to: every
  manifest prop loads, has a collider, is under its triangle cap, and every
  verb is one the engine knows.
- **Sources.** Authored in MagicaVoxel by Sean or by threads (the format is
  simple enough to write from code), and CC0 voxel packs to seed hundreds of
  generic items quickly. `docs/ART.md` stays the filter on the look.

### 2.2 One record for everything placed: `WorldObjects`

Every placed thing is a row, the way `RinkSim` has parts and `RinkPeople`
has people. Pure data (`RefCounted`), saved as one key.

```gdscript
# WorldObject
id: StringName            # "lobby.cup.17", stable across saves
prop: StringName          # manifest id
room: StringName          # VenueRoom id
xf: Transform3D
state: Dictionary         # {"open": true, "on": false, "contents": [...], "read": true}
flags: PackedStringArray  # "keepsake", "owner", "placed_by_player"
tier: int                 # BAKED, INSTANCED, LIVE (render tier, not saved)
```

- **`WorldObjects`** holds the rows, a per-room spatial hash, `spawn()`,
  `remove()`, `set_state()`, `query(room, tags)`, `nearest(pos, r)`, and
  `to_dict()/from_dict()`.
- **Three render tiers, decided per frame by distance and state.**
  - *BAKED*: part of the room's merged mesh (what `VenueKit.prop()` does now).
    Still has a row, so it has a name and can be looked at.
  - *INSTANCED*: one MultiMesh per (prop, age) for repeated items with no
    live state (seats, cups, pylons). Per-instance custom data carries tint.
  - *LIVE*: a `Node3D` (static or `RigidBody3D`) only while something needs it:
    the player is holding it, it is moving, it is open, it is within a few
    metres and has a verb that needs a node. Promotion and demotion follow
    `StickField`'s awake and sleep rules.
- **Picking without nodes.** The walker's look ray hits the room collider;
  the hit point looks up the nearest row in the spatial hash. That is how
  every object gets a name and a prompt with no node per object.
- **Rooms place through the store.** `VenueKit.prop()` becomes a thin call
  that spawns a row and bakes it. Renovation rebuilds re-spawn from the rows
  in the save, so a cup Sean put on the bench is still there after the lobby
  is renovated (the keepsake rule in `DECOR.md` 0.2 becomes a flag).

### 2.3 Verbs on the object, not spots in the room

Interaction becomes a set of components the manifest names. The prompt is
built from the object's verbs; the if-chain in `venue_walk.gd` goes away.

| Verb | What it does | State |
| --- | --- | --- |
| `inspect` | close-up and the manifest's `inspect` text (the caliper popup is already this pattern) | `read` |
| `read` | a readable (`data/world/readables.json`) or a note | `read` |
| `take` / `drop` / `place` | into the grid inventory (`ItemCatalog` reads `shape` from the manifest), out of it onto a surface | row moves rooms |
| `open` / `close` | doors, drawers, lockers, the fridge, the lost-and-found box | `open` |
| `contain` | holds other rows (a locker with a bag with tape in it) | `contents` |
| `switch` | lights, machines, the kettle; raises a world event | `on` |
| `sit` | benches, chairs, the stands; NPCs use the same verb | occupied |
| `push` | a rigid body while LIVE (sticks today; chairs, pucks, cones, bins) | asleep |
| `use` | the escape hatch for job and screen spots; `VenueSpot` stays as an adapter for those only | |

Rules: a verb's code lives in `scripts/world/objects/verbs/`; it reads and
writes the row's `state` and emits a world event; it never reaches into the
room or the walk scene. NPC brains get the same verbs, so what the player can
do to a thing, a person can (a kid takes a cup, a parent sits).

### 2.4 Clutter: generated, seeded, from the decor plan

A per-room clutter pass places tagged props from the manifest by room
archetype and age, with a seed, following the tables in `DECOR.md`: tape
rolls and cups in the dressing rooms, a lost-and-found bin in the lobby, bags
by the benches, pucks that roll under things. Keepsakes are hand-placed rows
with the `keepsake` flag; clutter is regenerated per day unless a row was
touched by the player (`placed_by_player`), which pins it. Density is a
setting and a budget.

## 3. The wider foundation

These are the pieces that make the three layers hold up at open-world scale.

1. **One save.** `user://saves/<slot>/` with one manifest and one key per
   system (`career`, `rink`, `people`, `objects`, `world`, `settings`).
   Every system keeps its `to_dict()/from_dict()`; a `SaveGame` object
   gathers them. One place to version, one place to migrate.
2. **One clock.** `RinkSim.advance()` stays the only mover; everything else
   subscribes (`day_ended`, `minute`, `session_started`). Objects that change
   with time (the coffee goes cold, the snow pile grows) register with the
   clock, never poll `Time`.
3. **A world event bus.** `WorldEvents` alongside `MatchEvents`:
   `object_taken`, `object_placed`, `door_opened`, `switched`, `read`,
   `sat`, `broken`, `npc_saw`. Sound, NPC brains, quests, Gus's tutorial, the
   log book and reputation subscribe. No system calls another to say what
   happened. This is what makes an NPC notice you took their cup.
4. **Rooms as data.** A room layout JSON (walls, openings, floors, lights,
   prop rows, spots) built by one generic builder, with the 30 room scripts
   as the first exporters. Needed for the four other rinks and for
   renovation variants; also lets Sean move a ticket booth without a thread.
5. **Interest management.** Rooms are the streaming unit: a room the player
   can't see keeps its rows and nothing else. Towns are scenes. Object tiers
   and NPC think-slices share one "near set" so the budget is one number.
6. **Budgets as tests.** Add to the budget tests: rows per room, LIVE nodes
   at once (target under 64), MultiMesh instance counts, draws per room,
   and a walk through the building with clutter at full density that holds
   the frame time.
7. **A trunk.** Merge the integration branch (#4) into `main` and branch
   short-lived from there. Thread branches 100 to 400 commits apart is where
   integration pain comes from, and every foundation change here touches
   shared files.
8. **Local tools for Sean.** Godot 4.3 installed locally, MagicaVoxel, a
   `scenes/dev/prop_viewer.tscn` that lists the manifest and shows any prop at
   any age, and the contact sheet as a CI artefact.
9. **Destruction, scoped.** `VoxelModel` is a sparse grid, so a prop can lose
   voxels or split into chunks. Do it for a short list (glass, sticks, a
   chair, drywall you renovate) as a `break` verb, not as general
   destructibility.

## 4. Build order

Each phase ends with something Sean can walk through, and CI green.

| Phase | Delivers | Done when |
| --- | --- | --- |
| **P0 Pipeline** | `PropLibrary`, manifest, `.vox` loading with palette ages, 20 existing props converted, `prop_sheet` tool, prop test | Every manifest prop loads at three ages under its cap; the sheet is a CI artefact; nothing in the walk looks different |
| **P1 Store and picking** | `WorldObjects`, rows for every placed prop, tiers (BAKED + LIVE), look-at naming, `inspect`, `take` / `drop`, inventory from manifest, rows in the save | Walk the lobby: every prop has a name on look; take a cup, drop it in the office, save, load, it's there; LIVE count stays under 64 |
| **P2 Verbs** | `open`, `contain`, `switch`, `sit`, `push`, INSTANCED tier, `WorldEvents`, spots reduced to job and screen adapters | Lockers open with bags inside; lights switch and NPCs react through the bus; 500 extra pushable props in the building hold the frame budget |
| **P3 Clutter and decor** | Clutter generator from `DECOR.md`, keepsakes, readables as objects, 100+ new props from `.vox` | Every room in `DECOR.md` 1.x has its listed items; density setting; budget tests pass at full density |
| **P4 Rooms as data** | Room JSON, generic builder, exporters from the room scripts, second rink built from data | Harlow Falls' rink stands from JSON with no new room script |

## 5. What this is not

- Not a rewrite of the venue. Rooms keep building as they do; `prop()` gains
  a row. Baked stays the default tier.
- Not a new physics layer. LIVE rigid bodies use `StickProp`'s layers (3 and
  4), so the hockey sim, the walker's footing and the people navmesh never
  see them.
- Not a content push. Phases P0 to P2 add almost nothing visible; they make
  P3 cheap.

## 6. Ownership (proposed row for `ARCHITECTURE.md`)

| Workstream | Owns |
| --- | --- |
| World objects | `scripts/world/objects/` (`PropLibrary`, `WorldObjects`, verbs, clutter), `data/props/`, `art/props/`, `tools/prop_sheet.gd`, `scenes/dev/prop_viewer.tscn`. World and asset design owns how a `.vox` looks; Rink environment owns where rows go; Mechanics owns what taking a thing means for the career. |
