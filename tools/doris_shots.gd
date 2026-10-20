extends SceneTree
## Renders Doris for review: three-quarter views front and back, the cockpit
## from the seat, the side with the service hatch open. Needs a renderer
## (run under xvfb; lavapipe is fine):
##   godot --path . --script res://tools/doris_shots.gd -- --out=prefix [--age=worn|repaired|renovated]
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


func _initialize() -> void:
	var age := Wear.WORN
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--age="):
			age = maxi(VenueRoom.AGE_NAMES.find(a.trim_prefix("--age=")), 0)
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


func _place() -> void:
	var v: Array = VIEWS[_names[_i]]
	_cam.look_at_from_position(v[0], v[1], Vector3.UP)


func _process(_dt: float) -> bool:
	_frame += 1
	if _frame < 30:
		return false
	var p := "%s_%s.png" % [_out, _names[_i]]
	root.get_texture().get_image().save_png(p)
	print("doris shot: ", p)
	_i += 1
	_frame = 0
	if _i >= _names.size():
		return true
	_place()
	return false
