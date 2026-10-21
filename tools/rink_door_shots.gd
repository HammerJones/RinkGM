extends SceneTree
## Renders the doors in the rink boards (RinkDoors) shut and open, one PNG
## per view and state. Needs a renderer (run under xvfb):
##   godot --path . --rendering-driver vulkan --script res://tools/rink_door_shots.gd -- --out=dir/prefix [--age=worn|repaired|renovated]
## Writes <prefix>_<view>_closed.png and <prefix>_<view>_open.png.

const VIEWS := {
	"bench_door": [-1.2, 1.6, -10.4, -3.05, 0.6, -13.2],
	"bench_door_inside": [-5.2, 1.65, -14.6, -3.05, 0.6, -12.9],
	"penalty_door": [-0.6, 1.7, 10.4, -2.45, 1.2, 13.1],
	"wide_rink_door": [-16.4, 1.7, 9.8, -19.0, 1.2, 13.1],
	"zamboni_door": [23.0, 2.2, 3.2, 30.5, 1.5, 0.0],
	"zamboni_door_walkway": [33.4, 1.8, -5.5, 30.6, 1.3, 0.0],
}

var _out := "rink_door"
var _names: Array = []
var _cam: Camera3D
var _venue: Venue
var _frame := 0
var _i := 0
var _open := false


func _initialize() -> void:
	var age := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--age="):
			age = VenueRoom.AGE_NAMES.find(a.trim_prefix("--age="))
	_names = VIEWS.keys()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var env := Look.make("arena")
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, -32.0, 0.0)
	sun.shadow_enabled = true
	root.add_child(sun)
	root.add_child(Rink.new())
	_venue = Venue.instantiate_for(Career.exhibition(0))
	root.add_child(_venue)
	if age >= 0:
		_venue.set_all_ages(age)
	(func(): _venue.apply_lighting(env, sun)).call_deferred()
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.near = 0.05
	_cam.far = 400.0
	root.add_child(_cam)
	_cam.current = true
	_place()


func _place() -> void:
	var p: Array = VIEWS[_names[_i]]
	_cam.look_at_from_position(Vector3(p[0], p[1], p[2]), Vector3(p[3], p[4], p[5]), Vector3.UP)


func _process(_dt: float) -> bool:
	_frame += 1
	# frames are slow under a software renderer: the doors' swing (real
	# time) is long done by the time these few have drawn
	if _frame < (12 if _i == 0 and not _open else 5):
		return false
	var path := "%s_%s_%s.png" % [_out, _names[_i], "open" if _open else "closed"]
	root.get_texture().get_image().save_png(path)
	print("rink door shot: ", path)
	_frame = 0
	_i += 1
	if _i >= _names.size():
		if _open:
			return true
		_open = true
		_i = 0
		for d in _venue.all_doors():
			if d is RinkDoor:
				d.open()
	_place()
	return false
