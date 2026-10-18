extends Node
## Headless checks that the human control scheme reaches the simulation:
## drives the human through PlayerInput.scripted (screen-space stick, as a
## pad or the mouse's virtual stick would give it) and checks what happens.
## Run: godot --headless --path . --fixed-fps 120 -- --test=controls

var game: Node
var _plan := Callable()
var _t := 0.0
var _fails := 0


func _ready() -> void:
	seed(12345)
	await get_tree().physics_frame
	# ratings are rolled per run; pin them so every run plays the same. Good
	# passers, so "the pass connects" checks the controls, not a missed pass.
	for sk in game.skaters:
		for key in Skills.SKATER_KEYS:
			sk.skills.values[key] = 55.0
		sk.skills.values["pass_quality"] = 85.0
		sk.set_skills(sk.skills)   # the physics profile is built from them at setup
	game.controller.player_input.scripted = func(f, dt):
		_t += dt
		if _plan.is_valid():
			_plan.call(f, _t)
	await _run()
	print("controls test: ", "FAILED %d" % _fails if _fails else "all passed")
	get_tree().quit(1 if _fails else 0)


# The human faces +x; on the broadcast camera screen right is +x, so a
# screen stick of (1, 0) is "forward" and (-1, 0) is "behind".

func _run() -> void:
	# --- flick forward from neutral: instant quick shot
	var quick := await _shot(func(f, t): f.stick = Vector2(1, 0) if t > 0.2 else Vector2.ZERO)
	_check(quick > 0.0, "flicking the stick forward shoots")

	# --- pull back, then push forward: wind-up shot
	var wrist := await _shot(func(f, t): f.stick = Vector2(-1, 0) if t < 0.6 else Vector2(1, 0))
	_check(wrist > 0.0, "pull back + push forward shoots")

	# --- lift held through the wind-up: slapshot, harder
	var slap := await _shot(func(f, t):
		f.stick = Vector2(-1, 0) if t < 0.9 else Vector2(1, 0)
		f.lift = 1.0 if t < 0.9 else 0.0)
	print("quick shot %.1f m/s, wind-up shot %.1f m/s, slapshot %.1f m/s" % [quick, wrist, slap])
	_check(slap > wrist, "slapshot is harder than the wind-up shot")

	# --- tilt lofts the shot
	await _shot(func(f, t):
		f.stick = Vector2(-1, 0) if t < 0.6 else Vector2(1, 0)
		f.tilt = 1.0, Vector2(15, 0))
	print("tilted shot vy %.2f" % game.puck.vel.y)
	_check(game.puck.vel.y > 1.0, "tilt lifts the shot")

	# --- the stick reaches round a 220 degree arc, not all the way behind
	await _carry(Vector2(-10, 0))
	_set_plan(func(f, _t2): f.stick = Vector2(0, -1))  # screen down = the skater's right
	await _wait(0.5)
	var bl: Vector2 = game.human.blade_local
	var ang := rad_to_deg(atan2(bl.y, bl.x))
	print("stick pushed 90 deg right sits at %.0f deg" % ang)
	_check(ang > 75.0 and ang <= 110.0, "blade follows the stick round the side")
	_set_plan(func(f, _t2): f.stick = Vector2(-0.5, -0.87))  # 120 deg back on the forehand
	await _wait(0.5)
	bl = game.human.blade_local
	ang = rad_to_deg(atan2(bl.y, bl.x))
	print("stick pulled 120 deg back sits at %.0f deg" % ang)
	_check(ang > 95.0 and ang <= 111.0, "the arc stops at 110 degrees each side")

	# --- learned shots and moves
	await _moves()
	await _stickhandling()

	# --- lift with the puck raises the blade
	await _carry(Vector2(-10, 0))
	_set_plan(func(f, _t2): f.lift = 1.0)
	await _wait(0.3)
	_check(game.human.lifting and game.human.blade_height > 0.1, "lift raises the blade")

	# --- dash
	await _carry(Vector2(-15, 0), false)
	_set_plan(func(f, _t2): f.move = Vector2(1, 0))
	await _wait(0.3)
	_set_plan(func(f, t):
		f.move = Vector2(1, 0)
		f.dash = t < 0.01)
	await _wait(0.25)
	var with_dash: float = game.human.vel.x
	await _carry(Vector2(-15, 0), false)
	_set_plan(func(f, _t2): f.move = Vector2(1, 0))
	await _wait(0.55)
	var without: float = game.human.vel.x
	print("speed after dash %.1f m/s, without %.1f m/s" % [with_dash, without])
	_check(with_dash > without + 0.5, "dash adds speed")

	# --- hockey stop
	await _carry(Vector2(-15, 0), false)
	_set_plan(func(f, _t2): f.move = Vector2(1, 0))
	await _wait(1.0)
	var cruising: float = game.human.vel.length()
	_set_plan(func(f, _t2): f.stop = true)
	await _wait(0.6)
	print("stop: %.1f -> %.1f m/s" % [cruising, game.human.vel.length()])
	_check(game.human.vel.length() < cruising * 0.5, "hockey stop sheds speed")

	# --- defensive stick lift on an opponent carrier
	var lifts := 0
	for trial in 20:
		var before: int = game.stats.stick_lifts
		await _lift_trial()
		if game.stats.stick_lifts > before:
			lifts += 1
	print("stick lift: %d of 20 lifted the carrier's stick" % lifts)
	_check(lifts >= 4 and lifts <= 18, "lift near a carrier's stick often lifts it, but not always")

	# --- pass to a teammate ahead
	await _carry(Vector2(-12, 0))
	var mate: Skater = game.teammates(game.human)[0]
	mate.place(Vector2(-4, 0.0), Vector3(-1, 0, 0))
	mate.stun_timer = 0.0
	_set_plan(func(f, t): f.pass_pressed = t > 0.1 and t < 0.11)
	# whether it gets trapped is the receiver's skill (physics); here: it was sent to them
	var got := await _until(func(): return game.puck.pass_target == mate, 0.5, [mate])
	print("pass sent to teammate: %s" % got)
	_check(got, "pass button passes to the teammate")
	got = await _until(func(): return game.puck.controller == mate, 1.5, [mate])
	print("teammate caught it: %s" % got)
	_check(got, "the pass connects")

	# --- without the puck, the pass button calls for it
	await _carry(Vector2(-4, 0), false)
	mate.place(Vector2(-12, 0.5), Vector3(1, 0, 0))
	mate.stun_timer = 0.0
	game.puck.reset_at(mate.puck_anchor())
	game.puck.controller = mate
	_set_plan(func(f, t): f.pass_pressed = t > 0.05 and t < 0.06)
	got = await _until(func(): return game.puck.pass_target == game.human, 2.0, [mate])
	print("called for the puck, carrier passed to you: %s" % got)
	_check(got, "calling for a pass makes the carrier pass to you")


