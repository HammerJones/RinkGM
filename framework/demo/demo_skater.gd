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

## In the camera's frame: where the top hand holds the knob, and which
## way (on the ground) the shaft runs from there down to the heel.
const HANDS := Vector3(0.35, -0.5, -1.3)  # arms out ahead, so the blade is in the view
const HEEL_DIR := Vector2(0.42, -0.91)  # x right, z forward (negative) in the camera's frame

var active := false
var vel := Vector2.ZERO  # on the sheet plane (x, z), world
var stick: Node3D
var stride_count := 0
var _mesh: MeshInstance3D  # the stick's voxels, placed in the camera's frame
var _stride_t := 0.0
var _foot := 1.0
var _stopping := false


func _ready() -> void:
	stick = Node3D.new()
	stick.name = "Stick"
	stick.visible = false
	add_child(stick)
	# the game's own stick (StickProps, a team stick with a right curve),
	# held in the camera's frame: the knob by the hands at the bottom right
	# of the view, the shaft down at its lie to the heel on the ice ahead
	# and to the right, the blade flat on the ice beyond it
	var mi := MeshInstance3D.new()
	mi.name = "Voxels"
	mi.mesh = StickProps.stick_mesh(StickProps.variant("team", -1, false, "black"))
	stick.add_child(mi)
	var shaft_len := (StickProps.SENIOR_VOX + 2) * StickProps.SV
	var heel := (
		HANDS
		+ (
			Vector3(HEEL_DIR.x * cos(StickProps.LIE), 0.0, HEEL_DIR.y * cos(StickProps.LIE))
			* shaft_len
		)
	)
	heel.y = HANDS.y - sin(StickProps.LIE) * shaft_len
	# stick space turned so the blade lies flat (the shaft then leans back
	# at the lie toward -X), then yawed so -X runs from the heel to the hands
	var yaw := Basis(Vector3.UP, atan2(-HEEL_DIR.y, HEEL_DIR.x))
	mi.basis = yaw * Basis(Vector3.BACK, StickProps.LIE)
	mi.position = heel
	_mesh = mi


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


## The blade's middle, world: where a puck is carried or shot from.
func blade_world() -> Vector3:
	return _mesh.to_global(Vector3(0.15, -0.04, 0.0))
