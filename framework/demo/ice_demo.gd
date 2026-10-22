extends Node3D
## The ice demo: a full NHL sheet of ice (60.96 x 25.9 m, 8.5 m corners,
## the lines and circles painted under it, boards around it)
## as columns (IceSheet), drawn by the ice shader with its four surface
## states. X cycles the whole sheet through
## snowed up, dry cut, flooded and fresh frozen. Holding LMB runs a hose
## where you look (a stream of drops, water that pools and runs downhill)
## and you watch it set from the edges in under the slab and air
## temperatures on the readout; set water is ice, so flooding one spot
## again and again builds it up, and the readout gives the height under
## the dot; I makes water set the instant it lands, for testing the blade
## against built-up ice. T speeds the clock up. RMB chips a gouge. R
## drives the resurfacer end to end down the sheet along your lane:
## in DRY CUT mode the blade shaves everything above
## its level and leaves striations along its travel, in FLOOD mode the
## rag lays a film behind the blade; M switches mode, [ and ] set the
## blade, Y wears the rag. Mugs on the ice to kick and carry. Footsteps
## leave the ice alone. Ctrl crouches, F flies, Z zooms.
##
##   godot --path . res://scenes/dev/ice_demo.tscn
##
## `-- --test=ice_demo` is the headless check.

# the NHL sheet, as scripts/rink/rink.gd has it (the demo keeps its own
# copy so the framework layer stays free of the game's scripts)
const RINK := Vector2(60.96, 25.9)  # metres
const CORNER_R := 8.5
const CELL := 0.025
# the markings, in metres from the sheet's corner
const PX := 80.0  # markings texels per metre (1.25 cm)
const LINE_W := 0.3048  # the blue and centre lines, 12 in
const THIN_W := 0.0508  # every other line, 2 in
const GOAL_LINE := 3.353  # 11 ft from the end boards
const BLUE_LINE := 22.86  # 75 ft
const CIRCLE_R := 4.572  # 15 ft
const DOT_R := 0.3048  # the face-off dots, 2 ft across
const DOT_FROM_GOAL := 6.096  # the end-zone dots, 20 ft from the goal line
const DOT_OFF := 6.706  # all dots 22 ft off the centre line
const NEUTRAL_DOT := 1.524  # the neutral-zone dots, 5 ft from the blue line
const HASH_LEN := 0.61  # 2 ft
const HASH_OFF := 0.851  # the hash marks 5 ft 7 in apart
const CREASE_R := 1.829  # 6 ft
const CREASE_HALF_W := 1.219  # 4 ft
const TRAP_GOAL := 3.353  # the trapezoid, half of 22 ft on the goal line
const TRAP_BOARDS := 4.267  # half of 28 ft at the boards
const REF_CREASE_R := 3.048  # 10 ft
const BOARD_H := 1.07  # 42 in
const KICK_H := 0.2
const BOARD_T := 0.1
const STATES := [
	["SNOWED UP", 1.0, 0.0, 0.0, 0.0],
	["DRY CUT", 0.0, 0.8, 0.0, 0.0],
	["FLOOD", 0.0, 0.8, 1.2, 0.0],
	["DRY, FRESH, FROZEN", 0.0, 0.0, 1.2, 1.0],
]
const SCALES := [1.0, 10.0, 60.0]
const RAGS := ["NEW", "USED", "WORN"]
const FLOOD_FULL_MM := 1.2  # the film the flood valve lays wide open
const MACHINE_W := 2.1  # the conditioner's width
const MACHINE_SPEED := 2.0  # m/s
const PASS_X0 := 2.0  # the pass runs end to end, clear of the end boards
const PASS_X1 := RINK.x - 2.0
const HOSE_LPS := 1.6  # the big hose wide open, litres a second
const HOSE_MIN := 0.1
const HOSE_MAX := 6.0
const HOSE_WIDTH := 0.5  # metres the stream wets
const RED := Color("c8322e")
const BLUE := Color("2a4fb0")
const LIGHT_BLUE := Color("9ec9e8")
const KICK := Color("e8c23a")
const BOARD := Color("f2f0ea")
const CONCRETE := Color("7d7f82")

