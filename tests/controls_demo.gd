extends Node
## Scripted showcase of the controls: drives the human through PlayerInput
## (the same path a pad or mouse uses) one move at a time, with captions.
## Record it with Godot's movie writer:
##   godot --path . --write-movie demo.avi --fixed-fps 30 --resolution 1280x720 -- --demo=controls
## `-- --demo=skating` plays a short close-up reel of the skating animation,
## `-- --demo=moves` the stick arc and every learned shot and stick move, with
## the right stick's path drawn on a pad in the corner. Each segment's start
## time in the video is printed ("SEG <seconds> <name>") for cutting clips.

var game: Node
var _plan := Callable()
var _t := 0.0
var _caption: Label
var _sub: Label
var _keep: Array = []
var _show_net := false
var _zoom := 6.5
var _mode := "controls"
var _cam: Camera3D
var _cam_dir := Vector3.ZERO
var _cam_angle := 80.0   # degrees from the skater's heading towards their right
var _cam_dist := 3.6
var _cam_height := 1.3
var _pad: StickPad
var _frames := 0         # physics frames since the start, for segment times


func _ready() -> void:
	seed(int(OS.get_environment("DEMO_SEED")) if OS.has_environment("DEMO_SEED") else 1)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--demo="):
			_mode = a.trim_prefix("--demo=")
	_make_captions()
	await get_tree().physics_frame
	# everyone gets the same middling ratings so the run is repeatable
	for sk in game.skaters:
		for key in Skills.SKATER_KEYS:
			sk.skills.values[key] = 55.0
	game.hud.toggle_help()
	game.camera_rig.toggle()  # isometric
	game.camera_rig.zoom = _zoom
	game.controller.player_input.scripted = func(f, dt):
		_t += dt
		if _plan.is_valid():
			_plan.call(f, _t)
	if _mode != "controls":
		# close-up camera that rides alongside the skater
		_cam = Camera3D.new()
		_cam.fov = 42.0
		add_child(_cam)
		_cam.make_current()
		game.hud.visible = false
	match _mode:
		"skating":
			await _run_skating()
		"moves":
			await _run_moves()
		_:
			await _run()
	get_tree().quit()


func _process(dt: float) -> void:
	if game and _cam:
		var h: Skater = game.human
		var a := deg_to_rad(_cam_angle)
		var want: Vector3 = (h.heading * cos(a) + h.right_vec() * sin(a)).normalized()
		_cam_dir = want if _cam_dir == Vector3.ZERO else _cam_dir.slerp(want, 1.0 - exp(-2.5 * dt)).normalized()
		var target: Vector3 = h.position + Vector3.UP * 0.75
		_cam.position = target + _cam_dir * _cam_dist + Vector3.UP * (_cam_height - 0.75)
		_cam.look_at(target)
	elif game:
		var f: Vector3 = game.human.position + game.human.heading * 1.5
		if _show_net:
			f = game.human.position.lerp(game.human.attack_goal(), 0.5)
		game.camera_rig.zoom = lerpf(game.camera_rig.zoom, 10.0 if _show_net else _zoom, 0.08)
		# CameraRig.follow halves z, so pre-double it to keep the player centred
		game._focus_override = Vector3(f.x, 0, f.z * 2.0)


