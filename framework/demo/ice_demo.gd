extends Node3D
## The ice demo: a sheet of ice as columns (IceSheet), drawn by the ice
## shader with its four surface states. X cycles the whole sheet through
## snowed up, dry cut, flooded and fresh frozen. Holding LMB runs a hose
## where you look (a stream of drops, water that pools and runs downhill)
## and you watch it set from the edges in under the slab and air
## temperatures on the readout; set water is ice, so flooding one spot
## again and again builds it up, and the readout gives the height under
## the dot; I makes water set the instant it lands, for testing the blade
## against built-up ice. T speeds the clock up. RMB chips a gouge. R
## drives the resurfacer from the blue line to the red line along your
## side of the sheet: in DRY CUT mode the blade shaves everything above
## its level and leaves striations along its travel, in FLOOD mode the
## rag lays a film behind the blade; M switches mode, [ and ] set the
## blade, Y wears the rag. Mugs on the ice to kick and carry. Footsteps
## leave the ice alone. Ctrl crouches, F flies, Z zooms.
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
const RAGS := ["NEW", "USED", "WORN"]
const MODES := ["DRY CUT", "FLOOD"]
const MACHINE_W := 2.1  # the conditioner's width
const MACHINE_SPEED := 2.0  # m/s
const PASS_X0 := 6.0  # the blue line
const PASS_X1 := 12.0  # the red line
const HOSE_LPS := 1.6  # the big hose wide open, litres a second
const HOSE_WIDTH := 0.5  # metres the stream wets
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
var rag_i := 0
var mode_i := 0
var blade_mm := 0.0
var instant := false
var pass_z := -1.0
var shaved_mm := 0.0
var _machine: Node3D
var hosing := false
var chipping := false
var _chip_t := 0.0
var hosed_l := 0.0
var _stream: GPUParticles3D
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
	(
		hud
		. legend(
			"[X] STATE   [LMB] HOSE   [RMB] CHIP   [R] RESURFACER   [M] MODE   [ [ ] ] BLADE   [Y] RAG   [I] INSTANT FREEZE   [T] CLOCK   [CTRL] CROUCH   [F] FLY   [Z] ZOOM"
		)
	)
	_machine = _make_machine()
	add_child(_machine)
	_machine.visible = false
	_stream = _make_stream()
	add_child(_stream)
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
	if instant:
		ice.set_now()
	if _zam >= 0.0:
		_zamboni_step(sdt)
	if walker:
		field.focus = walker.global_position
		if hosing:
			_hose(dt)
		_stream.emitting = hosing
		if chipping:
			_chip_t -= dt
			if _chip_t <= 0.0:
				_chip_t = 0.08
				_chip()
	if hud:
		var under := ""
		var at: Variant = _aim()
		if at != null:
			under = (
				"   UNDER THE DOT: TOP +%.1f MM, ICE +%.1f MM"
				% [ice.top_at(_local(at)), ice.ice_at(_local(at))]
			)
		(
			hud
			. readout(
				(
					"STATE %s   SLAB %.1f C   AIR %.1f C   CLOCK x%d%s   T+%s   WET %d   DIRTY %d / %d\nRESURFACER %s   BLADE %+.2f MM   RAG %s   SHAVED %.0f MM   HOSED %.0f L%s"
					% [
						STATES[state][0],
						slab_c,
						air_c,
						int(SCALES[scale_i]),
						"   INSTANT FREEZE" if instant else "",
						_clock(sim_t),
						ice.wet_cells,
						ice.dirty_count(),
						ice.chunk_count(),
						MODES[mode_i],
						blade_mm,
						RAGS[rag_i],
						shaved_mm,
						hosed_l,
						under
					]
				)
			)
		)


func _set_state(k: int) -> void:
	state = k % STATES.size()
	var s: Array = STATES[state]
	ice.fill_state(s[1], s[2], s[3], s[4], 0.08 if s[2] > 0.0 else 0.0)


