class_name RecRoom
extends VenueRoom
## A room of the recreation centre wing (RecPlan). The base class builds
## the box: floor, ceiling and roof, its walls with every door opening the
## plan lists on them, the doors it owns with a RINK-OS plate over each, and
## ceiling lights. Subclasses override furnish() for what is inside.

## Key into RecPlan.ROOMS, set before the room enters the tree.
var plan_id := ""
var x0 := 0.0
var z0 := 0.0
var x1 := 0.0
var z1 := 0.0
var h := 3.0


func _ready() -> void:
	wing = "rec"
	var p: Array = RecPlan.ROOMS[plan_id]
	room_id = plan_id
	display_name = p[0]
	var r := RecPlan.rect(plan_id)
	x0 = r.position.x
	z0 = r.position.y
	x1 = r.end.x
	z1 = r.end.y
	h = p[3]
	bounds = AABB(Vector3(x0, 0, z0), Vector3(x1 - x0, h, z1 - z0))
	spawn = Vector3((x0 + x1) * 0.5, 0, (z0 + z1) * 0.5)
	for d in RecPlan.DOORS:
		if d[7] == plan_id:
			spawn = _door_pos(d) + _inward(d) * 1.2
			break


func build(k: VenueKit) -> void:
	k.occlude_walls = true
	k.slab(Vector3(x0, -0.3, z0), Vector3(x1, 0, z1), floor_color(k), floor_tile(), 0.05)
	# ceiling (seen from below, walked under) and the roof over it
	k.slab(Vector3(x0, h, z0), Vector3(x1, h + 0.25, z1), ceiling_color(k), 1.2, 0.04, true)
	k.slab(Vector3(x0, h, z0), Vector3(x1, h + 0.25, z1), k.by_age(Color("6e6a62"), Color("7a766c"), Color("8a8a86")), 2.0, 0.08, false, false)
	var walls: String = RecPlan.ROOMS[plan_id][4]
	_edge(k, "x", z0, x0, x1, 1.0, walls)
	_edge(k, "x", z1, x0, x1, -1.0, walls)
	_edge(k, "z", x0, z0, z1, 1.0, walls)
	_edge(k, "z", x1, z0, z1, -1.0, walls)
	furnish(k)
	lights(k)


## Override: what is in the room.
func furnish(_k: VenueKit) -> void:
	pass


func floor_color(k: VenueKit) -> Color:
	return k.by_age(Color("b3a684"), Color("c4bba5"), Color("a3a19b"))


func floor_tile() -> float:
	return 1.0


func ceiling_color(k: VenueKit) -> Color:
	return k.by_age(Color("c8c0a8"), Color("d8d3c4"), Color("eceae4"))


## Interior wall paint. The old athletic club was beige over wood panel.
func paint(k: VenueKit) -> Color:
	return k.by_age(Color("c9b98f"), Color("d8cfb4"), Color("e6e4de"))


## True for rooms whose outside walls are bare block inside (gym, plant).
func bare_outer() -> bool:
	return false


func brick(k: VenueKit) -> Color:
	return k.by_age(Color("8a5642"), Color("9a614b"), Color("7d7f82"))


## Default ceiling lights: a grid of fluorescent strips (a dead tube or two
## when worn) and up to three shadowless room lights.
func lights(k: VenueKit) -> void:
	var lit: Color = k.by_age(Color("e6eed8"), Color("f4f6f0"), Color("fff6e6"))
	var w := x1 - x0
	var d := z1 - z0
	var nx := maxi(1, int(w / 3.2))
	var nz := maxi(1, int(d / 3.2))
	var i := 0
	for a in nx:
		for b in nz:
			var cx := x0 + (a + 0.5) * w / nx
			var cz := z0 + (b + 0.5) * d / nz
			var c := lit
			if k.age == Age.WORN and posmod(hash(Vector3i(a, b, hash(plan_id))), 6) == 0:
				c = Color("4a4d48")
			k.glow(Vector3(cx - 0.6, h - 0.05, cz - 0.15), Vector3(cx + 0.6, h - 0.01, cz + 0.15), c)
			i += 1
	var n := clampi(int(w * d / 45.0), 1, 5)
	var long := maxf(w, d)
	var short := minf(w, d)
	var reach := clampf(0.65 * sqrt(pow(long / n, 2.0) + short * short), 5.0, 14.0)
	for j in n:
		var t := (j + 0.5) / n
		var p := Vector3(lerpf(x0, x1, t), h - 0.4, (z0 + z1) * 0.5) if w >= d else Vector3((x0 + x1) * 0.5, h - 0.4, lerpf(z0, z1, t))
		rec_light(k, p, reach)


