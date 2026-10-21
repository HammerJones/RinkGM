extends Node3D
## The ice demo: a sheet of ice as columns (IceSheet), drawn by the ice
## shader with its four surface states. Z cycles the whole sheet through
## snowed up, dry cut, flooded and fresh frozen. LMB pours water where you
## look and you watch it set from the edges in under the slab and air
## temperatures on the readout; T speeds the clock up. RMB chips a gouge.
## R sends the resurfacer over the sheet. Mugs on the ice to kick and
## carry. Footsteps leave the ice alone.
##
##   godot --path . res://scenes/dev/ice_demo.tscn
##
## `-- --test=ice_demo` is the headless check.

const RINK := Vector2(24.0, 14.0)  # metres
const CELL := 0.025
const STATES := [
	["SNOWED UP", 1.0, 0.0, 0.0, 0.0],
	["DRY CUT", 0.0, 0.8, 0.0, 0.0],
	["FLOOD", 0.0, 0.8, 1.2, 0.0],
	["DRY, FRESH, FROZEN", 0.0, 0.0, 1.2, 1.0],
]
const SCALES := [1.0, 10.0, 60.0]
const RED := Color("c8322e")
const BLUE := Color("2a4fb0")

var ice: IceSheet
var field: PropField
var objects: WorldObjects
var walker: FirstPerson
var interactor: Interactor
var hud: WalkHud
var state := 1
var scale_i := 0
var slab_c := -5.0
var air_base := 8.0
var air_c := 8.0
var sim_t := 0.0
var _env: WorldEnvironment
var _sun: DirectionalLight3D
var _zam := -1.0
var _fails := 0


func _ready() -> void:
	_lights()
	ice = IceSheet.new()
	ice.name = "Ice"
	ice.position = Vector3(-RINK.x / 2, 0.0, -RINK.y / 2)
	add_child(ice)
	ice.setup(RINK, CELL)
	ice.set_markings(_markings())
	_set_state(state)
	ice.flush()
	# a floor under the ice for the walker and the props; boards around
	var shell := StaticBody3D.new()
	shell.collision_layer = Layers.bit(Layers.VENUE)
	shell.collision_mask = 0
	add_child(shell)
	_box(shell, Vector3(0, -0.1, 0), Vector3(RINK.x, 0.2, RINK.y), Color.WHITE, false)
	for s in [
		[Vector3(0, 0.6, -RINK.y / 2 - 0.1), Vector3(RINK.x + 0.4, 1.2, 0.2)],
		[Vector3(0, 0.6, RINK.y / 2 + 0.1), Vector3(RINK.x + 0.4, 1.2, 0.2)],
		[Vector3(-RINK.x / 2 - 0.1, 0.6, 0), Vector3(0.2, 1.2, RINK.y)],
		[Vector3(RINK.x / 2 + 0.1, 0.6, 0), Vector3(0.2, 1.2, RINK.y)],
	]:
		_box(shell, s[0], s[1], Color("f2f0ea"), true)
	for s in [
		[Vector3(0, 0.1, -RINK.y / 2 - 0.1), Vector3(RINK.x + 0.4, 0.2, 0.21)],
		[Vector3(0, 0.1, RINK.y / 2 + 0.1), Vector3(RINK.x + 0.4, 0.2, 0.21)],
	]:
		_box(shell, s[0], s[1], RED, true, false)
	field = PropField.new()
	field.name = "Props"
	add_child(field)
	objects = WorldObjects.new()
	objects.field = field
	add_child(objects)
	var audio := ContactAudio.new()
	add_child(audio)
	audio.listen_objects(objects)
	for i in 8:
		objects.spawn(
			"coffee_mug",
			Transform3D(
				Basis(Vector3.UP, i * 0.8), Vector3(-3.0 + i * 0.9, 0.0, 2.0 + (i % 2) * 0.6)
			)
		)
	var quality := "medium"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="):
			quality = a.trim_prefix("--quality=")
	Quality.apply(
		quality, {"env": _env, "sun": _sun, "fields": [field], "viewport": get_viewport()}
	)
	if OS.get_cmdline_user_args().has("--test=ice_demo"):
		_self_test.call_deferred()
		return
	walker = FirstPerson.new()
	walker.position = Vector3(-8.0, 0.05, 0.0)
	add_child(walker)
	interactor = Interactor.new()
	interactor.eye = walker.camera
	interactor.objects = objects
	add_child(interactor)
	hud = WalkHud.new()
	add_child(hud)
	hud.bind(interactor)
	hud.legend("[Z] NEXT STATE   [LMB] POUR WATER   [RMB] CHIP   [R] RESURFACER   [T] CLOCK SPEED")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screenshot="):
			_screenshot.call_deferred(a.trim_prefix("--screenshot="))


