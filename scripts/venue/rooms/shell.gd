extends VenueRoom
## The building envelope: floor around the ice, outer block walls with fire
## exits, a walker collider for the boards and the ice, and the clutter in
## the four corners. The end rooms (lobby, locker rooms, Zamboni bay) close
## the envelope between z -14 and 14 themselves.

const RUBBER := Color("34373d")
const PlantRoom := preload("res://scripts/venue/rooms/plant_room.gd")

## Gaps in the walker's board collider: bench and penalty-box gates on the
## sides, the Zamboni gate at the +X end. [axis value, from, to, which wall]
const GATES := [
	["z-", -11.4, -10.5], ["z-", -3.5, -2.6], ["z-", 2.6, 3.5], ["z-", 10.5, 11.4],
	["z+", -2.9, -2.0], ["z+", 2.0, 2.9],
	["x+", -1.8, 1.8],
]


func _ready() -> void:
	room_id = "shell"
	display_name = "Arena shell"
	bounds = AABB(Vector3(-Venue.HALF_X, 0, -Venue.HALF_Z), Vector3(Venue.HALF_X * 2, Venue.ROOF_Y, Venue.HALF_Z * 2))
	spawn = Vector3(-Venue.END_FRONT + 1.5, 0, 0)


func build(k: VenueKit) -> void:
	var hx := Venue.HALF_X
	var hz := Venue.HALF_Z
	var rx := Rink.HALF_L
	var rz := Rink.HALF_W
	var floor_col: Color = k.by_age(Color("2f3136"), RUBBER, Color("25272c"))
	# rubber floor around the ice (four slabs leave the rink rectangle open)
	k.slab(Vector3(-hx, -0.3, -hz), Vector3(hx, 0, -rz), floor_col)
	# the +Z side leaves a hole for the plant room's header trench
	var tr := PlantRoom.trench_rect()
	k.slab(Vector3(-hx, -0.3, rz), Vector3(tr.position.x, 0, hz), floor_col)
	k.slab(Vector3(tr.end.x, -0.3, rz), Vector3(hx, 0, hz), floor_col)
	k.slab(Vector3(tr.position.x, -0.3, rz), Vector3(tr.end.x, 0, tr.position.y), floor_col)
	k.slab(Vector3(tr.position.x, -0.3, tr.end.y), Vector3(tr.end.x, 0, hz), floor_col)
	k.slab(Vector3(-hx, -0.3, -rz), Vector3(-rx, 0, rz), floor_col)
	k.slab(Vector3(rx, -0.3, -rz), Vector3(hx, 0, rz), floor_col)
	# the ice itself is the rink's mesh; a walker still needs something to stand on
	k.collider(Vector3(-rx, -0.3, -rz), Vector3(rx, 0, rz))
	_board_colliders(k)
	# outer walls
	var wall_col: Color = k.by_age(Wear.CONCRETE.darkened(0.08), Wear.CONCRETE, Color("d8d4cb"))
	var t := Venue.WALL_T
	for s in [-1, 1]:
		var z: float = s * (hz - t * 0.5)
		var exits := [{"at": -40.0, "w": 1.9, "y0": 0.0, "y1": 2.3}, {"at": 40.0, "w": 1.9, "y0": 0.0, "y1": 2.3}]
		k.wall_x(z, -hx, hx, 0, Venue.ROOF_Y, t, wall_col, exits, 1.0)
		for ex in [-40.0, 40.0]:
			var d := add_door(k, Vector3(ex, 0, z), 0.0 if s < 0 else PI, VenueDoor.Kind.DOUBLE, 1.9, 2.3, Color("6d7680"), "Exit %s%d" % ["N" if s < 0 else "S", int(ex)])
			d.position.z -= s * 0.02
			_exit_sign(k, Vector3(ex, 2.7, z - s * (t * 0.5 + 0.02)), s)
		for ex in [-1, 1]:
			var x: float = ex * (hx - t * 0.5)
			var z0: float = s * Venue.ROOM_Z
			var z1: float = s * hz
			k.wall_z(x, z0, z1, 0, Venue.ROOF_Y, t, wall_col, [], 1.0)
	# painted bands at eye level: the old 70s orange and gold, or the club colour
	var bands: Array = [home_primary()] if k.age == VenueRoom.Age.RENOVATED else [Wear.OLD_ORANGE, Wear.OLD_GOLD]
	for s in [-1, 1]:
		var zf: float = s * (hz - t - 0.01)
		for bi in bands.size():
			var y0 := 2.6 + bi * 0.4
			k.aged_block(Vector3(-hx + t, y0, zf), Vector3(hx - t, y0 + 0.3, zf - s * 0.03), bands[bi], 1.0, 0.05, false)
	_corners(k)


