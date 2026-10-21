# The framework layer

**Status:** built 2026-10-20 on the integration branch; nothing is ported
onto it yet. This doc is the walkthrough: what each piece is, why it exists,
how to use it, and what the port looks like.

RinkGM's world code grew fast and grew its own versions of things Godot and
its ecosystem already do: a `.vox` reader, two meshers, hand-coded props, a
test runner, per-room physics. The framework is the thin layer that
replaces those with the engine's own machinery and a few libraries, so the
game code only has to do hockey. It is three things:

1. **A development environment.** Godot 4.7 with Jolt as the physics
   engine, gdUnit4 for tests, gdtoolkit for lint and format, Git LFS for
   binaries, CI pinned to the same engine build, and budget tests that fail
   the build when the frame cost grows.
2. **A runtime framework.** The `.vox` import pipeline, one mesher with
   baked ambient occlusion, a prop layer that keeps thousands of physical
   things cheap, and chunk streaming.
3. **An authoring layer.** The prop studio for looking at props as the game
   draws them, and the conventions that let MagicaVoxel be the art tool.

Sections 1 to 8 are the pipeline, props, streaming, objects and lighting;
9 to 12 are the world conventions (chunks that remember), contact audio,
the runtime voxel surface and the render benchmark; 13 is the demos.

## 1. The environment

| Piece | Where | What it does |
| --- | --- | --- |
| Godot 4.7.2 | `project.godot` (`config/features`), `.github/workflows/ci.yml` | The engine build the project and CI run on. Moved from 4.6 to 4.7.2 with no script changes; the whole gate passes on both. |
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
that contains a `PropField` brings its rows with it. The scene's scripts
are loaded on the main thread just before the request (GDScript compiled
on the loader thread cannot resolve class names it has not seen, and the
load would never finish); meshes and textures still load in the thread.

## 5. Authoring props: the generator and the sheet

Two kinds of prop live in `art/props/`:

- **Kit props** at 0.065 m voxels, built from boxes (`scripts/art/`) or
  drawn in MagicaVoxel: furniture, architecture, anything seen from a few
  metres away.
- **Hero props** at 1 to 5 mm voxels, 100 to 250 voxels across, in the
  look of the four reference models Sean supplied on 2026-10-20 (a CRT
  television, an open record player, a micro cassette, a long truck, kept
  hollowed in `art/props/` with `art/props/THIRD_PARTY.md`): rounded
  corners, two-tone dithered surfaces, cream label plates with lettering,
  screws and grilles. Things the player picks up and looks at.

Hero props come from `tools/propgen/`, a Python generator (numpy and
Pillow only): a prop is a small signed-distance scene voxelised at its
resolution, with a palette lifted from the references, a 5x7 bitmap font
for labels (flat faces or wrapped around a cylinder), grilles, vent slots,
screws and dither. `tools/propgen/library.py` holds the retro set
(boombox, VCR, VHS tape, desk phone, walkie-talkie, coffee mug, microwave,
wall clock, and the lobby pay phone booth built from a photo) and writes
each `.vox` with its manifest in `data/props/`; `--preview` adds a quick
render per prop. A prop from a photo is the same loop: proportions and
palette read off the picture, built, rendered on the sheet next to the
photo, adjusted; two or three rounds.

```
python3 tools/propgen/library.py                 # regenerate everything
python3 tools/propgen/library.py boombox --preview
python3 tools/propgen/hollow.py big.vox small.vox   # a solid MagicaVoxel model to surface voxels
GODOT=... tools/prop_sheet.sh                    # the contact sheet, as the game draws them
```

The sheet (`framework/studio/prop_sheet.gd`, run under a virtual display
with the software OpenGL driver) renders every prop with the baked AO mesh,
a key light, shadows and a floor, and writes `art/props/preview/sheet.png`
plus one image per prop. That is the review loop: a person opens the
sheet, Claude reads it, the generator changes, the sheet is rendered again.

Two things the generator settled that apply to every `.vox`:

