class_name PlantRoom
extends Node3D
## The plant room behind the Zamboni bay: the compressors, the chiller, the
## brine tank and pump along the far wall, the supply and return headers on
## the rink-side wall with a valve wheel per zone of floor circuits, and the
## control wall with the set point dial, the stage switches, the pump and
## warm loop switches, the trip lamps and reset buttons, and the gauges.
## Every control is aimed at and used the way the Zambelli's are: an Area3D
## of its own on the controls' layer, [E] to switch, the wheel to turn.

enum Kind { SET_POINT, STAGE, RESET, PUMP, PUMP_SPEED, WARM, ZONE }

const ROOM_D := 6.0  # metres past the bay's back wall
const ROOM_W := ZamboniBay.BAY_W
const WALL_H := ZamboniBay.WALL_H
const WALL_T := ZamboniBay.WALL_T
const ZONES := 13  # header valves, each a run of neighbouring circuits
const ZONE_Z0 := -1.2  # the first zone's drop, metres across the room
const ZONE_DZ := 0.4
const HEADER_Y := 2.5  # the supply header, above the door; the return a little under it
const RETURN_Y := 2.2
const WHEEL_Y := 1.4
const PANEL_X := 2.0  # the control panel's middle along the room
const PANEL_Y := 1.55
const REACH := 2.6
const LAYER := ZambelliControls.LAYER
const WALL := Color("8f8c84")
const ROOF := Color("3a3b3f")
const FLOOR := Color("63666a")
const STEEL := Color("5a5d63")
const JACKET := Color("d8d8d2")  # insulated pipe
const SUPPLY := Color("2d5fb8")
const RETURN := Color("3f8c8a")
const WARM := Color("d9772b")
const PANEL := Color("3d4047")
const BRASS := Color("b08d3c")
const LAMP_OFF := Color("4a4a4e")
const LAMP_RUN := Color("3fcf6a")
const LAMP_TRIP := Color("e0433a")

var plant: IcePlant
var zone_open := PackedFloat32Array()
var _controls: Array[Dictionary] = []
var _hover := -1
var _mats := {}
var _glow_mat: StandardMaterial3D
var _lamps: Array[MeshInstance3D] = []
var _gauges: Label3D
var _gauge_t := 0.0
var _level: MeshInstance3D
var _origin_x := 0.0


## Build the room with its near wall's inner face at world `x0` (the bay's
## back wall is that wall; its door is cut by the bay), run by `for_plant`.
func build(x0: float, for_plant: IcePlant) -> void:
	plant = for_plant
	_origin_x = x0
	position = Vector3(x0, 0.0, 0.0)
	zone_open.resize(ZONES)
	zone_open.fill(1.0)
	var shell := StaticBody3D.new()
	shell.name = "Shell"
	shell.collision_layer = Layers.bit(Layers.VENUE)
	shell.collision_mask = 0
	add_child(shell)
	var mid := ROOM_D / 2
	_box(shell, Vector3(mid, -0.1, 0.0), Vector3(ROOM_D, 0.2, ROOM_W), FLOOR)
	_box(
		shell,
		Vector3(ROOM_D + WALL_T / 2, WALL_H / 2, 0.0),
		Vector3(WALL_T, WALL_H, ROOM_W + 2 * WALL_T),
		WALL
	)
	for s: float in [-1.0, 1.0]:
		_box(
			shell,
			Vector3(mid, WALL_H / 2, s * (ROOM_W + WALL_T) / 2),
			Vector3(ROOM_D, WALL_H, WALL_T),
			WALL
		)
	_box(
		shell,
		Vector3(mid, WALL_H + 0.1, 0.0),
		Vector3(ROOM_D + WALL_T, 0.2, ROOM_W + 2 * WALL_T),
		ROOF
	)
	for z: float in [-2.0, 2.0]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(mid, WALL_H - 0.3, z)
		lamp.light_color = Color(0.95, 0.97, 1.0)
		lamp.light_energy = 2.2
		lamp.omni_range = 8.0
		lamp.shadow_enabled = false
		add_child(lamp)
	_machines(shell)
	_headers(shell)
	_panel(shell)


