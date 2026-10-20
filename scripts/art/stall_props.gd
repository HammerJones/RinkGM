class_name DressingStalls
extends RefCounted
## Hockey dressing room stalls (playtest W8): open wooden cubbies along the
## walls, each with a bench seat, a hanging bar for gear and a small shelf
## above for gloves and a helmet. They replace the old kit "lockers" in the
## arena's and the rec wing's dressing rooms.
##
## A room's stalls are one VoxelModel on one grid (every run of stalls along
## every wall), weathered once and meshed into ONE MeshInstance3D named
## "Stalls", so twenty stalls cost one draw instead of a MultiMesh per kit
## piece. Flat panels merge (greedy meshing) to keep the triangle count down.
##
## Ages, in the room's own era:
##   WORN       70s plywood: stained ply dividers and back, a painted stripe
##              in the room's old colour, a gouged plank bench, a rusty
##              galvanised bar, duct-tape name strips.
##   REPAIRED   the same ply, patched: some dividers and bench planks
##              replaced in fresh wood, the backs repainted in the room's
##              colour, new steel bars, tape names.
##   RENOVATED  pro stalls: maple dividers, a back in the team colour, a
##              padded seat over a closed base, chrome bars, white
##              nameplates, a light strip under each shelf.
##
## The MeshInstance carries meta "stalls": one Dictionary per stall with
## "bench", "bar" and "shelf" AABBs in the room's space (tests read it).

const V := Models.V
const W := 10      # stall width in voxels (0.65 m), divider included
const D := 8       # depth from the front to the wall (0.52 m)
const H := 33      # to the top of the cap (2.15 m)
const SEAT_Y := 6  # seat board (top at 0.455 m)
const BAR_Y := 23  # hanging bar (1.5 m)
const BAR_D := 4   # bar's distance from the front, in voxels
const SHELF_Y := 27  # shelf board (1.75..1.82 m)

## One stall's width in metres.
const STALL_W := W * V
const DEPTH := D * V


## How many stalls fit along `length` metres of wall.
static func fit(length: float) -> int:
	return maxi(int(floor((length - V) / STALL_W)), 0)


## Builds the room's stalls. Each run is {"start": Vector3 (the floor point
## on the wall's inside face where the run begins), "along": Vector3 (unit
## ±X or ±Z, the way the run goes), "out": Vector3 (unit, from the wall into
## the room), "count": int}. `look`: "paint" (the room's colour, for worn
## stripes and repaired backs), "team" (renovated backs and the gear).
## Adds the mesh and one collider per run to the kit; returns the mesh.
static func build(k: VenueKit, runs: Array, look: Dictionary, seed_: int) -> MeshInstance3D:
	var m := VoxelModel.new(V)
	var origin: Vector3 = runs[0].start
	origin.y = 0.0
	var parts: Array = []
	var glows: Array = []
	for r: Dictionary in runs:
		var run := _run(r, origin)
		var n: int = r.count
		for i in n:
			parts.append(_stall(m, run, i, k.age, look, hash([seed_, i, r.start]), glows))
		_divider(m, run, n * W, k.age, look, hash([seed_, n, r.start]))
		# one box for the run: the cubbies are solid to a walker
		var lo := _aabb(run, 0, 0, 0, n * W + 1, H, D)
		k.collider(origin + lo.position, origin + lo.end)
	Wear.fine = false  # flat panels keep one colour, so they merge
	Wear.weather(m, k.age, seed_)
	Wear.fine = true
	if k.age != VenueRoom.Age.RENOVATED:
		_grain(m, k.age, seed_)
	var mi := MeshInstance3D.new()
	mi.name = "Stalls"
	mi.mesh = m.build_mesh_merged(24)
	mi.position = origin
	mi.cast_shadow = Look.cast()
	for p: Dictionary in parts:
		for key in p:
			p[key] = AABB(p[key].position + origin, p[key].size)
	mi.set_meta("stalls", parts)
	k.add(mi)
	for g: AABB in glows:
		k.glow(origin + g.position, origin + g.end, Color("fff3dc"))
	return mi


## A run's grid frame: where it starts on the grid and its two axes.
static func _run(r: Dictionary, origin: Vector3) -> Dictionary:
	var along: Vector3 = r.along
	var out: Vector3 = r.out
	var a := 0 if absf(along.x) > 0.5 else 2
	var o := 0 if absf(out.x) > 0.5 else 2
	var rel: Vector3 = (r.start - origin) / V
	return {"base": Vector3i(roundi(rel.x), 0, roundi(rel.z)), "a": a, "sa": signi(roundi(along[a])), "o": o, "so": signi(roundi(out[o]))}


