class_name TestVoxPipeline
extends GdUnitTestSuite
## gdUnit4 suite for the framework's voxel pipeline. Runs in the editor's
## gdUnit4 panel and headless through tools/ci.sh (addons/gdUnit4/runtest.sh).
## The older tools/tests/test_*.gd scripts cover the same ground end to end;
## this is where new unit tests go.


func test_writer_reader_round_trip() -> void:
	var m := VoxelModel.new(0.02)
	m.box(0, 0, 0, 4, 2, 3, Color("9a6b3f"))
	m.set_voxel(5, 1, 0, Color("d0202a"))
	var path := "user://gdunit_round_trip.vox"
	var w := VoxWriter.write(m, path)
	assert_bool(w.ok).is_true()
	var a := VoxReader.read(path)
	assert_object(a).is_not_null()
	assert_int(a.count()).is_equal(m.voxels.size())
	assert_that(a.size).is_equal(Vector3i(6, 2, 3))
	a.voxel_m = 0.02
	var back := a.to_model()
	for p in m.voxels:
		assert_bool(back.voxels.has(p)).override_failure_message("missing voxel %s" % p).is_true()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_mesher_ao_keeps_face_count_and_greedy_merges() -> void:
	var m := VoxelModel.new()
	m.box(0, 0, 0, 6, 3, 4, Color("8fbfa8"))
	m.jitter = 0.04
	var kit := _tris(m.build_mesh())
	var ao := _tris(VoxMesher.build(m))
	var greedy := _tris(VoxMesher.build(m, {"greedy": true}))
	assert_int(ao).is_equal(kit)
	assert_int(greedy).is_less(ao)
	assert_int(_tris(VoxMesher.build(m, {"ao": false, "greedy": true}))).is_equal(
		_tris(m.build_mesh_merged())
	)


func test_lone_voxel_has_no_occlusion() -> void:
	var m := VoxelModel.new()
	m.set_voxel(0, 0, 0, Color.WHITE)
	m.jitter = 0.0
	var cols: PackedColorArray = VoxMesher.build(m).surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	for c in cols:
		assert_bool(c.is_equal_approx(Color.WHITE)).is_true()


func test_prop_row_saves_its_transform() -> void:
	var r := PropRow.new()
	r.id = &"lobby.cup.1"
	r.prop = &"coffee_cup"
	r.xf = Transform3D(Basis(Vector3.UP, 1.0), Vector3(1, 2, 3))
	var d := r.to_dict()
	assert_str(d.id).is_equal("lobby.cup.1")
	assert_bool(PropRow.xf_from(d.xf).is_equal_approx(r.xf)).is_true()


func test_rotation_code_identity() -> void:
	assert_bool(VoxReader._rotation(4).is_equal_approx(Basis.IDENTITY)).is_true()


static func _tris(mesh: ArrayMesh) -> int:
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3
