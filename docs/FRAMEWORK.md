# The framework layer

**Status:** built 2026-10-20 on the integration branch; nothing is ported
onto it yet. This doc is the walkthrough: what each piece is, why it exists,
how to use it, and what the port looks like.

RinkGM's world code grew fast and grew its own versions of things Godot and
its ecosystem already do: a `.vox` reader, two meshers, hand-coded props, a
test runner, per-room physics. The framework is the thin layer that
replaces those with the engine's own machinery and a few libraries, so the
game code only has to do hockey. It is three things:

1. **A development environment.** Godot 4.6 with Jolt as the physics
   engine, gdUnit4 for tests, gdtoolkit for lint and format, Git LFS for
   binaries, CI pinned to the same engine build, and budget tests that fail
   the build when the frame cost grows.
2. **A runtime framework.** The `.vox` import pipeline, one mesher with
   baked ambient occlusion, a prop layer that keeps thousands of physical
   things cheap, and chunk streaming.
3. **An authoring layer.** The prop studio for looking at props as the game
   draws them, and the conventions that let MagicaVoxel be the art tool.

## 1. The environment

| Piece | Where | What it does |
| --- | --- | --- |
| Godot 4.6 | `project.godot` (`config/features`), `.github/workflows/ci.yml` | The engine build the project and CI run on. The whole gate passed on 4.6 with no script changes. |
| Jolt | `project.godot` (`physics/3d/physics_engine`) | The 3D physics engine for everything that is a body: props, loose things, walkers. The on-ice simulation (`Skater`, `Puck`, `Contact`) is its own impulse model and never touched the engine's physics, so it is unaffected. |
| gdUnit4 | `addons/gdUnit4/`, suites in `tests/unit/` | Unit tests with assertions, a panel in the editor, and a headless runner in CI. New unit tests go here; the end-to-end `tools/tests/test_*.gd` scripts stay. |
| gdtoolkit | `tools/lint.sh`, `.gdlintrc` | `gdlint` and `gdformat` on the framework layer. `tools/lint.sh --fix` reformats. The older `scripts/` tree is not covered yet; add paths to `tools/lint.sh` as files are brought up to the rules. |
| Git LFS | not yet | The repo is 16 MB of binaries today, which plain git handles. Switching to LFS later is one coordinated `git lfs migrate` on a day with no open branches; a filter rule added now would turn every existing image into a pointer on its next commit, so `.gitattributes` only fixes line endings. |
| Budgets | `tools/tests/test_framework_props.gd` | Ten thousand props in a `PropField`, 64 woken into rigid bodies, settled, demoted, a chunk streamed in and out, with the frame cost asserted. |

Run everything locally with `GODOT=... tools/ci.sh`; the lint step needs
`pip install "gdtoolkit==4.*"` once.

## 2. Assets: `.vox` in, `VoxAsset` out

```
art/props/coffee_cup.vox          the MagicaVoxel file (authored or generated)
  -> import plugin                 addons/vox_import (runs in the editor, re-runs on change)
  -> VoxAsset                      positions, palette indices, palette, voxel_m
  -> VoxelModel                    asset.to_model(): the kit's grid of coloured voxels
  -> Wear.weather(model, age)      the three renovation ages, unchanged
  -> VoxMesher.build(model)        the mesh, with ambient occlusion
  -> model.collision_boxes()       the shape-following boxes, unchanged
```

**`VoxReader`** (`addons/vox_import/vox_reader.gd`) reads the whole format:
every model in the file, the scene graph (`nTRN`, `nGRP`, `nSHP`) that
places them, the palette. A one-model file lands exactly where the old
`VoxLoader` put it, so nothing that reads `.vox` today changes.

**`VoxAsset`** (`vox_asset.gd`) is the imported resource. Because the editor
imports it, `load("res://art/props/cup.vox")` is instant, cached, and the
asset ships in exports. Scripts that run without the import step (anything
under `--script`) use `VoxAsset.load_any(path)`, which falls back to the
reader. The Import dock shows two options per file: `voxel_m` (0.065 for
the kit, 0.0125 to 0.02 for handhelds) and `recentre`.

