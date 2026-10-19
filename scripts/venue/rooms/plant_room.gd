extends VenueRoom
## The ice plant room in the +X/+Z corner, beside the visitors' dressing room
## and round the corner from the resurfacer bay: two compressors, the
## chiller and receiver along the outside wall, the glycol pumps and tank,
## the supply and return header in its floor trench, the control panel, the
## eyewash and the ammonia detectors, and the pipe runs overhead. Laid out
## from the asset kit's plant props as in art/tools/plant_room_preview.gd.
##
## Everything is placed in "plant space", the preview's own coordinates (x
## across the room, z from the front wall at 0 to the back wall at 8.8,
## floor at 0), and PLANT turns that into the venue: the back wall is the
## building's +X outside wall and the front, with the door, faces the end of
## the rink. The shell leaves the header trench out of its floor
## (trench_rect()).

const BACK := 8.8
const LEFT := -6.4
const RIGHT := 7.4
const TRENCH := Vector2(1.0, 2.3)  # plant-space z extent of the trench
const TRENCH_X := 0.8              # the trench runs from here to the right wall
const H := 4.2                     # ceiling; the risers go up through it
const DOOR_X := -2.0               # plant-space x of the door in the front wall
## Plant space to venue space: +z (into the room) is venue +X, +x is venue -Z.
const PLANT := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(Venue.HALF_X - Venue.WALL_T - BACK, 0, 21.7))

static var _frost := {}
var _seg := 1.04


## The header trench in venue space, as Rect2(x, z, size x, size z).
static func trench_rect() -> Rect2:
	var a := PLANT * Vector3(TRENCH_X, 0, TRENCH.x)
	var b := PLANT * Vector3(RIGHT, 0, TRENCH.y)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.z, b.z)), Vector2(absf(a.x - b.x), absf(a.z - b.z)))


var _door: VenueDoor

func _ready() -> void:
	room_id = "plant_room"
	display_name = "Ice plant"
	var a := PLANT * Vector3(RIGHT, 0, 0)
	var b := PLANT * Vector3(LEFT, H, BACK)
	bounds = AABB(a.min(b), (a - b).abs())
	spawn = PLANT * Vector3(DOOR_X, 0, 3.0)


func build(k: VenueKit) -> void:
	_seg = Props.Plant.PIPE_LEN * Props.V
	_room(k)
	_plant(k)
	_plumbing(k)
	_lights(k)
	_spots(k)


# ---------------------------------------------------------------- helpers

## A box given by two plant-space corners.
func _block(k: VenueKit, a: Vector3, b: Vector3, col: Color, tile := 0.5, jitter := 0.06, solid := true) -> void:
	k.block(PLANT * a, PLANT * b, col, tile, jitter, solid)


func _prop(k: VenueKit, id: String, p: Vector3, yaw_deg := 0.0, solid := true) -> void:
	k.prop(id, PLANT * p, PI * 0.5 + deg_to_rad(yaw_deg), solid)


func _piece(k: VenueKit, mesh: Mesh, xf: Transform3D) -> void:
	k.instance(mesh, PLANT * xf)


## A refrigerant pipe piece frosted over, for the suction lines on the old
## plant (the cold side frosts white).
func _frosted(id: String, age: int) -> ArrayMesh:
	var key := "%s/%d" % [id, age]
	if not _frost.has(key):
		var m := Props.model(id, age)
		if age != Age.RENOVATED:
			for p in m.voxels:
				if posmod(hash(p), 10) < 8:
					m.voxels[p] = Color("e8eef1")
		_frost[key] = m.build_mesh()
	return _frost[key]


