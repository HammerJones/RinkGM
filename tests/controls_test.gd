extends Node
## Headless checks for the human control scheme. Drives the human through
## PlayerInput.scripted and prints what each gesture produced.
## Run: godot --headless --path . --fixed-fps 120 -- --test=controls
## (Game loads this node when it sees --test=controls.)

var game: Node
var _plan := Callable()
var _t := 0.0
var _fails := 0


func _ready() -> void:
	seed(12345)
	await get_tree().physics_frame
	game.player_input.scripted = func(f, dt):
		_t += dt
		if _plan.is_valid():
			_plan.call(f, _t)
	await _run()
	print("controls test: ", "FAILED %d" % _fails if _fails else "all passed")
	get_tree().quit(1 if _fails else 0)


func _run() -> void:
	var sc: StickControl = game.stick_control

	# --- quick shot: weak at low release, harder at high release
	for rel in [0.1, 0.5, 0.9]:
		sc.default_skills.shot_release = rel
		var v := await _shot_speed(func(f, t): f.stick = Vector2(1, 0) if t > 0.2 else Vector2.ZERO)
		print("quick shot  release %.1f -> %.1f m/s (%s)" % [rel, v, sc.last_event])
		_check(sc.last_event == "quick", "quick shot fires")
	sc.default_skills.shot_release = 0.5

	# --- wind-up shot and slapshot charge harder
	var quick := await _shot_speed(func(f, t): f.stick = Vector2(1, 0) if t > 0.2 else Vector2.ZERO)
	var wrist := await _shot_speed(func(f, t): f.stick = Vector2(-1, 0) if t < 0.8 else Vector2(1, 0))
	_check(sc.last_event == "wrist", "wind-up gives a wrist shot")
	var slap := await _shot_speed(func(f, t):
		f.stick = Vector2(-1, 0) if t < 1.0 else Vector2(1, 0)
		f.lift = 1.0 if t < 1.0 else 0.0)
	_check(sc.last_event == "slap", "lift + wind-up gives a slapshot")
	print("quick %.1f  wrist %.1f  slap %.1f m/s" % [quick, wrist, slap])
	_check(quick < wrist and wrist < slap, "wind-up and slapshot are harder than the quick shot")

	# --- tilt raises the shot
	await _carry(Vector2(18, 0))
	_plan = func(f, t):
		f.stick = Vector2(1, 0) if t > 0.2 else Vector2.ZERO
		f.tilt = 1.0
	await _wait(0.25)
	print("tilted shot vy %.2f" % game.puck.vel.y)
	_check(game.puck.vel.y > 1.0, "tilt lifts the shot")

	# --- stick stays inside the 90 degree arc
	await _carry(Vector2(-10, 0))
	_plan = func(f, _t2): f.stick = Vector2(0, -1)  # straight down the screen = right of a skater facing +x
	await _wait(0.5)
	var bl: Vector2 = game.human.blade_local
	var ang := rad_to_deg(atan2(bl.y, bl.x))
	print("stick pushed 90 deg right sits at %.0f deg" % ang)
	_check(absf(ang) <= 46.0, "blade limited to the arc")

	# --- stickhandling: low skill is slower and fumbles more than high skill
	var fumbled := []
	for sh in [0.1, 0.9]:
		sc.default_skills.stickhandling = sh
		var fumbles := 0
		for trial in 6:
			await _carry(Vector2(-15, 0))
			sc.events.clear()
			_plan = func(f, t): f.stick = Vector2(0.75, sin(t * TAU * 2.5) * 0.9)
			await _wait(3.0)
			fumbles += sc.events.count("fumble")
		fumbled.append(fumbles)
		print("stickhandling %.1f: blade cap %.1f m/s, fumbled in %d of 6 runs" % [sh, game.human.ctrl.blade_max_speed, fumbles])
	_check(fumbled[0] > fumbled[1], "low stickhandling fumbles more")
	sc.default_skills.stickhandling = 0.5

	# --- deke: lift the blade over the puck, put it down on the far side, pull across
	await _carry(Vector2(-15, 0))
	_plan = func(f, t):
		f.move = Vector2(0.4, 0)
		if t < 0.4:
			f.stick = Vector2(0.7, -0.6)        # forehand side
		elif t < 0.6:
			f.stick = Vector2(0.7, -0.05)       # over the puck, stick up
			f.lift = 1.0
		else:
			f.stick = Vector2(0.6, 0.8)         # down and pull to the backhand
	await _wait(0.4)
	var before_z: float = game.puck.position.z
	await _wait(0.6)
	print("deke: puck z %.2f -> %.2f, still carried %s" % [before_z, game.puck.position.z, game.human.has_puck()])
	_check(game.human.has_puck() and game.puck.position.z < before_z - 0.8, "deke carries the puck across")

	# --- dash
	await _carry(Vector2(-15, 0))
	game.puck.controller = null
	game.puck.position = Vector3(-25, 0, 10)
	_plan = func(f, _t2): f.move = Vector2(1, 0)
	await _wait(0.3)
	var base: float = game.human.vel.x
	_t = 0.0
	_plan = func(f, t):
		f.move = Vector2(1, 0)
		f.dash = t < 0.01
	await _wait(0.2)
	var with_dash: float = game.human.vel.x
	await _carry(Vector2(-15, 0))
	game.puck.controller = null
	game.puck.position = Vector3(-25, 0, 10)
	_plan = func(f, _t2): f.move = Vector2(1, 0)
	await _wait(0.5)
	var without: float = game.human.vel.x
	print("dash: %.1f -> %.1f m/s (no dash %.1f)" % [base, with_dash, without])
	_check(with_dash > without + 1.0, "dash adds speed")

	# --- defensive stick lift on an opponent carrier
	var won := 0
	for trial in 20:
		await _lift_trial()
		if sc.last_event == "lift":
			won += 1
	print("stick lift: %d of 20 stripped the puck" % won)
	_check(won >= 6 and won <= 19, "stick lift works but isn't automatic")

	# --- pass to a teammate ahead
	await _carry(Vector2(-12, 0))
	var mate: Skater = game.teammates(game.human)[0]
	mate.place(Vector2(-4, 0.5), Vector3(-1, 0, 0))
	mate.stun_timer = 0.0
	_plan = func(f, t): f.pass_pressed = t > 0.1 and t < 0.11
	var got := false
	for i in 150:
		await get_tree().physics_frame
		_freeze_others([mate])
		if game.puck.controller == mate:
			got = true
			break
	print("pass reached teammate: %s (%s)" % [got, sc.last_event])
	_check(got, "pass connects")


