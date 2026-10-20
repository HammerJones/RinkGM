class_name LiveProp
extends RigidBody3D
## A world object while it needs a node (WorldObject.LIVE): dropped,
## pushed, moving. A light rigid body with one box from the prop's voxel
## bounds, on StickProp's layers (3, pushed by 4), so the hockey sim, the
## walker's footing and the people's navmesh never see it. It follows
## StickProp's rules: capped speed, settles when barely moving and touching
## something, sleeps, and ObjectWalk writes its rest back into the row and
## demotes it when it's far or over the LIVE cap.

signal settled(prop: LiveProp)

const LAYER := StickProp.LAYER
const PUSH_LAYER := StickProp.PUSH_LAYER
const MAX_SPEED := 4.0
const MAX_SPIN := 14.0
const SETTLE_SPEED := 0.12
const SETTLE_SPIN := 0.8
const SETTLE_FRAMES := 20

var row: WorldObject
## Starts asleep (a row promoted at rest) instead of falling in.
var asleep := false
var _mi: MeshInstance3D
var _calm := 0


static func make(row_: WorldObject) -> LiveProp:
	var p := LiveProp.new()
	p.row = row_
	p.name = "Live_%s" % String(row_.id).replace(".", "_")
	p.mass = maxf(float(PropLibrary.info(row_.prop).get("mass_kg", 1.0)), 0.05)
	var b := PropLibrary.bounds(row_.prop, row_.age)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = b.size.max(Vector3.ONE * 0.02)
	cs.shape = shape
	cs.position = b.get_center()
	p.add_child(cs)
	p._mi = MeshInstance3D.new()
	p._mi.mesh = PropLibrary.mesh(row_.prop, row_.age)
	p._mi.cast_shadow = Look.cast()
	p._mi.visibility_range_end = StickField.DRAW_RANGE
	p.add_child(p._mi)
	p.transform = row_.xf
	return p


func _init() -> void:
	collision_layer = 1 << (LAYER - 1)
	collision_mask = (1 << (VenueKit.VENUE_LAYER - 1)) | (1 << (LAYER - 1)) | (1 << (PUSH_LAYER - 1))
	angular_damp = 0.8
	can_sleep = true
	contact_monitor = true
	max_contacts_reported = 2
	physics_material_override = StickProp.material()
	continuous_cd = true
	add_to_group("live_props")
	sleeping_state_changed.connect(_on_sleeping_changed)


func _ready() -> void:
	if asleep:
		# held still until the first physics step after it enters the world
		# (a body is woken on entering), then let go asleep, like StickProp
		freeze = true
		get_tree().physics_frame.connect(_let_go, CONNECT_ONE_SHOT)


func _let_go() -> void:
	freeze = false
	sleeping = true


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if state.get_contact_count() > 0 and state.linear_velocity.length() < SETTLE_SPEED and state.angular_velocity.length() < SETTLE_SPIN:
		_calm += 1
		if _calm >= SETTLE_FRAMES:
			_calm = 0
			state.linear_velocity = Vector3.ZERO
			state.angular_velocity = Vector3.ZERO
			state.sleeping = true
			return
	else:
		_calm = 0
	if state.linear_velocity.length() > MAX_SPEED:
		state.linear_velocity = state.linear_velocity.limit_length(MAX_SPEED)
	if state.angular_velocity.length() > MAX_SPIN:
		state.angular_velocity = state.angular_velocity.limit_length(MAX_SPIN)


func _on_sleeping_changed() -> void:
	if sleeping:
		settled.emit(self)