var ice: IceSheet
var field: PropField
var objects: WorldObjects
var walker: FirstPerson
var interactor: Interactor
var hud: WalkHud
var state := 1
var scale_i := 0
var rag_i := 0
var instant := false
var pass_z := -1.0
var shaved_mm := 0.0
var hosing := false
var chipping := false
var hosed_l := 0.0
var hose_lps := HOSE_LPS
var slab_c := -5.0
var air_base := 8.0
var air_c := 8.0
var sim_t := 0.0
var _machine: Zambelli
var _aimed := -1  # the machine control under the dot
var _no_aim := false  # a screenshot of a control, without its glow
var _aboard := false  # the walker is in the seat and the keys drive the machine
var _chip_t := 0.0
var _stream: GPUParticles3D
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
	ice.setup(RINK, CELL, CORNER_R)
	ice.set_markings(_markings())
	_set_state(state)
	ice.flush()
	# the concrete under the ice (seen past the corner arcs) for the walker
	# and the props; boards with curved corners around it
	var shell := StaticBody3D.new()
	shell.collision_layer = Layers.bit(Layers.VENUE)
	shell.collision_mask = 0
	add_child(shell)
	# the walker stands at the ice's nominal top; the concrete is drawn a
	# full sheet thickness lower (at the demo's height scale), so a cut
	# into the ice shows ice, and only a cut through all of it shows grey
	_box(shell, Vector3(0, -0.103, 0), Vector3(RINK.x + 0.4, 0.2, RINK.y + 0.4), CONCRETE, false)
	var slab_top := -ice.base_mm * 0.001 * ice.height_scale
	_box(
		shell,
		Vector3(0, slab_top - 0.1, 0),
		Vector3(RINK.x + 0.4, 0.2, RINK.y + 0.4),
		CONCRETE,
		true,
		false
	)
	_boards(shell)
	field = PropField.new()
	field.name = "Props"
	add_child(field)
	objects = WorldObjects.new()
	objects.field = field
	add_child(objects)
	var audio := ContactAudio.new()
	add_child(audio)
	audio.listen_objects(objects)
	var quality := "medium"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="):
			quality = a.trim_prefix("--quality=")
	Quality.apply(
		quality, {"env": _env, "sun": _sun, "fields": [field], "viewport": get_viewport()}
	)
	_machine = _make_machine()
	add_child(_machine)
	if OS.get_cmdline_user_args().has("--test=ice_demo"):
		_self_test.call_deferred()
		return
	walker = FirstPerson.new()
	walker.position = Vector3(-RINK.x / 2 + BLUE_LINE - 2.0, 0.05, 0.0)
	add_child(walker)
	walker.face(-PI / 2)  # down the ice
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
			(
				"[X] STATE   [LMB] HOSE   [WHEEL] VALVE   [RMB] CHIP   [, .] ICE OVER PAINT   "
				+ "[R] RESURFACER   [N] SEAT   [W S] PEDAL BRAKE   [A D] STEER   [E] USE   [WHEEL] TURN   [M] FLOOD   "
				+ "[ [ ] ] BLADE   [Y] RAG   [I] INSTANT FREEZE   [T] CLOCK   [B] BODY   "
				+ "[V] SEE MACHINE   [CTRL] CROUCH   [F] FLY   [Z] ZOOM"
			)
		)
	)
	_stream = _make_stream()
	add_child(_stream)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--base="):
			ice.base_mm = float(a.trim_prefix("--base="))
			ice.mark_all_dirty()
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
	elif _aboard:
		_drive(sdt)
	if _aboard and walker:
		walker.global_position = _machine.to_global(Zambelli.SEAT)
	if (
		_zam < 0.0
		and (
			_machine
			and _machine.speed == 0.0
			and _machine.auger_on
			and _machine.lift_on
			and _machine.trough_m3() + _machine.pile_m3 < 0.0005
		)
	):
		# the pass is over and the augers have cleared the snow: dump the tank
		_machine.auger_on = false
		_machine.lift_on = false
		var dumped := _machine.dump()
		if hud and dumped > 0.0:
			hud.toast("TANK DUMPED: %.0f L OF SNOW" % (dumped * 1000.0))
	if walker:
		field.focus = walker.global_position
		var cam := walker.camera
		_aimed = -1
		if not _no_aim:
			_aimed = _machine.controls.aim(cam.global_position, -cam.global_transform.basis.z)
		_machine.controls.set_hover(_aimed)
		if hud:
			hud.extra_prompt = _machine.controls.prompt(_aimed)
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
			var p := _local(at)
			under = (
				"   UNDER THE DOT: ICE %.2f MM THICK, SNOW %.2f MM, WATER %.2f MM"
				% [ice.thickness_at(p), ice.snow_at(p), ice.water_at(p)]
			)
		var line1 := (
			"STATE %s   PAINT UNDER %.0f MM   SLAB %.1f C   AIR %.1f C   CLOCK x%d%s   T+%s   WET %d   DIRTY %d / %d"
			% [
				STATES[state][0],
				ice.base_mm,
				slab_c,
				air_c,
				int(SCALES[scale_i]),
				"   INSTANT FREEZE" if instant else "",
				_clock(sim_t),
				ice.wet_cells,
				ice.dirty_count(),
				ice.chunk_count()
			]
		)
		var line2 := (
			"BLADE %s (%+.2f MM)   FLOOD %d%%   WASH %d%%   RAG %s   SHAVED %.0f MM   HOSE %.1f L/S   HOSED %.0f L%s"
			% [
				ZambelliControls.turns_text(_machine.blade_mm),
				_machine.blade_mm,
				roundi(_machine.flood * 100.0),
				roundi(_machine.wash * 100.0),
				RAGS[rag_i],
				shaved_mm,
				hose_lps,
				hosed_l,
				under
			]
		)
		var line3 := ""
		if _machine:
			line3 = _machine_line()
		hud.readout(line1 + "\n" + line2 + "\n" + line3)