- **Orientation.** MagicaVoxel models face -Y there. `VoxReader` maps a
  file's (x, y, z) to Godot's (-x, z, y), a proper rotation, so a model
  faces -Z with its right at +X, the kit's convention, and `VoxWriter`
  writes the same rotation back so exported files open in MagicaVoxel the
  right way round. (The older `VoxLoader` leaves imported models facing
  +Z; files round-tripped through it and the old writer need no change,
  they just read the same way they always did through it.)
- **Mesh baking.** The import plugin stores the greedy AO mesh, a flat
  low-detail mesh and the collision boxes in the `VoxAsset` (the
  `bake_mesh` import option), reading `voxel_m` from the prop's manifest.
  A 100k-voxel prop then loads in milliseconds; meshing it at runtime took
  1 to 4 s. Hero props are 20k to 130k triangles with AO (the dither is
  what stops faces merging); the low-detail mesh snaps colours to a coarse
  palette first (`quantize`), so the dither collapses and it comes out at
  a fraction of the faces, for distance and big repeats. Resolution is the
  other lever: triangles scale with the inverse square of the voxel size,
  and a handheld reads the same at 1.4 mm as at 1 mm.

## 6. Objects and interaction

`PropField` rows collide and draw; the object layer makes them things.

**`ObjectCatalog`** (`framework/objects/object_catalog.gd`): every prop
manifest in `data/props/` (and the coded kit behind them): name, verbs,
tags, mass, sound, inspect text, the inventory item shape, the baked AO
mesh and low-detail mesh from the imported `.vox`, the collision boxes.
Everything that spawns or names a prop reads it here.

**`WorldObjects`** (`framework/objects/world_objects.gd`): a registry over
one or more fields. `spawn("coffee_mug", xf)` makes a row with a stable id
(`coffee_mug.1`); `name_of`, `verbs_of` (a thing that is open offers
close), `get_state` / `set_state`; `act(verb, row, actor)` runs a verb and
emits `acted`. Built in: inspect, push (wake and shove), take (the row
leaves, an inventory item comes back with its state), drop (the item
comes back as a live row with a velocity), open, close, use (`used` is
emitted for the game). `add_verb` registers more. `to_save()` keeps only
rows the game placed, moved, took or changed, plus removed ids, so a room
laid out from code is rebuilt and then patched; `from_save()` applies it.

**`Interactor`** (`framework/objects/interactor.gd`): one ray from the
eye, blocked by walls; `hovered` is the row under the dot and it glows;
`prompt()` is the line for the HUD; `act("take")` picks the thing up.
Carrying is real-time physics, never a freeze: the body keeps simulating
in the hand, a velocity spring pulls it to the hold point every physics
step (it bumps into shelves and walls on the way), it turns with the
view, and a drop keeps its motion as a throw. The controls live here too,
the same in every scene, so the keyboard stays free for what a game adds:

| Input | Does |
| --- | --- |
| LMB | take into the hands; LMB again drops |
| RMB | throw what is held; shove what is looked at |
| E | the thing's own verb: open, close, use, read |
| Q | inspect (the manifest text, as a toast) |
| wheel | tumble what is held, top over bottom, four turns a revolution |
| ctrl + wheel | bring what is held nearer or farther |

**What the verbs do today.** `take` and `drop` are real. `push` is a real
shove. `inspect` shows the manifest text. `open`/`close` and `use` only
flip the row's `open` and `on` state and emit `state_changed` / `used`:
nothing yet lights a screen, plays a tape or heats a mug. Those are the
game's hooks (connect `used`, read the state when drawing). Which prop
offers what is its manifest's `verbs`; today: mugs, tapes, cassettes,
walkie-talkies, phones and the boombox can be taken; the microwave and
record player open; the boombox, phones, microwave, record player, TV,
VCR, walkie-talkie and pay phone can be used; the clock and the truck
only inspect. Nothing over 60 kg can be carried.

**`WalkHud`** (`framework/ui/walk_hud.gd`) is the one first-person
overlay, in the RINK-OS style: readout top left, the prompt as "[KEY]
VERB" pairs under the centre dot, toasts lower centre, a legend bottom
left, a centre panel for long text. The venue walk and every demo draw
through it and nowhere else (see "First-person overlay" in
`assets/ui/STYLE.md`).

