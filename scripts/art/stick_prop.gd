class_name StickProp
extends RigidBody3D
## One real hockey stick in the building (playtest notes #35, #40): racked,
## leaning on the boards or lying on the floor. A light rigid body with two
## boxes (shaft and blade) that sleeps until something bumps it; the walker
## shoves it (it is on PUSH_LAYER), it falls over, settles and sleeps again.
##
## Built by StickProps.fill() / place() inside a StickField, which draws the
## resting sticks of a room as one mesh and takes far ones out of physics.
## A stick draws its own mesh only while it is awake.
##
## Hooks for other threads:
##   knocked(by)    emitted once each time something (the walker, another
##                  stick) knocks it out of rest. Sound can play a clatter.
##   variant        the stick: StickProps.variant() dictionary
##   describe()     "Warlock HEX, left curve, senior, black tape"
##   take()         picks it up: removes it from the world and returns its
##                  variant (Mechanics' inventory decides what that means)
## Every stick is in the "stick_props" group.

signal knocked(by: Node)

## Physics layer of loose props (sticks), and the layer of bodies that
## shove them (the walker). Sticks collide with the venue (layer 2), each
## other and pushers; nothing else collides with them, so the hockey sim,
## the walker's footing and the people's navmesh never see them.
const LAYER := 3
const PUSH_LAYER := 4
const MASS := 0.45  # kg, a composite stick
## A stick squeezed between the walker and a wall is shoved out hard by the
## solver; these caps keep it a clatter, not a launch.
const MAX_SPEED := 4.0
const MAX_SPIN := 14.0

static var _material: PhysicsMaterial

var variant := {}
var mesh: ArrayMesh
var field: StickField
var _mi: MeshInstance3D
var _knocked := false


static func make(v: Dictionary) -> StickProp:
	var s := StickProp.new()
	s.variant = v
	s.name = "Stick"
	s.mesh = StickProps.stick_mesh(v)
	var boxes := StickProps.collision(v)
	var shapes := StickProps.shapes(v)
	for i in boxes.size():
		var cs := CollisionShape3D.new()
		cs.shape = shapes[i]
		cs.transform = boxes[i][0]
		s.add_child(cs)
	return s


static func material() -> PhysicsMaterial:
	if _material == null:
		_material = PhysicsMaterial.new()
		_material.friction = 0.9
		_material.bounce = 0.08
	return _material


func _init() -> void:
	collision_layer = 1 << (LAYER - 1)
	collision_mask = (1 << (VenueKit.VENUE_LAYER - 1)) | (1 << (LAYER - 1)) | (1 << (PUSH_LAYER - 1))
	mass = MASS
	angular_damp = 0.8
	can_sleep = true
	sleeping = true
	# held still until the first physics step after it enters the world (a
	# body is woken on entering), then let go asleep: see _let_go()
	freeze = true
	contact_monitor = true
	max_contacts_reported = 2
	physics_material_override = material()
	continuous_cd = true
	add_to_group("stick_props")
	body_entered.connect(_on_body_entered)
	sleeping_state_changed.connect(_on_sleeping_changed)
	WorldSound.hook_stick(self)  # the clatter (only when sound is on)


func _ready() -> void:
	if field == null:
		_show(true)
	if freeze:
		get_tree().physics_frame.connect(_let_go, CONNECT_ONE_SHOT)


func _let_go() -> void:
	freeze = false
	sleeping = true


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if state.linear_velocity.length() > MAX_SPEED:
		state.linear_velocity = state.linear_velocity.limit_length(MAX_SPEED)
	if state.angular_velocity.length() > MAX_SPIN:
		state.angular_velocity = state.angular_velocity.limit_length(MAX_SPIN)


func describe() -> String:
	return StickProps.describe(variant)


## Picks the stick up: it leaves the world and its variant comes back.
func take() -> Dictionary:
	if field:
		field.remove_stick(self)
	queue_free()
	return variant


func _on_body_entered(body: Node) -> void:
	if body is StaticBody3D or _knocked:
		return
	_knocked = true
	knocked.emit(body)


func _on_sleeping_changed() -> void:
	if sleeping:
		_knocked = false
	if field:
		_show(not sleeping)
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
