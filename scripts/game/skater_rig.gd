class_name SkaterRig
extends Node3D
## Voxel character rig: a hierarchy of VoxelParts posed procedurally each
## frame (skating stride, lean into turns, hockey-stop slide, falls, and
## two-hand stick IK so the stick follows the simulated blade).

const V := Models.V
const HIP_Y := 12 * V
const STICK_LEN := 23.5 * V

var goalie := false
var body: Node3D
var hips: VoxelPart
var torso: VoxelPart
var head: VoxelPart
var arm_l: VoxelPart
var arm_r: VoxelPart
var leg_l: VoxelPart
var leg_r: VoxelPart
var stick: VoxelPart

var _phase := 0.0
var _stride := 0.0
var _lean := 0.0
var _brake := 0.0
var _fall := 0.0
var _bf := 0.0


func build(pal: Dictionary, is_goalie: bool) -> void:
	goalie = is_goalie
	body = Node3D.new()
	add_child(body)
	hips = VoxelPart.make(Models.pants(pal, goalie))
	hips.position.y = HIP_Y
	body.add_child(hips)
	var leg_x := (2.6 if goalie else 2.0) * V
	leg_l = VoxelPart.make(Models.leg(pal, goalie))
	leg_l.position = Vector3(-leg_x, 0, 0)
	hips.add_child(leg_l)
	leg_r = VoxelPart.make(Models.leg(pal, goalie))
	leg_r.position = Vector3(leg_x, 0, 0)
	hips.add_child(leg_r)
	torso = VoxelPart.make(Models.torso(pal, goalie))
	torso.position.y = 3 * V
	hips.add_child(torso)
	head = VoxelPart.make(Models.head(pal, goalie))
	head.position.y = (10 if goalie else 9) * V
	torso.add_child(head)
	var arm_x := (6.5 if goalie else 5.5) * V
	var arm_y := (10 if goalie else 9) * V
	arm_l = VoxelPart.make(Models.arm(pal, "glove" if goalie else "skater"))
	arm_l.position = Vector3(-arm_x, arm_y, 0)
	torso.add_child(arm_l)
	arm_r = VoxelPart.make(Models.arm(pal, "blocker" if goalie else "skater"))
	arm_r.position = Vector3(arm_x, arm_y, 0)
	torso.add_child(arm_r)
	stick = VoxelPart.make(Models.stick(pal, goalie))
	add_child(stick)


func update_skater(s: Skater, dt: float) -> void:
	var speed := Vector2(s.vel.x, s.vel.z).length()
	var k := clampf(speed / 8.5, 0.0, 1.0)
	var pushing := s.ctrl.move.length() > 0.2 and not s.braking and s.stun_timer <= 0.0
	var smooth := 1.0 - exp(-8.0 * dt)
	_stride = lerpf(_stride, (0.25 + 0.45 * k) if pushing else 0.0, 1.0 - exp(-5.0 * dt))
	_phase += dt * (3.2 + speed * 0.9)
	var sp := sin(_phase)
	# skating stride pushes each leg out to the side in turn
	leg_l.rotation = Vector3(sp * 0.3 * _stride, 0, -maxf(0.0, sp) * _stride * 0.8 - 0.06)
	leg_r.rotation = Vector3(-sp * 0.3 * _stride, 0, maxf(0.0, -sp) * _stride * 0.8 + 0.06)
	hips.position.y = HIP_Y - 0.03 - 0.05 * k
	torso.rotation.x = lerpf(torso.rotation.x, -(0.18 + 0.4 * k) + s.windup() * 0.15, smooth)
	torso.rotation.y = lerpf(torso.rotation.y, s.windup() * 0.5, smooth)
	head.rotation.x = -torso.rotation.x * 0.7
	_lean = lerpf(_lean, clampf(s.yaw_rate * speed * 0.05, -0.45, 0.45), smooth)
	_brake = lerpf(_brake, 1.15 if s.braking else 0.0, 1.0 - exp(-12.0 * dt))
	_fall = lerpf(_fall, 1.0 if s.stun_timer > 0.25 else 0.0, 1.0 - exp(-7.0 * dt))
	body.rotation = Vector3(_fall * 1.35, _brake, _lean + _brake * 0.25)

	# stick: heel follows the simulated blade, the shaft points at the hands
	var heel := to_local(s.blade_pos)
	heel.y = s.blade_height
	var flat := Vector3(heel.x, 0, heel.z)
	var hand := Vector3(0.05, 0.95 - 0.08 * k, -0.15) + flat * 0.22 + Vector3(0, s.blade_height * 0.5, 0)
	_pose_stick(heel, hand, flat)


func update_goalie(g: Goalie, dt: float) -> void:
	var smooth := 1.0 - exp(-14.0 * dt)
	_bf = lerpf(_bf, 1.0 if g.butterfly_timer > 0.0 else 0.0, smooth)
	hips.position.y = lerpf(HIP_Y - 0.1, 0.34, _bf)
	leg_l.rotation = Vector3(lerpf(0.0, -0.25, _bf), 0, -lerpf(0.14, 1.35, _bf))
	leg_r.rotation = Vector3(lerpf(0.0, -0.25, _bf), 0, lerpf(0.14, 1.35, _bf))
	torso.rotation.x = -0.18
	head.rotation.x = 0.1
	# the reaching hand goes to the predicted puck spot, the other stays ready
	var reach := Vector3(g.reach.x, g.reach.y, -0.4)
	var glove_rest := Vector3(-0.5, 0.85 - _bf * 0.3, -0.35)
	var blocker_rest := Vector3(0.45, 0.7 - _bf * 0.3, -0.35)
	_aim_arm(arm_l, to_global(reach if g.reach.x < 0.0 else glove_rest))
	_aim_arm(arm_r, to_global(reach if g.reach.x >= 0.0 else blocker_rest))
	var heel := Vector3(-0.25, 0, -0.55)
	var hand := Vector3(0.35, 0.65, -0.3)
	var stick_basis := _stick_basis(heel, hand, Vector3.RIGHT)
	stick.transform = Transform3D(stick_basis, heel)


func _pose_stick(heel: Vector3, hand: Vector3, flat: Vector3) -> void:
	var toe := Vector3.UP.cross(flat.normalized()) if flat.length() > 0.05 else Vector3.LEFT
	var b := _stick_basis(heel, hand, toe)
	stick.transform = Transform3D(b, heel)
	var butt := heel + b.y * STICK_LEN
	_aim_arm(arm_l, to_global(butt - b.y * 0.05))
	_aim_arm(arm_r, to_global(heel + b.y * STICK_LEN * 0.6))


func _stick_basis(heel: Vector3, hand: Vector3, toe: Vector3) -> Basis:
	var y := hand - heel
	y = y.normalized() if y.length() > 0.01 else Vector3.UP
	var x := toe - y * toe.dot(y)
	x = x.normalized() if x.length() > 0.01 else Vector3.RIGHT
	return Basis(x, y, x.cross(y))


## Rotates an arm (which hangs along its local -Y) so the hand points at `target`.
func _aim_arm(arm: Node3D, target: Vector3) -> void:
	var parent := arm.get_parent() as Node3D
	var t := parent.to_local(target) - arm.position
	if t.length() < 0.01:
		return
	var up := -t.normalized()
	var x := Vector3.RIGHT - up * Vector3.RIGHT.dot(up)
	x = x.normalized() if x.length() > 0.01 else Vector3.FORWARD
	arm.basis = Basis(x, up, x.cross(up))