func _machines(shell: StaticBody3D) -> void:
	var fx := ROOM_D - 1.0  # the far wall's row of machines
	# two compressor stages: a base, a motor across it, a lamp on the front
	for s in IcePlant.STAGES:
		var z := 2.9 - 1.4 * s
		_box(shell, Vector3(fx, 0.4, z), Vector3(1.2, 0.8, 1.0), Color("2f4f3a"))
		_cyl(self, Vector3(fx, 1.05, z), 0.25, 1.0, Vector3.RIGHT, STEEL)
		_box(shell, Vector3(fx, 0.84, z + 0.3), Vector3(0.5, 0.08, 0.3), STEEL)
		var lamp := _mesh(
			self, Vector3(fx - 0.62, 0.95, z - 0.3), Vector3(0.04, 0.1, 0.1), LAMP_OFF
		)
		_lamps.append(lamp)
		_label(Vector3(fx - 0.62, 0.55, z), "STAGE %d" % (s + 1), -PI / 2, 0.0025)
	# the chiller: a long insulated shell on two saddles, the stages' refrigerant lines to it
	_cyl(self, Vector3(fx, 0.95, -0.9), 0.35, 2.4, Vector3.BACK, JACKET)
	for z: float in [-1.8, 0.0]:
		_box(shell, Vector3(fx, 0.3, z), Vector3(0.9, 0.6, 0.2), STEEL)
	for s in IcePlant.STAGES:
		var z := 2.9 - 1.4 * s
		_cyl(self, Vector3(fx + 0.3, 1.5, (z - 0.9) / 2), 0.03, z + 0.9, Vector3.BACK, STEEL)
		_cyl(self, Vector3(fx + 0.3, 1.35, z), 0.03, 0.4, Vector3.UP, STEEL)
	_cyl(self, Vector3(fx + 0.3, 1.4, -0.9), 0.03, 0.4, Vector3.UP, STEEL)
	# the brine tank, with a sight glass on its room side
	_box(shell, Vector3(fx, 0.8, -3.0), Vector3(1.4, 1.6, 1.4), Color("4f5a6a"))
	_mesh(self, Vector3(fx - 0.71, 0.8, -3.0), Vector3(0.02, 1.4, 0.07), Color("e8ecef"))
	_level = _mesh(self, Vector3(fx - 0.715, 0.66, -3.0), Vector3(0.03, 1.12, 0.05), SUPPLY)
	_label(Vector3(fx - 0.72, 1.7, -3.0), "BRINE TANK  9 000 L", -PI / 2, 0.0025)
	# the chiller's brine side: tank to chiller and back
	_cyl(self, Vector3(fx, 1.35, -2.0), 0.06, 0.6, Vector3.BACK, JACKET)
	# the pump beside the tank: a volute on the suction line, its motor behind
	var px := fx - 1.6
	_cyl(self, Vector3(fx - 0.9, 0.35, -3.3), 0.08, 0.6, Vector3.RIGHT, SUPPLY)
	_cyl(self, Vector3(px + 0.3, 0.35, -3.3), 0.24, 0.3, Vector3.RIGHT, STEEL)
	_cyl(self, Vector3(px + 0.75, 0.35, -3.3), 0.16, 0.5, Vector3.RIGHT, Color("2f4f3a"))
	_box(shell, Vector3(px + 0.5, 0.1, -3.3), Vector3(1.1, 0.2, 0.6), STEEL)
	_label(Vector3(px + 0.5, 0.75, -3.3), "BRINE PUMP", -PI / 2, 0.0025)
	# its discharge: along the floor to the near wall, up to the supply header
	_cyl(self, Vector3(px / 2 + 0.15, 0.35, -3.5), 0.08, px + 0.3, Vector3.RIGHT, SUPPLY)
	_cyl(self, Vector3(0.3, HEADER_Y / 2 + 0.17, -3.5), 0.08, HEADER_Y - 0.35, Vector3.UP, SUPPLY)
	# the return header's end, across the room to the tank's top
	_cyl(self, Vector3(fx / 2 + 0.15, RETURN_Y, -3.3), 0.08, fx - 0.3, Vector3.RIGHT, RETURN)
	_cyl(self, Vector3(fx, RETURN_Y / 2 + 0.8, -3.3), 0.08, RETURN_Y - 1.6, Vector3.UP, RETURN)
	# the warm loop: recovered heat off the compressors' discharge, a small
	# pump, and the glycol down into the floor under the slab
	_cyl(self, Vector3(fx - 0.9, 0.5, 2.2), 0.03, 0.5, Vector3.UP, WARM)
	_cyl(self, Vector3(fx - 1.3, 0.25, 2.2), 0.03, 0.8, Vector3.RIGHT, WARM)
	_cyl(self, Vector3(fx - 1.7, 0.25, 2.2), 0.1, 0.25, Vector3.RIGHT, STEEL)
	_cyl(self, Vector3(fx - 2.1, 0.25, 2.2), 0.03, 0.5, Vector3.RIGHT, WARM)
	_cyl(self, Vector3(fx - 2.35, 0.12, 2.2), 0.03, 0.25, Vector3.UP, WARM)
	_label(Vector3(fx - 1.7, 0.55, 2.2), "WARM LOOP", -PI / 2, 0.002)


