class_name PickupGame
extends Node3D
## Shooting around in the gym (playtest #33): a real basketball that bounces
## at the owner's side while they walk the court, and shots they aim with the
## view and power with how long they hold the left mouse (or right trigger).
## The ball flies, hits the backboard and rim, and counts when it drops
## through the hoop. After SHOTS shots the rest of the half-hour game runs on
## and Training.pickup turns the minutes and makes into skill.
##
## Built by KitHud from the gym's ball-cart spot, which carries the rims and
## backboards in venue space. The gym draws them; this adds their colliders.

signal finished(shots: int, makes: int)

const SHOTS := 10
const MINUTES := 30
const BALL_R := 0.12
const BALL_MASS := 0.62
const RIM_R := 0.23
const RIM_TUBE := 0.012
const CHARGE_TIME := 1.3          # seconds to full power
const SPEED_MIN := 5.0            # m/s at a tap
const SPEED_MAX := 9.5            # at full charge
const LIFT := 0.8                 # radians a shot leaves above the view
const DRIBBLE_HAND := 0.85        # m above the floor where the hand meets it
const DRIBBLE_PUSH := 3.6         # m/s down out of the hand
const RETURN_AFTER := 3.0         # s after a shot until a teammate feeds it back

var walker: VenueWalker
var cam: Camera3D
var hoops: Array = []
var ball: RigidBody3D
var shots := 0
var makes := 0
## 0..1 while the shot is held, -1 otherwise.
var charge := -1.0
var _flying := 0.0                # seconds since the shot left, 0 dribbling
var _above := {}                  # rim index -> the ball was just over the ring
var _scored := false


static func create(walker_: VenueWalker, cam_: Camera3D, hoops_: Array) -> PickupGame:
	var g := PickupGame.new()
	g.walker = walker_
	g.cam = cam_
	g.hoops = hoops_
	return g


func _ready() -> void:
	for h in hoops:
		_build_hoop(h)
	ball = RigidBody3D.new()
	ball.mass = BALL_MASS
	ball.collision_layer = 0
	ball.collision_mask = 1 << (VenueKit.VENUE_LAYER - 1)
	ball.continuous_cd = true
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.78          # a pumped ball off hardwood
	mat.friction = 0.6
	ball.physics_material_override = mat
	ball.linear_damp = 0.05
	ball.angular_damp = 0.3
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = BALL_R
	col.shape = sph
	ball.add_child(col)
	var mesh := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = BALL_R
	sm.height = BALL_R * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("d4661c")
	m.roughness = 0.8
	sm.material = m
	mesh.mesh = sm
	ball.add_child(mesh)
	add_child(ball)
	ball.global_position = _hand() + Vector3(0, 0.1, 0)


## The rim as a ring of short capsules and the backboard as a box, on the
## venue's physics layer so the ball (and only the ball) hits them.
func _build_hoop(h: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1 << (VenueKit.VENUE_LAYER - 1)
	body.collision_mask = 0
	var rim := Vector3(float(h.rim[0]), float(h.rim[1]), float(h.rim[2]))
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.55
	body.physics_material_override = mat
	var n := 16
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := rim + Vector3(cos(a0), 0, sin(a0)) * RIM_R
		var p1 := rim + Vector3(cos(a1), 0, sin(a1)) * RIM_R
		var c := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = RIM_TUBE
		cap.height = p0.distance_to(p1) + RIM_TUBE * 2.0
		c.shape = cap
		var dir := (p1 - p0).normalized()
		c.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), (p0 + p1) * 0.5)
		body.add_child(c)
	var board := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.06, 1.05, 1.8)
	board.shape = box
	board.position = Vector3(float(h.board), 3.425, rim.z)
	body.add_child(board)
	add_child(body)


## Where the ball meets the hand: at the walker's right side, a little ahead.
func _hand() -> Vector3:
	var b := walker.global_transform.basis
	return walker.global_position + b.x * 0.35 - b.z * 0.35 + Vector3(0, DRIBBLE_HAND, 0)


## Where a gathered ball sits: in front of the chest, below the eyes.
func _set_point() -> Vector3:
	return walker.head.global_position - cam.global_transform.basis.z * 0.35 + Vector3(0, -0.25, 0)


func _physics_process(dt: float) -> void:
	if _flying > 0.0:
		_flying += dt
		_check_score()
		if _flying > RETURN_AFTER or (_flying > 0.8 and ball.linear_velocity.length() < 0.4):
			_feed()
		return
	if charge >= 0.0:
		charge = minf(1.0, charge + dt / CHARGE_TIME)
		# gathered: held up by the chest, ready to go
		ball.global_position = _set_point()
		ball.linear_velocity = walker.velocity
		return
	_dribble()


## The auto-dribble: whenever the ball comes up to the hand it's pushed back
## down toward the floor ahead of where the walker will be.
func _dribble() -> void:
	var hand := _hand()
	var p := ball.global_position
	var flat := Vector2(p.x - hand.x, p.z - hand.z)
	if flat.length() > 2.0 or p.y < -1.0:
		_feed()
		return
	if p.y >= hand.y - 0.1 and ball.linear_velocity.y < 0.6:
		var lead := walker.velocity * 0.35
		var to := Vector3(hand.x + lead.x - p.x, 0, hand.z + lead.z - p.z) / 0.3
		ball.linear_velocity = Vector3(to.x, -DRIBBLE_PUSH, to.z)
		ball.angular_velocity = Vector3.ZERO


## Starts the shot (LMB / RT down).
func hold() -> void:
	if _flying == 0.0 and charge < 0.0 and shots < SHOTS:
		charge = 0.0


## Lets it go along the view, lifted, at the charged speed.
func release() -> void:
	if charge < 0.0:
		return
	var fwd := -cam.global_transform.basis.z
	var right := fwd.cross(Vector3.UP).normalized()
	ball.global_position = _set_point() + Vector3(0, 0.3, 0)  # up and out of the hands
	var dir := fwd.rotated(right, LIFT).normalized() if right.length() > 0.01 else Vector3.UP
	ball.linear_velocity = dir * lerpf(SPEED_MIN, SPEED_MAX, charge) + walker.velocity * 0.5
	ball.angular_velocity = right * -6.0  # backspin
	charge = -1.0
	_flying = 0.001
	_scored = false
	_above.clear()
	shots += 1


## Through the hoop: the centre drops through the rim plane inside the ring.
func _check_score() -> void:
	if _scored:
		return
	var p := ball.global_position
	for i in hoops.size():
		var rim := Vector3(float(hoops[i].rim[0]), float(hoops[i].rim[1]), float(hoops[i].rim[2]))
		var off := Vector2(p.x - rim.x, p.z - rim.z).length()
		var above := p.y > rim.y
		if _above.get(i, false) and not above and off < RIM_R - RIM_TUBE and ball.linear_velocity.y < 0.0:
			_scored = true
			makes += 1
		# over the ring last step (a ball from under the hoop doesn't count)
		_above[i] = above and off < RIM_R * 1.6


## A teammate passes it back; after the last shot the game's done.
func _feed() -> void:
	_flying = 0.0
	if shots >= SHOTS:
		finished.emit(shots, makes)
		return
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.global_position = _hand() + Vector3(0, 0.05, 0)


func status() -> String:
	var hint := "HOLD LMB / RT TO SHOOT, LET GO TO RELEASE" if charge < 0.0 else "POWER %d%%" % int(charge * 100.0)
	return "PICKUP  %d/%d SHOTS  %d IN   %s" % [shots, SHOTS, makes, hint]