## Straight pipe pieces along an axis-aligned centreline from `a` to `b`.
## `valves` lists piece indexes to swap for the valve piece.
func _run(k: VenueKit, kind: String, a: Vector3, b: Vector3, valves := [], frost := false) -> void:
	var d := b - a
	var length := d.length()
	var n := maxi(ceili(length / _seg - 0.01), 1)
	var step := (length - _seg) / maxf(n - 1, 1)
	var dir := d.normalized()
	for i in n:
		var c := a + dir * (_seg * 0.5 + step * i) if n > 1 else (a + b) * 0.5
		var id := "pipe_%s_valve" % kind if i in valves else "pipe_%s" % kind
		var mesh: Mesh = _frosted(id, k.age) if frost else Props.mesh(id, k.age)
		if absf(dir.y) > 0.5:
			_piece(k, mesh, Transform3D(Basis(Vector3.BACK, PI * 0.5), c + Vector3(0.13, 0, 0)))
		else:
			_piece(k, mesh, Transform3D(Basis(Vector3.UP, PI * 0.5 if absf(dir.z) > 0.5 else 0.0), c - Vector3(0, 0.13, 0)))


## An elbow whose corner is at `corner` (centreline): yaw 0 joins the -X and
## -Z legs.
func _elbow(k: VenueKit, kind: String, corner: Vector3, yaw_deg: float) -> void:
	_piece(k, Props.mesh("pipe_%s_elbow" % kind, k.age), Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), corner - Vector3(0, 0.13, 0)))


# ---------------------------------------------------------------- room

