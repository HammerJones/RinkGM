extends Node3D
## Root of the demo: builds the rink and players, runs the fixed-step
## simulation (skaters -> body contact -> goalies -> puck substeps with stick
## and save checks) and the game rules (faceoffs, goals, whistles, clock).
##
## A game is a match between two clubs (Career.next_user_game() from the
## career hub, or Career.exhibition() otherwise): three periods of
## GameSettings length, lines rotating through Bench, a BoxScore that goes
## back to the career. You are one player (no switching): in an exhibition
## you drive the centre's body; in a career game you drive your own player
## and watch from the bench when your line is off (hold Tab / Y to fast-forward).

const PUCK_SUBSTEPS := 4
## Faceoff spots per body, in Bench.SLOTS order (C, LD, RW, LW, RD).
const FACEOFF_OFFSETS := [Vector2(-0.95, 0.0), Vector2(-6.5, -2.5), Vector2(-2.0, 4.0), Vector2(-2.0, -4.0), Vector2(-6.5, 2.5)]
const PERIOD_NAMES := ["1ST", "2ND", "3RD"]

enum State { FACEOFF, PLAY, STOPPAGE, OVER }

## Every body contact between opponents. `impulse` is roughly kg*m/s (a hard
## open-ice hit is 300-600); game mechanics rolls injuries from it.
signal hit_landed(hitter: Skater, victim: Skater, impulse: float, knocked_down: bool)
signal stick_lifted(by: Skater, victim: Skater)

var rink: Rink
var puck: Puck
var skaters: Array[Skater] = []
var goalies: Array[Goalie] = []
var human: Skater
var camera_rig: CameraRig
var hud: Hud
var score := [0, 0]
var clock := 300.0
var state := State.FACEOFF
var time := 0.0

# match / career
var fixture: Dictionary
var settings: GameSettings
var career_mode := false
var benches: Array = []  # Bench per team
var box := BoxScore.new()
var period := 1
var overtime := false
var shootout := false
var user_profile: PlayerProfile
## False while the user's line is on the bench (career games).
var human_on_ice := true
var _between_periods := false
var _chain: Array = []  # profiles that carried the puck this possession (assists)
var _chain_team := -1
var _last_shooter: Skater = null
var _rng := RandomNumberGenerator.new()
var _finished := false

var _state_timer := 0.0
var _pending_faceoff := Vector2.ZERO
var _stall := 0.0
var _marker: MeshInstance3D
var _arc: MeshInstance3D
var controller: HumanController
var _palettes := []
var _focus_override: Variant = null
## `-- --autoplay` lets the AI drive your skater too (attract mode / testing).
var autoplay := "--autoplay" in OS.get_cmdline_user_args()
var stats := {"shots": 0, "saves": 0, "goals": 0, "possessions": 0, "whistles": 0, "checks": 0, "hits": 0, "knockdowns": 0, "stick_lifts": 0}


func _ready() -> void:
	randomize()
	_rng.randomize()
	if "--career" in OS.get_cmdline_user_args() and CareerState.fixture.is_empty():
		set_physics_process(false)
		set_process(false)
		get_tree().change_scene_to_file.call_deferred(CareerState.HUB_SCENE)
		return
	fixture = CareerState.fixture if not CareerState.fixture.is_empty() else Career.exhibition()
	career_mode = int(fixture.user_id) >= 0
	settings = fixture.settings
	for arg in OS.get_cmdline_user_args():
		# `-- --period=2` plays 2-minute periods (quick tests)
		if arg.begins_with("--period="):
			settings = GameSettings.from_dict(settings.to_dict())
			settings.period_minutes = arg.trim_prefix("--period=").to_float()
	_build_environment()
	rink = Rink.new()
	add_child(rink)
	puck = Puck.new()
	add_child(puck)
	puck.goal_scored.connect(_on_goal)
	# the user's club is always team 0 (red side of the old demo)
	var clubs: Array = [fixture.home, fixture.away] if fixture.user_home else [fixture.away, fixture.home]
	var lineups: Array = [fixture.home_lineup, fixture.away_lineup] if fixture.user_home else [fixture.away_lineup, fixture.home_lineup]
	for team in 2:
		var pal: Dictionary = clubs[team].palette()
		_palettes.append(pal)
		var bench := Bench.new(team, lineups[team], settings)
		benches.append(bench)
		for i in settings.skaters_on_ice:
			var s := Skater.new()
			s.setup(self, team, i, pal)
			add_child(s)
			skaters.append(s)
		bench.assign_all(team_skaters(team))
		var g := Goalie.new()
		g.setup(self, team, pal)
		if bench.goalie:
			g.skill = bench.goalie.skills.goalie_skill()
		add_child(g)
		goalies.append(g)
	clock = settings.period_length()
	human = skaters[0]
	hit_landed.connect(_on_hit_landed)
	if career_mode:
		user_profile = CareerState.career.players[int(fixture.user_id)]
		_sync_human()
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	hud = Hud.new()
	add_child(hud)
	_marker = _make_marker()
	add_child(_marker)
	_arc = _make_arc()
	add_child(_arc)
	controller = HumanController.new()
	controller.game = self
	add_child(controller)
	Tuning.mode_changed.connect(hud.set_mode)
	hud.set_mode(Tuning.mode_name())
	_start_faceoff(Vector2.ZERO)
	_handle_capture_args()
	# `-- --test=controls` runs the scripted control checks in tests/
	if "--test=controls" in OS.get_cmdline_user_args():
		var t: Node = load("res://tests/controls_test.gd").new()
		t.set("game", self)
		add_child(t)


