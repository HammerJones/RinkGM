extends SceneTree
## Builds every prop in the kit at every renovation age and checks each one
## is a usable mesh with its pivot on the floor.
##   godot --headless --path . --script res://tools/tests/test_props.gd


func _initialize() -> void:
	var failures := 0
	for id in Props.ids():
		for age in 3:
			var m := Props.model(id, age)
			if m == null or m.voxels.is_empty():
				printerr("%s/%s: no voxels" % [id, Wear.NAMES[age]])
				failures += 1
				continue
			var mesh := Props.mesh(id, age)
			if mesh == null or mesh.get_surface_count() == 0:
				printerr("%s/%s: no mesh" % [id, Wear.NAMES[age]])
				failures += 1
			if Props.mesh(id, age) != mesh:
				printerr("%s/%s: mesh not cached" % [id, Wear.NAMES[age]])
				failures += 1
			var aabb := mesh.get_aabb()
			# floor props stand on y=0; the light hangs below its ceiling mount
			var expect_top: bool = id == "light"
			var edge: float = aabb.end.y if expect_top else aabb.position.y
			if absf(edge) > 0.07:
				printerr("%s/%s: pivot is %.2f m off the %s" % [id, Wear.NAMES[age], edge, "ceiling" if expect_top else "floor"])
				failures += 1
	if failures == 0:
		print("props test: all passed (%d props x 3 ages)" % Props.ids().size())
	quit(1 if failures else 0)