## The grid cell of the stall voxel at `u` along the run, `y` up and `d`
## from the front (0) to the wall (D - 1).
static func _cell(run: Dictionary, u: int, y: int, d: int) -> Vector3i:
	var c: Vector3i = run.base
	var w := D - 1 - d
	c[run.a] += u if run.sa > 0 else -1 - u
	c[run.o] += w if run.so > 0 else -1 - w
	c.y = y
	return c


static func _fill(m: VoxelModel, run: Dictionary, u: int, y: int, d: int, su: int, sy: int, sd: int, col: Color) -> void:
	for i in su:
		for j in sy:
			for l in sd:
				var c := _cell(run, u + i, y + j, d + l)
				m.voxels[c] = col


## The box (grid metres, relative to the origin) a stall-space box covers.
static func _aabb(run: Dictionary, u: int, y: int, d: int, su: int, sy: int, sd: int) -> AABB:
	var a := Vector3(_cell(run, u, y, d)) * V
	var b := Vector3(_cell(run, u + su - 1, y + sy - 1, d + sd - 1)) * V
	var lo := a.min(b)
	var hi := a.max(b) + Vector3.ONE * V
	return AABB(lo, hi - lo)


static func _roll(seed_: int, salt: int) -> float:
	return float(posmod(hash([seed_, salt]), 1000)) / 1000.0


## The side panel at `u` (a stall's left one, or the run's last).
static func _divider(m: VoxelModel, run: Dictionary, u: int, age: int, look: Dictionary, seed_: int) -> void:
	var ply := Wear.PLYWOOD.darkened(0.18)
	var col: Color = [ply, Wear.NEW_WOOD if _roll(seed_, 1) < 0.3 else ply, Wear.NEW_WOOD.lerp(Color("e3c79a"), 0.4)][age]
	_fill(m, run, u, 0, 0, 1, H, D, col)
	if age != VenueRoom.Age.RENOVATED:
		# 70s ply: a scalloped front edge between the seat and the shelf
		for y in range(SEAT_Y + 3, SHELF_Y - 2):
			m.voxels.erase(_cell(run, u, y, 0))
		_fill(m, run, u, 0, 0, 1, 1, D, Wear.OLD_WOOD_DARK)  # scuffed foot
	else:
		_fill(m, run, u, H - 1, 0, 1, 1, 1, look.get("team", Wear.NAVY))  # top accent


