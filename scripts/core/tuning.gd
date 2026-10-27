extends Node
## Global feel settings. `blend` slides the skating and stick controls
## between pure simulation (0.0, the default) and arcade assistance (1.0):
## more turn and grip, direct thrust, a quicker blade. It never changes how
## contacts come out (shots, passes, traps, saves, hits). See README.

signal mode_changed(mode_name: String)

const MODES := [
	{"name": "SIM", "blend": 0.0},
	{"name": "HYBRID", "blend": 0.5},
	{"name": "ARCADE", "blend": 1.0},
]

var mode_index := 0  # SIM: nothing added on top of the physics
var blend := 0.0


func _ready() -> void:
	# e.g. `godot -- --mode=arcade`
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			set_mode(arg.trim_prefix("--mode=").to_upper())


func set_mode(mode_name_: String) -> void:
	for i in MODES.size():
		if MODES[i]["name"] == mode_name_:
			mode_index = i
			blend = MODES[i]["blend"]
			mode_changed.emit(mode_name_)


func cycle_mode() -> void:
	mode_index = (mode_index + 1) % MODES.size()
	blend = MODES[mode_index]["blend"]
	mode_changed.emit(mode_name())


func mode_name() -> String:
	return MODES[mode_index]["name"]