func _headers(shell: StaticBody3D) -> void:
	var z0 := -3.5
	var z1 := ZONE_Z0 + ZONE_DZ * (ZONES - 1) + 0.3
	var zm := (z0 + z1) / 2
	_cyl(self, Vector3(0.3, HEADER_Y, zm), 0.1, z1 - z0, Vector3.BACK, SUPPLY)
	_cyl(self, Vector3(0.3, RETURN_Y, zm - 0.1), 0.1, z1 - z0 - 0.2, Vector3.BACK, RETURN)
	_label(Vector3(0.42, HEADER_Y + 0.2, 0.6), "SUPPLY HEADER", PI / 2, 0.0025)
	_label(Vector3(0.42, RETURN_Y - 0.2, 0.6), "RETURN HEADER", PI / 2, 0.0025)
	for k in ZONES:
		var z := ZONE_Z0 + ZONE_DZ * k
		# the drops: supply down into the floor, the return up out of it
		_cyl(self, Vector3(0.3, HEADER_Y / 2, z - 0.09), 0.04, HEADER_Y, Vector3.UP, SUPPLY)
		_cyl(self, Vector3(0.3, RETURN_Y / 2, z + 0.09), 0.04, RETURN_Y, Vector3.UP, RETURN)
		# the zone valve on the supply drop: a handwheel on a stem toward the room
		var pivot := Node3D.new()
		pivot.position = Vector3(0.46, WHEEL_Y, z - 0.09)
		add_child(pivot)
		var wheel := _cyl(pivot, Vector3.ZERO, 0.09, 0.02, Vector3.RIGHT, BRASS)
		_mesh(pivot, Vector3.ZERO, Vector3(0.02, 0.16, 0.02), STEEL)
		_mesh(pivot, Vector3.ZERO, Vector3(0.02, 0.02, 0.16), STEEL)
		var stem := _cyl(self, Vector3(0.38, WHEEL_Y, z - 0.09), 0.025, 0.14, Vector3.RIGHT, STEEL)
		_label(Vector3(0.42, WHEEL_Y - 0.2, z - 0.09), "%d" % (k + 1), PI / 2, 0.002)
		_add(
			Kind.ZONE,
			k,
			_area(Vector3(0.2, 0.3, 0.3), Vector3(0.42, WHEEL_Y, z - 0.09)),
			[wheel, stem],
			pivot
		)
	_box(shell, Vector3(0.3, 0.1, zm), Vector3(0.5, 0.2, z1 - z0), STEEL)  # the trench cover