func _machine_line() -> String:
	return (
		(
			"DRIVE %s   CONDITIONER %s   AUGERS %s/%s   BIN %s   "
			+ "TROUGH %.1f L   PILE %.1f L   LIFT %.1f L/S   TANK %.0f L (%.0f%%)"
		)
		% [
			ZambelliControls.DRIVE_NAMES[_machine.drive],
			"DOWN" if _machine.is_down() else ("UP" if _machine.lift <= 0.001 else "MOVING"),
			"ON" if _machine.auger_on else "OFF",
			"ON" if _machine.lift_on else "OFF",
			"UP" if _machine.bin_up else "DOWN",
			_machine.trough_m3() * 1000.0,
			_machine.pile_m3 * 1000.0,
			_machine.lift_flow * 1000.0,
			_machine.tank_m3 * 1000.0,
			_machine.tank_m3 / Zambelli.TANK_M3 * 100.0
		]
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
	var litres := hose_lps * dt
	hosed_l += litres
	var area := PI * (HOSE_WIDTH * 0.5) * (HOSE_WIDTH * 0.5)
	var mm := litres * 0.001 / area * 1000.0  # L -> m3 -> m -> mm
	# the stream wanders a little, as a hose does
	var wander := Vector2(randf_range(-0.08, 0.08), randf_range(-0.08, 0.08))
	ice.pour(_local(at) + wander, HOSE_WIDTH, mm)
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
	_stream.amount_ratio = clampf(hose_lps / HOSE_LPS, 0.15, 1.0)
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


## The resurfacer: end to end along the player's lane at MACHINE_SPEED,
## the blade shaving as it goes; in FLOOD mode the rag lays the film
## behind it.
func _start_pass() -> void:
	if _zam >= 0.0 or walker == null:
		return
	_begin_pass(_local(walker.global_position).y)


func _begin_pass(z: float) -> void:
	_zam = PASS_X0
	pass_z = clampf(z, MACHINE_W / 2, RINK.y - MACHINE_W / 2)
	shaved_mm = 0.0
	_machine.position = ice.position + Vector3(_zam, 0.0, pass_z)
	_machine.cond_down = true
	_machine.auger_on = true
	_machine.lift_on = true
	_machine.drive = 0
	_machine.speed = MACHINE_SPEED


func _zamboni_step(sdt: float) -> void:
	var x0 := _zam
	_zam += sdt * MACHINE_SPEED
	var x1 := minf(_zam, PASS_X1)
	var film := FLOOD_FULL_MM * _machine.flood
	shaved_mm += ice.resurface(
		x0,
		x1,
		pass_z - MACHINE_W / 2,
		pass_z + MACHINE_W / 2,
		film,
		rag_i / 2.0,
		0.0,
		0.0,
		0.0,
		-_machine.blade_mm
	)
	_machine.feed(_shavings_by_bin())
	_machine.position = ice.position + Vector3(x1, 0.0, pass_z)
	if _zam >= PASS_X1:
		_zam = -1.0
		_machine.cond_down = false
		_machine.speed = 0.0
		_machine.drive = 1
		if hud:
			hud.toast("PASS DONE: SHAVED %.0f MM OF COLUMNS" % shaved_mm)


## The last resurface() call's shavings as the conditioner wants them: m³
## of ice under each of the blade's bins. The machine faces +X along the
## pass, so its bins run with the sheet's +Z; the band's rows (2.5 cm) are
## binned by where they sit across the 2.1 m blade.
func _shavings_by_bin() -> PackedFloat32Array:
	var bins := PackedFloat32Array()
	bins.resize(Zambelli.BINS)
	bins.fill(0.0)
	var z0 := pass_z - MACHINE_W / 2
	var cell_m3 := ice.cell * ice.cell * 0.001  # mm of a cell -> m³
	for r in ice.shave_rows.size():
		var mm := ice.shave_rows[r]
		if mm <= 0.0:
			continue
		var zm := (ice.shave_z0 + r + 0.5) * ice.cell
		var b := clampi(int((zm - z0) / MACHINE_W * Zambelli.BINS), 0, Zambelli.BINS - 1)
		bins[b] += mm * cell_m3
	return bins


## A frame at the wheel: W is the pedal, S the brake, A and D steer, the
## drive select lever on the console gives the direction. The conditioner
## resurfaces whatever the blade sweeps, on any heading; the boards stop
## the machine.
func _drive(sdt: float) -> void:
	_drive_with(
		sdt,
		1.0 if Input.is_key_pressed(KEY_W) else 0.0,
		1.0 if Input.is_key_pressed(KEY_S) else 0.0,
		(
			(1.0 if Input.is_key_pressed(KEY_A) else 0.0)
			- (1.0 if Input.is_key_pressed(KEY_D) else 0.0)
		)
	)


func _drive_with(sdt: float, pedal: float, brake: float, turn: float) -> void:
	var before := _machine.global_transform
	var sweep := _machine.drive_step(sdt, pedal, brake, turn)
	if sweep.is_empty():
		return
	if not _on_the_sheet():
		_machine.global_transform = before
		_machine.speed = 0.0
		if hud:
			hud.toast("THE BOARDS")
		return
	if not _machine.is_down():
		return
	var film := FLOOD_FULL_MM * _machine.flood
	var fwd := -_machine.global_transform.basis.z
	var took := ice.resurface_sweep(
		_local(sweep[0]),
		_local(sweep[1]),
		_local(sweep[2]),
		_local(sweep[3]),
		film,
		rag_i / 2.0,
		atan2(fwd.z, fwd.x),
		-_machine.blade_mm,
		Zambelli.BINS
	)
	shaved_mm += took
	if took > 0.0:
		var bins := ice.shave_bins.duplicate()
		var cell_m3 := ice.cell * ice.cell * 0.001
		for b in bins.size():
			bins[b] *= cell_m3
		_machine.feed(bins)


## Whether the machine's four corners are on the ice, clear of the boards.
func _on_the_sheet() -> bool:
	for c: Vector3 in [
		Vector3(-1.2, 0.0, -Zambelli.BLADE_Z - 0.1),
		Vector3(1.2, 0.0, -Zambelli.BLADE_Z - 0.1),
		Vector3(-1.2, 0.0, 0.85),
		Vector3(1.2, 0.0, 0.85)
	]:
		var p := _local(_machine.to_global(c))
		if p.x < 0.1 or p.x > RINK.x - 0.1 or p.y < 0.1 or p.y > RINK.y - 0.1:
			return false
	return true


## The resurfacer (framework/demo/zambelli.gd), parked by the end boards
## with the conditioner up until a pass; it faces +X, the way a pass runs.
func _make_machine() -> Zambelli:
	var z := Zambelli.new()
	z.name = "Zambelli"
	z.rotation.y = -PI / 2
	z.position = ice.position + Vector3(PASS_X0, 0.0, RINK.y - 3.0)
	z.cond_down = false
	z.lift = 0.0
	return z


func _blade_toast() -> String:
	return (
		"BLADE %s, %+.2f MM" % [ZambelliControls.turns_text(_machine.blade_mm), _machine.blade_mm]
	)


## Into the operator's seat: the whole machine shown, the keys drive it,
## the view over the console and the levers in reach.
func _at_the_controls() -> void:
	_machine.show_body = true
	_aboard = true
	walker.set_noclip(true)
	walker.driven = true
	walker.global_position = _machine.to_global(Zambelli.SEAT)
	walker.face(_machine.rotation.y)  # facing forward over the wheel
	walker.camera.rotation.x = -0.55


## Out of the seat, down on the ice beside the machine.
func _off_the_machine() -> void:
	_aboard = false
	walker.driven = false
	walker.set_noclip(false)
	walker.global_position = _machine.to_global(Vector3(-2.0, 0.05, 0.3))
	walker.face(_machine.rotation.y + PI / 2)
	walker.camera.rotation.x = -0.2


## The walker at `eye`, looking at `target` (noclip).
func _look_at(eye: Vector3, target: Vector3) -> void:
	walker.set_noclip(true)
	walker.global_position = eye - Vector3(0.0, FirstPerson.EYE, 0.0)
	var d := target - eye
	walker.face(atan2(-d.x, -d.z))
	walker.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


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
				hud.toast(
					(
						"RESURFACER: %s PASS, BLADE %+.2f MM"
						% ["FLOOD" if _machine.flood > 0.0 else "DRY", _machine.blade_mm]
					)
				)
			KEY_B:
				_machine.show_body = not _machine.show_body
				hud.toast("MACHINE: %s" % ("WHOLE" if _machine.show_body else "CONDITIONER ONLY"))
			KEY_V:
				# over to the machine, whole, from its left side
				_aboard = false
				walker.driven = false
				_machine.show_body = true
				walker.set_noclip(false)
				walker.global_position = _machine.global_position + Vector3(-1.5, 0.05, -5.0)
				walker.face(-2.85)
				walker.camera.rotation.x = -0.1
				hud.toast("THE ZAMBELLI")
			KEY_M:
				_machine.flood = 0.0 if _machine.flood > 0.0 else 0.65
				hud.toast("FLOOD VALVE %d%%" % roundi(_machine.flood * 100.0))
			KEY_BRACKETLEFT:  # half a turn of the handwheel either way
				_machine.blade_mm = clampf(_machine.blade_mm - 0.25, -3.0, 3.0)
				hud.toast(_blade_toast())
			KEY_BRACKETRIGHT:
				_machine.blade_mm = clampf(_machine.blade_mm + 0.25, -3.0, 3.0)
				hud.toast(_blade_toast())
			KEY_E:
				if _aimed >= 0:
					_machine.controls.toggle(_aimed)
					hud.toast(_machine.controls.prompt(_aimed).get_slice("   [", 0))
			KEY_N:
				if _aboard:
					_off_the_machine()
					hud.toast("OFF THE MACHINE")
				else:
					_at_the_controls()
					hud.toast("IN THE SEAT: [W] PEDAL  [S] BRAKE  [A D] STEER")
			KEY_COMMA:
				ice.base_mm = maxf(ice.base_mm - 2.0, 4.0)
				ice.mark_all_dirty()
				hud.toast("ICE OVER THE PAINT %.0f MM" % ice.base_mm)
			KEY_PERIOD:
				ice.base_mm = minf(ice.base_mm + 2.0, 60.0)
				ice.mark_all_dirty()
				hud.toast("ICE OVER THE PAINT %.0f MM" % ice.base_mm)
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
		elif (
			event.button_index == MOUSE_BUTTON_WHEEL_UP
			or event.button_index == MOUSE_BUTTON_WHEEL_DOWN
		):
			var up: bool = event.button_index == MOUSE_BUTTON_WHEEL_UP
			if _aimed >= 0:
				# a machine control under the dot: the handwheel or a valve
				_machine.controls.scroll(_aimed, 1.0 if up else -1.0)
				hud.toast(_machine.controls.prompt(_aimed).get_slice("   [", 0))
			else:
				# the valve (the Interactor has the wheel while something is held)
				var step := 1.25 if up else 0.8
				hose_lps = clampf(hose_lps * step, HOSE_MIN, HOSE_MAX)
				hud.toast("HOSE %.1f L/S" % hose_lps)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			hosing = true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			chipping = true
			_chip_t = 0.0


# --- dressing --------------------------------------------------------------


## The NHL markings as a texture under the ice: goal lines, blue lines,
## the centre line, the five circles and nine dots with their hash marks,
## the creases, the trapezoids, the referee's crease. Everything is rows
## of filled rectangles, so the 4877 x 2072 image draws in a moment.
func _markings() -> Texture2D:
	var img := Image.create(int(RINK.x * PX), int(RINK.y * PX), true, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var mid := RINK.y / 2
	for gl: float in [GOAL_LINE, RINK.x - GOAL_LINE]:
		var toward := 1.0 if gl < RINK.x / 2 else -1.0
		_rect(img, gl - THIN_W / 2, 0.0, gl + THIN_W / 2, RINK.y, RED)
		_crease(img, gl, toward, CREASE_R, CREASE_HALF_W, RED)
		_crease(img, gl, toward, CREASE_R - THIN_W, CREASE_HALF_W - THIN_W, LIGHT_BLUE)
		# the trapezoid behind the goal line, out to the end boards
		var boards := 0.0 if toward > 0.0 else RINK.x
		for side: float in [-1.0, 1.0]:
			_slant(
				img,
				Vector2(gl, mid + side * TRAP_GOAL),
				Vector2(boards, mid + side * TRAP_BOARDS),
				THIN_W,
				RED
			)
		# the end-zone circles, dots and hash marks
		var cx := gl + toward * DOT_FROM_GOAL
		for side: float in [-1.0, 1.0]:
			var cz := mid + side * DOT_OFF
			_ring(img, cx, cz, CIRCLE_R, THIN_W, RED)
			_disc(img, cx, cz, DOT_R, RED)
			for hx: float in [-1.0, 1.0]:
				for hz: float in [-1.0, 1.0]:
					var x := cx + hx * HASH_OFF
					var z0 := cz + hz * CIRCLE_R
					_rect(
						img,
						x - THIN_W / 2,
						minf(z0, z0 + hz * HASH_LEN),
						x + THIN_W / 2,
						maxf(z0, z0 + hz * HASH_LEN),
						RED
					)
	for bl: float in [BLUE_LINE, RINK.x - BLUE_LINE]:
		_rect(img, bl - LINE_W / 2, 0.0, bl + LINE_W / 2, RINK.y, BLUE)
		var toward := 1.0 if bl < RINK.x / 2 else -1.0
		for side: float in [-1.0, 1.0]:
			_disc(img, bl + toward * NEUTRAL_DOT, mid + side * DOT_OFF, DOT_R, RED)
	_rect(img, RINK.x / 2 - LINE_W / 2, 0.0, RINK.x / 2 + LINE_W / 2, RINK.y, RED)
	_ring(img, RINK.x / 2, mid, CIRCLE_R, THIN_W, BLUE)
	_disc(img, RINK.x / 2, mid, DOT_R / 2, BLUE)
	_ring(img, RINK.x / 2, 0.0, REF_CREASE_R, THIN_W, RED)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _rect(img: Image, x0: float, z0: float, x1: float, z1: float, colour: Color) -> void:
	var px0 := clampi(int(floor(x0 * PX)), 0, img.get_width())
	var px1 := clampi(int(ceil(x1 * PX)), 0, img.get_width())
	var pz0 := clampi(int(floor(z0 * PX)), 0, img.get_height())
	var pz1 := clampi(int(ceil(z1 * PX)), 0, img.get_height())
	if px1 > px0 and pz1 > pz0:
		img.fill_rect(Rect2i(px0, pz0, px1 - px0, pz1 - pz0), colour)


## A filled circle, drawn as rows.
static func _disc(img: Image, cx: float, cz: float, r: float, colour: Color) -> void:
	var rows := int(ceil(r * PX))
	for k in range(-rows, rows):
		var dz := (k + 0.5) / PX
		if absf(dz) >= r:
			continue
		var half := sqrt(r * r - dz * dz)
		_rect(img, cx - half, cz + k / PX, cx + half, cz + (k + 1) / PX, colour)


## A circle outline `wdt` wide, drawn as rows of two rectangles.
static func _ring(img: Image, cx: float, cz: float, r: float, wdt: float, colour: Color) -> void:
	var ri := r - wdt
	var rows := int(ceil(r * PX))
	for k in range(-rows, rows):
		var dz := (k + 0.5) / PX
		if absf(dz) >= r:
			continue
		var outer := sqrt(r * r - dz * dz)
		var inner := sqrt(ri * ri - dz * dz) if absf(dz) < ri else 0.0
		var z0 := cz + k / PX
		var z1 := cz + (k + 1) / PX
		_rect(img, cx - outer, z0, cx - inner, z1, colour)
		_rect(img, cx + inner, z0, cx + outer, z1, colour)


## The goal crease: a disc of radius `r` about the goal line's centre,
## cut to `half_w` either side and to the side toward centre ice.
static func _crease(
	img: Image, gl: float, toward: float, r: float, half_w: float, colour: Color
) -> void:
	var mid := RINK.y / 2
	var rows := int(ceil(half_w * PX))
	for k in range(-rows, rows):
		var dz := (k + 0.5) / PX
		if absf(dz) >= half_w or absf(dz) >= r:
			continue
		var reach := sqrt(r * r - dz * dz)
		var z0 := mid + k / PX
		var z1 := mid + (k + 1) / PX
		if toward > 0.0:
			_rect(img, gl, z0, gl + reach, z1, colour)
		else:
			_rect(img, gl - reach, z0, gl, z1, colour)


## A slanted line from a to b, `wdt` wide, as a run of small squares.
static func _slant(img: Image, a: Vector2, b: Vector2, wdt: float, colour: Color) -> void:
	var steps := int(ceil(a.distance_to(b) * PX))
	for k in steps + 1:
		var p := a.lerp(b, float(k) / maxi(steps, 1))
		_rect(img, p.x - wdt / 2, p.y - wdt / 2, p.x + wdt / 2, p.y + wdt / 2, colour)


## The boards: straight runs along the sides and ends, the corners as
## arcs of short segments, a kick plate along the foot. Positions are in
## world space (the sheet's centre is the origin).
func _boards(shell: StaticBody3D) -> void:
	var hx := RINK.x / 2
	var hz := RINK.y / 2
	var t := BOARD_T / 2
	for s in [
		[Vector3(0, 0, -hz - t), RINK.x - 2 * CORNER_R, 0.0],
		[Vector3(0, 0, hz + t), RINK.x - 2 * CORNER_R, 0.0],
		[Vector3(-hx - t, 0, 0), RINK.y - 2 * CORNER_R, PI / 2],
		[Vector3(hx + t, 0, 0), RINK.y - 2 * CORNER_R, PI / 2],
	]:
		_board(shell, s[0], s[1], s[2])
	var n := 16
	var seg := PI / 2 / n
	var r := CORNER_R + t
	var length := 2.0 * r * sin(seg / 2) * 1.03  # a hair of overlap closes the joints
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var centre := Vector3(sx * (hx - CORNER_R), 0, sz * (hz - CORNER_R))
			for i in n:
				var a := (i + 0.5) * seg
				var dir := Vector3(sx * cos(a), 0, sz * sin(a))
				var tangent := Vector3(-dir.z, 0, dir.x)
				_board(shell, centre + dir * r, length, atan2(-tangent.z, tangent.x))


func _board(shell: StaticBody3D, at: Vector3, length: float, yaw: float) -> void:
	_box(
		shell,
		at + Vector3(0, BOARD_H / 2, 0),
		Vector3(length, BOARD_H, BOARD_T),
		BOARD,
		false,
		true,
		yaw
	)
	_box(
		shell,
		at + Vector3(0, KICK_H / 2, 0),
		Vector3(length, KICK_H, BOARD_T + 0.01),
		KICK,
		true,
		false,
		yaw
	)
	_box(
		shell,
		at + Vector3(0, KICK_H + (BOARD_H - KICK_H) / 2, 0),
		Vector3(length, BOARD_H - KICK_H, BOARD_T),
		BOARD,
		true,
		false,
		yaw
	)


func _box(
	body: StaticBody3D,
	at: Vector3,
	size: Vector3,
	colour: Color,
	draw: bool,
	collide := true,
	yaw := 0.0
) -> void:
	if collide:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = at
		cs.rotation.y = yaw
		body.add_child(cs)
	if not draw:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = at
	mi.rotation.y = yaw
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
	for i in 7:
		var x := -24.0 + i * 8.0
		for z in [-6.5, 6.5]:
			var l := SpotLight3D.new()
			l.position = Vector3(x, 8.0, z)
			l.look_at_from_position(l.position, Vector3(x, 0, z * 0.6), Vector3.UP)
			l.light_color = Color("fff1dc")
			l.light_energy = 1.4
			l.spot_range = 20.0
			l.spot_angle = 50.0
			l.shadow_enabled = true
			l.shadow_bias = 0.2
			l.shadow_normal_bias = 3.0
			add_child(l)


static func _clock(t: float) -> String:
	return "%02d:%02d" % [int(t) / 60, int(t) % 60]


func _screenshot(path: String) -> void:
	# over the lines: a chip, a filled chip (clear ice) and the paint
	# showing through whatever ice is over it (--base=)
	walker.global_position = ice.position + Vector3(BLUE_LINE - 1.5, 0.05, RINK.y / 2)
	walker.face(-PI / 2)
	walker.camera.rotation.x = -0.55
	ice.chip(Vector2(BLUE_LINE - 0.2, RINK.y / 2 - 0.3), 0.14, 2.0, 0.3)
	ice.chip(Vector2(BLUE_LINE + 0.2, RINK.y / 2 + 0.1), 0.14, 2.0, 0.0)
	ice.pour(Vector2(BLUE_LINE + 0.2, RINK.y / 2 + 0.1), 0.4, 2.5)
	if not OS.get_cmdline_user_args().has("--view=pool"):
		ice.set_now()
	if OS.get_cmdline_user_args().has("--view=machine"):
		# the resurfacer mid-pass, from beside its lane
		walker.global_position = ice.position + Vector3(10.0, 0.05, 9.0)
		_machine.blade_mm = -0.5
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--cut="):
				_machine.blade_mm = -float(a.trim_prefix("--cut="))
		_set_state(0)  # a snowed-up sheet for the blade to shave
		ice.flush()
		_start_pass()
		for step in 540:  # 9 s of pass at 60 Hz, the augers carrying as they go
			_zamboni_step(1.0 / 60.0)
			_machine._process(1.0 / 60.0)
		_machine.settle()
		_machine.show_body = OS.get_cmdline_user_args().has("--body")
		if OS.get_cmdline_user_args().has("--flood"):
			# the flood water spraying from the pipe at the foot of the back
			# wall onto the ice, from low behind its +X end
			_machine.flood = 0.65
			_machine._process(1.0 / 60.0)
			_look_at(
				_machine.to_global(Vector3(1.6, 0.4, 1.4)),
				_machine.to_global(Vector3(0.2, 0.05, 0.64))
			)
		elif OS.get_cmdline_user_args().has("--side"):  # the whole machine side on
			walker.global_position = ice.position + Vector3(18.5, 0.05, 16.5)
			walker.camera.rotation.x = -0.05
			walker.face(0.0)
		elif _machine.show_body:
			walker.global_position = ice.position + Vector3(26.0, 0.05, 13.2)
			walker.camera.rotation.x = -0.15
		else:  # from above the front wall, into the open trough
			walker.set_noclip(true)
			walker.global_position = ice.position + Vector3(21.7, 0.9, 10.2)
			walker.camera.rotation.x = -0.62
		if (
			not OS.get_cmdline_user_args().has("--side")
			and not OS.get_cmdline_user_args().has("--flood")
		):
			walker.face(0.95)
	var args := OS.get_cmdline_user_args()
	if args.has("--view=console"):
		# the operator's station: the levers, the handwheel and the valves
		_machine.auger_on = true
		_machine.flood = 0.65
		_at_the_controls()
		if args.has("--above"):  # from behind and above, the whole console
			walker.global_position = _machine.to_global(Vector3(0.2, 1.9, 2.1))
			walker.face(_machine.rotation.y + 0.2)
			walker.camera.rotation.x = -0.72
		if args.has("--lever"):  # close on the console from the operator's left
			_no_aim = true
			_look_at(
				_machine.to_global(Vector3(-0.95, 2.35, 0.95)),
				_machine.to_global(Vector3(-0.12, 1.78, 0.25))
			)
	if args.has("--view=drive"):
		# from the seat, a dozen seconds into a curving flood pass across the sheet
		_machine.global_position = ice.position + Vector3(8.0, 0.0, 14.0)
		_machine.rotation.y = -PI / 2
		_machine.cond_down = true
		_machine.lift = 1.0
		_machine.settle()
		_machine.auger_on = true
		_machine.lift_on = true
		_machine.flood = 0.65
		_machine.drive = 0
		_at_the_controls()
		for step in 720:
			_drive_with(1.0 / 60.0, 1.0, 0.0, -0.3 if step > 240 else 0.0)
			_machine._process(1.0 / 60.0)
		walker.global_position = _machine.to_global(Zambelli.SEAT)
		walker.face(_machine.rotation.y + 2.9)  # looking back over the left shoulder at the lane
		walker.camera.rotation.x = -0.62
	if args.has("--view=pool"):
		# water run into the low spots and left to stand: a scraped trench,
		# a few chips, a pour between them, then a while to run downhill
		# with the slab at zero so nothing sets
		var o := Vector2(BLUE_LINE + 0.6, RINK.y / 2 + 0.4)
		walker.set_noclip(true)
		walker.global_position = ice.position + Vector3(o.x - 1.5, 1.0, o.y - 1.0)
		walker.face(-PI / 2 - 0.59)
		walker.camera.rotation.x = -0.62
		ice.stroke(o + Vector2(-0.3, -0.5), o + Vector2(1.4, 0.3), 0.06, 1.0, 2.5, 0.0)
		ice.chip(o + Vector2(0.4, 0.9), 0.18, 2.0, 0.0)
		ice.chip(o + Vector2(1.1, -0.6), 0.22, 3.0, 0.0)
		ice.chip(o + Vector2(-0.6, 0.3), 0.12, 1.2, 0.0)
		ice.pour(o + Vector2(0.5, 0.1), 0.9, 2.2)
		ice.pour(o + Vector2(0.9, -0.5), 0.5, 1.5)
		for step in 400:
			ice.thermal(0.1, 0.0, 8.0)
	if args.has("--view=cut"):
		# the dry cut from eye height, the striations a few metres off
		walker.global_position = ice.position + Vector3(BLUE_LINE - 7.0, 0.05, RINK.y / 2)
		walker.face(-PI / 2)
		walker.camera.rotation.x = -0.3
	if args.has("--view=wide"):
		# the whole sheet from above one end, after a few passes
		for lane in 4:
			var z := 3.0 + lane * MACHINE_W
			ice.resurface(
				PASS_X0, PASS_X1, z - MACHINE_W / 2, z + MACHINE_W / 2, 0.8, 0.0, 0.0, 0.0
			)
		walker.set_noclip(true)
		walker.global_position = Vector3(-RINK.x / 2 - 6.0, 12.0, 0.0)
		walker.face(-PI / 2)
		walker.camera.rotation.x = -0.42
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
	# 39 x 17 chunks less the ones wholly outside the corner arcs
	check.call(
		ice.chunk_count() > 600 and ice.chunk_count() < 39 * 17,
		"the sheet is %d chunks (want 600..662)" % ice.chunk_count()
	)
	check.call(not ice.is_ice(10, 10) and ice.is_ice(400, 400), "the corners are not ice")
	check.call(ice.dirty_count() == 0, "nothing dirty after the first flush")
	# a pour into a corner wets nothing outside the arc
	ice.pour(Vector2(0.4, 0.4), 0.6, 1.2)
	check.call(ice.wet_cells == 0, "water does not land outside the arc (%d)" % ice.wet_cells)
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
	check.call(ms < 8.0, "a thermal step on a flooded sheet is under 8 ms (%.1f)" % ms)
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
	# the paint is at a fixed depth: thicker ice over it reads deeper
	var d0 := ice.paint_depth(ice.index(10, 10))
	ice.base_mm += 10.0
	check.call(
		is_equal_approx(ice.paint_depth(ice.index(10, 10)), d0 + 10.0),
		"more base ice is more over the paint"
	)
	ice.base_mm -= 10.0
	ice.chip(Vector2(12.0, 12.0), 0.12, 2.0, 0.0)
	var cc := ice.cell_at(Vector2(12.0, 12.0))
	check.call(
		ice.paint_depth(ice.index(cc.x, cc.y)) < d0, "a chip brings the paint nearer the surface"
	)
	# water flows: a pour spreads into a pool and leaves a film at its rim
	_set_state(1)
	ice.flush()
	ice.pour(Vector2(16.0, 7.0), 0.3, 6.0)
	var pc := ice.cell_at(Vector2(16.0, 7.0))
	var pi := ice.index(pc.x, pc.y)
	var deep0 := ice.water[pi]
	var far := ice.index(ice.cell_at(Vector2(16.3, 7.0)).x, pc.y)
	check.call(ice.water[far] == 0.0, "the pour starts in its disc")
	for step in 60:
		ice.thermal(0.1, 0.0, 8.0)  # slab at 0: flow without freezing
	check.call(
		ice.water[far] > 0.0 and ice.water[pi] < deep0,
		(
			"water flowed 30 cm out (%.2f mm there, middle %.2f -> %.2f)"
			% [ice.water[far], deep0, ice.water[pi]]
		)
	)
	var rim := ice.index(ice.cell_at(Vector2(16.2, 7.0)).x, pc.y)
	check.call(ice.water[rim] >= 0.15, "a film clings behind the flow (%.2f mm)" % ice.water[rim])
	# snow has height: the blade must get under it to touch the ice
	_set_state(0)
	ice.flush()
	var snc := ice.cell_at(Vector2(8.0, 10.0))
	var sni := ice.index(snc.x, snc.y)
	var snow0 := ice.snow[sni]
	var ang0 := ice.ang[sni]
	ice.resurface(PASS_X0, PASS_X1, 9.0, 11.0, 0.0, 0.0, 2.0, 1.0)
	check.call(
		is_equal_approx(ice.snow[sni], snow0) and is_equal_approx(ice.ang[sni], ang0),
		"a blade above the snow touches nothing"
	)
	ice.resurface(PASS_X0, PASS_X1, 9.0, 11.0, 0.0, 0.0, 0.4, 1.0)
	check.call(
		ice.snow[sni] < snow0 and ice.snow[sni] > 0.3 and is_equal_approx(ice.ang[sni], ang0),
		"a blade in the snow shaves only snow (%.2f of %.2f)" % [ice.snow[sni], snow0]
	)
	ice.resurface(PASS_X0, PASS_X1, 9.0, 11.0, 0.0, 0.0, 0.0, 1.0)
	check.call(
		ice.snow[sni] == 0.0 and is_equal_approx(ice.ang[sni], 1.0),
		"a blade at the ice takes the snow and cuts"
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
	# a set cut takes the ice itself: clean ice gets thinner and the
	# shavings are what the conditioner carries
	_set_state(1)
	ice.flush()
	var thick0 := ice.thickness_at(Vector2(20.0, 8.0))
	var cut_took := ice.resurface(PASS_X0, PASS_X1, 7.0, 9.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5)
	check.call(
		cut_took > 0.0 and is_equal_approx(ice.thickness_at(Vector2(20.0, 8.0)), thick0 - 0.5),
		(
			"a 0.5 mm cut thinned clean ice (%.2f -> %.2f mm, shaved %.0f)"
			% [thick0, ice.thickness_at(Vector2(20.0, 8.0)), cut_took]
		)
	)
	ice.resurface(PASS_X0, PASS_X1, 7.0, 9.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5)
	check.call(
		is_equal_approx(ice.thickness_at(Vector2(20.0, 8.0)), thick0 - 1.0),
		"a second cut takes another 0.5 mm (%.2f)" % ice.thickness_at(Vector2(20.0, 8.0))
	)
	ice.flush()
	check.call(ice.remeshed > 600, "chunks re-meshed (%d)" % ice.remeshed)
	for id in [
		"zambelli_body", "zambelli_conditioner", "zambelli_auger", "zambelli_lift", "zambelli_wheel"
	]:
		var m := ObjectCatalog.mesh(id)
		check.call(m != null and m.get_surface_count() > 0, "%s has a mesh" % id)
	# the conditioner: the blade's shavings land in the trough under the
	# rows they came from, the auger walks them to the middle, the lift
	# takes them up into the tank, and the tank is dumped once it is clear
	_set_state(1)
	ice.flush()
	for again in 4:
		ice.pour(Vector2(8.0, 5.0), 0.3, 1.2)  # a bump at the +Z edge of lane z = 4
		ice.set_now()
	_machine.blade_mm = 0.0
	_begin_pass(4.0)
	_zamboni_step(4.0)
	var hi := 0
	for b in Zambelli.BINS:
		if _machine.trough[b] > _machine.trough[hi]:
			hi = b
	check.call(
		_machine.trough_m3() > 0.0 and hi > Zambelli.BINS * 0.6,
		"the shavings landed in the trough on the side they were cut (bin %d)" % hi
	)
	var trough0 := _machine.trough_m3()
	for step in 240:
		_machine._process(1.0 / 60.0)
	check.call(
		_machine.trough_m3() < trough0 * 0.5 and _machine.tank_m3 > 0.0,
		(
			"the augers carried the snow to the middle and up (%.3f -> %.3f L, tank %.3f L)"
			% [trough0 * 1000.0, _machine.trough_m3() * 1000.0, _machine.tank_m3 * 1000.0]
		)
	)
	_zamboni_step(60.0)  # to the end of the pass
	for step in 600:
		_machine._process(1.0 / 60.0)
		_process(1.0 / 60.0)
	check.call(
		_machine.tank_m3 == 0.0 and not _machine.auger_on, "the tank was dumped after the pass"
	)
	# the console: the levers, the handwheel and the valves drive the machine's state
	var ctl: ZambelliControls = _machine.controls
	var k_h := -1
	var k_blade := -1
	var k_flood := -1
	for i in ctl._controls.size():
		match ctl._controls[i].kind:
			ZambelliControls.Kind.AUGER_H:
				k_h = i
			ZambelliControls.Kind.BLADE:
				k_blade = i
			ZambelliControls.Kind.FLOOD:
				k_flood = i
	check.call(k_h >= 0 and k_blade >= 0 and k_flood >= 0, "the console's controls are registered")
	ctl.toggle(k_h)
	check.call(_machine.auger_on, "the horizontal auger's lever switches it on")
	ctl.toggle(k_h)
	check.call(not _machine.auger_on, "... and off")
	_machine.blade_mm = 0.0
	ctl.scroll(k_blade, 16.0)
	check.call(
		(
			is_equal_approx(_machine.blade_mm, -0.5)
			and ZambelliControls.turns_text(-0.5) == "1 TURN DOWN"
		),
		(
			"sixteen notches up is one turn clockwise, half a millimetre down (%s)"
			% ZambelliControls.turns_text(_machine.blade_mm)
		)
	)
	ctl.scroll(k_blade, -3.0)
	check.call(
		ZambelliControls.turns_text(_machine.blade_mm) == "13/16 TURNS DOWN",
		"the turns read in sixteenths (%s)" % ZambelliControls.turns_text(_machine.blade_mm)
	)
	ctl.scroll(k_blade, 200.0)
	check.call(is_equal_approx(_machine.blade_mm, -3.0), "the wheel stops at 3 mm down")
	# driving: a sweep on a heading off the axes cuts and feeds the auger
	_machine.global_position = ice.position + Vector3(20.0, 0.0, 12.0)
	_machine.rotation.y = -PI / 2 + 0.5
	_machine.cond_down = true
	_machine.lift = 1.0
	_machine.blade_mm = -1.0
	_machine.drive = 0
	_machine.settle()
	var before_drive := _machine.global_position
	var sweep_took := 0.0
	for step in 240:
		var sweep := _machine.drive_step(1.0 / 60.0, 1.0, 0.0, 0.3)
		if sweep.is_empty():
			continue
		var fwd := -_machine.global_transform.basis.z
		sweep_took += ice.resurface_sweep(
			_local(sweep[0]),
			_local(sweep[1]),
			_local(sweep[2]),
			_local(sweep[3]),
			0.0,
			0.0,
			atan2(fwd.z, fwd.x),
			1.0,
			Zambelli.BINS
		)
	check.call(
		_machine.global_position.distance_to(before_drive) > 2.0 and _machine.speed > 1.0,
		"the pedal moves the machine (%.1f m)" % _machine.global_position.distance_to(before_drive)
	)
	check.call(
		absf(_machine.rotation.y + PI / 2 - 0.5) > 0.1,
		"the wheel turns it (%.2f)" % _machine.rotation.y
	)
	check.call(sweep_took > 1000.0, "the sweep cuts the ice on the way (%.0f mm)" % sweep_took)
	var fed := 0.0
	for b in ice.shave_bins.size():
		fed += ice.shave_bins[b]
	check.call(
		fed > 0.0 and ice.shave_bins[0] > 0.0 and ice.shave_bins[41] > 0.0, "... across the blade"
	)
	check.call(
		ice.thickness_at(_local(_machine.to_global(Vector3(0.0, 0.0, 0.5)))) < 24.5,
		(
			"the lane behind it is cut (%.2f mm)"
			% ice.thickness_at(_local(_machine.to_global(Vector3(0.0, 0.0, 0.5))))
		)
	)
	_machine.speed = 0.0
	ctl.scroll(k_flood, 7.0)
	check.call(is_equal_approx(_machine.flood, 0.35), "seven notches open the flood valve 35%%")
	check.call(ZambelliControls.turns_text(0.0) == "FLUSH", "flush reads as flush")
	print("ice demo: %d chunks, %d re-meshes" % [ice.chunk_count(), ice.remeshed])
	if _fails == 0:
		print("ice_demo test: all passed")
	get_tree().quit(1 if _fails else 0)