## The hose, while LMB is held: HOSE_LPS of water a second over a disc
## HOSE_WIDTH across where you look, and the stream of drops to match.
func _hose(dt: float) -> void:
	var at: Variant = _aim()
	if at == null:
		return
	var litres := HOSE_LPS * dt
	hosed_l += litres
	var area := PI * (HOSE_WIDTH * 0.5) * (HOSE_WIDTH * 0.5)
	ice.pour(_local(at), HOSE_WIDTH, litres * 0.001 / area * 1000.0)  # L -> m3 -> m -> mm
	var hand := (
		walker.camera.global_position
		- walker.camera.global_transform.basis.z * 0.5
		- Vector3(0, 0.35, 0)
	)
	_stream.global_position = hand
	var to: Vector3 = at - hand
	var mat: ParticleProcessMaterial = _stream.process_material
	# a drop flies the distance under gravity in about 0.45 s
	var t := 0.45
	var v := Vector3(to.x / t, to.y / t + 0.5 * 9.8 * t, to.z / t)
	mat.direction = v.normalized()
	mat.initial_velocity_min = v.length() * 0.9
	mat.initial_velocity_max = v.length() * 1.1
	if WorldSound.wanted():
		WorldSound.play(self, "ball_bounce_2", at, -20.0, 0.6)


func _make_stream() -> GPUParticles3D:
	var ps := GPUParticles3D.new()
	ps.amount = 240
	ps.lifetime = 0.8
	ps.emitting = false
	ps.local_coords = false
	var mat := ParticleProcessMaterial.new()
	mat.gravity = Vector3(0, -9.8, 0)
	mat.spread = 4.0
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = 5.0
	mat.scale_min = 0.6
	mat.scale_max = 1.0
	ps.process_material = mat
	var mesh := SphereMesh.new()
	mesh.radius = 0.012
	mesh.height = 0.024
	mesh.radial_segments = 6
	mesh.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.85, 1.0, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	mesh.material = m
	ps.draw_pass_1 = mesh
	return ps


## A chip (RMB held: one every 0.08 s wherever you look): a small round
## gouge under the dot, 2 mm deep in the middle, snow thrown around it.
func _chip() -> void:
	var at: Variant = _aim()
	if at == null:
		return
	ice.chip(_local(at), 0.12, 2.0, 0.4)
	if WorldSound.wanted():
		WorldSound.play(self, "blade_skip", at, -6.0, 0.9)


## The resurfacer: from the blue line to the red line along the player's
## side of the sheet at MACHINE_SPEED, the blade shaving as it goes; in
## FLOOD mode the rag lays the film behind it.
func _start_pass() -> void:
	if _zam >= 0.0 or walker == null:
		return
	_zam = PASS_X0
	pass_z = clampf(_local(walker.global_position).y, MACHINE_W / 2, RINK.y - MACHINE_W / 2)
	shaved_mm = 0.0
	_machine.visible = true


func _zamboni_step(sdt: float) -> void:
	var x0 := _zam
	_zam += sdt * MACHINE_SPEED
	var x1 := minf(_zam, PASS_X1)
	var film := 0.8 if mode_i == 1 else 0.0
	shaved_mm += ice.resurface(
		x0, x1, pass_z - MACHINE_W / 2, pass_z + MACHINE_W / 2, film, rag_i / 2.0, blade_mm, 0.0
	)
	_machine.position = ice.position + Vector3(x1 + 1.2, 0.0, pass_z)
	if _zam >= PASS_X1:
		_zam = -1.0
		_machine.visible = false
		if hud:
			hud.toast("PASS DONE: %s, SHAVED %.0f MM OF COLUMNS" % [MODES[mode_i], shaved_mm])


## A box for the machine, so the pass is seen; the blade is the dark bar
## at the back edge.
func _make_machine() -> Node3D:
	var n := Node3D.new()
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.8, 1.6, MACHINE_W)
	body.mesh = bm
	body.position = Vector3(0, 0.9, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("2f4a6e")
	body.material_override = m
	n.add_child(body)
	var blade := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.12, 0.08, MACHINE_W)
	blade.mesh = bb
	blade.position = Vector3(-1.3, 0.04, 0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color("1a1c20")
	blade.material_override = bmat
	n.add_child(blade)
	return n


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
			KEY_X:
				_set_state(state + 1)
				hud.toast("STATE: %s" % STATES[state][0])
			KEY_R:
				_start_pass()
				hud.toast("RESURFACER: %s PASS, BLADE %+.2f MM" % [MODES[mode_i], blade_mm])
			KEY_M:
				mode_i = (mode_i + 1) % MODES.size()
				hud.toast("RESURFACER MODE: %s" % MODES[mode_i])
			KEY_BRACKETLEFT:
				blade_mm = maxf(blade_mm - 0.25, -2.0)
				hud.toast("BLADE %+.2f MM" % blade_mm)
			KEY_BRACKETRIGHT:
				blade_mm = minf(blade_mm + 0.25, 6.0)
				hud.toast("BLADE %+.2f MM" % blade_mm)
			KEY_I:
				instant = not instant
				hud.toast("INSTANT FREEZE %s" % ("ON" if instant else "OFF"))
			KEY_T:
				scale_i = (scale_i + 1) % SCALES.size()
				hud.toast("CLOCK x%d" % int(SCALES[scale_i]))
			KEY_Y:
				rag_i = (rag_i + 1) % RAGS.size()
				hud.toast("RAG: %s" % RAGS[rag_i])
	elif event is InputEventMouseButton:
		if not event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				hosing = false
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				chipping = false
			return
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_LEFT:
			hosing = true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			chipping = true
			_chip_t = 0.0


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
	e.ambient_light_energy = 0.45
	e.ssao_enabled = true
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.05
	e.tonemap_white = 5.0
	_env.environment = e
	add_child(_env)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-62, 20, 0)
	_sun.light_energy = 0.25
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
			l.light_energy = 1.4
			l.spot_range = 16.0
			l.spot_angle = 48.0
			l.shadow_enabled = true
			l.shadow_bias = 0.2
			l.shadow_normal_bias = 3.0
			add_child(l)