func _panel(shell: StaticBody3D) -> void:
	var zw := ROOM_W / 2  # the control wall: the room's +z side
	var y := PANEL_Y + 0.2
	_box(shell, Vector3(PANEL_X, PANEL_Y, zw - 0.04), Vector3(2.8, 1.3, 0.08), PANEL)
	_label(Vector3(PANEL_X, PANEL_Y + 0.55, zw - 0.09), "BRINE PLANT", PI, 0.0018)
	# the set point dial: a knob with a pointer, turned with the wheel
	var dial_pivot := Node3D.new()
	dial_pivot.position = Vector3(PANEL_X - 1.0, y, zw - 0.12)
	add_child(dial_pivot)
	var dial := _cyl(dial_pivot, Vector3.ZERO, 0.1, 0.06, Vector3.BACK, STEEL)
	_mesh(dial_pivot, Vector3(0.0, 0.05, -0.035), Vector3(0.02, 0.1, 0.01), Color("e8ecef"))
	_label(Vector3(PANEL_X - 1.0, y - 0.2, zw - 0.09), "SET POINT", PI, 0.0011)
	_add(
		Kind.SET_POINT,
		0,
		_area(Vector3(0.28, 0.28, 0.2), Vector3(PANEL_X - 1.0, y, zw - 0.12)),
		[dial],
		dial_pivot
	)
	# the stage switches, their lamps and reset buttons
	for s in IcePlant.STAGES:
		var x := PANEL_X - 0.5 + 0.35 * s
		var plate := _mesh(self, Vector3(x, y, zw - 0.1), Vector3(0.12, 0.2, 0.03), STEEL)
		var lever := _mesh(
			self, Vector3(x, y, zw - 0.14), Vector3(0.05, 0.05, 0.06), Color("e8ecef")
		)
		var lamp := _mesh(self, Vector3(x, y + 0.17, zw - 0.1), Vector3(0.08, 0.05, 0.03), LAMP_OFF)
		_lamps.append(lamp)
		_label(Vector3(x, y - 0.2, zw - 0.09), "STAGE %d" % (s + 1), PI, 0.0011)
		_add(
			Kind.STAGE,
			s,
			_area(Vector3(0.16, 0.24, 0.16), Vector3(x, y, zw - 0.12)),
			[plate],
			lever
		)
		var button := _cyl(
			self, Vector3(x, y - 0.32, zw - 0.1), 0.03, 0.04, Vector3.BACK, LAMP_TRIP
		)
		_label(Vector3(x, y - 0.42, zw - 0.09), "RESET", PI, 0.0009)
		_add(
			Kind.RESET, s, _area(Vector3(0.1, 0.1, 0.12), Vector3(x, y - 0.32, zw - 0.1)), [button]
		)
	# the pump switch and speed dial
	var px := PANEL_X + 0.35
	var pump_plate := _mesh(self, Vector3(px, y, zw - 0.1), Vector3(0.12, 0.2, 0.03), STEEL)
	var pump_lever := _mesh(
		self, Vector3(px, y, zw - 0.14), Vector3(0.05, 0.05, 0.06), Color("e8ecef")
	)
	_label(Vector3(px, y - 0.2, zw - 0.09), "BRINE PUMP", PI, 0.0011)
	_add(
		Kind.PUMP,
		0,
		_area(Vector3(0.16, 0.24, 0.16), Vector3(px, y, zw - 0.12)),
		[pump_plate],
		pump_lever
	)
	var speed_pivot := Node3D.new()
	speed_pivot.position = Vector3(px + 0.4, y, zw - 0.12)
	add_child(speed_pivot)
	var speed := _cyl(speed_pivot, Vector3.ZERO, 0.08, 0.06, Vector3.BACK, STEEL)
	_mesh(speed_pivot, Vector3(0.0, 0.04, -0.035), Vector3(0.02, 0.08, 0.01), Color("e8ecef"))
	_label(Vector3(px + 0.4, y - 0.2, zw - 0.09), "SPEED", PI, 0.0011)
	_add(
		Kind.PUMP_SPEED,
		0,
		_area(Vector3(0.24, 0.24, 0.2), Vector3(px + 0.4, y, zw - 0.12)),
		[speed],
		speed_pivot
	)
	# the warm loop switch
	var wx := PANEL_X + 1.15
	var warm_plate := _mesh(self, Vector3(wx, y, zw - 0.1), Vector3(0.12, 0.2, 0.03), STEEL)
	var warm_lever := _mesh(self, Vector3(wx, y, zw - 0.14), Vector3(0.05, 0.05, 0.06), WARM)
	_label(Vector3(wx, y - 0.2, zw - 0.09), "WARM LOOP", PI, 0.0011)
	_add(
		Kind.WARM,
		0,
		_area(Vector3(0.16, 0.24, 0.16), Vector3(wx, y, zw - 0.12)),
		[warm_plate],
		warm_lever
	)
	# the gauges: one plate of figures under the controls
	_gauges = _label(Vector3(PANEL_X, PANEL_Y - 0.4, zw - 0.09), "", PI, 0.0012)
	_refresh_gauges()
	# the start-up card, laminated, beside the panel
	_mesh(
		self,
		Vector3(PANEL_X + 1.95, PANEL_Y + 0.05, zw - 0.03),
		Vector3(0.55, 0.75, 0.02),
		Color("efe9d6")
	)
	var card := _label(Vector3(PANEL_X + 1.95, PANEL_Y + 0.05, zw - 0.05), "", PI, 0.0008)
	card.modulate = Color(0.12, 0.12, 0.14)
	card.text = (
		"COLD START\n\n1  TANK LEVEL, BRINE 1.20\n2  PUMP 60 %, WATCH KPA\n"
		+ "3  ZONES OPEN, CENTRE OUT\n4  STAGE 1 AUTO, WAIT\n5  STAGE 2 IF RETURN WARM\n6  WARM LOOP ON"
	)


