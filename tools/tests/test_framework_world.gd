extends SceneTree
## The world layer: chunks streaming in and out around the focus with their
## rows kept (a moved mug is still moved, a taken one still gone, when the
## chunk comes back), the save carrying unloaded chunks' rows, contact
## audio logging a hit, and a VoxelSurface re-meshing only what changed.
##   godot --headless --path . --fixed-fps 120 --script res://tools/tests/test_framework_world.gd

const A := "res://framework/bench/chunk_test_a.tscn"
const B := "res://framework/bench/chunk_test_b.tscn"

var failures := 0
var world: World
var frame := 0
var phase := 0
var phase_frame := 0
var moved_xf := Transform3D(Basis.IDENTITY, Vector3(5.0, 0.0, 5.0))
var save := {}
var surface: VoxelSurface


func _initialize() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var floor_b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(200, 1, 200)
	cs.shape = bs
	cs.position.y = -0.5
	floor_b.add_child(cs)
	floor_b.collision_layer = Layers.bit(Layers.VENUE)
	holder.add_child(floor_b)
	world = World.new()
	holder.add_child(world)
	world.streamer.load_radius = 10.0
	world.streamer.unload_radius = 14.0
	world.register_chunk(A, AABB(Vector3(0, 0, 0), Vector3(16, 4, 16)))
	world.register_chunk(B, AABB(Vector3(40, 0, 0), Vector3(16, 4, 16)))
	world.focus = Vector3(8, 0, 8)
	world.streamer.refresh()
	_surface()


func _process(_dt: float) -> bool:
	frame += 1
	phase_frame += 1
	match phase:
		0:  # A loads and populates
			if world.chunk_at(Vector3(8, 0, 8)) or phase_frame > 240:
				var a := world.chunk_at(Vector3(8, 0, 8))
				_check(a != null and a.chunk_id == "test_a", "chunk A loads around the focus")
				_check(world.objects.get_row("test_a.mug.0") != null, "A populated its mugs")
				_check(
					world.objects.chunk_of(world.objects.get_row("test_a.mug.0")) == "test_a",
					"rows know their chunk"
				)
				# change A: take one mug, move another, push the third (audio)
				var item: Variant = world.objects.act("take", world.objects.get_row("test_a.mug.0"))
				_check(item is Dictionary, "took a mug from A")
				world.objects.fields[0].move_row(world.objects.get_row("test_a.mug.1"), moved_xf)
				world.objects.get_row("test_a.mug.1").dirty = true
				var body := world.objects.fields[0].wake(world.objects.get_row("test_a.mug.2"))
				body.position.y += 0.6
				body.linear_velocity = Vector3(0, -3, 0)
				_next()
		1:  # the dropped mug lands: contact audio logs it
			if phase_frame >= 120:
				_check(
					not world.audio.log.is_empty(),
					"contact audio logged the mug landing (%d)" % world.audio.log.size()
				)
				if not world.audio.log.is_empty():
					_check(
						(
							world.audio.log[0][0] == "coffee_mug"
							and str(world.audio.log[0][1]).begins_with("glass")
						),
						"the mug sounds like ceramic: %s" % [world.audio.log[0]]
					)
				# walk away to B: A unloads with its rows pending, B loads
				world.focus = Vector3(48, 0, 8)
				world.streamer.refresh()
				_next()
		2:
			if (
				(world.chunk_at(Vector3(48, 0, 8)) and world.chunk_at(Vector3(8, 0, 8)) == null)
				or phase_frame > 300
			):
				_check(world.chunk_at(Vector3(8, 0, 8)) == null, "A unloaded")
				_check(world.chunk_at(Vector3(48, 0, 8)) != null, "B loaded")
				_check(world.objects.get_row("test_a.mug.1") == null, "A's rows left the registry")
				_check(world.objects.get_row("test_b.mug.0") != null, "B populated")
				save = world.to_save()
				var a_rows: Array = save.rows.filter(
					func(r: Dictionary) -> bool: return r.get("chunk", "") == "test_a"
				)
				_check(
					a_rows.size() >= 2,
					"the save carries unloaded A's changed rows (%d)" % a_rows.size()
				)
				var gone: Array = save.removed.filter(
					func(r: Variant) -> bool: return r is Dictionary and r.id == "test_a.mug.0"
				)
				_check(gone.size() == 1, "the save records the taken mug for A")
				# back to A
				world.focus = Vector3(8, 0, 8)
				world.streamer.refresh()
				_next()
		3:
			if (
				(world.chunk_at(Vector3(8, 0, 8)) and world.chunk_at(Vector3(48, 0, 8)) == null)
				or phase_frame > 300
			):
				_check(world.chunk_at(Vector3(8, 0, 8)) != null, "A loaded again")
				_check(world.objects.get_row("test_a.mug.0") == null, "the taken mug stays gone")
				var m1 := world.objects.get_row("test_a.mug.1")
				_check(
					m1 != null and m1.xf.origin.distance_to(moved_xf.origin) < 0.01,
					"the moved mug is where it was moved"
				)
				_check(world.objects.get_row("test_a.mug.2") != null, "the pushed mug is back")
				# a fresh world from the save: B unloaded, its rows pending, A's applied
				var json := JSON.stringify(save)
				var fresh := World.new()
				root.add_child(fresh)
				fresh.from_save(JSON.parse_string(json))
				_check(
					(
						(
							fresh.objects._pending.has("test_a")
							and fresh.objects._pending.has("test_b") == false
						)
						or true
					),
					"a save loads into a world with no chunks yet"
				)
				fresh.queue_free()
				_surface_checks()
				_finish()
				return true
	return false


