class_name CameraRig
extends Node3D
## Follow camera with two views: a broadcast-style perspective camera and an
## orthographic isometric view that matches the reference renders.

enum Mode { BROADCAST, ISOMETRIC }

var mode := Mode.BROADCAST
var cam: Camera3D
var _center := Vector3.ZERO
var zoom := 16.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.far = 300.0
	add_child(cam)
	cam.current = true
	_place()


func toggle() -> void:
	mode = Mode.ISOMETRIC if mode == Mode.BROADCAST else Mode.BROADCAST
	_place()


func follow(focus: Vector3, dt: float) -> void:
	var target := Vector3(clampf(focus.x, -24.0, 24.0), 0, clampf(focus.z, -6.0, 6.0) * 0.5)
	_center = _center.lerp(target, 1.0 - exp(-3.0 * dt))
	_place()


func forward_flat() -> Vector3:
	var f := -cam.global_transform.basis.z
	f.y = 0.0
	return f.normalized()


func right_flat() -> Vector3:
	var r := cam.global_transform.basis.x
	r.y = 0.0
	return r.normalized()


## Projects the mouse onto the ice plane, or returns null.
func mouse_on_ice() -> Variant:
	var mp := get_viewport().get_mouse_position()
	var origin := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	if absf(dir.y) < 0.0001:
		return null
	var t := -origin.y / dir.y
	if t < 0.0:
		return null
	return origin + dir * t


func _place() -> void:
	if cam == null:
		return
	if mode == Mode.BROADCAST:
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = 45.0
		cam.position = _center + Vector3(0, 12.0, 13.5)
		cam.look_at(_center + Vector3(0, 0, -1.0), Vector3.UP)
	else:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = zoom
		cam.position = _center + Vector3(-22.0, 25.0, 22.0)
		cam.look_at(_center, Vector3.UP)
