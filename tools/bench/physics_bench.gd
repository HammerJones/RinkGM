extends Node
## Headless physics bench: drives skaters with scripted controls on empty ice
## and prints what each rating actually produces (speeds, stops, turns, puck
## retention, shots, passes, hits) as Markdown tables.
##
##   godot --headless --path . res://tools/bench/bench.tscn [-- --out=bench.md]
##
## It stands in for Game (the methods Skater and StickPuck call), so the
## numbers come from exactly the code the game runs.

const DT := 1.0 / 120.0
const SUBSTEPS := 4
const RATINGS := [1, 25, 50, 75, 100]
const CUT := 85.0

var puck: Puck
var skaters: Array[Skater] = []
var stats := {"checks": 0}
var _out := PackedStringArray()
var _possessions := 0


# ---------------------------------------------------------------- Game stand-in

func is_frozen() -> bool:
	return false


func attack_side(team: int) -> int:
	return 1 if team == 0 else -1


func teammates(s: Skater) -> Array:
	return skaters.filter(func(x): return x.team == s.team and x != s)


func on_possession(_s: Skater) -> void:
	_possessions += 1


var _last_shot := ""


func on_shot(_s: Skater, slap: bool) -> void:
	_last_shot = "%s %.0f mph" % ["slapshot" if slap else "wrist shot", puck.horizontal_speed() / PhysicsProfile.MPH]


func on_stick_lift(_by: Skater, _victim: Skater) -> void:
	pass


# ---------------------------------------------------------------- harness

func _ready() -> void:
	seed(12345)
	puck = Puck.new()
	add_child(puck)
	Tuning.set_mode("HYBRID")
	_line("# RinkGM physics bench")
	_line("")
	_line("Mode HYBRID unless noted. Ratings not named in a table are 50. 1 m/s = 2.24 mph.")
	_bench_gestures()
	_bench_skating()
	_bench_stop()
	_bench_turn()
	_bench_carry()
	_bench_stickhandle()
	_bench_shots()
	_bench_passes()
	_bench_hits()
	var text := "\n".join(_out)
	print(text)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			var f := FileAccess.open(arg.trim_prefix("--out="), FileAccess.WRITE)
			f.store_string(text + "\n")
	get_tree().quit()


func _line(s: String) -> void:
	_out.append(s)


func _stats(over: Dictionary) -> Skills:
	var st := Skills.new()
	for k in Skills.SKATER_KEYS:
		st.values[k] = float(over.get(k, 50))
	return st


func _skater(st: Skills, team := 0) -> Skater:
	var s := Skater.new()
	add_child(s)
	s.setup(self, team, skaters.size(), {}, st)
	skaters.append(s)
	s.place(Vector2.ZERO, Vector3(1, 0, 0))
	return s


func _clear() -> void:
	for s in skaters:
		s.queue_free()
		remove_child(s)
	skaters.clear()
	puck.reset_at(Vector3(0, 0, 0))
	puck.position = Vector3(100, 0, 100)


func _step() -> void:
	for s in skaters:
		s.physics_update(DT)
	var sdt := DT / SUBSTEPS
	for i in SUBSTEPS:
		StickPuck.step(self, puck, sdt)
		puck.integrate(sdt)


## Keeps a straight-line test away from the boards by sliding everything back.
func _recentre(s: Skater) -> void:
	if absf(s.position.x) > 18.0 or absf(s.position.z) > 8.0:
		var shift := Vector3(s.position.x, 0, s.position.z)
		s.position -= shift
		s.blade_pos -= shift
		if puck.controller == s:
			puck.position -= shift


func _give_puck(s: Skater) -> void:
	puck.reset_at(s.puck_anchor())
	puck.vel = s.vel
	puck.controller = s


func _mph(v: float) -> String:
	return "%.1f mph" % (v / PhysicsProfile.MPH)


# ---------------------------------------------------------------- gestures

## Feeds a right-stick sequence [[stick, lift, frames], ...] to a puck carrier
## and returns what shot (if any) came off.
func _gesture(seq: Array) -> String:
	_clear()
	var s := _skater(_stats({}))
	_give_puck(s)
	_last_shot = "none"
	for k in 20:
		_step()
	for part in seq:
		for f in part[2]:
			s.ctrl.reset()
			s.ctrl.stick = part[0]
			s.ctrl.lift = part[1]
			_step()
	return _last_shot