## `-- --screenshot=out.png --shot-after=6 [--iso]` saves a frame and quits
## (used to check the look from the command line).
func _handle_capture_args() -> void:
	var path := ""
	var after := 5.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			path = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--shot-after="):
			after = arg.trim_prefix("--shot-after=").to_float()
		elif arg == "--iso":
			camera_rig.toggle()
		elif arg.begins_with("--focus="):
			var xz := arg.trim_prefix("--focus=").split_floats(",")
			_focus_override = Vector3(xz[0], 0, xz[1])
		elif arg.begins_with("--zoom="):
			camera_rig.zoom = arg.trim_prefix("--zoom=").to_float()
	if path == "":
		return
	await get_tree().create_timer(after).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


# ---------------------------------------------------------------- queries

func attack_side(team: int) -> int:
	return 1 if team == 0 else -1


func is_frozen() -> bool:
	return state == State.FACEOFF or state == State.OVER


func team_skaters(team: int) -> Array:
	return skaters.filter(func(s): return s.team == team)


func teammates(s: Skater) -> Array:
	return skaters.filter(func(x): return x.team == s.team and x != s)


func nearest_skater(team: int, p: Vector2) -> Skater:
	var best: Skater = null
	var best_d := INF
	for s in skaters:
		if s.team != team or s.stun_timer > 0.0:
			continue
		var d := p.distance_to(Vector2(s.position.x, s.position.z))
		if d < best_d:
			best_d = d
			best = s
	return best


func nearest_opponent(team: int, p: Vector2) -> Skater:
	return nearest_skater(1 - team, p)


func nearest_opponent_distance_to(team: int, p: Vector2) -> float:
	var o := nearest_opponent(team, p)
	return INF if o == null else p.distance_to(Vector2(o.position.x, o.position.z))


## True when no skater of the other team is within `margin` of the segment.
func lane_clear(team: int, from: Vector2, to: Vector2, margin: float) -> bool:
	for o in team_skaters(1 - team):
		var p := Vector2(o.position.x, o.position.z)
		if Geometry2D.get_closest_point_to_segment(p, from, to).distance_to(p) < margin:
			return false
	return true


## The open teammate furthest up ice, or null.
func best_pass_option(s: Skater) -> Skater:
	var att := attack_side(s.team)
	var from := Vector2(s.position.x, s.position.z)
	var best: Skater = null
	var best_score := -INF
	for m in teammates(s):
		var to := Vector2(m.position.x, m.position.z)
		var open := INF
		for o in team_skaters(1 - s.team):
			open = minf(open, Geometry2D.get_closest_point_to_segment(Vector2(o.position.x, o.position.z), from, to).distance_to(Vector2(o.position.x, o.position.z)))
		if open < 1.4:
			continue
		var sc := to.x * att + minf(open, 4.0) * 2.0
		if sc > best_score:
			best_score = sc
			best = m
	return best


# ---------------------------------------------------------------- loop

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_mode"):
		Tuning.cycle_mode()
	elif event.is_action_pressed("camera"):
		camera_rig.toggle()
	elif event.is_action_pressed("reset"):
		_new_game()
	elif event.is_action_pressed("help"):
		hud.toggle_help()