## A room light a little brighter than the arena's back rooms: these rooms
## have no ice glare to borrow from.
func rec_light(k: VenueKit, pos: Vector3, reach: float, energy := 1.0) -> void:
	room_light(k, pos, reach)
	var l: OmniLight3D = k._extra.back()
	l.light_energy *= 1.35 * energy


# ---------------------------------------------------------------- walls

## One edge of the room: `along` "x" is a wall at z = `at` running x s0..s1;
## `inward` is the sign toward the room's inside.
func _edge(k: VenueKit, along: String, at: float, s0: float, s1: float, inward: float, walls: String) -> void:
	if along == "x" and absf(at - RecPlan.Z_ARENA) < 0.05:
		_arena_doors(k, s0, s1)
		return  # the arena's own wall (the shell cuts its openings)
	var outer := RecPlan.is_outer(along, at)
	if walls == "outer" and not outer:
		return
	if not outer:
		# up to the taller ceiling of the two rooms: the hall builds no skins
		# of its own, so a lower room's wall left a gap under its ceiling (W22)
		wall_line(k, along, at, at + inward * RecPlan.WALL * 0.5, s0, s1, maxf(h, _neighbour_h(along, at, s0, s1)), RecPlan.WALL, paint(k))
		return
	# brick outside; painted inside unless the room shows its block walls
	var t := 0.3 if bare_outer() else 0.28
	wall_line(k, along, at, at + inward * t * 0.5, s0, s1, h + 0.6, t, brick(k))
	if not bare_outer():
		wall_line(k, along, at, at + inward * 0.29, s0, s1, h, 0.02, paint(k), false)


## The tallest ceiling among the skinless rooms (walls "outer": the hall and
## the link) that share the edge line `at` over s0..s1 (0 when none does).
func _neighbour_h(along: String, at: float, s0: float, s1: float) -> float:
	var best := 0.0
	for id: String in RecPlan.ROOMS:
		if id == plan_id or RecPlan.ROOMS[id][4] != "outer":
			continue
		var r := RecPlan.rect(id)
		var lo: float = r.position.y if along == "x" else r.position.x
		var hi: float = r.end.y if along == "x" else r.end.x
		var a: float = r.position.x if along == "x" else r.position.y
		var b: float = r.end.x if along == "x" else r.end.y
		if (absf(lo - at) < 0.05 or absf(hi - at) < 0.05) and minf(b, s1) - maxf(a, s0) > 0.05:
			best = maxf(best, float(RecPlan.ROOMS[id][3]))
	return best


## Doors this room owns through the arena's wall (the shell's, 0.5 m thick
## at z -30..-29.5), opening onto the corridor under the stands.
func _arena_doors(k: VenueKit, s0: float, s1: float) -> void:
	var zc := RecPlan.Z_ARENA + Venue.WALL_T * 0.5
	for d in RecPlan.doors_on("x", RecPlan.Z_ARENA, s0, s1):
		if d[7] != plan_id:
			continue
		add_door(k, Vector3(d[1], 0, zc), 0.0, d[6], d[4], d[5], door_color(k, d), d[0])
		var text := "// RINK"
		var plate := VenueSign.make([[text, plate_color()]], text.length() + 1, 1, 0.018)
		plate.name = "Plate_%s" % String(d[0]).replace(" ", "_")
		plate.dead = k.by_age(0.05, 0.0, 0.0)
		k.sign(plate, Transform3D(Basis(Vector3.UP, PI), Vector3(d[1], d[5] + 0.32, RecPlan.Z_ARENA - 0.02)))


## An interior partition centred on the line `at` (doors listed in the plan
## on that line are cut, and hung if this room owns them).
func partition(k: VenueKit, along: String, at: float, s0: float, s1: float, col: Color, top := -1.0) -> void:
	wall_line(k, along, at, at, s0, s1, h if top < 0.0 else top, 0.2, col)


