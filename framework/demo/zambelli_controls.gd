class_name ZambelliControls
extends Node3D
## The Zambelli's operator console: the controls the demo can aim at and
## work. Each is a prop from the bought model (tools/propgen/zambelli_lever.py
## takes a lever out of the GLB at 3 mm) hung on a pivot the machine
## registers with `add_lever()`; the demo rays at their aim areas, shows
## `prompt()` for the one under the dot, and calls `toggle()` (E) or
## `scroll()` (the wheel). The poses follow the machine's state, so a
## pass that switches the augers on throws their levers too.
##
## So far: the horizontal auger's lever, the leftmost of the row.

enum Kind { DRIVE, AUGER_H, AUGER_V, COND, BIN, BLADE, FLOOD, WASH }

const LAYER := 6  # a collision layer of their own for the aim ray
const REACH := 2.6
const DECK_Y := 1.644
const LEVER_TILT := deg_to_rad(30.0)  # the auger levers: back is on, as modelled is off
const SELECT_TILT := deg_to_rad(20.0)  # drive select: F forward, N, R back
const MOMENT_TILT := deg_to_rad(20.0)  # conditioner and bin: a push, then neutral
const MOMENT_HOLD := 1.2  # seconds a pushed lever stays over before it springs back
const TURN_MM := 0.5  # the handwheel: one turn of blade travel
const BLADE_MAX := 3.0  # mm, fully raised (+) to fully lowered (-)
const NOTCH := 1.0 / 16.0  # a wheel notch, turns
const VALVE_NOTCH := 0.05  # a wheel notch on a valve
const DRIVE_NAMES := ["FORWARD", "NEUTRAL", "REVERSE"]

static var _glow_mat: StandardMaterial3D

var machine: Zambelli
var hovered := -1
var _controls: Array[Dictionary] = []


## A lever: `pivot` is the node the lever's meshes hang from, placed at
## the lever's foot, that tilts about its x; `size` and `at` are the aim
## box in the pivot's frame.
func add_lever(kind: Kind, label: String, pivot: Node3D, size: Vector3, at: Vector3) -> void:
	var meshes: Array[MeshInstance3D] = []
	for n in pivot.get_children():
		if n is MeshInstance3D:
			meshes.append(n)
	_controls.append(
		{
			"kind": kind,
			"name": label,
			"pivot": pivot,
			"axis": "x",
			"meshes": meshes,
			"area": _area(pivot, size, at),
			"angle": 0.0,
			"push": 0.0,
			"hold": 0.0
		}
	)


func _process(dt: float) -> void:
	if machine == null:
		return
	for c in _controls:
		var target := _target_angle(c)
		if c.hold > 0.0:
			c.hold -= dt
			if c.hold <= 0.0:
				c.push = 0.0
		var rate: float = 6.0 if c.kind == Kind.BLADE else 5.0
		c.angle = lerpf(c.angle, target, minf(rate * dt, 1.0))
		var pivot: Node3D = c.pivot
		match c.axis:
			"x":
				pivot.rotation = Vector3(c.angle, 0.0, 0.0)
			"y":
				pivot.rotation = Vector3(0.0, c.angle, 0.0)
			"z":
				pivot.rotation = Vector3(0.0, 0.0, c.angle)


## The control the view ray hits, or -1.
func aim(from: Vector3, dir: Vector3) -> int:
	if not is_inside_tree():
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


func set_hover(i: int) -> void:
	if i == hovered:
		return
	if hovered >= 0:
		_glow(_controls[hovered], false)
	hovered = i
	if hovered >= 0:
		_glow(_controls[hovered], true)


