extends SceneTree
## Writes assets/ui/rinkos_theme.tres from RinkOS.build_theme().
## godot --headless --path . --script res://scripts/ui/build_theme.gd

const OUT := "res://assets/ui/rinkos_theme.tres"


func _init() -> void:
	var err := ResourceSaver.save(RinkOS.build_theme(), OUT)
	if err != OK:
		push_error("could not save %s (%d)" % [OUT, err])
		quit(1)
		return
	print("wrote ", OUT)
	quit(0)