static func _clock(t: float) -> String:
	return "%02d:%02d" % [int(t) / 60, int(t) % 60]


func _screenshot(path: String) -> void:
	# a bump of instant-frozen floods, then a dry pass at +1 mm over it:
	# the blade leaves striations along its travel and shaves the bump
	walker.global_position = ice.position + Vector3(5.0, 0.05, 4.0)
	walker.rotation.y = -PI / 2  # look along +x, down the pass
	walker.camera.rotation.x = -0.45
	for again in 4:
		ice.pour(Vector2(8.0, 4.0), 0.8, 1.2)
		ice.set_now()
	_start_pass()
	blade_mm = 1.0
	for i in 20:
		_zamboni_step(0.15)
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
		ice.ice[edge] > 0.0 or ice.frozen[edge] > ice.frozen[mid],
		(
			"the shallow edge sets before the deep middle (%.2f vs %.2f)"
			% [ice.frozen[edge], ice.frozen[mid]]
		)
	)
	for minute in 16:
		ice.thermal(60.0, -5.0, 8.0)
	check.call(
		ice.water[mid] == 0.0 and ice.ice[mid] > 1.0,
		(
			"1.2 mm at -5 C sets in under 20 minutes (water %.2f, ice %.2f)"
			% [ice.water[mid], ice.ice[mid]]
		)
	)
	ice.thermal(1.0, -5.0, 8.0)
	check.call(ice.wet_cells == 0, "no wet cells left (%d)" % ice.wet_cells)
	# set water is ice: flooding the same spot again builds it up
	var h0 := ice.ice_at(Vector2(6.0, 7.0))
	check.call(h0 > 1.0, "the set pour became ice (%.2f mm)" % h0)
	for again in 3:
		ice.pour(Vector2(6.0, 7.0), 0.6, 1.2)
		for minute in 20:
			ice.thermal(60.0, -5.0, 8.0)
	var h1 := ice.ice_at(Vector2(6.0, 7.0))
	check.call(h1 > h0 + 3.0, "three more floods raised it (%.2f -> %.2f mm)" % [h0, h1])
	# a whole flooded sheet: level chunks stay one quad and a step stays cheap
	_set_state(2)
	ice.flush()
	ice.thermal(1.0, -5.0, 8.0)  # the first call builds the walk list
	var t0 := Time.get_ticks_usec()
	ice.thermal(1.0, -5.0, 8.0)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	check.call(ms < 6.0, "a thermal step on a flooded sheet is under 6 ms (%.1f)" % ms)
	t0 = Time.get_ticks_usec()
	ice.flush()
	var flush_ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("ice demo: flooded sheet thermal %.1f ms, full flush %.0f ms" % [ms, flush_ms])
	_set_state(1)
	ice.flush()
	# a chip gouges; a blade at zero rides over it, a blade below the base takes it
	ice.stroke(Vector2(3.0, 3.0), Vector2(3.3, 3.0), 0.04, 0.9, 2.0, 0.4)
	var g := ice.index(ice.cell_at(Vector2(3.15, 3.0)).x, ice.cell_at(Vector2(3.15, 3.0)).y)
	check.call(ice.gouge[g] > 1.0, "a chip gouges (%.2f mm)" % ice.gouge[g])
	ice.resurface(0.0, RINK.x, 0.0, RINK.y, 0.8, 0.0, 0.0, 0.0)
	check.call(
		ice.gouge[g] > 1.0 and is_equal_approx(ice.water[g], 0.8),
		"a flood pass at blade 0 leaves the gouge under an even film"
	)
	ice.resurface(0.0, RINK.x, 0.0, RINK.y, 0.0, 0.0, -2.0, 0.0)
	check.call(ice.gouge[g] == 0.0, "a dry pass at -2 mm takes the gouge (%.2f)" % ice.gouge[g])
	# the rag: a worn one leaves streaks and a coarser cut
	ice.resurface(0.0, RINK.x, 0.0, RINK.y, 0.8, 1.0, 0.0, 0.0)
	var streaky := false
	for z in 40:
		if not is_equal_approx(ice.water[ice.index(g % ice.w, z)], 0.8):
			streaky = true
	check.call(streaky, "a worn rag leaves streaks")
	# water on snow is slush and sets into a rough crust
	_set_state(0)
	ice.flush()
	ice.pour(Vector2(12.0, 5.0), 0.6, 1.2)
	var sc := ice.cell_at(Vector2(12.0, 5.0))
	var si := ice.index(sc.x, sc.y)
	check.call(ice.snow[si] > 0.0 and ice.water[si] > 0.0, "water on snow keeps the snow as slush")
	for minute in 25:
		ice.thermal(60.0, -5.0, 8.0)
	check.call(
		ice.crust[si] > 0.5 and ice.snow[si] == 0.0 and ice.water[si] == 0.0,
		"slush set into a crust (%.2f mm)" % ice.crust[si]
	)
	# water runs into a gouge and fills it: the trench goes, a scar stays
	_set_state(1)
	ice.flush()
	ice.stroke(Vector2(9.0, 9.0), Vector2(9.4, 9.0), 0.04, 0.9, 2.0, 0.0)
	var gc := ice.cell_at(Vector2(9.2, 9.0))
	var gi := ice.index(gc.x, gc.y)
	var depth0 := ice.gouge[gi]
	ice.pour(Vector2(9.2, 9.1), 0.6, 1.5)  # a puddle over and beside it
	for minute in 30:
		ice.thermal(60.0, -5.0, 8.0)
	check.call(
		ice.gouge[gi] < depth0 and ice.scar[gi] > 0.0,
		(
			"water ran into the gouge and set (gouge %.2f -> %.2f, scar %.2f)"
			% [depth0, ice.gouge[gi], ice.scar[gi]]
		)
	)
	# the blade: built-up ice above its level is shaved, striations run along the travel
	_set_state(1)
	ice.flush()
	for again in 4:
		ice.pour(Vector2(8.0, 4.0), 0.6, 1.2)
		ice.set_now()
	var bump := ice.top_at(Vector2(8.0, 4.0))
	check.call(bump > 3.0, "four instant floods built a bump (%.2f mm)" % bump)
	var took := ice.resurface(PASS_X0, PASS_X1, 3.0, 5.0, 0.0, 0.0, 1.0, 0.0)
	check.call(
		took > 0.0 and ice.top_at(Vector2(8.0, 4.0)) <= 1.01,
		(
			"a blade at +1 mm shaved it to 1 mm (%.2f, took %.0f)"
			% [ice.top_at(Vector2(8.0, 4.0)), took]
		)
	)
	var bc := ice.cell_at(Vector2(8.0, 4.0))
	var bi := ice.index(bc.x, bc.y)
	check.call(
		is_equal_approx(ice.ang[bi], 0.0) and ice.cut[bi] > 0.7,
		"the cut's striations run along the travel"
	)
	var uc := ice.cell_at(Vector2(9.5, 4.8))
	check.call(ice.ang[ice.index(uc.x, uc.y)] > 0.05, "a column below the blade keeps its old cut")
	took = ice.resurface(PASS_X0, PASS_X1, 3.0, 5.0, 0.0, 0.0, 0.0, 0.0)
	check.call(
		ice.top_at(Vector2(8.0, 4.0)) <= 0.01 and took > 0.0,
		"a blade at 0 takes the rest (%.2f)" % ice.top_at(Vector2(8.0, 4.0))
	)
	ice.flush()
	check.call(ice.remeshed > 135, "chunks re-meshed (%d)" % ice.remeshed)
	check.call(objects.count() == 8, "mugs on the ice")
	print("ice demo: %d chunks, %d re-meshes" % [ice.chunk_count(), ice.remeshed])
	if _fails == 0:
		print("ice_demo test: all passed")
	get_tree().quit(1 if _fails else 0)
