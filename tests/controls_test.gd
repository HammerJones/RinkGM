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
	# the scripted stick is in screen space for the side-on view: right is +x
	game.camera_rig.set_mode(CameraRig.Mode.BROADCAST)
	# the stick-motion shots and moves below are the gamepad scheme; the
	# keyboard + mouse traced shots have their own section
	game.controller.pad_scheme = true
	game.controller.player_input.scripted = func(f, dt):
		_t += dt
		if _plan.is_valid():
			_plan.call(f, _t)
	var reach := "body reach (m) by angle:"
	for d in range(-180, 181, 30):
		reach += "  %d %.2f" % [d, Skater.reach_limit(deg_to_rad(d))]
	print(reach)
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
	await _job_input()
	await _backwards_and_look()
	await _traced_shots()

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

	# --- hockey stop (and the marks strides and stops leave on the ice)
	var heard := {"stride": 0, "stop": 0}
	var on_stride := func(_a, _b, _c): heard.stride += 1
	var on_stop := func(_a, _b): heard.stop += 1
	game.human.stride.connect(on_stride)
	game.human.stop_spray.connect(on_stop)
	var gouge0: float = game.ice.mean_gouge_mm()
	var snow0: float = game.ice.snow
	await _carry(Vector2(-15, 0), false)
	_set_plan(func(f, _t2): f.move = Vector2(1, 0))
	await _wait(1.0)
	var cruising: float = game.human.vel.length()
	_set_plan(func(f, _t2): f.stop = true)
	await _wait(0.6)
	print("stop: %.1f -> %.1f m/s" % [cruising, game.human.vel.length()])
	game.human.stride.disconnect(on_stride)
	game.human.stop_spray.disconnect(on_stop)
	game.ice.flush()
	print("ice marks: %d strides, %d stop sprays, gouge %.4f -> %.4f mm, snow %.4f -> %.4f" % [heard.stride, heard.stop, gouge0, game.ice.mean_gouge_mm(), snow0, game.ice.snow])
	_check(heard.stride >= 1 and heard.stop >= 1, "strides and stops send their events")
	_check(game.ice.mean_gouge_mm() > gouge0 and game.ice.snow > snow0, "strides and stops cut the ice and throw snow")
	_check(game.human.vel.length() < cruising * 0.5, "hockey stop sheds speed")

	# --- defensive stick lift on an opponent carrier
	var lifts := 0
	for trial in 20:
		var before: int = game.stats.stick_lifts
		await _lift_trial(trial / 19.0)
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
	# whether it gets trapped is the receiver's skill (physics); here: it was sent to them.
	# The receiver waits where it was put (its AI would skate off to get open).
	var spot := mate.position
	var waiting := func() -> void:
		mate.position = spot
		mate.vel = Vector3.ZERO
	var got := await _until(func(): waiting.call(); return game.puck.pass_target == mate, 0.5, [mate])
	print("pass sent to teammate: %s" % got)
	_check(got, "pass button passes to the teammate")
	# the controls' part is getting it to him: it connects when it reaches
	# his blade (whether he traps it cleanly is his hands, physics' to test)
	var closest := {"m": INF}  # (a lambda can't assign an outer local)
	got = await _until(func():
		waiting.call()
		closest.m = minf(closest.m, Vector2(game.puck.position.x - mate.blade_pos.x, game.puck.position.z - mate.blade_pos.z).length())
		return game.puck.controller == mate or closest.m < 0.5, 1.5, [mate])
	print("teammate caught it: %s (closest %.2f m, controlled %s)" % [got, closest.m, game.puck.controller == mate])
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
	print("lacrosse: puck rode up to %.2f m, %s" % [peak[0], seen])
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