func _shot_speed(plan: Callable) -> float:
	await _carry(Vector2(-12, 0))
	_plan = plan
	game.stick_control.last_event = ""
	for i in 240:
		await get_tree().physics_frame
		_freeze_others()
		if game.stick_control.last_event != "":
			return game.puck.horizontal_speed()
	return 0.0


## Puts the human at `p` facing +x with the puck on the blade.
func _carry(p: Vector2) -> void:
	_plan = Callable()
	game.state = game.State.PLAY
	game.clock = 300.0
	game.human.place(p, Vector3(1, 0, 0))
	game.stick_control._reset_gesture()
	var puck: Puck = game.puck
	puck.reset_at(game.human.puck_anchor())
	puck.controller = game.human
	for i in 12:
		await get_tree().physics_frame
		_freeze_others()
	_t = 0.0


func _lift_trial() -> void:
	await _carry(Vector2(-15, 0))
	var opp: Skater = game.team_skaters(1)[0]
	opp.place(Vector2(-13.6, 0.4), Vector3(-1, 0, 0))
	opp.stun_timer = 0.0
	game.puck.controller = opp
	game.puck.position = opp.puck_anchor()
	game.stick_control._lift_cd = 0.0
	game.stick_control.last_event = ""
	_t = 0.0
	_plan = func(f, t): f.lift = 1.0 if t > 0.05 else 0.0
	for i in 12:
		await get_tree().physics_frame
		_freeze_others([opp])
		if game.stick_control.last_event != "":
			break


## Everyone but the human (and `keep`) stands still and can't play the puck.
func _freeze_others(keep: Array = []) -> void:
	game.state = game.State.PLAY
	for s in game.skaters:
		if s != game.human and not s in keep:
			s.stun_timer = 1.0
			s.position = Vector3(25 + s.number, 0, -10 - s.team * 5)
			s.vel = Vector3.ZERO


func _wait(seconds: float) -> void:
	var frames := int(seconds * 120.0)
	for i in frames:
		await get_tree().physics_frame
		_freeze_others()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("  FAIL: ", what)