func _process(dt: float) -> void:
	if plant == null:
		return
	_gauge_t += dt
	if _gauge_t > 0.25:
		_gauge_t = 0.0
		_refresh_gauges()
	for c in _controls:
		match c.kind:
			Kind.SET_POINT:
				# -12 at the left stop, -4 at the right: a turn and a half between
				var f := (
					(plant.set_point - IcePlant.SET_MIN) / (IcePlant.SET_MAX - IcePlant.SET_MIN)
				)
				c.knob.rotation.z = lerpf(0.75 * PI, -0.75 * PI, f)
			Kind.PUMP_SPEED:
				c.knob.rotation.z = lerpf(0.75 * PI, -0.75 * PI, plant.pump_speed)
			Kind.STAGE:
				c.knob.position.y = PANEL_Y + 0.2 + 0.055 * (plant.stage_mode[c.idx] - 1)
			Kind.PUMP:
				c.knob.position.y = PANEL_Y + 0.2 + (0.05 if plant.pump_on else -0.05)
			Kind.WARM:
				c.knob.position.y = PANEL_Y + 0.2 + (0.05 if plant.warm_on else -0.05)
			Kind.ZONE:
				c.knob.rotation.x = zone_open[c.idx] * 1.5 * PI
	for s in IcePlant.STAGES:
		var colour := LAMP_OFF
		if plant.trip[s] != IcePlant.Trip.NONE:
			colour = LAMP_TRIP
		elif plant.stage_on[s]:
			colour = LAMP_RUN
		_lamp(_lamps[s], colour)
		_lamp(_lamps[IcePlant.STAGES + s], colour)


func _refresh_gauges() -> void:
	if _gauges == null:
		return
	var f := plant.pad
	_gauges.text = (
		(
			"SUPPLY %5.1f C    RETURN %5.1f C    HEADER %3.0f KPA    OUTSIDE %4.1f C\n"
			+ "GROUND %5.1f C    HEAVE %4.1f MM    STAGE HOURS %.0f / %.0f    %.0f KWH"
		)
		% [
			plant.supply_c(),
			plant.return_c(),
			plant.header_kpa(),
			plant.outside_c,
			f.ground_min(),
			f.heave_max(),
			plant.hours[0],
			plant.hours[1],
			plant.kwh
		]
	)