func _process(dt: float) -> void:
	var sdt: float = dt * SCALES[scale_i]
	sim_t += sdt
	# the building's air drifts over the day; the slab holds its setpoint
	air_c = air_base + 3.0 * sin(sim_t / 900.0)
	ice.thermal(sdt, slab_c, air_c)
	if _zam >= 0.0:
		_zamboni_step(sdt)
	if walker:
		field.focus = walker.global_position
	if hud:
		(
			hud
			. readout(
				(
					"STATE %s   SLAB %.1f C   AIR %.1f C   CLOCK x%d   T+%s   WET %d CELLS   DIRTY %d / %d CHUNKS"
					% [
						STATES[state][0],
						slab_c,
						air_c,
						int(SCALES[scale_i]),
						_clock(sim_t),
						ice.wet_cells,
						ice.dirty_count(),
						ice.chunk_count()
					]
				)
			)
		)


func _set_state(k: int) -> void:
	state = k % STATES.size()
	var s: Array = STATES[state]
	ice.fill_state(s[1], s[2], s[3], s[4], 0.08 if s[2] > 0.0 else 0.0)


## A 1.2 mm puddle 60 cm across where you look.
func _pour() -> void:
	var at: Variant = _aim()
	if at == null:
		return
	ice.pour(_local(at), 0.6, 1.2)
	if WorldSound.wanted():
		WorldSound.play(self, "ball_bounce_2", at, -14.0, 0.7)


## A chip: a short deep stroke with snow thrown aside.
func _chip() -> void:
	var at: Variant = _aim()
	if at == null:
		return
	var p := _local(at)
	var dir := Vector2.from_angle(walker.rotation.y + PI / 2)
	ice.stroke(p - dir * 0.15, p + dir * 0.15, 0.04, 0.9, 2.0, 0.4)
	if WorldSound.wanted():
		WorldSound.play(self, "blade_skip", at, -6.0, 0.9)


## The resurfacer: a bar that sweeps the sheet from west to east over 60 s
## of sim time, leaving a fresh cut and a wet film behind it.
func _zamboni_step(sdt: float) -> void:
	var x0 := _zam
	_zam += sdt * (RINK.x / 60.0)
	ice.resurface(x0, minf(_zam, RINK.x), 0.0, RINK.y, 0.8)
	if _zam >= RINK.x:
		_zam = -1.0


func _local(p: Vector3) -> Vector2:
	var l := p - ice.global_position
	return Vector2(l.x, l.z)


## Where the view line meets the ice plane, or null when it does not.
func _aim() -> Variant:
	var cam := walker.camera
	var o := cam.global_position
	var dir := -cam.global_transform.basis.z
	if dir.y >= -0.01:
		return null
	var t := -o.y / dir.y
	if t > 30.0:
		return null
	return o + dir * t


## The Interactor takes LMB and RMB when something is looked at or held;
## on bare ice they pour and chip.
func _unhandled_input(event: InputEvent) -> void:
	if walker == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Z:
				_set_state(state + 1)
				hud.toast("STATE: %s" % STATES[state][0])
			KEY_R:
				if _zam < 0.0:
					_zam = 0.0
					hud.toast("RESURFACER OUT")
			KEY_T:
				scale_i = (scale_i + 1) % SCALES.size()
				hud.toast("CLOCK x%d" % int(SCALES[scale_i]))
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_pour()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_chip()


# --- dressing --------------------------------------------------------------


## Centre red line, two blue lines, goal lines, as a texture under the ice.
func _markings() -> Texture2D:
	var img := Image.create(960, 560, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var px_m := 960.0 / RINK.x
	for l in [
		[RINK.x / 2, 0.15, RED],
		[RINK.x / 4, 0.15, BLUE],
		[RINK.x * 3 / 4, 0.15, BLUE],
		[1.5, 0.05, RED],
		[RINK.x - 1.5, 0.05, RED]
	]:
		var x0 := int((l[0] - l[1]) * px_m)
		var x1 := int((l[0] + l[1]) * px_m)
		img.fill_rect(Rect2i(x0, 0, maxi(x1 - x0, 1), 560), l[2])
	return ImageTexture.create_from_image(img)


func _box(
	body: StaticBody3D, at: Vector3, size: Vector3, colour: Color, draw: bool, collide := true
) -> void:
	if collide:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = at
		body.add_child(cs)
	if not draw:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.9
	mi.material_override = mat
	body.add_child(mi)


## Arena-style lamps: a row of warm spots with the shadow bias raised (a
## flat glossy sheet shows shadow acne as dark bands otherwise) and a dim sun.
func _lights() -> void:
	_env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("0b0d12")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.42, 0.45, 0.52)
	e.ambient_light_energy = 0.22
	e.ssao_enabled = true
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 0.95
	e.tonemap_white = 5.0
	_env.environment = e
	add_child(_env)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-62, 20, 0)
	_sun.light_energy = 0.1
	_sun.shadow_enabled = true
	_sun.shadow_bias = 0.1
	_sun.shadow_normal_bias = 3.0
	add_child(_sun)
	for x in [-8.0, 0.0, 8.0]:
		for z in [-4.0, 4.0]:
			var l := SpotLight3D.new()
			l.position = Vector3(x, 7.0, z)
			l.look_at_from_position(l.position, Vector3(x, 0, z + 0.3), Vector3.UP)
			l.light_color = Color("fff1dc")
			l.light_energy = 0.9
			l.spot_range = 16.0
			l.spot_angle = 48.0
			l.shadow_enabled = true
			l.shadow_bias = 0.2
			l.shadow_normal_bias = 3.0
			add_child(l)


