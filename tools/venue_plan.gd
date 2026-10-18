extends SceneTree
## Draws the venue's floor plans: a straight-down orthographic view of the
## building cut at a height (everything above the cut is behind the camera),
## plus a JSON list of the rooms and doors for labelling the plan. Needs a
## renderer (not --headless):
##   godot --path . --script res://tools/venue_plan.gd -- --out=plan [--age=worn|repaired|renovated] [--cuts=2.6,8.5]
## writes plan_<cut>.png per cut and plan.json. +X is right and the bench
## side (-Z) is at the top; one image pixel is PX metres.

const PX := 0.05  # metres per pixel
const MARGIN := 2.0

var _out := "plan"
var _age := -1
var _cuts: Array[float] = [2.6, 8.5]
var _venue: Venue
var _cam: Camera3D
var _frame := 0
var _shot := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--age="):
			_age = VenueRoom.AGE_NAMES.find(a.trim_prefix("--age="))
		elif a.begins_with("--cuts="):
			_cuts.clear()
			for v in a.trim_prefix("--cuts=").split_floats(","):
				_cuts.append(v)
	var w := Venue.HALF_X * 2.0 + MARGIN * 2.0
	var h := Venue.HALF_Z * 2.0 + MARGIN * 2.0
	DisplayServer.window_set_size(Vector2i(roundi(w / PX), roundi(h / PX)))
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("15161a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.92, 1.0)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-70.0, -30.0, 0.0)
	sun.light_energy = 0.8
	world.add_child(sun)
	world.add_child(Rink.new())
	_venue = Venue.instantiate_for({})
	if _age >= 0:
		for r in _venue.get_children():
			if r is VenueRoom:
				r.age = _age
	_venue.set_attendance(0.35)
	world.add_child(_venue)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.size = h
	_cam.near = 0.05
	_cam.far = 60.0
	world.add_child(_cam)
	_cam.current = true
	_place_cam()


func _place_cam() -> void:
	_cam.look_at_from_position(Vector3(0, _cuts[_shot], 0), Vector3.ZERO, Vector3(0, 0, -1))


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 12:
		return false
	var cut := _cuts[_shot]
	var path := "%s_%s.png" % [_out, String.num(cut, 1).replace(".", "_")]
	root.get_texture().get_image().save_png(path)
	print("venue plan: cut at %.1f m saved to %s" % [cut, path])
	_shot += 1
	_frame = 0
	if _shot < _cuts.size():
		_place_cam()
		return false
	_write_json()
	return true


func _write_json() -> void:
	var rooms := []
	for r in _venue.get_children():
		if not r is VenueRoom or r.bounds.size == Vector3.ZERO:
			continue
		var b: AABB = r.bounds
		rooms.append({
			"id": r.room_id, "name": r.display_name, "age": VenueRoom.AGE_NAMES[r.age],
			"x0": b.position.x, "z0": b.position.z, "x1": b.end.x, "z1": b.end.z,
			"y0": b.position.y, "y1": b.end.y,
		})
	var doors := []
	for d in _venue.all_doors():
		var p := d.global_position
		doors.append({"label": d.label, "x": p.x, "y": p.y, "z": p.z, "w": d.width, "rot": d.global_rotation.y, "kind": VenueDoor.Kind.keys()[d.kind]})
	var data := {
		"metres_per_pixel": PX, "margin": MARGIN,
		"half_x": Venue.HALF_X, "half_z": Venue.HALF_Z,
		"rink": {"half_l": Rink.HALF_L, "half_w": Rink.HALF_W, "corner_r": Rink.CORNER_R},
		"cuts": _cuts, "rooms": rooms, "doors": doors,
	}
	var f := FileAccess.open(_out + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
	print("venue plan: rooms and doors saved to %s.json" % _out)