## The lift is a strength contest with leverage: getting under their shaft
## near the blade (`along` 1) beats them, near their hands (0) doesn't. Each
## trial gets under a different point of the carrier's stick.
func _lift_trial(along: float) -> void:
	await _carry(Vector2(-15, 0), false)
	var opp: Skater = game.team_skaters(1)[0]
	var at := lerpf(0.1, 0.9, along)
	opp.place(Vector2(-13.8 + at * Skater.DEFAULT_BLADE.length(), 0.35 + at * Skater.DEFAULT_BLADE.y), Vector3(-1, 0, 0))
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


## Keyboard + mouse: RMB traces a shot pattern (ShotPatterns) and fires on
## release; side-to-side stickhandling has a rhythm limit.
func _traced_shots() -> void:
	var h: Skater = game.human
	var ctl: HumanController = game.controller
	ctl.pad_scheme = false
	for kind in [&"wrist_shot", &"snap_shot", &"slapshot", &"toe_drag_shot"]:
		await _carry(Vector2(-12, 0))
		var tr := _pattern(kind, 0.25)
		var dot: Variant = ctl.aim_from_view()
		_plan = func(f, t):
			f.tracing = t < 0.3
			f.trace_done = t >= 0.3 and t < 0.305
			if f.trace_done:
				f.trace = tr
		var shot := await _until(func(): return not ctl.last_shot.is_empty() and ctl.last_shot.get("fired", false), 0.6)
		_check(shot and ctl.last_shot.kind == kind, "a traced %s fires as one (%s)" % [kind, ctl.last_shot.get("kind", "-")])
		# it goes where the centre dot points, not automatically at the net
		var want: Vector3 = ctl.last_shot.get("target", Vector3.ZERO)
		var v2 := Vector2(game.puck.vel.x, game.puck.vel.z)
		var to := Vector2(want.x - h.position.x, want.z - h.position.z).normalized()
		_check(dot is Vector3 and want.distance_to(dot) < 2.0 and v2.length() > 12.0 and v2.normalized().dot(to) > 0.75,
				"and goes at the centre dot (%.1f m/s, %.2f on line)" % [v2.length(), v2.normalized().dot(to)])
		ctl.last_shot = {}
	# a slow, sloppy wrist shot is weaker and spreads wider than a quick clean one
	await _carry(Vector2(-12, 0))
	var clean := ctl.grade(h, _pattern(&"wrist_shot", 0.2), ctl.net_target(h))
	var sloppy := ctl.grade(h, _pattern(&"wrist_shot", 1.2, 30.0), ctl.net_target(h))
	_check(clean.puck_speed > sloppy.puck_speed + 4.0, "a quick stroke shoots harder (%.1f vs %.1f m/s)" % [clean.puck_speed, sloppy.puck_speed])
	_check(clean.radius < sloppy.radius * 0.6, "a clean pattern lands tighter (%.2f vs %.2f m)" % [clean.radius, sloppy.radius])
	# stickhandling: wide easy sweeps keep it, frantic ones lose it
	var sweep := func(hz: float, amp: float) -> Array:
		await _carry(Vector2(-14, 0))
		_plan = func(f, t):
			f.move = Vector2(0.4, 0)
			f.stick = Vector2(amp * sin(t * TAU * hz), 0.5)  # mouse: x across the body, y ahead
		var peak := 0.0
		var lost := false
		var lo := INF
		var hi := -INF
		for i in 480:
			await get_tree().physics_frame
			_freeze_others()
			lost = lost or game.puck.controller != h
			if i > 60 and not lost:
				peak = maxf(peak, h.handle_load)
				var side: float = (game.puck.position - h.position).dot(h.right_vec())
				lo = minf(lo, side)
				hi = maxf(hi, side)
		return [peak, lost, hi - lo]
	# turning the body with the stick held still moves no hands: the puck stays
	await _carry(Vector2(-14, 0))
	_plan = func(f, t):
		f.move = Vector2(cos(t * 2.5), sin(t * 2.5))
		f.stick = Vector2(0.0, 0.5)
	var turn_peak := 0.0
	var turn_lost := false
	for i in 360:
		await get_tree().physics_frame
		_freeze_others()
		turn_lost = turn_lost or game.puck.controller != h
		turn_peak = maxf(turn_peak, h.handle_load)
	_check(not turn_lost and turn_peak < 0.5, "turning with the puck keeps it and the meter low (%.2f)" % turn_peak)
	# skating feel: turns redirect speed but never add it; pulling back brakes
	await _carry(Vector2(-14, 0), false)
	_set_plan(func(f, t): f.move = Vector2(1, 0) if t < 2.0 else Vector2(cos((t - 2.0) * 3.0), sin((t - 2.0) * 3.0)))
	await _until(func(): return _t >= 2.0, 2.5)
	var cruise := h.speed()
	var turn_top := 0.0
	await _until(func():
		turn_top = maxf(turn_top, h.speed())
		return false, 1.5)
	_check(turn_top <= cruise + 0.05, "a turn never adds speed (%.2f vs %.2f m/s)" % [turn_top, cruise])
	await _carry(Vector2(-14, 0), false)
	_set_plan(func(f, t): f.move = Vector2(1, 0) if t < 2.0 else Vector2(-1, 0))
	await _until(func(): return _t >= 2.0, 2.5)
	var fast := h.speed()
	await _until(func(): return false, 0.6)
	_check(h.speed() < fast * 0.4 and h.vel.x > -0.3, "pulling back brakes rather than turning round (%.2f -> %.2f m/s)" % [fast, h.speed()])
	var easy: Array = await sweep.call(0.7, 0.6)
	_check(easy[0] < 1.0 and not easy[1], "slow wide handles stay in the green and keep the puck (%.2f)" % easy[0])
	_check(easy[2] > 1.0, "the handles carry the puck side to side across the body (%.2f m)" % easy[2])
	# the meter counts changes of direction, not stick speed: a quick hard
	# swing that changes direction rarely stays green
	var swing: Array = await sweep.call(0.6, 1.0)
	_check(swing[0] < 0.6 and not swing[1], "fast swings with few changes of direction stay green (%.2f)" % swing[0])
	var frantic: Array = await sweep.call(4.0, 0.6)
	_check(frantic[1], "frantic handles run past the limit and lose the puck (%.2f)" % frantic[0])
	_plan = Callable()
	ctl.pad_scheme = true