func _room(k: VenueKit) -> void:
	var ren := k.age == Age.RENOVATED
	var concrete: Color = k.by_age(Color("6f6a60"), Color("77736a"), Color("7d8287"))
	var low: Color = Wear.NAVY if ren else Wear.OLD_MINT.darkened(0.15)
	var high: Color = Wear.WHITE if ren else Wear.OLD_CREAM
	# floor round the header trench (the shell leaves the trench open)
	var t0 := TRENCH.x
	var t1 := TRENCH.y
	_block(k, Vector3(LEFT, 0, t1), Vector3(RIGHT, 0.02, BACK), concrete, 1.0, 0.07, false)
	_block(k, Vector3(LEFT, 0, 0), Vector3(RIGHT, 0.02, t0), concrete, 1.0, 0.07, false)
	_block(k, Vector3(LEFT, 0, t0), Vector3(TRENCH_X, 0.02, t1), concrete, 1.0, 0.07, false)
	# the trench: floor, sides and ends, all concrete
	var hd := Props.Plant.HEADER_TRENCH * Props.V
	var pit := concrete.darkened(0.3)
	_block(k, Vector3(TRENCH_X, -hd - 0.1, t0), Vector3(RIGHT, -hd, t1), pit, 0.5, 0.08)
	_block(k, Vector3(TRENCH_X, -hd, t0 - 0.1), Vector3(RIGHT, 0, t0), pit, 0.5, 0.08)
	_block(k, Vector3(TRENCH_X, -hd, t1), Vector3(RIGHT, 0, t1 + 0.1), pit, 0.5, 0.08)
	_block(k, Vector3(TRENCH_X - 0.1, -hd, t0), Vector3(TRENCH_X, 0, t1), pit, 0.5, 0.08)
	# a run of grating over the end of the trench by the walkway
	var grate: Color = Wear.STEEL if ren else Wear.OLD_STEEL.darkened(0.25)
	_block(k, Vector3(TRENCH_X, 0, t0), Vector3(TRENCH_X + 1.0, 0.04, t1), grate, 0.25, 0.1)
	# safety lines round the compressors, oil and glycol stains on an old floor
	var line: Color = Props.Plant.SAFETY_YELLOW if ren else Wear.OLD_GOLD.darkened(0.2)
	for cx in [-3.6, -0.3]:
		_block(k, Vector3(cx - 1.45, 0.02, 3.57), Vector3(cx + 1.45, 0.03, 3.63), line, 1.0, 0.0, false)
		if not ren:
			_block(k, Vector3(cx - 0.25, 0.02, 3.5), Vector3(cx + 0.45, 0.026, 4.0), Color("2a241d"), 0.3, 0.1, false)
			_block(k, Vector3(cx - 0.68, 0.02, 3.35), Vector3(cx - 0.33, 0.026, 3.65), Color("3a3227"), 0.3, 0.1, false)
	if not ren:
		_block(k, Vector3(4.95, 0.02, 3.05), Vector3(5.85, 0.026, 3.75), Color("4f5a43"), 0.3, 0.1, false)
	# walls: front with the door, the two sides; the back is the building's
	# outside wall. Two-tone block paint inside.
	var f0 := PLANT * Vector3(0, 0, -0.15)
	k.wall_z(f0.x, (PLANT * Vector3(RIGHT, 0, 0)).z, (PLANT * Vector3(LEFT, 0, 0)).z, 0, H, 0.3, k.by_age(high.darkened(0.12), high, high),
		[{"at": (PLANT * Vector3(DOOR_X, 0, 0)).z, "w": 1.0, "y0": 0.0, "y1": 2.2}], 0.4)
	_door = add_door(k, PLANT * Vector3(DOOR_X, 0, -0.15), PI * 0.5, VenueDoor.Kind.SWING, 0.95, 2.2, k.by_age(Color("6b6f73"), Color("7d858c"), Wear.CHARCOAL), "Ice plant")
	for sx in [LEFT, RIGHT]:
		var s := 1.0 if sx > 0.0 else -1.0
		var p := PLANT * Vector3(sx + s * 0.1, 0, 0)
		k.wall_x(p.z, (PLANT * Vector3(0, 0, -0.3)).x, Venue.HALF_X - Venue.WALL_T, 0, H, 0.2, k.by_age(high.darkened(0.12), high, high), [], 0.4)
	# wainscot: the low 1.2 m painted darker on the inside of each wall
	var w := 0.02
	_block(k, Vector3(LEFT, 0, BACK - w), Vector3(RIGHT, 1.2, BACK), low, 0.4, 0.05, false)
	_block(k, Vector3(LEFT, 0, 0), Vector3(LEFT + w, 1.2, BACK), low, 0.4, 0.05, false)
	_block(k, Vector3(RIGHT - w, 0, 0), Vector3(RIGHT, 1.2, BACK), low, 0.4, 0.05, false)
	_block(k, Vector3(LEFT, 0, 0), Vector3(DOOR_X - 0.5, 1.2, w), low, 0.4, 0.05, false)
	_block(k, Vector3(DOOR_X + 0.5, 0, 0), Vector3(RIGHT, 1.2, w), low, 0.4, 0.05, false)
	_block(k, Vector3(LEFT, 1.2, BACK - w), Vector3(RIGHT, H, BACK), high, 0.4, 0.04, false)
	# ceiling
	var c0 := PLANT * Vector3(LEFT - 0.2, H, -0.3)
	var c1 := PLANT * Vector3(RIGHT + 0.2, H + 0.2, BACK)
	k.slab(c0, c1, k.by_age(Color("8b877e"), Color("98948a"), Color("d8d8d4")), 1.0, 0.05, true, false)
	# AMMONIA MACHINERY ROOM placard on the back wall, yellow and black
	_block(k, Vector3(-1.9, 1.775, BACK - 0.05), Vector3(-0.9, 2.225, BACK - 0.02), Color("e8b82a"), 0.5, 0.0, false)
	_block(k, Vector3(-1.8, 2.05, BACK - 0.06), Vector3(-1.0, 2.11, BACK - 0.05), Color("1a1a1a"), 0.5, 0.0, false)
	_block(k, Vector3(-1.7, 1.91, BACK - 0.06), Vector3(-1.1, 1.97, BACK - 0.05), Color("1a1a1a"), 0.5, 0.0, false)
	# the engraved phenolic sign over the door (1974), lit by the room
	# a caged bulkhead lamp over the door, so the notes can be read at 05:00
	var cage := PLANT * Vector3(DOOR_X, 2.75, -0.42)
	k.glow(cage - Vector3(0.06, 0.05, 0.06), cage + Vector3(0.06, 0.05, 0.06), Color("ffe3b0") if k.age == Age.WORN else Color("fff3dc"))
	k.block(cage + Vector3(-0.09, 0.05, -0.09), cage + Vector3(0.09, 0.09, 0.09), Color("3b3d40"), 1.0, 0.0, false)
	var bulk := OmniLight3D.new()
	bulk.position = cage + Vector3(-0.15, -0.15, 0)
	bulk.omni_range = 4.5
	bulk.omni_attenuation = 1.3
	bulk.light_energy = k.by_age(0.9, 1.1, 1.2)
	bulk.light_color = Color("ffd9a0") if k.age == Age.WORN else Color("fff0d8")
	Look.fixture(bulk)
	bulk.shadow_enabled = Look.at_least(Look.Quality.MEDIUM)
	k.add(bulk)
	var plate := Readable.make("plant_sign")
	plate.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), PLANT * Vector3(DOOR_X, 2.45, -0.31))
	k.add(plate)