static func _clock(t: float) -> String:
	return "%02d:%02d" % [int(t) / 60, int(t) % 60]


func _screenshot(path: String) -> void:
	walker.rotation.y = PI / 2
	walker.camera.rotation.x = -0.4
	for i in 8:
		await get_tree().process_frame
	_pour()
	walker.rotation.y = PI / 2 + 0.5
	for i in 8:
		await get_tree().process_frame
	_chip()
	walker.rotation.y = PI / 2 + 0.2
	walker.camera.rotation.x = -0.35
	ice.flush()
	for i in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	print("ice demo: screenshot %s" % path)
	get_tree().quit()


func _self_test() -> void:
	var check := func(ok: bool, what: String) -> void:
		if not ok:
			_fails += 1
			push_error("FAIL: " + what)
			print("FAIL: " + what)
	await get_tree().process_frame
	check.call(ice.chunk_count() == 15 * 9, "the sheet is %d chunks (want 135)" % ice.chunk_count())
	check.call(ice.dirty_count() == 0, "nothing dirty after the first flush")
	# the four states
	for k in STATES.size():
		_set_state(k)
		var s: Array = STATES[k]
		var i := ice.index(100, 100)
		check.call(
			is_equal_approx(ice.cut[i], s[2]) and is_equal_approx(ice.water[i], s[3]),
			"state %s fills the sheet" % s[0]
		)
	_set_state(1)
	ice.flush()
	# a puddle sets from the edges in
	ice.pour(Vector2(6.0, 7.0), 0.6, 1.2)
	var c := ice.cell_at(Vector2(6.0, 7.0))
	var mid := ice.index(c.x, c.y)
	check.call(ice.water[mid] > 1.0 and ice.frozen[mid] == 0.0, "the pour is liquid in the middle")
	check.call(
		ice.dirty_count() >= 1 and ice.dirty_count() <= 4,
		"a pour dirties its chunks (%d)" % ice.dirty_count()
	)
	await get_tree().process_frame
	await get_tree().process_frame
	check.call(ice.dirty_count() == 0, "the budget re-meshes them within a frame or two")
	var edge := ice.index(c.x + 10, c.y)
	for minute in 4:
		ice.thermal(60.0, -5.0, 8.0)
	check.call(
		ice.frozen[edge] > ice.frozen[mid],
		(
			"the shallow edge sets before the deep middle (%.2f vs %.2f)"
			% [ice.frozen[edge], ice.frozen[mid]]
		)
	)
	for minute in 16:
		ice.thermal(60.0, -5.0, 8.0)
	check.call(
		ice.frozen[mid] >= 1.0, "1.2 mm at -5 C sets in under 20 minutes (%.2f)" % ice.frozen[mid]
	)
	ice.thermal(1.0, -5.0, 8.0)
	check.call(ice.wet_cells == 0, "no wet cells left (%d)" % ice.wet_cells)
	# a chip gouges; the resurfacer wipes it and leaves a film
	ice.stroke(Vector2(3.0, 3.0), Vector2(3.3, 3.0), 0.04, 0.9, 2.0, 0.4)
	var g := ice.index(ice.cell_at(Vector2(3.15, 3.0)).x, ice.cell_at(Vector2(3.15, 3.0)).y)
	check.call(ice.gouge[g] > 1.0, "a chip gouges (%.2f mm)" % ice.gouge[g])
	ice.resurface(0.0, RINK.x, 0.0, RINK.y, 0.8)
	check.call(
		ice.gouge[g] == 0.0 and is_equal_approx(ice.water[g], 0.8),
		"the resurfacer wipes it and leaves a film"
	)
	ice.flush()
	check.call(ice.remeshed > 135, "chunks re-meshed (%d)" % ice.remeshed)
	check.call(objects.count() == 8, "mugs on the ice")
	print("ice demo: %d chunks, %d re-meshes" % [ice.chunk_count(), ice.remeshed])
	if _fails == 0:
		print("ice_demo test: all passed")
	get_tree().quit(1 if _fails else 0)
