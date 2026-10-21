extends Node3D
## The objects demo: a small room, every catalog prop on tables and the
## floor, a first-person walker with the Interactor and the prompt. Walk
## up to anything: it lights up and names itself; E takes it into your
## hands (a live body on a spring, bumps into things), E again drops it,
## F throws or shoves, right click inspects, Q does the thing's other verb
## (open, use). Esc frees the mouse, F5 saves and reloads the rows.
##
##   godot --path . res://scenes/dev/object_demo.tscn
##
## `-- --test=objects` runs the headless check: spawn, look, take, drop,
## push, open, save and load, then prints "objects test: all passed".

const ROOM := Vector3(10.0, 3.0, 8.0)

var objects: WorldObjects
var field: PropField
var walker: FirstPerson
var interactor: Interactor
var prompt: InteractPrompt
var _saved := {}
var _fails := 0


func _ready() -> void:
	_build_room()
	field = PropField.new()
	field.name = "Props"
	add_child(field)
	objects = WorldObjects.new()
	objects.name = "Objects"
	objects.field = field
	add_child(objects)
	_place_props()
	if OS.get_cmdline_user_args().has("--test=objects"):
		_self_test.call_deferred()
		return
	walker = FirstPerson.new()
	walker.position = Vector3(0, 0.05, 2.5)
	add_child(walker)
	interactor = Interactor.new()
	interactor.eye = walker.camera
	interactor.objects = objects
	add_child(interactor)
	prompt = InteractPrompt.new()
	add_child(prompt)
	prompt.bind(interactor)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screenshot="):
			_screenshot.call_deferred(a.trim_prefix("--screenshot="))


func _unhandled_input(event: InputEvent) -> void:
	if interactor == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				interactor.act("take")
			KEY_F:
				if interactor.carrying:
					interactor.act("throw")
				else:
					interactor.act("push")
			KEY_Q:
				if interactor.hovered:
					for v in objects.verbs_of(interactor.hovered):
						if v in ["open", "close", "use", "read"]:
							interactor.act(v)
							break
			KEY_ESCAPE:
				Input.mouse_mode = (
					Input.MOUSE_MODE_VISIBLE
					if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
					else Input.MOUSE_MODE_CAPTURED
				)
			KEY_F5:
				if _saved.is_empty():
					_saved = objects.to_save()
					prompt.show_inspect("saved %d rows" % _saved.rows.size())
				else:
					objects.from_save(_saved)
					prompt.show_inspect("loaded %d rows" % _saved.rows.size())
					_saved = {}
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			interactor.act("inspect")
		elif (
			event.button_index == MOUSE_BUTTON_LEFT
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
		):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- the room ------------------------------------------------------------


func _build_room() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("1d1f24")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.52, 0.58)
	e.ambient_light_energy = 0.7
	e.ssao_enabled = true
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.7, 0)
	lamp.light_energy = 2.0
	lamp.omni_range = 9.0
	lamp.shadow_enabled = true
	add_child(lamp)
	var body := StaticBody3D.new()
	body.name = "Room"
	body.collision_layer = Layers.bit(Layers.VENUE)
	body.collision_mask = 0
	add_child(body)
	_slab(body, Vector3(0, -0.1, 0), Vector3(ROOM.x, 0.2, ROOM.z), Color("8a8676"))
	_slab(body, Vector3(0, ROOM.y + 0.1, 0), Vector3(ROOM.x, 0.2, ROOM.z), Color("d8d4c8"))
	_slab(
		body,
		Vector3(-ROOM.x / 2 - 0.1, ROOM.y / 2, 0),
		Vector3(0.2, ROOM.y, ROOM.z),
		Color("9fb8a8")
	)
	_slab(
		body,
		Vector3(ROOM.x / 2 + 0.1, ROOM.y / 2, 0),
		Vector3(0.2, ROOM.y, ROOM.z),
		Color("9fb8a8")
	)
	_slab(
		body,
		Vector3(0, ROOM.y / 2, -ROOM.z / 2 - 0.1),
		Vector3(ROOM.x, ROOM.y, 0.2),
		Color("9fb8a8")
	)
	_slab(
		body,
		Vector3(0, ROOM.y / 2, ROOM.z / 2 + 0.1),
		Vector3(ROOM.x, ROOM.y, 0.2),
		Color("9fb8a8")
	)
	# two tables and a counter
	_slab(body, Vector3(-2.5, 0.72, -1.5), Vector3(2.0, 0.06, 1.0), Color("6e4a2a"))
	_slab(body, Vector3(2.5, 0.72, -1.5), Vector3(2.0, 0.06, 1.0), Color("6e4a2a"))
	_slab(body, Vector3(0, 0.45, -3.4), Vector3(8.0, 0.9, 0.6), Color("5b3a22"))
	for tx in [-3.4, -1.6, 1.6, 3.4]:
		for tz in [-1.9, -1.1]:
			_slab(body, Vector3(tx, 0.35, tz), Vector3(0.06, 0.7, 0.06), Color("4a3424"))


func _slab(body: StaticBody3D, at: Vector3, size: Vector3, colour: Color) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = at
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.95
	mi.material_override = mat
	body.add_child(mi)


