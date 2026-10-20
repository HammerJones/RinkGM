extends VenueRoom
## The outside of the building: the arena's shallow barrel roof with its
## metal-clad gable ends, pilasters, bands and cornice on the block walls,
## gutters and downspouts, the brick street front with its painted name and
## the 70s entrance canopy, and the clutter round the back (dumpster pen,
## propane cage, the ice plant's condenser). With the recreation wing built
## it also gives the wing its brown mansard fascia (it was added later and
## looks it) and rooftop units.
##
## Not a room (no bounds), so it never wins room_at(). Everything on the
## arena roof lives in a child node that hides with the roof deck when the
## camera is above the roof line, so the isometric view still sees the ice.
## Only the outside faces of the envelope are touched.

const HX := Venue.HALF_X
const HZ := Venue.HALF_Z
const Y0 := Venue.ROOF_Y + 0.4   # top of the roof deck: the arch springs from here
const RISE := 4.5                # barrel roof rise at the ridge
const EAVE := 0.6                # overhang past the long walls
const GABLE_OUT := 0.7           # overhang past the end walls
const CHORDS := 16               # straight runs making up the arch
const PIER_STEP := 6.0           # pilasters line up with the roof trusses
const SPOUTS := [-33.0, -9.0, 15.0, 33.0]
const EXITS := [-40.0, 40.0]

## 3x5 pixel font for the painted name: five rows, top to bottom.
const FONT := {
	"A": ".#. #.# ### #.# #.#", "B": "##. #.# ##. #.# ##.", "C": ".## #.. #.. #.. .##", "D": "##. #.# #.# #.# ##.",
	"E": "### #.. ##. #.. ###", "F": "### #.. ##. #.. #..", "G": ".## #.. #.# #.# .##", "H": "#.# #.# ### #.# #.#",
	"I": "### .#. .#. .#. ###", "J": "..# ..# ..# #.# .#.", "K": "#.# #.# ##. #.# #.#", "L": "#.. #.. #.. #.. ###",
	"M": "#.# ### ### #.# #.#", "N": "##. #.# #.# #.# #.#", "O": ".#. #.# #.# #.# .#.", "P": "##. #.# ##. #.. #..",
	"Q": ".#. #.# #.# ##. .##", "R": "##. #.# ##. #.# #.#", "S": ".## #.. .#. ..# ##.", "T": "### .#. .#. .#. .#.",
	"U": "#.# #.# #.# #.# ###", "V": "#.# #.# #.# #.# .#.", "W": "#.# #.# ### ### #.#", "X": "#.# #.# .#. #.# #.#",
	"Y": "#.# #.# .#. .#. .#.", "Z": "### ..# .#. #.. ###", "0": "### #.# #.# #.# ###", "1": ".#. ##. .#. .#. ###",
	"2": "##. ..# .#. #.. ###", "3": "##. ..# .#. ..# ##.", "4": "#.# #.# ### ..# ..#", "5": "### #.. ##. ..# ##.",
	"6": ".## #.. ### #.# ###", "7": "### ..# .#. .#. .#.", "8": "### #.# ### #.# ###", "9": "### #.# ### ..# ##.",
	"-": "... ... ### ... ...", ".": "... ... ... ... .#.", "'": ".#. .#. ... ... ...",
}

var _top: Node3D
var _hidden := false


func _ready() -> void:
	room_id = "exterior"
	display_name = "Outside walls and roof"
	# reacts to the camera going above the roof, but only hides its roof part
	overhead = true


func set_overhead_hidden(hidden: bool) -> void:
	_hidden = hidden
	if is_instance_valid(_top):
		_top.visible = not hidden


func build(k: VenueKit) -> void:
	var wings := _wings()
	# the roof: its own kit, committed under a node that hides in the iso view
	var top := VenueKit.new(hash("exterior_roof"), k.age)
	_roof(top)
	_gables(top)
	_roof_units(top)
	_top = Node3D.new()
	_top.name = "RoofTop"
	_top.set_meta("overhead", true)  # the roof never shadows the bowl
	top.commit(_top)
	_top.visible = not _hidden
	k.add(_top)
	_long_walls(k, wings)
	_end_walls(k)
	_street_front(k)
	_painted_name(k)
	if wings:
		# the ground round the building only exists with the site (RecSite)
		_canopy(k)
		_front_clutter(k)
		_back_clutter(k)
		_rec_wing(k)


func _wings() -> bool:
	return venue != null and venue.has_method("has_wings") and venue.has_wings()


## Height of the arch above the deck at z (a parabola, carried on past the
## walls for the eaves).
static func arch_y(z: float) -> float:
	var t := z / HZ
	return Y0 + RISE * (1.0 - t * t)


## Top of the recreation wing against the arena's -Z wall at x (0 = none).
static func wing_top(x: float) -> float:
	var top := 0.0
	for id in RecPlan.ROOMS:
		var r := RecPlan.rect(id)
		if absf(r.end.y - RecPlan.Z_ARENA) < 0.05 and x >= r.position.x - 0.01 and x <= r.end.x + 0.01:
			top = maxf(top, float(RecPlan.ROOMS[id][3]) + 0.6)
	return top


# ---------------------------------------------------------------- roof

func _metal(k: VenueKit) -> Color:
	return k.by_age(Color("7d8784"), Color("8e9897"), Color("3d444d"))


func _trim(k: VenueKit) -> Color:
	return k.by_age(Wear.OLD_ORANGE.darkened(0.15), Wear.OLD_ORANGE, home_primary())


## Points along the arch from eave to eave.
func _arch_points() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var z0 := -HZ - EAVE
	for i in CHORDS + 1:
		var z := z0 + (HZ + EAVE) * 2.0 * i / CHORDS
		pts.append(Vector2(z, arch_y(z)))
	return pts


