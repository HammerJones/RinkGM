extends SceneTree
## The framework's voxel pipeline: VoxWriter -> VoxReader round trip (what
## the import plugin runs), the scene-graph rotation decode, VoxAsset ->
## VoxelModel, and VoxMesher (ambient occlusion, greedy merge, triangle
## counts against the kit's meshers).
##   godot --headless --path . --script res://tools/tests/test_framework_vox.gd

var failures := 0


func _initialize() -> void:
	_round_trip()
	_rotation()
	_default_palette()
	_mesher()
	_import_plugin_loads()
	if failures == 0:
		print("framework_vox test: all passed")
	quit(1 if failures else 0)


func _round_trip() -> void:
	var m := VoxelModel.new(0.02)
	m.box(0, 0, 0, 5, 3, 4, Color("9a6b3f"))
	m.box(1, 3, 1, 3, 2, 2, Color("d0202a"))
	m.set_voxel(6, 0, 0, Color("1d3557"))
	var path := "user://test_framework_round_trip.vox"
	var w := VoxWriter.write(m, path)
	_check(w.ok, "VoxWriter writes: %s" % w.error)
	var a := VoxReader.read(path)
	_check(a != null, "VoxReader reads the file back")
	if a == null:
		return
	_check(a.count() == m.voxels.size(), "voxel count %d == %d" % [a.count(), m.voxels.size()])
	_check(a.size == Vector3i(7, 5, 4), "size is %s (want 7x5x4)" % a.size)
	_check(
		a.used_indices().size() == 3, "three palette colours used, got %d" % a.used_indices().size()
	)
	a.voxel_m = 0.02
	var back := a.to_model()
	var same := back.voxels.size() == m.voxels.size()
	for p in m.voxels:
		if not back.voxels.has(p) or not _close(back.voxels[p], m.voxels[p]):
			same = false
			break
	_check(same, "every voxel comes back at the same place with the same colour")
	_check(is_equal_approx(back.voxel_size, 0.02), "voxel size carried (%.3f)" % back.voxel_size)
	# recentre is a no-op on a file that already sits at the origin
	var before := a.positions.duplicate()
	a.recentre()
	_check(a.positions == before, "recentre leaves a cornered model alone")
	# load_any falls back to the reader under --script
	var any := VoxAsset.load_any(path)
	_check(
		any != null and any.count() == a.count(), "VoxAsset.load_any reads without the import step"
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _rotation() -> void:
	# 4 = identity (row 0 picks x, row 1 picks y, no sign bits)
	_check(
		VoxReader._rotation(4).is_equal_approx(Basis.IDENTITY), "rotation code 4 is the identity"
	)
	# swap x and y: row 0 picks column 1, row 1 picks column 0
	var swap := VoxReader._rotation(1)
	_check(
		(swap * Vector3(1, 0, 0)).is_equal_approx(Vector3(0, 1, 0)),
		"rotation code 1 maps x to y, got %s" % (swap * Vector3(1, 0, 0))
	)
	# identity with row 0 negated (bit 4)
	var neg := VoxReader._rotation(4 | 16)
	_check(
		(neg * Vector3(1, 0, 0)).is_equal_approx(Vector3(-1, 0, 0)),
		"sign bit flips the row, got %s" % (neg * Vector3(1, 0, 0))
	)
	_check(VoxReader._translation("3 -2 10") == Vector3i(3, -2, 10), "translation parses")


func _default_palette() -> void:
	var p := VoxReader.default_palette()
	_check(p.size() == 256, "default palette has 256 slots")
	_check(p[1].is_equal_approx(Color.WHITE), "default palette slot 1 is white")
	_check(p[0].a == 0.0, "slot 0 is empty")


func _mesher() -> void:
	var m := VoxelModel.new(0.065)
	m.box(0, 0, 0, 8, 4, 6, Color("8fbfa8"))
	m.box(2, 4, 2, 4, 2, 2, Color("c8642a"))
	m.jitter = 0.04
	var plain := m.build_mesh()
	var kit_lod := m.build_mesh_merged()
	var ao := VoxMesher.build(m)
	var greedy := VoxMesher.build(m, {"greedy": true})
	var flat := VoxMesher.build(m, {"ao": false, "greedy": true})
	var t_plain := _tris(plain)
	var t_ao := _tris(ao)
	var t_greedy := _tris(greedy)
	var t_flat := _tris(flat)
	var t_kit := _tris(kit_lod)
	print(
		(
			"mesher: kit %d, kit merged %d, ao %d, ao+greedy %d, flat greedy %d triangles"
			% [t_plain, t_kit, t_ao, t_greedy, t_flat]
		)
	)
	_check(
		t_ao == t_plain, "AO mesh has the same faces as the kit mesh (%d vs %d)" % [t_ao, t_plain]
	)
	_check(t_greedy < t_ao, "greedy with AO merges faces (%d < %d)" % [t_greedy, t_ao])
	_check(
		t_flat == t_kit, "flat greedy matches the kit's merged mesher (%d vs %d)" % [t_flat, t_kit]
	)
	_check(ao.get_aabb().is_equal_approx(plain.get_aabb()), "AO mesh bounds match")
	# AO darkens tucked corners and leaves open ones alone
	var arrays := ao.surface_get_arrays(0)
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var darkest := 1.0
	var brightest := 0.0
	for c in cols:
		darkest = minf(darkest, c.get_luminance())
		brightest = maxf(brightest, c.get_luminance())
	_check(
		darkest < brightest * 0.8,
		"AO shades corners (darkest %.2f, brightest %.2f)" % [darkest, brightest]
	)
	var one := VoxelModel.new(0.065)
	one.box(0, 0, 0, 6, 6, 6, Color("8fbfa8"))
	one.jitter = 0.04
	var ao_off := VoxMesher.build(one, {"ao": false})
	var cols2: PackedColorArray = ao_off.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var spread := 0.0
	for c in cols2:
		spread = maxf(spread, absf(c.get_luminance() - cols2[0].get_luminance()))
	_check(spread < 0.2, "without AO only the speckle varies (spread %.2f)" % spread)
	# an open corner is untouched: a lone voxel has every corner at 3
	var lone := VoxelModel.new()
	lone.set_voxel(0, 0, 0, Color.WHITE)
	lone.jitter = 0.0
	var lone_cols: PackedColorArray = VoxMesher.build(lone).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var all_white := true
	for c in lone_cols:
		if not c.is_equal_approx(Color.WHITE):
			all_white = false
	_check(all_white, "a lone voxel has no occlusion")
	# collision boxes still come from the model
	_check(m.collision_boxes().size() >= 2, "collision boxes follow the shape")


func _import_plugin_loads() -> void:
	var s := load("res://addons/vox_import/vox_import_plugin.gd")
	_check(s != null, "import plugin script loads")
	var cfg := ConfigFile.new()
	_check(cfg.load("res://addons/vox_import/plugin.cfg") == OK, "plugin.cfg loads")


static func _tris(mesh: ArrayMesh) -> int:
	if mesh.get_surface_count() == 0:
		return 0
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3


static func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + what)
		print("FAIL: " + what)