func _bench_gestures() -> void:
	_line("")
	_line("## Right-stick gestures (skater facing +x, all ratings 50)")
	_line("")
	_line("| gesture | result |")
	_line("|---|---|")
	var fwd := Vector2(1, 0)
	var back := Vector2(-1, 0)
	var side := Vector2(0.7, 0.7)
	_line("| flick forward from neutral | %s |" % _gesture([[Vector2.ZERO, false, 10], [fwd, false, 3]]))
	_line("| slow push forward (stickhandling) | %s |" % _gesture([[Vector2.ZERO, false, 10], [fwd * 0.5, false, 15], [fwd, false, 15]]))
	_line("| sweep side to side | %s |" % _gesture([[side, false, 30], [Vector2(0.7, -0.7), false, 30], [side, false, 30]]))
	_line("| pull back 0.1 s, push forward | %s |" % _gesture([[back, false, 12], [fwd, false, 5]]))
	_line("| pull back 1 s, push forward | %s |" % _gesture([[back, false, 120], [fwd, false, 5]]))
	_line("| hold lift, pull back 1 s, push forward | %s |" % _gesture([[back, true, 120], [fwd, false, 5]]))
	_line("| pull back, then let go (cancel) | %s |" % _gesture([[back, false, 60], [Vector2.ZERO, false, 60]]))
	# deke: blade on the right, lift it over to the far left, set it down, pull
	_gesture([[Vector2(0.7, 0.6), false, 40], [Vector2(0.7, 0.0), true, 25], [Vector2(0.6, -0.8), false, 40]])
	_line("| deke: lift over to the far side, set down, pull | %s |" % ("kept the puck" if puck.controller == skaters[0] else "lost the puck"))


# ---------------------------------------------------------------- skating

func _bench_skating() -> void:
	_line("")
	_line("## Skating from a standstill (full stick forward)")
	_line("")
	_line("| speed | top speed | after 1 s | 0 to 90% | 0 to 90% dashing | peak while dashing |")
	_line("|---|---|---|---|---|---|")
	for r in RATINGS:
		var res := []
		for use_dash in [false, true]:
			_clear()
			var s := _skater(_stats({"speed": r}))
			var t := 0.0
			var t90 := -1.0
			var at1 := 0.0
			var peak := 0.0
			while t < 8.0:
				s.ctrl.reset()
				s.ctrl.move = Vector2(1, 0)
				s.ctrl.dash = use_dash
				_step()
				_recentre(s)
				t += DT
				peak = maxf(peak, s.speed())
				if absf(t - 1.0) < DT * 0.5:
					at1 = s.speed()
				if t90 < 0.0 and s.speed() >= s.profile.max_speed * 0.9:
					t90 = t
			res.append([s.profile.max_speed, at1, t90, peak])
		_line("| %d | %s | %s | %.2f s | %.2f s | %s |" % [r, _mph(res[0][0]), _mph(res[0][1]), res[0][2], res[1][2], _mph(res[1][3])])


func _bench_stop() -> void:
	_line("")
	_line("## Hockey stop from top speed (speed 100)")
	_line("")
	_line("| agility | stopping distance | time |")
	_line("|---|---|---|")
	for r in RATINGS:
		_clear()
		var s := _skater(_stats({"speed": 100, "agility": r}))
		s.vel = Vector3(s.profile.max_speed, 0, 0)
		var t := 0.0
		var x0 := s.position.x
		while s.speed() > 0.3 and t < 5.0:
			s.ctrl.reset()
			s.ctrl.stop = true
			_step()
			t += DT
		_line("| %d | %.1f m | %.2f s |" % [r, s.position.x - x0, t])


func _bench_turn() -> void:
	_line("")
	_line("## Full-speed turn (speed 75, stick swung 90 degrees, then 180)")
	_line("")
	_line("| agility | 90 degree turn: time | 90 degree turn: radius | speed kept | 180 degree reversal: time |")
	_line("|---|---|---|---|---|")
	for r in RATINGS:
		_clear()
		var s := _skater(_stats({"speed": 75, "agility": r}))
		s.vel = Vector3(s.profile.max_speed, 0, 0)
		var t := 0.0
		var start := s.position
		var v0 := s.speed()
		# 90: velocity direction reaches 80 degrees
		while t < 4.0:
			s.ctrl.reset()
			s.ctrl.move = Vector2(0, 1)
			_step()
			t += DT
			if atan2(s.vel.z, s.vel.x) > deg_to_rad(80.0):
				break
		var radius := (s.position - start).z
		var kept := s.speed() / v0
		var t90 := t
		_clear()
		s = _skater(_stats({"speed": 75, "agility": r}))
		s.vel = Vector3(s.profile.max_speed, 0, 0)
		t = 0.0
		while t < 5.0 and s.vel.x > -1.0:
			s.ctrl.reset()
			s.ctrl.move = Vector2(-1, 0.05)
			_step()
			_recentre(s)
			t += DT
		_line("| %d | %.2f s | %.1f m | %d%% | %.2f s |" % [r, t90, radius, kept * 100.0, t])