## A box along the chord a..b (z, y), spanning x0..x1, `thick` across the
## chord, its bottom `drop` below the chord line.
func _chord_box(k: VenueKit, a: Vector2, b: Vector2, x0: float, x1: float, thick: float, drop: float, col: Color) -> void:
	var d := b - a
	var along := Vector3(0, d.y, d.x)
	var n := Vector3(0, d.x, -d.y).normalized()
	if n.y < 0.0:
		n = -n
	var mid := Vector3((x0 + x1) * 0.5, (a.y + b.y) * 0.5, (a.x + b.x) * 0.5) + n * (thick * 0.5 - drop)
	k.oriented(Transform3D(Basis(Vector3(x1 - x0, 0, 0), n * thick, along), mid), col)


## Standing-seam barrel roof: a skin of panels (rusty or patched by age),
## a seam every 1.5 m, a ridge cap.
func _roof(k: VenueKit) -> void:
	var pts := _arch_points()
	var metal := _metal(k)
	var x0 := -HX - GABLE_OUT
	var x1 := HX + GABLE_OUT
	var sections := 8
	for i in CHORDS:
		for s in sections:
			var sx0 := lerpf(x0, x1, float(s) / sections)
			var sx1 := lerpf(x0, x1, float(s + 1) / sections)
			var c := k.aged(metal, Vector2i(i, s))
			if k.age == Age.WORN and posmod(hash(Vector2i(s, i * 3)), 9) == 0:
				c = c.lerp(Wear.RUST, 0.45)
			elif k.age == Age.REPAIRED and posmod(hash(Vector2i(s, i)), 4) == 0:
				c = Color("b4bcbd")  # a newer replacement panel
			c = VoxelMeshBuilder.jitter_color(c, Vector2i(i * 7, s), 0.03)
			_chord_box(k, pts[i], pts[i + 1], sx0, sx1, 0.22, 0.0, c)
	# seams
	var seam := metal.lightened(0.12)
	var x := x0 + 0.75
	while x < x1:
		for i in CHORDS:
			_chord_box(k, pts[i], pts[i + 1], x - 0.05, x + 0.05, 0.36, 0.0, seam)
		x += 1.5
	# ridge cap and a vent strip along it
	var ry := arch_y(0.0)
	k.block(Vector3(x0, ry + 0.15, -0.7), Vector3(x1, ry + 0.45, 0.7), seam.darkened(0.1), 2.0, 0.04, false)
	k.block(Vector3(-HX + 4.0, ry + 0.45, -0.4), Vector3(HX - 4.0, ry + 0.75, 0.4), Color("4a4e52"), 2.0, 0.05, false)
	# fascia and box gutter along both eaves
	var trim := _trim(k)
	for s in [-1, 1]:
		var ze: float = s * (HZ + EAVE)
		var ye := arch_y(ze)
		k.block(Vector3(x0, ye - 0.55, ze - s * 0.02), Vector3(x1, ye + 0.3, ze + s * 0.12), trim, 1.0, 0.05, false)
		k.block(Vector3(x0, ye - 0.75, ze + s * 0.12), Vector3(x1, ye - 0.1, ze + s * 0.5), k.by_age(Color("8a8a82"), Color("9fa3a3"), Wear.CHARCOAL), 1.0, 0.05, false)
		# the underside of the overhang, back to the wall
		k.block(Vector3(x0, ye - 0.6, s * HZ), Vector3(x1, ye - 0.55, ze), Color("4c4a45"), 2.0, 0.04, false)


## Gable ends: metal siding filled in under the arch (stepped like the
## blocks it sits on), a barge board along the curve, a louvre at the peak,
## and weather streaks off the gutter ends when worn.
func _gables(k: VenueKit) -> void:
	var pts := _arch_points()
	var side: Color = k.by_age(Wear.OLD_BROWN.lightened(0.18), Wear.OLD_BROWN.lightened(0.25), Wear.CHARCOAL.lightened(0.08))
	var rib := side.darkened(0.18)
	var trim := _trim(k)
	var y := Venue.ROOF_Y
	for e in [-1, 1]:
		var xo: float = e * HX           # outside face of the end wall
		var xi: float = e * (HX - 0.4)
		# stepped fill, two steps per chord, under the curve
		for i in CHORDS:
			for half in 2:
				var za: float = lerpf(pts[i].x, pts[i + 1].x, half * 0.5)
				var zb: float = lerpf(pts[i].x, pts[i + 1].x, half * 0.5 + 0.5)
				za = clampf(za, -HZ, HZ)
				zb = clampf(zb, -HZ, HZ)
				if zb - za < 0.05:
					continue
				var ty := minf(arch_y(za), arch_y(zb)) + 0.05
				k.aged_block(Vector3(xi, y, za), Vector3(xo, ty, zb), side, 1.0, 0.05, false)
		# vertical ribs on the siding
		var z := -HZ + 1.0
		while z < HZ - 0.5:
			var ty := arch_y(z) - 0.2
			if ty > y + 0.3:
				k.block(Vector3(xo, y, z - 0.07), Vector3(xo + e * 0.08, ty, z + 0.07), rib, 1.0, 0.03, false)
			z += 1.0
		# barge board following the arch, past the roof's overhang
		var bx0: float = e * (HX + GABLE_OUT - 0.05)
		var bx1: float = e * (HX + GABLE_OUT + 0.2)
		for i in CHORDS:
			_chord_box(k, pts[i], pts[i + 1], minf(bx0, bx1), maxf(bx0, bx1), 1.0, 0.75, k.aged(trim, i))
		# louvred vent at the peak
		var ly := y + 1.0
		k.block(Vector3(xo, ly - 0.2, -1.8), Vector3(xo + e * 0.12, ly + 2.4, 1.8), side.darkened(0.3), 0.5, 0.03, false)
		for j in 5:
			var yy := ly + 0.1 + j * 0.42
			k.block(Vector3(xo, yy, -1.6), Vector3(xo + e * 0.22, yy + 0.16, 1.6), k.by_age(Color("5a5d5f"), Color("6c7072"), Color("1e2126")), 0.5, 0.02, false)
		# a cap band where the block wall meets the siding
		k.block(Vector3(xo - e * 0.02, y - 0.25, -HZ - 0.2), Vector3(xo + e * 0.3, y + 0.15, HZ + 0.2), Wear.OLD_CREAM if k.age != Age.RENOVATED else home_secondary(), 1.0, 0.04, false)
		if k.age == Age.WORN:
			for i in 9:
				var sz := k.rng.randf_range(-HZ + 2.0, HZ - 2.0)
				var top := arch_y(sz) - 0.6
				var len := k.rng.randf_range(0.8, 2.6)
				k.block(Vector3(xo, top - len, sz - 0.15), Vector3(xo + e * 0.1, top, sz + 0.15), Wear.RUST.darkened(0.1), 0.5, 0.06, false)


