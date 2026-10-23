class_name PropGrab
extends Node
## The walker's hands for loose things, the way My Summer Car does it: hold
## the left mouse on a loose prop under the centre dot (within REACH) and it
## floats in front of the eyes, following the view on a spring. It stays a
## physics body while held, so it bumps into walls and shelves instead of
## clipping through them (pulled too far behind something, it is let go).
## The wheel turns it; letting go drops it where it is, keeping a little of
## the view's motion as a throw, and it falls and settles.
##
## Anything in the "loose_props" group can be picked up: LooseProp (cups,
## bottles, pucks, cones, boxes, chairs, tools, bins) and StickProp. Fixed
## parts of the building (walls, counters, benches, stalls, machines, doors)
## are venue colliders, not bodies, and stay put.
##
##   grab.eye = camera        # VenueWalk sets it; the hold point hangs off it
##   grab.looked()            # the loose prop under the centre dot, or null
##   grab.try_pick()          # LMB down: picks up looked(); true when it did
##   grab.drop()              # LMB up
##   grab.turn_by(notches)    # the wheel: TURN_STEP a notch about the vertical

const REACH := 2.4
## Heavier than this and it won't come off the floor (nothing in the
## building is, for now; a full toolbox is about 40 kg).
const MAX_MASS := 60.0
## The hold point: this far in front of the eyes past the prop's own size,
## and a little below the line of sight.
const HOLD_GAP := 0.45
const HOLD_MIN := 0.55
const HOLD_MAX := 1.6
const HOLD_DROP := 0.12
## The spring (per second): a light prop snaps to the hold point, a heavy
## one lags. Speeds are capped so a pull is never a launch.
const SPRING := 14.0
const MAX_PULL := 7.0
const TURN_SPRING := 12.0
const MAX_TURN := 10.0
const TURN_STEP := PI / 12.0  # 15 degrees a wheel notch
## Held this far from the hold point once it got there (stuck behind a
## wall), it is let go; so is one that never gets there in REACH_TIME s.
const BREAK := 1.0
const REACH_TIME := 1.5
## The most of the view's motion a dropped prop keeps (m/s).
const THROW := 4.0

signal picked(body: RigidBody3D)
signal dropped(body: RigidBody3D)

var eye: Node3D
var held: RigidBody3D
## Wheel turns since the pick, in TURN_STEP notches.
var turns := 0
var _rel := Basis()       # the prop's basis relative to the view's yaw at the pick
var _centre := Vector3.ZERO  # the middle of its shape, in its own space
var _dist := 1.0
var _mask := 0
var _gravity := 1.0
var _damp := 0.0
var _reached := false
var _t := 0.0


## True when `n` is a loose thing a person could pick up.
static func grabbable(n: Object) -> bool:
	var b := n as RigidBody3D
	return b != null and b.is_in_group("loose_props") and b.mass <= MAX_MASS and not b.is_queued_for_deletion()


## The loose prop under the centre dot within REACH (walls and counters in
## the way block it), or null.
func looked() -> RigidBody3D:
	if eye == null or not eye.is_inside_tree():
		return null
	var from := eye.global_position
	var to := from - eye.global_transform.basis.z * REACH
	var mask := (1 << (VenueKit.VENUE_LAYER - 1)) | (1 << (StickProp.LAYER - 1))
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	var hit := eye.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not grabbable(hit.collider):
		return null
	return hit.collider as RigidBody3D


## What the [LMB] hint calls the prop.
static func name_of(b: RigidBody3D) -> String:
	if b is StickProp:
		return "STICK"
	var l = b.get("label")
	return str(l) if l != null and str(l) != "" else "IT"


func try_pick() -> bool:
	var b := looked()
	if b == null:
		return false
	pick(b)
	return true


func pick(b: RigidBody3D) -> void:
	if held:
		drop()
	held = b
	turns = 0
	_reached = false
	_t = 0.0
	var box := _shape_box(b)
	_centre = box.get_center()
	_dist = clampf(box.size.length() * 0.5 + HOLD_GAP, HOLD_MIN, HOLD_MAX)
	_rel = _yaw_basis().inverse() * b.global_transform.basis.orthonormalized()
	_mask = b.collision_mask
	_gravity = b.gravity_scale
	_damp = b.angular_damp
	if b.has_method("set_held"):
		b.call("set_held", true)
	else:
		b.freeze = false
		b.sleeping = false
	# the walker doesn't shove what it's carrying
	b.collision_mask = _mask & ~(1 << (StickProp.PUSH_LAYER - 1))
	b.gravity_scale = 0.0
	b.can_sleep = false
	b.angular_damp = 2.0
	picked.emit(b)


func drop() -> void:
	var b := held
	held = null
	if b == null or not is_instance_valid(b):
		return
	b.collision_mask = _mask
	b.gravity_scale = _gravity
	b.angular_damp = _damp
	b.can_sleep = true
	b.linear_velocity = b.linear_velocity.limit_length(THROW)
	b.angular_velocity = b.angular_velocity.limit_length(4.0)
	if b.has_method("set_held"):
		b.call("set_held", false)
	dropped.emit(b)


func turn_by(notches: int) -> void:
	if held:
		turns += notches


## Where the held prop's middle is pulled to.
func hold_point() -> Vector3:
	var xf := eye.global_transform
	return xf.origin - xf.basis.z * _dist - Vector3(0, HOLD_DROP, 0)


## The orientation the held prop is turned toward: as it was picked up,
## relative to the way you face (not up or down, so a cup stays upright),
## plus the wheel's turns.
func hold_basis() -> Basis:
	return _yaw_basis() * Basis(Vector3.UP, turns * TURN_STEP) * _rel


func _yaw_basis() -> Basis:
	var f := -eye.global_transform.basis.z if eye else Vector3.FORWARD
	return Basis(Vector3.UP, atan2(-f.x, -f.z))


func _physics_process(dt: float) -> void:
	if held == null:
		return
	if not is_instance_valid(held) or not held.is_inside_tree() or eye == null or not eye.is_inside_tree():
		held = null
		return
	var xf := held.global_transform
	var off := hold_point() - xf * _centre
	_t += dt
	if off.length() < 0.25:
		_reached = true
	if (_reached and off.length() > BREAK) or (not _reached and _t > REACH_TIME):
		drop()
		return
	var k := SPRING / (1.0 + held.mass / 15.0)
	held.linear_velocity = (off * k).limit_length(MAX_PULL)
	var q := Quaternion(hold_basis() * xf.basis.orthonormalized().inverse()).normalized()
	var angle := q.get_angle()
	if angle > PI:
		angle -= TAU
	var spin := Vector3.ZERO
	if absf(angle) > 0.001:
		spin = q.get_axis().normalized() * angle * TURN_SPRING
	held.angular_velocity = spin.limit_length(MAX_TURN)
	held.sleeping = false


## The box around a body's collision shapes, in its own space.
static func _shape_box(b: RigidBody3D) -> AABB:
	var out := AABB()
	var first := true
	for c in b.get_children():
		var cs := c as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		var half := Vector3.ONE * 0.05
		if cs.shape is BoxShape3D:
			half = (cs.shape as BoxShape3D).size * 0.5
		elif cs.shape is SphereShape3D:
			half = Vector3.ONE * (cs.shape as SphereShape3D).radius
		var box := cs.transform * AABB(-half, half * 2.0)
		out = box if first else out.merge(box)
		first = false
	return out