func _moves() -> void:
	var h: Skater = game.human
	# good hands: physics runs move paths under the skater's own limits, and a
	# weak stickhandler is allowed to lose the puck on them
	h.skills.values["stick_handling"] = 80.0
	h.set_skills(h.skills)
	# screen space: +x is forward, -y is the forehand (right), +y the backhand
	var side := func(deg: float, r := 1.0) -> Vector2: return Vector2(cos(deg_to_rad(deg)), -sin(deg_to_rad(deg))) * r

	# snapshot: out wide on the forehand, snapped forward
	var seen := await _move_run(func(f, t): f.stick = side.call(50.0, 0.85) if t < 0.4 else Vector2(1, 0))
	_check(seen[0] == &"snap_shot" and seen[1], "wide forehand snapped forward is a snapshot")

	# backhand snap: the same on the backhand side
	seen = await _move_run(func(f, t): f.stick = side.call(-50.0, 0.85) if t < 0.4 else Vector2(1, 0))
	_check(seen[0] == &"backhand_shot" and seen[1], "wide backhand snapped forward is a backhand snap")

	# toe drag: tilt held, stick out front (eased there: snapping it would be a
	# quick shot), then pulled back across to the backhand
	var drag := func(f, t):
		f.tilt = 1.0
		# then eases back in to the backhand side once the move has it
		if t < 0.4:
			f.stick = Vector2(minf(t / 0.25, 1.0) * 0.5, 0)
		elif t < 0.45:
			f.stick = side.call(-80.0, 0.8)
		else:
			f.stick = side.call(-30.0, 0.6)
	seen = await _move_run(drag)
	_check(seen[0] == &"toe_drag" and not seen[1] and h.has_puck(), "toe drag pulls the puck across and keeps it")

	# toe drag shot: the same with lift held too
	seen = await _move_run(func(f, t):
		drag.call(f, t)
		f.lift = t > 0.3)
	_check(seen[0] == &"toe_drag_shot" and seen[1], "lift + tilt toe drag ends in a shot")

	# quick deke: forehand, backhand, forehand in one quick motion
	seen = await _move_run(func(f, t):
		var a: float = 50.0 if t < 0.4 or t > 0.6 else -50.0
		f.stick = side.call(a, 0.8) if t > 0.1 else Vector2.ZERO)
	_check(seen[0] == &"quick_deke" and h.has_puck(), "forehand-backhand-forehand whip is a quick deke")

	# lacrosse: tilt held, swept from the backhand round to the forehand, the
	# puck rides up on the blade; push forward (tilt still held) to throw it
	var peak := [0.0]
	seen = await _move_run(func(f, t):
		peak[0] = maxf(peak[0], game.puck.position.y)
		f.tilt = 1.0
		var a: float = lerpf(-60.0, 120.0, clampf((t - 0.4) / 0.4, 0.0, 1.0))
		f.stick = side.call(a, minf(t / 0.3, 0.85)) if t < 1.3 else Vector2(1, 0))
	print("lacrosse: puck rode up to %.2f m" % peak[0])
	_check(seen[0] == &"lacrosse" and seen[1] and peak[0] > 0.6, "lacrosse lifts the puck onto the blade and throws it")
	h.skills.values["stick_handling"] = 55.0