## One stall, `i` along the run. Returns its bench, bar and shelf boxes.
static func _stall(m: VoxelModel, run: Dictionary, i: int, age: int, look: Dictionary, seed_: int, glows: Array) -> Dictionary:
	var u := i * W
	var paint: Color = look.get("paint", Wear.OLD_AVOCADO)
	var team: Color = look.get("team", Wear.NAVY)
	var worn := age == VenueRoom.Age.WORN
	var new := age == VenueRoom.Age.RENOVATED
	_divider(m, run, u, age, look, seed_)
	var x := u + 1
	var w := W - 1
	# back panel against the wall
	var back: Color = [Wear.PLYWOOD.darkened(0.08), paint, team][age]
	_fill(m, run, x, 0, D - 1, w, H, 1, back)
	if worn:
		_fill(m, run, x, BAR_Y - 6, D - 1, w, 2, 1, paint)  # the club's painted stripe
	elif not new and _roll(seed_, 2) < 0.25:
		_fill(m, run, x, 2, D - 1, w, 6, 1, Wear.PLYWOOD)  # an unpainted patch low down
	# the bench seat
	var bench_col: Color = [Wear.OLD_WOOD, Wear.NEW_WOOD if _roll(seed_, 3) < 0.5 else Wear.OLD_WOOD, Wear.CHARCOAL][age]
	var bench := _aabb(run, x, SEAT_Y, 0, w, 1, D - 1)
	if new:
		_fill(m, run, x, 1, 0, w, SEAT_Y - 1, 1, Wear.NEW_WOOD.darkened(0.12))  # closed base
		_fill(m, run, x, 0, 0, w, 1, 1, Wear.CHARCOAL)  # toe kick
		_fill(m, run, x, SEAT_Y - 1, 0, w, 1, D - 1, Wear.NEW_WOOD.darkened(0.12))
		_fill(m, run, x, SEAT_Y, 0, w, 2, D - 1, Wear.CHARCOAL)  # the pad
		_fill(m, run, x, SEAT_Y + 1, 0, w, 1, 1, team.lightened(0.15))  # piping
		bench = _aabb(run, x, SEAT_Y, 0, w, 2, D - 1)
	else:
		_fill(m, run, x, SEAT_Y, 0, w, 1, D - 1, bench_col)
		_fill(m, run, x, SEAT_Y - 1, 0, w, 1, 1, Wear.OLD_WOOD_DARK)  # front apron
		if worn:
			for g in [2, 6]:
				m.voxels[_cell(run, x + g, SEAT_Y, 0)] = Wear.CONCRETE  # skate gouges
	# the hanging bar, wall to wall across the stall
	var bar_col: Color = [Wear.OLD_STEEL, Wear.STEEL.darkened(0.08), Wear.STEEL.lightened(0.1)][age]
	_fill(m, run, x, BAR_Y, BAR_D, w, 1, 1, bar_col)
	var bar := _aabb(run, x, BAR_Y, BAR_D, w, 1, 1)
	if worn:
		m.voxels[_cell(run, x + 1 + posmod(seed_, w - 2), BAR_Y, BAR_D)] = Wear.RUST
	# the shelf above, for gloves and a helmet
	var shelf_col: Color = [Wear.PLYWOOD.darkened(0.12), Wear.PLYWOOD.darkened(0.05), Wear.NEW_WOOD][age]
	_fill(m, run, x, SHELF_Y, 0, w, 1, D - 1, shelf_col)
	var shelf := _aabb(run, x, SHELF_Y, 0, w, 1, D - 1)
	# the cap and its name strip
	var cap: Color = [Wear.PLYWOOD.darkened(0.2), Wear.PLYWOOD.darkened(0.12), Wear.NEW_WOOD.darkened(0.05)][age]
	_fill(m, run, x, H - 2, 0, w, 2, D - 1, cap)
	if new:
		_fill(m, run, x + 2, H - 2, 0, w - 4, 1, 1, Wear.WHITE)  # nameplate
		glows.append(_strip(run, x, w))
	elif _roll(seed_, 4) < (0.75 if worn else 0.9):
		_fill(m, run, x + 1 + posmod(seed_ >> 3, 2), H - 2, 0, 5, 1, 1, Wear.DUCT_TAPE)  # tape and marker
	# what's in it: a sweater on the bar, a helmet and gloves up top, skates
	# renovated backs are the team colour, so the sweaters hang as whites
	var kit: Color = [paint.lerp(Wear.OLD_CREAM, 0.2), team, Wear.WHITE][age]
	var stripe: Color = [Wear.OLD_GOLD, Wear.WHITE, team][age]
	if _roll(seed_, 5) < 0.55:
		_fill(m, run, x + 2, BAR_Y - 8, BAR_D, w - 4, 8, 1, kit)  # hung sweater
		_fill(m, run, x + 1, BAR_Y - 2, BAR_D, 1, 2, 1, kit)      # its shoulders
		_fill(m, run, x + w - 2, BAR_Y - 2, BAR_D, 1, 2, 1, kit)
		_fill(m, run, x + 2, BAR_Y - 5, BAR_D, w - 4, 1, 1, stripe)  # stripe
	if _roll(seed_, 6) < 0.7:
		var hc: Color = [Wear.CHARCOAL, team, Wear.WHITE, Wear.CHARCOAL][posmod(seed_ >> 5, 4)]
		_fill(m, run, x + 1, SHELF_Y + 1, 2, 3, 3, 3, hc)  # helmet
		_fill(m, run, x + 1, SHELF_Y + 1, 1, 3, 2, 1, Wear.STEEL if not worn else Wear.OLD_STEEL)  # cage
	if _roll(seed_, 7) < 0.65:
		var gc: Color = Wear.OLD_BROWN if worn else team.darkened(0.2)
		_fill(m, run, x + 5, SHELF_Y + 1, 1, 2, 2, 3, gc)  # gloves, cuffs out
		_fill(m, run, x + 7, SHELF_Y + 1, 1, 2, 2, 3, gc)
	if not new and _roll(seed_, 8) < 0.4:
		_fill(m, run, x + 2, 0, 1, 1, 2, 4, Wear.RUBBER)  # skates under the bench
		_fill(m, run, x + 4, 0, 1, 1, 2, 4, Wear.RUBBER)
	return {"bench": bench, "bar": bar, "shelf": shelf}


## The light strip under a renovated shelf's front edge, grid metres.
static func _strip(run: Dictionary, x: int, w: int) -> AABB:
	var b := _aabb(run, x, SHELF_Y, 0, w, 1, 1)
	var y := b.position.y
	return AABB(Vector3(b.position.x, y - 0.012, b.position.z), Vector3(b.size.x, 0.012, b.size.z)).grow(-0.002)


## A little plywood grain on the old stalls: alternate rows of the dividers
## and backs a shade darker (after weathering, so it survives the merge).
static func _grain(m: VoxelModel, age: int, seed_: int) -> void:
	for p: Vector3i in m.voxels:
		if posmod(p.y + (p.x + p.z) / 3, 5) == 0 and _roll(seed_, hash(p)) < 0.6:
			m.voxels[p] = m.voxels[p].darkened(0.06 if age == VenueRoom.Age.WORN else 0.04)
