class_name Interactor
extends Node3D
## A person's reach into the world of objects: what is under the centre dot
## (one physics ray from `eye`, blocked by walls), the look-at highlight on
## it, the prompt line, and carrying.
##
##   interactor.eye = camera
##   interactor.objects = world_objects
##   interactor.hovered                 # the PropRow under the dot, or null
##   interactor.prompt()                # "Coffee mug   [E] take   [F] push   [RMB] inspect"
##   interactor.act("take")             # the verb on the hovered row (take starts a carry)
##   interactor.carrying                # the row in hand, or null
##   interactor.turn_held(0.3)          # radians, top over bottom (the wheel does this)
##   interactor.nudge_held(0.1)         # metres nearer or farther (ctrl + wheel)
##   interactor.drop()
##
## Carrying is real-time physics, never a freeze: the body keeps simulating
## while held, a velocity spring pulls it toward the hold point every
## physics step, so it bumps into shelves and walls on the way, and when
## dropped it keeps its motion as a throw. Only `take` into an inventory
## removes it from the world (see WorldObjects.act("take")).

signal hover_changed(row: PropRow)
signal carried(row: PropRow)
signal dropped(row: PropRow)

const REACH := 2.4
## The hold point: in front of the eyes past the thing's own size, a little below the line of sight.
const HOLD_GAP := 0.4
const HOLD_MIN := 0.55
const HOLD_MAX := 1.5
## One wheel notch while carrying: tumble it (top over bottom; four full
## turns of a 24-notch wheel for one revolution), or with ctrl held,
## nearer or farther.
const WHEEL_TURN := TAU / 96
const WHEEL_NUDGE := 0.1
const HOLD_DROP := 0.12
## The spring (per second) and the most pull it may give.
const SPRING := 14.0
const MAX_PULL := 7.0
const TURN_SPRING := 10.0
## Once it has reached the hand, held this far from the hold point (stuck
## behind something) it is let go; before that it has GRACE seconds to
## arrive (a thing picked off the floor starts well over a metre away).
const BREAK := 1.0
const GRACE := 1.5
const REACHED := 0.3
const THROW := 4.0
const HIGHLIGHT := 0.55

var eye: Node3D
var objects: WorldObjects
## Layers that block the look ray (walls, counters) besides props.
var wall_mask := Layers.mask([Layers.VENUE])
## Heavier than this and it won't come off the floor.
var max_carry_mass := 60.0

var hovered: PropRow
var carrying: PropRow
var _body: RigidBody3D
var _rel := Basis()
var _dist := 1.0
var _gravity := 1.0
var _damp := 0.0
var _mask := 0
var _reached := false
var _carry_t := 0.0


func _process(_dt: float) -> void:
	var row := _look()
	if row != hovered:
		if hovered:
			_set_highlight(hovered, 0.0)
		hovered = row
		if hovered:
			_set_highlight(hovered, HIGHLIGHT)
		hover_changed.emit(hovered)


func _unhandled_input(event: InputEvent) -> void:
	if carrying == null or not event is InputEventMouseButton or not event.pressed:
		return
	var notch := 0.0
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		notch = 1.0
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		notch = -1.0
	if notch == 0.0:
		return
	if event.ctrl_pressed:
		nudge_held(notch * WHEEL_NUDGE)
	else:
		turn_held(notch * WHEEL_TURN)
	get_viewport().set_input_as_handled()


func _physics_process(_dt: float) -> void:
	if carrying == null:
		return
	if _body == null or not is_instance_valid(_body) or carrying.node != _body:
		_let_go()
		return
	var target := _hold_point()
	var to := target - _body.global_position
	_carry_t += _dt
	if to.length() < REACHED:
		_reached = true
	if to.length() > BREAK and (_reached or _carry_t > GRACE):
		_let_go()
		return
	_body.linear_velocity = (to * SPRING).limit_length(MAX_PULL)
	# turn with the view (a quaternion's axis is undefined at zero angle,
	# and a non-finite velocity would make Jolt drop both velocities)
	var want := _yaw_basis() * _rel
	var q := (
		(want * _body.global_transform.basis.orthonormalized().inverse())
		. get_rotation_quaternion()
		. normalized()
	)
	var angle := q.get_angle()
	if angle > PI:
		angle -= TAU
	var spin := Vector3.ZERO
	if absf(angle) > 0.002:
		var axis := q.get_axis()
		if axis.is_finite():
			spin = axis.normalized() * angle * TURN_SPRING
	_body.angular_velocity = spin.limit_length(6.0)


# --- looking -------------------------------------------------------------