func _place_props() -> void:
	var small := 0
	var big := 0
	for id in ObjectCatalog.ids():
		var tags := ObjectCatalog.tags(id)
		var info := ObjectCatalog.info(id)
		var size: Array = info.get("size_m", [0.3, 0.3, 0.3])
		var xf: Transform3D
		if id == "wall_clock":
			xf = Transform3D(Basis(Vector3.UP, 0.0), Vector3(0, 2.0, ROOM.z / 2))
		elif id == "wall_phone_booth":
			xf = Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-ROOM.x / 2, 0.6, 1.5))
		elif tags.has("vehicle"):
			continue  # the truck does not fit a room
		elif float(size[0]) > 0.4 or float(size[2]) > 0.3:
			# big things along the counter at the back
			xf = Transform3D(Basis(Vector3.UP, 0.3 * big), Vector3(-3.2 + big * 1.1, 0.9, -3.4))
			big += 1
		else:
			# small things in a row along the two tables, 0.55 m apart
			var tx := -3.4 + small * 0.55
			if tx > -1.6 and tx < 1.6:
				tx += 3.2  # skip the gap between the tables
			xf = Transform3D(
				Basis(Vector3.UP, 0.4 * small),
				Vector3(tx, 0.75, -1.5 + (0.25 if small % 2 else -0.25))
			)
			small += 1
		objects.spawn(id, xf)
	# a few extra mugs and tapes on the floor to kick around
	for k in 6:
		objects.spawn(
			"coffee_mug", Transform3D(Basis(Vector3.UP, k), Vector3(-2 + k * 0.8, 0.0, 1.0))
		)
		objects.spawn(
			"vhs_tape", Transform3D(Basis(Vector3.UP, k * 0.7), Vector3(-2 + k * 0.8, 0.0, 0.3))
		)


## Looks at the left table from the walker's spot and saves a frame (for a
## look at the render without a display).
func _screenshot(path: String) -> void:
	walker.position = Vector3(-1.2, 0.05, 0.6)
	walker.rotation.y = 0.55
	walker.camera.rotation.x = -0.35
	for i in 12:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	print("objects demo: screenshot %s" % path)
	get_tree().quit()


# --- headless check --------------------------------------------------------


func _self_test() -> void:
	var check := func(ok: bool, what: String) -> void:
		if not ok:
			_fails += 1
			push_error("FAIL: " + what)
			print("FAIL: " + what)
	await get_tree().process_frame
	await get_tree().process_frame
	check.call(objects.count() >= 12, "props spawned (%d)" % objects.count())
	var eye := Node3D.new()
	add_child(eye)
	var mug := objects.get_row("coffee_mug.1")
	check.call(mug != null, "the first mug has an id")
	# look at it from in front
	eye.global_position = mug.xf.origin + Vector3(0, 0.3, 1.0)
	eye.look_at(mug.xf.origin + Vector3(0, 0.05, 0), Vector3.UP)
	var it := Interactor.new()
	it.eye = eye
	it.objects = objects
	add_child(it)
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame
	check.call(
		it.hovered == mug,
		"looking at the mug hovers it (got %s)" % (it.hovered.id if it.hovered else "nothing")
	)
	check.call(mug.highlight > 0.0, "the hovered mug is highlighted")
	check.call(it.prompt().begins_with("COFFEE MUG"), "prompt names it: %s" % it.prompt())
	var text: Variant = it.act("inspect")
	check.call(str(text).contains("Hot Stove"), "inspect returns the text")
	# carry: the body stays live and follows the eye
	check.call(it.act("take") == true, "take carries the mug")
	check.call(
		it.carrying == mug and mug.node != null and not mug.node.freeze,
		"carried mug is a live body"
	)
	for f in 40:
		await get_tree().physics_frame
	var hold := it._hold_point()
	check.call(
		mug.node.global_position.distance_to(hold) < 0.35,
		"the mug reached the hand (%.2f m off)" % mug.node.global_position.distance_to(hold)
	)
	eye.global_position += Vector3(0.5, 0, 0)
	for f in 40:
		await get_tree().physics_frame
	check.call(
		mug.node.global_position.distance_to(it._hold_point()) < 0.35, "the mug follows a move"
	)
	it.drop()
	check.call(it.carrying == null and mug.node != null, "dropped: still live, falling")
	for f in 180:
		await get_tree().physics_frame
	check.call(mug.node == null or mug.node.sleeping, "the dropped mug settles")
	# take into an inventory and drop it back
	var n0 := objects.count()
	var item: Variant = objects.act("take", mug)
	check.call(
		item is Dictionary and item.prop == "coffee_mug", "take into inventory returns the item"
	)
	check.call(
		objects.count() == n0 - 1 and objects.get_row("coffee_mug.1") == null,
		"the taken row is gone"
	)
	var back: Variant = objects.act(
		"drop",
		null,
		null,
		{
			"item": item,
			"xf": Transform3D(Basis.IDENTITY, Vector3(0, 1.0, 0)),
			"velocity": Vector3(0, 0, 1)
		}
	)
	check.call(
		back is PropRow and back.id == &"coffee_mug.1" and back.node != null,
		"drop spawns it back live with its id"
	)
	# push and open
	var vcr := objects.get_row("vcr.1")
	check.call(objects.act("push", vcr, eye) == true and vcr.node != null, "push wakes the VCR")
	var micro := objects.get_row("microwave.1")
	check.call(
		objects.act("open", micro) == true and objects.verbs_of(micro).has("close"),
		"open sets state and offers close"
	)
	# save and load
	var save := objects.to_save()
	check.call(save.rows.size() >= 3, "save keeps the changed rows (%d)" % save.rows.size())
	var json := JSON.stringify(save)
	var loaded: Variant = JSON.parse_string(json)
	objects.from_save(loaded)
	check.call(
		objects.get_row("coffee_mug.1") != null and objects.get_state(micro, "open") == true,
		"load restores rows and state"
	)
	print("objects demo: %d rows, %d fields" % [objects.count(), objects.fields.size()])
	if _fails == 0:
		print("objects test: all passed")
	get_tree().quit(1 if _fails else 0)