## Boards and glass: boxes along the board line up to the top of the glass
## (VenuePhysics), with gaps where the gates are. A walker can't climb them and
## a puck flying back from the stands bounces off them.
func _board_colliders(k: VenueKit) -> void:
	var step := 1.0
	var sx := Rink.HALF_L - Rink.CORNER_R
	var sz := Rink.HALF_W - Rink.CORNER_R
	var samples := []  # [pos, normal]
	var x := -sx
	while x < sx:
		samples.append([Vector2(x + step * 0.5, -Rink.HALF_W), Vector2(0, -1)])
		samples.append([Vector2(x + step * 0.5, Rink.HALF_W), Vector2(0, 1)])
		x += step
	var z := -sz
	while z < sz:
		samples.append([Vector2(-Rink.HALF_L, z + step * 0.5), Vector2(-1, 0)])
		samples.append([Vector2(Rink.HALF_L, z + step * 0.5), Vector2(1, 0)])
		z += step
	var arc := int(ceil(Rink.CORNER_R * PI * 0.5 / step))
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			for i in arc:
				var a := (i + 0.5) / arc * PI * 0.5
				var dir := Vector2(cx * cos(a), cz * sin(a))
				samples.append([Vector2(cx * sx, cz * sz) + dir * Rink.CORNER_R, dir])
	for smp in samples:
		var p: Vector2 = smp[0]
		var n: Vector2 = smp[1]
		if _in_gate(p, n):
			continue
		var c := p + n * 0.16
		var half := Vector2(absf(n.y) * step * 0.5 + absf(n.x) * 0.16, absf(n.x) * step * 0.5 + absf(n.y) * 0.16)
		k.collider(Vector3(c.x - half.x, 0, c.y - half.y), Vector3(c.x + half.x, VenuePhysics.board_top() + VenuePhysics.glass_height(p, n), c.y + half.y))


func _in_gate(p: Vector2, n: Vector2) -> bool:
	for g in GATES:
		var wall: String = g[0]
		if wall == "z-" and n.y < -0.99 and p.x > g[1] and p.x < g[2]:
			return true
		if wall == "z+" and n.y > 0.99 and p.x > g[1] and p.x < g[2]:
			return true
		if wall == "x+" and n.x > 0.99 and p.y > g[1] and p.y < g[2]:
			return true
	return false


func _exit_sign(k: VenueKit, pos: Vector3, s: int) -> void:
	var sign := VenueSign.make([["EXIT", VenueSign.GREEN]], 4, 1, 0.025)
	sign.name = "ExitSign"
	var basis := Basis(Vector3.UP, 0.0 if s < 0 else PI)
	k.sign(sign, Transform3D(basis, pos))


## Corner clutter between the side stands and the end rooms. A worn rink
## keeps junk here; a renovated one has a fan zone with high-top tables.
func _corners(k: VenueKit) -> void:
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			var x0: float = cx * 27.0
			var z0: float = cz * 26.5
			match k.age:
				VenueRoom.Age.WORN:
					# stacked folding chairs, puck buckets
					for i in 4:
						k.block(Vector3(x0 + cx * i * 0.6, 0, z0), Vector3(x0 + cx * (i * 0.6 + 0.5), 0.9 + 0.12 * (i % 2), z0 + cz * 0.5), k.aged(Wear.OLD_STEEL, i), 0.25, 0.1)
					for i in 3:
						k.block(Vector3(x0 - cx * 1.2, 0, z0 + cz * (i * 0.55)), Vector3(x0 - cx * 0.8, 0.45, z0 + cz * (i * 0.55 + 0.4)), Color("2c2d31"), 0.2, 0.1)
				VenueRoom.Age.REPAIRED:
					for i in 3:
						k.block(Vector3(x0 + cx * i * 1.4, 0, z0), Vector3(x0 + cx * (i * 1.4 + 1.0), 0.45, z0 + cz * 0.4), Wear.OLD_WOOD, 0.25, 0.06)
				VenueRoom.Age.RENOVATED:
					for i in 3:
						var tx: float = x0 + cx * i * 1.8
						k.block(Vector3(tx - 0.05, 0, z0 - 0.05), Vector3(tx + 0.05, 1.05, z0 + 0.05), Wear.CHARCOAL, 0.5, 0.0)
						k.block(Vector3(tx - 0.4, 1.05, z0 - 0.4), Vector3(tx + 0.4, 1.1, z0 + 0.4), home_primary(), 0.4, 0.03)
			# a drinks machine and a bin from the Props kit in every corner
			k.prop("vending_machine", Vector3(x0 + cx * 3.45, 0, z0 + cz * 2.05), 0.0 if cz > 0 else PI)
			k.prop("trash_can", Vector3(x0 + cx * 4.4, 0, z0 + cz * 2.1), 0.0 if cz > 0 else PI)