## A wall skin centred at `center` (on the axis across the wall) for the
## edge line `line`, with the plan's openings on that line.
## `fit` false makes a bare skin: openings cut, but no doors or glass.
func wall_line(k: VenueKit, along: String, line: float, center: float, s0: float, s1: float, top: float, t: float, col: Color, fit := true) -> void:
	var openings := []
	for d in RecPlan.doors_on(along, line, s0, s1):
		var pos: float = d[1] if along == "x" else d[2]
		openings.append({"at": pos, "w": d[4] + 0.04, "y0": 0.0, "y1": d[5] + 0.02})
		if fit and d[7] == plan_id and d[6] != RecPlan.OPEN:
			_hang(k, d, along, center, col)
	for w in windows(along, line):
		openings.append(w)
		if not fit:
			continue
		var g0 := Vector3(w.at - w.w * 0.5, w.y0, center - 0.03) if along == "x" else Vector3(center - 0.03, w.y0, w.at - w.w * 0.5)
		var g1 := Vector3(w.at + w.w * 0.5, w.y1, center + 0.03) if along == "x" else Vector3(center + 0.03, w.y1, w.at + w.w * 0.5)
		k.glass(g0, g1)
	if along == "x":
		k.wall_x(center, s0, s1, 0.0, top, t, col, openings, 1.0)
	else:
		k.wall_z(center, s0, s1, 0.0, top, t, col, openings, 1.0)


func _hang(k: VenueKit, d: Array, along: String, center: float, wall_col: Color) -> void:
	var pos := Vector3(d[1], 0, center) if along == "x" else Vector3(center, 0, d[2])
	var col: Color = door_color(k, d)
	add_door(k, pos, 0.0 if along == "x" else PI * 0.5, d[6], d[4], d[5], col, d[0])
	# frame around the opening
	var trim: Color = k.by_age(Color("6b4f33"), wall_col.darkened(0.25), Color("3a3d44"))
	var hw: float = d[4] * 0.5 + 0.06
	var th := 0.22 if along == "x" else 0.22
	if along == "x":
		k.block(Vector3(pos.x - hw, d[5], pos.z - th * 0.5), Vector3(pos.x + hw, d[5] + 0.08, pos.z + th * 0.5), trim, 0.5, 0.0, false)
	else:
		k.block(Vector3(pos.x - th * 0.5, d[5], pos.z - hw), Vector3(pos.x + th * 0.5, d[5] + 0.08, pos.z + hw), trim, 0.5, 0.0, false)
	# a RINK-OS plate on the outside, over the door
	var out := -_inward(d)
	var text: String = "// " + String(d[0]).to_upper()
	var plate := VenueSign.make([[text, plate_color()]], text.length() + 1, 1, 0.018)
	plate.name = "Plate_%s" % String(d[0]).replace(" ", "_").replace("'", "")
	plate.dead = k.by_age(0.05, 0.0, 0.0)
	var face := Basis.looking_at(-out, Vector3.UP)  # the sign's face looks along +Z
	k.sign(plate, Transform3D(face, pos + out * 0.17 + Vector3(0, d[5] + 0.32, 0)))


## Override: window openings (glazed) on one of this room's wall lines, as
## {"at", "w", "y0", "y1"} like a wall opening. Both rooms on a shared line
## must list the same window.
func windows(_along: String, _line: float) -> Array:
	return []


func door_color(k: VenueKit, _d: Array) -> Color:
	return k.by_age(Color("6b4f33"), Color("7a828c"), Color("2a2e36"))


func plate_color() -> Color:
	return VenueSign.CYAN


static func _door_pos(d: Array) -> Vector3:
	return Vector3(d[1], 0, d[2])


## Unit vector from the door's line into the owner room.
func _inward(d: Array) -> Vector3:
	var c := Vector3((x0 + x1) * 0.5, 0, (z0 + z1) * 0.5)
	# a door on an interior partition through the room's middle (the
	# meeting room's) leads toward the back of the building
	if d[3] == "x":
		var s := signf(c.z - d[2])
		return Vector3(0, 0, s if s != 0.0 else -1.0)
	var s := signf(c.x - d[1])
	return Vector3(s if s != 0.0 else -1.0, 0, 0)


# ---------------------------------------------------------------- furnishing helpers

## A sign on a wall: `pos` on the wall face, facing along `normal`.
func wall_sign(k: VenueKit, lines: Array, cols: int, rows: int, px: float, pos: Vector3, normal: Vector3, sign_name: String, bg := VenueSign.BG) -> VenueSign:
	var s := VenueSign.make(lines, cols, rows, px)
	s.name = sign_name
	s.background = bg
	s.dead = k.by_age(0.04, 0.0, 0.0)
	k.sign(s, Transform3D(Basis.looking_at(-normal, Vector3.UP), pos + normal * 0.01))
	return s


