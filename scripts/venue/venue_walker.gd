class_name VenueWalker
extends CharacterBody3D
## A person on foot in the venue: 1.8 m capsule, walks at 1.4 m/s (runs at
## 4), climbs steps up to STEP high, and collides only with the venue's
## physics layer. This is the seed of the explorable rink; for now it drives
## the walk-around playtest and the walkability test.
##
## Drive it with `wish` (a world-space direction, set by input or a test).

const HEIGHT := 1.8
const RADIUS := 0.3
const EYE := 1.65
const STEP := 0.32
const WALK := 1.4
const RUN := 4.0
const GRAVITY := 9.8

var wish := Vector3.ZERO
var running := false
var head: Node3D


func _init() -> void:
	collision_layer = 0
	collision_mask = 1 << (VenueKit.VENUE_LAYER - 1)
	floor_snap_length = STEP + 0.05
	floor_max_angle = deg_to_rad(50.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = HEIGHT
	cs.shape = cap
	cs.position.y = HEIGHT * 0.5
	add_child(cs)
	head = Node3D.new()
	head.position.y = EYE
	add_child(head)


func _physics_process(dt: float) -> void:
	var flat := Vector3(wish.x, 0, wish.z)
	if flat.length() > 1.0:
		flat = flat.normalized()
	var speed := RUN if running else WALK
	velocity.x = flat.x * speed
	velocity.z = flat.z * speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * dt
	_step_up(Vector3(velocity.x, 0, velocity.z) * dt)
	move_and_slide()


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
func nearest_spot(venue: Venue, forward: Vector3) -> VenueSpot:
	var eye := head.global_position if head else global_position + Vector3(0, 1.6, 0)
	var best: VenueSpot = null
	var best_score := INF
	for s in venue.all_spots():
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
