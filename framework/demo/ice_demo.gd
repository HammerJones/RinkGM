extends Node3D
## The ice demo: a sheet of ice that is voxels, re-meshed only where it
## changes. Walk on it and your boots carve a trail; left click throws a
## snowball (a splat of snow on the ice), right click chips a crater, Z
## sends the resurfacer across (a bar that wipes the sheet line by line
## over a few seconds, re-meshing within the frame budget), R resurfaces
## at once. The lines are painted voxels, the goal light is an emissive
## one. Mugs on the ice to kick and carry, so the two layers meet.
##
##   godot --path . res://scenes/dev/ice_demo.tscn
##
## The HUD shows dirty chunks, chunks re-meshed this frame and the cost.
## `-- --test=ice_demo` is the headless check.

const RINK := Vector2(24.0, 14.0)  # metres
const VOXEL := 0.05
const LAYERS := 4  # two under layers, the top ice layer, and air above for snow
const TOP := 2  # the ice layer you walk on; carving it shows the one below
const ICE := Color("eef4f8")
const UNDER := Color("5f8fb8")
const SNOW := Color("ffffff")
const RED := Color("c8322e")
const BLUE := Color("2a4fb0")

var ice: VoxelSurface
var field: PropField
var objects: WorldObjects
var walker: FirstPerson
var interactor: Interactor
var prompt: InteractPrompt
var hud: Label
var _env: WorldEnvironment
var _sun: DirectionalLight3D
var _nx := 0
var _nz := 0
var _top := 0.0
var _last_foot := Vector3.ZERO
var _zam := -1.0  # x of the resurfacer bar, or -1
var _remesh_ms := 0.0
var _remeshed_last := 0
var _fails := 0


func _ready() -> void:
	_lights()
	_nx = int(RINK.x / VOXEL)
	_nz = int(RINK.y / VOXEL)
	_top = (TOP + 1) * VOXEL
	ice = VoxelSurface.new()
	ice.name = "Ice"
	ice.position = Vector3(-RINK.x / 2, 0.0, -RINK.y / 2)
	ice.budget_ms = 3.0
	add_child(ice)
	ice.setup(Vector3i(_nx, LAYERS, _nz), VOXEL)
	_resurface()
	_paint_lines()
	ice.remesh_now()
	# a floor under the ice for the walker and the props; boards around
	var shell := StaticBody3D.new()
	shell.collision_layer = Layers.bit(Layers.VENUE)
	shell.collision_mask = 0
	add_child(shell)
	_box(shell, Vector3(0, _top - 0.1, 0), Vector3(RINK.x, 0.2, RINK.y), Color("eef4f8"), false)
	for s in [
		[Vector3(0, 0.6, -RINK.y / 2 - 0.1), Vector3(RINK.x + 0.4, 1.2, 0.2)],
		[Vector3(0, 0.6, RINK.y / 2 + 0.1), Vector3(RINK.x + 0.4, 1.2, 0.2)],
		[Vector3(-RINK.x / 2 - 0.1, 0.6, 0), Vector3(0.2, 1.2, RINK.y)],
		[Vector3(RINK.x / 2 + 0.1, 0.6, 0), Vector3(0.2, 1.2, RINK.y)],
	]:
		_box(shell, s[0], s[1], Color("f2f0ea"), true)
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
				Basis(Vector3.UP, i * 0.8), Vector3(-3.0 + i * 0.9, _top, 2.0 + (i % 2) * 0.6)
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
	walker.position = Vector3(-8.0, _top + 0.05, 0.0)
	add_child(walker)
	_last_foot = walker.position
	interactor = Interactor.new()
	interactor.eye = walker.camera
	interactor.objects = objects
	add_child(interactor)
	prompt = InteractPrompt.new()
	add_child(prompt)
	prompt.bind(interactor)
	hud = Label.new()
	hud.position = Vector2(16, 12)
	hud.modulate = Color(0.9, 0.95, 1.0)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.add_child(hud)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screenshot="):
			_screenshot.call_deferred(a.trim_prefix("--screenshot="))


