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
	## After a shot the view follows the puck this long before easing back (Sean:
	## letting go of the mouse by reflex lost sight of where the shot went).
	const WATCH_S := 2.0
	const WATCH_RATE := 7.0  # 1/s, the view swinging onto the puck
	const RETURN_RATE := 3.5  # 1/s, easing back to the skating view
	var yaw := 0.0
	var pitch := PITCH
	var pull := 0.0  # the hands' pull on the view (DemoHands), radians
	var watch_t := 0.0
	var watching: Puck

	func _ready() -> void:
		mode = Mode.FIRST  # no camera made, nothing placed: `cam` is the walker's

	## A shot went: the view holds on `puck` for WATCH_S.
	func watch(puck: Puck) -> void:
		watching = puck
		watch_t = WATCH_S

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
		var want_pitch := PITCH
		var rate := 9.0
		if watch_t > 0.0:
			watch_t -= dt
			# the puck back on your blade (or gone, or reset) ends the watch early
			if watching == null or watching.controller == h or watching.frozen:
				watch_t = 0.0
		if watch_t > 0.0:
			var eye := h.global_position + Vector3(0.0, EYE, 0.0)
			var to := watching.position - eye
			if Vector2(to.x, to.z).length() > 0.5:
				want = atan2(-to.x, -to.z)
				want_pitch = clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.2, 0.6)
				rate = WATCH_RATE
		elif absf(angle_difference(yaw, want)) > 0.3 or absf(pitch - PITCH) > 0.2:
			rate = RETURN_RATE
		yaw = lerp_angle(yaw, want, 1.0 - exp(-rate * dt))
		pitch = lerpf(pitch, want_pitch, 1.0 - exp(-rate * dt))
		if not looking:
			look = look.lerp(Vector2.ZERO, 1.0 - exp(-10.0 * dt))
		body.global_position = h.global_position
		body.rotation.y = yaw + look.x + pull
		cam.position.y = EYE
		cam.rotation.x = clampf(pitch + look.y, -1.4, 1.4)


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
	camera_rig.watch(puck)


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