## Carries the puck, runs a stick plan for 1.5 s and returns
## [the first move the skater performed, whether a shot was taken].
func _move_run(plan: Callable) -> Array:
	await _carry(Vector2(-10, 0))
	var shots: int = game.stats.shots
	var first := [&""]
	_set_plan(plan)
	await _until(func():
		if first[0] == &"" and game.human.move_id != &"":
			first[0] = game.human.move_id
		if OS.has_environment("TRACE_MOVES") and game.human.move_id != &"":
			print("  t %.2f ang %.0f reach %.2f h %.2f puck %s" % [_t, rad_to_deg(game.human.blade_ang), game.human.blade_reach, game.human.blade_height, game.human.has_puck()])
		return false, 1.5)
	var shot: bool = game.stats.shots > shots
	print("move: %s, shot %s, puck kept %s" % [first[0], shot, game.human.has_puck()])
	return [first[0], shot]


## Runs a shot plan with the puck on the blade; returns the puck's speed
## when it leaves the stick, or 0 if no shot was taken.
func _shot(plan: Callable, at := Vector2(-12, 0)) -> float:
	await _carry(at)
	var shots: int = game.stats.shots
	_set_plan(plan)
	for i in 300:
		await get_tree().physics_frame
		_freeze_others()
		if game.stats.shots > shots:
			return game.puck.horizontal_speed()
	return 0.0


## Puts the human at `p` facing +x, with the puck on the blade or out of play.
func _carry(p: Vector2, with_puck := true) -> void:
	_plan = Callable()
	game.state = game.State.PLAY
	game.clock = 300.0
	game.human.place(p, Vector3(1, 0, 0))
	var puck: Puck = game.puck
	if with_puck:
		puck.reset_at(game.human.puck_anchor())
		puck.controller = game.human
	else:
		puck.reset_at(Vector3(25, 0, 12))
	for i in 12:
		await get_tree().physics_frame
		_freeze_others()
	_t = 0.0