func _process(dt: float) -> void:
	var before := ice.remeshed
	var t0 := Time.get_ticks_usec()
	if _zam >= 0.0:
		_zamboni_step(dt)
	if walker:
		field.focus = walker.global_position
		_tracks()
	# the surface re-meshes in its own _process; measure what this frame cost it
	_remeshed_last = ice.remeshed - before
	_remesh_ms = (Time.get_ticks_usec() - t0) / 1000.0
	if hud:
		hud.text = (
			"ice %dx%d voxels in %d chunks   dirty %d   re-meshed this frame %d\n%s"
			% [
				_nx,
				_nz,
				ice._chunks.size(),
				ice.dirty_count(),
				_remeshed_last,
				"walk to carve   LMB snowball   RMB chip   Z resurfacer   R resurface now   E/F mugs"
			]
		)


## Two boot trails under the walker, two voxels wide, every 12 cm of travel.
func _tracks() -> void:
	var p := walker.global_position
	if p.distance_to(_last_foot) < 0.12:
		return
	_last_foot = p
	var side := walker.transform.basis.x * 0.14
	for foot in [p - side, p + side]:
		var v := _voxel_at(foot)
		for dx in 2:
			for dz in 2:
				_carve(v.x + dx, v.z + dz, 0)


## A snowball: a 10 cm splat of snow raised on the surface where you aim.
func _snowball() -> void:
	var at: Variant = _aim()
	if at == null:
		return
	var v := _voxel_at(at)
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			if dx * dx + dz * dz <= 4:
				ice.set_voxel(v.x + dx, TOP + 1, v.z + dz, SNOW)
	if WorldSound.wanted():
		WorldSound.play(self, "ball_bounce_2", at, -10.0, 1.4)


## A crater: the top layer gone in a 30 cm disc, the one below chipped in the middle.
func _chip() -> void:
	var at: Variant = _aim()
	if at == null:
		return
	var v := _voxel_at(at)
	for dx in range(-6, 7):
		for dz in range(-6, 7):
			var d := dx * dx + dz * dz
			if d <= 36:
				_carve(v.x + dx, v.z + dz, 1 if d <= 6 else 0)
	if WorldSound.wanted():
		WorldSound.play(self, "blade_skip", at, -6.0, 0.9)


## Carves at (x, z): `deep` 0 takes the top layer, 1 the one below as well.
func _carve(x: int, z: int, deep: int) -> void:
	ice.set_voxel(x, TOP + 1, z, Color(0, 0, 0, 0))  # any snow goes too
	ice.set_voxel(x, TOP, z, Color(0, 0, 0, 0))
	if deep > 0:
		ice.set_voxel(x, TOP - 1, z, Color(0, 0, 0, 0))


## The resurfacer: a bar that wipes the sheet from west to east over
## 6 seconds, filling 1.5 m of it a frame at most, the mesher keeping up
## within its budget.
func _zamboni_step(dt: float) -> void:
	var x0 := int(_zam / VOXEL)
	_zam += dt * (RINK.x / 6.0)
	var x1 := mini(int(_zam / VOXEL), _nx)
	if x1 > x0:
		ice.fill(Vector3i(x0, 0, 0), Vector3i(x1, TOP, _nz), UNDER)
		ice.fill(Vector3i(x0, TOP, 0), Vector3i(x1, TOP + 1, _nz), ICE)
		ice.fill(Vector3i(x0, TOP + 1, 0), Vector3i(x1, LAYERS, _nz), Color(0, 0, 0, 0))
		_paint_lines(x0, x1)
	if _zam >= RINK.x:
		_zam = -1.0


func _resurface() -> void:
	ice.fill(Vector3i.ZERO, Vector3i(_nx, TOP, _nz), UNDER)
	ice.fill(Vector3i(0, TOP, 0), Vector3i(_nx, TOP + 1, _nz), ICE)
	ice.fill(Vector3i(0, TOP + 1, 0), Vector3i(_nx, LAYERS, _nz), Color(0, 0, 0, 0))


