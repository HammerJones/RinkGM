extends Node
## Scripted showcase of the controls: drives the human through PlayerInput
## (the same path a pad or mouse uses) one move at a time, with captions.
## Record it with Godot's movie writer:
##   godot --path . --write-movie demo.avi --fixed-fps 30 --resolution 1280x720 -- --demo=controls

var game: Node
var _plan := Callable()
var _t := 0.0
var _caption: Label
var _sub: Label
var _keep: Array = []
var _show_net := false


func _ready() -> void:
	seed(int(OS.get_environment("DEMO_SEED")) if OS.has_environment("DEMO_SEED") else 1)
	_make_captions()
	await get_tree().physics_frame
	# everyone gets the same middling ratings so the run is repeatable
	for sk in game.skaters:
		for key in Skills.SKATER_KEYS:
			sk.skills.values[key] = 55.0
	game.hud.toggle_help()
	game.camera_rig.toggle()  # isometric
	game.camera_rig.zoom = 6.5
	game.controller.player_input.scripted = func(f, dt):
		_t += dt
		if _plan.is_valid():
			_plan.call(f, _t)
	await _run()
	get_tree().quit()


func _process(_dt: float) -> void:
	if game:
		var f: Vector3 = game.human.position + game.human.heading * 1.5
		if _show_net:
			f = game.human.position.lerp(game.human.attack_goal(), 0.5)
		game.camera_rig.zoom = lerpf(game.camera_rig.zoom, 10.0 if _show_net else 6.5, 0.08)
		# CameraRig.follow halves z, so pre-double it to keep the player centred
		game._focus_override = Vector3(f.x, 0, f.z * 2.0)


func _run() -> void:
	var h: Skater = game.human
	_title("RinkGM controls", "Pad: Slapshot Rebound style.  Keyboard + mouse: the mouse is the right stick.")
	await _reset(Vector2(-14, 0), false)
	await _hold(2.5)

	_title("Skating", "Left stick / WASD. You push along your skates, so turns carve.")
	await _reset(Vector2(-18, -3), false)
	_set_plan(func(f, t):
		var a: float = 0.0 if t < 1.6 else (t - 1.6) * 1.4
		f.move = _screen(Vector2(cos(a), sin(a))))
	await _hold(4.5)

	_title("Dash", "L3 / Shift: a hard push-off. Costs stamina.")
	await _reset(Vector2(-18, 0), false)
	_set_plan(func(f, t):
		f.move = _screen(Vector2(1, 0))
		f.dash = (t > 1.0 and t < 1.04) or (t > 2.0 and t < 2.04))
	await _hold(3.2)

	_title("Hockey stop", "R3 / Space: skates turn sideways and scrape off speed.")
	_set_plan(func(f, t):
		f.move = _screen(Vector2(1, 0)) if t < 0.3 else Vector2.ZERO
		f.stop = t >= 0.3)
	await _hold(2.5)

	_title("The stick: a 90 degree arc", "Right stick / mouse moves the blade anywhere in the arc in front of you.")
	await _reset(Vector2(-14, 0), true)
	_set_plan(func(f, t):
		var a: float = sin(t * 1.6) * PI * 0.5
		f.stick = _screen(Vector2(cos(a), sin(a)) * (0.55 + 0.45 * absf(sin(t * 0.8)))))
	await _hold(5.0)

	_title("Stickhandling: Stick Handling 35", "Side to side moves the puck. Low rating: slower blade, looser puck.")
	h.skills.values["stick_handling"] = 35.0
	await _reset(Vector2(-18, 0), true)
	_set_plan(func(f, t):
		f.move = _screen(Vector2(0.45, 0))
		f.stick = _screen(Vector2(0.75, sin(t * TAU * 2.2) * 0.9)))
	await _hold(4.0)

	_title("Stickhandling: Stick Handling 90", "Same input, a skilled hand: faster blade, puck stays on the tape.")
	h.skills.values["stick_handling"] = 90.0
	await _reset(Vector2(-18, 0), true)
	await _hold(4.0)
	h.skills.values["stick_handling"] = 50.0

	_title("Deke", "LT / right click lifts the blade over the puck; put it down past it and pull.")
	for side in [1.0, -1.0]:
		await _reset(Vector2(-18, 0), true)
		_set_plan(func(f, t):
			f.move = _screen(Vector2(0.4, 0))
			if t < 0.6:
				f.stick = _screen(Vector2(0.7, 0.6 * side))
			elif t < 0.8:
				f.stick = _screen(Vector2(0.7, 0.1 * side))
				f.lift = 1.0
			else:
				f.stick = _screen(Vector2(0.6, -0.8 * side)))
		await _hold(2.4)

	_title("Quick shot", "Flick the stick forward: instant release. Power and accuracy grow with Shot Release.")
	await _shoot_from(Vector2(14, 3), func(f, t):
		f.move = _screen(Vector2(0.3, 0))
		f.stick = _screen(Vector2(1, 0)) if t > 0.6 else Vector2.ZERO)

	_title("Wind-up shot", "Pull the stick behind you, then push it forward. Longer pull = more power.")
	await _shoot_from(Vector2(12, -3), func(f, t):
		f.stick = _screen(Vector2(-1, 0.2)) if t < 1.2 else _screen(Vector2(1, 0)))

	_title("Slapshot", "Hold LT / right click while you pull back: the stick comes up high.")
	await _shoot_from(Vector2(8, 4), func(f, t):
		f.stick = _screen(Vector2(-1, 0.2)) if t < 1.4 else _screen(Vector2(1, 0))
		f.lift = 1.0 if t < 1.4 else 0.0)

	_title("Tilt the blade", "RT / left click opens the blade face: the shot goes top shelf.")
	await _shoot_from(Vector2(15, -2), func(f, t):
		f.stick = _screen(Vector2(-1, 0.2)) if t < 1.0 else _screen(Vector2(1, 0))
		f.tilt = 1.0)

	_title("Passing", "A / E passes where you skate or point the stick. Pass Quality sets the accuracy.")
	await _reset(Vector2(-16, -4), true)
	var mate: Skater = game.teammates(h)[0]
	mate.place(Vector2(-6, 3), Vector3(-1, 0, 0))
	mate.stun_timer = 0.0
	_keep = [mate]
	_set_plan(func(f, t):
		f.move = _screen(Vector2(0.4, 0.3)) if t < 0.8 else Vector2.ZERO
		f.stick = _screen(Vector2(0.6, 0.3))
		f.pass_pressed = t > 0.8 and t < 0.84)
	await _hold(3.5)

	_title("Call for the puck", "A / E without the puck: an open teammate feeds you.")
	# a pass can still be fumbled on the catch; show up to three tries
	for attempt in 3:
		await _reset(Vector2(-6, -2), false, Vector3(-1, 0, 0))
		mate.place(Vector2(-14, 2), Vector3(1, 0, 0))
		mate.stun_timer = 0.0
		_keep = [mate]
		game.puck.reset_at(mate.puck_anchor())
		game.puck.controller = mate
		_set_plan(func(f, t):
			f.stick = _screen(Vector2(0.8, 0.0))
			f.pass_pressed = t > 0.5 and t < 0.54)
		await _hold(3.0)
		if h.has_puck():
			await _hold(0.5)
			break

	_title("Stick lift on defense", "LT / right click near the carrier's stick lifts it and frees the puck.")
	for i in 3:
		await _reset(Vector2(-15, 0), false)
		var opp: Skater = game.team_skaters(1)[0]
		opp.place(Vector2(-13.5, 0.4), Vector3(-1, 0, 0))
		opp.stun_timer = 0.0
		_keep = [opp]
		game.puck.reset_at(opp.puck_anchor())
		game.puck.controller = opp
		h.lift_cd = 0.0
		_set_plan(func(f, t):
			f.stick = _screen(Vector2(0.8, 0.2))
			f.lift = 1.0 if t > 0.5 and t < 0.9 else 0.0)
		await _hold(1.6)

	_title("", "")
	_keep = []


