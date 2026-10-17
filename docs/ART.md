# RinkGM art and voxel style guide

Owned by the World and asset design workstream (see `ARCHITECTURE.md`). This
is how things look; Rink environment decides where they go.

## The look in one line

Chunky, readable voxel models with flat vertex colours and a little per-voxel
speckle, lit by one soft key light with ambient occlusion, matching the
reference renders in `art/reference/`. The world tells the renovation story:
it starts as a tired 1970s community rink and visibly gets better.

## Scale

| Use | Voxel size | Notes |
| --- | --- | --- |
| Characters, equipment, props | 0.065 m (`Models.V`) | One size so everything the player stands next to reads as one world. A 1.85 m skater is about 28 voxels tall |
| Puck, net | 0.05 m, 0.061 m | Kept for regulation sizes |
| Skater stick (shaft and blade) | 0.0175 m (`Models.STICK_V`) | Finer so the shaft reads as a stick |
| Architecture (walls, floors, roof, stands) | Rink environment's tiles, 0.3-1 m | Built by Rink environment in the `Wear` palettes. Flat colour, so big surfaces stay cheap |

Real-world sizes are used throughout: doors are 0.9 x 2.1 m, seats 0.45 m
off the floor, the ice resurfacer about 1.9 x 3.6 m.

## Conventions

- +Y is up and the front faces -Z, the same as `VoxelModel`.
- Props have their pivot on the floor, centred. Hanging things (lights) have
  it at the ceiling mount. `tools/tests/test_props.gd` checks this.
- Grid voxels for anything that sits square; oriented voxels
  (`VoxelModel.add_oriented`, drawn with `VoxelMeshBuilder.add_box`) for
  things that don't, such as curved boards or a stick's heel.
- One mesh per prop and age, shared by every copy (`Props.mesh(id, age)` caches
  it), so a stand of 400 seats is one mesh drawn 400 times. Use a
  `MultiMeshInstance3D` for big repeats.
- Two detail levels: `Props.mesh(id, age, 1)` drops the speckle, rust, chips
  and grime gradient and merges flat faces of one colour
  (`VoxelModel.build_mesh_merged`). Use it for the stands and anything far
  away; a seat goes from about 640-860 triangles to 120-210.
- Doors come whole (`door`) or in two parts so the leaf can swing:
  `door_frame` has the door's pivot, `door_leaf` has its pivot on the hinge,
  and `Props.DOOR_HINGE` is where the hinge sits in the frame's space.

## Renovation ages

Every prop comes in three ages (`Wear.WORN`, `Wear.REPAIRED`,
`Wear.RENOVATED`). `Wear.weather()` applies the shared ageing so all props age
alike; each prop adds its own story details.

| Age | Shapes | Colour | Details |
| --- | --- | --- | --- |
| Worn | The original 1970s designs: wood, cast iron, painted steel | Old palette, faded about 30% and grimier toward the floor, extra speckle | Chipped corners, rust on steel, missing parts (a seat slat, a sign letter), notes taped on |
| Repaired | The same designs | Old palette repainted, faded about 10% | Visible volunteer fixes: an unpainted replacement plank, plywood over a broken pane, tape round a split bin, a letter repainted in the wrong red |
| Renovated | New designs: moulded plastic, glass, steel, LED | The club palette, clean, low speckle | Tidy edges and light trim |

### Palettes

Old rink: wood `9a6b3f`, institutional mint `8fbfa8`, harvest gold `d9a62e`,
burnt orange `c8642a`, avocado `7d8a3a`, brown `5b3a22`, cream `e3d9bf`,
concrete `a8a294`, steel `8f9498`, rust `8a4a24`, sodium light `ffb84d`.

Renovated club: navy `1d3557`, rink red `d0202a`, white `eeeeea`, steel
`b9c0c6`, charcoal `2b2d33`, teal `2a9d8f`, glass `a9d3e0`, LED `f4f8ff`.

These live as constants in `scripts/art/wear.gd`. Team colours for players
stay in `Models.palette()`.

## Props kit (`scripts/art/props.gd`)

`arena_seat`, `door` (or `door_frame` + `door_leaf`), `light`,
`vending_machine`, `trash_can`, `rink_sign`, `resurfacer`, `lockers`,
`player_bench` (a 2 m section), `penalty_box`, `glass_frame` + `glass_pane`
(one 1.83 m panel on top of the boards), `concession_counter` and
`scoreboard`, each at all three ages. Next: skate-sharpening bench, rubber
flooring, crowd figures and staff.

Glass panes are drawn with `Props.glass_material(age)` (see-through; old glass
is yellowed and cloudier). The scoreboard leaves its displays dark:
`Props.scoreboard_faces(age)` gives each face's centre, outward normal and
size to fill with `RinkOS.sign_3d()`. The old scoreboard is a 6.5 x 3 m wall
board; the renovated one is a four-sided centre-hung board, pivoted at its
ceiling mount like the lights. The resurfacer is the world's classic Zambelli Model 525: a boxy gas machine with the tall snow tank in front, the driver up on the left behind it, the engine cowl on the right and the conditioner and towel trailing. The penalty box is 4.3 x 1.9 m with a 1 m door
gap in the back wall.

To add a prop: write a `_name(age)` builder in `props.gd`, add the id to
`IDS` and `_build()`, then check it on the prop sheet.

## Sticks

The skater stick is two parts posed by `SkaterRig`: `Models.shaft()` and
`Models.blade()`. The blade's heel is not a right angle: it curves smoothly
up into a hosel at the stick's lie (47° off the ice, so the heel is an
obtuse angle of about 133°), and the shaft starts where the hosel ends,
`Models.blade_heel`. Controls owns the grip and how the stick is posed.
`art/tools/stick_sheet.gd` renders the stick on its own
(`--view=full|heel|top`), and `tools/tests/test_stick.gd` checks the heel.

## Text on signs

In-world text follows the UI style (`assets/ui/STYLE.md`, PR #6): signs,
banners and the scoreboard use `RinkOS.sign_3d()`, which puts one font pixel
on one 0.065 m voxel. Props supply the board and frame. The voxel letters in
`Props.letters()` are only for the old hand-painted sign, where the worn and
repaired versions need letters that can fall off or be repainted; the
renovated sign switches to `RinkOS.sign_3d()` once PR #6 is merged.

## Authoring in MagicaVoxel

`VoxLoader.load_vox(path, voxel_size)` reads a `.vox` file into a
`VoxelModel`, so a hand-made model can replace a procedural one. Sources go in
`art/` next to the code that uses them. Use the voxel sizes above, Z-up in
MagicaVoxel (the loader converts), and the front facing MagicaVoxel's -Y.

## Reviewing the look

The prop sheet renders every prop at every age into one PNG:

```
godot --path . --script res://art/tools/prop_sheet.gd -- --out=props.png [--ids=door,light]
```

In the cloud container (no GPU), install `mesa-vulkan-drivers` and `xvfb`, then
run it under `xvfb-run` with
`VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json`.

## Budget

The full 5-on-5 game must hold 60 fps on a mid-range PC. Props that repeat
(seats, bins, lights) stay under about 2,000 faces each; one-offs such as the
resurfacer can go to 8,000. Big one-offs with large flat panels (the resurfacer) are listed in `Props._MERGED` and merge their faces even at full detail, keeping rust and grime but not the speckle (about 650-2,100 triangles). Share meshes, and give large
repeated sets (seats, crowd) a `MultiMeshInstance3D`. Next pipeline step:
merge flat runs of faces for architecture, where the per-voxel speckle
matters less.