func _physics_process(dt: float) -> void:
	time += dt
	_update_rules(dt)
	_update_benches(dt)
	if not autoplay and human_on_ice:
		controller.update(dt)
	for s in skaters:
		if s != human or autoplay or not human_on_ice:
			SkaterAI.think(s, self, dt)
	for s in skaters:
		s.physics_update(dt)
	_collide_bodies()
	for g in goalies:
		g.physics_update(dt)
	var sdt := dt / PUCK_SUBSTEPS
	for i in PUCK_SUBSTEPS:
		var prev := puck.position
		StickPuck.step(self, puck, sdt)
		puck.integrate(sdt)
		_puck_body_collisions()
		for g in goalies:
			g.check_save(puck, prev)
	_check_stall(dt)


func _process(dt: float) -> void:
	var focus: Vector3 = puck.position * 0.65 + human.position * 0.35
	if _focus_override != null:
		focus = _focus_override
	camera_rig.follow(focus, dt)
	_marker.position = human.position + Vector3(0, 0.02, 0)
	_marker.visible = human_on_ice
	_arc.visible = not autoplay and human_on_ice
	_arc.transform = Transform3D(human.basis, human.position + Vector3(0, 0.015, 0))
	hud.set_score(_palettes[0].name, _palettes[1].name, score[0], score[1], clock, _period_label())
	if career_mode and not human_on_ice and state != State.OVER:
		hud.set_bench(_bench_text())
	else:
		hud.set_bench("")
	hud.set_stamina(human.stamina)
	hud.set_power(human.windup())
	# career: hold fast-forward while you're on the bench
	var ff := career_mode and not human_on_ice and state != State.OVER and not autoplay and Input.is_action_pressed("fast_forward")
	Engine.time_scale = 4.0 if ff else 1.0


func _update_rules(dt: float) -> void:
	_state_timer -= dt
	match state:
		State.FACEOFF:
			if _state_timer <= 0.0:
				state = State.PLAY
				puck.frozen = false
				puck.vel = Vector3(0, -1.0, 0)
		State.PLAY:
			clock -= dt
			box.add_toi(_on_ice_profiles(-1), dt)
			if clock <= 0.0:
				clock = 0.0
				_end_period()
		State.STOPPAGE:
			if _state_timer <= 0.0:
				if _between_periods:
					_between_periods = false
					clock = settings.ot_length(fixture.playoff) if overtime else settings.period_length()
				_start_faceoff(_pending_faceoff)


# ---------------------------------------------------------------- players


func on_possession(s: Skater) -> void:
	stats.possessions += 1
	if s.team != _chain_team:
		_chain.clear()
		_chain_team = s.team
	if s.player and (_chain.is_empty() or _chain[-1] != s.player):
		_chain.append(s.player)


func on_shot(s: Skater, _slap: bool) -> void:
	stats.shots += 1
	_last_shooter = s


func on_save(g: Goalie, frozen: bool) -> void:
	if state != State.PLAY:
		return
	stats.saves += 1
	_credit_shot(1 - g.team)
	if frozen:
		hud.show_message("SAVE", 1.2)
		_whistle(Vector2(g.side * Rink.DOT_X, Rink.DOT_Z * signf(puck.position.z if puck.position.z != 0.0 else 1.0)))


# ---------------------------------------------------------------- puck & bodies

## Skates and shins block pucks that aren't on that skater's stick.
func _puck_body_collisions() -> void:
	if puck.frozen or puck.in_net_side != 0 or puck.position.y > 0.5:
		return
	for s in skaters:
		if s == puck.controller or not puck.can_be_touched_by(s):
			continue
		var d := Vector2(puck.position.x - s.position.x, puck.position.z - s.position.z)
		var dist := d.length()
		if dist > 0.3 or dist < 0.0001:
			continue
		var n := d / dist
		puck.position.x = s.position.x + n.x * 0.3
		puck.position.z = s.position.z + n.y * 0.3
		var n3 := Vector3(n.x, 0, n.y)
		var vn := (puck.vel - s.vel).dot(n3)
		if vn < 0.0:
			puck.vel -= n3 * vn * 1.2
			puck.vel *= 0.7