## A pattern as mouse motion: Vector3(x px, y px up, t s), drawn in `seconds`.
func _pattern(kind: StringName, seconds: float, wobble := 0.0) -> Array:
	var pts := ShotPatterns.outline(kind)
	var out := []
	var n := 40
	for i in n + 1:
		var u := float(i) / n * (pts.size() - 1)
		var k := mini(int(u), pts.size() - 2)
		var q := pts[k].lerp(pts[k + 1], u - k)
		if i > 0 and i < n:
			q += Vector2(wobble * sin(i * 2.3), wobble * cos(i * 1.7))
		out.append(Vector3(q.x, q.y, seconds * i / n))
	return out


## Turn around (F / X) and skate backwards; free look (LMB / LB) turns the
## view but not the controls.
func _backwards_and_look() -> void:
	var h: Skater = game.human
	# skate forwards to speed, then turn around
	await _carry(Vector2(-25, 0), false)
	_plan = func(f, t): f.move = Vector2(1, 0)
	await _wait(3.0)
	var fwd_speed := h.vel.length()
	_plan = func(f, t):
		f.move = Vector2(1, 0)
		f.turn_pressed = t > 3.0 and t < 3.01
	await _wait(0.5)
	_check(h.backwards and h.heading.dot(Vector3(-1, 0, 0)) > 0.9, "turning around faces the other way (%s)" % h.heading)
	# still skating the same way, now backwards
	await _wait(3.0)
	_check(h.vel.x > 2.0 and h.heading.x < -0.9, "skating backwards keeps going where the stick points (%.1f m/s)" % h.vel.x)
	_check(h.vel.length() < fwd_speed * 0.85, "backwards is slower than forwards (%.1f vs %.1f)" % [h.vel.length(), fwd_speed])
	_plan = func(f, t): f.turn_pressed = t > 0.0 and t < 0.01
	_t = 0.0
	await _wait(0.5)
	_check(not h.backwards and h.heading.x > 0.9, "turning around again faces forwards")
	# free look: the view turns, the controls don't
	var rig: CameraRig = game.camera_rig
	var before := rig.forward_flat()
	var cam_before := -rig.cam.global_basis.z
	_plan = func(f, t):
		f.looking = true
		f.look = Vector2(0.02, 0.0)
	await _wait(0.5)
	var cam_now := -rig.cam.global_basis.z
	_check(cam_now.angle_to(cam_before) > 0.5, "holding free look turns the view")
	_check(rig.forward_flat().angle_to(before) < 0.05, "and leaves the controls where they were")
	_plan = Callable()
	await _wait(1.5)
	_check(rig.look.length() < 0.05, "letting go eases the view back")


