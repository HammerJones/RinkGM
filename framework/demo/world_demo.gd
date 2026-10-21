extends Node3D
## The world demo: five rooms in a row that stream in and out as you walk
## (watch the HUD: a room loads a few metres before its door and unloads
## when you are two rooms away), full of things you can pick up, carry,
## throw and hear land. Move something, walk two rooms on, come back: it
## is where you left it. Pocket something: it stays gone.
##
##   godot --path . res://scenes/dev/world_demo.tscn
##
## WASD walk, Shift run, mouse look. E take / drop, F throw (or shove),
## RMB inspect, Q open/use, T pocket what you carry, G drop a box of mugs
## at your feet (contact audio), F5 save, F9 load, Esc frees the mouse.
## `-- --test=world_demo` is the headless check.

const ROOMS := 5
const ROOM_X := 10.0

var world: World
var walker: FirstPerson
var interactor: Interactor
var prompt: InteractPrompt
var hud: Label
var _saved := {}
var _pocket: Array = []
var _env: WorldEnvironment
var _sun: DirectionalLight3D
var _fails := 0


func _ready() -> void:
	_lights()
	world = World.new()
	world.name = "World"
	add_child(world)
	world.streamer.load_radius = 7.0
	world.streamer.unload_radius = 13.0
	for i in ROOMS:
		world.register_chunk(
			"res://framework/demo/rooms/room_%d.tscn" % i,
			AABB(Vector3(i * ROOM_X - 5.0, 0.0, -4.0), Vector3(10.0, 3.0, 8.0))
		)
	var quality := "medium"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="):
			quality = a.trim_prefix("--quality=")
	Quality.apply(quality, {"env": _env, "sun": _sun, "viewport": get_viewport()})
	world.chunk_loaded.connect(
		func(c: WorldChunk) -> void: Quality.apply(Quality.current, {"fields": [c.field]})
	)
	if OS.get_cmdline_user_args().has("--test=world_demo"):
		world.focus = Vector3.ZERO
		_self_test.call_deferred()
		return
	walker = FirstPerson.new()
	walker.position = Vector3(0, 0.05, 2.0)
	add_child(walker)
	interactor = Interactor.new()
	interactor.eye = walker.camera
	interactor.objects = world.objects
	add_child(interactor)
	prompt = InteractPrompt.new()
	add_child(prompt)
	prompt.bind(interactor)
	hud = Label.new()
	hud.position = Vector2(16, 12)
	hud.modulate = Color(0.9, 0.95, 1.0)
	prompt.add_child(hud)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screenshot="):
			_screenshot.call_deferred(a.trim_prefix("--screenshot="))


func _process(_dt: float) -> void:
	if walker == null:
		return
	world.focus = walker.global_position
	var names: Array = []
	for c in world.loaded_chunks():
		names.append(c.chunk_id)
	names.sort()
	var live := 0
	for f in world.objects.fields:
		live += f.live_count()
	var hit := ""
	if not world.audio.log.is_empty():
		var h: Array = world.audio.log[-1]
		hit = "   last hit: %s -> %s at %.1f m/s" % [h[0], h[1], h[2]]
	hud.text = (
		"loaded: %s   rows %d   live %d   pocket %d%s\n%s"
		% [
			", ".join(names),
			world.objects.count(),
			live,
			_pocket.size(),
			hit,
			"E take/drop  F throw/shove  RMB inspect  Q open/use  T pocket  G box of mugs  F5 save  F9 load"
		]
	)


func _unhandled_input(event: InputEvent) -> void:
	if interactor == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				interactor.act("take")
			KEY_F:
				interactor.act("throw" if interactor.carrying else "push")
			KEY_Q:
				if interactor.hovered:
					for v in world.objects.verbs_of(interactor.hovered):
						if v in ["open", "close", "use", "read"]:
							interactor.act(v)
							break
			KEY_T:
				var row := interactor.carrying if interactor.carrying else interactor.hovered
				if row:
					var item: Variant = world.objects.act("take", row)
					if item is Dictionary:
						_pocket.append(item)
						prompt.show_inspect(
							"pocketed %s (%d in pocket)" % [item.prop, _pocket.size()]
						)
			KEY_G:
				_box_of_mugs()
			KEY_ESCAPE:
				Input.mouse_mode = (
					Input.MOUSE_MODE_VISIBLE
					if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
					else Input.MOUSE_MODE_CAPTURED
				)
			KEY_F5:
				_saved = world.to_save()
				prompt.show_inspect(
					"saved: %d changed rows, %d gone" % [_saved.rows.size(), _saved.removed.size()]
				)
			KEY_F9:
				if _saved.is_empty():
					prompt.show_inspect("nothing saved yet (F5)")
				else:
					world.from_save(_saved.duplicate(true))
					prompt.show_inspect("loaded the save")
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			interactor.act("inspect")
		elif (
			event.button_index == MOUSE_BUTTON_LEFT
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
		):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## A dozen mugs dropped from waist height in front of you: a pile that