## Skater vs skater (with body checks) and skaters vs goalies.
func _collide_bodies() -> void:
	var n := skaters.size()
	var min_d := Skater.RADIUS * 2.0
	for i in n:
		var a := skaters[i]
		for j in range(i + 1, n):
			var b := skaters[j]
			var d := Vector3(b.position.x - a.position.x, 0, b.position.z - a.position.z)
			var dist := d.length()
			if dist >= min_d or dist < 0.0001:
				continue
			var nrm := d / dist
			var pen := min_d - dist
			a.position -= nrm * pen * 0.5
			b.position += nrm * pen * 0.5
			var closing := (a.vel - b.vel).dot(nrm)
			if closing <= 0.0:
				continue
			var imp := (1.0 + 0.25) * closing * 0.5
			a.vel -= nrm * imp
			b.vel += nrm * imp
			if a.team != b.team and closing > 3.0:
				# whoever is driving into the contact harder is the hitter
				var a_in := a.vel.dot(nrm) + imp
				var b_in := -(b.vel.dot(nrm) - imp)
				if a_in >= b_in:
					_body_hit(a, b, nrm, closing)
				else:
					_body_hit(b, a, -nrm, closing)
	for g in goalies:
		for s in skaters:
			var d := Vector2(s.position.x - g.pos2.x, s.position.z - g.pos2.y)
			var r := Skater.RADIUS + 0.45
			if d.length() < r and d.length() > 0.0001:
				var p := g.pos2 + d.normalized() * r
				s.position = Vector3(p.x, 0, p.y)
				var n3 := Vector3(d.x, 0, d.y).normalized()
				var vn := s.vel.dot(n3)
				if vn < 0.0:
					s.vel -= n3 * vn


## Opponents colliding: the impulse grows with closing speed and the hitter's
## rating (more with a shoulder check). It knocks the victim down if it beats
## their balance (toughness, less while carving hard or stopping), and a
## lighter hit can still jar the puck loose.
func _body_hit(hitter: Skater, victim: Skater, nrm: Vector3, closing: float) -> void:
	if victim.stun_timer > 0.0:
		return
	# a shoulder check carries the hitter's weight; incidental bumps don't
	var impulse := closing * Skater.MASS * 0.5 * hitter.profile.hit_power
	impulse *= 1.4 if hitter.check_timer > 0.0 else 0.3
	var balance := victim.profile.balance * victim.stability()
	var down := impulse > balance
	stats.hits += 1
	if down:
		stats.knockdowns += 1
		victim.knock_down(nrm * closing * 0.6)
	elif victim.has_puck() and impulse > balance * 0.6 and randf() < (impulse / balance - 0.6) * 1.5:
		puck.release(victim, victim.vel + nrm * 2.0)
	hit_landed.emit(hitter, victim, impulse, down)


func on_stick_lift(by: Skater, victim: Skater) -> void:
	stats.stick_lifts += 1
	stick_lifted.emit(by, victim)


## Hits feed the box score, and hard ones can injure. Physics impulses run
## ~50-200 for a bump and ~250-500 for a shoulder check; Injury wants a
## 2 (routine) .. 6+ (huge) impact scale.
func _on_hit_landed(hitter: Skater, victim: Skater, impulse: float, knocked_down: bool) -> void:
	if hitter.check_timer > 0.0 or knocked_down:
		box.hit(hitter.player)
	if victim.player == null or state != State.PLAY or impulse < 150.0:
		return
	var inj := Injury.roll_hit(hitter.skills, victim.skills, impulse / 80.0, 1.0 - victim.stamina, _rng)
	if inj == null:
		return
	var p := victim.player
	box.injuries.append({"pid": p.id, "injury": inj})
	benches[victim.team].injure(p, team_skaters(victim.team))
	hud.show_message("%s hurt\n%s" % [p.short_name(), inj.describe()], 2.5)
	if career_mode:
		_sync_human()


func _check_stall(dt: float) -> void:
	if state != State.PLAY or puck.controller != null or puck.horizontal_speed() > 0.3:
		_stall = 0.0
		return
	_stall += dt
	if _stall > 8.0:
		var p := puck.position
		var spot := Vector2(signf(p.x) * (Rink.DOT_X if absf(p.x) > Rink.BLUE_X else Rink.NEUTRAL_DOT_X), signf(p.z if p.z != 0.0 else 1.0) * Rink.DOT_Z)
		_whistle(spot)


# ---------------------------------------------------------------- rules

func _on_goal(side: int) -> void:
	if state != State.PLAY:
		return
	var scorer := 0 if side == attack_side(0) else 1
	score[scorer] += 1
	stats.goals += 1
	_credit_goal(scorer)
	hud.show_message("%s GOAL!" % _palettes[scorer].name, 2.8)
	state = State.STOPPAGE
	_state_timer = 3.0
	_pending_faceoff = Vector2.ZERO
	if overtime:
		_game_over()