## The HUD line for a control: its name, its state and what the keys do.
func prompt(i: int) -> String:
	if i < 0 or i >= _controls.size() or machine == null:
		return ""
	var c := _controls[i]
	match c.kind:
		Kind.DRIVE:
			return "%s: %s   [E] NEXT" % [c.name, DRIVE_NAMES[machine.drive]]
		Kind.AUGER_H:
			return "%s: %s   [E] TOGGLE" % [c.name, "ON" if machine.auger_on else "OFF"]
		Kind.AUGER_V:
			return "%s: %s   [E] TOGGLE" % [c.name, "ON" if machine.lift_on else "OFF"]
		Kind.COND:
			var st := "DOWN" if machine.is_down() else ("UP" if machine.lift <= 0.001 else "MOVING")
			return "%s: %s   [E] %s" % [c.name, st, "RAISE" if machine.cond_down else "LOWER"]
		Kind.BIN:
			return (
				"%s: %s   [E] %s"
				% [
					c.name,
					"UP" if machine.bin_up else "DOWN",
					"LOWER" if machine.bin_up else "RAISE"
				]
			)
		Kind.BLADE:
			return (
				"BLADE: %s, %+.2f MM   [WHEEL] TURN (1/16)"
				% [turns_text(machine.blade_mm), machine.blade_mm]
			)
		Kind.FLOOD:
			return "%s: %d%% OPEN   [WHEEL] VALVE" % [c.name, roundi(machine.flood * 100.0)]
		Kind.WASH:
			return "%s: %d%% OPEN   [WHEEL] VALVE" % [c.name, roundi(machine.wash * 100.0)]
	return ""


## E on a lever.
func toggle(i: int) -> void:
	if i < 0 or i >= _controls.size() or machine == null:
		return
	var c := _controls[i]
	match c.kind:
		Kind.DRIVE:
			machine.drive = (machine.drive + 1) % 3
		Kind.AUGER_H:
			machine.auger_on = not machine.auger_on
		Kind.AUGER_V:
			machine.lift_on = not machine.lift_on
		Kind.COND:
			machine.cond_down = not machine.cond_down
			c.push = MOMENT_TILT if machine.cond_down else -MOMENT_TILT  # back is down
			c.hold = MOMENT_HOLD
		Kind.BIN:
			machine.set_bin(not machine.bin_up)
			c.push = -MOMENT_TILT if machine.bin_up else MOMENT_TILT  # forward is up
			c.hold = MOMENT_HOLD


## The wheel on the handwheel or a valve: `notches` up (+) or down (-).
## Wheel down turns the handwheel clockwise, which lowers the blade.
func scroll(i: int, notches: float) -> void:
	if i < 0 or i >= _controls.size() or machine == null:
		return
	var c := _controls[i]
	match c.kind:
		Kind.BLADE:
			var turns := snappedf(machine.blade_mm / TURN_MM + notches * NOTCH, NOTCH)
			machine.blade_mm = clampf(turns * TURN_MM, -BLADE_MAX, BLADE_MAX)
		Kind.FLOOD:
			machine.flood = clampf(
				snappedf(machine.flood + notches * VALVE_NOTCH, VALVE_NOTCH), 0.0, 1.0
			)
		Kind.WASH:
			machine.wash = clampf(
				snappedf(machine.wash + notches * VALVE_NOTCH, VALVE_NOTCH), 0.0, 1.0
			)


## "2 3/16 TURNS DOWN" from the blade's level: turns clockwise from flush.
static func turns_text(blade_mm: float) -> String:
	var sixteenths := roundi(absf(blade_mm) / TURN_MM * 16.0)
	if sixteenths == 0:
		return "FLUSH"
	var whole := sixteenths / 16
	var rest := sixteenths % 16
	var frac := ""
	if rest > 0:
		var g := 16
		var n := rest
		while n % 2 == 0:
			n /= 2
			g /= 2
		frac = "%d/%d" % [n, g]
	var parts: Array[String] = []
	if whole > 0:
		parts.append(str(whole))
	if frac != "":
		parts.append(frac)
	var s := " ".join(parts)
	var one := sixteenths == 16
	return "%s TURN%s %s" % [s, "" if one else "S", "DOWN" if blade_mm < 0.0 else "UP"]


func _target_angle(c: Dictionary) -> float:
	match c.kind:
		Kind.DRIVE:
			return [-SELECT_TILT, 0.0, SELECT_TILT][machine.drive]
		Kind.AUGER_H:
			return LEVER_TILT if machine.auger_on else 0.0
		Kind.AUGER_V:
			return LEVER_TILT if machine.lift_on else 0.0
		Kind.COND, Kind.BIN:
			return c.push
		Kind.BLADE:
			# clockwise, seen by the operator behind it facing forward (-Z), lowers
			return (BLADE_MAX - machine.blade_mm) / TURN_MM * TAU * -1.0
		Kind.FLOOD:
			return machine.flood * PI / 2  # a quarter turn anticlockwise from above
		Kind.WASH:
			return -machine.wash * PI / 2  # clockwise
	return 0.0


func _area(parent: Node3D, size: Vector3, at: Vector3) -> Area3D:
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
	parent.add_child(a)
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
