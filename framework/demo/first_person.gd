class_name FirstPerson
extends CharacterBody3D
## A minimal first-person body for framework demos: WASD, mouse look, a
## camera at eye height, on the walker layer so it shoves props. Ctrl
## crouches, F toggles noclip (fly through anything: Space up, Ctrl
## down), holding Z zooms the view. Not the game's VenueWalker (which has
## stairs, jobs, balance); just enough to walk a test room.

const SPEED := 3.2
const RUN := 5.5
const CROUCH_SPEED := 1.6
const FLY := 6.0
const EYE := 1.62
const EYE_CROUCH := 1.0
const SENS := 0.0022
const FOV := 70.0
const FOV_ZOOM := 24.0

var camera: Camera3D
var look_enabled := true
var noclip := false
var crouching := false
var _yaw := 0.0
var _pitch := 0.0
var _mask := 0


func _ready() -> void:
	collision_layer = Layers.bit(Layers.WALKER)
	collision_mask = Layers.mask([Layers.VENUE, Layers.PROPS, Layers.WORLD])
	_mask = collision_mask
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	camera = Camera3D.new()
	camera.position.y = EYE
	camera.fov = FOV
	add_child(camera)
	camera.current = true


## Turns the body to a heading (radians about Y; 0 looks down -Z).
func face(yaw: float) -> void:
	_yaw = yaw
	rotation.y = yaw


func set_noclip(on: bool) -> void:
	noclip = on
	collision_mask = 0 if on else _mask
	collision_layer = 0 if on else Layers.bit(Layers.WALKER)
	velocity = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseMotion
		and look_enabled
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	):
		# a zoomed view turns slower, as a scope would
		var k := camera.fov / FOV
		_yaw -= event.relative.x * SENS * k
		_pitch = clampf(_pitch - event.relative.y * SENS * k, -1.4, 1.4)
		rotation.y = _yaw
		camera.rotation.x = _pitch
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		set_noclip(not noclip)


func _physics_process(dt: float) -> void:
	var zoom := Input.is_key_pressed(KEY_Z)
	camera.fov = lerpf(camera.fov, FOV_ZOOM if zoom else FOV, 0.25)
	var wish := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		wish -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		wish += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		wish -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		wish += transform.basis.x
	if noclip:
		# fly where the eyes point; Space up, Ctrl down
		var fwd := -camera.global_transform.basis.z
		wish = (
			fwd
			* (
				1.0
				if Input.is_key_pressed(KEY_W)
				else (-1.0 if Input.is_key_pressed(KEY_S) else 0.0)
			)
		)
		wish += (
			transform.basis.x
			* (
				1.0
				if Input.is_key_pressed(KEY_D)
				else (-1.0 if Input.is_key_pressed(KEY_A) else 0.0)
			)
		)
		if Input.is_key_pressed(KEY_SPACE):
			wish.y += 1.0
		if Input.is_key_pressed(KEY_CTRL):
			wish.y -= 1.0
		var fly := FLY * (2.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
		velocity = wish.normalized() * fly if wish.length() > 0.01 else Vector3.ZERO
		global_position += velocity * dt
		return
	crouching = Input.is_key_pressed(KEY_CTRL)
	camera.position.y = lerpf(camera.position.y, EYE_CROUCH if crouching else EYE, 0.2)
	wish.y = 0.0
	var speed := CROUCH_SPEED if crouching else (RUN if Input.is_key_pressed(KEY_SHIFT) else SPEED)
	var target := wish.normalized() * speed if wish.length() > 0.01 else Vector3.ZERO
	velocity.x = target.x
	velocity.z = target.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * dt
	move_and_slide()