**`VoxWriter`** (`framework/voxel/vox_writer.gd`) is the inverse: a
`VoxelModel` out to a `.vox` that MagicaVoxel opens. This is how Claude
authors props (build in code, write the file, render the sheet, look) and
how a coded kit prop becomes an asset Sean can edit.

**`VoxMesher`** (`framework/voxel/vox_mesher.gd`) replaces the two kit
meshers with one pass and adds baked ambient occlusion: each face corner
darkens by how many of its three neighbouring voxels are solid, and the
quad's diagonal flips so the shading has no seam. It costs nothing at
runtime (it is vertex colour) and is the biggest single step toward the
ray-traced look of the references.

```gdscript
VoxMesher.build(model)                      # speckle + AO, full detail
VoxMesher.build(model, {"greedy": true})    # flat faces merged, AO kept (distance / big repeats)
VoxMesher.build(model, {"ao": false})       # the kit's plain look
```

Numbers from the test on an 8x4x6 box with a bump: kit mesher 464
triangles, AO 464 (same faces, better light), AO + greedy 64, flat greedy
28 (equal to the kit's merged mesher).

## 3. Props: `PropField` and `PropRow`

The problem: "everything is physical" cannot mean a node per thing. Ten
thousand `RigidBody3D`s cost more in scene-tree overhead than in physics.
`StickField` already solved this for sticks (resting sticks are one mesh;
a stick is a body only while disturbed). `PropField` is that idea for
everything.

**A `PropRow`** (`framework/props/prop_row.gd`) is one placed thing: id,
prop id, mesh, shape boxes, transform, mass, free-form `state`, and the
handles the field uses. Pure data; `to_dict()` is what a save keeps.

**A `PropField`** (`framework/props/prop_field.gd`) holds rows and decides
their tier:

| Tier | Drawn by | Collides by | When |
| --- | --- | --- | --- |
| INSTANCED | one `RenderingServer` MultiMesh per mesh per 8 m cell | one `PhysicsServer3D` static body per 8 m cell holding every row's box shapes (shapes shared per mesh) | the default; thousands at once |
| LIVE | its own `RigidBody3D` (Jolt) with a `MeshInstance3D` | the body | while something needs it to move |

```gdscript
var field := PropField.new()          # one per room or per area
add_child(field)
var row := field.add(&"lobby.cup.17", &"coffee_cup", mesh, boxes, xf, 0.25)
field.wake(row).apply_central_impulse(Vector3(0, 2, 0))   # a shove, a drop
field.focus = walker.global_position                     # each frame or so
var hit := field.raycast(eye, eye + look * 2.5)            # -> PropRow or null
var near := field.nearest(pos, 3.0)
```

How the tiers move:

- `wake(row)` frees the static body, hides the instance, and adds a
  `RigidBody3D` with the row's boxes and mass. Returns the body.
- When the body sleeps (Jolt's own sleep) and is farther than
  `sleep_radius` from `focus`, or the live count is over `live_cap`, the
  field writes the resting transform back to the row and instances it
  again. Nearby sleeping bodies stay live so a second shove is instant.
- `wake()` past the cap demotes the farthest sleeping body first; if every
  live body is still moving it returns null, and the caller treats the
  thing as fixed for that moment.
- Picking is the physics ray the walker already casts: the cell body
  carries the field's instance id and the hit's shape index names the row,
  so `field.row_of(hit)` (or `raycast`) maps a hit back to its row. No
  node, no spatial hash of its own.
- A cell whose rows changed rebuilds its body once, at the start of the
  next idle frame, with every shape in place before the body enters the
  space. Rows are therefore visible to rays on the frame after `add`;
  `flush()` forces it sooner.

Per-cell MultiMeshes mean frustum culling and `draw_range` work per cell,
so a far room costs nothing to draw. Leaving the tree drops every server
object and keeps the rows; re-entering instances them again, which is what
chunk streaming needs.

Measured in the headless test (10k rows, 3 meshes, Jolt, one physics
step a frame, `framework/bench/prop_field_bench.gd` for trying it by
hand): adding 10,000 rows takes about 60 ms plus about 30 ms to build the
200 cell bodies; a frame with 10,000 resting rows costs under 0.01 ms;
with 64 live bodies among them about 0.35 ms; the bodies settle within
2 s and are demoted when the focus leaves. (First measurements used
Godot's time monitors, which in headless runs hold a stale value; the
test now measures wall-clock with the idle sleep off.)

## 4. Streaming: `ChunkStreamer`

```gdscript
var streamer := ChunkStreamer.new()
add_child(streamer)
streamer.register("res://scenes/venue/chunks/lobby.tscn", AABB(Vector3(0, 0, 0), Vector3(30, 6, 20)))
streamer.focus = walker.global_position
streamer.chunk_loaded.connect(func(path, node): ...)
```

A chunk is a `PackedScene` with a bounding box. When `focus` comes within
`load_radius` of the box the scene is requested through
`ResourceLoader.load_threaded_request` (no hitch), instantiated when ready
(at most `per_check` a tick), and freed past `unload_radius`. The gap
between the two radii stops a chunk flapping at the edge. A chunk scene
that contains a `PropField` brings its rows with it.

## 5. The prop studio

`scenes/dev/prop_studio.tscn` (script `framework/studio/prop_studio.gd`).
Run it from the editor, or `godot -- res://scenes/dev/prop_studio.tscn`.
It lists every `.vox` under `art/props/` and every coded kit prop, and
draws the selected one at its three ages side by side as the game draws it
(AO mesher, speckle, shadows, SSAO), with triangle counts per detail
level, voxel count, size in metres, and the collision boxes as a wireframe.
Keys: drag to orbit, wheel to zoom, `A` toggles AO, `G` toggles greedy,
`B` toggles boxes, `R` reloads from disk, arrows move through the list.
Drop a new `.vox` into `art/props/` and press `R`.

This is the authoring loop for both of us: Sean edits in MagicaVoxel and
looks here; Claude writes a `.vox`, renders the contact sheet
(`tools/prop_sheet.gd`), reads the image and adjusts.

## 6. What the port looks like

Nothing is ported yet. The order, each step a PR that keeps CI green:

1. **Props to assets.** The world-objects branch already converts the kit
   to `.vox` plus manifests. Rebase it on this layer: `PropLibrary` reads
   `VoxAsset` instead of `VoxLoader`, meshes through `VoxMesher`. The
   coded fallback stays until the last prop is converted.
2. **Rooms place rows.** `VenueKit.prop()` adds a `PropRow` to the room's
   `PropField` instead of baking into the merged mesh. The merged mesh
   stays for architecture (walls, floors, stands).
3. **Loose things.** `StickField`, `StickProp`, `LooseProp` and `PropGrab`
   become `PropField.wake()` and `sleep()`; the grab keeps its joint and
   its hands.
4. **The building streams.** Rooms become chunk scenes registered with a
   `ChunkStreamer`; occluders are baked per chunk.
5. **Lighting.** `LightmapGI` for the shell, SDFGI for props, SSAO on.
6. **The match scene** moves last and mostly unchanged: the skaters, the
   puck and the shot patterns do not touch any of this.

## 7. Rules for building on it

- A new prop is a `.vox` and a record, never code. A coded builder is a
  generator that writes a `.vox` (`VoxWriter`) and is then done.
- Anything placed in the world is a `PropRow` in a `PropField`. Scene nodes
  are for things that are unique and always live (doors, the Zamboni,
  the walker).
- One mesher: `VoxMesher`. One voxel reader: `VoxReader`.
- Budgets are tests. A change that makes `test_framework_props.gd` slower
  needs a number in the PR saying why.
- Framework code is linted and formatted; `tools/lint.sh --fix` before
  pushing.
