class_name LooseProp
extends RigidBody3D
## One loose thing in the building that a person can pick up, carry and drop
## (Sean's My Summer Car hands): a cup, a bottle, a puck, a cone, a box, a
## chair, a toolbox, a bin. Like a StickProp it is a light rigid body that
## sleeps until something bumps it, on StickProp.LAYER: it collides with the
## venue, other loose things and the walker (which shoves it), and nothing
## else sees it (the hockey sim, the walker's footing, the people's navmesh).
##
## Built by VenueKit.loose() / LooseProps.body() for a walk only; a match
## venue draws static copies instead (see VenueKit.commit). The room's
## StickField draws every resting loose thing in one merged mesh; a prop
## draws its own mesh only while it is awake (moving, held).
##
##   prop_id      LooseProps id ("coffee_cup", "toolbox"...)
##   label        what the [LMB] hint calls it ("COFFEE CUP")
##   held         true while PropGrab carries it (never settles asleep)
##   knocked(by)  emitted once each time something knocks it out of rest
## Every loose prop is in the "loose_props" group, with the sticks: that
## group is what PropGrab can pick up.

signal knocked(by: Node)

## A thrown or shoved prop is capped at these (a shove between the walker
## and a wall is a clatter, not a launch).
const MAX_SPEED := 9.0
const MAX_SPIN := 18.0
## Resting like a StickProp: touching something and slower than these for
## SETTLE_FRAMES physics steps puts it to sleep.
const SETTLE_SPEED := 0.1
const SETTLE_SPIN := 0.6
const SETTLE_FRAMES := 20

static var _material: PhysicsMaterial

var prop_id := ""
var label := ""
var mesh: Mesh
var field: StickField
var held := false
## Set by the kit: on its first physics step it drops onto the surface
## under it (a counter, a shelf, the floor), so a placement need not know
## the exact height of what it stands on.
var snap := false
var _mi: MeshInstance3D
var _knocked := false
var _calm := 0


## A loose prop with `mesh` (pivot on its base) and one box `box` (in the
## mesh's space) for collision.
static func make(id: String, mesh_: Mesh, box: AABB, kg: float, label_ := "") -> LooseProp:
	var p := LooseProp.new()
	p.name = id.to_pascal_case()
	p.prop_id = id
	p.label = label_ if label_ != "" else id.replace("_", " ").to_upper()
	p.mesh = mesh_
	p.mass = kg
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = box.size.max(Vector3.ONE * 0.02)
	cs.shape = sh
	cs.position = box.get_center()
	p.add_child(cs)
	return p


static func material() -> PhysicsMaterial:
	if _material == null:
		_material = PhysicsMaterial.new()
		_material.friction = 0.8
		_material.bounce = 0.12
	return _material


func _init() -> void:
	collision_layer = 1 << (StickProp.LAYER - 1)
	collision_mask = (1 << (VenueKit.VENUE_LAYER - 1)) | (1 << (StickProp.LAYER - 1)) | (1 << (StickProp.PUSH_LAYER - 1))
	angular_damp = 0.6
	can_sleep = true
	sleeping = true
	freeze = true  # until its first physics step (see StickProp._let_go)
	contact_monitor = true
	max_contacts_reported = 2
	physics_material_override = material()
	continuous_cd = true
	add_to_group("loose_props")
	body_entered.connect(_on_body_entered)
	sleeping_state_changed.connect(_on_sleeping_changed)


func _ready() -> void:
	if field == null:
		_show(true)
	if freeze:
		get_tree().physics_frame.connect(_let_go, CONNECT_ONE_SHOT)


func _let_go() -> void:
	if not is_inside_tree():
		return
	if snap:
		# moved while still frozen; let go on the next step, so the move
		# doesn't wake it
		snap = false
		_snap_down()
		get_tree().physics_frame.connect(_let_go, CONNECT_ONE_SHOT)
		return
	freeze = false
	sleeping = true


## Drops the prop onto the first venue surface below its base (within a
## metre and a half), so it rests on it instead of hovering or sinking in.
func _snap_down() -> void:
	var from := global_position + Vector3(0, 0.08, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from - Vector3(0, 1.6, 0), 1 << (VenueKit.VENUE_LAYER - 1))
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	global_position.y = (hit.position as Vector3).y + 0.002
	if field:
		field.mark_dirty()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not held and state.get_contact_count() > 0 and state.linear_velocity.length() < SETTLE_SPEED and state.angular_velocity.length() < SETTLE_SPIN:
		_calm += 1
		if _calm >= SETTLE_FRAMES:
			# every step from here (see StickProp: Jolt wakes a sleeping body
			# that an awake one touches, so a pile settles together or not)
			_calm = SETTLE_FRAMES
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


## PropGrab picks it up (true) or lets go (false).
func set_held(on: bool) -> void:
	held = on
	_calm = 0
	if on:
		freeze = false
		sleeping = false


func _on_body_entered(body: Node) -> void:
	if body is StaticBody3D or _knocked or held:
		return
	_knocked = true
	knocked.emit(body)


func _on_sleeping_changed() -> void:
	if sleeping:
		_knocked = false
	if field:
		# woken on entering the world, before its first step: still resting
		_show(not sleeping and not freeze)
		field.mark_dirty()


func _show(on: bool) -> void:
	if on and _mi == null:
		_mi = MeshInstance3D.new()
		_mi.mesh = mesh
		_mi.visibility_range_end = StickField.DRAW_RANGE
		_mi.cast_shadow = Look.cast()
		add_child(_mi)
	elif not on and _mi != null:
		_mi.queue_free()
		_mi = null