## The control under the view line, or -1.
func aim(from: Vector3, dir: Vector3) -> int:
	if not is_inside_tree() or _controls.is_empty():
		return -1
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * REACH, 1 << (LAYER - 1))
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return -1
	for i in _controls.size():
		if _controls[i].area == hit.collider:
			return i
	return -1


func control_count() -> int:
	return _controls.size()


func kind_of(i: int) -> int:
	return _controls[i].kind


## The control of a kind (and index), for a test or a view.
func find(kind: int, idx := 0) -> int:
	for i in _controls.size():
		if _controls[i].kind == kind and _controls[i].idx == idx:
			return i
	return -1


func set_hover(i: int) -> void:
	if i == _hover:
		return
	if _hover >= 0:
		_glow(_controls[_hover], false)
	_hover = i
	if _hover >= 0:
		_glow(_controls[_hover], true)


func prompt(i: int) -> String:
	var c := _controls[i]
	match c.kind:
		Kind.SET_POINT:
			return "SET POINT %.1f C   [WHEEL] TURN" % plant.set_point
		Kind.STAGE:
			return "STAGE %d %s   [E] OFF / AUTO / HAND" % [c.idx + 1, plant.stage_text(c.idx)]
		Kind.RESET:
			if plant.trip[c.idx] != IcePlant.Trip.NONE:
				return (
					"STAGE %d TRIPPED: %s   [E] RESET"
					% [c.idx + 1, IcePlant.TRIP_NAMES[plant.trip[c.idx]]]
				)
			return "STAGE %d RESET   [E] PRESS" % (c.idx + 1)
		Kind.PUMP:
			return "BRINE PUMP %s   [E] SWITCH" % ("ON" if plant.pump_on else "OFF")
		Kind.PUMP_SPEED:
			return "PUMP SPEED %.0f%%   [WHEEL] TURN" % (plant.pump_speed * 100.0)
		Kind.WARM:
			return "WARM LOOP %s   [E] SWITCH" % ("ON" if plant.warm_on else "OFF")
		Kind.ZONE:
			return (
				"HEADER ZONE %d VALVE %s   [E] OPEN / SHUT   [WHEEL] THROTTLE"
				% [c.idx + 1, _valve_text(zone_open[c.idx])]
			)
	return ""


## [E] on a control. What happened, for the toast.
func toggle(i: int) -> String:
	var c := _controls[i]
	match c.kind:
		Kind.STAGE:
			plant.cycle_mode(c.idx)
			return "STAGE %d %s" % [c.idx + 1, IcePlant.MODE_NAMES[plant.stage_mode[c.idx]]]
		Kind.RESET:
			if plant.trip[c.idx] == IcePlant.Trip.NONE:
				return "STAGE %d: NO TRIP" % (c.idx + 1)
			if plant.reset(c.idx):
				return "STAGE %d RESET" % (c.idx + 1)
			if plant.lockout[c.idx] > 0.0:
				return "STAGE %d LOCKED OUT %.0f S" % [c.idx + 1, plant.lockout[c.idx]]
			return (
				"STAGE %d: %s, CLEAR THE CAUSE FIRST"
				% [c.idx + 1, IcePlant.TRIP_NAMES[plant.trip[c.idx]]]
			)
		Kind.PUMP:
			plant.pump_on = not plant.pump_on
			return "BRINE PUMP %s" % ("ON" if plant.pump_on else "OFF")
		Kind.WARM:
			plant.warm_on = not plant.warm_on
			return "WARM LOOP %s" % ("ON" if plant.warm_on else "OFF")
		Kind.ZONE:
			set_zone(c.idx, 0.0 if zone_open[c.idx] > 0.5 else 1.0)
			return "ZONE %d VALVE %s" % [c.idx + 1, _valve_text(zone_open[c.idx])]
		Kind.SET_POINT:
			return "SET POINT %.1f C: TURN IT WITH THE WHEEL" % plant.set_point
		Kind.PUMP_SPEED:
			return "PUMP SPEED %.0f%%: TURN IT WITH THE WHEEL" % (plant.pump_speed * 100.0)
	return ""