## Rooftop units: two HVAC boxes off the ridge, exhaust fans along it.
func _roof_units(k: VenueKit) -> void:
	var box: Color = k.by_age(Color("9a9886"), Color("b0b2a8"), Color("cfd3d6"))
	for u in [[-30.0, 4.0], [12.0, -5.0], [28.0, 3.5]]:
		var ux: float = u[0]
		var uz: float = u[1]
		var base := minf(arch_y(uz - 1.2), arch_y(uz + 1.2)) - 0.1
		k.block(Vector3(ux - 2.2, base - 0.3, uz - 1.5), Vector3(ux + 2.2, base + 0.3, uz + 1.5), Color("5e5c56"), 1.0, 0.04, false)  # curb
		k.aged_block(Vector3(ux - 2.0, base + 0.3, uz - 1.3), Vector3(ux + 2.0, base + 1.9, uz + 1.3), box, 0.5, 0.05, false)
		# louvres on the long faces
		for s in [-1, 1]:
			for j in 4:
				var ly := base + 0.55 + j * 0.3
				k.block(Vector3(ux - 1.6, ly, uz + s * 1.3), Vector3(ux + 0.4, ly + 0.12, uz + s * 1.36), box.darkened(0.35), 0.5, 0.0, false)
		# fan shroud and grille on top
		k.block(Vector3(ux + 0.4, base + 1.9, uz - 0.9), Vector3(ux + 1.8, base + 2.25, uz + 0.9), box.darkened(0.15), 0.5, 0.03, false)
		k.block(Vector3(ux + 0.6, base + 2.25, uz - 0.7), Vector3(ux + 1.6, base + 2.3, uz + 0.7), Color("2a2c2e"), 0.5, 0.0, false)
		# duct down into the roof
		k.block(Vector3(ux - 1.8, base - 0.6, uz - 0.4), Vector3(ux - 1.0, base + 0.3, uz + 0.4), box.darkened(0.1), 0.5, 0.03, false)
	# mushroom exhaust fans along the ridge
	var fan: Color = k.by_age(Color("8d918c"), Color("a6aaa6"), Color("d4d7da"))
	var x := -36.0
	var i := 0
	while x <= 36.0:
		if absf(x - 12.0) > 3.0:
			var zf := 2.2 if i % 2 == 0 else -2.2
			var b := arch_y(zf) - 0.05
			var c := k.aged(fan, i)
			k.block(Vector3(x - 0.5, b, zf - 0.5), Vector3(x + 0.5, b + 0.6, zf + 0.5), c, 0.5, 0.04, false)
			k.block(Vector3(x - 0.8, b + 0.6, zf - 0.8), Vector3(x + 0.8, b + 0.85, zf + 0.8), c.lightened(0.08), 0.5, 0.04, false)
			k.block(Vector3(x - 0.55, b + 0.85, zf - 0.55), Vector3(x + 0.55, b + 1.0, zf + 0.55), c.darkened(0.1), 0.5, 0.04, false)
		x += 12.0
		i += 1


# ---------------------------------------------------------------- walls