func _whistle(spot: Vector2) -> void:
	stats.whistles += 1
	state = State.STOPPAGE
	_state_timer = 1.3
	_pending_faceoff = spot
	puck.frozen = true
	puck.controller = null


func _start_faceoff(spot: Vector2) -> void:
	state = State.FACEOFF
	_state_timer = 1.0
	_stall = 0.0
	_chain.clear()
	_last_shooter = null
	for b in benches:
		if b.tick(0.0, team_skaters(b.team), true, true) and career_mode:
			_sync_human()
	puck.reset_at(Vector3(spot.x, 1.0, spot.y))
	puck.frozen = true
	for team in 2:
		var att := attack_side(team)
		var list := team_skaters(team)
		for i in list.size():
			var o: Vector2 = FACEOFF_OFFSETS[i % FACEOFF_OFFSETS.size()]
			var p := Vector2(spot.x + o.x * att, spot.y + o.y)
			p.x = clampf(p.x, -Rink.GOAL_X + 1.5, Rink.GOAL_X - 1.5)
			p.y = clampf(p.y, -Rink.HALF_W + 1.5, Rink.HALF_W - 1.5)
			list[i].place(p, Vector3(att, 0, 0))
	for g in goalies:
		g.reset()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if autoplay and settings:
		print("autoplay stats: ", stats, " score ", score, " period ", period, " clock ", snappedf(clock, 0.1))
		_print_box()


func _print_box() -> void:
	for team in 2:
		var b: Bench = benches[team]
		var rows: Array = []
		for l in b.f_lines + b.d_pairs:
			for p in l:
				if p and box.lines.has(p.id) and not rows.has(p):
					rows.append(p)
		print("  %s  shots on goal %d" % [_palettes[team].name, box.shots_on[team]])
		for p in rows:
			var l: Dictionary = box.lines[p.id]
			print("    %-3s %-16s %dG %dA %2dS %dH %+d  toi %d:%02d" % [p.position, p.short_name(), l.g, l.a, l.shots, l.hits, l.pm, int(l.toi) / 60, int(l.toi) % 60])
	for e in box.injuries:
		print("  injury: ", e.pid, " ", e.injury.describe(), " out ", e.injury.games_out)


## Clock hit zero: intermission, overtime, shootout or final.
func _end_period() -> void:
	var regulation_over := period >= settings.periods
	if not regulation_over:
		hud.show_message("END OF %s PERIOD" % PERIOD_NAMES[mini(period - 1, 2)], settings.intermission_seconds)
		_intermission()
		return
	if score[0] != score[1]:
		_game_over()
		return
	if fixture.playoff or not overtime:
		overtime = true
		hud.show_message("OVERTIME\nNext goal wins", settings.intermission_seconds)
		_intermission()
		return
	_shootout()


func _intermission() -> void:
	period += 1
	_between_periods = true
	_whistle(Vector2.ZERO)
	_state_timer = settings.intermission_seconds
	for s in skaters:
		s.stamina = minf(1.0, s.stamina + 0.5)


## Shootouts are resolved from ratings for now: three rounds, then sudden death.
func _shootout() -> void:
	shootout = true
	var made := [0, 0]
	for r in 20:
		for team in 2:
			var b: Bench = benches[team]
			var shooter: PlayerProfile = b.f_lines[r % 3][1] if r < 3 else b.f_lines[(r + 1) % 3][r % 3]
			var g: PlayerProfile = benches[1 - team].goalie
			var p := 0.33 + 0.3 * (shooter.skills.n("shot_accuracy") * 0.5 + shooter.skills.n("stick_handling") * 0.5) - 0.3 * (g.skills.goalie_skill() - 0.6) if g else 0.6
			if _rng.randf() < p:
				made[team] += 1
		if (r >= 2 and made[0] != made[1]) or r == 19:
			break
	var w := 0 if made[0] >= made[1] else 1
	score[w] += 1
	hud.show_message("SHOOTOUT %d-%d" % [made[0], made[1]], 3.0)
	_game_over()


func _game_over() -> void:
	state = State.OVER
	Engine.time_scale = 1.0
	var text := "TIE GAME"
	if score[0] != score[1]:
		text = "%s WINS" % _palettes[0 if score[0] > score[1] else 1].name
	if overtime and not shootout:
		text += " IN OT"
	var next := "R / Start for the career hub" if career_mode else "R / Start to play again"
	hud.show_message("%s\n%s" % [text, next], 9999.0)
	if career_mode and not _finished:
		_finished = true
		CareerState.finish_match(_result())
		if autoplay:
			get_tree().create_timer(1.0).timeout.connect(CareerState.back_to_hub)


