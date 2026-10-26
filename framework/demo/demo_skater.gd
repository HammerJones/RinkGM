class_name DemoSkater
extends Node3D
## Skating in the demo with the game's own mechanics: a `Skater` (its
## strides, edges, dashes, stops and turn-arounds from PhysicsProfile), a
## `Puck` on its blade through StickPuck, and the keyboard + mouse scheme
## from HumanController and PlayerInput (WASD skates, Shift dashes, Space
## stops, R turns around, the mouse is the stick, LMB looks, RMB draws a
## shot pattern that fires on release, E passes). The demo's walker is
## carried along at the skater's eyes, looking down at the blade, its own
## head and torso hidden from its camera. Every stride, stop, turn and
## glide is written into the ice through `SkateWear`.

const SELF_LAYER := CameraRig.SELF_LAYER
const PUCK_SUBSTEPS := 4
const TURN_G := 3.0  # m/s2 of lateral load under which a turn leaves no edge mark
const SURE_REACH := Skater.REACH_ONE_HAND  # m from the body: a loose puck this close is yours
const CUP_SOFT := 0.4  # share of the cup's pull let go at a fast blade: the puck rides the face
const CUP_SOFT_V := Vector2(1.5, 4.5)  # m/s of blade: the softening comes in between these

var active := false
var stride_count := 0
## Sure hands (Sean): a loose puck anywhere the stick can reach, forehand
## or backhand, is picked up at once, and a carried puck is never lost
## (a shot or a pass still leaves the blade).
var sure_hands := true
## The ice on the puck (IceTouch): snow, water, slush, crust and ruts.
var ice_feel := true
## The mouse as hands (DemoHands): lead, weight, the swing's release.
var hands_on := true
var touch := IceTouch.new()
var hands: DemoHands
var game: DemoRinkGame
var skater: Skater
var controller: HumanController
var _walker: Node3D
var _sheet: IceSheet
var _to_sheet: Callable
var _cull := 0xFFFFF
var _pitch := 0.0


## The skater on `puck` with an even 62 in every rating; `on_message`
## (text, seconds) takes the controller's shot and pass messages.
func setup(puck: Puck, on_message: Callable) -> void:
	game = DemoRinkGame.new()
	game.name = "Game"
	game.puck = puck
	game.hud.on_message = on_message
	add_child(game)
	skater = Skater.new()
	skater.name = "Skater"
	add_child(skater)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	skater.setup(game, 0, 9, Models.palette(0), Skills.create(Skills.SKATER_KEYS, 62.0, 0.0, rng))
	game.skaters = [skater]
	game.human = skater
	skater.stride.connect(_on_stride)
	skater.stop_spray.connect(_on_stop)
	skater.visible = false
	controller = HumanController.new()
	controller.name = "Controller"
	controller.game = game
	add_child(controller)
	hands = DemoHands.new()
	hands.name = "Hands"
	add_child(hands)
	hands.on_swing_end = _release_swing
	# no body in the view (Sean: the hands got in the way): the stick and
	# its blade stay, everything else of you is on the layer the eyes skip
	var rig := skater.rig
	for part in (
		[rig.head, rig.torso, rig.hips, rig.arm_l, rig.arm_r, rig.leg_l, rig.leg_r]
		+ Array(rig.uppers)
		+ Array(rig.forearms)
		+ Array(rig.thighs)
		+ Array(rig.shins)
	):
		if part:
			part.layers = SELF_LAYER


## On the skates: the skater stands where the walker stands, facing its
## way; the walker rides the skater's eyes from here on.
func start(walker: Node3D) -> void:
	active = true
	stride_count = 0
	_walker = walker
	var yaw: float = walker.rotation.y
	skater.place(
		Vector2(walker.global_position.x, walker.global_position.z),
		Vector3(-sin(yaw), 0.0, -cos(yaw))
	)
	skater.visible = true
	walker.set("driven", true)
	walker.set("look_enabled", false)
	walker.call("set_noclip", true)
	var cam: Camera3D = walker.get("camera")
	var rig := game.camera_rig
	rig.cam = cam
	rig.yaw = yaw
	rig.look = Vector2.ZERO
	_cull = cam.cull_mask
	_pitch = cam.rotation.x
	cam.cull_mask = _cull & ~SELF_LAYER
	controller.player_input.capture_mouse()


func stop_skating() -> void:
	active = false
	skater.visible = false
	if _walker:
		_walker.set("driven", false)
		_walker.set("look_enabled", true)
		_walker.call("set_noclip", false)
		var cam: Camera3D = _walker.get("camera")
		cam.cull_mask = _cull
		cam.rotation.x = _pitch
		cam.position.y = FirstPerson.EYE
	_walker = null


## Tests and views drive the controls instead of the devices:
## `fn(frame: PlayerInput.Frame, dt)` fills the frame (null: the devices again).
func script(fn: Callable) -> void:
	controller.player_input.scripted = fn