## The long block walls: pilasters at the truss lines, a split-face band and
## a coping band, downspouts, wall packs over the exits, grime streaks.
func _long_walls(k: VenueKit, wings: bool) -> void:
	var block: Color = k.by_age(Wear.CONCRETE.darkened(0.12), Wear.CONCRETE.darkened(0.04), Color("d1ccc2"))
	var pier: Color = k.by_age(Color("8a8274"), Color("968e80"), Color("b9b4aa"))
	var band: Color = k.by_age(Color("857c6c"), Color("8e8676"), Color("a9a49a"))
	# the 70s stripes, carried round the outside too; the club colour once renovated
	var stripes: Array = [home_primary()] if k.age == Age.RENOVATED else [Wear.OLD_ORANGE, Wear.OLD_GOLD]
	var cope: Color = k.by_age(Wear.OLD_CREAM.darkened(0.2), Wear.OLD_CREAM, home_secondary())
	for s in [-1, 1]:
		var zf: float = s * HZ                 # outside face
		var zo: float = s * (HZ + 0.25)        # pilaster face
		var covered: bool = wings and s < 0    # the wing hides the bottom
		var x := -HX + PIER_STEP
		while x < HX - 0.1:
			var y0 := wing_top(x) if covered else 0.0
			k.aged_block(Vector3(x - 0.45, y0, zf), Vector3(x + 0.45, Venue.ROOF_Y - 0.4, zo + s * 0.1), pier, 0.9, 0.05, not covered)
			x += PIER_STEP
		# corner piers wrap the ends
		for e in [-1, 1]:
			var y0 := wing_top(e * HX) if covered else 0.0
			k.aged_block(Vector3(e * (HX - 0.5), y0, zf - s * 0.5), Vector3(e * (HX + 0.3), Venue.ROOF_Y - 0.4, zo), pier, 0.7, 0.05, not covered)
		# coping band at the top, split-face band at door-head height
		k.aged_block(Vector3(-HX - 0.3, Venue.ROOF_Y - 0.9, zf), Vector3(HX + 0.3, Venue.ROOF_Y - 0.3, s * (HZ + 0.32)), cope, 1.0, 0.04, false)
		if not covered:
			k.aged_block(Vector3(-HX, 3.0, zf), Vector3(HX, 3.5, s * (HZ + 0.12)), band, 1.0, 0.06, false)
			for i in stripes.size():
				var sy := 3.7 + i * 0.55
				k.aged_block(Vector3(-HX, sy, zf), Vector3(HX, sy + 0.4, s * (HZ + 0.03)), stripes[i], 1.0, 0.05, false)
			for run in _runs(-HX, HX, [[-41.1, -38.9], [38.9, 41.1]]):
				k.aged_block(Vector3(run.x, 0.0, zf), Vector3(run.y, 0.6, s * (HZ + 0.08)), band.darkened(0.2), 1.0, 0.06)
			for ex in EXITS:
				_wall_pack(k, Vector3(ex, 2.75, zf), Vector3(0, 0, s))
		else:
			# a flashing strip where the wing's roofs meet the arena wall
			for id in RecPlan.ROOMS:
				var r := RecPlan.rect(id)
				if absf(r.end.y - RecPlan.Z_ARENA) < 0.05:
					var ty := float(RecPlan.ROOMS[id][3]) + 0.6
					k.block(Vector3(r.position.x, ty, zf), Vector3(r.end.x, ty + 0.3, zf - 0.12), Color("5b5d5f"), 1.0, 0.04, false)
		for sx in SPOUTS:
			var y0 := wing_top(sx) + 0.25 if covered else 0.0
			_downspout(k, sx, zf, s, y0)
		_streaks(k, zf, s, covered)


