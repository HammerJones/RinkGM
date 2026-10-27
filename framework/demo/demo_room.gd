extends WorldChunk
## One room of the world demo: a 10 x 8 m box in a row of rooms along x,
## a doorway in its west wall (and east, for the last one), a lamp, and a
## theme that decides what sits on its table and floor. Built in code so
## the demo needs no editor work; a real room would be a scene with its
## walls as nodes and the same `populate`.

const SIZE := Vector3(10.0, 3.0, 8.0)
const THEMES := [
	{
		"name": "LOBBY",
		"wall": "9fb8a8",
		"props":
		[
			"wall_clock",
			"wall_phone_booth",
			"desk_phone",
			"coffee_mug",
			"coffee_mug",
			"micro_cassette"
		]
	},
	{
		"name": "BREAK ROOM",
		"wall": "b8a89f",
		"props": ["microwave", "coffee_mug", "coffee_mug", "coffee_mug", "boombox", "vhs_tape"]
	},
	{
		"name": "LOUNGE",
		"wall": "9fa8b8",
		"props": ["tv_crt", "vcr", "vhs_tape", "vhs_tape", "vhs_tape", "record_player"]
	},
	{
		"name": "OFFICE",
		"wall": "b8b49f",
		"props":
		[
			"desk_phone",
			"soviet_phone",
			"walkie_talkie",
			"walkie_talkie",
			"micro_cassette",
			"micro_cassette",
			"coffee_mug"
		]
	},
	{
		"name": "STORE ROOM",
		"wall": "a8a8a8",
		"props":
		[
			"boombox",
			"microwave",
			"vcr",
			"coffee_mug",
			"coffee_mug",
			"walkie_talkie",
			"vhs_tape",
			"vhs_tape",
			"tv_crt"
		]
	},
]

@export var theme := 0
@export var last := false

var _body: StaticBody3D


func _ready() -> void:
	_body = StaticBody3D.new()
	_body.name = "Shell"
	_body.collision_layer = Layers.bit(Layers.VENUE)
	_body.collision_mask = 0
	add_child(_body)
	var c := bounds.get_center()
	var wall := Color(THEMES[theme].wall)
	_slab(Vector3(c.x, -0.1, c.z), Vector3(SIZE.x, 0.2, SIZE.z), Color("8a8676"))
	_slab(Vector3(c.x, SIZE.y + 0.1, c.z), Vector3(SIZE.x, 0.2, SIZE.z), Color("d8d4c8"))
	_slab(Vector3(c.x, SIZE.y / 2, c.z - SIZE.z / 2 - 0.1), Vector3(SIZE.x, SIZE.y, 0.2), wall)
	_slab(Vector3(c.x, SIZE.y / 2, c.z + SIZE.z / 2 + 0.1), Vector3(SIZE.x, SIZE.y, 0.2), wall)
	_door_wall(c.x - SIZE.x / 2 - 0.1, c.z, wall)
	if last:
		_door_wall(c.x + SIZE.x / 2 + 0.1, c.z, wall)
	# a table against the back wall and a counter along the front
	_slab(Vector3(c.x, 0.72, c.z - 2.8), Vector3(3.0, 0.06, 1.0), Color("6e4a2a"))
	for tx in [-1.4, 1.4]:
		for tz in [-3.2, -2.4]:
			_slab(Vector3(c.x + tx, 0.35, c.z + tz), Vector3(0.06, 0.7, 0.06), Color("4a3424"))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(c.x, SIZE.y - 0.3, c.z)
	lamp.light_energy = 1.6
	lamp.omni_range = 9.0
	lamp.light_color = Color(1.0, 0.96, 0.88)
	add_child(lamp)
	var sign := Label3D.new()
	sign.text = THEMES[theme].name
	sign.font_size = 96
	sign.pixel_size = 0.004
	sign.position = Vector3(c.x, 2.4, c.z - SIZE.z / 2 + 0.02)
	sign.modulate = Color(0.1, 0.1, 0.12)
	add_child(sign)


## A wall across z at `x` with a 1.6 m wide, 2.2 m tall doorway in it.
func _door_wall(x: float, cz: float, colour: Color) -> void:
	var side := (SIZE.z - 1.6) / 2
	_slab(Vector3(x, SIZE.y / 2, cz - SIZE.z / 2 + side / 2), Vector3(0.2, SIZE.y, side), colour)
	_slab(Vector3(x, SIZE.y / 2, cz + SIZE.z / 2 - side / 2), Vector3(0.2, SIZE.y, side), colour)
	_slab(Vector3(x, 2.2 + (SIZE.y - 2.2) / 2, cz), Vector3(0.2, SIZE.y - 2.2, 1.6), colour)


func _slab(at: Vector3, size: Vector3, colour: Color) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = at
	_body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.95
	mi.material_override = mat
	_body.add_child(mi)
	if size.x > 1.0 and size.y > 1.0 or size.z > 1.0 and size.y > 1.0:
		occluder_boxes.append(AABB(at - size / 2, size))


## The theme's props: wall things on the walls, the rest along the table
## and spilling onto the floor. Ids are "<chunk>.<prop>.<n>" so a saved
## row finds its place and a taken one stays taken.
func populate(objects: WorldObjects) -> void:
	var c := bounds.get_center()
	var n := 0
	var on_table := 0
	var on_floor := 0
	for prop in THEMES[theme].props:
		var id := "%s.%s.%d" % [chunk_id, prop, n]
		n += 1
		var xf: Transform3D
		if prop == "wall_clock":
			xf = Transform3D(Basis(Vector3.UP, PI), Vector3(c.x, 2.0, c.z + SIZE.z / 2 - 0.14))
		elif prop == "wall_phone_booth":
			xf = Transform3D(Basis.IDENTITY, Vector3(c.x + 3.5, 0.6, c.z - SIZE.z / 2 + 0.25))
		elif on_table < 4:
			xf = Transform3D(
				Basis(Vector3.UP, 0.3 * on_table - 0.4),
				Vector3(c.x - 1.1 + on_table * 0.75, 0.75, c.z - 2.8)
			)
			on_table += 1
		else:
			xf = Transform3D(
				Basis(Vector3.UP, 0.9 * on_floor),
				Vector3(c.x - 2.5 + on_floor * 1.2, 0.0, c.z + 1.0 + (on_floor % 2) * 0.8)
			)
			on_floor += 1
		objects.spawn(prop, xf, id, field)
