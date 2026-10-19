class_name VenueWalker
extends CharacterBody3D
## A person on foot in the venue: 1.8 m capsule, walks at 2.2 m/s and
## sprints at 6.5 (building up over 0.4 s), hops about 0.45 m,
## crouches to 1.2 m (eyes at 1.1 m) to get under pipes and machines,
## climbs steps up to STEP high, and collides only with the venue's physics
## layer. It drives the walk (venue_walk.gd) and the walkability tests.
##
## Drive it with `wish` (a world-space direction), `running`, `crouch` (held)
## and `jump()` (a press), set by input or a test.

const HEIGHT := 1.8
const RADIUS := 0.3
const EYE := 1.65
const STEP := 0.32
const WALK := 2.2
const RUN := 6.5
const GRAVITY := 9.8
## Jump apex above the floor, and the take-off speed that reaches it.
const JUMP_HEIGHT := 0.45
const JUMP_SPEED := 2.97  # sqrt(2 * GRAVITY * JUMP_HEIGHT)
## Crouched: capsule height, eye height and speed.
const CROUCH_HEIGHT := 1.2
const CROUCH_EYE := 1.1
const CROUCH_SPEED := 1.0
## Seconds for a sprint to build from walking pace to full speed. On the
## ground the walker turns and stops at once; in the air it keeps its
## momentum and can only steer a little (AIR_ACCEL, m/s^2).
const SPRINT_RAMP := 0.4
const AIR_ACCEL := 3.0

var wish := Vector3.ZERO
var running := false
## Multiplies every pace: 0.5 on the ice in shoes (IceBalance), 0 while down.
var speed_scale := 1.0
## Held to crouch; the walker stays down while there is no room to stand.
var crouch := false
var crouched := false
var head: Node3D
var _shape: CollisionShape3D
var _jump_queued := false
var _sprint := 0.0  # 0 walking pace .. 1 full sprint


func _init() -> void:
	collision_layer = 0
	collision_mask = 1 << (VenueKit.VENUE_LAYER - 1)
	floor_snap_length = STEP + 0.05
	floor_max_angle = deg_to_rad(50.0)
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = HEIGHT
	_shape.shape = cap
	_shape.position.y = HEIGHT * 0.5
	add_child(_shape)
	head = Node3D.new()
	head.position.y = EYE
	add_child(head)


## A jump press: takes off on the next physics tick if standing on a floor.
func jump() -> void:
	_jump_queued = true


func height() -> float:
	return CROUCH_HEIGHT if crouched else HEIGHT


func _physics_process(dt: float) -> void:
	_update_crouch()
	var flat := Vector3(wish.x, 0, wish.z)
	if flat.length() > 1.0:
		flat = flat.normalized()
	var sprinting := running and not crouched and flat.length() > 0.1
	if is_on_floor() or not sprinting:
		_sprint = move_toward(_sprint, 1.0 if sprinting else 0.0, dt / SPRINT_RAMP)
	var speed := CROUCH_SPEED if crouched else lerpf(WALK, RUN, _sprint)
	var target := flat * speed * speed_scale
	if is_on_floor():
		velocity.x = target.x
		velocity.z = target.z
	else:
		var h := Vector2(velocity.x, velocity.z).move_toward(Vector2(target.x, target.z), AIR_ACCEL * dt)
		velocity.x = h.x
		velocity.z = h.y
	if is_on_floor():
		velocity.y = 0.0
		if _jump_queued and not crouched:
			velocity.y = JUMP_SPEED
	else:
		velocity.y -= GRAVITY * dt
	_jump_queued = false
	_step_up(Vector3(velocity.x, 0, velocity.z) * dt)
	move_and_slide()
	head.position.y = move_toward(head.position.y, CROUCH_EYE if crouched else EYE, 4.0 * dt)


## Crouches at once; stands back up only when the full height fits.
func _update_crouch() -> void:
	if crouch == crouched:
		return
	if not crouch and test_move(global_transform, Vector3(0, HEIGHT - CROUCH_HEIGHT, 0)):
		return  # a ceiling, pipe or machine overhead: stay down
	crouched = crouch
	var cap := _shape.shape as CapsuleShape3D
	cap.height = height()
	_shape.position.y = height() * 0.5


## Lifts the walker onto a step when the way ahead is blocked low down but
## clear STEP higher.
func _step_up(motion: Vector3) -> void:
	if motion.length() < 0.0001 or not is_on_floor():
		return
	var probe := motion.normalized() * maxf(motion.length(), 0.08)
	if not test_move(global_transform, probe):
		return
	var up := Vector3(0, STEP, 0)
	if test_move(global_transform, up):
		return
	if not test_move(global_transform.translated(up), probe):
		global_position += up


## The nearest door within reach, or null.
## The spot the walker is looking at: within its reach, in front of the head
## (within about 50 degrees of `forward`), the closest to the line of sight.
func nearest_spot(venue: Venue, forward: Vector3, extra: Array[VenueSpot] = []) -> VenueSpot:
	var eye := head.global_position if head else global_position + Vector3(0, 1.6, 0)
	var best: VenueSpot = null
	var best_score := INF
	for s in venue.all_spots() + extra:
		if not s.is_inside_tree():
			continue
		var to := s.global_position - eye
		var flat := Vector2(s.global_position.x - global_position.x, s.global_position.z - global_position.z).length()
		if flat > s.reach or absf(to.y) > 2.2:
			continue
		var d := to.length()
		var cosang := to.dot(forward) / maxf(d, 0.001)
		if cosang < 0.64:
			continue
		var score := d * (2.0 - cosang)
		if score < best_score:
			best_score = score
			best = s
	return best


func nearest_door(venue: Venue, reach := 2.0) -> VenueDoor:
	var best: VenueDoor = null
	var best_d := reach
	for d in venue.all_doors():
		var dist := d.global_position.distance_to(global_position)
		if dist < best_d:
			best_d = dist
			best = d
	return best
