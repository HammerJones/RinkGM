class_name DemoRinkGame
extends Node
## What the game's Skater, Puck, StickPuck and HumanController ask of the
## Game node, for a demo with one skater and no game: a puck, a list of
## skaters, the human, a clock, a camera rig and a HUD. Nothing is ever
## frozen, every shot is at the +x net, there are no teammates to pass to
## and no stats beyond the shot count the rig watches.


## The game's first-person camera on a camera the demo owns: a `CameraRig`
## (HumanController types it so; `aim_from_view` asks it for the viewport
## and `cam`) that makes no camera of its own and never places one. The
## view turns with the skater, looks down enough to see the blade, and LMB
## looks around from there. HumanController reads its forward and right.
class DemoCameraRig:
	extends CameraRig
	const EYE := 1.55
	const PITCH := deg_to_rad(-36.0)
	var yaw := 0.0

	func _ready() -> void:
		mode = Mode.FIRST  # no camera made, nothing placed: `cam` is the walker's

	func forward_flat() -> Vector3:
		return Vector3(-sin(yaw), 0.0, -cos(yaw))

	func right_flat() -> Vector3:
		return Vector3(cos(yaw), 0.0, -sin(yaw))

	## Free look: the view turns by `delta` while `held`, and swings back when let go.
	func free_look(delta: Vector2, held: bool) -> void:
		looking = held
		if held:
			look.x = clampf(look.x - delta.x, -LOOK_YAW, LOOK_YAW)
			look.y = clampf(look.y + delta.y, -LOOK_PITCH, LOOK_PITCH)

	## The eyes on `body` (the demo's walker, which carries `cam`) at the
	## skater's head, turned the way they skate.
	func ride(h: Skater, body: Node3D, dt: float) -> void:
		var want := atan2(-h.heading.x, -h.heading.z)
		yaw = lerp_angle(yaw, want, 1.0 - exp(-9.0 * dt))
		if not looking:
			look = look.lerp(Vector2.ZERO, 1.0 - exp(-10.0 * dt))
		body.global_position = h.global_position
		body.rotation.y = yaw + look.x
		cam.position.y = EYE
		cam.rotation.x = clampf(PITCH + look.y, -1.4, 1.4)


## A HUD the controller can talk to: its messages go to the demo's toast.
class DemoHudBridge:
	extends RefCounted
	var on_message: Callable

	func show_message(text: String, seconds: float) -> void:
		if on_message.is_valid():
			on_message.call(text, seconds)


var puck: Puck
var skaters: Array = []
var goalies: Array = []
var human: Skater
var time := 0.0
var practice := true
var stats := {"shots": 0, "checks": 0}
var camera_rig: DemoCameraRig
var hud: DemoHudBridge


func _init() -> void:
	camera_rig = DemoCameraRig.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	hud = DemoHudBridge.new()


func is_frozen() -> bool:
	return false


func on_shot(_s: Skater, _slap: bool) -> void:
	stats.shots += 1


func on_new_stick(_s: Skater) -> void:
	pass


func attack_side(_team: int) -> int:
	return 1


func teammates(_s: Skater) -> Array:
	return []


func on_stick_lift(_lifter: Skater, _holder: Skater) -> void:
	pass


func on_possession(_s: Skater) -> void:
	pass


func lane_clear(_team: int, _from: Vector2, _to: Vector2, _width: float) -> bool:
	return false


## E without the puck calls for a pass; there is no one to make one.
func practice_feed() -> void:
	hud.show_message("NO ONE TO PASS TO", 0.8)
