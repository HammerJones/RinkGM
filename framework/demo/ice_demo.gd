# gdlint:disable=max-file-lines
# (the scene's own self-test lives here with what it exercises; it is most of the file)
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
const HEAT_REFRESH := 2.0  # seconds between the heatmap's range reads
const BOARDS_TURN := 0.5  # radians of swing toward the boards' line per metre of push
const BOARDS_TURN_MAX := 0.02  # radians a frame, at most
const SKATE_START := Vector3(3.0, 0.05, 0.0)  # on the skates: centre ice, clear of the parked machine
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
const BOARD_H_CAP := 1.11  # the kit's cap rail on top, where the glass stands
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
const FLOOD_FULL_MM := 1.0  # the film the flood valve lays wide open: a litre a square metre, and it holds its edge
const MACHINE_W := Zambelli.BLADE_W  # the blade's width: the conditioner plus 6 in on the left
const FLOOD_BEHIND := Zambelli.WALL_Z  # the flood pipe this far behind the blade: a strip is cut dry, then flooded
const MACHINE_SPEED := 2.0  # m/s
const EDGER_LOOK := deg_to_rad(50.0)  # how far the head turns off the edger's line while pushing
const EDGER_SIDE := 0.42  # the edger's left side this far in from the boards when set against them
const SPRAY_CELLS := 2500  # columns the hose pours a frame, at most: the cone in strips
const RUNNER_M := 0.8  # the conditioner's runners: how far ahead of the blade they ride
const LEVEL_RATE_MM := 1.0  # the most the blade's level moves per metre of travel
const PASS_X0 := 2.0  # the pass runs end to end, clear of the end boards
const PASS_X1 := RINK.x - 2.0
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
var snow_level := 0.0  # the [ ] scale, 0..1
var hosing := false
var chipping := false
var hosed_l := 0.0
var slab_c := -9.0  # the pad: a brine rink's
var air_base := 8.0
var air_c := 8.0
var sim_t := 0.0
var heatmap := false  # H: the ice coloured by height, blue low .. red high
var goals := 0  # pucks into the net on the skates
var show_data := false  # F1: the readout lines and the key legend
var _footprint := Zambelli.outline()  # the machine's edge, for the boards
var _heat_t := 0.0  # seconds since the heatmap's range was read
var _machine: Zambelli
var _bay: ZamboniBay
var _hose: FireHose
var _edger: IceEdger
var _pusher: SnowPusher
var _net: HockeyNet
var _skater: DemoSkater
var _skates: Node3D  # the skates and stick on the bay floor
var _puck: DemoPuck
var _kit: Node3D  # the rink kit on show in the bay: board sections and glass
var _rink_pieces := {}  # kit id -> how many the rink's boards and glass use
var _edging := false  # at the edger's handles: the keys push it
var _spray_strip := 0  # which strip of the hose's cone this frame pours
var _aimed := -1  # the machine control under the dot
var _no_aim := false  # a screenshot of a control, without its glow
var _aboard := false  # the walker is in the seat and the keys drive the machine
var _chip_t := 0.0
var _stream: GPUParticles3D
var _env: WorldEnvironment
var _sun: DirectionalLight3D
var _zam := -1.0
var _level := NAN  # the blade's height over the base, mm, carried along the cut
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
	_bay = ZamboniBay.new()
	_bay.name = "Bay"
	_bay.build(RINK.x / 2 + BOARD_T, BOARD_H, BOARD_T, KICK_H, BOARD, KICK)
	add_child(_bay)
	_hose = FireHose.new()
	_hose.name = "FireHose"
	# on the bay's -z wall, the reel a metre up, its plate to the wall
	_hose.build(Vector3(RINK.x / 2 + BOARD_T + 3.0, 0.5, -ZamboniBay.BAY_W / 2 + 0.23), PI)
	add_child(_hose)
	_edger = IceEdger.new()
	_edger.name = "Edger"
	# parked in the bay, nose toward the doors
	_edger.position = Vector3(RINK.x / 2 + BOARD_T + 5.5, 0.0, 2.2)
	_edger.rotation.y = PI / 2
	add_child(_edger)
	_pusher = SnowPusher.new()
	_pusher.name = "SnowPusher"
	# on the bay's +z wall, across from the hose, its blade's face to the bay
	_pusher.build(Vector3(RINK.x / 2 + BOARD_T + 3.0, 0.45, ZamboniBay.BAY_W / 2 - 0.3), 0.0)
	add_child(_pusher)
	_net = HockeyNet.new()
	_net.name = "Net"
	_net.position = Vector3(RINK.x / 2 + BOARD_T + 7.0, 0.0, -2.4)
	_net.rotation.y = PI / 2  # its mouth toward the doors
	add_child(_net)
	_skates = _make_skates(Vector3(RINK.x / 2 + BOARD_T + 7.0, 0.0, -0.6))
	add_child(_skates)
	_puck = DemoPuck.new()
	_puck.name = "Puck"
	_puck.position = _skates.position + Vector3(0.3, 0.0, 0.45)  # by the skates until you are on them
	add_child(_puck)
	_kit = _kit_display()
	add_child(_kit)
	_skater = DemoSkater.new()
	_skater.name = "Skater"
	add_child(_skater)
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
	if not OS.get_cmdline_user_args().has("--windowed") and _no_screenshot_arg():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)  # Sean's ask
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
	hud.legend(
		(
			"[X] STATE  [ ] SNOW  [E] USE  [LMB] SPRAY  [RMB] CHIP  [WHEEL] ADJUST  "
			+ "[W S A D] DRIVE  [TAB] EDGER BLADE  [T] CLOCK  [B] BODY  [V] MACHINE  "
			+ "[H] HEATMAP  [CTRL] CROUCH  [F] FLY  [Z] ZOOM  [F1] DATA"
		)
	)
	_show_data(false)  # the readout and the key legend stay off until F1 (Sean)
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
	if heatmap:
		# the range follows the ice: re-read every couple of seconds
		_heat_t += dt
		if _heat_t >= HEAT_REFRESH:
			_heat_t = 0.0
			ice.heatmap_refresh()
	if _zam >= 0.0:
		_zamboni_step(sdt)
	elif _aboard:
		_drive(sdt)
	elif _edging:
		_push(sdt)
	elif _skater.active and walker:
		_skater.step(
			sdt,
			walker,
			ice,
			_local,
			_inside_the_sheet.bind(0.35),
			Input.is_key_pressed(KEY_W),
			Input.is_key_pressed(KEY_S)
		)
		_puck_step(sdt)
	if _pusher.held and walker:
		_shovel()
	if _aboard and walker:
		walker.global_position = _machine.to_global(Zambelli.SEAT)
	if _edging and walker:
		_stay_behind_the_edger()
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
		# the pass is over and the augers have cleared the snow: dump the
		# tank (the levers are the operator's: they stay where they are)
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
			if _aimed < 0 and _aboard:
				hud.extra_prompt = "[E] GET OUT"
			elif (
				_aimed < 0
				and not _hose.held
				and _edger.engine_aimed(cam.global_position, -cam.global_transform.basis.z)
			):
				hud.extra_prompt = "[E] %s THE EDGER" % ("STOP" if _edger.running else "START")
			elif _aimed < 0 and _edging:
				hud.extra_prompt = "[W S] PUSH   [A D] TURN   [WHEEL] CRANK   [TAB] BLADE   [E] LET GO"
			elif (
				_aimed < 0
				and not _hose.held
				and _edger.aimed(cam.global_position, -cam.global_transform.basis.z)
			):
				hud.extra_prompt = "[E] TAKE THE EDGER'S HANDLES"
			elif _aimed < 0 and _bay.aimed(cam.global_position, -cam.global_transform.basis.z):
				hud.extra_prompt = _bay.prompt()
			elif _aimed < 0 and _hose.aimed(cam.global_position, -cam.global_transform.basis.z):
				hud.extra_prompt = _hose.prompt()
			elif _aimed < 0 and _hose.held:
				hud.extra_prompt = "[LMB] SPRAY   [WHEEL] MIST .. JET   [E] HANG IT UP"
			elif _aimed < 0 and _pusher.held:
				hud.extra_prompt = (
					"[W] PUSH   [LMB] SET THE SNOW DOWN   [RMB] %s   [E] HANG IT UP"
					% ("LOWER" if _pusher.raised else "LIFT")
				)
			elif _aimed < 0 and _pusher.aimed(cam.global_position, -cam.global_transform.basis.z):
				hud.extra_prompt = _pusher.prompt()
			elif _aimed < 0 and _net.carried:
				hud.extra_prompt = "[E] SET THE NET DOWN"
			elif _aimed < 0 and _net.aimed(cam.global_position, -cam.global_transform.basis.z):
				hud.extra_prompt = _net.prompt()
			elif _aimed < 0 and _skater.active:
				hud.extra_prompt = "[W] STRIDE   [S] STOP   [MOUSE] STEER   [LMB] SHOOT   [E] SKATES OFF"
			elif _aimed < 0 and _skates_aimed(cam.global_position, -cam.global_transform.basis.z):
				hud.extra_prompt = "[E] SKATE"

		if hosing and _hose.held:
			_spray(dt)
		_stream.emitting = hosing and _hose.held
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
				"   UNDER THE DOT: ICE %.2f MM THICK AT %.1f C, SNOW %.2f MM, WATER %.2f MM"
				% [
					ice.thickness_at(p),
					ice.ice_temp_at(p, slab_c, air_c),
					ice.snow_at(p),
					ice.water_at(p)
				]
			)
		var line1 := (
			"STATE %s   PAINT UNDER %.0f MM   SLAB %.1f C   AIR %.1f C   CLOCK x%d%s   T+%s   WET / COOLING %d   DIRTY %d / %d"
			% [
				STATES[state][0],
				ice.base_mm,
				slab_c,
				air_c,
				int(SCALES[scale_i]),
				("   INSTANT FREEZE" if instant else "") + _heat_text(),
				_clock(sim_t),
				ice.wet_cells,
				ice.dirty_count(),
				ice.chunk_count()
			]
		)
		var line2 := (
			"BLADE %s (%+.2f MM)   FLOOD %d%%   WASH %d%%   RAG %s   SHAVED %.0f MM   FIRE HOSE %s   HOSED %.0f L%s"
			% [
				ZambelliControls.turns_text(_machine.blade_mm),
				_machine.blade_mm,
				roundi(_machine.flood * 100.0),
				roundi(_machine.wash * 100.0),
				RAGS[rag_i],
				shaved_mm,
				_hose.pattern_text() if _hose.held else "ON THE REEL",
				hosed_l,
				under
			]
		)
		var line3 := ""
		if _machine:
			line3 = _machine_line()
		if _pusher.held:
			line3 += "   SNOW PUSHER %s" % _pusher.load_text()
		if _skater.active:
			line3 += "   " + _skater.state_text() + "   GOALS %d" % goals
		if _edging:
			line3 += "   " + _edger.state_text()
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


## The fire hose, while LMB is held with it in hand: FireHose.LPS of
## water a second, landing where you look within the pattern's reach (a
## mist falls short and wets a wide disc, a jet carries and wets a small
## one), and the stream of drops to match.
func _spray(dt: float, cam: Camera3D = null) -> void:
	if cam == null:
		cam = walker.camera
	var dir := -cam.global_transform.basis.z
	var hand := (
		cam.global_position + dir * 0.45 + cam.global_transform.basis.x * 0.22 - Vector3(0, 0.2, 0)
	)
	var reach := _hose.reach()
	var at: Variant = _aim(cam)
	if at == null or hand.distance_to(at) > reach:
		# the water falls short of where you look: down at the end of its carry
		if dir.y > 0.5:
			return
		var land: Vector3 = hand + dir * reach
		land.y = 0.0
		at = land
	var dist: float = hand.distance_to(at)
	var width := 0.3 + 2.0 * dist * tan(_hose.cone())
	var litres := FireHose.LPS * dt
	hosed_l += litres
	var area := PI * (width * 0.5) * (width * 0.5)
	var mm := litres * 0.001 / area * 1000.0  # L -> m3 -> m -> mm
	var wander := Vector2(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05))
	# a wide cone is thousands of columns, and every one poured is a
	# column the sheet rebuilds: the cone is poured a strip a frame, its
	# share of the water each, scanning down it (Sean: the hose lagged)
	var land_c := ice.cell_at(_local(at) + wander)
	var r_cells := int(ceil(width * 0.5 / ice.cell))
	var strips := maxi(1, ceili(float(r_cells * r_cells * 4) / SPRAY_CELLS))
	_spray_strip = (_spray_strip + 1) % strips
	var rows := ceili(float(2 * r_cells + 1) / strips)
	var z0 := land_c.y - r_cells + _spray_strip * rows
	ice.pour(
		_local(at) + wander,
		width,
		mm * strips,
		Rect2i(land_c.x - r_cells, z0, 2 * r_cells + 1, rows)
	)
	if _stream == null:
		return
	_stream.global_position = hand
	var to: Vector3 = at - hand
	var mat: ParticleProcessMaterial = _stream.process_material
	# a jet crosses in under a second, a mist drifts
	var t := clampf(dist / 18.0, 0.3, 0.9)
	var v := Vector3(to.x / t, to.y / t + 0.5 * 9.8 * t, to.z / t)
	mat.direction = v.normalized()
	mat.initial_velocity_min = v.length() * 0.9
	mat.initial_velocity_max = v.length() * 1.1
	mat.spread = rad_to_deg(_hose.cone())
	mat.scale_min = lerpf(0.25, 0.2, _hose.pattern)
	mat.scale_max = lerpf(0.45, 0.35, _hose.pattern)
	_stream.amount_ratio = 1.0
	if WorldSound.wanted():
		WorldSound.play(self, "ball_bounce_2", at, -16.0, 0.6, 3.0, 35.0, "stop_spray")