func _run_moves() -> void:
	var h = game.human
	h.skills.values["shot_release"] = 70.0
	h.skills.values["stick_handling"] = 70.0
	_pad = StickPad.new()
	_pad.skater = h
	_pad.game = game
	_caption.get_parent().get_parent().get_parent().add_child(_pad)

	_seg("The stick: a 220 degree arc", "Two hands in the front 90 degrees, one hand past it. Behind the hip (to 110) is the shot wind-up.")
	_cam_angle = 180.0
	_cam_dist = 2.6
	_cam_height = 3.0
	await _reset(Vector2(-6, 0), false)
	_set_plan(func(f, t):
		f.stick = _at(sin(t * 0.9) * 93.0, 0.9))
	await _hold(7.0)

	_cam_angle = 75.0
	_cam_dist = 3.8
	_cam_height = 1.4
	_seg("Stickhandling in close", "Two hands, small quick moves in front of the body.")
	await _reset(Vector2(-6, 0), true)
	_set_plan(func(f, t):
		f.move = _screen(Vector2(0.25, 0))
		f.stick = _at(sin(t * TAU * 1.5) * 40.0, 0.7))
	await _hold(3.5)
	_seg("Wide reach", "Past the front 90 degrees the bottom hand lets go and the top hand reaches.")
	_set_plan(func(f, t):
		f.move = _screen(Vector2(0.25, 0))
		f.stick = _at(sin(t * TAU * 0.45 + asin(40.0 / 85.0)) * 85.0, 0.95))  # carries on from 40 deg
	await _hold(4.5)

	await _move_clip("Quick shot", "Starter. Flick forward from neutral: instant, weak.", func(f, t):
		f.stick = _at(0.0, 1.0) if t > 0.5 else Vector2.ZERO)
	await _move_clip("Wrist shot", "Starter. Draw back behind the forehand hip, sweep forward.", func(f, t):
		f.stick = _at(lerpf(30.0, 110.0, clampf(t / 0.4, 0.0, 1.0)), 0.9) if t < 1.1 else _at(lerpf(110.0, 0.0, clampf((t - 1.1) / 0.12, 0.0, 1.0)), 1.0))
	await _move_clip("Snapshot", "Learned. Pull out to the forehand side, then snap all the way forward.", func(f, t):
		f.stick = _at(lerpf(10.0, 50.0, clampf(t / 0.3, 0.0, 1.0)), 0.85) if t < 0.75 else _at(0.0, 1.0))
	await _move_clip("Slapshot", "Learned. Hold LT while you draw back, then forward.", func(f, t):
		f.lift = 1.0 if t > 0.35 and t < 1.3 else 0.0
		f.stick = _at(lerpf(30.0, 110.0, clampf(t / 0.4, 0.0, 1.0)), 0.95) if t < 1.3 else _at(0.0, 1.0))
	await _move_clip("Backhand", "Starter. Draw back behind the backhand hip, sweep forward.", func(f, t):
		f.stick = _at(lerpf(-30.0, -110.0, clampf(t / 0.4, 0.0, 1.0)), 0.9) if t < 1.0 else _at(lerpf(-110.0, 0.0, clampf((t - 1.0) / 0.12, 0.0, 1.0)), 1.0), 3.0, -75.0)
	await _move_clip("Backhand snap", "Learned. Pull out to the backhand side, then snap all the way forward.", func(f, t):
		f.stick = _at(lerpf(-10.0, -50.0, clampf(t / 0.3, 0.0, 1.0)), 0.85) if t < 0.75 else _at(0.0, 1.0), 3.0, -75.0)
	await _move_clip("Quick deke", "Learned. Whip the stick forehand, backhand, forehand.", func(f, t):
		f.move = _screen(Vector2(0.3, 0))
		var a: float = 40.0 if t < 0.6 or t > 0.8 else -50.0
		f.stick = _at(a, 0.8) if t > 0.3 else Vector2.ZERO, 3.0, 30.0)
	await _move_clip("Toe drag", "Learned. Hold RT, stick out front, pull it back across to the backhand.", func(f, t):
		f.move = _screen(Vector2(0.3, 0))
		f.tilt = 1.0 if t > 0.3 and t < 1.4 else 0.0
		f.stick = _at(0.0, minf(t / 0.4, 1.0) * 0.5) if t < 0.8 else (_at(-80.0, 0.8) if t < 0.86 else _at(-25.0, 0.5)), 3.2, 30.0)
	await _move_clip("Toe drag shot", "Learned. Hold LT and RT, stick out front, pull it back across.", func(f, t):
		f.tilt = 1.0 if t > 0.3 and t < 1.4 else 0.0
		f.lift = 1.0 if t > 0.7 and t < 1.0 else 0.0
		f.stick = _at(0.0, minf(t / 0.4, 1.0) * 0.5) if t < 0.8 else (_at(-80.0, 0.8) if t < 0.86 else _at(-25.0, 0.5)), 3.2, 30.0)
	await _move_clip("Lacrosse", "Learned. Hold RT, sweep from the backhand round to the forehand, then push forward.", func(f, t):
		f.tilt = 1.0 if t > 0.2 and t < 2.0 else 0.0
		f.stick = _at(lerpf(-60.0, 120.0, clampf((t - 0.5) / 0.4, 0.0, 1.0)), minf(t / 0.3, 0.85)) if t < 1.7 else _at(0.0, 1.0), 4.0, 125.0)
	_seg("", "")
	_title("", "")


## One move: reset with the puck, run the stick plan, hold long enough to see
## the follow-through.
func _move_clip(title: String, sub: String, plan: Callable, seconds := 3.0, cam := 75.0) -> void:
	_cam_angle = cam
	await _reset(Vector2(-6, 0), true)
	_seg(title, sub)
	_set_plan(plan)
	await _hold(seconds)


## A segment starts: caption it and log its time in the video.
func _seg(title: String, sub: String) -> void:
	print("SEG %.2f %s" % [_frames / 120.0, title if title != "" else "END"])
	_title(title, sub)


## Screen-space stick for a skater-relative angle (0 ahead, + forehand) and length.
func _at(deg: float, r: float) -> Vector2:
	var a := deg_to_rad(deg)
	return _screen(Vector2(cos(a), sin(a)) * r)


