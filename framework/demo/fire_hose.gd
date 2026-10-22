class_name FireHose
extends Node3D
## The fire hose on the bay wall: Sean's uploaded reel model voxelised
## (art/props/fire_hose.vox by tools/propgen/glb2vox.py) hung on the
## bay's side wall, and its nozzle (art/props/fire_nozzle.vox, the same
## model's nozzle cropped out) carried in hand once taken. Look at the
## reel and E takes it; E with nothing else under the dot hangs it back.
## In hand, LMB sprays and the wheel sets the pattern, continuously, from
## a fine mist cone (`pattern` 0: wide, short) to a straight jet (1:
## tight, far). The flow is a fire hose's, `LPS`, whatever the pattern;
## the pattern is where it lands. The demo (ice_demo.gd `_hose`) does the
## spraying from `cone()` and `reach()`; this is the props and the state.

const LPS := 8.0  # litres a second: a 1.5 in attack line, five times the old garden hose
const MIST_HALF := deg_to_rad(28.0)  # the cone's half angle, fine mist
const JET_HALF := deg_to_rad(1.5)
const MIST_REACH := 3.5  # metres the mist carries from the nozzle
const JET_REACH := 20.0
const NOTCH := 0.05  # a wheel notch of pattern
const TAKE_REACH := 2.6
const REEL_R := 0.55  # the reel's aim sphere

var held := false
var pattern := 0.5  # 0 mist .. 1 jet
var reel: MeshInstance3D
var nozzle: MeshInstance3D
var _hang_parent: Node3D


## Hangs the reel on a wall at `at` (world, the reel's base centre) with
## its mounting plate facing `yaw` (the model's plate is on its +z side).
func build(at: Vector3, yaw: float) -> void:
	reel = MeshInstance3D.new()
	reel.name = "Reel"
	reel.mesh = ObjectCatalog.mesh("fire_hose")
	reel.material_override = PropMaterial.shared()
	reel.position = at
	reel.rotation.y = yaw
	add_child(reel)
	nozzle = MeshInstance3D.new()
	nozzle.name = "Nozzle"
	nozzle.mesh = ObjectCatalog.mesh("fire_nozzle")
	nozzle.material_override = PropMaterial.shared()
	nozzle.visible = false
	add_child(nozzle)
	_hang_parent = self


## True when the view line from `origin` along `dir` meets the reel within reach.
func aimed(origin: Vector3, dir: Vector3) -> bool:
	if held or reel == null:
		return false
	var centre := reel.global_position + Vector3(0.0, 0.5, 0.0)
	var to := centre - origin
	var t := to.dot(dir)
	if t < 0.0 or t > TAKE_REACH + REEL_R:
		return false
	return (to - dir * t).length() < REEL_R


func prompt() -> String:
	return "[E] TAKE THE FIRE HOSE"


## Into the hand: the nozzle rides the camera, pointing where it looks.
func take(camera: Camera3D) -> void:
	held = true
	nozzle.reparent(camera, false)
	nozzle.position = Vector3(0.26, -0.26, -0.5)
	nozzle.rotation = Vector3(-PI / 2 + 0.12, 0.0, 0.0)
	nozzle.visible = true


## Back on the reel.
func hang() -> void:
	held = false
	nozzle.visible = false
	nozzle.reparent(_hang_parent, false)
	nozzle.position = Vector3.ZERO
	nozzle.rotation = Vector3.ZERO


func scroll(up: bool) -> void:
	pattern = clampf(pattern + (NOTCH if up else -NOTCH), 0.0, 1.0)


func cone() -> float:
	return lerpf(MIST_HALF, JET_HALF, pattern)


func reach() -> float:
	return lerpf(MIST_REACH, JET_REACH, pattern)


func pattern_text() -> String:
	if pattern <= 0.02:
		return "FINE MIST"
	if pattern >= 0.98:
		return "STRAIGHT JET"
	return "%d%% TOWARD JET" % roundi(pattern * 100.0)
