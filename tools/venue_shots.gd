extends SceneTree
## Renders eye-level views of the venue for review, one PNG per view. Needs
## a renderer (run under xvfb; lavapipe is fine):
##   godot --path . --script res://tools/venue_shots.gd -- --out=dir [--age=worn|repaired|renovated] [--tier=N] [--wings]
##     [--view=name:x,y,z,lookx,looky,lookz ...]
## With no --view it renders the stock tour of the recreation centre wing.

const TOUR := {
	"entrance_outside": [-58.0, 1.7, -37.0, -46.0, 2.6, -37.0],
	"front_desk": [-45.0, 1.65, -33.0, -36.0, 1.3, -40.0],
	"hall_east": [-31.0, 1.65, -42.0, 0.0, 1.4, -42.0],
	"hall_west": [44.0, 1.65, -42.0, 0.0, 1.4, -42.0],
	"gym": [-1.0, 1.65, -45.0, -24.0, 2.5, -54.0],
	"gym_bleachers": [-20.0, 1.65, -47.0, -14.0, 2.0, -60.0],
	"pro_shop": [-21.0, 1.65, -39.0, -29.0, 1.2, -31.0],
	"weight_room": [14.5, 1.65, -45.0, 4.0, 1.2, -55.0],
	"community_hall": [30.0, 1.65, -45.0, 20.0, 1.5, -58.0],
	"dressing_room": [9.0, 1.65, -39.0, 15.0, 1.0, -31.5],
	"washroom": [-19.5, 1.65, -39.0, -17.5, 1.0, -30.5],
	"offices": [-33.0, 1.65, -45.0, -43.0, 1.2, -50.0],
	"meeting_room": [-34.0, 1.65, -53.0, -44.0, 1.2, -57.0],
	"workshop": [34.0, 1.65, -45.0, 44.0, 1.2, -56.0],
	"boiler_room": [43.0, 1.65, -39.0, 44.5, 1.0, -31.0],
	"aerial": [-70.0, 40.0, 30.0, -10.0, 0.0, -30.0],
}

var _out := "shot"
var _views := {}
var _names: Array = []
var _cam: Camera3D
var _frame := 0
var _i := 0


func _initialize() -> void:
	var age := -1
	var tier := 0
	var wings := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--age="):
			age = VenueRoom.AGE_NAMES.find(a.trim_prefix("--age="))
		elif a.begins_with("--tier="):
			tier = a.trim_prefix("--tier=").to_int()
		elif a == "--wings":
			wings = true
		elif a.begins_with("--view="):
			var kv := a.trim_prefix("--view=").split(":")
			_views[kv[0]] = Array(kv[1].split_floats(","))
	if _views.is_empty():
		_views = TOUR
		wings = true
	_names = _views.keys()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9fb4c8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, -32.0, 0.0)
	sun.shadow_enabled = true
	root.add_child(sun)
	root.add_child(Rink.new())
	var v := Venue.instantiate_for(Career.exhibition(tier), wings)
	root.add_child(v)
	if age >= 0:
		v.set_all_ages(age)
	v.apply_lighting(env, sun)
	for d in v.all_doors():
		d.open()
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.near = 0.05
	_cam.far = 400.0
	root.add_child(_cam)
	_cam.current = true
	_place()


func _place() -> void:
	var p: Array = _views[_names[_i]]
	_cam.look_at_from_position(Vector3(p[0], p[1], p[2]), Vector3(p[3], p[4], p[5]), Vector3.UP)


func _process(_dt: float) -> bool:
	_frame += 1
	if _frame < 40:
		return false
	var path := "%s_%s.png" % [_out, _names[_i]]
	root.get_texture().get_image().save_png(path)
	print("venue shot: ", path)
	_i += 1
	_frame = 0
	if _i >= _names.size():
		return true
	_place()
	return false
