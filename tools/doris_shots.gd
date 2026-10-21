extends SceneTree
## Renders Doris for review: three-quarter views front and back, the cockpit
## from the seat, the side with the service hatch open. Needs a renderer
## (run under xvfb; lavapipe is fine):
##   godot --path . --script res://tools/doris_shots.gd -- --out=prefix [--age=worn|repaired|renovated] [--bay]
## --bay renders the hatch flow in the venue's resurfacer bay instead: the
## walk-up to Doris's hatch, then the plug change playing there in place.
## --job=doris_oil_change|doris_carb plays that hatch job instead, and
## --steps=a,b,c renders it at those step ids (default: its second step).
## Without scripts/art/doris_model.gd it renders the old Props "resurfacer".

const VIEWS := {
	"front_left": [Vector3(-3.6, 2.4, -4.2), Vector3(0, 0.9, -0.2)],
	"rear_right": [Vector3(3.4, 2.6, 4.4), Vector3(0, 0.9, 0.6)],
	"cockpit": [Vector3(-0.5, 1.85, 1.25), Vector3(0.05, 1.0, 0.2)],
	"hatch": [Vector3(2.6, 1.3, 1.6), Vector3(0.6, 0.75, 0.85)],
	"top": [Vector3(0.0, 6.5, 0.6), Vector3(0, 0, 0.0)],
}

var _out := "doris"
var _names: Array = []
var _cam: Camera3D
var _frame := 0
var _i := 0
var _doris: Node3D
var _bay := false
var _venue: Node3D
var _job: Node3D
var _walk_cam: Camera3D
const HATCH_SCENES := {
	"doris_plugs": "res://scenes/world/jobs/doris_plugs.tscn",
	"doris_oil_change": "res://scenes/world/jobs/doris_oil.tscn",
	"doris_carb": "res://scenes/world/jobs/doris_carb.tscn",
}
var _job_id := "doris_plugs"
var _steps: PackedStringArray = []


func _initialize() -> void:
	var age := Wear.WORN
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--age="):
			age = maxi(VenueRoom.AGE_NAMES.find(a.trim_prefix("--age=")), 0)
		elif a == "--bay":
			_bay = true
		elif a.begins_with("--job="):
			_job_id = a.trim_prefix("--job=")
		elif a.begins_with("--steps="):
			_steps = a.trim_prefix("--steps=").split(",")
	if _bay:
		_init_bay()
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var env := Look.make("studio")
	env.background_color = Color("2a2d33")
	env.ambient_light_color = Color(0.92, 0.95, 1.0)
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.shadow_enabled = true
	sun.light_energy = 1.1
	root.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0.0, 2.6, 1.0)
	fill.omni_range = 4.0
	fill.light_energy = 0.6
	root.add_child(fill)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(14, 14)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("6f6c66")
	floor_mi.material_override = fm
	root.add_child(floor_mi)
	var path := "res://scripts/art/doris_model.gd"
	if ResourceLoader.exists(path):
		_doris = load(path).new(age)
		root.add_child(_doris)
		_doris.set("hatch_open", 1.0)
		_doris.set("hatch_want", true)
		_doris.set("cond_pos", 1.0)
		_doris.set("towel_down", true)
		_doris.call("apply")
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = Props.mesh("resurfacer", age)
		root.add_child(mi)
	_names = VIEWS.keys()
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.near = 0.02
	root.add_child(_cam)
	_cam.current = true
	_place()


func _init_bay() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var env := Look.make("arena")
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, -32.0, 0.0)
	root.add_child(sun)
	root.add_child(Rink.new())
	_venue = Venue.instantiate_for(Career.exhibition(0), false)
	root.add_child(_venue)
	(func() -> void: _venue.call("apply_lighting", env, sun)).call_deferred()
	_walk_cam = Camera3D.new()
	_walk_cam.fov = 70.0
	_walk_cam.near = 0.05
	root.add_child(_walk_cam)
	_walk_cam.current = true
	_names = ["bay_walkup", "bay_hatch_job", "bay_hatch_well"]
	if _job_id != "doris_plugs" or not _steps.is_empty():
		_names = ["bay_walkup", "bay_%s" % _job_id]
		for st in _steps:
			_names.append("bay_%s_%s" % [_job_id, st])


func _bay_step() -> void:
	match _i:
		0:
			var d := _bay_doris()
			var stand := d.global_transform * DorisModel.hatch_stand()
			_walk_cam.look_at_from_position(stand + Vector3(0.6, 1.65, -1.2), d.global_transform * Vector3(0.9, 0.8, 0.85), Vector3.UP)
		1:
			var d2 := _bay_doris()
			_job = (load(HATCH_SCENES[_job_id]) as PackedScene).instantiate()
			root.add_child(_job)
			_job.set_physics_process(false)
			_job.call("begin", {"sim": null, "job": _job_id, "target": _job_id, "room": "zamboni_bay",
				"place": d2.global_transform * DorisModel.hatch_frame(), "host": d2, "eye": _walk_cam.global_transform})
			_job.get("input").set("scripted", func(_f: JobInput.Frame, _dt: float, _c: int) -> void: pass)
		_:
			if _steps.is_empty():
				_job.call("advance")
				return
			# play it with the autopilot up to the step, then hold there
			var pilot := JobAutopilot.new(_job as JobScene, false)
			pilot.hold_at = _steps[_i - 2]
			pilot.hold_ticks = 3
			_job.get("input").set("scripted", pilot.drive)
			for k in 4000:
				if str(_job.call("step_id")) == pilot.hold_at:
					break
				_job.call("tick", 1.0 / 30.0)
			for k in 40:
				_job.call("tick", 1.0 / 30.0)


func _bay_doris() -> DorisModel:
	for n in root.get_tree().get_nodes_in_group("doris_model"):
		return n as DorisModel
	return null


func _place() -> void:
	var v: Array = VIEWS[_names[_i]]
	_cam.look_at_from_position(v[0], v[1], Vector3.UP)


func _process(dt: float) -> bool:
	if _bay:
		if _frame == 0:
			_bay_step()
		if _job:
			_job.call("tick", dt)
	_frame += 1
	if _frame < (60 if _bay else 30):
		return false
	var p := "%s_%s.png" % [_out, _names[_i]]
	root.get_texture().get_image().save_png(p)
	print("doris shot: ", p)
	_i += 1
	_frame = 0
	if _i >= _names.size():
		return true
	if not _bay:
		_place()
	return false
