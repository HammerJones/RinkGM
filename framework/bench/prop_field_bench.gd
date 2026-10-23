extends SceneTree
## The PropField cost bench: wall-clock per frame with N instanced rows and
## K live bodies, one physics step a frame, no real-time pacing. Prints one
## line and quits. The budget test (tools/tests/test_framework_props.gd)
## asserts the same numbers in CI; this is for trying a change by hand.
##
##   godot --headless --path . --fixed-fps 120 --script res://framework/bench/prop_field_bench.gd -- 10000 64
##
## Measured on the 2026-10-20 build (4-core Xeon, Jolt): 10k rows and no
## live bodies, under 0.01 ms a frame; 10k rows with 64 live bodies, about
## 0.35 ms a frame.

const WARMUP := 40
const WINDOW := 120

var frame := 0
var field: PropField
var rows := 10000
var live := 64
var t0 := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	rows = int(a[0]) if a.size() > 0 else 10000
	live = int(a[1]) if a.size() > 1 else 64
	OS.low_processor_usage_mode = false
	Engine.max_fps = 0


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 2:
		_build()
	if frame == 4 and live > 0:
		for r in field.nearest(Vector3.ZERO, 60.0).slice(0, live):
			field.wake(r).position.y += 1.0
	if frame == WARMUP:
		t0 = Time.get_ticks_usec()
	if frame == WARMUP + WINDOW:
		var per := (Time.get_ticks_usec() - t0) / float(WINDOW) / 1000.0
		print(
			(
				"prop_field_bench: %d rows, %d live: %.3f ms/frame (one physics step each) %s"
				% [rows, live, per, field.stats()]
			)
		)
		quit()
		return true
	return false


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var fb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(300, 1, 300)
	cs.shape = bs
	cs.position.y = -0.5
	fb.add_child(cs)
	fb.collision_layer = 0b11
	root.add_child(fb)
	field = PropField.new()
	field.live_cap = live + 1
	field.sleep_radius = 1000.0
	root.add_child(field)
	var m := VoxelModel.new(0.065)
	m.box(0, 0, 0, 6, 4, 6, Color.WHITE)
	m.set_pivot(3, 0, 3)
	var mesh := VoxMesher.build(m, {"greedy": true})
	var boxes := m.collision_boxes()
	for i in rows:
		var xf := Transform3D(
			Basis(Vector3.UP, rng.randf() * TAU),
			Vector3(rng.randf() * 100 - 50, 0, rng.randf() * 100 - 50)
		)
		field.add(StringName("r%d" % i), &"p", mesh, boxes, xf, 0.5)
