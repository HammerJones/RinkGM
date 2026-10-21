extends Node3D
## The render benchmark: a room with many hero props and a camera flying a
## fixed path, measured under the real renderer. Prints frame time,
## primitives and draw calls over the path. Absolute numbers depend on the
## machine (under the virtual display's software driver they are slow and
## only comparable to themselves); the point is the same scene measured the
## same way before and after a change.
##
##   tools/render_bench.sh [--props=200] [--quality=medium]
##   godot --path . res://scenes/dev/render_bench.tscn -- --props=200
##
## `-- --test=render_bench` is the headless check that it runs (no renderer
## numbers there). Bench setup follows the objects demo so the two stay
## comparable.

const PATH_FRAMES := 240

var props := 200
var quality := "medium"
var field: PropField
var objects: WorldObjects
var cam: Camera3D
var frame := 0
var t_last := 0
var frame_usec: Array[int] = []
var prims: Array[int] = []
var draws: Array[int] = []
var _env: WorldEnvironment
var _sun: DirectionalLight3D
var _headless := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--props="):
			props = int(a.trim_prefix("--props="))
		elif a.begins_with("--quality="):
			quality = a.trim_prefix("--quality=")
		elif a == "--test=render_bench":
			_headless = true
	OS.low_processor_usage_mode = false
	Engine.max_fps = 0
	_build()
	Quality.apply(
		quality, {"env": _env, "sun": _sun, "fields": [field], "viewport": get_viewport()}
	)
	print(
		(
			"render_bench: %d props, quality %s, %s"
			% [objects.count(), quality, RenderingServer.get_video_adapter_name()]
		)
	)


func _build() -> void:
	_env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("1d1f24")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.52, 0.58)
	_env.environment = e
	add_child(_env)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-55, 35, 0)
	_sun.shadow_enabled = true
	add_child(_sun)
	var room := StaticBody3D.new()
	room.collision_layer = Layers.bit(Layers.VENUE)
	add_child(room)
	var boxes: Array = []
	for spec in [
		[Vector3(0, -0.1, 0), Vector3(24, 0.2, 24)],
		[Vector3(0, 3.1, 0), Vector3(24, 0.2, 24)],
		[Vector3(-12.1, 1.5, 0), Vector3(0.2, 3, 24)],
		[Vector3(12.1, 1.5, 0), Vector3(0.2, 3, 24)],
		[Vector3(0, 1.5, -12.1), Vector3(24, 3, 0.2)],
		[Vector3(0, 1.5, 12.1), Vector3(24, 3, 0.2)],
		[Vector3(0, 1.5, 0), Vector3(0.2, 3, 16)],
	]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = spec[1]
		mi.mesh = bm
		mi.position = spec[0]
		room.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = spec[1]
		cs.shape = bs
		cs.position = spec[0]
		room.add_child(cs)
		boxes.append(AABB(spec[0] - spec[1] / 2, spec[1]))
	Occluders.from_boxes(self, boxes)
	field = PropField.new()
	add_child(field)
	objects = WorldObjects.new()
	objects.field = field
	add_child(objects)
	var ids := ObjectCatalog.ids().filter(
		func(id: String) -> bool: return not ObjectCatalog.tags(id).has("vehicle")
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in props:
		var id: String = ids[i % ids.size()]
		var xf := Transform3D(
			Basis(Vector3.UP, rng.randf() * TAU),
			Vector3(rng.randf() * 22 - 11, 0.0, rng.randf() * 22 - 11)
		)
		objects.spawn(id, xf)
	cam = Camera3D.new()
	cam.fov = 70.0
	add_child(cam)
	cam.current = true


func _process(_dt: float) -> void:
	var now := Time.get_ticks_usec()
	if frame > 2:
		frame_usec.append(now - t_last)
		prims.append(
			int(
				RenderingServer.get_rendering_info(
					RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME
				)
			)
		)
		draws.append(
			int(
				RenderingServer.get_rendering_info(
					RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
				)
			)
		)
	t_last = now
	# a loop around the room, looking inward, past both halves
	var t := float(frame) / PATH_FRAMES * TAU
	cam.position = Vector3(sin(t) * 9.0, 1.6, cos(t) * 9.0)
	cam.look_at(Vector3(sin(t + 1.2) * 3.0, 0.8, cos(t + 1.2) * 3.0), Vector3.UP)
	field.focus = cam.position
	frame += 1
	if frame >= PATH_FRAMES + 3:
		_report()
		get_tree().quit()


func _report() -> void:
	var sum := 0
	var mx := 0
	for u in frame_usec:
		sum += u
		mx = maxi(mx, u)
	var avg := sum / 1000.0 / maxi(frame_usec.size(), 1)
	var p_sum := 0
	var d_sum := 0
	for v in prims:
		p_sum += v
	for v in draws:
		d_sum += v
	print(
		(
			"render_bench: %d frames, %.2f ms/frame avg, %.2f max, %d primitives, %d draw calls (per frame avg), %d live"
			% [
				frame_usec.size(),
				avg,
				mx / 1000.0,
				p_sum / maxi(prims.size(), 1),
				d_sum / maxi(draws.size(), 1),
				field.live_count()
			]
		)
	)
	if _headless:
		print("render_bench test: all passed")
