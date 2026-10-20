extends SceneTree
## Loads a scene and prints average CPU frame costs after it settles:
##   godot --headless --path . --script res://tools/perf_probe.gd -- --scene=res://scenes/venue/venue_walk.tscn [game args]

var _scene := "res://scenes/venue/venue_walk.tscn"
var _t := 0.0
var _n := 0
var _proc := 0.0
var _phys := 0.0
var _worst := 0.0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			_scene = a.trim_prefix("--scene=")
	change_scene_to_file.call_deferred(_scene)

func _process(delta: float) -> bool:
	_t += delta
	if _t < 6.0:
		return false
	if _n == 0:
		for n in root.find_children("*", "RinkPeople", true, false):
			n.profile = true
	var p := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var ph := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_proc += p
	_phys += ph
	_worst = maxf(_worst, p + ph)
	_n += 1
	if _t > 16.0:
		print("PERF scene=%s process=%.2fms physics=%.2fms worst=%.2fms nodes=%d objects=%d" % [_scene.get_file(), _proc / _n, _phys / _n, _worst, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT)])
		for n in root.find_children("*", "RinkPeople", true, false):
			var secs: Dictionary = n.stats.get("sections", {})
			var out := []
			for k in secs:
				out.append("%s=%.2fms" % [k, secs[k] / 1000.0 / _n])
			print("PEOPLE agents=%d %s" % [n.agents.size(), " ".join(out)])
		quit()
	return false