func _make_stream() -> GPUParticles3D:
	var ps := GPUParticles3D.new()
	ps.amount = 2000
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
	pass_z = clampf(z, -Zambelli.BLADE_X0, RINK.y - Zambelli.BLADE_X1)
	shaved_mm = 0.0
	_level = NAN
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
	# the machine faces +X: its left (BLADE_X0) is the sheet's -Z
	var z0 := pass_z + Zambelli.BLADE_X0
	var z1 := pass_z + Zambelli.BLADE_X1
	var ahead: Array[Vector2] = [
		Vector2(x1, z0), Vector2(x1 + RUNNER_M, z0), Vector2(x1 + RUNNER_M, z1), Vector2(x1, z1)
	]
	var swept: Array[Vector2] = [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]
	_follow(ahead, swept, x1 - x0)
	if not is_nan(_level):
		# the blade cuts the strip dry; the flood pipe, FLOOD_BEHIND behind
		# it, lays the film on the strip it cut that long ago
		shaved_mm += ice.resurface(x0, x1, z0, z1, 0.0, rag_i / 2.0, _level, 0.0, 0.0)
		var f0 := maxf(x0 - FLOOD_BEHIND, PASS_X0)
		var f1 := x1 - FLOOD_BEHIND
		if f1 > f0:
			ice.lay_film(f0, f1, z0, z1, film, rag_i / 2.0)
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
	var z0 := pass_z + Zambelli.BLADE_X0
	var cell_m3 := ice.cell * ice.cell * 0.001  # mm of a cell -> m³
	for r in ice.shave_rows.size():
		var mm := ice.shave_rows[r]
		if mm <= 0.0:
			continue
		var zm := (ice.shave_z0 + r + 0.5) * ice.cell
		var b := clampi(int((zm - z0) / MACHINE_W * Zambelli.BINS), 0, Zambelli.BINS - 1)
		bins[b] += mm * cell_m3
	return bins


## The blade's level for the next strip: the handwheel's setting below
## the ice the conditioner's runners ride, read `ahead` of the blade
## (the strip itself when the runners are off the sheet), and eased
## there at LEVEL_RATE_MM a metre over `dist`. A level set from each
## strip's own mean left a ridge across the lane at every step, as if
## the blade skipped; carried along, the cut is one continuous plane.
func _follow(ahead: Array[Vector2], swept: Array[Vector2], dist: float) -> void:
	var ride := ice.mean_solid(ahead)
	if is_nan(ride):
		ride = ice.mean_solid(swept)
	if is_nan(ride):
		return
	var target := ride + _machine.blade_mm
	if is_nan(_level):
		_level = target
	else:
		_level = move_toward(_level, target, LEVEL_RATE_MM * dist)


## A frame at the wheel: W is the gas pedal and moves the machine the
## way the drive select lever on the console is set (F, N or R), S is
## always the brake, A and D steer. The conditioner resurfaces whatever
## the blade sweeps, on any heading; the boards push the nose back in
## and it slides along them.
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
	if not _along_the_boards():
		_machine.global_transform = before
		return
	# the blade's edge where the machine is now, after any push off the boards
	sweep[2] = _machine.to_global(Vector3(Zambelli.BLADE_X0, 0.0, 0.0))
	sweep[3] = _machine.to_global(Vector3(Zambelli.BLADE_X1, 0.0, 0.0))
	if not _machine.is_down():
		_level = NAN  # the conditioner is up: the next cut finds its own level
		return
	var film := FLOOD_FULL_MM * _machine.flood
	var fwd := -_machine.global_transform.basis.z
	var a0 := _local(sweep[0])
	var a1 := _local(sweep[1])
	var b0 := _local(sweep[2])
	var b1 := _local(sweep[3])
	var step := (b0 - a0 + b1 - a1) / 2.0
	var on := step.normalized() * RUNNER_M
	_follow([b0, b0 + on, b1 + on, b1], [a0, a1, b1, b0], step.length())
	if is_nan(_level):
		return
	var took := ice.resurface_sweep(
		a0,
		a1,
		b0,
		b1,
		0.0,
		rag_i / 2.0,
		atan2(fwd.z, fwd.x),
		IceSheet.NO_CUT,
		Zambelli.BINS,
		_level
	)
	# the flood pipe, behind the blade, sweeps its own quad
	var half := Zambelli.COND_W / 2
	ice.lay_film_sweep(
		_local(before * Vector3(-half, 0.0, FLOOD_BEHIND)),
		_local(before * Vector3(half, 0.0, FLOOD_BEHIND)),
		_local(_machine.to_global(Vector3(-half, 0.0, FLOOD_BEHIND))),
		_local(_machine.to_global(Vector3(half, 0.0, FLOOD_BEHIND))),
		film,
		rag_i / 2.0
	)
	shaved_mm += took
	if took > 0.0:
		var bins := ice.shave_bins.duplicate()
		var cell_m3 := ice.cell * ice.cell * 0.001
		for b in bins.size():
			bins[b] *= cell_m3
		_machine.feed(bins)


## The boards, with the bumper's roller: a point of the machine's
## footprint (`Zambelli.outline()`: the hull and the wider conditioner,
## right at the model's skin, no margin, so it rides flush and the nose
## reaches into a corner) that would go past them (the straights, or the
## corner arcs) is pushed back in and the machine slides along, losing
## some speed to the rub; only a run straight at them stops it. Returns
## false for that stop.
func _along_the_boards() -> bool:
	var push := Vector2.ZERO
	var in_bay := _local(_machine.global_position).x > RINK.x
	var at := Vector2.ZERO  # the point pushed furthest
	var at_c := Vector2.ZERO
	var deepest := 0.0
	for c in _footprint:
		var p := _local(_machine.to_global(Vector3(c.x, 0.0, c.y)))
		var d := _inside_the_boards(p, in_bay, 0.0) - p
		if absf(d.x) > absf(push.x):
			push.x = d.x
		if absf(d.y) > absf(push.y):
			push.y = d.y
		if d.length_squared() > deepest:
			deepest = d.length_squared()
			at = p
			at_c = c
	if push == Vector2.ZERO:
		return true
	var fwd := -_machine.global_transform.basis.z
	var going := Vector2(fwd.x, fwd.z) * signf(_machine.speed)
	var square := -push.normalized().dot(going)  # 1 head on, 0 brushing along
	if square > 0.97:
		_machine.speed = 0.0
		if hud:
			hud.toast("THE BOARDS")
		return false
	# the push turns the machine as well as moving it: the boards hold
	# the point that touches and the machine swings about that point
	# toward their line, the faster the harder it leans on them (a nose
	# on the boards stays put and the rear comes in, Sean's ask), and the
	# push itself is a slide in
	var n := push.normalized()
	var tangent := Vector2(-n.y, n.x)
	if tangent.dot(going) < 0.0:
		tangent = -tangent
	var fwd2 := Vector2(fwd.x, fwd.z)
	var toward := fwd2.y * tangent.x - fwd2.x * tangent.y  # a +y turn swings the nose this way
	var turn := signf(toward) * minf(BOARDS_TURN * push.length(), BOARDS_TURN_MAX)
	if absf(toward) > 0.002 and turn != 0.0:
		_machine.rotation.y += turn
		var at_now := _local(_machine.to_global(Vector3(at_c.x, 0.0, at_c.y)))
		_machine.global_position += Vector3(at.x - at_now.x, 0.0, at.y - at_now.y)
		# what the turn left to push, read again
		push = Vector2.ZERO
		for c in _footprint:
			var p := _local(_machine.to_global(Vector3(c.x, 0.0, c.y)))
			var d := _inside_the_boards(p, in_bay, 0.0) - p
			if absf(d.x) > absf(push.x):
				push.x = d.x
			if absf(d.y) > absf(push.y):
				push.y = d.y
	_machine.global_position += Vector3(push.x, 0.0, push.y)
	# a bump slides and keeps most of its speed; the squarer the hit the
	# more the boards take, a frame at a time while it leans on them (a
	# brush loses a fifth a second, a square shove about half: Sean asked
	# for a lighter penalty than the first cut)
	_machine.speed *= lerpf(0.9985, 0.985, square)
	return true


## The nearest point to `p` (sheet metres) a hand's width inside the
## boards: the straights, and the corner arcs of CORNER_R. With the bay
## doors open the doorway is a throat from the sheet onto the bay's pad:
## a machine on the sheet (`in_bay` false) may be in the sheet or the
## throat, one on the pad in the bay or the throat, so the only way
## between them is through the doors.
func _inside_the_boards(p: Vector2, in_bay := false, margin := 0.1) -> Vector2:
	var q := _inside_the_sheet(p, margin)
	if _bay == null or _bay.open < 0.9:
		return q
	var mid := RINK.y / 2
	var half := ZamboniBay.DOOR_W / 2 - margin
	var pad_x1 := RINK.x + BOARD_T + ZamboniBay.BAY_D - margin
	# the throat: the doorway's width, run from a little inside the boards to the back wall
	var throat := Vector2(clampf(p.x, RINK.x - 3.0, pad_x1), clampf(p.y, mid - half, mid + half))
	if in_bay:
		var bay_half := ZamboniBay.BAY_W / 2 - margin
		q = Vector2(
			clampf(p.x, RINK.x + BOARD_T + margin, pad_x1),
			clampf(p.y, mid - bay_half, mid + bay_half)
		)
	if throat.distance_squared_to(p) < q.distance_squared_to(p):
		return throat
	return q


## How far `p` (sheet metres) is inside the boards' corner arc when it is
## in a corner, else INF.
func _corner_gap(p: Vector2) -> float:
	var cx := (
		CORNER_R if p.x < CORNER_R else (RINK.x - CORNER_R if p.x > RINK.x - CORNER_R else -1.0)
	)
	var cy := (
		CORNER_R if p.y < CORNER_R else (RINK.y - CORNER_R if p.y > RINK.y - CORNER_R else -1.0)
	)
	if cx < 0.0 or cy < 0.0:
		return INF
	return CORNER_R - (p - Vector2(cx, cy)).length()


func _inside_the_sheet(p: Vector2, margin := 0.1) -> Vector2:
	var q := Vector2(clampf(p.x, margin, RINK.x - margin), clampf(p.y, margin, RINK.y - margin))
	var cx := (
		CORNER_R if q.x < CORNER_R else (RINK.x - CORNER_R if q.x > RINK.x - CORNER_R else -1.0)
	)
	var cy := (
		CORNER_R if q.y < CORNER_R else (RINK.y - CORNER_R if q.y > RINK.y - CORNER_R else -1.0)
	)
	if cx < 0.0 or cy < 0.0:
		return q
	var c := Vector2(cx, cy)
	var v := q - c
	if v.length() > CORNER_R - margin:
		q = c + v.normalized() * (CORNER_R - margin)
	return q


## The resurfacer (framework/demo/zambelli.gd), parked by the end boards
## with the conditioner up until a pass; it faces +X, the way a pass runs.
func _make_machine() -> Zambelli:
	var z := Zambelli.new()
	z.name = "Zambelli"
	z.rotation.y = -PI / 2
	z.position = ice.position + Vector3(RINK.x / 2, 0.0, RINK.y / 2)  # centre ice, facing down the sheet
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


