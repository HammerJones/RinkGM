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

const SELF_LAYER := DemoRinkGame.DemoCameraRig.SELF_LAYER
const PUCK_SUBSTEPS := 4
const TURN_G := 3.0  # m/s2 of lateral load under which a turn leaves no edge mark

var active := false
var stride_count := 0
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
	var a0: Vector2 = to_sheet.call(skater.global_position)
	controller.update(dt)
	skater.physics_update(dt)
	var puck := game.puck
	var sdt := dt / PUCK_SUBSTEPS
	for i in PUCK_SUBSTEPS:
		StickPuck.step(game, puck, sdt, float(i + 1) / PUCK_SUBSTEPS)
		puck.integrate(sdt)
	game.time += dt
	game.camera_rig.follow(skater, _walker, dt)
	# the ice under the blades
	var v := skater.speed()
	var a1: Vector2 = to_sheet.call(skater.global_position)
	if v > 0.05 and a1 != a0:
		var dir := (a1 - a0).normalized()
		if skater.turn_load > TURN_G:
			SkateWear.turn(sheet, a0, a1, dir, skater.turn_load, skater.yaw_rate > 0.0)
		SkateWear.glide(sheet, a0, a1, dir, v)


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
	var puck_s := "ON THE BLADE" if skater.has_puck() else "LOOSE"
	return (
		"SKATING %.1f M/S%s%s   STRIDES %d   PUCK %s"
		% [
			skater.speed(),
			"  STOPPING" if skater.braking else "",
			"  BACKWARDS" if skater.backwards else "",
			stride_count,
			puck_s
		]
	)


## The blade, world: where a puck is carried.
func blade_world() -> Vector3:
	return skater.blade_pos