## A physical readable (Readable) on the wall face at `pos` with outward
## `normal`, or lying on a table when `normal` is UP (top edge toward `top`).
func readable(k: VenueKit, id: String, pos: Vector3, normal: Vector3, movable := false, top := Vector3.FORWARD) -> Readable:
	var r := Readable.make(id, movable)
	r.transform = Transform3D(Readable.on_table(top) if normal.y > 0.9 else Readable.on_wall(normal), pos + normal * 0.002)
	k.add(r)
	return r


## A plain table: top at `top_y`, four legs.
func table(k: VenueKit, a: Vector3, b: Vector3, top_y: float, col: Color, leg := Color("3a3b3e")) -> void:
	var lo := a.min(b)
	var hi := a.max(b)
	k.aged_block(Vector3(lo.x, top_y - 0.05, lo.z), Vector3(hi.x, top_y, hi.z), col, 0.6, 0.04)
	for c in [Vector2(lo.x + 0.05, lo.z + 0.05), Vector2(hi.x - 0.1, lo.z + 0.05), Vector2(lo.x + 0.05, hi.z - 0.1), Vector2(hi.x - 0.1, hi.z - 0.1)]:
		k.block(Vector3(c.x, 0, c.y), Vector3(c.x + 0.05, top_y - 0.05, c.y + 0.05), leg, 0.5, 0.0, false)


## A shelving unit `a`..`b` (floor to top) with `n` shelves and boxes on them.
func shelves(k: VenueKit, a: Vector3, b: Vector3, n: int, col: Color, stuff: Array = []) -> void:
	var lo := a.min(b)
	var hi := a.max(b)
	var sz := hi - lo
	for i in n + 1:
		var y := lo.y + sz.y * i / n
		k.block(Vector3(lo.x, y, lo.z), Vector3(hi.x, y + 0.03, hi.z), col, 0.6, 0.03, i == 0)
	for c in [lo, Vector3(hi.x - 0.04, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z - 0.04), Vector3(hi.x - 0.04, lo.y, hi.z - 0.04)]:
		k.block(c, c + Vector3(0.04, sz.y, 0.04), col.darkened(0.2), 0.5, 0.0, false)
	k.collider(lo, hi)
	if stuff.is_empty():
		return
	var along_x := sz.x >= sz.z
	var length := sz.x if along_x else sz.z
	var depth := sz.z if along_x else sz.x
	for i in n:
		var y := lo.y + sz.y * i / n + 0.03
		var gap := sz.y / n - 0.08
		var s := 0.05
		var j := 0
		while s < length - 0.2:
			var w := 0.2 + 0.35 * posmod(hash(Vector3i(i, j, int(lo.x * 10 + lo.z))), 5) / 4.0
			var hh := gap * (0.45 + 0.5 * posmod(hash(Vector2i(i, j)), 3) / 2.0)
			if posmod(hash(Vector3i(j, i, 7)), 4) != 0:
				var col2: Color = stuff[posmod(hash(Vector3i(i, j, 3)), stuff.size())]
				var dd := depth * 0.8
				if along_x:
					k.block(Vector3(lo.x + s, y, lo.z + 0.05), Vector3(lo.x + minf(s + w, length - 0.05), y + hh, lo.z + 0.05 + dd), k.aged(col2, j), 0.3, 0.06, false)
				else:
					k.block(Vector3(lo.x + 0.05, y, lo.z + s), Vector3(lo.x + 0.05 + dd, y + hh, lo.z + minf(s + w, length - 0.05)), k.aged(col2, j), 0.3, 0.06, false)
			s += w + 0.05
			j += 1


## A stacked pile of folding chairs (or anything thin) at `p`.
func stack(k: VenueKit, p: Vector3, size: Vector3, n: int, col: Color) -> void:
	for i in n:
		var y := p.y + i * size.y
		var off := 0.02 * (i % 2)
		k.block(Vector3(p.x + off, y, p.z), Vector3(p.x + size.x + off, y + size.y * 0.8, p.z + size.z), k.aged(col, i), 0.3, 0.05, i == 0)
	k.collider(p, p + Vector3(size.x, size.y * n, size.z))


## A bench seat with legs.
func bench(k: VenueKit, a: Vector3, b: Vector3, col: Color) -> void:
	table(k, a, b, 0.45, col)
