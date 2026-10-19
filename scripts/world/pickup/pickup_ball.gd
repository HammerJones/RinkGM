class_name PickupBall
extends RigidBody3D
## The gym's basketball: a real, bouncing size 7 ball (24 cm, 0.62 kg) in
## 3 cm voxels with its black seams. While someone dribbles or holds it, the
## game carries it (frozen, kinematic); shots, passes and rebounds are free
## flight on the physics server against the court's own colliders, so a
## missed jumper rattles off the real rim and backboard.
##
## `hit(kind, at, strength)` fires on every contact: kind is "floor",
## "wall", "rim" or "board"; strength 0..1 from the speed going in.

signal hit(kind: String, at: Vector3, strength: float)

const RADIUS := 0.12
const MASS := 0.62
const V := 0.03
const ORANGE := Color("c8642a")
const SEAM := Color("2b1a12")
## The court's collision layer (bit 20): only the ball and PickupRun's
## floor, walls, rims and backboards are on it, so nothing else in the
## building notices the ball and the ball notices nothing else.
const LAYER := 1 << 19

var held := false
var _pending: Array = []   # [velocity, spin] to set free with
var _last_v := Vector3.ZERO
var _mesh: MeshInstance3D


func _init() -> void:
	name = "Basketball"
	mass = MASS
	collision_layer = LAYER
	collision_mask = LAYER
	continuous_cd = true
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 4
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.4
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.78
	pm.friction = 0.7
	physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = RADIUS
	cs.shape = sh
	add_child(cs)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = mesh()
	add_child(_mesh)
	body_entered.connect(_on_body_entered)


static var _cached: ArrayMesh

## The voxel ball, centred on its middle.
static func mesh() -> ArrayMesh:
	if _cached:
		return _cached
	var m := VoxelModel.new(V)
	m.jitter = 0.05
	for x in 8:
		for y in 8:
			for z in 8:
				var d := Vector3(x + 0.5, y + 0.5, z + 0.5) - Vector3(4, 4, 4)
				if d.length() > 4.1:
					continue
				var seam := absf(d.x) < 0.6 or absf(d.y) < 0.6 or absf(Vector2(d.x, d.z).length() - 2.6) < 0.45 and absf(d.y) > 2.2
				m.set_voxel(x, y, z, SEAM if seam else ORANGE)
	m.set_pivot(4, 4, 4)
	_cached = m.build_mesh()
	return _cached


## Carried by a hand: frozen and moved by the game.
func carry(at: Vector3) -> void:
	_pending = []
	if not held:
		held = true
		freeze = true
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	position = at


## Let go at `from` with velocity `v` (a shot, a pass, a dropped ball), both
## in the parent's space. The ball is put there frozen and set free on the
## next physics step: teleporting a live rigid body doesn't always stick.
func launch(from: Vector3, v: Vector3, spin := Vector3.ZERO) -> void:
	held = false
	freeze = true
	position = from
	var p := get_parent() as Node3D
	var basis := p.global_transform.basis if p else Basis.IDENTITY
	_pending = [basis * v, basis * spin]
	_last_v = basis * v


func spin_with(v: Vector3, dt: float) -> void:
	# a carried ball rolls in the hand a little, so the seams move
	_mesh.rotate_object_local(Vector3.RIGHT, -v.length() * dt * 2.0)


func _physics_process(_dt: float) -> void:
	if not _pending.is_empty():
		freeze = false
		linear_velocity = _pending[0]
		angular_velocity = _pending[1]
		_pending = []
	elif not held:
		_last_v = linear_velocity


func _on_body_entered(body: Node) -> void:
	var kind := str(body.get_meta("court", "wall"))
	var s := clampf(_last_v.length() / 8.0, 0.0, 1.0)
	if s > 0.04:
		hit.emit(kind, global_position, s)