## At the edger's handles: the keys push it, the walker rides behind it.
## The skates and a stick on the bay floor by the net: the skate prop
## twice (Sean's skate model) and a stick from primitives.
func _make_skates(at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "Skates"
	n.position = at
	for k in 2:
		var sk := MeshInstance3D.new()
		sk.mesh = ObjectCatalog.mesh("hockey_skate")
		sk.material_override = PropMaterial.shared()
		sk.position = Vector3(0.0, 0.0, -0.1 + 0.2 * k)
		sk.rotation.y = PI / 2
		n.add_child(sk)
	# the game's stick (StickProps) lying flat beside them, blade toward the doors
	var stick := MeshInstance3D.new()
	stick.mesh = StickProps.stick_mesh(StickProps.variant("team", -1, false, "black"))
	stick.position = Vector3(0.45, 0.02, 0.25)
	stick.rotation = Vector3(-PI / 2, PI + 0.2, 0.0)
	n.add_child(stick)
	return n


## The rink kit on show in the bay: the straight sections and the eighth
## corner along the +z wall (a 6 ft glass on the 2 m board), the 4 m
## board and the 8 ft glass against the back wall, the quarter corner on
## the -z wall. Each stands on the floor, its ice side into the bay.
func _kit_display() -> Node3D:
	var n := Node3D.new()
	n.name = "RinkKit"
	var x0 := RINK.x / 2 + BOARD_T  # the hinge line
	var back := x0 + ZamboniBay.BAY_D - 0.07
	var side := ZamboniBay.BAY_W / 2 - 0.08
	var pieces := [
		["board_1m", Vector3(x0 + 4.6, 0.0, side), 0.0],
		["board_2m", Vector3(x0 + 6.2, 0.0, side), 0.0],
		["board_curve_eighth", Vector3(x0 + 8.1, 0.0, side - 0.12), 0.0],
		["board_4m", Vector3(back, 0.0, -1.8), PI / 2],
		["board_curve_quarter", Vector3(x0 + 6.6, 0.0, -side + 0.15), PI],
	]
	for p in pieces:
		var b := RinkKit.board(p[0])
		b.position = p[1]
		b.rotation.y = p[2]
		n.add_child(b)
	var g6 := RinkKit.glass("glass_4x6")
	g6.position = Vector3(x0 + 6.2, 1.11, side)  # on the 2 m board's cap
	n.add_child(g6)
	var g8 := RinkKit.glass("glass_4x8")
	g8.position = Vector3(back, 0.0, 1.0)
	g8.rotation.y = PI / 2
	n.add_child(g8)
	return n


func _skates_aimed(origin: Vector3, dir: Vector3) -> bool:
	if _skater.active or _skates == null:
		return false
	var to := _skates.global_position + Vector3(0.3, 0.15, 0.0) - origin
	var t := to.dot(dir)
	if t < 0.0 or t > 3.2:
		return false
	return (to - dir * t).length() < 0.7


## On the skates: out to centre ice, driven by the skater. The net stays
## wherever it was carried (it is set down first if it is in hand).
func _skates_on() -> void:
	if _net.carried:
		_net.set_down()
	if _pusher.held:
		_set_snow_down()
		_pusher.hang()
	walker.driven = true
	walker.set_noclip(false)
	# centre ice, a stride past the dot so the parked resurfacer is not in the way
	walker.global_position = SKATE_START
	walker.face(PI / 2)  # down the ice, toward the bay end
	walker.camera.rotation.x = -0.15
	_skater.start(walker)
	# a puck ahead on the ice
	_puck.live = true
	_puck.vel = Vector2.ZERO
	_puck.at = _local(SKATE_START) + Vector2(3.0, 0.3)
	_place_puck()


## The data on screen (the three readout lines and the key legend) shown
## or hidden; the prompts and toasts stay either way.
func _show_data(on: bool) -> void:
	show_data = on
	if hud.readout_label:
		hud.readout_label.visible = on
	if hud.legend_label:
		hud.legend_label.visible = on


func _skates_off() -> void:
	_skater.stop_skating()
	walker.driven = false
	# the puck goes back to the bay with the skates
	_puck.live = false
	_puck.vel = Vector2.ZERO
	_puck.position = _skates.position + Vector3(0.3, 0.0, 0.45)


func _place_puck() -> void:
	_puck.position = ice.global_position + Vector3(_puck.at.x, 0.0, _puck.at.y)


## The puck on the ice this step: carried on the blade when it is under it,
## sliding and bouncing off the boards otherwise, held in the net once in.
func _puck_step(dt: float) -> void:
	if not _puck.live:
		return
	var in_net := _net.holds(_puck.position)
	if in_net:
		_puck.vel = Vector2.ZERO
	else:
		_puck.carry(_local(_skater.blade_world()), _skater.vel)
		_puck.step(dt, _inside_the_sheet.bind(DemoPuck.RADIUS))
		_place_puck()
		if _net.holds(_puck.position):
			goals += 1
			_puck.vel = Vector2.ZERO
			if hud:
				hud.toast("GOAL! %d" % goals)


## LMB on the skates: the puck off the blade, hard, where you face.
func _shoot() -> void:
	if not _puck.live or _net.holds(_puck.position):
		return
	var yaw := walker.rotation.y
	var face := Vector2(-sin(yaw), -cos(yaw))
	if _puck.shoot(_local(_skater.blade_world()), face):
		_puck.step(0.0, _inside_the_sheet.bind(DemoPuck.RADIUS))
		_place_puck()


## The snow pusher pushed: the blade's sweep since last frame scoops the
## snow in its path into the load; the surplus past the blade's capacity
## rolls off its ends; pulled back, the load is left where the blade was.
func _shovel() -> void:
	var ends := _pusher.blade_ends()
	var a0 := _local(ends[0])
	var a1 := _local(ends[1])
	if _pusher.raised or _pusher.last0 == Vector2.INF:
		_pusher.last0 = a0
		_pusher.last1 = a1
		return
	var mid := (a0 + a1) / 2
	var last_mid := (_pusher.last0 + _pusher.last1) / 2
	var moved := mid - last_mid
	if moved.length() < 0.003:
		return
	var fwd := -walker.global_transform.basis.z
	var along := moved.dot(Vector2(fwd.x, fwd.z))
	if along > 0.0:
		var got := ice.scoop(_pusher.last0, _pusher.last1, a0, a1)
		var load := _pusher.load + got
		if load > SnowPusher.CAPACITY:
			var spill := load - SnowPusher.CAPACITY
			ice.mound(a0, 0.3, spill / 2)
			ice.mound(a1, 0.3, spill / 2)
			load = SnowPusher.CAPACITY
		_pusher.set_load(load)
	elif _pusher.load > 0.0:
		ice.mound(last_mid, SnowPusher.BLADE_W, _pusher.load)
		_pusher.set_load(0.0)
	_pusher.last0 = a0
	_pusher.last1 = a1


## The load set down ahead of the blade as a mound.
func _set_snow_down() -> void:
	if _pusher.load <= 0.0:
		return
	var ends := _pusher.blade_ends()
	var mid := (_local(ends[0]) + _local(ends[1])) / 2
	var fwd := -walker.global_transform.basis.z
	ice.mound(mid + Vector2(fwd.x, fwd.z) * 0.45, SnowPusher.BLADE_W, _pusher.load)
	_pusher.set_load(0.0)
	_pusher.last0 = Vector2.INF


## Cells with a gouge in a square `size` across at `at` (tests).
func _count_gouged(at: Vector2, size: float) -> int:
	var c := ice.cell_at(at)
	var r := int(size / 2 / ice.cell)
	var n := 0
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if ice.is_ice(c.x + dx, c.y + dz) and ice.gouge[ice.index(c.x + dx, c.y + dz)] > 0.05:
				n += 1
	return n


func _take_the_handles() -> void:
	_edging = true
	walker.set_noclip(true)
	walker.driven = true
	walker.global_position = _edger.to_global(IceEdger.HANDLES)
	walker.face(_edger.rotation.y)
	walker.camera.rotation.x = -0.5


## Keeps the walker square behind the edger: its heading follows the
## machine as it turns (so A and D turn you with it, and a push always
## goes straight down its line), and the mouse looks around only within
## `EDGER_LOOK` of dead ahead, the way you can turn your head but not
## your hands on the handles.
func _stay_behind_the_edger() -> void:
	walker.global_position = _edger.to_global(IceEdger.HANDLES)
	var off := wrapf(walker.rotation.y - _edger.rotation.y, -PI, PI)
	walker.face(_edger.rotation.y + clampf(off, -EDGER_LOOK, EDGER_LOOK))


func _let_go() -> void:
	_edging = false
	_edger.speed = 0.0
	walker.driven = false
	walker.set_noclip(false)
	walker.global_position = _edger.to_global(IceEdger.HANDLES + Vector3(0.0, 0.0, 0.6))


func _push(sdt: float) -> void:
	_push_with(
		sdt,
		(
			(1.0 if Input.is_key_pressed(KEY_W) else 0.0)
			- (1.0 if Input.is_key_pressed(KEY_S) else 0.0)
		),
		(
			(1.0 if Input.is_key_pressed(KEY_A) else 0.0)
			- (1.0 if Input.is_key_pressed(KEY_D) else 0.0)
		)
	)


## A step of the edger: pushed, kept inside the boards by its deck's
## corners, right at the boards (no margin: it has to cut flush along
## them) and sliding along them with nothing lost but a push straight
## into them, the blade cutting the path the disc's centre took.
func _push_with(sdt: float, push: float, turn: float) -> void:
	var path := _edger.step(sdt, push, turn)
	var in_bay := _local(_edger.global_position).x > RINK.x
	var shove := Vector2.ZERO
	for c: Vector3 in [
		Vector3(-IceEdger.DECK_HALF_W, 0.0, IceEdger.DECK_FRONT),
		Vector3(IceEdger.DECK_HALF_W, 0.0, IceEdger.DECK_FRONT),
		Vector3(-IceEdger.DECK_HALF_W, 0.0, IceEdger.DECK_BACK),
		Vector3(IceEdger.DECK_HALF_W, 0.0, IceEdger.DECK_BACK)
	]:
		var p := _local(_edger.to_global(c))
		var d := _inside_the_boards(p, in_bay, 0.0) - p
		if absf(d.x) > absf(shove.x):
			shove.x = d.x
		if absf(d.y) > absf(shove.y):
			shove.y = d.y
	if shove != Vector2.ZERO:
		_edger.global_position += Vector3(shove.x, 0.0, shove.y)
		var fwd := -_edger.global_transform.basis.z
		var going := Vector2(fwd.x, fwd.z) * signf(_edger.speed)
		if -shove.normalized().dot(going) > 0.95:
			_edger.speed = 0.0  # straight into them
		if path.size() == 2:
			path[1] += Vector3(shove.x, 0.0, shove.y)
	# round a corner the deck's ends sit on the arc and its middle stands
	# off it (4 cm on this deck and radius), so there the lane reaches
	# out to the boards past the rim (Sean: a cut outside the model's
	# size is fine in the curves, flush is what matters)
	var rim := _local(_edger.to_global(Vector3(-IceEdger.DECK_HALF_W, 0.0, IceEdger.BLADE_Z)))
	var gap := _corner_gap(rim)
	_edger.edge_over = (
		IceEdger.EDGE_OVER if gap == INF else clampf(gap + 0.01, IceEdger.EDGE_OVER, 0.09)
	)
	if path.size() == 2:
		var took := _edger.cut(ice, _local(path[0]), _local(path[1]))
		shaved_mm += took


## The walker at `eye`, looking at `target` (noclip).
func _look_at(eye: Vector3, target: Vector3) -> void:
	walker.set_noclip(true)
	walker.global_position = eye - Vector3(0.0, FirstPerson.EYE, 0.0)
	var d := target - eye
	walker.face(atan2(-d.x, -d.z))
	walker.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _no_screenshot_arg() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screenshot="):
			return false
	return true


func _local(p: Vector3) -> Vector2:
	var l := p - ice.global_position
	return Vector2(l.x, l.z)


## Where the view line meets the ice plane, or null when it does not.
func _aim(cam: Camera3D = null) -> Variant:
	if cam == null:
		cam = walker.camera
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
## The heatmap on or off: the ice's colour by height, its range read now.
func set_heatmap(on: bool) -> void:
	heatmap = on
	_heat_t = 0.0
	ice.heatmap(on)


func _heat_text() -> String:
	if not heatmap:
		return ""
	var r := ice.height_range() / (0.001 * ice.height_scale)
	return "   HEATMAP %.2f .. %.2f MM" % [r.x, r.y]


func _unhandled_input(event: InputEvent) -> void:
	if walker == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_X:
				_set_state(state + 1)
				hud.toast("STATE: %s" % STATES[state][0])
			KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
				# how snowed up: a sliding scale, the snow laid where it collects
				snow_level = clampf(
					snow_level + (0.1 if event.keycode == KEY_BRACKETRIGHT else -0.1), 0.0, 1.0
				)
				ice.snow_level(snow_level)
				hud.toast("SNOWED UP %d%%" % int(round(snow_level * 100.0)))
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
			KEY_E:
				if _aimed >= 0 and _machine.controls.kind_of(_aimed) == ZambelliControls.Kind.SEAT:
					_at_the_controls()
					(
						hud
						. toast(
							"IN THE SEAT: [W] GAS (DRIVE SELECT F N R)  [S] BRAKE  [A D] STEER  [E] GET OUT"
						)
					)
				elif _aimed >= 0:
					_machine.controls.toggle(_aimed)
					hud.toast(_machine.controls.prompt(_aimed).get_slice("   [", 0))
				elif _aboard:
					_off_the_machine()
					hud.toast("OFF THE MACHINE")
				elif (
					not _hose.held
					and _edger.engine_aimed(
						walker.camera.global_position, -walker.camera.global_transform.basis.z
					)
				):
					_edger.toggle_engine()
					hud.toast("THE EDGER %s" % ("RUNS" if _edger.running else "IS OFF"))
				elif _edging:
					_let_go()
					hud.toast("OFF THE EDGER")
				elif _bay.aimed(
					walker.camera.global_position, -walker.camera.global_transform.basis.z
				):
					_bay.toggle()
					hud.toast("THE BAY DOORS SWING %s" % ("OPEN" if _bay.want_open else "SHUT"))
				elif _hose.aimed(
					walker.camera.global_position, -walker.camera.global_transform.basis.z
				):
					_hose.take(walker.camera)
					hud.toast("THE FIRE HOSE: [LMB] SPRAY   [WHEEL] MIST .. JET")
				elif (
					not _hose.held
					and _edger.aimed(
						walker.camera.global_position, -walker.camera.global_transform.basis.z
					)
				):
					_take_the_handles()
					hud.toast("THE EDGER: [W S] PUSH   [A D] TURN   [WHEEL] CRANK   [TAB] BLADE")
				elif _hose.held:
					_hose.hang()
					hosing = false
					hud.toast("THE HOSE IS BACK ON THE REEL")
				elif _pusher.held:
					_set_snow_down()
					_pusher.hang()
					hud.toast("THE SNOW PUSHER IS BACK ON THE WALL")
				elif _pusher.aimed(
					walker.camera.global_position, -walker.camera.global_transform.basis.z
				):
					_pusher.take(walker)
					hud.toast("THE SNOW PUSHER: WALK INTO SNOW, [LMB] SET IT DOWN, [RMB] LIFT")
				elif _net.carried:
					_net.set_down()
					hud.toast("THE NET IS DOWN")
				elif _net.aimed(
					walker.camera.global_position, -walker.camera.global_transform.basis.z
				):
					_net.carry(walker)
					hud.toast("CARRYING THE NET: [E] SETS IT DOWN")
				elif _skater.active:
					_skates_off()
					hud.toast("SKATES OFF")
				elif _skates_aimed(
					walker.camera.global_position, -walker.camera.global_transform.basis.z
				):
					_skates_on()
					hud.toast("ON THE ICE: [W] STRIDE  [S] STOP  [MOUSE] STEER  [E] SKATES OFF")
			KEY_TAB:
				if _edging:
					_edger.toggle_blade()
					hud.toast(
						(
							"EDGER BLADE %s"
							% ("DOWN AT %+.1f MM" % _edger.level_mm if _edger.blade_down else "UP")
						)
					)
			KEY_T:
				scale_i = (scale_i + 1) % SCALES.size()
				hud.toast("CLOCK x%d" % int(SCALES[scale_i]))
			KEY_F1:
				_show_data(not show_data)
				hud.toast("DATA %s" % ("ON" if show_data else "OFF"))
			KEY_H:
				set_heatmap(not heatmap)
				hud.toast(
					"HEATMAP %s" % ("ON: BLUE LOW, GREEN MID, RED HIGH" if heatmap else "OFF")
				)
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
			elif _hose.held:
				# the nozzle's pattern (the Interactor has the wheel while a prop is held)
				_hose.scroll(up)
				hud.toast("FIRE HOSE: %s" % _hose.pattern_text())
			elif _edging:
				# the crank: counter-clockwise lowers the blade
				_edger.crank_notch(up)
				hud.toast(
					(
						"CRANK %s: BLADE %+.1f MM%s"
						% [
							"CLOCKWISE" if up else "COUNTER-CLOCKWISE",
							_edger.level_mm,
							"" if _edger.blade_down else " (RAISED)"
						]
					)
				)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if _pusher.held:
				_set_snow_down()
			elif _skater.active:
				_shoot()
			else:
				hosing = true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if _pusher.held:
				_pusher.toggle_raise()
				hud.toast("THE BLADE IS %s" % ("UP" if _pusher.raised else "ON THE ICE"))
			else:
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


## The boards: the rink kit's sections (RinkKit, tools/propgen/rink_kit.py)
## laid along the sides and ends, four quarter-corner curves round each
## corner, and the 6 ft glass on the cap all the way round (Sean). The
## collision stays the analytic boxes the walker and the machine slide
## along: straight runs and the corners as arcs of short segments.
## Positions are in world space (the sheet's centre is the origin).
func _boards(shell: StaticBody3D) -> void:
	var hx := RINK.x / 2
	var hz := RINK.y / 2
	var t := BOARD_T / 2
	var kit := Node3D.new()
	kit.name = "Boards"
	add_child(kit)
	for s in [
		[Vector3(0, 0, -hz - t), RINK.x - 2 * CORNER_R, PI],
		[Vector3(0, 0, hz + t), RINK.x - 2 * CORNER_R, 0.0],
		[Vector3(-hx - t, 0, 0), RINK.y - 2 * CORNER_R, -PI / 2],
	]:
		_board(shell, s[0], s[1], s[2])
		_board_run(kit, s[0], s[1], s[2])
	# the +X end: the straight is split around the bay doorway
	var side := (RINK.y - 2 * CORNER_R - ZamboniBay.DOOR_W) / 2
	for sz: float in [-1.0, 1.0]:
		var at := Vector3(hx + t, 0, sz * (ZamboniBay.DOOR_W / 2 + side / 2))
		_board(shell, at, side, PI / 2)
		_board_run(kit, at, side, PI / 2)
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
			_board_corner(kit, centre, sx, sz)


## The collision of a straight run of boards: one box, nothing drawn.
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


## A straight run of the kit along `length` metres centred at `at` (the
## panel's mid-thickness), the ice side facing `yaw`'s -Z: the longest
## sections first, the remainder closed with a 1 m section tucked a
## centimetre behind its neighbour; then the glass on the cap.
func _board_run(kit: Node3D, at: Vector3, length: float, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var along := basis * Vector3.RIGHT  # the run's +x in the world
	var back := basis * Vector3.BACK  # away from the ice
	var x := -length / 2
	var left := length
	while left > 0.005:
		var id := "board_4m" if left >= 4.0 else ("board_2m" if left >= 2.0 else "board_1m")
		var l := RinkKit.length_m(id)
		var tuck := 0.0
		if l > left + 0.005:  # the last piece overlaps the one before, a shade behind it
			tuck = 0.01
			x = length / 2 - l
		var b := RinkKit.board(id)
		b.position = at + along * (x + l / 2) + back * tuck
		b.rotation.y = yaw
		kit.add_child(b)
		_rink_pieces[id] = _rink_pieces.get(id, 0) + 1
		x += l
		left = length / 2 - x
	# the glass: as many 4 ft panels as fit, spread to the run's length
	var count := maxi(int(length / RinkKit.glass_w()), 1)
	var pitch := length / count
	for k in count:
		var g := RinkKit.glass("glass_4x6")
		g.position = at + along * (-length / 2 + (k + 0.5) * pitch) + Vector3(0, BOARD_H_CAP, 0)
		g.rotation.y = yaw
		kit.add_child(g)
		_rink_pieces["glass_4x6"] = _rink_pieces.get("glass_4x6", 0) + 1


## A corner of the kit: four quarter-corner curves round the arc about
## `centre` in the (sx, sz) quadrant, the glass as flat panels along it.
func _board_corner(kit: Node3D, centre: Vector3, sx: float, sz: float) -> void:
	var id := "board_curve_quarter"
	var rec := ObjectCatalog.info(id)
	var spec: Dictionary = rec.get("board", {})
	var angle := deg_to_rad(float(spec.get("angle_deg", 22.5)))
	var size: Array = rec.get("size_m", [3.36, 1.12, 0.3])
	var half := angle / 2
	# the piece's origin is its bounding box's bottom centre: this far out
	# from the arc's centre along the piece's middle
	var d := CORNER_R * cos(half) + float(size[2]) / 2 - 0.02
	var pieces := int(round(PI / 2 / angle))
	for k in pieces:
		var a := (k + 0.5) * angle
		var u := Vector3(sx * cos(a), 0, sz * sin(a))
		var b := RinkKit.board(id)
		b.position = centre + u * d
		b.rotation.y = atan2(u.x, u.z)
		kit.add_child(b)
		_rink_pieces[id] = _rink_pieces.get(id, 0) + 1
	var arc := (CORNER_R + BOARD_T / 2) * PI / 2
	var count := maxi(int(arc / RinkKit.glass_w()), 1)
	var step := PI / 2 / count
	for k in count:
		var a := (k + 0.5) * step
		var u := Vector3(sx * cos(a), 0, sz * sin(a))
		var g := RinkKit.glass("glass_4x6")
		g.position = centre + u * (CORNER_R + BOARD_T / 2) + Vector3(0, BOARD_H_CAP, 0)
		g.rotation.y = atan2(u.x, u.z)
		kit.add_child(g)
		_rink_pieces["glass_4x6"] = _rink_pieces.get("glass_4x6", 0) + 1


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
		if args.has("--right"):  # from the operator's right, over the console toward the seat
			_no_aim = true
			_off_the_machine()
			_look_at(
				_machine.to_global(Vector3(1.5, 2.5, 0.9)),
				_machine.to_global(Vector3(-0.3, 1.7, 0.45))
			)
		if args.has("--noprops"):  # the body alone: what is left of the old controls
			for pv in _machine.console_pivots:
				pv.visible = false
		if args.has("--lever"):  # close on the console from the operator's left
			_no_aim = true
			_look_at(
				_machine.to_global(Vector3(-0.95, 2.35, 0.95)),
				_machine.to_global(Vector3(-0.12, 1.78, 0.25))
			)
	if args.has("--view=wet"):
		# a flooded lane from standing height, the film's surface up close:
		# the machine's own pass, stepped at 60 Hz as in play
		_set_state(1)
		_machine.flood = 0.65
		_begin_pass(9.05)
		for step in 1800:
			_zamboni_step(1.0 / 60.0)
			_machine._process(1.0 / 60.0)
		ice.flush()
		walker.global_position = ice.position + Vector3(20.0, 0.05, 9.0)
		walker.face(-1.33)  # toward a lamp's reflection on the film
		walker.camera.rotation.x = -0.73
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
	if args.has("--view=boards"):
		# the machine slid along the side boards, its conditioner's end on
		# them, from the ice behind its left side: the fit of the hitbox
		_machine.show_body = true
		_machine.rotation.y = PI / 2 + 0.04
		_machine.global_position = ice.position + Vector3(RINK.x / 2 + 3.0, 0.0, RINK.y - 1.75)
		_machine.drive = 0
		for step in 240:
			_drive_with(1.0 / 60.0, 1.0, 0.0, 0.0)
		walker.set_noclip(true)
		walker.global_position = _machine.to_global(Vector3(2.6, 1.7, 3.4))
		walker.face(_machine.rotation.y + 0.6)
		walker.camera.rotation.x = -0.28
	if args.has("--view=shovel"):
		# the snow pusher in hand, pushed through a drift on the ice, the
		# roll in the blade and the mound it set down, from the pusher's eyes
		ice.fill_state(0.0, 0.0, 0.0, 0.0, 0.0)
		ice.mound(Vector2(RINK.x / 2 - 6.0, RINK.y / 2), 1.6, 0.08)
		ice.mound(Vector2(RINK.x / 2 - 4.5, RINK.y / 2 + 0.4), 1.2, 0.05)
		ice.flush()
		walker.global_position = Vector3(-8.5, 0.05, 0.0)
		walker.face(-PI / 2)
		_pusher.take(walker)
		for step in 80:
			walker.global_position += Vector3(0.03, 0.0, 0.0)
			_shovel()
		walker.camera.rotation.x = -0.5
	if args.has("--view=skate"):
		# a skater's marks: strides out, a hard turn, a stop, seen from past
		# the stop looking back along them (the pile, the scrape, the
		# turn's gouge, the stride chips)
		_skates_on()
		for step in 150:
			_skater.step(1.0 / 60.0, walker, ice, _local, _inside_the_sheet.bind(0.35), true, false)
		walker.face(walker.rotation.y + 1.3)
		for step in 70:
			_skater.step(
				1.0 / 60.0, walker, ice, _local, _inside_the_sheet.bind(0.35), false, false
			)
		var travel := Vector3(_skater.vel.x, 0.0, _skater.vel.y).normalized()
		for step in 60:
			_skater.step(1.0 / 60.0, walker, ice, _local, _inside_the_sheet.bind(0.35), false, true)
		var stop_at := walker.global_position
		_skates_off()
		walker.set_noclip(true)
		walker.global_position = stop_at + Vector3(0.0, 1.2, 0.0) + travel * 1.6
		walker.face(atan2(travel.x, travel.z))
		walker.camera.rotation.x = -0.55
	if args.has("--view=practice"):
		# the net set down by the goal line and the skater's own view of
		# it from the slot: the game's stick, the puck ahead, nothing else of you
		_net.carry(walker)
		walker.global_position = Vector3(RINK.x / 2 - GOAL_LINE - 1.7, 0.05, 0.0)
		walker.face(-PI / 2)
		_net.set_down()
		_skates_on()
		walker.global_position = Vector3(RINK.x / 2 - GOAL_LINE - 7.0, 0.05, 1.0)
		walker.face(-PI / 2 + 0.15)
		for step in 60:
			_skater.step(1.0 / 60.0, walker, ice, _local, _inside_the_sheet.bind(0.35), true, false)
		_puck.at = _local(walker.global_position) + Vector2(3.2, -0.6)
		_place_puck()
		walker.camera.rotation.x = -0.2
	if args.has("--view=kit"):
		# the rink kit on show in the bay, from inside the doors
		_bay.want_open = true
		_bay.open = 1.0
		_bay._process(0.0)
		walker.set_noclip(true)
		walker.global_position = Vector3(RINK.x / 2 + BOARD_T + 0.8, 0.9, -1.2)
		walker.face(-PI / 2 - 0.5)
		walker.camera.rotation.x = -0.05
	if args.has("--view=bay"):
		# from the ice by the end boards: the doors swung open and the
		# machine half through them onto the pad (--closed: shut, the machine before them)
		var shut := args.has("--closed")
		_bay.want_open = not shut
		_bay.open = 0.0 if shut else 1.0
		_bay._process(0.0)
		_machine.show_body = true
		_machine.rotation.y = -PI / 2
		_machine.global_position = (
			ice.position + Vector3(RINK.x + (0.3 if not shut else -3.5), 0.0, RINK.y / 2)
		)
		_look_at(
			ice.position + Vector3(RINK.x - 4.5, 1.7, RINK.y / 2 + 4.0),
			ice.position + Vector3(RINK.x + 1.0, 0.7, RINK.y / 2)
		)
	if args.has("--view=hose"):
		# in the bay, the reel on its wall
		_bay.want_open = true
		_bay.open = 1.0
		_bay._process(0.0)
		var hx := RINK.x / 2 + BOARD_T
		_look_at(Vector3(hx + 0.8, 1.5, -0.8), Vector3(hx + 3.0, 0.95, -ZamboniBay.BAY_W / 2))
	if args.has("--view=spray"):
		# on the ice by the end, the hose in hand, spraying down the sheet
		# (--pattern=0 mist .. 1 jet) for a second before the shot
		walker.set_noclip(false)
		walker.global_position = ice.position + Vector3(RINK.x - 5.0, 0.05, RINK.y / 2 + 2.0)
		walker.face(PI / 2)
		walker.camera.rotation.x = -0.3
		_hose.take(walker.camera)
		_hose.pattern = 0.5
		for a in args:
			if a.begins_with("--pattern="):
				_hose.pattern = float(a.trim_prefix("--pattern="))
		hosing = true
		for i in 70:
			await get_tree().process_frame
	if args.has("--view=edger"):
		# the edger pushed a few metres along the side boards, its left
		# side on them, the blade set 1.5 mm down, seen from behind its
		# right shoulder
		_set_state(1)
		ice.flush()
		_edger.global_position = ice.position + Vector3(RINK.x - 12.0, 0.0, RINK.y - EDGER_SIDE)
		_edger.rotation.y = PI / 2  # nose toward -X, the boards on its left
		_edger.level_mm = -1.5
		_edger.blade_down = true
		_edger.running = true
		for step in 300:
			_push_with(1.0 / 60.0, 1.0, 0.0)
		ice.flush()
		_look_at(
			_edger.to_global(Vector3(1.3, 1.5, 2.2)), _edger.to_global(Vector3(0.0, 0.0, -1.5))
		)
	if args.has("--view=push"):
		# at the edger's handles on the ice by the side boards, the view
		# the pusher gets: the right grip's crank in front, the lane ahead
		_set_state(1)
		ice.flush()
		_edger.global_position = ice.position + Vector3(RINK.x - 12.0, 0.0, RINK.y - EDGER_SIDE)
		_edger.rotation.y = PI / 2
		_edger.level_mm = -1.5
		_edger.blade_down = true
		_edger.running = true
		_take_the_handles()
		for step in 120:
			_push_with(1.0 / 60.0, 1.0, 0.0)
		ice.flush()
		_stay_behind_the_edger()
		walker.camera.rotation.x = -0.5
	if args.has("--view=snow"):
		# half snowed up, a mist's water on a patch of it (slush) and a
		# patch set into crust, from low over the sheet
		_set_state(1)
		ice.snow_level(0.5)
		var o := Vector2(BLUE_LINE + 2.0, RINK.y / 2)
		ice.pour(o + Vector2(0.0, 0.8), 1.6, 0.5)
		ice.pour(o + Vector2(0.0, -1.0), 1.6, 0.5)
		# the second patch set: walk its cells to crust
		var c := ice.cell_at(o + Vector2(0.0, -1.0))
		for dz in range(-40, 41):
			for dx in range(-40, 41):
				var i := ice.index(c.x + dx, c.y + dz)
				if ice.water[i] > 0.0 and ice.snow[i] > 0.0:
					ice.crust[i] += ice.snow[i] + ice.water[i] * 0.5
					ice.snow[i] = 0.0
					ice.water[i] = 0.0
					ice._wet_flag[i] = 0
					ice._wet_n -= 1
		ice.mark_all_dirty()
		ice.flush()
		_look_at(
			ice.position + Vector3(o.x - 2.6, 1.3, o.y + 2.6),
			ice.position + Vector3(o.x + 0.5, 0.0, o.y - 0.3)
		)
	if args.has("--view=track"):
		# from above and behind: the lane the conditioner leaves against its width
		_machine.global_position = ice.position + Vector3(8.0, 0.0, 10.0)
		_machine.rotation.y = -PI / 2
		_machine.cond_down = true
		_machine.lift = 1.0
		_machine.settle()
		_machine.flood = 0.65
		_machine.drive = 0
		_machine.show_body = true
		for step in 300:
			_drive_with(1.0 / 60.0, 1.0, 0.0, 0.0)
			_machine._process(1.0 / 60.0)
		ice.flush()
		_look_at(
			_machine.to_global(Vector3(0.0, 4.0, 4.5)), _machine.to_global(Vector3(0.0, 0.0, 0.5))
		)
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
	if args.has("--view=heat"):
		# the heatmap over a sheet with a few passes, an edger lane and a gouge
		for lane in 3:
			var z := 3.0 + lane * MACHINE_W
			ice.resurface(
				PASS_X0,
				PASS_X1,
				z - MACHINE_W / 2,
				z + MACHINE_W / 2,
				0.8 + 0.3 * lane,
				0.0,
				0.0,
				0.0
			)
		ice.edge_sweep(
			Vector2(4.0, 0.4),
			Vector2(RINK.x - 4.0, 0.4),
			0.23,
			-3.0,
			IceEdger.SLOPE,
			3.0,
			0.01,
			0.4
		)
		ice.pour(Vector2(RINK.x / 2, RINK.y / 2), 2.0, 1.5)
		set_heatmap(true)
		walker.set_noclip(true)
		walker.global_position = Vector3(-RINK.x / 2 - 6.0, 12.0, 0.0)
		walker.face(-PI / 2)
		walker.camera.rotation.x = -0.42
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
		ice.thermal(60.0, -9.0, 8.0)
	check.call(
		ice.ice[edge] > 0.0 or ice.frozen[edge] > ice.frozen[mid],
		(
			"the shallow edge sets before the deep middle (%.2f vs %.2f)"
			% [ice.frozen[edge], ice.frozen[mid]]
		)
	)
	for minute in 16:
		ice.thermal(60.0, -9.0, 8.0)
	check.call(
		ice.water[mid] == 0.0 and ice.ice[mid] > 1.0,
		(
			"1.2 mm at -5 C sets in under 20 minutes (water %.2f, ice %.2f)"
			% [ice.water[mid], ice.ice[mid]]
		)
	)
	for minute in 25:
		ice.thermal(60.0, -9.0, 8.0)  # the set columns cool back to steady and leave the walk
	check.call(ice.wet_cells == 0, "no wet or cooling cells left (%d)" % ice.wet_cells)
	# set water is ice: flooding the same spot again builds it up
	var h0 := ice.ice_at(Vector2(6.0, 7.0))
	check.call(h0 > 1.0, "the set pour became ice (%.2f mm)" % h0)
	for again in 3:
		ice.pour(Vector2(6.0, 7.0), 0.6, 1.2)
		for minute in 20:
			ice.thermal(60.0, -9.0, 8.0)
	var h1 := ice.ice_at(Vector2(6.0, 7.0))
	check.call(h1 > h0 + 3.0, "three more floods raised it (%.2f -> %.2f mm)" % [h0, h1])
	# a whole flooded sheet: level chunks stay one quad and a step stays cheap
	_set_state(2)
	ice.flush()
	ice.thermal(1.0, -9.0, 8.0)  # the first call builds the walk list
	var t0 := Time.get_ticks_usec()
	ice.thermal(1.0, -9.0, 8.0)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	check.call(ms < 12.0, "a thermal step on a flooded sheet is under 12 ms (%.1f)" % ms)  # ~6 here, the CI box is slow
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
	# the same pour on bare ice next to it: the slush sets first, by a lot
	ice.pour(Vector2(12.0, 8.0), 0.6, 1.2)
	for x in 60:
		for z in 60:
			ice.snow[ice.index(sc.x - 30 + x, sc.y + 90 + z)] = 0.0
	var bare_i := ice.index(sc.x, sc.y + 120)
	var slush_t := -1.0
	var film_t := -1.0
	for second in 1500:
		ice.thermal(1.0, -9.0, 8.0)
		if slush_t < 0.0 and ice.water[si] == 0.0:
			slush_t = second
		if film_t < 0.0 and ice.water[bare_i] == 0.0:
			film_t = second
		if slush_t >= 0.0 and film_t >= 0.0:
			break
	check.call(
		ice.crust[si] > 0.5 and ice.snow[si] == 0.0 and ice.water[si] == 0.0,
		"slush set into a crust (%.2f mm)" % ice.crust[si]
	)
	check.call(
		slush_t > 0.0 and film_t > slush_t * 2.5,
		"slush sets several times faster than water on ice (%.0f s vs %.0f s)" % [slush_t, film_t]
	)
	# Sean's clock: a 0.8 mm flood on 25 mm over a -9 C pad sets in about four
	# minutes; the freeze is heat flow, so a mist sets in under a minute,
	# thin ice freezes faster (the pad is nearer) and a second flood on the
	# warmed column takes longer
	var film_time := func(mm: float, base: float, slab: float) -> float:
		_set_state(1)
		ice.base_mm = base
		ice.flush()
		ice.lay_film(10.0, 12.0, 4.0, 6.0, mm, 0.0)
		var fi := ice.index(ice.cell_at(Vector2(11.0, 5.0)).x, ice.cell_at(Vector2(11.0, 5.0)).y)
		for second in 3600:
			ice.thermal(1.0, slab, 8.0)
			if ice.water[fi] == 0.0:
				return float(second)
		return 3600.0
	var set_t: float = film_time.call(0.8, 25.0, -9.0)
	check.call(
		set_t >= 180.0 and set_t <= 300.0,
		"0.8 mm on 25 mm at -9 C, 8 C air sets in 3 to 5 minutes (%.0f s)" % set_t
	)
	var mist_t: float = film_time.call(0.15, 25.0, -9.0)
	check.call(mist_t < 60.0, "a mist's 0.15 mm sets in under a minute (%.0f s)" % mist_t)
	var thin_t: float = film_time.call(0.8, 12.0, -9.0)
	check.call(thin_t < set_t * 0.7, "the same film on 12 mm of ice sets faster (%.0f s)" % thin_t)
	var pool_t: float = film_time.call(3.0, 25.0, -9.0)
	check.call(pool_t > set_t * 3.0, "a 3 mm pool takes much longer (%.0f s)" % pool_t)
	# a second flood right after the first, on the warmed column
	ice.lay_film(10.0, 12.0, 4.0, 6.0, 0.8, 0.0)
	var fi2 := ice.index(ice.cell_at(Vector2(11.0, 5.0)).x, ice.cell_at(Vector2(11.0, 5.0)).y)
	var again_t := 3600.0
	for second in 3600:
		ice.thermal(1.0, -9.0, 8.0)
		if ice.water[fi2] == 0.0:
			again_t = float(second)
			break
	check.call(
		again_t > set_t * 1.15,
		(
			"a flood right after a flood sets slower on the warmed column (%.0f vs %.0f s)"
			% [again_t, set_t]
		)
	)
	ice.base_mm = 25.0
	check.call(
		(
			ice.ice_temp_at(Vector2(30.0, 12.0), -9.0, 8.0) < -8.0
			and ice.ice_temp_at(Vector2(30.0, 12.0), -9.0, 8.0) > -9.0
		),
		(
			"a dry column sits a little above the pad's temperature (%.1f C)"
			% ice.ice_temp_at(Vector2(30.0, 12.0), -9.0, 8.0)
		)
	)
	# the snowed-up scale: a little snow is a few drifts, the full scale covers the sheet
	ice.snow_level(0.25)
	var snowed := 0
	var sampled := 0
	for x in range(100, ice.w - 100, 50):
		for z in range(100, ice.d - 100, 50):
			sampled += 1
			if ice.snow[ice.index(x, z)] > 0.0:
				snowed += 1
	var frac := float(snowed) / sampled
	check.call(
		frac > 0.04 and frac < 0.7,
		"a quarter snowed up is drifts (%.0f%% of the sheet)" % (frac * 100.0)
	)
	ice.snow_level(1.0)
	var bare := 0
	for x in range(100, ice.w - 100, 50):
		for z in range(100, ice.d - 100, 50):
			if ice.snow[ice.index(x, z)] < 0.3:
				bare += 1
	check.call(bare == 0, "fully snowed up covers the sheet (%d bare samples)" % bare)
	ice.snow_level(0.0)
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
	ice.pour(Vector2(16.0, 7.0), 0.4, 7.0)  # half a litre: a pool, which spreads
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
		ice.thermal(60.0, -9.0, 8.0)
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
		_machine.tank_m3 == 0.0 and _machine.auger_on and _machine.lift_on,
		"the tank was dumped after the pass and the levers stayed where they were"
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
	_machine.auger_on = false
	ctl.toggle(k_h)
	check.call(
		_machine.auger_on and _machine.lift_on, "the horizontal lever leaves the vertical alone"
	)
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
	var hull_before: Vector3 = (
		PhysicsServer3D
		. body_get_state(_machine.hull.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
		. origin
	)
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
	# the hull (the collider the walker bumps into) travels with the machine
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hull_now: Vector3 = (
		PhysicsServer3D
		. body_get_state(_machine.hull.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
		. origin
	)
	check.call(
		(
			hull_now.distance_to(hull_before) > 2.0
			and hull_now.distance_to(_machine.hull.global_position) < 0.01
		),
		(
			"the hull travels with the machine (%.1f m, off by %.3f)"
			% [
				hull_now.distance_to(hull_before),
				hull_now.distance_to(_machine.hull.global_position)
			]
		)
	)
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
	# the blade's level is carried along the cut: a pass stepped at 60 Hz
	# over bumpy ice leaves one plane, not a ridge across the lane at
	# every strip (the blade-skip look)
	_set_state(1)
	ice.flush()
	for k in 12:
		ice.pour(Vector2(6.0 + k * 4.3, 6.0 + (k % 3 - 1) * 0.5), 0.5, 0.6 + 0.1 * (k % 4))
	ice.set_now()
	_machine.blade_mm = -1.0
	_machine.flood = 0.0
	_begin_pass(6.0)
	for step in 1800:
		_zamboni_step(1.0 / 60.0)
	var ridge := 0.0
	var row := ice.cell_at(Vector2(0.0, 6.0)).y
	for x in range(
		ice.cell_at(Vector2(PASS_X0 + 1.0, 0.0)).x, ice.cell_at(Vector2(PASS_X1 - 1.0, 0.0)).x
	):
		var i := ice.index(x, row)
		var j := ice.index(x + 1, row)
		ridge = maxf(ridge, absf((ice.ice[j] + ice.crust[j]) - (ice.ice[i] + ice.crust[i])))
	check.call(
		ridge < 0.1,
		"the stepped pass cuts one plane, no ridges across it (max step %.3f mm)" % ridge
	)
	# the flood: the blade cuts dry and the pipe behind it lays the film,
	# the lane is the conditioner's width, and every changed column is
	# rebuilt the frame it changes (no queue, no seam at a chunk's edge)
	_set_state(1)
	ice.flush()
	_machine.blade_mm = -0.5
	_machine.flood = 0.65
	_begin_pass(6.0)
	var worst_us := 0
	var sum_us := 0
	for step in 600:
		_zamboni_step(1.0 / 60.0)
		_machine._process(1.0 / 60.0)
		ice.thermal(1.0 / 60.0, -9.0, 8.0)
		var tick := Time.get_ticks_usec()
		ice._process(1.0 / 60.0)
		var us := Time.get_ticks_usec() - tick
		worst_us = maxi(worst_us, us)
		sum_us += us
	print(
		(
			"ice demo: a flood pass rebuilds in %.1f ms a frame, worst %.1f"
			% [sum_us / 600000.0, worst_us / 1000.0]
		)
	)
	check.call(ice.dirty_count() == 0, "every changed column is on screen the frame it changed")
	var blade_x := _zam
	var just_cut := Vector2(blade_x - FLOOD_BEHIND / 2, 6.0)
	var flooded := Vector2(blade_x - FLOOD_BEHIND - 0.3, 6.0)
	var jc := ice.cell_at(just_cut)
	check.call(
		ice.water_at(just_cut) == 0.0 and ice.cut[ice.index(jc.x, jc.y)] > 0.0,
		"the strip behind the blade is a dry cut before the pipe reaches it"
	)
	check.call(
		ice.water_at(flooded) > 0.5, "... and flooded once it has (%.2f mm)" % ice.water_at(flooded)
	)
	var lane_lo := 99.0
	var lane_hi := -99.0
	var xc := ice.cell_at(Vector2(blade_x - 2.0, 0.0)).x
	for z in ice.d:
		if ice.ice[ice.index(xc, z)] < -0.01:
			lane_lo = minf(lane_lo, z * ice.cell)
			lane_hi = maxf(lane_hi, (z + 1) * ice.cell)
	check.call(
		absf((lane_hi - lane_lo) - Zambelli.BLADE_W) < 0.06,
		"the lane is the blade's width (%.2f m)" % (lane_hi - lane_lo)
	)
	# a tile's apron holds the next tile's edge cells, so the textures read
	# the same on both sides of a tile's edge (no seam every 6.4 m)
	ice.flush()
	var tile_m := IceSheet.TILE * ice.cell
	ice.pour(Vector2(tile_m * 2, 7.0), 0.3, 1.0)
	ice.flush()
	var zr := ice.cell_at(Vector2(0.0, 7.0)).y
	var left: Variant = ice._tiles[Vector2i(1, zr / IceSheet.TILE)]
	var right: Variant = ice._tiles[Vector2i(2, zr / IceSheet.TILE)]
	var pz := zr % IceSheet.TILE + 1
	check.call(
		(
			right.state_img.get_pixel(1, pz).b > 0.0
			and left.state_img.get_pixel(IceSheet.TILE + 1, pz) == right.state_img.get_pixel(1, pz)
			and right.state_img.get_pixel(0, pz) == left.state_img.get_pixel(IceSheet.TILE, pz)
			and left.depth_img.get_pixel(IceSheet.TILE + 1, pz) == right.depth_img.get_pixel(1, pz)
		),
		"the tiles' aprons carry the edge cells across the seam"
	)
	# a column on a chunk's first row is the chunk before's border row too
	ice.flush()
	ice.pour(Vector2(30.0, IceSheet.CHUNK * ice.cell * 4 + ice.cell / 2), 0.03, 1.0)
	var edge_keys := ice._dirty.keys()
	check.call(
		edge_keys.size() == 2 and edge_keys.has(Vector2i(int(30.0 / ice.cell) / IceSheet.CHUNK, 3)),
		"a change on a chunk's edge rebuilds the chunk before it too (%s)" % [edge_keys]
	)
	ice.flush()
	# the fire hose: taken off the reel it sprays FireHose.LPS where you
	# look; a mist wets a wide disc close by, a jet a small one far off
	_set_state(1)
	ice.flush()
	var hcam := Camera3D.new()
	add_child(hcam)
	hcam.global_position = ice.position + Vector3(RINK.x - 2.0, 1.6, RINK.y / 2)
	check.call(not _hose.held, "the hose starts on the reel")
	var reel_eye: Vector3 = _hose.reel.global_position + Vector3(-2.0, 1.1, 0.0)
	check.call(
		_hose.aimed(reel_eye, Vector3(1.0, -0.1, 0.0).normalized()), "the reel is under the dot"
	)
	check.call(not _hose.aimed(reel_eye, Vector3(-1.0, 0.0, 0.0)), "... not behind you")
	_hose.take(hcam)
	check.call(
		_hose.held and _hose.nozzle.visible and _hose.nozzle.get_parent() == hcam,
		"E takes it in hand"
	)
	hcam.rotation = Vector3(-0.35, PI / 2, 0.0)  # looking down the sheet toward -X
	_hose.pattern = 1.0
	hosing = true
	var hosed0 := hosed_l
	for frame in 60:
		_spray(1.0 / 60.0, hcam)
	check.call(
		absf(hosed_l - hosed0 - FireHose.LPS) < 0.05,
		"a second of jet is %.1f litres (%.1f)" % [FireHose.LPS, hosed_l - hosed0]
	)
	var jet_wet := 0
	var mist_wet := 0
	for x in range(0, ice.w, 4):
		for z in range(0, ice.d, 4):
			if ice.water[ice.index(x, z)] > 0.0:
				jet_wet += 1
	check.call(jet_wet > 0, "the jet wets the ice down the sheet (%d samples)" % jet_wet)
	var jet_far := 0.0
	for x in range(0, ice.w, 4):
		for z in range(0, ice.d, 4):
			if ice.water[ice.index(x, z)] > 0.0:
				jet_far += ((RINK.x - 2.0) - x * ice.cell) / jet_wet  # the mean reach
	ice.fill_state(0.0, 0.8, 0.0, 0.0, 0.08)
	ice.flush()
	_hose.pattern = 0.0
	var spray_us := 0
	for frame in 60:
		var ta := Time.get_ticks_usec()
		_spray(1.0 / 60.0, hcam)
		ice.flush()
		spray_us += Time.get_ticks_usec() - ta
	print("  a mist frame, poured and rebuilt: %.1f ms" % (spray_us / 60000.0))
	var mist_far := 0.0
	for x in range(0, ice.w, 4):
		for z in range(0, ice.d, 4):
			if ice.water[ice.index(x, z)] > 0.0:
				mist_wet += 1
				mist_far += (RINK.x - 2.0) - x * ice.cell
	mist_far /= maxi(mist_wet, 1)
	check.call(
		mist_wet > jet_wet * 3 and mist_far < jet_far,
		(
			"the mist wets a wider disc, closer in (%d vs %d samples, %.1f vs %.1f m)"
			% [mist_wet, jet_wet, mist_far, jet_far]
		)
	)
	hosing = false
	_hose.hang()
	check.call(not _hose.held and not _hose.nozzle.visible, "E hangs it back on the reel")
	hcam.queue_free()
	ice.fill_state(0.0, 0.8, 0.0, 0.0, 0.08)
	ice.flush()
	# the edger: pushed along, the blade down cuts its lane with arcs and
	# throws the shavings to its right; the crank sets the depth
	_set_state(1)
	ice.flush()
	_edger.global_position = ice.position + Vector3(RINK.x - 12.0, 0.0, RINK.y / 2)
	_edger.rotation.y = -PI / 2  # nose toward +X
	_edger.level_mm = -4.0
	_edger.blade_down = false
	_edger.running = false
	_edger.speed = 0.0
	var e0 := _edger.global_position
	for step in 120:
		_push_with(1.0 / 60.0, 1.0, 0.0)
	var moved := _edger.global_position.distance_to(e0)
	check.call(
		moved > 1.0 and _edger.global_position.x > e0.x + 1.0,
		"W pushes the edger forward (%.2f m in two seconds)" % moved
	)
	var lane := _local(
		_edger.to_global(Vector3(IceEdger.BLADE_X - 0.19, 0.0, IceEdger.BLADE_Z + 0.3))
	)
	check.call(is_equal_approx(ice.thickness_at(lane), 25.0), "the blade up, the lane is untouched")
	var free_speed := _edger.speed
	_edger.blade_down = true
	for step in 60:
		_push_with(1.0 / 60.0, 1.0, 0.0)
	lane = _local(_edger.to_global(Vector3(IceEdger.BLADE_X - 0.19, 0.0, IceEdger.BLADE_Z + 0.4)))
	check.call(
		is_equal_approx(ice.thickness_at(lane), 25.0), "the engine off, the blade down cuts nothing"
	)
	var eng_eye: Vector3 = _edger.to_global(Vector3(0.0, 1.5, 1.6))
	var eng_dir: Vector3 = (_edger.to_global(Vector3(0.0, 0.45, -0.25)) - eng_eye).normalized()
	check.call(
		_edger.engine_aimed(eng_eye, eng_dir), "the engine is under the dot from the handles"
	)
	_edger.toggle_engine()
	check.call(_edger.running, "E starts it")
	for step in 120:
		_push_with(1.0 / 60.0, 1.0, 0.0)
	check.call(
		(
			is_equal_approx(free_speed, IceEdger.PUSH_SPEED * IceEdger.FREE)
			and is_equal_approx(_edger.speed, IceEdger.PUSH_SPEED)
		),
		(
			"the push is %.0f%% quicker with the blade clear (%.2f vs %.2f m/s)"
			% [(IceEdger.FREE - 1.0) * 100.0, free_speed, _edger.speed]
		)
	)
	lane = _local(_edger.to_global(Vector3(IceEdger.BLADE_X - 0.19, 0.0, IceEdger.BLADE_Z + 0.4)))
	var disc_mid := _local(
		_edger.to_global(Vector3(IceEdger.BLADE_X - 0.07, 0.0, IceEdger.BLADE_Z + 0.4))
	)
	var right_of := _local(_edger.to_global(Vector3(0.15, 0.0, IceEdger.BLADE_Z + 0.4)))
	check.call(
		ice.thickness_at(lane) < 24.0,
		"the blade down, the left rim cuts about 4 mm (%.2f mm)" % ice.thickness_at(lane)
	)
	check.call(
		ice.thickness_at(disc_mid) > ice.thickness_at(lane) and ice.thickness_at(disc_mid) < 25.0,
		"... shallower toward the disc's centre (%.2f mm)" % ice.thickness_at(disc_mid)
	)
	check.call(
		is_equal_approx(ice.thickness_at(right_of), 25.0),
		(
			"... and the disc's right half, tilted clear, cuts nothing (%.2f mm)"
			% ice.thickness_at(right_of)
		)
	)
	var lane_c := ice.cell_at(disc_mid)
	var circling := false
	var arcs := 0
	for dx in range(-8, 9):
		for dz in range(-8, 9):
			var li := ice.index(lane_c.x + dx, lane_c.y + dz)
			if ice.gouge[li] > 0.3:
				arcs += 1
			if ice.cut[li] > 0.0 and absf(ice.ang[li] - PI) > 0.4 and absf(ice.ang[li]) > 0.4:
				circling = true
	check.call(arcs > 0, "the rim rocked arcs into the lane (%d cells)" % arcs)
	check.call(circling, "the striations circle the disc")
	var throw_r := _local(_edger.to_global(Vector3(IceEdger.THROW, 0.0, IceEdger.BLADE_Z + 0.4)))
	var throw_l := _local(
		_edger.to_global(Vector3(IceEdger.BLADE_X - IceEdger.THROW, 0.0, IceEdger.BLADE_Z + 0.4))
	)
	check.call(
		ice.snow_at(throw_r) > 0.0 and ice.snow_at(throw_l) == 0.0,
		(
			"the shavings land to its right (%.2f mm right, %.2f left)"
			% [ice.snow_at(throw_r), ice.snow_at(throw_l)]
		)
	)
	var crank0 := _edger.level_mm
	_edger.crank_notch(true)
	check.call(
		is_equal_approx(_edger.level_mm, crank0 + IceEdger.CRANK_MM), "clockwise raises the blade"
	)
	_edger.crank_notch(false)
	check.call(is_equal_approx(_edger.level_mm, crank0), "counter-clockwise lowers it")
	for notch in 20:
		_edger.crank_notch(true)
	check.call(is_equal_approx(_edger.level_mm, IceEdger.LEVEL_MAX), "it goes up to +4 mm")
	for notch in 40:
		_edger.crank_notch(false)
	check.call(is_equal_approx(_edger.level_mm, IceEdger.LEVEL_MIN), "... and down to -4 mm")
	_edger.level_mm = crank0
	_edger.toggle_blade()
	check.call(not _edger.blade_down, "TAB lifts the blade")
	var yaw0 := _edger.rotation.y
	_push_with(1.0 / 60.0, 0.0, 1.0)
	var turned_up := absf(_edger.rotation.y - yaw0)
	_edger.blade_down = true
	yaw0 = _edger.rotation.y
	_push_with(1.0 / 60.0, 0.0, 1.0)
	check.call(
		absf(_edger.rotation.y - yaw0) < turned_up * 0.6,
		"it turns slower with the blade in the ice"
	)
	_edger.blade_down = false
	_edger.toggle_engine()
	check.call(not _edger.running, "E again stops it")
	_edger.speed = 0.0
	# against the side boards, a touch into them: it rides flush and slides
	# along at full speed (Sean: no gap, no sticking)
	_edger.global_position = ice.position + Vector3(RINK.x - 12.0, 0.0, RINK.y - 0.3)
	_edger.rotation.y = PI / 2 + 0.05  # nose toward -X, leaning a little into the boards
	for step in 90:
		_push_with(1.0 / 60.0, 1.0, 0.0)
	var gap := INF
	for cz: float in [IceEdger.DECK_FRONT, IceEdger.DECK_BACK]:
		var corner := _local(_edger.to_global(Vector3(-IceEdger.DECK_HALF_W, 0.0, cz)))
		gap = minf(gap, RINK.y - corner.y)
	check.call(gap < 0.02 and gap > -0.001, "its deck rides flush on the boards (%.3f m off)" % gap)
	check.call(
		_edger.speed > IceEdger.PUSH_SPEED * IceEdger.FREE * 0.98,
		"... and slides along them at full speed (%.2f m/s)" % _edger.speed
	)
	check.call(
		is_equal_approx(_edger.edge_over, IceEdger.EDGE_OVER),
		"on the straight the lane starts at the rim (+%.0f mm)" % (_edger.edge_over * 1000.0)
	)
	# in a corner, the deck's ends on the arc, its middle stands off: the lane reaches out
	var arc_c := Vector2(RINK.x - CORNER_R, RINK.y - CORNER_R)
	var at45 := arc_c + Vector2(1.0, 1.0).normalized() * (CORNER_R - IceEdger.DECK_HALF_W - 0.05)
	_edger.global_position = ice.position + Vector3(at45.x, 0.0, at45.y)
	_edger.rotation.y = PI / 4 + PI / 2  # tangent to the arc, the boards on its left
	_edger.speed = 0.0
	for step in 30:
		_push_with(1.0 / 60.0, 1.0, 0.0)
	check.call(
		_edger.edge_over > 0.04,
		(
			"round the corner it reaches past the rim to the boards (+%.0f mm)"
			% (_edger.edge_over * 1000.0)
		)
	)
	_edger.speed = 0.0
	# the bay: shut doors are boards, open ones a doorway onto the pad, and
	# the pad's walls are the end of it
	_bay.want_open = false
	_bay.open = 0.0
	_bay._process(0.0)
	_machine.rotation.y = -PI / 2
	_machine.cond_down = false
	_machine.settle()
	_machine.global_position = ice.position + Vector3(RINK.x - 6.0, 0.0, RINK.y / 2)
	_machine.drive = 0
	for step in 600:
		_drive_with(1.0 / 60.0, 1.0, 0.0, 0.0)
	check.call(
		_local(_machine.global_position).x < RINK.x - 1.0 and _machine.speed == 0.0,
		"shut, the bay doors are boards (x %.2f)" % _local(_machine.global_position).x
	)
	var eye := ice.position + Vector3(RINK.x - 1.5, 1.6, RINK.y / 2 - 1.0)
	check.call(_bay.aimed(eye, Vector3(1.0, -0.6, 0.0).normalized()), "a leaf is under the dot")
	check.call(not _bay.aimed(eye, Vector3(-1.0, -0.6, 0.0).normalized()), "... not from behind")
	_bay.toggle()
	for step in 180:
		_bay._process(1.0 / 60.0)
	check.call(
		_bay.open == 1.0 and absf(_bay._leaves[0].rotation.y - ZamboniBay.OPEN_RAD) < 0.01,
		"E swings the leaves outward in three seconds (%.2f rad)" % _bay._leaves[0].rotation.y
	)
	_machine.speed = 0.0
	for step in 900:
		_drive_with(1.0 / 60.0, 1.0, 0.0, 0.0)
	check.call(
		_local(_machine.global_position).x > RINK.x + 2.0,
		(
			"open, the machine drives through onto the pad (x %.2f)"
			% _local(_machine.global_position).x
		)
	)
	check.call(
		_local(_machine.global_position).x < RINK.x + ZamboniBay.BAY_D and _machine.speed == 0.0,
		"... and stops at the back wall"
	)
	_machine.drive = 2
	_machine.speed = 0.0
	for step in 900:
		_drive_with(1.0 / 60.0, 1.0, 0.0, 0.0)
	check.call(
		_local(_machine.global_position).x < RINK.x - 4.0,
		"reverse takes it back out onto the ice (x %.2f)" % _local(_machine.global_position).x
	)
	_machine.drive = 0
	_bay.toggle()
	for step in 180:
		_bay._process(1.0 / 60.0)
	check.call(_bay.open == 0.0, "E again swings them shut")
	# the boards fit the model: along the side boards the conditioner's
	# end rides on them (the hull is narrower, so it sits in from them by
	# the blade's reach), and nosed into a corner the nose meets the arc
	_machine.rotation.y = PI / 2 + 0.04  # nose toward -X, leaning a little into the boards
	_machine.global_position = ice.position + Vector3(RINK.x / 2 + 3.0, 0.0, RINK.y - 1.75)
	_machine.speed = 0.0
	_machine.drive = 0
	for step in 420:
		_drive_with(1.0 / 60.0, 1.0, 0.0, 0.0)
	var side_edge := -INF
	for fp in _footprint:
		side_edge = maxf(side_edge, _local(_machine.to_global(Vector3(fp.x, 0.0, fp.y))).y)
	check.call(
		RINK.y - side_edge < 0.02 and RINK.y - side_edge > -0.001 and _machine.speed > 0.5,
		(
			"the conditioner's end rides flush on the side boards (%.3f m off, %.2f m/s)"
			% [RINK.y - side_edge, _machine.speed]
		)
	)
	# the push turned it to lie along them, the conditioner's side on the
	# boards (the hull sits in from them, narrower by the blade's reach)
	var lean := wrapf(_machine.rotation.y - PI / 2, -PI, PI)
	print("ice demo: boards slide lean %.3f rad" % lean)
	check.call(
		absf(lean) < 0.03, "... and the push turned it to lie along them (lean %.3f rad)" % lean
	)
	_machine.rotation.y = PI / 2 + PI / 4  # nose into the -X +z corner
	_machine.global_position = ice.position + Vector3(6.0, 0.0, RINK.y - 6.0)
	_machine.speed = 0.0
	for step in 300:
		_drive_with(1.0 / 60.0, 1.0, 0.0, 0.0)
	# (the nose is flat and 1.9 m wide, so its corners meet the arc first)
	var nose_gap := INF
	for fp in _footprint:
		nose_gap = minf(nose_gap, _corner_gap(_local(_machine.to_global(Vector3(fp.x, 0.0, fp.y)))))
	check.call(
		nose_gap >= -0.001 and nose_gap < 0.02,
		"nosed into a corner the nose's corner meets the arc (%.3f m off)" % nose_gap
	)
	# snow with volume: a shovelled mound is as tall as its cubic metres
	# say, at true scale, and the pusher sweeps it up and sets it down
	ice.fill_state(0.0, 0.0, 0.0, 0.0, 0.0)
	ice.flush()
	var pile_at := Vector2(RINK.x / 2 - 8.0, RINK.y / 2)
	ice.mound(pile_at, 0.9, 0.03)
	ice.flush()
	var in_pile := ice.snow_in(pile_at, 1.2)
	check.call(
		in_pile > 0.026 and in_pile < 0.034,
		"a 30 L mound holds its volume on the sheet (%.1f L)" % (in_pile * 1000.0)
	)
	var pile_c := ice.cell_at(pile_at)
	var pile_h := ice._height(pile_c.x, pile_c.y)
	check.call(
		pile_h > 0.10 and pile_h < 0.20,
		"... and stands at true scale, 14 cm or so at the middle (%.3f m)" % pile_h
	)
	walker = FirstPerson.new()  # the tools and the skates want someone holding them
	add_child(walker)
	walker.global_position = ice.position + Vector3(pile_at.x - 2.2, 0.05, pile_at.y)
	walker.face(-PI / 2)  # toward +X, the pile ahead
	_pusher.take(walker)
	check.call(_pusher.held, "E takes the snow pusher off the wall")
	for step in 100:
		walker.global_position += Vector3(0.03, 0.0, 0.0)
		_shovel()
	check.call(
		_pusher.load > 0.015,
		"pushed through the mound, the blade carries most of it (%.1f L)" % (_pusher.load * 1000.0)
	)
	var left_behind := ice.snow_in(pile_at, 0.8)
	check.call(
		left_behind < in_pile * 0.35,
		"... and the mound is gone from where it was (%.1f L left)" % (left_behind * 1000.0)
	)
	var carried := _pusher.load
	var ahead := _local(walker.global_position) + Vector2(1.6, 0.0)
	var before_dump := ice.snow_in(ahead, 1.2)
	_set_snow_down()
	ice.flush()
	var after_dump := ice.snow_in(ahead, 1.2)
	check.call(
		_pusher.load == 0.0 and after_dump - before_dump > carried * 0.8,
		"LMB sets the load down ahead as a mound (%.1f L)" % ((after_dump - before_dump) * 1000.0)
	)
	_pusher.toggle_raise()
	check.call(_pusher.raised, "RMB lifts the blade")
	_pusher.toggle_raise()
	_pusher.hang()
	check.call(not _pusher.held, "E hangs it back on the wall")
	# the net: carried from the bay and set down where you stand
	var net_eye: Vector3 = _net.to_global(Vector3(0.0, 1.6, -2.0))
	var net_dir: Vector3 = (_net.to_global(Vector3(0.0, 0.6, 0.5)) - net_eye).normalized()
	check.call(_net.aimed(net_eye, net_dir), "the net is under the dot from before its mouth")
	_net.carry(walker)
	check.call(_net.carried, "E picks it up")
	walker.global_position = Vector3(10.0, 0.05, 3.0)
	walker.face(0.0)
	_net.set_down()
	check.call(
		not _net.carried and _net.global_position.distance_to(Vector3(10.0, 0.0, 3.0 - 1.7)) < 0.05,
		"E sets it down ahead of where you stand (%s)" % _net.global_position
	)
	# skating: out to centre ice, strides build speed and mark the ice, a
	# hard turn gouges, a stop throws snow ahead
	_skates_on()
	check.call(
		_skater.active and walker.global_position.distance_to(SKATE_START) < 0.1,
		"E on the skates puts you at centre ice on them"
	)
	check.call(
		walker.driven and _skater.stick.visible, "... driven by the skates, the stick in view"
	)
	var sk0 := _local(walker.global_position)
	for step in 240:
		_skater.step(1.0 / 60.0, walker, ice, _local, _inside_the_sheet.bind(0.35), true, false)
	var sk_v := _skater.vel.length()
	var sk1 := _local(walker.global_position)
	check.call(
		sk_v > 4.0 and _skater.stride_count >= 5 and sk1.distance_to(sk0) > 8.0,
		(
			"four seconds of strides build speed (%.1f m/s, %d strides, %.1f m)"
			% [sk_v, _skater.stride_count, sk1.distance_to(sk0)]
		)
	)
	var track := ice.cell_at(sk0.lerp(sk1, 0.5) + Vector2(0.0, SkateWear.BLADE_GAP / 2))
	var lined := 0
	for dz in range(-2, 3):
		if ice.cut[ice.index(track.x, track.y + dz)] > 0.0:
			lined += 1
	check.call(lined > 0, "the glide leaves a blade line on the ice (%d cells)" % lined)
	# a hard turn: face well off the travel at speed
	walker.face(walker.rotation.y + 1.2)
	var gouged_before := _count_gouged(sk1, 6.0)
	for step in 90:
		_skater.step(1.0 / 60.0, walker, ice, _local, _inside_the_sheet.bind(0.35), false, false)
	var sk2 := _local(walker.global_position)
	var gouged := _count_gouged(sk1.lerp(sk2, 0.5), 6.0) - gouged_before
	check.call(
		gouged > 0, "a hard turn at speed gouges the outside edge's line (%d cells)" % gouged
	)
	# a stop: snow thrown ahead, the speed gone
	var stop_dir := _skater.vel.normalized()
	var stop_at := _local(walker.global_position)
	var snow_before := ice.snow_in(stop_at + stop_dir * 1.5, 2.0)
	for step in 90:
		_skater.step(1.0 / 60.0, walker, ice, _local, _inside_the_sheet.bind(0.35), false, true)
	var snow_after := ice.snow_in(stop_at + stop_dir * 1.5, 2.0)
	check.call(
		_skater.vel.length() < 0.5 and snow_after > snow_before,
		(
			"a hockey stop kills the speed and throws snow ahead (%.2f -> %.2f L)"
			% [snow_before * 1000.0, snow_after * 1000.0]
		)
	)
	# the puck: the game's model, on the ice ahead when the skates go on;
	# it rides the blade, a shot sends it off, the boards send it back,
	# and it counts in the net
	check.call(_puck.live and _puck.position.y < 0.01, "a puck is on the ice with you")
	# back to centre ice, still, the puck put on the blade
	walker.global_position = SKATE_START
	walker.face(PI / 2)
	_skater.vel = Vector2.ZERO
	_puck.at = _local(_skater.blade_world())
	_puck.vel = Vector2.ZERO
	_place_puck()
	var puck0 := _puck.at
	walker.face(walker.rotation.y)
	for step in 60:
		_skater.step(1.0 / 60.0, walker, ice, _local, _inside_the_sheet.bind(0.35), true, false)
		_puck_step(1.0 / 60.0)
	check.call(
		(
			_puck.at.distance_to(puck0) > 0.5
			and _puck.at.distance_to(_local(_skater.blade_world())) < 0.6
		),
		(
			"the puck under the blade goes with you (%.2f m, %.2f from the blade)"
			% [_puck.at.distance_to(puck0), _puck.at.distance_to(_local(_skater.blade_world()))]
		)
	)
	_shoot()
	var shot_v := _puck.vel.length()
	for step in 240:
		_puck.step(1.0 / 60.0, _inside_the_sheet.bind(DemoPuck.RADIUS))
	var inside: Vector2 = _inside_the_sheet.bind(DemoPuck.RADIUS).call(_puck.at)
	check.call(
		shot_v > 10.0 and inside == _puck.at,
		"LMB shoots it (%.1f m/s) and the boards keep it on the sheet" % shot_v
	)
	# into the net: the net set across the puck's path
	_puck.vel = Vector2.ZERO
	_puck.at = Vector2(20.0, 8.0)
	_place_puck()
	_net.global_position = ice.global_position + Vector3(24.0, 0.0, 8.0)
	_net.global_rotation = Vector3(0.0, PI / 2, 0.0)  # mouth toward -x, the puck
	var goals0 := goals
	_puck.vel = Vector2(8.0, 0.0)
	for step in 120:
		_puck_step(1.0 / 60.0)
	check.call(
		goals == goals0 + 1 and _net.holds(_puck.position) and _puck.vel == Vector2.ZERO,
		"a puck into the net counts a goal and stays (%d)" % (goals - goals0)
	)
	_skates_off()
	check.call(not _skater.active and not walker.driven, "E again takes the skates off")
	check.call(
		not _puck.live and _puck.position.distance_to(_skates.position) < 1.0,
		"the puck is back in the bay"
	)
	# the rink kit: the board sections and glass panels from the generator
	check.call(
		RinkKit.ids("board").size() == 5 and RinkKit.ids("glass").size() == 2,
		(
			"the kit has five board sections and two glass panels (%s %s)"
			% [RinkKit.ids("board"), RinkKit.ids("glass")]
		)
	)
	check.call(
		(
			absf(RinkKit.length_m("board_4m") - 4.0) < 0.01
			and absf(RinkKit.length_m("board_curve_quarter") - 3.36) < 0.02
		),
		"straight sections are their length, the quarter corner a 3.36 m chord"
	)
	var g8 := RinkKit.glass("glass_4x8")
	var pane: MeshInstance3D = g8.get_node("Pane")
	check.call(
		(
			pane != null
			and absf((pane.mesh as BoxMesh).size.y - 2.38) < 0.03
			and absf((pane.mesh as BoxMesh).size.x - 1.12) < 0.01
		),
		"the 8 ft glass has a see-through pane 4 ft wide between its posts"
	)
	g8.free()  # a loose body would leak at exit, which CI counts as an error
	check.call(
		_kit.get_child_count() == 7,
		"the kit is on show in the bay (%d pieces)" % _kit.get_child_count()
	)
	check.call(
		(
			_rink_pieces.get("board_curve_quarter", 0) == 16
			and _rink_pieces.get("board_4m", 0) == 22
			and _rink_pieces.get("glass_4x6", 0) > 120
		),
		"the rink's boards are the kit, the 6 ft glass all round (%s)" % _rink_pieces
	)
	walker.queue_free()
	walker = null
	ice.flush()
	# the heatmap: H colours the ice by height over the sheet's own range
	ice.fill_state(0.0, 0.0, 0.0, 0.0, 0.0)  # the piles and marks cleared
	ice.flush()
	var range_flat := ice.height_range()
	ice.pour(Vector2(RINK.x / 2, RINK.y / 2), 1.0, 6.0)  # deeper than the snow the edger threw
	ice.flush()
	var heat_t0 := Time.get_ticks_usec()
	var range0 := ice.height_range()
	var heat_ms := (Time.get_ticks_usec() - heat_t0) / 1000.0
	print("ice demo: height range read in %.1f ms" % heat_ms)
	check.call(
		range0.y > range_flat.y and range0.x == range_flat.x,
		"a puddle raises the sheet's high point and not its low (%s -> %s)" % [range_flat, range0]
	)
	set_heatmap(true)
	check.call(ice.material.get_shader_parameter("heatmap") == true, "H turns the heatmap on")
	check.call(
		ice.material.get_shader_parameter("heat_hi") > ice.material.get_shader_parameter("heat_lo"),
		"... with the range on the material"
	)
	check.call(heat_ms < 150.0, "the range reads in under 150 ms (%.0f)" % heat_ms)
	set_heatmap(false)
	check.call(ice.material.get_shader_parameter("heatmap") == false, "H again turns it off")
	print("ice demo: %d chunks, %d re-meshes" % [ice.chunk_count(), ice.remeshed])
	if _fails == 0:
		print("ice_demo test: all passed")
	get_tree().quit(1 if _fails else 0)