**Tint and highlight** ride the field's MultiMeshes as per-instance custom
data and a live body's instance uniforms, read by one shader
(`framework/render/voxel_prop.gdshader`, `PropMaterial`): vertex-colour
albedo times a tint (the renovation ages, no mesh per age), plus the glow.

**`Layers`** (`framework/core/layers.gd`) names the physics layers the game
already uses (world 1, venue 2, props 3, walker 4, read 5) so new code
reads them from one place.

The objects demo (`scenes/dev/object_demo.tscn`) is a room with every
catalog prop on tables and the floor and a first-person body: walk up to
anything, it names itself, and the controls above apply; F5 saves and
reloads the rows.
`-- --test=objects` is its headless check (hover, prompt, carry, drop,
take, push, open, save, load); `tests/unit/test_world_objects.gd` covers
the catalog and the registry.

## 7. Detail, light and culling

**Level of detail.** A row with a low-detail mesh (every imported prop
has one: flat colours, dither collapsed, no AO) gets a second MultiMesh
per cell. The full batch is visible out to `lod_distance`, the low one
from there to `draw_range`, with a short cross-fade (Godot's visibility
ranges, per cell). A hero prop at 60k triangles costs its 5k low mesh
from a few metres away.

**Emission.** A `.vox` material of type `_emit` (MagicaVoxel's emissive
materials; the reference TV's screen and LEDs have them, the generator's
`EMISSIVE` table writes them) is read into `VoxAsset.emissive`, carried
through the model and the mesher as vertex alpha below 1, and turned into
glow by the shader (`emission_strength`). No second attribute, no second
material; the low-detail mesh glows too. Glass materials are read but not
yet drawn as glass.

**Quality presets** (`framework/render/quality.gd`): low, medium, high as
one dictionary each (SSAO, SDFGI, glow, shadow atlas and splits, draw and
LOD distances, prop shadows, MSAA), applied to an Environment, the key
light, the fields and the viewport with one call. The look is tuned by
editing a preset; a settings screen calls `Quality.apply`. SDFGI and SSAO
act on Forward+ only.

**Occluders** (`framework/render/occluders.gd`): `Occluders.from_boxes`
turns a room's walls, floors and counters into one `OccluderInstance3D`
at runtime, so a code-built room (every VenueKit room, the demo) gets
occlusion culling without an editor bake. Lightmap baking still needs the
editor (`LightmapGI`), and is the one lighting step left for the port.

The objects demo takes `--quality=low|medium|high` and builds occluders
from its slabs.

## 8. The prop studio

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

## 9. The world: chunks that remember

`framework/world/world.gd` (`World`) and `world_chunk.gd` (`WorldChunk`)
are the conventions that tie the streamer, the fields and the registry
together, so a building made of rooms behaves as one world.

```gdscript
var world := World.new()
add_child(world)
world.register_chunk("res://scenes/venue/chunks/lobby.tscn", AABB(Vector3(0, 0, 0), Vector3(30, 6, 20)))
world.focus = walker.global_position        # each frame
world.objects.act("take", row)              # the one registry
var save := world.to_save()                 # every chunk's rows, loaded or not
world.from_save(save)
```