## The parts of lo..hi left between the sorted `gaps` ([from, to] each).
static func _runs(lo: float, hi: float, gaps: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var at := lo
	for g in gaps:
		if g[0] > at:
			out.append(Vector2(at, g[0]))
		at = maxf(at, g[1])
	if hi > at:
		out.append(Vector2(at, hi))
	return out


## A downspout from the gutter at x down the wall at zf, kicking out at the
## foot (or onto the wing's roof).
func _downspout(k: VenueKit, x: float, zf: float, s: int, y0: float) -> void:
	var pipe: Color = k.by_age(Color("8f8a78"), Color("a2a49c"), home_primary().darkened(0.2))
	var zo := zf + s * 0.32
	var ye := arch_y(zf + s * EAVE) - 0.7
	k.block(Vector3(x - 0.3, ye - 0.6, zf + s * 0.1), Vector3(x + 0.3, ye, zo + s * 0.2), pipe.darkened(0.08), 0.5, 0.04, false)  # leader head
	k.block(Vector3(x - 0.13, y0 + 0.35, zf + s * 0.12), Vector3(x + 0.13, ye - 0.6, zo), pipe, 1.0, 0.04, false)
	k.block(Vector3(x - 0.13, y0, zf + s * 0.12), Vector3(x + 0.13, y0 + 0.35, zo + s * 0.45), pipe, 0.5, 0.04, false)
	var y := y0 + 2.0
	while y < ye - 1.0:
		k.block(Vector3(x - 0.18, y, zf), Vector3(x + 0.18, y + 0.08, zo + s * 0.02), Color("4c4e50"), 0.5, 0.0, false)  # strap
		y += 3.0
	if k.age == Age.WORN:
		k.block(Vector3(x - 0.35, ye - 3.5, zf), Vector3(x - 0.15, ye - 0.6, zf + s * 0.02), Wear.RUST.darkened(0.15), 0.5, 0.08, false)
	if y0 < 0.1:
		k.block(Vector3(x - 0.3, 0.0, zo + s * 0.2), Vector3(x + 0.3, 0.06, zo + s * 0.9), Color("8a867c"), 0.5, 0.05, false)  # splash block


## Dark grime and rust under the coping when worn; a repaired wall keeps a
## few faint ones.
func _streaks(k: VenueKit, zf: float, s: int, covered: bool) -> void:
	var n: int = k.by_age(26, 8, 0)
	for i in n:
		var x := k.rng.randf_range(-HX + 1.0, HX - 1.0)
		var top := Venue.ROOF_Y - 0.9
		var bottom := maxf(wing_top(x) + 0.5 if covered else 0.8, top - k.rng.randf_range(1.5, 7.5))
		var w := k.rng.randf_range(0.2, 0.6)
		var c: Color = Wear.GRIME.darkened(0.25) if i % 3 else Wear.RUST.darkened(0.2)
		if k.age == Age.REPAIRED:
			c = c.lightened(0.25)
		k.block(Vector3(x - w * 0.5, bottom, zf), Vector3(x + w * 0.5, top, zf + s * 0.03), c, 0.5, 0.1, false)


## A boxy wall-pack lamp over a door at `p` (wall face), facing `n`.
func _wall_pack(k: VenueKit, p: Vector3, n: Vector3) -> void:
	var side := Vector3(absf(n.z), 0, absf(n.x)) * 0.25
	var out := p + n * 0.3
	k.block(p - side, out + side + Vector3(0, 0.35, 0), Color("3a3c40"), 0.25, 0.0, false)
	var lit: Color = k.by_age(Wear.SODIUM_DIM, Wear.SODIUM, Wear.LED)
	k.glow(p + n * 0.05 - side * 0.8 + Vector3(0, -0.02, 0), out - n * 0.02 + side * 0.8, lit)


## The two end walls: block pilasters and cornice at the back, wall packs
## over the Zamboni garage door.
func _end_walls(k: VenueKit) -> void:
	var block: Color = k.by_age(Color("a9a191").darkened(0.08), Color("bdb4a2"), Color("d1ccc2"))
	var cope: Color = k.by_age(Wear.OLD_CREAM.darkened(0.2), Wear.OLD_CREAM, home_secondary())
	var xf := HX
	for z in [-26.0, -20.0, -14.0, -8.0, 8.0, 14.0, 20.0, 26.0]:
		k.aged_block(Vector3(xf, 0, z - 0.35), Vector3(xf + 0.25, Venue.ROOF_Y - 0.4, z + 0.35), block.lightened(0.08), 0.7, 0.05)
	k.aged_block(Vector3(xf, Venue.ROOF_Y - 0.9, -HZ - 0.3), Vector3(xf + 0.32, Venue.ROOF_Y - 0.3, HZ + 0.3), cope, 1.0, 0.04, false)
	for run in _runs(-HZ, HZ, [[-2.1, 2.1]]):
		k.aged_block(Vector3(xf, 0.0, run.x), Vector3(xf + 0.08, 0.6, run.y), block.darkened(0.25), 1.0, 0.06)
	# a steel header and wall packs over the garage door
	k.block(Vector3(xf, 4.0, -2.4), Vector3(xf + 0.2, 4.4, 2.4), k.by_age(Color("5a5048"), Color("60666c"), Wear.CHARCOAL), 0.5, 0.04, false)
	for z in [-3.0, 3.0]:
		_wall_pack(k, Vector3(xf, 4.3, z), Vector3(1, 0, 0))
	if k.age == Age.WORN:
		for i in 10:
			var z := k.rng.randf_range(-HZ + 1.0, HZ - 1.0)
			if absf(z) < 2.6:
				continue
			var len := k.rng.randf_range(1.5, 6.0)
			k.block(Vector3(xf, Venue.ROOF_Y - 0.9 - len, z - 0.2), Vector3(xf + 0.03, Venue.ROOF_Y - 0.9, z + 0.2), Wear.GRIME.darkened(0.25), 0.5, 0.1, false)


## The street front: brick pilasters framing the lobby's brick, a stone
## sill band and a corbelled cornice, block pilasters on the plain parts.
func _street_front(k: VenueKit) -> void:
	var xf := -HX
	var brick: Color = k.by_age(Color("7a4a39"), Color("86523f"), Wear.STEEL.darkened(0.15))
	var block: Color = k.by_age(Wear.CONCRETE.darkened(0.05), Wear.CONCRETE.lightened(0.04), Color("dad6cd"))
	var stone: Color = k.by_age(Wear.OLD_CREAM.darkened(0.18), Wear.OLD_CREAM, home_secondary())
	for z in [-14.0, 14.0]:
		k.aged_block(Vector3(xf - 0.35, 0, z - 0.6), Vector3(xf, Venue.ROOF_Y - 0.3, z + 0.6), brick, 0.5, 0.06)
		k.block(Vector3(xf - 0.45, 0, z - 0.7), Vector3(xf, 0.8, z + 0.7), stone.darkened(0.1), 0.5, 0.04)  # plinth
	for z in [-26.0, -20.0, 20.0, 26.0]:
		k.aged_block(Vector3(xf - 0.25, 0, z - 0.35), Vector3(xf, Venue.ROOF_Y - 0.4, z + 0.35), block, 0.7, 0.05)
	# stone sill band over the windows, and the cornice in two steps
	k.aged_block(Vector3(xf - 0.15, 7.2, -HZ - 0.3), Vector3(xf, 7.6, HZ + 0.3), stone, 1.0, 0.04, false)
	k.aged_block(Vector3(xf - 0.2, Venue.ROOF_Y - 1.0, -HZ - 0.3), Vector3(xf, Venue.ROOF_Y - 0.5, HZ + 0.3), stone, 1.0, 0.04, false)
	k.aged_block(Vector3(xf - 0.4, Venue.ROOF_Y - 0.5, -HZ - 0.3), Vector3(xf, Venue.ROOF_Y - 0.1, HZ + 0.3), stone.darkened(0.08), 1.0, 0.04, false)
	# dentils under the cornice over the brick
	var z := -13.2
	while z < 13.3:
		k.block(Vector3(xf - 0.12, Venue.ROOF_Y - 1.35, z - 0.18), Vector3(xf, Venue.ROOF_Y - 1.0, z + 0.18), stone.darkened(0.12), 0.5, 0.0, false)
		z += 0.8
	# a soldier course over the door and windows
	k.block(Vector3(xf - 0.08, 2.6, -6.8), Vector3(xf, 3.0, 6.8), brick.darkened(0.12), 0.25, 0.08, false)
	if k.age == Age.WORN:
		for i in 8:
			var sz := k.rng.randf_range(-HZ + 1.0, HZ - 1.0)
			var len := k.rng.randf_range(1.0, 4.0)
			k.block(Vector3(xf - 0.03, Venue.ROOF_Y - 1.35 - len, sz - 0.2), Vector3(xf, Venue.ROOF_Y - 1.35, sz + 0.2), Wear.GRIME.darkened(0.3), 0.5, 0.1, false)


## The rink's name painted on the brick in big block letters: faded with
## flaked-off pixels when worn, repainted when repaired, the club's colour
## on a fresh band when renovated.
func _painted_name(k: VenueKit) -> void:
	var name := rink_name()
	var lines := [name]
	for suffix in [" COMMUNITY RINK", " ARENA"]:
		if name.ends_with(suffix):
			lines = [name.trim_suffix(suffix), suffix.strip_edges()]
	var xf := -HX - 0.04
	var span := 25.0
	var col: Color = k.by_age(Wear.OLD_CREAM.lerp(Color("8e5a45"), 0.2), Wear.OLD_CREAM, home_primary())
	var ys := [11.6, 8.3] if lines.size() > 1 else [9.6]
	var maxpx := [0.66, 0.44]
	if k.age == Age.RENOVATED:
		k.block(Vector3(-HX - 0.03, 7.9, -13.0), Vector3(-HX, 15.0, 13.0), home_secondary(), 1.0, 0.02, false)
	for li in lines.size():
		var text: String = lines[li]
		var cols := text.length() * 4 - 1
		var px: float = minf(maxpx[li] if lines.size() > 1 else 0.6, span / cols)
		var z0 := -cols * px * 0.5
		var y0: float = ys[li]
		for ci in text.length():
			var g := String(FONT.get(text[ci], "")).replace(" ", "")
			if g.length() != 15:
				continue  # a space, or a character the font doesn't have
			for r in 5:
				for c in 3:
					if g[r * 3 + c] != "#":
						continue
					if k.age == Age.WORN and posmod(hash(Vector3i(li, ci, r * 3 + c)), 11) == 0:
						continue  # flaked off
					var z := z0 + (ci * 4 + c) * px
					var y := y0 + (4 - r) * px
					var pc := k.aged(col, Vector3i(li, ci, r * 3 + c)) if k.age == Age.WORN else col
					k.block(Vector3(xf, y, z), Vector3(-HX, y + px, z + px), pc, px, 0.03, false)


# ---------------------------------------------------------------- ground

## The 70s canopy over the front doors: a deep two-tone fascia on square
## columns, can lights in the soffit (one out when worn).
func _canopy(k: VenueKit) -> void:
	var x0 := -HX - 4.5
	var x1 := -HX
	var yb := 4.9
	var fascia: Color = k.by_age(Wear.OLD_BROWN, Wear.OLD_BROWN.lightened(0.08), Wear.CHARCOAL)
	var stripe: Color = _trim(k)
	var soffit: Color = k.by_age(Color("b8ab8a"), Color("cfc6ae"), Color("e6e4de"))
	k.block(Vector3(x0, yb, -4.5), Vector3(x1, yb + 0.5, 4.5), Color("5b5750"), 1.0, 0.04, false)  # deck
	k.block(Vector3(x0 + 0.2, yb - 0.02, -4.3), Vector3(x1, yb, 4.3), soffit, 0.6, 0.04, false)
	# fascia round the three open sides
	for part in [[Vector3(x0 - 0.2, yb - 0.3, -4.7), Vector3(x0, yb + 0.8, 4.7)],
			[Vector3(x0 - 0.2, yb - 0.3, -4.7), Vector3(x1, yb + 0.8, -4.5)],
			[Vector3(x0 - 0.2, yb - 0.3, 4.5), Vector3(x1, yb + 0.8, 4.7)]]:
		k.aged_block(part[0], part[1], fascia, 0.5, 0.05, false)
	k.block(Vector3(x0 - 0.24, yb + 0.15, -4.74), Vector3(x0 - 0.2, yb + 0.4, 4.74), stripe, 0.5, 0.03, false)
	for s in [-1, 1]:
		k.block(Vector3(x0 - 0.2, yb + 0.15, s * 4.7), Vector3(x1, yb + 0.4, s * 4.74), stripe, 0.5, 0.03, false)
	# columns
	for z in [-4.1, 4.1]:
		k.aged_block(Vector3(x0 + 0.2, 0, z - 0.2), Vector3(x0 + 0.6, yb, z + 0.2), fascia.lightened(0.1), 0.4, 0.05)
		k.block(Vector3(x0 + 0.1, 0, z - 0.3), Vector3(x0 + 0.7, 0.4, z + 0.3), Color("8a867c"), 0.3, 0.03)
	var lit: Color = k.by_age(Color("f0dca0"), Color("fff0c8"), Wear.LED)
	var i := 0
	for lx in [x0 + 1.2, x0 + 3.0]:
		for lz in [-3.0, -1.0, 1.0, 3.0]:
			var c := lit
			if k.age == Age.WORN and i == 5:
				c = Color("4a4840")
			k.glow(Vector3(lx - 0.22, yb - 0.04, lz - 0.22), Vector3(lx + 0.22, yb - 0.02, lz + 0.22), c)
			i += 1


## Planters, bollards and a bike rack by the front doors.
func _front_clutter(k: VenueKit) -> void:
	var conc: Color = k.by_age(Color("8f8a7e"), Color("a19c90"), Color("c9c6be"))
	var green: Color = k.by_age(Color("5d6b3a"), Color("4f7a3a"), Color("3f7f45"))
	for s in [-1, 1]:
		var zc: float = s * 8.5
		k.aged_block(Vector3(-HX - 1.5, 0, zc - 1.1), Vector3(-HX - 0.4, 0.7, zc + 1.1), conc, 0.5, 0.05)
		# shrubs (scraggly when worn)
		var n: int = k.by_age(2, 3, 4)
		for j in n:
			var sz := zc - 0.7 + j * 1.4 / maxf(1.0, n - 1)
			var h: float = 0.4 + 0.25 * ((j + (1 if s > 0 else 0)) % 2)
			k.block(Vector3(-HX - 1.3, 0.7, sz - 0.3), Vector3(-HX - 0.6, 0.7 + h, sz + 0.3), green.darkened(0.08 * j), 0.25, 0.1, false)
		# bollards either side of the walk
		for bz in [2.4, 6.4]:
			var z: float = s * bz
			k.block(Vector3(-HX - 2.3, 0, z - 0.15), Vector3(-HX - 2.0, 0.9, z + 0.15), k.by_age(Color("c9a43a"), Color("e0b830"), home_primary()), 0.3, 0.05)
			k.block(Vector3(-HX - 2.3, 0.9, z - 0.15), Vector3(-HX - 2.0, 1.0, z + 0.15), Color("2a2c30"), 0.3, 0.0, false)
	# bike rack: a row of steel hoops
	var steel: Color = k.by_age(Color("7d7f7e"), Color("9a9c9c"), Wear.CHARCOAL)
	for i in 5:
		var z := 11.0 + i * 0.7
		k.block(Vector3(-HX - 1.6, 0, z - 0.04), Vector3(-HX - 1.52, 0.85, z + 0.04), steel, 0.3, 0.0)
		k.block(Vector3(-HX - 0.88, 0, z - 0.04), Vector3(-HX - 0.8, 0.85, z + 0.04), steel, 0.3, 0.0)
		k.block(Vector3(-HX - 1.6, 0.85, z - 0.04), Vector3(-HX - 0.8, 0.93, z + 0.04), steel, 0.3, 0.0, false)


## Behind the arena: bollards at the garage door, the dumpster pen, the
## propane cage for the resurfacer, the ice plant's condenser on its pad.
func _back_clutter(k: VenueKit) -> void:
	var yellow: Color = k.by_age(Color("c9a43a"), Color("e0b830"), Color("f0c419"))
	for z in [-2.6, 2.6]:
		k.block(Vector3(HX + 0.3, 0, z - 0.17), Vector3(HX + 0.64, 1.1, z + 0.17), yellow, 0.3, 0.05)
	# dumpster pen: block walls on three sides, open to the lot
	var pen: Color = k.by_age(Wear.CONCRETE.darkened(0.15), Wear.CONCRETE, Color("cfcac0"))
	var px0 := HX + 0.6
	var px1 := HX + 5.0
	k.aged_block(Vector3(px0, 0, 4.2), Vector3(px1, 1.9, 4.5), pen, 0.5, 0.06)
	k.aged_block(Vector3(px0, 0, 9.0), Vector3(px1, 1.9, 9.3), pen, 0.5, 0.06)
	k.aged_block(Vector3(px0, 0, 4.5), Vector3(px0 + 0.3, 1.9, 9.0), pen, 0.5, 0.06)
	var bin: Color = k.by_age(Color("2f5a3b"), Color("2f6a45"), Color("24507a"))
	k.aged_block(Vector3(px0 + 0.6, 0.15, 4.9), Vector3(px0 + 2.5, 1.4, 6.9), bin, 0.4, 0.06)
	k.block(Vector3(px0 + 0.55, 1.4, 4.85), Vector3(px0 + 2.6, 1.5, 6.95), Color("1f2124"), 0.4, 0.03, false)
	k.aged_block(Vector3(px0 + 0.6, 0.15, 7.3), Vector3(px0 + 2.2, 1.2, 8.6), Color("5a5c60"), 0.4, 0.06)  # recycling
	if k.age == Age.WORN:
		k.block(Vector3(px0 + 2.8, 0, 5.4), Vector3(px0 + 3.5, 0.5, 6.1), Wear.PLYWOOD.darkened(0.2), 0.25, 0.1)  # a box nobody took
	# propane cage: steel frame, mesh bars, four cylinders
	var cx0 := HX + 0.4
	var cx1 := HX + 1.9
	var cz0 := 10.4
	var cz1 := 12.8
	var frame := Color("5a5e62")
	k.collider(Vector3(cx0, 0, cz0), Vector3(cx1, 2.0, cz1))
	k.block(Vector3(cx0, 1.9, cz0), Vector3(cx1, 2.0, cz1), frame, 0.5, 0.0, false)
	k.block(Vector3(cx0, 0, cz0), Vector3(cx1, 0.1, cz1), Color("8a867c"), 0.5, 0.03, false)
	for p in [Vector2(cx0, cz0), Vector2(cx1 - 0.08, cz0), Vector2(cx0, cz1 - 0.08), Vector2(cx1 - 0.08, cz1 - 0.08)]:
		k.block(Vector3(p.x, 0, p.y), Vector3(p.x + 0.08, 1.9, p.y + 0.08), frame, 0.5, 0.0, false)
	var z := cz0 + 0.2
	while z < cz1 - 0.1:
		k.block(Vector3(cx1 - 0.03, 0.1, z - 0.02), Vector3(cx1, 1.9, z + 0.02), frame.lightened(0.15), 0.5, 0.0, false)
		z += 0.25
	var x := cx0 + 0.2
	while x < cx1 - 0.1:
		for zz in [cz0, cz1 - 0.03]:
			k.block(Vector3(x - 0.02, 0.1, zz), Vector3(x + 0.02, 1.9, zz + 0.03), frame.lightened(0.15), 0.5, 0.0, false)
		x += 0.25
	for i in 4:
		var tz := cz0 + 0.45 + i * 0.5
		k.block(Vector3(cx0 + 0.45, 0.1, tz - 0.17), Vector3(cx0 + 0.8, 1.05, tz + 0.17), Color("e8e6e0") if i != 2 else Color("c8c4b8"), 0.25, 0.04, false)
		k.block(Vector3(cx0 + 0.55, 1.05, tz - 0.07), Vector3(cx0 + 0.7, 1.2, tz + 0.07), Color("8a8c8e"), 0.1, 0.0, false)
	k.block(Vector3(cx1, 1.2, cz0 + 0.8), Vector3(cx1 + 0.03, 1.6, cz1 - 0.8), Color("c8312f"), 0.2, 0.0, false)  # placard
	# ice plant condenser on its pad, piped through the wall
	var cond: Color = k.by_age(Color("8e938f"), Color("a4aaa8"), Color("c8ccce"))
	var qx0 := HX + 1.2
	var qx1 := HX + 4.6
	k.block(Vector3(HX + 0.6, 0, 18.4), Vector3(qx1 + 0.6, 0.2, 25.6), Color("8a867c"), 1.0, 0.04)
	k.aged_block(Vector3(qx0, 0.2, 19.0), Vector3(qx1, 3.0, 25.0), cond, 0.5, 0.05)
	for j in 6:
		var ly := 0.5 + j * 0.38
		k.block(Vector3(qx1, ly, 19.3), Vector3(qx1 + 0.05, ly + 0.16, 24.7), cond.darkened(0.3), 0.5, 0.0, false)
	for fz in [20.5, 23.5]:
		k.block(Vector3(qx0 + 0.4, 3.0, fz - 1.1), Vector3(qx1 - 0.4, 3.5, fz + 1.1), cond.darkened(0.1), 0.5, 0.04, false)
		k.block(Vector3(qx0 + 0.6, 3.5, fz - 0.9), Vector3(qx1 - 0.6, 3.55, fz + 0.9), Color("25272a"), 0.5, 0.0, false)
	for py in [1.8, 2.4]:
		k.block(Vector3(HX, py, 21.8), Vector3(qx0, py + 0.25, 22.05), Color("6d7680"), 0.5, 0.03, false)
	if k.age == Age.WORN:
		k.block(Vector3(qx0 - 0.02, 0.2, 21.0), Vector3(qx0, 2.2, 21.6), Wear.RUST, 0.5, 0.1, false)


## The recreation wing, added on later: a brown 70s mansard fascia round
## its roofline (stepping with each room's height), rooftop units, and a
## wall pack over each outside door.
func _rec_wing(k: VenueKit) -> void:
	var shingle: Color = k.by_age(Color("5c4532"), Color("644a34"), Wear.CHARCOAL.lightened(0.05))
	var trim: Color = k.by_age(Wear.OLD_GOLD.darkened(0.3), Wear.OLD_GOLD.darkened(0.15), home_primary())
	for id in RecPlan.ROOMS:
		var r := RecPlan.rect(id)
		var top := float(RecPlan.ROOMS[id][3]) + 0.6
		# [along, line, s0, s1, outward]
		var edges := [["x", r.position.y, r.position.x, r.end.x, Vector3(0, 0, -1)],
			["z", r.position.x, r.position.y, r.end.y, Vector3(-1, 0, 0)],
			["z", r.end.x, r.position.y, r.end.y, Vector3(1, 0, 0)]]
		for e in edges:
			if not RecPlan.is_outer(e[0], e[1]):
				continue
			var s0: float = e[2]
			var s1: float = e[3]
			var n: Vector3 = e[4]
			# wrap the building's corners
			if e[0] == "x":
				if absf(s0 - RecPlan.X_W) < 0.05:
					s0 -= 0.6
				if absf(s1 - RecPlan.X_E) < 0.05:
					s1 += 0.6
			elif absf(s0 - RecPlan.Z_BACK) < 0.05:
				s0 -= 0.6
			_mansard(k, e[0], e[1], s0, s1, n, top, shingle, trim, id)
		_rec_roof(k, id, r, top - 0.35)
	for d in RecPlan.DOORS:
		var line: float = d[2] if d[3] == "x" else d[1]
		if RecPlan.is_outer(d[3], line) and d[0] != "Main entrance":
			var n := Vector3(0, 0, -1) if d[3] == "x" else Vector3(signf(d[1]), 0, 0)
			_wall_pack(k, Vector3(d[1], float(d[5]) + 0.45, d[2]), n)


## One run of mansard: a sloped skirt of shingle courses stepping out, a
## trim board along its foot.
func _mansard(k: VenueKit, along: String, line: float, s0: float, s1: float, n: Vector3, top: float, col: Color, trim: Color, key: String) -> void:
	var courses := 4
	for c in courses:
		var out := 0.6 - c * 0.13
		var y0 := top - 0.7 + c * 0.32
		var cc := k.aged(col, [key, c]).darkened(0.05 * (c % 2))
		_edge_block(k, along, line, s0, s1, n, 0.0, out, y0, y0 + 0.34, cc, 0.5)
	_edge_block(k, along, line, s0, s1, n, 0.0, 0.66, top - 0.86, top - 0.66, k.aged(trim, key), 1.0)


## A block along an outside edge, from `d0` to `d1` metres out from the
## wall line on the outward side `n`.
func _edge_block(k: VenueKit, along: String, line: float, s0: float, s1: float, n: Vector3, d0: float, d1: float, y0: float, y1: float, col: Color, tile: float) -> void:
	if along == "x":
		k.aged_block(Vector3(s0, y0, line + n.z * d0), Vector3(s1, y1, line + n.z * d1), col, tile, 0.06, false)
	else:
		k.aged_block(Vector3(line + n.x * d0, y0, s0), Vector3(line + n.x * d1, y1, s1), col, tile, 0.06, false)


## Rooftop bits on the wing's flat roofs: a unit on the bigger rooms, a
## vent stack on the small ones.
func _rec_roof(k: VenueKit, id: String, r: Rect2, y: float) -> void:
	var c := Vector3(r.get_center().x, y, r.get_center().y)
	var box: Color = k.by_age(Color("9a9886"), Color("b0b2a8"), Color("cfd3d6"))
	if r.size.x * r.size.y > 150.0:
		k.aged_block(c + Vector3(-1.6, 0, -1.0), c + Vector3(1.6, 1.3, 1.0), box, 0.5, 0.05, false)
		k.block(c + Vector3(-1.4, 1.3, -0.8), c + Vector3(0.2, 1.36, 0.8), Color("2a2c2e"), 0.5, 0.0, false)
		k.block(c + Vector3(1.6, 0.2, -0.3), c + Vector3(2.4, 0.8, 0.3), box.darkened(0.15), 0.5, 0.03, false)
	elif posmod(hash(id), 2) == 0:
		k.block(c + Vector3(-0.2, 0, -0.2), c + Vector3(0.2, 1.1, 0.2), Color("6a6e72"), 0.3, 0.03, false)
		k.block(c + Vector3(-0.35, 1.1, -0.35), c + Vector3(0.35, 1.25, 0.35), Color("55595c"), 0.3, 0.03, false)