# ---------------------------------------------------------------- puck

## Sharp cuts with the puck: the stick swings 70 degrees left/right of the
## skating line every 0.5 s at full speed. Counts how often the puck slides off.
func _carry_losses(sh: int, agi: int, mode: String, period: float) -> float:
	Tuning.set_mode(mode)
	var losses := 0
	var trials := 4
	for trial in trials:
		_clear()
		var s := _skater(_stats({"stick_handling": sh, "agility": agi, "speed": 75}))
		s.vel = Vector3(s.profile.max_speed * 0.9, 0, 0)
		_give_puck(s)
		var t := 0.0
		while t < 8.0:
			var side := 1.0 if fmod(t, period * 2.0) < period else -1.0
			s.ctrl.reset()
			s.ctrl.move = Vector2(cos(deg_to_rad(CUT)), side * sin(deg_to_rad(CUT)))
			_step()
			_recentre(s)
			t += DT
			if puck.controller != s:
				losses += 1
				_give_puck(s)
	Tuning.set_mode("HYBRID")
	return losses / float(trials) / 8.0 * 10.0


func _bench_carry() -> void:
	_line("")
	_line("## Carrying through hard cuts (speed 75, 85 degree cuts every 0.4 s)")
	_line("")
	_line("Pucks lost per 10 s of cutting. Agility turns you faster, which is harder to hold.")
	_line("")
	_line("| stick handling | agility 1 | agility 50 | agility 100 |")
	_line("|---|---|---|---|")
	for r in RATINGS:
		_line("| %d | %.1f | %.1f | %.1f |" % [r,
			_carry_losses(r, 1, "HYBRID", 0.4), _carry_losses(r, 50, "HYBRID", 0.4), _carry_losses(r, 100, "HYBRID", 0.4)])
	_line("")
	_line("Same test with both ratings equal, by physics mode:")
	_line("")
	_line("| rating | SIM | HYBRID | ARCADE |")
	_line("|---|---|---|---|")
	for r in RATINGS:
		_line("| %d | %.1f | %.1f | %.1f |" % [r,
			_carry_losses(r, r, "SIM", 0.4), _carry_losses(r, r, "HYBRID", 0.4), _carry_losses(r, r, "ARCADE", 0.4)])


func _bench_stickhandle() -> void:
	_line("")
	_line("## Stickhandling in place (right stick swept edge to edge of the arc)")
	_line("")
	_line("| stick handling | arc crossing time | losses / 10 s at 1 sweep/s | at 1.5 sweeps/s | at 2 sweeps/s |")
	_line("|---|---|---|---|---|")
	for r in RATINGS:
		var cells := []
		# crossing time: blade from one edge of the arc to the other
		_clear()
		var s := _skater(_stats({"stick_handling": r}))
		var left := Vector2(cos(-Skater.ARC_HALF), sin(-Skater.ARC_HALF))
		for i in 120:
			s.ctrl.reset()
			s.ctrl.stick = left
			_step()
		var t := 0.0
		while t < 2.0:
			s.ctrl.reset()
			s.ctrl.stick = Vector2(left.x, -left.y)
			_step()
			t += DT
			if atan2(s.blade_local.y, s.blade_local.x) > Skater.ARC_HALF * 0.9:
				break
		cells.append("%.2f s" % t)
		for hz in [1.0, 1.5, 2.0]:
			var losses := 0
			_clear()
			s = _skater(_stats({"stick_handling": r}))
			_give_puck(s)
			t = 0.0
			while t < 10.0:
				var side := 1.0 if fmod(t * hz, 1.0) < 0.5 else -1.0
				s.ctrl.reset()
				s.ctrl.stick = Vector2(left.x, left.y * side)
				_step()
				t += DT
				if puck.controller != s:
					losses += 1
					_give_puck(s)
			cells.append(str(losses))
		_line("| %d | %s | %s | %s | %s |" % [r, cells[0], cells[1], cells[2], cells[3]])


