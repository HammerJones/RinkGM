class_name HumanController
extends Node
## Fills the human skater's Skater.Controls each tick from PlayerInput. Only
## reads intent: what the stick, lift and tilt do on the ice (arc, wind-ups,
## slapshots, dekes, stick lifts, skill effects) is the simulation's job.

var game: Node
var player_input: PlayerInput
var _pass_call_until := -10.0
var gestures := StickGestures.new()


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
	c.dash = f.dash
	c.stop = f.stop
	c.check = f.check_pressed
	c.turn_around = f.turn_pressed
	game.camera_rig.free_look(f.look, f.looking)
	c.lift = f.lift > 0.5
	c.tilt = f.tilt
	var sw := right * f.stick.x + fwd * f.stick.y
	c.stick = Vector2(sw.x, sw.z)
	# stick patterns for learned moves (Moves); physics runs them
	var local := Vector2(sw.dot(human.heading), sw.dot(human.right_vec()))
	c.move_id = gestures.feed(local, f.tilt, c.lift, human.has_puck(), dt)
	# shots go at the net; lean on the left stick to pick the near or far post
	c.aim_point = human.attack_goal() + Vector3(0, 0, clampf(w.z, -1.0, 1.0) * 0.75)
	# passes go where you're skating, else where the stick points
	c.pass_dir = c.move if c.move.length() > 0.3 else c.stick
	if f.pass_pressed:
		if human.has_puck():
			c.pass_pressed = true
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