## One tick: the controls read, the skater and the puck stepped, the
## walker's camera at the eyes, the ice marked (sheet metres through `to_sheet`).
func step(dt: float, sheet: IceSheet, to_sheet: Callable) -> void:
	if not active:
		return
	_sheet = sheet
	_to_sheet = to_sheet
	# the mouse is the stick for as long as you skate: the game's Esc lets it
	# go, and a loose cursor over the editor takes the next click there (Sean)
	if DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		controller.player_input.capture_mouse()
	var a0: Vector2 = to_sheet.call(skater.global_position)
	controller.update(dt)
	if hands_on:
		hands.shape(
			skater.ctrl,
			skater,
			dt,
			controller.player_input.mouse_sensitivity,
			skater.skill("stick_handling"),
			controller.player_input.frame.tracing
		)
	skater.physics_update(dt)
	var puck := game.puck
	var sdt := dt / PUCK_SUBSTEPS
	for i in PUCK_SUBSTEPS:
		var carried := puck.controller == skater
		var p0 := puck.position
		var v0 := puck.vel
		StickPuck.step(game, puck, sdt, float(i + 1) / PUCK_SUBSTEPS)
		if carried and hands_on and puck.controller == skater:
			_soft_cup(puck, p0, v0, sdt)
		puck.integrate(sdt)
		if ice_feel and puck.controller == null:
			touch.apply(puck, sheet, to_sheet, sdt)
		if sure_hands:
			_sure_hands()
	game.time += dt
	game.camera_rig.pull = hands.pull if hands_on else 0.0
	game.camera_rig.ride(skater, _walker, dt)
	# the ice under the blades
	var v := skater.speed()
	var a1: Vector2 = to_sheet.call(skater.global_position)
	if v > 0.05 and a1 != a0:
		var dir := (a1 - a0).normalized()
		if skater.turn_load > TURN_G:
			SkateWear.turn(sheet, a0, a1, dir, skater.turn_load, skater.yaw_rate > 0.0)
		SkateWear.glide(sheet, a0, a1, dir, v)


## A loose puck the stick can reach, or one that just slipped off the
## blade, is on the blade: the stick's own 220 degree arc and one-hand
## reach, no release in progress (a shot or a pass goes), the puck on the ice.
func _sure_hands() -> void:
	var puck := game.puck
	if puck.controller == skater or puck.frozen or puck.in_net_side != 0 or puck.out_of_play:
		return
	if not puck.can_be_touched_by(skater) or puck.position.y > StickPuck.BLADE_TOP:
		return
	var to := puck.position - skater.global_position
	to.y = 0.0
	var slipped := puck.controller == null and puck.last_touch == skater
	if not slipped:
		if to.length() > SURE_REACH:
			return
		if (
			absf(skater.heading.signed_angle_to(to, Vector3.UP)) > Skater.ARC_HALF
			and to.length() > 0.3
		):
			return
	# yours: within the hands' feel the cup draws it onto the face from
	# where it is (no jump); further out it is on the blade at once
	puck.controller = skater
	puck.last_touch = skater
	if puck.position.distance_to(skater.blade_pos) > StickPuck.CARRY_REACH:
		var anchor := skater.puck_anchor()
		puck.position = Vector3(anchor.x, 0.0, anchor.z)
		puck.vel = skater.vel
	game.on_possession(skater)


## The game's cup pulls a carried puck onto the blade's face at 25/s, so
## nothing the hands do shows in the puck. At a fast blade part of that
## pull is let go: the puck lags a snap, gets ahead of a stop and rolls
## along the face, which is what stickhandling feels like.
func _soft_cup(puck: Puck, p0: Vector3, v0: Vector3, dt: float) -> void:
	var bv := skater.blade_lvel.length()  # the blade's speed in the hands, not the body's
	var soft := CUP_SOFT * clampf((bv - CUP_SOFT_V.x) / (CUP_SOFT_V.y - CUP_SOFT_V.x), 0.0, 1.0)
	if soft <= 0.0:
		return
	var free := p0 + v0 * dt
	free.y = puck.position.y
	puck.position = puck.position.lerp(free, soft)
	puck.vel = puck.vel.lerp(v0, soft)


## The swing ended (DemoHands): the shot goes now, as if RMB were let go.
func _release_swing() -> void:
	Input.action_release(&"shot_trace")


func _on_stride(at: Vector3, speed: float, foot: int) -> void:
	stride_count += 1
	if _sheet == null:
		return
	var h := skater.heading
	SkateWear.stride(_sheet, _to_sheet.call(at), Vector2(h.x, h.z), float(foot), speed)


func _on_stop(at: Vector3, speed: float) -> void:
	if _sheet == null:
		return
	var d := Vector2(skater.vel.x, skater.vel.z)
	if d.length() < 0.1:
		return
	SkateWear.stop(
		_sheet,
		_to_sheet.call(at),
		d.normalized(),
		speed,
		skater.profile.stop_decel,
		Skater.STOP_EVERY
	)


func vel2() -> Vector2:
	return Vector2(skater.vel.x, skater.vel.z)


func state_text() -> String:
	var puck_s := "ON THE BLADE" if skater.has_puck() else "LOOSE ON %s" % touch.surface
	return (
		"SKATING %.1f M/S%s%s   STRIDES %d   PUCK %s   HANDS %.0f PX/S"
		% [
			skater.speed(),
			"  STOPPING" if skater.braking else "",
			"  BACKWARDS" if skater.backwards else "",
			stride_count,
			puck_s,
			hands.hand_speed
		]
	)


## The blade, world: where a puck is carried.
func blade_world() -> Vector3:
	return skater.blade_pos