# ---------------------------------------------------------------- equipment

func _plant(k: VenueKit) -> void:
	var ren := k.age == Age.RENOVATED
	# compressors 1 (the grumpy one) and 2; renovated swaps in the screw package
	if ren:
		_prop(k, "compressor_screw", Vector3(-3.6, 0, 4.4))
		_prop(k, "compressor_co2", Vector3(-0.3, 0, 4.5))
	else:
		_prop(k, "compressor_recip", Vector3(-3.6, 0, 4.4))
		_prop(k, "compressor_recip", Vector3(-0.3, 0, 4.4))
	_prop(k, "receiver", Vector3(-3.4, 0, 8.05))
	_prop(k, "chiller", Vector3(3.6, 0, 7.75))
	_prop(k, "glycol_pump", Vector3(5.5, 0, 3.8))
	_prop(k, "glycol_pump", Vector3(5.5, 0, 5.1))
	_prop(k, "glycol_tank", Vector3(6.75, 0, 6.0))
	_prop(k, "control_panel", Vector3(LEFT + 0.27, 0, 2.2), -90.0)
	_prop(k, "eyewash_station", Vector3(LEFT + 0.35, 0, 3.9), -90.0)
	_prop(k, "ammonia_detector", Vector3(0.6, 2.1, BACK - 0.04), 0.0, false)
	_prop(k, "ammonia_detector", Vector3(LEFT + 0.02, 2.1, 6.4), -90.0, false)
	# the header in its trench, one module per 1.04 m
	var hd := Props.Plant.HEADER_TRENCH * Props.V
	var x := TRENCH_X + 0.25 + _seg * 0.5
	while x + _seg * 0.5 <= RIGHT + 0.01:
		_prop(k, "header", Vector3(x, -hd, TRENCH.x + 0.6), 0.0, false)
		x += _seg
	# waste oil drum and a pail of fresh oil by compressor 1
	_block(k, Vector3(-5.99, 0, 5.31), Vector3(-5.41, 0.88, 5.89), Wear.NAVY if ren else Color("2c2f33"), 0.3, 0.06)
	_block(k, Vector3(-5.35, 0, 4.75), Vector3(-5.05, 0.36, 5.05), Color("2f6fb0"), 0.3, 0.04)
	if not ren:
		# the log book on its shelf beside the panel
		_block(k, Vector3(LEFT + 0.02, 1.235, 2.9), Vector3(LEFT + 0.27, 1.265, 3.5), Wear.OLD_WOOD, 0.3, 0.04)
		_block(k, Vector3(LEFT + 0.05, 1.265, 3.06), Vector3(LEFT + 0.25, 1.305, 3.34), Color("1e3b6a"), 0.3, 0.0, false)