## The rink job input (JobInput): the real bindings, not the scripted hook.
func _job_input() -> void:
	var ji := JobInput.new()
	add_child(ji)
	var dt := 1.0 / 120.0
	var tree := get_tree()
	var wheel := func(down: bool):
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
		e.pressed = true
		Input.parse_input_event(e)
	# grab held on a bench: two wheel notches down tighten 1/6 turn
	Input.action_press("job_grab")
	ji.poll(dt, JobInput.Context.BENCH)
	wheel.call(true)
	wheel.call(true)
	await tree.physics_frame
	var f := ji.poll(dt, JobInput.Context.BENCH)
	_check(absf(f.turn - 2.0 * JobInput.TURN_STEP) < 0.0001, "wheel down while grabbing tightens a step a notch (%.3f)" % f.turn)
	# circling the right stick clockwise once tightens one turn
	var total := 0.0
	for i in 121:
		var a := -TAU * i / 120.0   # clockwise on screen
		_press_vector(Vector2(cos(a), sin(a)), "stick_left", "stick_right", "stick_down", "stick_up")
		total += ji.poll(dt, JobInput.Context.BENCH).turn
	_check(absf(total - 1.0) < 0.02, "circling the right stick clockwise turns one turn (%.3f)" % total)
	# without the grab the stick looks instead
	Input.action_release("job_grab")
	_press_vector(Vector2(1, 0), "stick_left", "stick_right", "stick_down", "stick_up")
	f = ji.poll(dt, JobInput.Context.BENCH)
	_check(f.turn == 0.0 and f.look.x > 0.0 and f.grab_released, "letting go of the grab turns the stick back into look")
	_press_vector(Vector2.ZERO, "stick_left", "stick_right", "stick_down", "stick_up")
	# Doris: brake and the levers, as real events so a lever is "just pressed"
	var act := func(action: String, down: bool):
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		e.strength = 1.0 if down else 0.0
		Input.parse_input_event(e)
	act.call("drive_blade", true)
	act.call("drive_brake", true)
	await tree.physics_frame
	f = ji.poll(dt, JobInput.Context.DRIVE)
	_check(f.brake > 0.9 and f.blade_lever_pressed and not f.water_lever_pressed, "driving reads the brake and blade lever (%s %s)" % [f.brake, f.blade_lever_pressed])
	await tree.physics_frame
	f = ji.poll(dt, JobInput.Context.DRIVE)
	_check(f.brake > 0.9 and not f.blade_lever_pressed, "a lever press is one pull, not held")
	act.call("drive_brake", false)
	act.call("drive_blade", false)
	await tree.physics_frame
	ji.queue_free()


func _press_vector(v: Vector2, left: String, right: String, down: String, up: String) -> void:
	for pair in [[left, -v.x], [right, v.x], [down, -v.y], [up, v.y]]:
		if pair[1] > 0.0:
			Input.action_press(pair[0], pair[1])
		else:
			Input.action_release(pair[0])


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
