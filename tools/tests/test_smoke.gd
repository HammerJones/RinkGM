extends SceneTree
## Example headless test: `godot --headless --path . --script res://tools/tests/test_smoke.gd`.
## Tests live in tools/tests/test_*.gd, extend SceneTree and quit(1) on failure.
## Scripts run this way have no autoloads (Tuning, InputSetup), so test pure
## logic classes here (career, stats, voxel), and leave the match to the
## autoplay game in tools/ci.sh.

func _init() -> void:
	var failures := 0
	var m := VoxelModel.new()
	if m == null:
		printerr("FAIL: VoxelModel did not instantiate")
		failures += 1
	print("smoke: %d failure(s)" % failures)
	quit(1 if failures else 0)
