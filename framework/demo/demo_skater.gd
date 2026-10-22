class_name DemoSkater
extends Node3D
## Skating in the demo: on the skates, the walker is driven here instead
## of walking. The mouse faces you, W strides (a push-off every
## `STRIDE_S`, `STRIDE_ACC` up to `TOP`), S is a hockey stop
## (`STOP_DEC`), nothing is a coast (`COAST`). Your velocity swings
## toward where you face as fast as the edges hold (`GRIP` of lateral
## pull); asking more than that slides, and past `SkateWear.GRIP_G` the
## outside edge gouges. Every step is written to the ice through
## `SkateWear`. No body, no hands (Sean: they got in the way): just the
## stick, held low to the right of the view, its blade down on the ice.

const TOP := 9.0
const STRIDE_ACC := 2.8
const STRIDE_S := 0.55
const STOP_DEC := 7.5
const COAST := 0.35
const GRIP := 7.0  # m/s2 the edges hold before the skates slide

var active := false
var vel := Vector2.ZERO  # on the sheet plane (x, z), world
var stick: Node3D
var stride_count := 0
var _stride_t := 0.0
var _foot := 1.0
var _stopping := false


func _ready() -> void:
	stick = Node3D.new()
	stick.name = "Stick"
	stick.visible = false
	add_child(stick)
	# in the camera's frame: from the hands at the bottom right of the
	# view down to the blade on the ice ahead and to the right
	var hand := Vector3(0.28, -0.22, -0.55)
	var blade := Vector3(0.85, -1.05, -2.1)
	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.013
	cyl.bottom_radius = 0.013
	cyl.height = hand.distance_to(blade)
	cyl.radial_segments = 8
	shaft.mesh = cyl
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.72, 0.56, 0.32)
	wood.roughness = 0.6
	shaft.material_override = wood
	shaft.position = (hand + blade) / 2
	var dir := (blade - hand).normalized()
	shaft.basis = Basis.looking_at(dir, Vector3.UP).rotated(
		Basis.looking_at(dir, Vector3.UP).x, PI / 2
	)
	stick.add_child(shaft)
	var bl := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.32, 0.07, 0.025)
	bl.mesh = box
	var tape := StandardMaterial3D.new()
	tape.albedo_color = Color(0.1, 0.1, 0.1)
	tape.roughness = 0.9
	bl.material_override = tape
	bl.position = blade + Vector3(0.14, 0.035, -0.02)
	bl.rotation.y = -0.35
	stick.add_child(bl)


## On the skates: the walker is ours to move, the stick in its view.
func start(walker: Node3D) -> void:
	active = true
	vel = Vector2.ZERO
	_stride_t = 0.0
	stride_count = 0
	var cam: Node3D = walker.get("camera")
	stick.reparent(cam if cam else walker, false)
	stick.position = Vector3.ZERO
	stick.rotation = Vector3.ZERO
	stick.visible = true


func stop_skating() -> void:
	active = false
	vel = Vector2.ZERO
	stick.visible = false
	stick.reparent(self, false)


## One step: `push` W held, `brake` S held. Moves `walker`, marks `sheet`
## (positions in sheet metres through `to_sheet`), keeps inside the
## boards through `clamp_fn(p: Vector2) -> Vector2` (sheet metres).
func step(
	dt: float,
	walker: Node3D,
	sheet: IceSheet,
	to_sheet: Callable,
	clamp_fn: Callable,
	push: bool,
	brake: bool
) -> void:
	var yaw := walker.rotation.y
	var face := Vector2(-sin(yaw), -cos(yaw))
	var v := vel.length()
	var dir := vel / v if v > 0.01 else face
	var a0: Vector2 = to_sheet.call(walker.global_position)
	var lat_g := 0.0
	var left := false
	# where the velocity points swings toward the face as the edges allow
	if v > 0.01:
		var want := dir.angle_to(face)
		var can := GRIP / maxf(v, 0.5) * dt
		var swing := clampf(want, -can, can)
		dir = dir.rotated(swing)
		lat_g = absf(swing) / dt * v
		left = swing < 0.0  # a negative angle on the sheet (x right, z down) turns left
	_stopping = brake and v > 0.3
	if _stopping:
		v = maxf(v - STOP_DEC * dt, 0.0)
		SkateWear.stop(sheet, a0 + dir * 0.1, dir, v, STOP_DEC, dt)
	elif push:
		# a stride is a push every STRIDE_S, the speed built between
		v = minf(v + STRIDE_ACC * dt * (1.0 - v / TOP * 0.5), TOP)
		_stride_t += dt
		if _stride_t >= STRIDE_S:
			_stride_t = 0.0
			_foot = -_foot
			stride_count += 1
			SkateWear.stride(sheet, a0, face, _foot, v)
		if v < 1.0:
			dir = face
	else:
		v = maxf(v - COAST * dt, 0.0)
	vel = dir * v
	var a1 := a0 + vel * dt
	var held: Vector2 = clamp_fn.call(a1)
	if held != a1:
		# the boards: the velocity into them is lost
		var n := (held - a1).normalized()
		vel -= n * minf(vel.dot(n), 0.0)
		a1 = held
	if lat_g > 0.0:
		SkateWear.turn(sheet, a0, a1, dir, lat_g, left)
	SkateWear.glide(sheet, a0, a1, dir, v)
	var d := a1 - a0
	walker.global_position += Vector3(d.x, 0.0, d.y)


func state_text() -> String:
	return (
		"SKATING %.1f M/S%s   STRIDES %d"
		% [vel.length(), "  STOPPING" if _stopping else "", stride_count]
	)