**A chunk scene** has a `WorldChunk` root with a stable `chunk_id`, a
`bounds` box in world space, and optional `occluder_boxes` (built into an
`OccluderInstance3D` on enter). It owns one `PropField` named `Props`
(created if the scene has none). Its layout goes in `populate(objects)`:
spawn rows through the registry with ids like `lobby.chair.3` and `field`
as the target. `framework/bench/test_chunk.gd` is the smallest example.
Anything that must only run while the room is loaded (its people, a
machine's loop) hangs under the chunk and goes with it.

**What the World does on load:** registers the chunk's field with
`WorldObjects` under its `chunk_id`, applies any rows that were pending
for that chunk (a save, or the state from the last time it was loaded),
connects contact audio, then calls `populate`. A layout spawn whose id
already has a row is skipped, and one whose id was *taken* (removed) is
refused, so the cup you moved is still moved and the one you pocketed is
still gone when the room streams back in. On unload the chunk's changed
rows (moved, taken, or awake) are kept as pending data and dropped from
the registry; unchanged layout rows cost nothing to forget.

**The save** (`WorldObjects.to_save`) carries each changed row with its
chunk, the removed ids with theirs, and the pending data of chunks that
are not loaded right now. `from_save` applies what it can to loaded
chunks and parks the rest until those chunks come in. A fresh `World`
with no chunks loaded yet accepts a save and hands each chunk its part on
load. `tools/tests/test_framework_world.gd` walks the whole loop: load,
change, leave, save, return, reload from JSON.

## 10. Contact audio

`framework/audio/contact_audio.gd` (`ContactAudio`). `PropField` emits
`contact(row, other, speed, at)` when a live body hits something, with the
closing speed from the step *before* the hit (by the time Godot reports
the contact the impulse has already taken the speed away) and at most one
signal per row every 0.12 s. `ContactAudio` listens to every field the
registry knows (`listen_objects(objects)`; the World does this itself),
looks up the prop's manifest `sound` (wood, metal, plastic, rubber,
ceramic, glass, cloth, paper), and plays one of that material's
recordings from `assets/audio` through `WorldSound`, quieter for a tap and
full for a throw, with a little pitch spread. Unknown materials sound like
wood. `audio.log` holds the last 32 hits for tests and the dev menu. New
materials are a row in `ContactAudio.SOUNDS`; new recordings go through
`art/tools/synth_sounds.py` like the existing ones.

## 11. Voxels that change: `VoxelSurface`

`framework/voxel/voxel_surface.gd`. The props are static voxels: meshed at
import, never edited. The ice, a dented wall, a snowbank are voxels that
change at runtime, and `VoxelSurface` is the runtime mesher for them.

```gdscript
var ice := VoxelSurface.new()
add_child(ice)
ice.setup(Vector3i(640, 2, 300), 0.05)           # voxels, metres per voxel
ice.fill(Vector3i.ZERO, Vector3i(640, 2, 300), Color.WHITE)
ice.set_voxel(x, 1, z, Color.TRANSPARENT)        # a skate mark (alpha 0 = empty)
ice.set_voxel(x, 1, z, Color(1, 0.8, 0.2, 0.3))  # alpha under 1 = glows
ice.budget_ms = 2.0                              # re-mesh time per frame
```

