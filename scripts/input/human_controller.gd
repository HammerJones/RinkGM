class_name HumanController
extends Node
## Fills the human skater's Controls each tick from PlayerInput (devices) and
## StickControl (stick gestures). Game calls update() before the skaters move.

var game: Node
var player_input: PlayerInput
var stick_control := StickControl.new()
var _pass_call_until := -10.0


func _ready() -> void:
	player_input = PlayerInput.new()
	add_child(player_input)


func update(dt: float) -> void:
	var human: Skater = game.human
	var c := human.ctrl
	c.reset()
	var f := player_input.poll(dt)
	var fwd: Vector3 = game.camera_rig.forward_flat()
	var right: Vector3 = game.camera_rig.right_flat()
	var w := right * f.move.x + fwd * f.move.y
	c.move = Vector2(w.x, w.z)
	c.brake = f.stop
	c.dash = f.dash
	c.check_pressed = f.check_pressed
	var sw := right * f.stick.x + fwd * f.stick.y
	var stick := Vector2(sw.x, sw.z)
	stick_control.update(human, stick, f.lift, f.tilt, dt)
	if f.pass_pressed:
		if human.has_puck():
			# pass where you're skating, else where the stick points
			var dir := c.move if c.move.length() > 0.3 else stick
			stick_control.pass_puck(human, dir, f.tilt)
		else:
			_pass_call_until = game.time + 1.2
			game.hud.show_message("PASS!", 0.6)


## The human if they're calling for a pass from `carrier` and the lane is open enough.
func pass_caller(carrier: Skater) -> Skater:
	var human: Skater = game.human
	if game.time > _pass_call_until or carrier.team != human.team or carrier == human:
		return null
	var from := Vector2(carrier.position.x, carrier.position.z)
	if not game.lane_clear(carrier.team, from, Vector2(human.position.x, human.position.z), 0.8):
		return null
	_pass_call_until = -10.0
	return human