func _look() -> PropRow:
	if eye == null or objects == null or not eye.is_inside_tree():
		return null
	var from := eye.global_position
	var to := from - eye.global_transform.basis.z * REACH
	var mask := wall_mask
	for f in objects.fields:
		mask |= Layers.bit(f.layer)
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	if _body:
		q.exclude = [_body.get_rid()]
	var hit := eye.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var row := objects.row_of(hit)
	return row if row != carrying else null


## The prompt line for the hovered row (empty when nothing is there).
func prompt() -> String:
	if carrying:
		return (
			"%s   [E] drop   [F] throw   [wheel] turn   [ctrl+wheel] near/far"
			% objects.name_of(carrying).to_upper()
		)
	if hovered == null:
		return ""
	var parts: Array[String] = [objects.name_of(hovered).to_upper()]
	for v in objects.verbs_of(hovered):
		match v:
			"take":
				parts.append("[E] take")
			"inspect":
				parts.append("[RMB] inspect")
			"push":
				parts.append("[F] push")
			_:
				parts.append("[Q] %s" % v)
	return "   ".join(parts)


# --- acting --------------------------------------------------------------


## The verb on the hovered row. "take" picks it up into the hands (a game
## that wants it in an inventory calls objects.act("take") itself).
func act(verb: String) -> Variant:
	if carrying and verb in ["take", "drop"]:
		drop()
		return null
	if carrying and verb == "throw":
		drop(true)
		return null
	if hovered == null or objects == null:
		return null
	if verb == "take":
		return carry(hovered)
	var actor := eye if eye else self
	return objects.act(verb, hovered, actor)


## Picks the row up into the hands: it becomes (or stays) a live body and
## follows the view on a spring.
func carry(row: PropRow) -> bool:
	if row == null or ObjectCatalog.mass(String(row.prop)) > max_carry_mass:
		return false
	if not objects.can(row, "take") and not objects.can(row, "push"):
		return false
	var f := objects._field_of(row)
	var body := f.wake(row)
	if body == null:
		return false
	if carrying:
		drop()
	carrying = row
	_body = body
	_reached = false
	_carry_t = 0.0
	var box := row.world_aabb()
	_dist = clampf(box.size.length() * 0.5 + HOLD_GAP, HOLD_MIN, HOLD_MAX)
	_rel = _yaw_basis().inverse() * body.global_transform.basis.orthonormalized()
	_mask = body.collision_mask
	_gravity = body.gravity_scale
	_damp = body.angular_damp
	body.collision_mask = _mask & ~Layers.bit(Layers.WALKER)  # the walker doesn't shove what it carries
	body.gravity_scale = 0.0
	body.can_sleep = false
	body.angular_damp = 2.0
	_set_highlight(row, 0.0)
	carried.emit(row)
	return true


## Turns the held thing by `angle` (radians) about `axis` in view space:
## RIGHT tumbles it top over bottom (the wheel), UP spins it left to
## right. It keeps that turn relative to the view.
func turn_held(angle: float, axis := Vector3.RIGHT) -> void:
	if carrying:
		_rel = Basis(axis.normalized(), angle) * _rel


## Moves the hold point nearer (negative) or farther (positive), within
## reach.
func nudge_held(metres: float) -> void:
	if carrying:
		_dist = clampf(_dist + metres, HOLD_MIN, HOLD_MAX)


## Lets go where it is; `throw` adds the view's forward push.
func drop(throw := false) -> void:
	var row := carrying
	var body := _body
	_let_go()
	if row == null or body == null or not is_instance_valid(body):
		return
	body.linear_velocity = body.linear_velocity.limit_length(THROW)
	if throw and eye:
		body.linear_velocity = -eye.global_transform.basis.z * 6.0 + Vector3(0, 1.5, 0)
	body.angular_velocity = body.angular_velocity.limit_length(4.0)
	row.dirty = true
	dropped.emit(row)


func _let_go() -> void:
	if _body and is_instance_valid(_body):
		_body.collision_mask = _mask
		_body.gravity_scale = _gravity
		_body.angular_damp = _damp
		_body.can_sleep = true
	carrying = null
	_body = null


# --- helpers -------------------------------------------------------------


func _hold_point() -> Vector3:
	var b := eye.global_transform.basis
	return eye.global_position - b.z * _dist - Vector3(0, HOLD_DROP, 0)


func _yaw_basis() -> Basis:
	var fwd := -eye.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return Basis.IDENTITY
	return Basis.looking_at(fwd.normalized(), Vector3.UP)


func _set_highlight(row: PropRow, h: float) -> void:
	if objects:
		objects._field_of(row).set_highlight(row, h)