## rattles down, settles and sleeps.
func _box_of_mugs() -> void:
	var chunk := world.chunk_at(walker.global_position)
	if chunk == null:
		return
	var at := walker.global_position - walker.transform.basis.z * 1.2
	for i in 12:
		var xf := Transform3D(
			Basis(Vector3.UP, i * 0.7),
			at + Vector3((i % 3) * 0.12 - 0.12, 1.0 + (i / 3) * 0.13, (i % 2) * 0.12)
		)
		var row := world.objects.spawn("coffee_mug", xf, "", chunk.field, {}, true)
		chunk.field.wake(row)


func _lights() -> void:
	_env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("101114")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.52, 0.58)
	e.ambient_light_energy = 0.6
	e.ssao_enabled = true
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.environment = e
	add_child(_env)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-50, 30, 0)
	_sun.light_energy = 0.6
	_sun.shadow_enabled = true
	add_child(_sun)


func _screenshot(path: String) -> void:
	for i in 90:
		await get_tree().process_frame
		world.focus = walker.global_position
	walker.rotation.y = -0.45  # the table ahead, the doorway to the right
	walker.camera.rotation.x = -0.15
	for i in 12:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	print("world demo: screenshot %s" % path)
	get_tree().quit()


func _self_test() -> void:
	var check := func(ok: bool, what: String) -> void:
		if not ok:
			_fails += 1
			push_error("FAIL: " + what)
			print("FAIL: " + what)
	var waited := 0
	while world.chunk_at(Vector3.ZERO) == null and waited < 4000:
		await get_tree().process_frame
		waited += 1
	var lobby := world.chunk_at(Vector3.ZERO)
	check.call(lobby != null and lobby.chunk_id == "room_0", "the lobby loads at the start")
	check.call(world.objects.get_row("room_0.coffee_mug.3") != null, "the lobby has its mugs")
	check.call(world.chunk_at(Vector3(30, 0, 0)) == null, "the office is not loaded yet")
	# walk to the last room and back; the lobby's moved mug stays moved
	var mug := world.objects.get_row("room_0.coffee_mug.3")
	lobby.field.move_row(mug, Transform3D(Basis.IDENTITY, Vector3(2.0, 0.0, 2.0)))
	mug.dirty = true
	for step in 50:
		world.focus = Vector3(step * 1.0, 0, 0)
		for i in 10:
			await get_tree().process_frame
	waited = 0
	while (
		(world.chunk_at(Vector3(40, 0, 0)) == null or world.chunk_at(Vector3.ZERO) != null)
		and waited < 4000
	):
		await get_tree().process_frame
		waited += 1
	check.call(world.chunk_at(Vector3(40, 0, 0)) != null, "the store room loaded on the walk")
	check.call(world.chunk_at(Vector3.ZERO) == null, "the lobby unloaded behind us")
	for step in 50:
		world.focus = Vector3(40.0 - step * 1.0, 0, 0)
		for i in 10:
			await get_tree().process_frame
	waited = 0
	while world.chunk_at(Vector3.ZERO) == null and waited < 4000:
		await get_tree().process_frame
		waited += 1
	mug = world.objects.get_row("room_0.coffee_mug.3")
	check.call(
		mug != null and mug.xf.origin.distance_to(Vector3(2.0, 0.0, 2.0)) < 0.01,
		"the moved mug is still moved"
	)
	print(
		(
			"world demo: %d rows over %d loaded rooms"
			% [world.objects.count(), world.loaded_chunks().size()]
		)
	)
	if _fails == 0:
		print("world_demo test: all passed")
	get_tree().quit(1 if _fails else 0)
