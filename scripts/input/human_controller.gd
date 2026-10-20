class_name HumanController
extends Node
## Fills the human skater's Skater.Controls each tick from PlayerInput. Only
## reads intent: what the stick does on the ice (arc, stickhandling, skill
## effects) is the simulation's job.
##
## Keyboard + mouse (Sean, 19 Oct): shots are traced patterns (ShotPatterns)
## drawn with RMB held, aimed at the net or, with LMB held, at the centre dot.
## How fast the forward stroke goes sets the power (shot power lets a slower
## stroke hit as hard), how cleanly it matches the pattern sets how far from
## the aim it can land (shot accuracy forgives a wobblier pattern). The gamepad
## keeps the stick-motion shots and moves for now.

## Engine.time_scale the game should run at (a maxed shooter's slowed clock
## while drawing a shot); Game reads it.
var time_slow := 1.0
## Tests: drive the human with the gamepad scheme (stick-motion shots and
## moves) even though the scripted input isn't a pad.
var pad_scheme := false

var game: Node
var player_input: PlayerInput
var overlay: ShotOverlay
var _pass_call_until := -10.0
var gestures := StickGestures.new()
var _aim_dot: Variant = null   # where the centre dot was when the pattern started
var last_shot := {}            # the last traced shot's grade (tests, HUD)
var _stick_prev := Vector2.ZERO

## Puck speed of each traced shot at full power, of the skater's slapshot.
const SHOT_POWER := {&"slapshot": 1.0, &"snap_shot": 0.88, &"wrist_shot": 0.8, &"toe_drag_shot": 0.75}
## Forward-stroke speed (px/s) for full power, at shot power 0 and 1.
const FULL_STROKE := Vector2(2600.0, 1300.0)
## How far from the aim a shot can land (m), for a sloppy and a perfect pattern.
const SPREAD := Vector2(1.4, 0.06)


func _ready() -> void:
	player_input = PlayerInput.new()
	add_child(player_input)
	overlay = ShotOverlay.new()
	add_child(overlay)


func update(dt: float) -> void:
	var human: Skater = game.human
	var c := human.ctrl
	c.reset()
	var f := player_input.poll(dt)
	var kbm := InputSetup.device != InputSetup.Device.PAD and not pad_scheme
	human.traced_shots = kbm
	var fwd: Vector3 = game.camera_rig.forward_flat()
	var right: Vector3 = game.camera_rig.right_flat()
	var w := right * f.move.x + fwd * f.move.y
	c.move = Vector2(w.x, w.z)
	# on the keyboard, pushing against the way you're skating brakes rather
	# than turning you round (S going forwards, W going backwards on the
	# chase camera)
	var brake := false
	var going := Vector2(human.vel.x, human.vel.z)
	if kbm and going.length() > 0.6 and c.move.length() > 0.3 \
			and going.normalized().dot(c.move.normalized()) < -0.7:
		brake = true
		c.move = Vector2.ZERO
	c.dash = f.dash
	c.stop = f.stop or brake
	c.check = f.check_pressed
	c.turn_around = f.turn_pressed
	game.camera_rig.free_look(Vector2.ZERO if f.tracing else f.look, f.looking)
	c.lift = f.lift > 0.5
	c.tilt = f.tilt
	# the pad's stick is camera-relative; the mouse places the blade around
	# the body (up is where you face), so turning carries the puck round with
	# you instead of leaving the blade pointing where it was
	var s_right := human.right_vec() if kbm else right
	var s_fwd := human.heading if kbm else fwd
	var sw := s_right * f.stick.x + s_fwd * f.stick.y
	c.stick = Vector2(sw.x, sw.z)
	var ds := f.stick - _stick_prev
	_stick_prev = f.stick
	var dw := s_right * ds.x + s_fwd * ds.y
	c.stick_move = Vector2(dw.x, dw.z)
	if not kbm:
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
	_traced(human, f)


## RMB patterns: lock the aim when the drawing starts, shoot on release.
func _traced(human: Skater, f: PlayerInput.Frame) -> void:
	if f.tracing and _aim_dot == null:
		# the shot goes where the centre dot is, not automatically at the net
		_aim_dot = aim_from_view()
		if _aim_dot == null:
			_aim_dot = false
	var shooter := (human.skill("shot_accuracy") + human.skill("shot_power") + human.skill("shot_release")) / 3.0
	time_slow = 0.35 if f.tracing and shooter >= 0.95 else 1.0
	overlay.show_state(f.looking, f.tracing, f.trace_pos, human.handle_load if human.has_puck() else -1.0)
	if f.trace_done:
		var aim: Variant = _aim_dot
		_aim_dot = null
		var target: Vector3 = aim if aim is Vector3 else net_target(human)
		last_shot = grade(human, f.trace, target)
		if last_shot.ok:
			last_shot.fired = human.shoot_traced(last_shot.kind, last_shot.puck_speed, last_shot.landing)
			if last_shot.fired:
				game.hud.show_message("%s  %d%%" % [ShotPatterns.NAMES[last_shot.kind], roundi(last_shot.match * 100.0)], 0.8)


## The middle of the net, a little off the ice.
func net_target(human: Skater) -> Vector3:
	return human.attack_goal() + Vector3(0, 0.45, 0)


## Where the centre dot points: where it meets the plane of the net you
## attack (kept on the ice surface, up to the glass), or a point 20 m along
## the view when it points away from that end. Null only without a view.
func aim_from_view() -> Variant:
	var rig: CameraRig = game.camera_rig
	var vp := rig.get_viewport()
	if vp == null:
		return null
	var mid := vp.get_visible_rect().size * 0.5
	var o := rig.cam.project_ray_origin(mid)
	var d := rig.cam.project_ray_normal(mid)
	var gx: float = game.human.attack_goal().x
	var p := o + d * 20.0
	if absf(d.x) > 0.0001 and (gx - o.x) / d.x > 0.0:
		p = o + d * ((gx - o.x) / d.x)
	var half := Rink.HALF_W - 0.3
	return Vector3(p.x, clampf(p.y, 0.05, 3.0), clampf(p.z, -half, half))


## Grades a drawn pattern into a shot: which one, how hard, where it lands.
func grade(human: Skater, trace: Array, target: Vector3) -> Dictionary:
	var g := ShotPatterns.match(trace, human.skill("shot_accuracy"))
	if not g.ok:
		return g
	var full := lerpf(FULL_STROKE.x, FULL_STROKE.y, human.skill("shot_power"))
	g.power = clampf(g.speed / full, 0.3, 1.0)
	g.puck_speed = human.profile.shot_speed * SHOT_POWER[g.kind] * lerpf(0.4, 1.0, g.power)
	g.radius = lerpf(SPREAD.x, SPREAD.y, g.match)
	# anywhere in the circle across the line of the shot, evenly
	var from := human.puck.position
	var across := Vector3(target.z - from.z, 0, from.x - target.x).normalized()
	var a := randf() * TAU
	var r: float = g.radius * sqrt(randf())
	g.landing = target + across * cos(a) * r + Vector3.UP * sin(a) * r
	g.landing.y = maxf(g.landing.y, 0.03)
	g.target = target
	return g


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
