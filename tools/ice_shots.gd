extends SceneTree
## Renders the ice for review (docs/world/ICE.md): the worn Millbrook sheet,
## the same sheet just after a driven resurface, the cockpit, and the
## measuring tools' popups. Needs a renderer (run under xvfb; lavapipe is fine):
##   godot --path . --script res://tools/ice_shots.gd -- --out=dir [--only=name,name]
## Shots: ice_before, ice_after, ice_after_wide, cockpit, caliper, survey, lidar.

var _out := "shot"
var _only: PackedStringArray = []
var _queue: Array[Callable] = []
var _frame := 0
var _wait := 0
var _name := ""
var _root: Node
var _worn: IceSlab
var _after: IceSlab


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			_only = a.trim_prefix("--only=").split(",")
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_worn = IceSlab.create_millbrook()
	_worn.surface_temp = -5.0
	_worn.wear_sessions(3.0, 20.0)
	_worn.flush()
	for n in ["ice_before", "ice_after", "ice_after_wide", "cockpit", "caliper", "survey", "lidar"]:
		if _only.is_empty() or n in _only:
			_queue.append(Callable(self, "_shot_" + n))
	_next()


func _next() -> void:
	if _root:
		_root.free()
		_root = null
	if _queue.is_empty():
		quit()
		return
	var c: Callable = _queue.pop_front()
	_root = Node3D.new()
	root.add_child(_root)
	_name = c.get_method().trim_prefix("_shot_")
	c.call()
	_wait = 12


func _process(_dt: float) -> bool:
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			var img := root.get_viewport().get_texture().get_image()
			var path := _out.path_join(_name + ".png")
			img.save_png(path)
			print("saved ", path)
			_next()
	return false


## The rink under arena light with the slab on it.
func _rink(ice: IceSlab) -> Rink:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1b1d22")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.9, 1.0)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62.0, -28.0, 0.0)
	sun.light_energy = 0.45
	sun.shadow_enabled = true
	_root.add_child(sun)
	for x in [-20.0, 0.0, 20.0]:
		for z in [-6.0, 6.0]:
			var o := OmniLight3D.new()
			o.position = Vector3(x, 9.0, z)
			o.omni_range = 22.0
			o.light_energy = 0.55
			_root.add_child(o)
	var rink := Rink.new()
	_root.add_child(rink)
	var iv := IceView.attach(rink, ice)
	if OS.get_environment("ICE_DEBUG") != "":
		iv.debug_view = OS.get_environment("ICE_DEBUG").to_int()
		if iv.material:
			iv.material.set_shader_parameter("debug_view", iv.debug_view)
	return rink


func _cam(eye: Vector3, at: Vector3, fov := 60.0) -> Camera3D:
	var c := Camera3D.new()
	c.fov = fov
	c.near = 0.03
	_root.add_child(c)
	c.look_at_from_position(eye, at, Vector3.UP)
	c.make_current()
	return c


func _shot_ice_before() -> void:
	_rink(_worn)
	_cam(Vector3(-22.0, 1.4, -3.0), Vector3(-27.5, 0.0, 0.5), 55.0)


func _after_ice() -> IceSlab:
	if _after:
		return _after
	var run := ResurfaceRun.start(_worn, ResurfacerSim.create_doris())
	var ap := ResurfaceAutopilot.new(run, ResurfaceAutopilot.NORMAL)
	# stop partway: the last strips still wet, the rest frozen, the cut edge visible
	while not ap.done and run.time_s < 470.0:
		ap.tick(1.0 / 20.0)
	run.ice.flush()
	_after = run.ice
	return _after


func _shot_ice_after() -> void:
	_rink(_after_ice())
	_cam(Vector3(-22.0, 1.4, -3.0), Vector3(-27.5, 0.0, 0.5), 55.0)


func _shot_ice_after_wide() -> void:
	_rink(_after_ice())
	_cam(Vector3(-36.0, 9.0, -16.0), Vector3(-8.0, 0.0, 2.0), 50.0)


func _shot_cockpit() -> void:
	var scene: Node = load("res://scenes/world/jobs/doris_drive.tscn").instantiate()
	_root.add_child(scene)
	scene.call("begin", {"job": "resurface", "target": "doris_drive", "preview": "cockpit", "ice": _worn})


func _shot_caliper() -> void:
	_popup("caliper")


func _shot_survey() -> void:
	_popup("survey")


func _shot_lidar() -> void:
	_popup("lidar")


func _popup(mode: String) -> void:
	var scene: Node = load("res://scenes/world/jobs/ice_measure.tscn").instantiate()
	_root.add_child(scene)
	scene.call("begin", {"job": {"caliper": "ice_depth", "survey": "ice_survey", "lidar": "ice_survey"}[mode], "target": "ice_" + mode,
		"preview": mode, "ice": _worn})