## The wheel on a control, `notches` up (+) or down.
func scroll(i: int, notches: float) -> String:
	var c := _controls[i]
	match c.kind:
		Kind.SET_POINT:
			plant.turn_set_point(notches)
			return "SET POINT %.1f C" % plant.set_point
		Kind.PUMP_SPEED:
			plant.pump_speed = clampf(plant.pump_speed + 0.05 * notches, 0.0, 1.0)
			return "PUMP SPEED %.0f%%" % (plant.pump_speed * 100.0)
		Kind.ZONE:
			set_zone(c.idx, zone_open[c.idx] + 0.1 * notches)
			return "ZONE %d VALVE %s" % [c.idx + 1, _valve_text(zone_open[c.idx])]
	return toggle(i)


## A zone valve, 0 shut .. 1 open, on the floor's circuits.
func set_zone(zone: int, open: float) -> void:
	zone_open[zone] = clampf(open, 0.0, 1.0)
	plant.pad.set_zone(zone, ZONES, zone_open[zone])


static func _valve_text(open: float) -> String:
	if open <= 0.0:
		return "SHUT"
	if open >= 1.0:
		return "OPEN"
	return "%.0f%%" % (open * 100.0)


func _add(kind: int, idx: int, area: Area3D, meshes: Array, knob: Node3D = null) -> void:
	_controls.append({"kind": kind, "idx": idx, "area": area, "meshes": meshes, "knob": knob})


func _area(size: Vector3, at: Vector3) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = 1 << (LAYER - 1)
	a.collision_mask = 0
	a.monitoring = false
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = at
	a.add_child(cs)
	add_child(a)
	return a


func _glow(c: Dictionary, on: bool) -> void:
	if _glow_mat == null:
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.albedo_color = Color(1.0, 0.95, 0.6, 0.25)
		_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow_mat.emission_enabled = true
		_glow_mat.emission = Color(0.9, 0.8, 0.3)
		_glow_mat.emission_energy_multiplier = 0.8
		_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for mi: MeshInstance3D in c.meshes:
		mi.material_overlay = _glow_mat if on else null


func _lamp(mi: MeshInstance3D, colour: Color) -> void:
	var m := mi.material_override as StandardMaterial3D
	if m == null or m.albedo_color == colour:
		return
	var lit := StandardMaterial3D.new()
	lit.albedo_color = colour
	if colour != LAMP_OFF:
		lit.emission_enabled = true
		lit.emission = colour
		lit.emission_energy_multiplier = 1.5
	mi.material_override = lit


func _mat(colour: Color) -> StandardMaterial3D:
	if _mats.has(colour):
		return _mats[colour]
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.75
	_mats[colour] = m
	return m


func _box(body: StaticBody3D, at: Vector3, size: Vector3, colour: Color) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = at
	body.add_child(cs)
	_mesh(self, at, size, colour)


func _mesh(parent: Node3D, at: Vector3, size: Vector3, colour: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(colour)
	mi.position = at
	parent.add_child(mi)
	return mi


## A cylinder of radius `r`, `length` long along `axis` (x, y or z), centred at `at`.
func _cyl(
	parent: Node3D, at: Vector3, r: float, length: float, axis: Vector3, colour: Color
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = length
	cm.radial_segments = 16
	mi.mesh = cm
	mi.material_override = _mat(colour)
	mi.position = at
	if axis == Vector3.RIGHT:
		mi.rotation.z = PI / 2
	elif axis == Vector3.BACK:
		mi.rotation.x = PI / 2
	parent.add_child(mi)
	return mi


## Text on a wall, turned `yaw` about the vertical: 0 reads from +z, PI from -z, PI/2 from +x.
func _label(at: Vector3, text: String, yaw: float, pixel: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = pixel
	l.position = at
	l.rotation.y = yaw
	l.modulate = Color(0.92, 0.93, 0.95)
	l.outline_size = 4
	add_child(l)
	return l
