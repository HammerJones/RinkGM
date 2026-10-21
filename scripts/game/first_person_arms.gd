class_name FirstPersonArms
extends Node3D
## The player's own arms in first person, for the plant room jobs: the same
## upper arm and forearm parts and the same two-bone IK as the body
## (SkaterRig), hung from shoulders just below and behind the eye. Make it a
## child of the first-person camera. At rest the hands sit low in the corners
## of the view and bob a little with walking; give a hand a point in `reach`
## and it goes there (a valve wheel, a breaker, a bolt), the elbow bending
## out and down like a real arm.
##
## The parts draw on VIEW_LAYER only, so the camera that shows these arms
## should leave out the body's own arms (PersonRig.hide_from_view does that).

const NONE := Vector3.INF
## Render layer (1-based) the first-person arms draw on.
const VIEW_LAYER := 11
## Shoulders, from the eye: across, down, back (metres).
const SHOULDER := Vector3(0.21, -0.36, 0.16)
## Where a resting hand sits in view: across, down, forward from the eye.
const REST := Vector3(0.24, -0.36, -0.38)
## The arms are drawn this much slimmer than the body's, so they frame the
## view instead of filling it (as first-person games do).
const SLIM := 0.6

## Where each hand reaches (world space, 0 = left, 1 = right), or NONE.
var reach: Array[Vector3] = [NONE, NONE]

var uppers: Array[VoxelPart] = []
var forearms: Array[VoxelPart] = []
var _hand: Array[Vector3] = [NONE, NONE]
var _w: Array[float] = [0.0, 0.0]
var _bob := 0.0


func build(pal: Dictionary) -> void:
	for i in 2:
		var up := VoxelPart.make(Models.upper_arm(pal))
		var fa := VoxelPart.make(Models.forearm(pal))
		for part in [up, fa]:
			part.layers = 1 << (VIEW_LAYER - 1)
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			part.top_level = true
			add_child(part)
		uppers.append(up)
		forearms.append(fa)


## Poses the arms for this frame. `speed` is how fast the player walks (m/s),
## for the bob.
func update_arms(speed: float, dt: float) -> void:
	var T := AnimTuning.current()
	var eye := get_parent() as Node3D
	if eye == null:
		return
	# shoulders follow the body's heading, not the head's pitch
	var fwd := -eye.global_basis.z
	var yaw := atan2(-fwd.x, -fwd.z)
	var body := Basis(Vector3.UP, yaw)
	var origin := eye.global_position
	_bob += dt * lerpf(0.0, T.walk_cadence * PI, clampf(speed / VenueWalker.WALK, 0.0, 1.5))
	var k := T.grip_arm_length
	var l1 := SkaterRig.UPPER_ARM * k
	var l2 := SkaterRig.FOREARM * k
	for i in 2:
		var sd := -1.0 if i == 0 else 1.0
		var sh := origin + body * Vector3(sd * SHOULDER.x, SHOULDER.y, SHOULDER.z)
		var bob := Vector3(0.0, absf(sin(_bob + i * PI)) * 0.015, 0.0) * minf(speed, 1.5)
		var rest := eye.global_transform * (Vector3(sd * REST.x, REST.y, REST.z) + bob)
		_w[i] = lerpf(_w[i], 1.0 if reach[i] != NONE else 0.0, 1.0 - exp(-T.reach_speed * dt))
		if reach[i] != NONE:
			_hand[i] = reach[i] if _hand[i] == NONE else _hand[i].lerp(reach[i], 1.0 - exp(-T.reach_speed * 2.0 * dt))
		var target := rest.lerp(_hand[i], _w[i]) if _hand[i] != NONE else rest
		var root := sh
		var over := root.distance_to(target) - (l1 + l2)
		if over > 0.0:
			root += (target - root).normalized() * minf(over, SkaterRig.SHOULDER_REACH)
		var elbow := SkaterRig._two_bone(root, target, l1, l2, body * Vector3(sd, -0.6, 0.4))
		var hand := root + (target - root).limit_length(l1 + l2 - 0.002)
		var stretch := Basis.from_scale(Vector3(SLIM, k, SLIM))
		uppers[i].global_transform = Transform3D(SkaterRig._basis_along(root - elbow, yaw) * stretch, root)
		forearms[i].global_transform = Transform3D(SkaterRig._basis_along(elbow - hand, yaw) * stretch, elbow)


## Where hand `i` is now (world space): the middle of the glove.
func hand_pos(i: int) -> Vector3:
	return forearms[i].global_transform * Vector3(0.0, -SkaterRig.FOREARM, 0.0)