The volume is split into 16-voxel chunks, each one `MeshInstance3D` with
the prop material (AO, emission by alpha, the same look as everything
else). Changing a voxel dirties its chunk, and its neighbour when it sits
on a chunk face; dirty chunks are rebuilt in `_process` within
`budget_ms`, or all at once by `remesh_now()`. Each rebuild meshes the
chunk's own voxels with a one-voxel skirt of neighbours as occluders
(`VoxMesher`'s `skip` option), so chunk seams show no faces. Measured on
this machine: a 64x3x64 slab is 16 chunks in about 60 ms; three edited
chunks re-mesh in about 12 ms. This is the GDScript mesher, fine for
marks and dents; a native mesher later replaces `_build_chunk` and nothing
else.

## 11b. The ice: `IceSheet`

`framework/ice/ice_sheet.gd` with `framework/render/ice_sheet.gdshader`.
The sheet of ice is not cubes: it is a surface a few millimetres thick
whose detail lives at three scales, so it is a grid of columns.

```gdscript
var ice := IceSheet.new()
add_child(ice)
ice.setup(Vector2(24, 14), 0.025)          # metres, metres per cell
ice.fill_state(0.0, 0.8, 0.0, 0.0)         # snow mm, cut, water mm, frozen
ice.pour(Vector2(3, 2), 0.6, 1.2)           # a 1.2 mm puddle 60 cm across
ice.stroke(a, b, 0.03, 0.9, 1.5, 0.3)       # a blade: width, cut, gouge mm, snow mm
ice.resurface(x0, x1, z0, z1, 0.8)          # shaved, a 0.8 mm film left wet
ice.thermal(dt, slab_c, air_c)              # water sets from the edges in
```

**Columns, 2.5 cm.** Per cell: loose snow (mm), liquid water (mm), how
much of that water has set, the dry-cut amount and its angle, gouge
depth, built-up ice, filled-gouge scar, and crust. A chunked heightfield
(64 cells a side) gives all of it real height; a level chunk (dry, or an
even film, or built-up ice all one height) is two triangles.

**Water is ice when it sets.** Set water joins the column's ice
thickness (water expands 9%), so flooding one spot again and again makes
it measurably higher, and the new surface is fresh frozen. Liquid water
flows: each visit a wet cell sends part of the head difference (ice plus
crust plus water minus gouge) to each lower neighbour, all but a 0.2 mm
film that clings to the ice, and water that has begun to set is slush
and stays put. So a pour spreads into a pool, runs downhill, fills a
gouge (when it sets the trench is gone but a pale scar stays visible)
and pins as a film at its rim. Water on snow is slush, wet grey and half glossy, and
sets with the snow into a rough crust of peaks.

**The state texture, one texel per cell.** Two RGBA8 images carry the
columns to the shader; only dirty chunks are rewritten, and the textures
upload once per frame within `budget_ms`.

**The shader, millimetre detail.** Four surface states blended per pixel:
snowed up (matte, grainy), dry cut (a sheen with striations at the cut
angle: grooves 5 to 10 mm wide at random spacing and depth, running the
length with a slow wander, from a one-metre tiling map), flood (a glossy
water layer over whichever state is under it, which is why flood over
snow and flood over a cut look different), and dry fresh frozen (hard
gloss, a faint freeze ripple); plus scars and crust. The detail maps are
generated once and sampled with mipmaps; without them a grazing view
turns the striations into moiré.

**Freezing.** `thermal()` sets each wet cell's water at a rate from the
slab temperature under it, slower in deep water and warm air, faster next
to cells already set or dry, so a pool shrinks inward; 1.2 mm at -5 C
takes about 12 minutes, the sim's number. It walks the wet cells in
slices of 3000 a frame through an append-only list (no per-cell calls or
allocations), so a whole flooded sheet of 537k cells costs under 3 ms a
frame and each cell is visited every three seconds with that much sim
time. `set_now()` sets every wet cell at once, for a test rig.

**The blade.** `resurface(x0, x1, z0, z1, film_mm, rag_wear, blade_mm,
travel)` is the resurfacer over a band: the blade at `blade_mm` above
the base shaves off everything higher. Snow has height: a blade above
the snow touches nothing, a blade in the snow shaves only snow, and a
blade in the solid (built-up ice, crust peaks) takes the snow with it
and cuts the ice; below zero it cuts into the base and takes gouge
depth. Where it cut the solid it leaves a dry cut whose striations run
along `travel`, the blade's direction. Columns below the blade keep
their old cut. The shavings go up the auger into the tank (a `spill`
share can be left as a ridge along the sides, off by default: side-by-side
passes must blend), and the call returns the millimetres taken. With
`film_mm` > 0 the conditioner's rag lays water behind the blade: a new
rag (`rag_wear` 0) an even film, a worn one (1) streaks and a coarser
cut. A dry pass is the one without the film. The
game's `IceSlab` and `RefrigerationPlant` are where the real heat balance
lives; this is the surface they will drive, and the sim's 25 cm grid is
the source the 2.5 cm columns sample.

**Lighting lesson.** A near-mirror sheet shows two things an ordinary
floor hides: any light too strong clips the whole surface to white, and
spot shadows with the default bias self-shadow in stripes along the
shadow map's rows. The ice demo's lamps carry the raised bias; the
arena's lamps need the same when the ice moves into the game.

**Measured here:** a full GDScript pass over every cell costs 0.6 ms at
25 cm, 15 ms at 5 cm, 63 ms at 2.5 cm, 400 ms at 1 cm; the state texture
is 10 MB at 2.5 cm and 60 MB at 1 cm. So: sim at 25 cm, columns and
texture at 2.5 cm, shader below, with a local 5 mm patch an option later.

**Future, not built:** physical skate gouges, where the skater contact
model writes blade strokes into the columns and reads the height back,
so a rut is felt as well as seen.

## 12. The render benchmark

`tools/render_bench.sh [--props=200] [--quality=medium]` runs
`scenes/dev/render_bench.tscn` under the virtual display: a 24 m room with
a dividing wall, N catalog props on the floor, and a camera flying one
loop around it. It prints the average and worst frame time, primitives
and draw calls per frame, and how many bodies were live. Under the
software driver the frame times are meaningless (a second a frame); the
primitive and draw-call counts are real, and the same scene before and
after a change is the comparison. The first baseline, 200 props at medium:
159 draw calls, 7.9 M primitives a frame (shadows count twice), 0 live.
Headless CI runs the scene as `--test=render_bench` to keep it working.

## 13. The demos

Three scenes under `scenes/dev/` to get a feel for it, each run from the
editor or with `godot --path . res://scenes/dev/<name>.tscn`. All take
`--quality=low|medium|high`, `--screenshot=<png>` for a frame without a
display, and run as headless checks in CI (`--test=<name>`).

- **`object_demo`**: one room with every catalog prop on tables and the
  floor. Walk up to anything, E takes it into your hands (a live body on
  a spring that bumps into things), E drops, F throws or shoves, right
  click inspects, Q opens or uses, F5 saves and reloads the rows. While
  holding something the wheel tumbles it top over bottom (four wheel
  turns for one revolution) and ctrl + wheel brings it nearer or farther (every demo, through the Interactor).
- **`world_demo`**: five themed rooms in a row (`framework/demo/rooms/`,
  one `DemoRoom` chunk each) that stream in and out as you walk; the HUD
  names the loaded ones. The same controls, plus T to pocket what you
  hold, G to tip a box of mugs at your feet (contact audio), F5 to save,
  F9 to load. Move something, walk two rooms on and back: it is still moved;
  pocket it: still gone.
- **`ice_demo`**: a 24 x 14 m `IceSheet` (section 11b) under arena-style
  lamps. X cycles the whole sheet through the four states; holding LMB
  runs a hose where you look (1.6 L/s, the wheel is the valve from 0.1
  to 6 L/s, a stream of drops to match) and the readout
  shows the slab and air temperatures, the clock, the litres hosed and
  the column's top and built-up ice under the dot while it sets from the
  edges in; I makes water set the instant it lands; T speeds the clock
  (x1, x10, x60); holding RMB chips gouges wherever you look. R drives
  the resurfacer from the blue line to the red line along your side of
  the sheet: M switches DRY CUT (the blade shaves, striations along the
  travel) and FLOOD (the rag lays a film behind the blade), [ and ] set
  the blade in quarter millimetres, Y wears the rag. Footsteps leave the
  ice alone. Mugs on the ice to kick and carry. In every demo Ctrl
  crouches, F toggles noclip (Space up, Ctrl down) and holding Z zooms.

## 14. What the port looks like

Nothing is ported yet. The order, each step a PR that keeps CI green:

1. **Props to assets.** The world-objects branch converts the kit to
   `.vox` plus manifests; those files drop into `data/props/` and
   `art/props/` and `ObjectCatalog` reads them. The coded fallback stays
   until the last prop is converted.
2. **Rooms place rows.** `VenueKit.prop()` adds a `PropRow` to the room's
   `PropField` instead of baking into the merged mesh. The merged mesh
   stays for architecture (walls, floors, stands).
3. **Loose things.** `StickField`, `StickProp`, `LooseProp` and `PropGrab`
   become `WorldObjects` rows, `Interactor.carry()` and `drop()`; the
   venue walk keeps its own HUD and inventory, fed by `prompt()` and
   `act("take")` into `ItemCatalog`.
4. **The building streams.** Rooms become chunk scenes registered with a
   `ChunkStreamer`; occluders are baked per chunk.
5. **Lighting.** `LightmapGI` for the shell (an editor bake), the
   `Quality` presets for the rest.
6. **The match scene** moves last and mostly unchanged: the skaters, the
   puck and the shot patterns do not touch any of this.

## 15. Rules for building on it

- A new prop is a `.vox` and a record, never code in the game. A coded
  builder is a generator that writes a `.vox` (`VoxWriter`, or
  `tools/propgen/` for hero props) and is then done.
- Anything placed in the world is a `PropRow` in a `PropField`. Scene nodes
  are for things that are unique and always live (doors, the Zamboni,
  the walker).
- One mesher: `VoxMesher`. One voxel reader: `VoxReader`.
- Budgets are tests. A change that makes `test_framework_props.gd` slower
  needs a number in the PR saying why.
- Framework code is linted and formatted; `tools/lint.sh --fix` before
  pushing.
