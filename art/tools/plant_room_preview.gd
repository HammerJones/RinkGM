extends SceneTree
## A look at Millbrook's ice plant room (docs/world/RINK_SIM.md 3.1) laid out
## from the plant props in scripts/art/plant_props.gd: the two Nordale
## reciprocating compressors, the chiller and receiver along the back wall,
## the duty and standby glycol pumps, the expansion tank, the supply and
## return header in its floor trench, the control panel, the eyewash and the
## ammonia detector, and the pipe runs overhead. A review sketch, not the
## plant scene. Needs a renderer (not --headless); see docs/ART.md for the
## cloud recipe:
##   godot --path . --script res://art/tools/plant_room_preview.gd -- --out=plant_room.png [--age=worn|repaired|renovated]
##
## Room space: x runs across (+x is on the left as the camera looks in, as
## for props facing it), z from
## the open front (z = 0) to the back wall (z = 8.8), floor at y = 0. The
## header trench runs along the front, 0.72 m deep.

const V := Models.V
const BACK := 8.8
const LEFT := -6.4
const RIGHT := 7.4
const TRENCH := Vector2(1.0, 2.3)  # z extent of the trench
const TRENCH_X := 0.8  # the trench runs from here to the right wall

var _out := "plant_room.png"
var _age := Wear.WORN
var _frames := 0
var _world: Node3D
var _seg := 1.04
var _frost_cache := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--age="):
			_age = maxi(Wear.NAMES.find(arg.trim_prefix("--age=")), 0)
	_seg = Props.Plant.PIPE_LEN * V
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	_world = Node3D.new()
	root.add_child(_world)
	_environment()
	_room()
	_plant()
	_plumbing()
	_lights()
	_camera()


# ---------------------------------------------------------------- helpers

