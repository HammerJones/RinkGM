class_name FirstPerson
extends CharacterBody3D
## A minimal first-person body for framework demos: WASD, mouse look, a
## camera at eye height, on the walker layer so it shoves props. Not the
## game's VenueWalker (which has crouch, stairs, jobs); just enough to walk
## a test room.

const SPEED := 3.2
const RUN := 5.5
const EYE := 1.62
const SENS := 0.0022

var camera: Camera3D
var look_enabled := true
var _yaw := 0.0
var _pitch := 0.0


func _ready() -> void:
	collision_layer = Layers.bit(Layers.WALKER)
	collision_mask = Layers.mask([Layers.VENUE, Layers.PROPS, Layers.WORLD])
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	camera = Camera3D.new()
	camera.position.y = EYE
	camera.fov = 70.0
	add_child(camera)
	camera.current = true


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseMotion
		and look_enabled
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	):
		_yaw -= event.relative.x * SENS
		_pitch = clampf(_pitch - event.relative.y * SENS, -1.4, 1.4)
		rotation.y = _yaw
		camera.rotation.x = _pitch


func _physics_process(dt: float) -> void:
	var wish := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		wish -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		wish += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		wish -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		wish += transform.basis.x
	wish.y = 0.0
	var speed := RUN if Input.is_key_pressed(KEY_SHIFT) else SPEED
	var target := wish.normalized() * speed if wish.length() > 0.01 else Vector3.ZERO
	velocity.x = target.x
	velocity.z = target.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * dt
	move_and_slide()