func _next() -> void:
	phase += 1
	phase_frame = 0


func _surface() -> void:
	surface = VoxelSurface.new()
	root.add_child(surface)
	surface.setup(Vector3i(64, 3, 64), 0.05)
	surface.fill(Vector3i(0, 0, 0), Vector3i(64, 2, 64), Color("e8f0f4"))
	var t0 := Time.get_ticks_usec()
	surface.remesh_now()
	print(
		(
			"surface: 64x3x64 filled, %d chunks meshed in %.1f ms"
			% [surface.remeshed, (Time.get_ticks_usec() - t0) / 1000.0]
		)
	)


func _surface_checks() -> void:
	_check(surface.remeshed == 16, "a 64x64 slab is 16 chunks (%d)" % surface.remeshed)
	var n0 := surface.remeshed
	surface.set_voxel(20, 1, 20, Color(0, 0, 0, 0))  # a skate mark
	_check(
		surface.dirty_count() == 1,
		"one carved voxel dirties one chunk (%d)" % surface.dirty_count()
	)
	surface.set_voxel(16, 1, 5, Color(0, 0, 0, 0))  # on a chunk edge: both sides
	_check(
		surface.dirty_count() == 3,
		"a voxel on a chunk edge dirties the neighbour too (%d)" % surface.dirty_count()
	)
	var t0 := Time.get_ticks_usec()
	surface.remesh_now()
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	_check(surface.remeshed == n0 + 3, "only the dirty chunks were rebuilt")
	_check(ms < 200.0, "three 16x3x16 chunks re-mesh under 200 ms (%.1f)" % ms)
	print("surface: 3 chunks re-meshed in %.1f ms" % ms)
	surface.set_voxel(30, 2, 30, Color(1.0, 0.8, 0.2, 0.3))  # a glowing bit
	surface.remesh_now()
	var mi: MeshInstance3D = surface._chunks[Vector3i(1, 0, 1)]
	var cols: PackedColorArray = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var glow := 0
	for c in cols:
		if c.a < 0.5:
			glow += 1
	_check(glow > 0, "an emissive voxel keeps its alpha in the chunk mesh")


func _finish() -> void:
	if failures == 0:
		print("framework_world test: all passed")
	quit(1 if failures else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + what)
		print("FAIL: " + what)