func _prop(id: String, pos: Vector3, yaw_deg := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Props.mesh(id, _age)
	mi.position = pos
	mi.rotation_degrees.y = yaw_deg
	_world.add_child(mi)
	return mi


func _box(size: Vector3, pos: Vector3, c: Color, emit := 0.0) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.9
	if emit > 0.0:
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = emit
	bm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.position = pos
	_world.add_child(mi)
	return mi


## A refrigerant pipe piece frosted over, for the suction lines on the old
## plant (the cold side frosts white).
func _frosted(id: String) -> ArrayMesh:
	if not _frost_cache.has(id):
		var m := Props.model(id, _age)
		if _age != Wear.RENOVATED:
			for p in m.voxels:
				if posmod(hash(p), 10) < 8:
					m.voxels[p] = Color("e8eef1")
		_frost_cache[id] = m.build_mesh()
	return _frost_cache[id]


## Lays straight pipe pieces along an axis-aligned centreline from `a` to `b`
## (metres). `valves` lists piece indexes to swap for the valve piece.
func _run(kind: String, a: Vector3, b: Vector3, valves := [], frost := false) -> void:
	var d := b - a
	var length := d.length()
	var n := maxi(ceili(length / _seg - 0.01), 1)
	var step := (length - _seg) / maxf(n - 1, 1)
	var dir := d.normalized()
	for i in n:
		var c := a + dir * (_seg * 0.5 + step * i) if n > 1 else (a + b) * 0.5
		var id := "pipe_%s_valve" % kind if i in valves else "pipe_%s" % kind
		var mi := MeshInstance3D.new()
		mi.mesh = _frosted(id) if frost else Props.mesh(id, _age)
		if absf(dir.y) > 0.5:
			mi.rotation_degrees.z = 90.0
			mi.position = c + Vector3(0.13, 0, 0)
		else:
			mi.rotation_degrees.y = 90.0 if absf(dir.z) > 0.5 else 0.0
			mi.position = c - Vector3(0, 0.13, 0)
		_world.add_child(mi)


## An elbow whose corner is at `corner` (centreline): yaw 0 joins the -X and
## -Z legs; turn it to join others.
func _elbow(kind: String, corner: Vector3, yaw_deg: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Props.mesh("pipe_%s_elbow" % kind, _age)
	mi.position = corner - Vector3(0, 0.13, 0)
	mi.rotation_degrees.y = yaw_deg
	_world.add_child(mi)


# ---------------------------------------------------------------- room

func _room() -> void:
	var ren := _age == Wear.RENOVATED
	var concrete := Color("6f6a60") if not ren else Color("7d8287")
	# floor slabs round the header trench, 0.8 m thick so its sides show
	var t0 := TRENCH.x
	var t1 := TRENCH.y
	_box(Vector3(RIGHT - LEFT, 0.8, BACK - t1), Vector3((LEFT + RIGHT) * 0.5, -0.4, (t1 + BACK) * 0.5), concrete)
	_box(Vector3(RIGHT - LEFT, 0.8, t0 + 1.5), Vector3((LEFT + RIGHT) * 0.5, -0.4, (t0 - 1.5) * 0.5), concrete)
	_box(Vector3(TRENCH_X - LEFT, 0.8, t1 - t0), Vector3((LEFT + TRENCH_X) * 0.5, -0.4, (t0 + t1) * 0.5), concrete)
	var hd := Props.Plant.HEADER_TRENCH * V
	_box(Vector3(RIGHT - TRENCH_X, 0.1, t1 - t0), Vector3((TRENCH_X + RIGHT) * 0.5, -hd - 0.05, (t0 + t1) * 0.5), concrete.darkened(0.3))
	# trench grating, a few panels pulled up and leaning
	var grate := Wear.OLD_STEEL.darkened(0.25) if not ren else Wear.STEEL
	_box(Vector3(1.0, 0.04, t1 - t0), Vector3(TRENCH_X + 0.5, 0.02, (t0 + t1) * 0.5), grate)
	# yellow safety lines round the compressors, oil stains under them
	var line := Wear.OLD_GOLD.darkened(0.2) if not ren else Color("f2c230")
	for cx in [-3.6, -0.3]:
		_box(Vector3(2.9, 0.012, 0.06), Vector3(cx, 0.006, 3.6), line)
		if not ren:
			_box(Vector3(0.7, 0.008, 0.5), Vector3(cx + 0.1, 0.004, 3.75), Color("2a241d"))
			_box(Vector3(0.35, 0.008, 0.3), Vector3(cx - 0.5, 0.004, 3.5), Color("3a3227"))
	if not ren:
		_box(Vector3(0.9, 0.008, 0.7), Vector3(5.4, 0.004, 3.4), Color("4f5a43"))  # glycol under the pump
	_wall(true)
	_wall(false)


## Painted concrete-block wall: back (along x) or left (along z).
func _wall(back: bool) -> void:
	var m := VoxelModel.new(0.2)
	var n := int((RIGHT - LEFT) / 0.2) if back else int(BACK / 0.2)
	var h := 21
	var ren := _age == Wear.RENOVATED
	var low := Wear.OLD_MINT.darkened(0.15) if not ren else Wear.NAVY
	var high := Wear.OLD_CREAM if not ren else Wear.WHITE
	for i in n:
		for y in h:
			var c := low if y < 6 else high
			if y == 6:
				c = c.darkened(0.25)
			if posmod(i + (y % 2), 2) == 0:
				c = c.darkened(0.04)
			if back:
				m.set_voxel(i, y, 0, c)
			else:
				m.set_voxel(0, y, i, c)
	Wear.fine = false  # grime without chipping the wall's top edge
	Wear.weather(m, _age, 7 if back else 9)
	Wear.fine = true
	var mi := MeshInstance3D.new()
	mi.mesh = m.build_mesh_merged(24)
	mi.position = Vector3(LEFT, 0, BACK) if back else Vector3(LEFT - 0.2, 0, 0)
	_world.add_child(mi)
	if back:
		# a sign by the door: AMMONIA MACHINERY ROOM, yellow and black
		_box(Vector3(1.0, 0.45, 0.03), Vector3(-1.4, 2.0, BACK - 0.02), Color("e8b82a"))
		_box(Vector3(0.8, 0.06, 0.02), Vector3(-1.4, 2.08, BACK - 0.04), Color("1a1a1a"))
		_box(Vector3(0.6, 0.06, 0.02), Vector3(-1.4, 1.94, BACK - 0.04), Color("1a1a1a"))


# ---------------------------------------------------------------- equipment

func _plant() -> void:
	var ren := _age == Wear.RENOVATED
	# compressors 1 (the grumpy one) and 2; renovated swaps in the screw package
	if ren:
		_prop("compressor_screw", Vector3(-3.6, 0, 4.4))
		_prop("compressor_co2", Vector3(-0.3, 0, 4.5))
	else:
		_prop("compressor_recip", Vector3(-3.6, 0, 4.4))
		_prop("compressor_recip", Vector3(-0.3, 0, 4.4))
	_prop("receiver", Vector3(-3.4, 0, 8.05))
	_prop("chiller", Vector3(3.6, 0, 7.75))
	_prop("glycol_pump", Vector3(5.5, 0, 3.8))
	_prop("glycol_pump", Vector3(5.5, 0, 5.1))
	_prop("glycol_tank", Vector3(6.75, 0, 6.0))
	_prop("control_panel", Vector3(LEFT + 0.27, 0, 2.2), -90.0)
	_prop("eyewash_station", Vector3(LEFT + 0.35, 0, 3.9), -90.0)
	_prop("ammonia_detector", Vector3(0.6, 2.1, BACK))
	_prop("ammonia_detector", Vector3(LEFT, 2.1, 6.4), -90.0)
	# the header in its trench, one module per 1.04 m
	var hd := Props.Plant.HEADER_TRENCH * V
	var x := TRENCH_X + 0.25 + _seg * 0.5
	while x + _seg * 0.5 <= RIGHT + 0.01:
		_prop("header", Vector3(x, -hd, TRENCH.x + 0.6))
		x += _seg
	# waste oil drum and a pail of fresh oil by compressor 1
	var drum := CylinderMesh.new()
	drum.top_radius = 0.29
	drum.bottom_radius = 0.29
	drum.height = 0.88
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color("2c2f33") if not ren else Wear.NAVY
	drum.material = dm
	var di := MeshInstance3D.new()
	di.mesh = drum
	di.position = Vector3(-5.7, 0.44, 5.6)
	_world.add_child(di)
	var pail := CylinderMesh.new()
	pail.top_radius = 0.15
	pail.bottom_radius = 0.13
	pail.height = 0.36
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color("2f6fb0")
	pail.material = pm
	var pi := MeshInstance3D.new()
	pi.mesh = pail
	pi.position = Vector3(-5.2, 0.18, 4.9)
	_world.add_child(pi)
	if not ren:
		# the log book on its shelf beside the panel
		_box(Vector3(0.25, 0.03, 0.6), Vector3(LEFT + 0.14, 1.25, 3.2), Wear.OLD_WOOD)
		_box(Vector3(0.2, 0.04, 0.28), Vector3(LEFT + 0.15, 1.285, 3.2), Color("1e3b6a"))


func _plumbing() -> void:
	var y_dis := 2.9   # discharge main
	var y_suc := 2.5   # suction main
	var y_gly := 2.65  # glycol mains
	for cx in [-3.6, -0.3]:
		if _age == Wear.RENOVATED:
			continue
		# discharge: up from the stop valve at the back of each compressor
		_run("refrig", Vector3(cx - 1.17, 1.3, 4.9), Vector3(cx - 1.17, y_dis, 4.9))
		# suction: down from the main, then along the floor into the strainer
		_run("refrig", Vector3(cx - 1.15, 0.47, 6.0), Vector3(cx - 1.15, y_suc, 6.0), [], true)
		_run("refrig", Vector3(cx - 1.15, 0.47, 4.95), Vector3(cx - 1.15, 0.47, 6.0), [], true)
	# discharge main along the room and up through the roof to the condenser
	_run("refrig", Vector3(-5.0, y_dis, 4.9), Vector3(2.6, y_dis, 4.9), [2, 5])
	_run("refrig", Vector3(2.6, y_dis, 4.9), Vector3(2.6, 4.2, 4.9))
	# liquid back down from the condenser into the receiver
	_run("refrig", Vector3(-4.9, 1.4, 7.8), Vector3(-4.9, 4.2, 7.8), [1])
	# suction main from the chiller's surge drum to the compressors
	_run("refrig", Vector3(3.57, 2.1, 7.75), Vector3(3.57, y_suc, 7.75), [], true)
	_run("refrig", Vector3(3.57, y_suc, 6.0), Vector3(3.57, y_suc, 7.75), [], true)
	_run("refrig", Vector3(-5.0, y_suc, 6.0), Vector3(3.57, y_suc, 6.0), [3], true)
	# glycol: out of the chiller head, along the back and down the right wall
	for i in 2:
		var z := 7.55 + i * 0.45
		var xr := 6.75 + i * 0.4
		_run("glycol", Vector3(2.05, 1.5, z), Vector3(2.05, y_gly, z))
		_run("glycol", Vector3(2.05, y_gly, z), Vector3(xr - _seg * 0.5, y_gly, z), [1] if i == 0 else [])
		_elbow("glycol", Vector3(xr, y_gly, z), 0.0)
		_run("glycol", Vector3(xr, y_gly, TRENCH.x + 0.4 + i * 0.5), Vector3(xr, y_gly, z - _seg * 0.5), [2])
		_run("glycol", Vector3(xr, -0.4, TRENCH.x + 0.4 + i * 0.5), Vector3(xr, y_gly, TRENCH.x + 0.4 + i * 0.5))
	# pump discharges up into the supply main
	for pz in [3.8, 5.1]:
		_run("glycol", Vector3(4.88, 1.1, pz - 0.16), Vector3(4.88, y_gly - 0.4, pz - 0.16), [0])
		_run("glycol", Vector3(4.88, y_gly - 0.4, pz - 0.16), Vector3(6.75, y_gly - 0.4, pz - 0.16))


func _lights() -> void:
	var ren := _age == Wear.RENOVATED
	for p in [Vector3(-3.2, 3.9, 4.0), Vector3(1.2, 3.9, 5.0), Vector3(4.6, 3.9, 4.0)]:
		if ren:
			_box(Vector3(1.2, 0.04, 0.3), p, Wear.LED, 2.5)
		else:
			_box(Vector3(1.2, 0.06, 0.12), p, Color(0.85, 0.95, 1.0), 4.0)
		var o := OmniLight3D.new()
		o.position = p - Vector3(0, 0.4, 0)
		o.light_color = Color(0.85, 0.95, 1.0) if not ren else Color(1.0, 0.98, 0.94)
		o.light_energy = 1.0
		o.omni_range = 7.0
		o.shadow_enabled = p.x < 0.0
		_world.add_child(o)
	if not ren:
		var warn := OmniLight3D.new()  # the panel's red trip lamp glows
		warn.position = Vector3(LEFT + 0.6, 1.6, 2.2)
		warn.light_color = Color(1.0, 0.4, 0.3)
		warn.light_energy = 0.4
		warn.omni_range = 1.6
		_world.add_child(warn)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1a1b1e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.95, 1.0)
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55.0, 150.0, 0.0)
	key.light_energy = 0.45
	key.shadow_enabled = true
	_world.add_child(key)


func _camera() -> void:
	var cam := Camera3D.new()
	cam.fov = 56.0
	_world.add_child(cam)
	cam.look_at_from_position(Vector3(0.3, 6.8, -3.9), Vector3(0.3, 0.6, 4.6))
	cam.current = true


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 10:
		root.get_texture().get_image().save_png(_out)
		print("plant room preview saved to ", _out)
		return true
	return false