## Centre red line, two blue lines, a goal line each end, and a glowing
## goal light voxel strip at one end (emission by alpha).
func _paint_lines(x0 := 0, x1 := -1) -> void:
	if x1 < 0:
		x1 = _nx
	var lines := [
		[_nx / 2, 3, RED],
		[_nx / 4, 3, BLUE],
		[_nx * 3 / 4, 3, BLUE],
		[int(1.5 / VOXEL), 1, RED],
		[_nx - int(1.5 / VOXEL), 1, RED]
	]
	for l in lines:
		var lo: int = l[0] - l[1]
		var hi: int = l[0] + l[1]
		if hi < x0 or lo >= x1:
			continue
		ice.fill(Vector3i(maxi(lo, x0), TOP, 0), Vector3i(mini(hi, x1), TOP + 1, _nz), l[2])
	var gx := _nx - int(1.5 / VOXEL)
	if gx >= x0 and gx < x1:
		ice.fill(
			Vector3i(gx - 1, TOP, _nz / 2 - 20),
			Vector3i(gx + 1, TOP + 1, _nz / 2 + 20),
			Color(1.0, 0.2, 0.15, 0.2)
		)


func _voxel_at(p: Vector3) -> Vector3i:
	var l := p - ice.position
	return Vector3i(int(l.x / VOXEL), 0, int(l.z / VOXEL))


## Where the view line meets the ice plane, or null when it does not.
func _aim() -> Variant:
	var cam := walker.camera
	var o := cam.global_position
	var d := -cam.global_transform.basis.z
	if d.y >= -0.01:
		return null
	var t := (_top - o.y) / d.y
	if t > 30.0:
		return null
	return o + d * t


func _unhandled_input(event: InputEvent) -> void:
	if walker == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				interactor.act("take")
			KEY_F:
				interactor.act("throw" if interactor.carrying else "push")
			KEY_Z:
				if _zam < 0.0:
					_zam = 0.0
			KEY_R:
				_resurface()
				_paint_lines()
			KEY_ESCAPE:
				Input.mouse_mode = (
					Input.MOUSE_MODE_VISIBLE
					if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
					else Input.MOUSE_MODE_CAPTURED
				)
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_snowball()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_chip()


func _box(body: StaticBody3D, at: Vector3, size: Vector3, colour: Color, draw: bool) -> void:
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


func _lights() -> void:
	_env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("1a1d24")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.6, 0.7)
	e.ambient_light_energy = 0.5
	e.ssao_enabled = true
	e.glow_enabled = true
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.environment = e
	add_child(_env)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-62, 20, 0)
	_sun.light_energy = 1.0
	_sun.shadow_enabled = true
	add_child(_sun)


func _screenshot(path: String) -> void:
	# a boot trail, a crater and a snowball in view, seen from the end of the trail
	for i in 40:
		walker.position += Vector3(0.12, 0, 0.04 * sin(i * 0.3))
		_tracks()
	walker.rotation.y = PI / 2  # look back down the trail (-x)
	walker.camera.rotation.x = -0.6
	for i in 12:
		await get_tree().process_frame
	_chip()
	walker.camera.rotation.x = -0.5
	for i in 12:
		await get_tree().process_frame
	_snowball()
	walker.camera.rotation.x = -0.55
	for i in 30:
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
	var chunks := ice._chunks.size()
	check.call(
		chunks == ceili(float(_nx) / 16) * ceili(float(_nz) / 16),
		"the sheet is meshed in chunks (%d)" % chunks
	)
	check.call(ice.dirty_count() == 0, "nothing dirty after the first mesh")
	var v := _voxel_at(Vector3(0.0, 0.0, 0.0))
	_carve(v.x, v.z, 0)
	check.call(ice.dirty_count() >= 1, "a boot mark dirties its chunk")
	await get_tree().process_frame
	await get_tree().process_frame
	check.call(ice.dirty_count() == 0, "the budget re-meshes it within a frame or two")
	check.call(ice.get_voxel(v.x, TOP, v.z).a == 0.0, "the top voxel is gone")
	_zam = 0.0
	var frames := 0
	while _zam >= 0.0 and frames < 2000:
		await get_tree().process_frame
		frames += 1
	check.call(_zam < 0.0, "the resurfacer finishes")
	check.call(ice.get_voxel(v.x, TOP, v.z).a > 0.0, "the resurfacer filled the mark")
	var settle := 0
	while ice.dirty_count() > 0 and settle < 600:
		await get_tree().process_frame
		settle += 1
	check.call(
		ice.dirty_count() == 0, "the mesher caught up after the pass (%d left)" % ice.dirty_count()
	)
	check.call(objects.count() == 8, "mugs on the ice")
	print("ice demo: %d chunks, resurfacer pass in %d frames" % [chunks, frames])
	if _fails == 0:
		print("ice_demo test: all passed")
	get_tree().quit(1 if _fails else 0)