func _lift_trial() -> void:
	await _carry(Vector2(-15, 0), false)
	var opp: Skater = game.team_skaters(1)[0]
	opp.place(Vector2(-13.6, 0.4), Vector3(-1, 0, 0))
	opp.stun_timer = 0.0
	game.puck.reset_at(opp.puck_anchor())
	game.puck.controller = opp
	game.human.lift_cd = 0.0
	_set_plan(func(f, t): f.lift = 1.0 if t > 0.05 else 0.0)
	await _until(func(): return false, 0.15, [opp])


func _set_plan(plan: Callable) -> void:
	_plan = plan
	_t = 0.0


func _until(cond: Callable, seconds: float, keep: Array = []) -> bool:
	for i in int(seconds * 120.0):
		await get_tree().physics_frame
		_freeze_others(keep)
		if cond.call():
			return true
	return false


## Everyone but the human (and `keep`) stands still out of the way.
func _freeze_others(keep: Array = []) -> void:
	game.state = game.State.PLAY
	for s in game.skaters:
		if s != game.human and not s in keep:
			s.stun_timer = 1.0
			s.position = Vector3(25 + s.number, 0, -10 - s.team * 5)
			s.vel = Vector3.ZERO


func _wait(seconds: float) -> void:
	await _until(func(): return false, seconds)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("  FAIL: ", what)


## Stickhandling the puck from side to side must not shoot: sweeps across the
## front on the rim, through the middle, wide to both sides, at a range of
## speeds a player would use. Each runs for 3 s with the puck.
func _stickhandling() -> void:
	var rim := func(amp: float, hz: float) -> Callable:
		return func(f, t):
			var a := deg_to_rad(amp) * sin(TAU * hz * t)
			# eased out from neutral so the start isn't a flick
			f.stick = Vector2(cos(a), -sin(a)) * minf(t / 0.3, 1.0)
	var through := func(hz: float) -> Callable:
		return func(f, t): f.stick = Vector2(0.15, -sin(TAU * hz * t))
	var snap := func(hz: float) -> Callable:
		return func(f, t): f.stick = Vector2(0.45, -0.89 if fmod(t * hz, 1.0) < 0.5 else 0.89)
	var plans := {
		"rim +-60 2Hz": rim.call(60.0, 2.0), "rim +-80 2.5Hz": rim.call(80.0, 2.5),
		"rim +-90 3Hz": rim.call(90.0, 3.0), "rim +-100 1.5Hz": rim.call(100.0, 1.5),
		"rim +-110 2Hz": rim.call(110.0, 2.0), "rim +-60 0.8Hz": rim.call(60.0, 0.8),
		"rim +-100 0.8Hz": rim.call(100.0, 0.8),
		"through 2Hz": through.call(2.0), "through 4Hz": through.call(4.0),
		"snap 3Hz": snap.call(3.0), "snap 5Hz": snap.call(5.0),
	}
	var total := 0
	for name in plans:
		await _carry(Vector2(-10, 0))
		var shots: int = game.stats.shots
		_set_plan(plans[name])
		await _wait(3.0)
		var n: int = game.stats.shots - shots
		total += n
		print("stickhandling %s: %d shots, puck kept %s" % [name, n, game.human.has_puck()])
	_check(total == 0, "stickhandling side to side doesn't shoot")

	# while a short, deliberate draw behind the hip still shoots
	var quick_draw := await _shot(func(f, t):
		var a := deg_to_rad(135.0)
		f.stick = Vector2(cos(a), -sin(a)) if t < 0.18 else Vector2(1, 0))
	print("short draw-back shot: %.1f m/s" % quick_draw)
	_check(quick_draw > 0.0, "a quick draw back past the hip, then forward, shoots")