func _plumbing(k: VenueKit) -> void:
	var y_dis := 2.9   # discharge main
	var y_suc := 2.5   # suction main
	var y_gly := 2.65  # glycol mains
	if k.age != Age.RENOVATED:
		for cx in [-3.6, -0.3]:
			# discharge: up from the stop valve at the back of each compressor
			_run(k, "refrig", Vector3(cx - 1.17, 1.3, 4.9), Vector3(cx - 1.17, y_dis, 4.9))
			# suction: down from the main, then along the floor into the strainer
			_run(k, "refrig", Vector3(cx - 1.15, 0.47, 6.0), Vector3(cx - 1.15, y_suc, 6.0), [], true)
			_run(k, "refrig", Vector3(cx - 1.15, 0.47, 4.95), Vector3(cx - 1.15, 0.47, 6.0), [], true)
	# discharge main along the room and up through the roof to the condenser
	_run(k, "refrig", Vector3(-5.0, y_dis, 4.9), Vector3(2.6, y_dis, 4.9), [2, 5])
	_run(k, "refrig", Vector3(2.6, y_dis, 4.9), Vector3(2.6, H, 4.9))
	# liquid back down from the condenser into the receiver
	_run(k, "refrig", Vector3(-4.9, 1.4, 7.8), Vector3(-4.9, H, 7.8), [1])
	# suction main from the chiller's surge drum to the compressors
	_run(k, "refrig", Vector3(3.57, 2.1, 7.75), Vector3(3.57, y_suc, 7.75), [], true)
	_run(k, "refrig", Vector3(3.57, y_suc, 6.0), Vector3(3.57, y_suc, 7.75), [], true)
	_run(k, "refrig", Vector3(-5.0, y_suc, 6.0), Vector3(3.57, y_suc, 6.0), [3], true)
	# glycol: out of the chiller head, along the back and down the right wall
	for i in 2:
		var z := 7.55 + i * 0.45
		var xr := 6.75 + i * 0.4
		_run(k, "glycol", Vector3(2.05, 1.5, z), Vector3(2.05, y_gly, z))
		_run(k, "glycol", Vector3(2.05, y_gly, z), Vector3(xr - _seg * 0.5, y_gly, z), [1] if i == 0 else [])
		_elbow(k, "glycol", Vector3(xr, y_gly, z), 0.0)
		_run(k, "glycol", Vector3(xr, y_gly, TRENCH.x + 0.4 + i * 0.5), Vector3(xr, y_gly, z - _seg * 0.5), [2])
		_run(k, "glycol", Vector3(xr, -0.4, TRENCH.x + 0.4 + i * 0.5), Vector3(xr, y_gly, TRENCH.x + 0.4 + i * 0.5))
	# pump discharges up into the supply main
	for pz in [3.8, 5.1]:
		_run(k, "glycol", Vector3(4.88, 1.1, pz - 0.16), Vector3(4.88, y_gly - 0.4, pz - 0.16), [0])
		_run(k, "glycol", Vector3(4.88, y_gly - 0.4, pz - 0.16), Vector3(6.75, y_gly - 0.4, pz - 0.16))


func _lights(k: VenueKit) -> void:
	var ren := k.age == Age.RENOVATED
	for p in [Vector3(-3.2, H - 0.3, 4.0), Vector3(1.2, H - 0.3, 5.0), Vector3(4.6, H - 0.3, 4.0)]:
		var half := Vector3(0.6, 0.02, 0.15) if ren else Vector3(0.6, 0.03, 0.06)
		k.glow(PLANT * (p - half), PLANT * (p + half), Wear.LED if ren else Color(0.85, 0.95, 1.0))
	# one shadowless light for the room (the building's light budget is tight)
	room_light(k, PLANT * Vector3(0.3, H - 0.5, 4.4), 9.0)


## Gus's door of notes (and Marg's replies, and Earl's): real paper stuck
## to the door's leaf, so they swing open with it. Every one can be taken
## down and stuck somewhere else.
const DOOR_NOTES := [
	# id, door-space x, y, tilt (degrees)
	["plant_nfpa", 0.0, 1.86, 0.0],
	["plant_ammonia", 0.0, 1.7, 0.0],
	["plant_round", -0.2, 1.43, -1.5],
	["gus_index_card", 0.21, 1.52, 2.0],
	["gus_breaker", 0.24, 1.36, -5.0],
	["gus_ticks", -0.24, 1.17, -3.0],
	["marg_reply", -0.22, 1.05, -2.0],
	["gus_oil", 0.05, 1.2, 3.0],
	["earl_strip", 0.04, 0.9, 2.0],
]


