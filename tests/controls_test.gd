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
	# --- pull back, then push forward: wind-up shot
	var wrist := await _shot(func(f, t): f.stick = Vector2(-1, 0) if t < 0.6 else Vector2(1, 0))
	_check(wrist > 0.0, "pull back + push forward shoots")

	# --- lift held through the wind-up: slapshot, harder
	var slap := await _shot(func(f, t):
		f.stick = Vector2(-1, 0) if t < 0.9 else Vector2(1, 0)
		f.lift = 1.0 if t < 0.9 else 0.0)
	print("wind-up shot %.1f m/s, slapshot %.1f m/s" % [wrist, slap])
	_check(slap > wrist, "slapshot is harder than the wind-up shot")

	# --- tilt lofts the shot
	await _shot(func(f, t):
		f.stick = Vector2(-1, 0) if t < 0.6 else Vector2(1, 0)
		f.tilt = 1.0, Vector2(15, 0))
	print("tilted shot vy %.2f" % game.puck.vel.y)
	_check(game.puck.vel.y > 1.0, "tilt lifts the shot")

	# --- the stick stays inside the 90 degree arc
	await _carry(Vector2(-10, 0))
	_set_plan(func(f, _t2): f.stick = Vector2(0, -1))  # screen down = the skater's right
	await _wait(0.5)
	var bl: Vector2 = game.human.blade_local
	var ang := rad_to_deg(atan2(bl.y, bl.x))
	print("stick pushed 90 deg right sits at %.0f deg" % ang)
	_check(ang > 30.0 and ang <= 46.0, "blade follows the stick, limited to the arc")

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
	_check(lifts > 0, "lift near a carrier's stick lifts it")

	# --- pass to a teammate ahead
	await _carry(Vector2(-12, 0))
	var mate: Skater = game.teammates(game.human)[0]
	mate.place(Vector2(-4, 0.5), Vector3(-1, 0, 0))
	mate.stun_timer = 0.0
	_set_plan(func(f, t): f.pass_pressed = t > 0.1 and t < 0.11)
	# whether it gets trapped is the receiver's skill (physics); here: it was sent to them
	var got := await _until(func(): return game.puck.pass_target == mate, 0.5, [mate])
	print("pass sent to teammate: %s" % got)
	_check(got, "pass button passes to the teammate")

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
