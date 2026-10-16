extends Node
## Global feel settings. `blend` slides every physics system between pure
## simulation (0.0) and arcade assistance (1.0). See README for what it affects.

signal mode_changed(mode_name: String)

const MODES := [
	{"name": "SIM", "blend": 0.0},
	{"name": "HYBRID", "blend": 0.5},
	{"name": "ARCADE", "blend": 1.0},
]

var mode_index := 1
var blend := 0.5


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
