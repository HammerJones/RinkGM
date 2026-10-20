extends SceneTree
## Renders an M1 mini game mid-job (scenes/world/jobs/), HUD and all, for
## review. JobAutopilot plays the scene up to the step named by --step and
## holds it there a few ticks in. Needs a renderer (not --headless); see
## docs/ART.md for the cloud recipe:
##   godot --path . --script res://art/tools/job_preview.gd -- --job=compressor_oil_service --step=fill --out=oil.png [--ticks=60] [--sloppy]
## --job is the scene name: compressor_oil_service, doris_blade or doris_plugs.

const JOBS := {
	"compressor_oil_service": "compressor_oil_change",
	"doris_blade": "blade_change",
	"doris_plugs": "doris_plugs",
}
const DT := 1.0 / 60.0

var _name := "compressor_oil_service"
var _step := ""
var _hold := 30
var _out := "job.png"
var _sloppy := false
var _target := "comp1"
var _scene: JobScene
var _pilot: JobAutopilot
var _ticks := 0
var _shot := -1
var _frames := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--job="):
			_name = arg.trim_prefix("--job=")
		elif arg.begins_with("--step="):
			_step = arg.trim_prefix("--step=")
		elif arg.begins_with("--ticks="):
			_hold = int(arg.trim_prefix("--ticks="))
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--target="):
			_target = arg.trim_prefix("--target=")
		elif arg == "--sloppy":
			_sloppy = true
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var ps := load("res://scenes/world/jobs/%s.tscn" % _name) as PackedScene
	_scene = ps.instantiate()
	_scene.begin({"job": str(JOBS.get(_name, "")), "target": _target, "room": ""})
	root.add_child(_scene)
	_scene.set_physics_process(false)
	_pilot = JobAutopilot.new(_scene, _sloppy)
	_pilot.hold_at = _step
	_pilot.hold_ticks = _hold
	_scene.input.scripted = _pilot.drive


func _process(_delta: float) -> bool:
	_frames += 1
	if _shot < 0:
		for i in 300:
			_scene.tick(DT)
			_ticks += 1
			if _scene.step_id() == _step and _pilot._in_step > _hold or _ticks > 40000 or _scene.closed:
				_shot = _frames + 12
				_scene.snap_camera()
				break
	elif _frames == _shot:
		root.get_texture().get_image().save_png(_out)
		print("job preview saved to ", _out, " at step ", _scene.step_id())
		return true
	return false