func _door_notes(k: VenueKit) -> void:
	var face := Basis(Vector3.UP, PI)  # readables face +Z; the door's outside is -Z
	for n in DOOR_NOTES:
		var r := Readable.make(n[0], not String(n[0]).begins_with("plant_"))
		_door.attach(r, Transform3D(face * Basis(Vector3.BACK, deg_to_rad(n[3])), Vector3(n[1], n[2], -0.031)))
	# Gus's binder on its hook, beside the latch
	var b := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.24, 0.31, 0.05)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("1e3b6a")
	m.roughness = 0.6
	bm.material = m
	b.mesh = bm
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_door.attach(b, Transform3D(Basis.IDENTITY, Vector3(0.3, 0.78, -0.06)))


## RINK_SIM M1: the door of notes and the binder outside, the compressors'
## oil sight glasses, the blue oil drum, the glycol thermometers and the log
## book. Jobs launch World and assets' mini games (scenes/world/jobs/).
func _spots(k: VenueKit) -> void:
	if k.age != Age.RENOVATED and _door:
		_door_notes(k)
	add_spot(k, VenueSpot.Kind.READ, "door_of_notes", PLANT * Vector3(DOOR_X - 0.2, 1.5, -0.4), "Notes on the plant room door", {"readable": "note_door_oil", "note": "door_of_notes"}, 1.6)
	add_spot(k, VenueSpot.Kind.READ, "screwdriver", PLANT * Vector3(DOOR_X - 0.45, 1.2, -0.4), "Screwdriver with a card", {"readable": "note_screwdriver"}, 1.4)
	add_spot(k, VenueSpot.Kind.READ, "gus_binder", PLANT * Vector3(DOOR_X + 0.25, 1.1, -0.4), "Gus's binder", {"readable": "gus_binder"}, 1.6)
	add_spot(k, VenueSpot.Kind.READ, "pamphlet_ammonia", PLANT * Vector3(DOOR_X + 0.6, 1.5, 0.05), "Pamphlet: That Smell", {"readable": "pamphlet_ammonia"}, 1.4)
	for i in 2:
		var cx: float = [-3.6, -0.3][i]
		add_spot(k, VenueSpot.Kind.JOB, "compressor_%d" % (i + 1), PLANT * Vector3(cx, 0.8, 3.6), "Compressor No. %d" % (i + 1),
			{"job": "compressor_oil_change", "args": {"compressor": i}, "target": "comp%d" % (i + 1), "scene": "res://scenes/world/jobs/compressor_oil_service.tscn"}, 1.7)
	add_spot(k, VenueSpot.Kind.READ, "oil_drum", PLANT * Vector3(-5.2, 0.45, 4.9), "Blue oil drum", {"note": "oil_drum"}, 1.5)
	# two dial thermometers on the glycol mains by the pumps
	for j in 2:
		var tz := 3.25 + j * 0.45
		_block(k, Vector3(4.85, 1.45, tz), Vector3(4.9, 1.6, tz + 0.15), Color("e8e8e2"), 0.1, 0.0, false)
	add_spot(k, VenueSpot.Kind.JOB, "glycol_thermometer", PLANT * Vector3(4.85, 1.5, 3.5), "Glycol thermometers",
		{"job": "plant_round", "target": "glycol", "note": "glycol_thermometer"}, 1.5)
	add_spot(k, VenueSpot.Kind.SCREEN, "log_book", PLANT * Vector3(LEFT + 0.15, 1.3, 3.2), "Plant log book", {"screen": "log_book"}, 1.5)
	# the Nordale page Gus keeps taped up by the log book
	var nordale := Readable.make("nordale_page", true)
	nordale.transform = Transform3D(PLANT.basis * Basis(Vector3.UP, PI * 0.5), PLANT * Vector3(LEFT + 0.022, 1.95, 2.2))
	k.add(nordale)
	add_spot(k, VenueSpot.Kind.READ, "nordale_manual", PLANT * Vector3(LEFT + 0.15, 1.3, 2.7), "Nordale RC-4 manual", {"readable": "nordale_manual"}, 1.3)