## Fires `n` shots from the top of the slot (10 m out, centred) and returns
## [mean speed, share on net]. On-net is the straight-line crossing at the goal
## line inside the posts and under the bar; goalies aren't involved.
func _shots(st: Skills, held: float, slap: bool, n: int) -> Array:
	_clear()
	var s := _skater(st)
	var spot := Vector2(Rink.GOAL_X - 10.0, 0.0)
	var total := 0.0
	var on := 0
	for i in n:
		s.place(spot, Vector3(1, 0, 0))
		s.ctrl.reset()
		s.ctrl.aim_point = Vector3(Rink.GOAL_X, 0, 0.55 * (1.0 if i % 2 == 0 else -1.0))
		_give_puck(s)
		puck.position.y = 0.0
		s.shoot(held, slap)
		var v := puck.vel
		var from := puck.position
		total += Vector2(v.x, v.z).length()
		var tt := (Rink.GOAL_X - from.x) / v.x
		var z := from.z + v.z * tt
		var y := from.y + v.y * tt - 0.5 * Puck.GRAVITY * tt * tt
		if absf(z) < Rink.NET_HALF_W - Puck.RADIUS and y < Rink.NET_H - Puck.RADIUS:
			on += 1
	return [total / n, on / float(n)]


func _bench_shots() -> void:
	_line("")
	_line("## Shots from the top of the slot, 10 m out, aimed just inside a post")
	_line("")
	_line("Speed and share of shots on net. Shot power, accuracy and release all set to the rating.")
	_line("")
	_line("| rating | instant shot | wrist, 0.3 s wind-up | wrist, full wind-up | slapshot, full wind-up |")
	_line("|---|---|---|---|---|")
	for r in RATINGS:
		var st := _stats({"shot_power": r, "shot_accuracy": r, "shot_release": r})
		var cells := []
		for c in [[0.0, false], [0.3, false], [1.0, false], [1.4, true]]:
			var res := _shots(st, c[0], c[1], 300)
			cells.append("%s, %d%%" % [_mph(res[0]), int(res[1] * 100.0)])
		_line("| %d | %s | %s | %s | %s |" % ([r] + cells))
	_line("")
	_line("Release on its own (power and accuracy 50):")
	_line("")
	_line("| shot release | instant shot | time to full wind-up |")
	_line("|---|---|---|")
	for r in RATINGS:
		var st := _stats({"shot_release": r})
		var res := _shots(st, 0.0, false, 300)
		_line("| %d | %s, %d%% | %.2f s |" % [r, _mph(res[0]), int(res[1] * 100.0), PhysicsProfile.from_skills(st).charge_time])


func _bench_passes() -> void:
	_line("")
	_line("## Passes to a standing teammate")
	_line("")
	_line("Share of passes the receiver traps cleanly. Passer and receiver have the same pass quality.")
	_line("")
	_line("| pass quality | 8 m | 15 m | 22 m |")
	_line("|---|---|---|---|")
	for r in RATINGS:
		var cells := []
		for dist in [8.0, 15.0, 22.0]:
			var ok := 0
			var n := 60
			for i in n:
				_clear()
				var a := _skater(_stats({"pass_quality": r}))
				var b := _skater(_stats({"pass_quality": r}))
				a.place(Vector2(-dist * 0.5, 0), Vector3(1, 0, 0))
				b.place(Vector2(dist * 0.5, 0), Vector3(-1, 0, 0))
				_give_puck(a)
				for k in 30:
					_step()
				a.ctrl.reset()
				a.ctrl.pass_pressed = true
				a.ctrl.pass_hint = b
				_step()
				var t := 0.0
				while t < 3.0 and not b.has_puck():
					_step()
					t += DT
				if b.has_puck():
					ok += 1
			cells.append("%d%%" % int(ok * 100.0 / n))
		_line("| %d | %s | %s | %s |" % [r, cells[0], cells[1], cells[2]])


func _bench_hits() -> void:
	_line("")
	_line("## Body checks (shoulder check, 6 m/s closing speed, victim skating straight)")
	_line("")
	_line("Impulse / victim's balance. Above 1.0 knocks them down; 0.6 to 1.0 can jar the puck loose.")
	_line("")
	_line("| hitting \\ toughness | 1 | 50 | 100 |")
	_line("|---|---|---|---|")
	for h in [1, 50, 100]:
		var hp := PhysicsProfile.from_skills(_stats({"hitting": h}))
		var cells := []
		for tg in [1, 50, 100]:
			var vp := PhysicsProfile.from_skills(_stats({"toughness": tg}))
			var impulse := 6.0 * Skater.MASS * 0.5 * hp.hit_power * 1.4
			cells.append("%.2f" % (impulse / vp.balance))
		_line("| %d | %s | %s | %s |" % [h, cells[0], cells[1], cells[2]])