## The game in the career's result format (home/away order restored).
func _result() -> Dictionary:
	var home_first: bool = fixture.user_home
	var goals := [score[0], score[1]] if home_first else [score[1], score[0]]
	var gs := [benches[0].goalie, benches[1].goalie] if home_first else [benches[1].goalie, benches[0].goalie]
	return box.to_result(fixture.home.id, fixture.away.id, goals, overtime and not shootout, shootout, fixture.playoff, gs, settings.game_length())


func _new_game() -> void:
	if career_mode:
		if state == State.OVER:
			CareerState.back_to_hub()
		return
	score = [0, 0]
	period = 1
	overtime = false
	shootout = false
	box = BoxScore.new()
	clock = settings.period_length()
	hud.show_message("", 0.0)
	_start_faceoff(Vector2.ZERO)


# ---------------------------------------------------------------- lines & stats

func _update_benches(dt: float) -> void:
	if state != State.PLAY:
		return
	var changed := false
	for b in benches:
		# change on the fly unless the puck is in our end
		var safe: bool = puck.position.x * attack_side(b.team) > -Rink.BLUE_X
		changed = b.tick(dt, team_skaters(b.team), false, safe) or changed
	if changed and career_mode:
		_sync_human()


## In a career game the human drives whichever body their player is on.
func _sync_human() -> void:
	var was := human_on_ice
	human_on_ice = false
	for s in team_skaters(0):
		if s.player == user_profile:
			if s != human:
				human.cancel_shot()
			human = s
			human_on_ice = true
	if hud and was and not human_on_ice and not benches[0].hurt.has(user_profile.id):
		hud.show_message("LINE CHANGE", 1.0)


func _bench_text() -> String:
	if benches[0].hurt.has(user_profile.id):
		return "INJURED - out for the game\nHold %s to fast-forward" % _ff_hint()
	return "ON THE BENCH\nHold %s to fast-forward" % _ff_hint()


func _ff_hint() -> String:
	return "Tab" if InputSetup.device == InputSetup.Device.KBM else "Y"


func _period_label() -> String:
	if shootout:
		return "SO"
	if overtime:
		return "OT" if period <= settings.periods + 1 else "%dOT" % (period - settings.periods)
	return PERIOD_NAMES[mini(period - 1, 2)]


## Profiles on the ice for a team (-1 = both).
func _on_ice_profiles(team: int) -> Array:
	var out: Array = []
	for s in skaters:
		if (team == -1 or s.team == team) and s.player:
			out.append(s.player)
	return out


func _credit_shot(team: int) -> void:
	var shooter: PlayerProfile = _last_shooter.player if _last_shooter and _last_shooter.team == team else null
	box.shot_on_goal(shooter, team)
	_last_shooter = null


func _credit_goal(team: int) -> void:
	var touch: Skater = puck.last_touch
	var scorer: PlayerProfile = touch.player if touch and touch.team == team else null
	if scorer == null and _chain_team == team and not _chain.is_empty():
		scorer = _chain[-1]
	box.shot_on_goal(scorer, team)
	_last_shooter = null
	var assists: Array = []
	if _chain_team == team:
		for i in range(_chain.size() - 1, -1, -1):
			var p: PlayerProfile = _chain[i]
			if p != scorer and not assists.has(p):
				assists.append(p)
			if assists.size() == 2:
				break
	box.goal(scorer, assists, _on_ice_profiles(team), _on_ice_profiles(1 - team))


# ---------------------------------------------------------------- scene

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("24252b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.89, 0.96)
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, -32.0, 0.0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)


func _make_marker() -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.62
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("ffd23f")
	torus.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = torus
	mi.scale = Vector3(1, 0.08, 1)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## The 90 degree arc the stick can reach, drawn on the ice under the player.
func _make_arc() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 18
	for i in steps:
		var pts := []
		for k in [i, i + 1]:
			var a := lerpf(-Skater.ARC_HALF, Skater.ARC_HALF, float(k) / steps)
			for r in [Skater.REACH_MIN, Skater.REACH_MAX]:
				# local forward is -Z, right is +X (see Skater._apply_transform)
				pts.append(Vector3(sin(a) * r, 0, -cos(a) * r))
		for idx in [0, 1, 2, 2, 1, 3]:
			st.add_vertex(pts[idx])
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.0, 0.82, 0.25, 0.22)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
