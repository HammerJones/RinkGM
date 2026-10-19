class_name AnimPerson
extends Node3D
## A person on foot on the animation studio's treadmill: a PersonRig (the
## skater's body without skates or stick) plus first-person arms on an eye
## camera, and the props the on-foot clips work at (a bench, a low machine
## panel standing in for Doris and the compressors, and markers showing
## where the hands are meant to land). A clip sets where the person walks,
## their pose, what each hand reaches for and what they look at; the rig
## does the animating, exactly as it would behind a VenueWalker.

## Render layer the body's own head and arms move to, so the first-person
## camera can leave them out and show FirstPersonArms instead.
const BODY_LAYER := 12

var rig: PersonRig
var arms: FirstPersonArms
var eye: Camera3D
## Walking velocity the clip asks for (world, m/s); vel eases towards it.
var go := Vector3.ZERO
var vel := Vector3.ZERO
var accel := 6.0
## First-person clip: the eye camera shows the view and FirstPersonArms reach.
var first_person := false
## Crouched, as VenueWalker.crouched.
var crouched := false
## Height off the floor and vertical speed in a jump (VenueWalker's numbers).
var y := 0.0
var vy := 0.0
const JUMP_SPEED := 2.97

var bench: MeshInstance3D
var panel: MeshInstance3D
var wheel: MeshInstance3D
var markers: Array[MeshInstance3D] = []


func setup(pal: Dictionary) -> void:
	rig = PersonRig.new()
	add_child(rig)
	rig.build_person(pal)
	rig.hide_from_view(BODY_LAYER)
	eye = Camera3D.new()
	eye.fov = 70.0
	eye.near = 0.05
	eye.cull_mask &= ~(1 << (BODY_LAYER - 1))
	add_child(eye)
	arms = FirstPersonArms.new()
	eye.add_child(arms)
	arms.build(pal)
	bench = _box(Vector3(1.2, 0.45, 0.4), Color("6b5a48"))
	panel = _box(Vector3(0.8, 0.9, 0.5), Color("8a9298"))
	wheel = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.1
	ring.outer_radius = 0.125
	wheel.mesh = ring
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color("c0392b")
	wheel.material_override = wmat
	add_child(wheel)
	for i in 2:
		var m := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.03
		s.height = 0.06
		m.mesh = s
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("ffb000") if i == 0 else Color("33ff66")
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.material_override = mat
		add_child(m)
		markers.append(m)


func _box(size: Vector3, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	m.material_override = mat
	add_child(m)
	return m


## Back to standing still facing forward, nothing in hand, props away.
func restart() -> void:
	go = Vector3.ZERO
	vel = Vector3.ZERO
	first_person = false
	crouched = false
	accel = 6.0
	y = 0.0
	vy = 0.0
	rig.position = Vector3.ZERO
	rig.pose = PersonRig.Pose.STAND
	rig.seat = PersonRig.NONE
	rig.facing = Vector3.FORWARD
	rig.look = PersonRig.NONE
	clear_intent()
	bench.visible = false
	panel.visible = false
	wheel.visible = false


## Clears the per-frame intent; clips set what they need after this.
func clear_intent() -> void:
	rig.reach = [PersonRig.NONE, PersonRig.NONE]
	arms.reach = [FirstPersonArms.NONE, FirstPersonArms.NONE]


## Takes off, if on the floor.
func jump() -> void:
	if y <= 0.0:
		vy = JUMP_SPEED


## Applies this frame's intent and poses the rig.
func step(dt: float) -> void:
	vel = vel.move_toward(go, accel * dt)
	position = Vector3.ZERO
	# a jump is the only thing that leaves the floor on the treadmill
	if vy != 0.0 or y > 0.0:
		vy -= VenueWalker.GRAVITY * dt
		y += vy * dt
		if y <= 0.0:
			y = 0.0
			vy = 0.0
	rig.position.y = y
	rig.airborne = y > 0.0
	rig.crouched = crouched
	rig.update_person(Vector3(vel.x, vy, vel.z), dt)
	# the eye sits in the head and looks where the head looks
	var h := rig.head.global_transform
	eye.global_transform = Transform3D(h.basis.orthonormalized(), h * Vector3(0.0, 0.13, -0.08))
	arms.update_arms(vel.length(), dt)
	for i in 2:
		var r: Vector3 = arms.reach[i] if first_person else rig.reach[i]
		markers[i].visible = r != PersonRig.NONE
		if markers[i].visible:
			markers[i].global_position = r


## Shows the valve wheel facing the person, its centre at `at` (body
## space), turned `angle` radians.
func show_wheel(at: Vector3, radius: float, angle: float) -> void:
	wheel.visible = true
	var s := radius / 0.1125
	wheel.global_basis = rig.global_basis * Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, angle) * Basis.from_scale(Vector3(s, s, s))
	wheel.global_position = rig.to_global(at)


## Where a hand is now, on whichever arms the clip shows.
func hand_pos(i: int) -> Vector3:
	return arms.hand_pos(i) if first_person else rig.hand_pos(i)


## The way the body faces (for the studio's cameras).
func heading() -> Vector3:
	return rig.facing