func _shoot_from(p: Vector2, plan: Callable) -> void:
	_show_net = true
	await _reset(p, true)
	_set_plan(plan)
	await _hold(3.4)
	_show_net = false


## Puts the human at `p` (facing the attacking net by default), with or without the puck.
func _reset(p: Vector2, with_puck: bool, facing := Vector3(1, 0, 0)) -> void:
	_plan = Callable()
	_keep = []
	game.state = game.State.PLAY
	game.clock = 300.0
	game.human.place(p, facing)
	if with_puck:
		game.puck.reset_at(game.human.puck_anchor())
		game.puck.controller = game.human
	else:
		game.puck.reset_at(Vector3(28, 0, 14))
	for g in game.goalies:
		g.reset()
	await _hold(0.3)
	_t = 0.0


func _set_plan(plan: Callable) -> void:
	_plan = plan
	_t = 0.0


func _hold(seconds: float) -> void:
	for i in int(seconds * 120.0):
		await get_tree().physics_frame
		_park_others()


## Everyone else stands at the far end out of shot, unless kept in the scene.
func _park_others() -> void:
	game.state = game.State.PLAY
	for s in game.skaters:
		if s != game.human and not s in _keep:
			s.stun_timer = 1.0
			s.position = Vector3(-26 + s.number * 1.2, 0, 11 + s.team * 1.5)
			s.vel = Vector3.ZERO


## Skater-relative (forward, right) to the screen-space stick PlayerInput gives.
func _screen(local: Vector2) -> Vector2:
	var h: Skater = game.human
	var w: Vector3 = h.heading * local.x + h.right_vec() * local.y
	return Vector2(w.dot(game.camera_rig.right_flat()), w.dot(game.camera_rig.forward_flat()))


func _title(title: String, sub: String) -> void:
	if _caption.text != "":
		print("%-36s carried %-5s shots %d goals %d lifts %d puck %.1f m/s owner %s" % [_caption.text, game.human.has_puck(), game.stats.shots, game.stats.goals, game.stats.stick_lifts, game.puck.vel.length(), game.puck.controller.name if game.puck.controller else "-"])
	_caption.text = title
	_sub.text = sub
	_caption.get_parent().visible = title != ""


func _make_captions() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.06, 0.08, 0.82)
	box.set_corner_radius_all(6)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 8
	box.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", box)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -40
	layer.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_caption)
	_sub = Label.new()
	_sub.add_theme_font_size_override("font_size", 17)
	_sub.add_theme_color_override("font_color", Color(0.85, 0.87, 0.92))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_sub)