func _run_skating() -> void:
	_cam_angle = 90.0
	_cam_dist = 3.8
	_cam_height = 1.2
	_title("Ready stance", "Knees bent, weight over the skates.")
	await _reset(Vector2(-20, 0), false)
	await _hold(2.0)
	_title("Stride", "Each push goes out and back; the other leg glides and recovers under the hips.")
	_set_plan(func(f, _t2): f.move = _screen(Vector2(1, 0)))
	await _hold(5.0)
	_title("Turning", "Lean into the turn; the outside leg crosses over.")
	_set_plan(func(f, t): f.move = _screen(Vector2(cos(t * 1.3), sin(t * 1.3))))
	await _hold(5.0)
	_title("Hockey stop", "Skates turn sideways, knees drop, shoulders stay up.")
	_set_plan(func(f, t):
		f.move = _screen(Vector2(1, 0)) if t < 1.6 else Vector2.ZERO
		f.stop = t >= 1.6)
	await _hold(3.2)
	_title("Stickhandling on the move", "")
	await _reset(Vector2(-20, 0), true)
	_set_plan(func(f, t):
		f.move = _screen(Vector2(0.6, 0))
		f.stick = _screen(Vector2(0.75, sin(t * TAU * 1.6) * 0.9)))
	await _hold(4.0)
	_title("Wind-up shot", "")
	_set_plan(func(f, t):
		f.move = _screen(Vector2(0.4, 0))
		f.stick = _screen(Vector2(-1, 0.2)) if t < 1.0 else _screen(Vector2(1, 0)))
	await _hold(2.2)
	_title("", "")


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
		_frames += 1
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


## Right-stick pad drawn in the corner: the reachable 220 degree arc (brighter
## where both hands stay on), the stick's recent path, LT/RT, and the name of
## the move when one comes off. Up on the pad is the skater's forward, right is
## the forehand.
class StickPad extends Control:
	const R := 86.0
	var skater
	var game: Node
	var _trail: Array[Vector2] = []
	var _shots := 0
	var _move := &""
	var _label := ""
	var _label_t := 0.0
	var _font: Font

	func _ready() -> void:
		_font = ThemeDB.fallback_font
		set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		position = Vector2(1280 - 2 * R - 60, 720 - 2 * R - 110)
		size = Vector2(2 * R + 40, 2 * R + 80)

	func _process(dt: float) -> void:
		var l := Vector2.ZERO
		var st: Vector2 = skater.ctrl.stick
		if st.length() > 0.05:
			var w := Vector3(st.x, 0, st.y)
			l = Vector2(w.dot(skater.right_vec()), -w.dot(skater.heading))
		_trail.append(l)
		while _trail.size() > 36:
			_trail.pop_front()
		if game.stats.shots > _shots:
			_shots = game.stats.shots
			if _label_t <= 0.0:
				_label = "Shot"
				_label_t = 1.6
		if skater.move_id != _move:
			_move = skater.move_id
			if _move != &"":
				_label = Moves.display_name(_move)
				_label_t = 1.6
		_label_t -= dt
		queue_redraw()

	func _wedge(c: Vector2, from_deg: float, to_deg: float, col: Color) -> void:
		var pts := PackedVector2Array([c])
		var n := 24
		for i in n + 1:
			var a := deg_to_rad(lerpf(from_deg, to_deg, float(i) / n))
			pts.append(c + Vector2(sin(a), -cos(a)) * R)
		draw_colored_polygon(pts, col)

	func _draw() -> void:
		var c := Vector2(R + 20, R + 46)
		draw_circle(c, R + 6, Color(0.06, 0.06, 0.08, 0.78))
		_wedge(c, -110, 110, Color(1, 1, 1, 0.10))
		_wedge(c, -45, 45, Color(1, 1, 1, 0.16))
		draw_line(c, c + Vector2(0, -R), Color(1, 1, 1, 0.25), 1.0)
		draw_string(_font, c + Vector2(-R + 4, 6), "BH", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.5))
		draw_string(_font, c + Vector2(R - 22, 6), "FH", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.5))
		if _trail.size() > 1:
			var pts := PackedVector2Array()
			var cols := PackedColorArray()
			for i in _trail.size():
				pts.append(c + _trail[i] * R)
				cols.append(Color(1.0, 0.8, 0.25, float(i) / _trail.size()))
			draw_polyline_colors(pts, cols, 4.0, true)
		draw_circle(c + (_trail[-1] if _trail.size() > 0 else Vector2.ZERO) * R, 9, Color(1.0, 0.85, 0.3))
		var lt: bool = skater.ctrl.lift
		var rt: bool = skater.ctrl.tilt > 0.3
		_pill(Vector2(c.x - R, 4), "LT lift", lt)
		_pill(Vector2(c.x + R - 70, 4), "RT tilt", rt)
		draw_string(_font, Vector2(c.x - R, c.y + R + 26), "Right stick / mouse", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.6))
		if _label_t > 0.0:
			var a := clampf(_label_t / 0.4, 0.0, 1.0)
			draw_string(_font, Vector2(c.x - R, c.y - R - 14), _label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.85, 0.3, a))

	func _pill(p: Vector2, text: String, on: bool) -> void:
		draw_rect(Rect2(p, Vector2(70, 26)), Color(1.0, 0.75, 0.2, 0.95) if on else Color(0.2, 0.2, 0.24, 0.85))
		draw_string(_font, p + Vector2(9, 18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.05, 0.05, 0.05) if on else Color(1, 1, 1, 0.7))
