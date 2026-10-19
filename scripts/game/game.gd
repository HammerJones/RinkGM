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
##
## Practice (CareerState.start_practice(), `-- --practice`) uses the same rink:
## your skater alone with a puck and the nets, no opponents, clock or stats,
## and a goalie you can switch on from the Esc menu (PauseMenu).

const PUCK_SUBSTEPS := 4
## Faceoff spots per body, in Bench.SLOTS order (C, LD, RW, LW, RD).
const FACEOFF_OFFSETS := [Vector2(-0.95, 0.0), Vector2(-6.5, -2.5), Vector2(-2.0, 4.0), Vector2(-2.0, -4.0), Vector2(-6.5, 2.5)]
const PERIOD_NAMES := ["1ST", "2ND", "3RD"]
const BENCH_GATES := [3.05, 10.95]  # |x| of each bench's centre-ice and far gates
const GATE_IN := 0.6           # how far out from the boards the gate spots sit
const DOOR_REACH := 1.3        # a called skater this close to the exit gate is off
const DOOR_EXIT_SPEED := 3.0   # m/s the fresh skater steps onto the ice with
const BENCH_X := [[-11.4, -2.6], [11.4, 2.6]]  # each bench's length along the boards, door end last
const BENCH_ROW := 12          # players standing in a row along a bench

enum State { FACEOFF, PLAY, STOPPAGE, OVER }

## Every body contact between opponents. `impulse` is roughly kg*m/s (a hard
## open-ice hit is 300-600); game mechanics rolls injuries from it.
signal hit_landed(hitter: Skater, victim: Skater, impulse: float, knocked_down: bool)
signal stick_lifted(by: Skater, victim: Skater)
## A stick snapped (StickWear): `stick_id` is the shop item (&"" outside a
## career game), `cause` &"slapshot", &"block", &"slash", &"lift" or &"check".
## Each one, either team's, is a broken stick for the rink's barrel.
signal stick_broken(s: Skater, stick_id: StringName, cause: StringName)
## The bench handed a skater a new stick (at the door, or at a faceoff).
signal stick_replaced(s: Skater)


const BRACED := 2.0  # balance multiplier for a skater who sees the hit coming

var rink: Rink
var venue: Venue
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
var _so: Shootout  # the shootout being played (Shootout), or null
var _last_played := Vector2.ZERO  # where a stick last had the puck (out-of-play faceoffs)
var user_profile: PlayerProfile
## False while the user's line is on the bench (career games).
var human_on_ice := true
var _between_periods := false
var _chain: Array = []  # profiles that carried the puck this possession (assists)
var _chain_team := -1
var _last_shooter: Skater = null
var _rng := RandomNumberGenerator.new()
var _finished := false
## Everything that happens in the match, for the HUD, venue, stats and dev menu.
var events := MatchEvents.new()
## How organised the play is at this level (read by the on-ice AI).
var tier_ai: TierAI

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
## Per-team override of the match's TierAI (see ai_for).
var team_ai: Array = [null, null]
var _default_ai := TierAI.for_tier(4)
## Shots and seconds of possession per team (the tier check prints them).
var team_shots := [0, 0]
var team_possession := [0.0, 0.0]
var _debris: Array[Node3D] = []
## Practice mode: one skater, a puck, the nets; nothing is recorded.
var practice := false
var _practice_reset := 0.0  # seconds until the puck comes back after a goal or freeze
var stats := {"shots": 0, "saves": 0, "goals": 0, "possessions": 0, "whistles": 0, "checks": 0, "hits": 0, "knockdowns": 0, "stick_lifts": 0, "sticks_broken": 0}


func _ready() -> void:
	randomize()
	# `-- --seed=N` replays the same game (the tier check uses it so results
	# don't change with nothing but art in a diff)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed(hash(arg.trim_prefix("--seed=")))
	_rng.seed = randi()
	var args := OS.get_cmdline_user_args()
	# `-- --venue-walk` explores the building on foot instead of playing
	if "--venue-walk" in args:
		set_physics_process(false)
		set_process(false)
		get_tree().change_scene_to_file.call_deferred("res://scenes/venue/venue_walk.tscn")
		return
	practice = CareerState.practice or "--practice" in args or "--test=practice" in args
	if "--career" in args and CareerState.fixture.is_empty() and not practice:
		set_physics_process(false)
		set_process(false)
		get_tree().change_scene_to_file.call_deferred(CareerState.HUB_SCENE)
		return
	if practice:
		fixture = Career.exhibition(CareerState.career.tier if CareerState.career else 4)
	else:
		fixture = CareerState.fixture if not CareerState.fixture.is_empty() else Career.exhibition(4, Array(args).any(func(x: String) -> bool: return x.begins_with("--ai-levels=")))
	career_mode = int(fixture.user_id) >= 0
	settings = fixture.settings
	tier_ai = TierAI.for_tier(int(fixture.get("tier", 4)))
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
	puck.left_rink.connect(_on_puck_out)
	# the building around the ice (scenes/venue); `-- --no-venue` leaves it out
	if not "--no-venue" in OS.get_cmdline_user_args():
		venue = Venue.instantiate_for(fixture)
		add_child(venue)
		venue.bind_game(self)
	# the user's club is always team 0 (red side of the old demo)
	var clubs: Array = [fixture.home, fixture.away] if fixture.user_home else [fixture.away, fixture.home]
	var lineups: Array = [fixture.home_lineup, fixture.away_lineup] if fixture.user_home else [fixture.away_lineup, fixture.home_lineup]
	for team in 2:
		var pal: Dictionary = clubs[team].palette()
		_palettes.append(pal)
		var bench := Bench.new(team, lineups[team], settings)
		benches.append(bench)
		bench.make_body = _make_body.bind(team, pal)
		var slots: int = settings.skaters_on_ice
		if practice:
			slots = 1 if team == 0 else 0
		for s in bench.lineup_bodies(slots):
			skaters.append(s)
		if practice:
			continue
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
	elif practice and CareerState.career:
		# your own ratings and learned moves (Skater.knows)
		user_profile = CareerState.career.user()
		human.apply_player(user_profile)
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
	if practice:
		_start_practice()
	else:
		_start_faceoff(Vector2.ZERO)
		events.period_started.emit(period, _period_label())
	_handle_capture_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ai-levels="):
			var lv := arg.trim_prefix("--ai-levels=").split_floats(",")
			for team in mini(lv.size(), 2):
				team_ai[team] = TierAI.for_level(lv[team])
	# `-- --test=controls` runs the scripted control checks in tests/, and
	# `-- --demo=controls|skating|moves` plays a captioned showcase
	if Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("--demo=")):
		var d: Node = load("res://tests/controls_demo.gd").new()
		d.set("game", self)
		add_child(d)
	if "--test=controls" in OS.get_cmdline_user_args():
		var t: Node = load("res://tests/controls_test.gd").new()
		t.set("game", self)
		add_child(t)
	if "--test=sticks" in OS.get_cmdline_user_args():
		var st: Node = load("res://tests/stick_test.gd").new()
		st.set("game", self)
		add_child(st)
	if "--test=lines" in args:
		var lt: Node = load("res://tests/lines_test.gd").new()
		lt.set("game", self)
		add_child(lt)
	if "--test=shootout" in args:
		var so: Node = load("res://tests/shootout_test.gd").new()
		so.set("game", self)
		add_child(so)
	if "--test=positions" in args:
		var ps: Node = load("res://tests/positions_test.gd").new()
		ps.set("game", self)
		add_child(ps)
	if "--test=nets" in args:
		var nt: Node = load("res://tests/nets_test.gd").new()
		nt.set("game", self)
		add_child(nt)
	if "--test=practice" in args:
		var pt: Node = load("res://tests/practice_test.gd").new()
		pt.set("game", self)
		add_child(pt)


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
			camera_rig.set_mode(CameraRig.Mode.ISOMETRIC)
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


## The best open teammate, or null. `vision` (TierAI, 0..1) is how well the
## passer reads the ice: low only sees nearby mates and will force a pass
## into traffic, high finds the open man furthest up ice.
func best_pass_option(s: Skater, vision := 0.5) -> Skater:
	var att := attack_side(s.team)
	var from := Vector2(s.position.x, s.position.z)
	var sees := lerpf(12.0, 45.0, vision)
	var needs_open := lerpf(0.5, 1.8, vision)
	var best: Skater = null
	var best_score := -INF
	for m in teammates(s):
		var to := Vector2(m.position.x, m.position.z)
		var dist := from.distance_to(to)
		if dist > sees:
			continue
		var open := INF
		for o in team_skaters(1 - s.team):
			open = minf(open, Geometry2D.get_closest_point_to_segment(Vector2(o.position.x, o.position.z), from, to).distance_to(Vector2(o.position.x, o.position.z)))
		if open < needs_open:
			continue
		var sc := to.x * att * vision + minf(open, 4.0) * 2.0 * vision - dist * (1.0 - vision) * 0.5
		# a mate open in front of their net is the pass a good reader looks for
		if to.distance_to(Vector2(att * Rink.GOAL_X, 0)) < 8.0:
			sc += 6.0 * vision
		if sc > best_score:
			best_score = sc
			best = m
	return best


# ---------------------------------------------------------------- match API
# Read-only views and the dev menu's levers. Other systems call these rather
# than reaching into the rules state.

## A snapshot for scoreboards and overlays.
func match_info() -> Dictionary:
	return {
		"names": [_palettes[0].name, _palettes[1].name],
		"colors": [_palettes[0].ui, _palettes[1].ui],
		"score": score.duplicate(), "period": period, "period_label": _period_label(),
		"clock": clock, "state": State.keys()[state], "overtime": overtime, "shootout": shootout,
		"shots": box.shots_on.duplicate(), "playoff": bool(fixture.get("playoff", false)),
		"tier": int(fixture.get("tier", 4)), "user_on_ice": human_on_ice,
		"practice": practice,
	}


func team_palette(team: int) -> Dictionary:
	return _palettes[team]


## The body the user drives (the centre in an exhibition).
func user_skater() -> Skater:
	return human


func set_tier_ai(ai: TierAI) -> void:
	tier_ai = ai


func dev_set_score(team: int, n: int) -> void:
	score[team] = maxi(n, 0)
	events.score_changed.emit(score[0], score[1])


func dev_set_clock(seconds: float) -> void:
	clock = maxf(seconds, 0.0)


## Jumps to the start of period `n` (regulation only).
func dev_set_period(n: int) -> void:
	if state == State.OVER:
		return
	period = clampi(n, 1, settings.periods)
	overtime = false
	clock = settings.period_length()
	_whistle(Vector2.ZERO, "dev")


func dev_end_period() -> void:
	if state == State.OVER:
		return
	clock = 0.0
	_end_period()


## Ends the game now with the current score (a tie goes to the shootout).
func dev_end_game() -> void:
	if state == State.OVER:
		return
	if score[0] == score[1]:
		_shootout()
	else:
		_game_over()


## Changes one of the user's ratings for the rest of this game (and in the
## career, since the profile is shared; the hub saves it).
func dev_set_skill(key: String, value: float) -> void:
	var p := human.player
	if p == null:
		return
	p.skills.values[key] = clampf(value, 1.0, 100.0)
	human.set_skills(p.skills)


## How organised `team` plays (TierAI). The match's tier sets both sides
## (`tier_ai`, set by the match setup); `team_ai[team]` overrides one side, as
## `-- --ai-levels=0.5,3` does (team 0 at level 0.5, team 1 at level 3).
func ai_for(team: int) -> TierAI:
	if team_ai[team] != null:
		return team_ai[team]
	var t: TierAI = get("tier_ai")
	return t if t != null else _default_ai


# ---------------------------------------------------------------- loop

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_mode"):
		Tuning.cycle_mode()
	elif event.is_action_pressed("camera"):
		camera_rig.toggle()
	elif event.is_action_pressed("reset"):
		if practice:
			practice_reset_puck()
		else:
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
		StickPuck.step(self, puck, sdt, float(i + 1) / PUCK_SUBSTEPS)
		puck.integrate(sdt)
		_puck_body_collisions()
		for g in goalies:
			g.check_save(puck, prev)
	_check_stall(dt)
	if puck.controller:
		team_possession[puck.controller.team] += dt


func _process(dt: float) -> void:
	var focus: Vector3 = puck.position * 0.65 + human.position * 0.35
	if _focus_override != null:
		focus = _focus_override
	camera_rig.follow(focus, dt)
	_marker.position = human.position + Vector3(0, 0.02, 0)
	_marker.visible = human_on_ice
	_arc.visible = not autoplay and human_on_ice
	_arc.transform = Transform3D(human.basis, human.position + Vector3(0, 0.015, 0))
	if practice:
		hud.set_practice()
	else:
		hud.set_score(_palettes[0].name, _palettes[1].name, score[0], score[1], clock, _period_label())
	if career_mode and not human_on_ice and state != State.OVER and _so == null:
		hud.set_bench(_bench_text())
	else:
		hud.set_bench("")
	hud.set_stamina(human.stamina)
	hud.set_power(human.windup())
	# career: hold fast-forward while you're on the bench
	var ff := career_mode and not human_on_ice and state != State.OVER and not autoplay and _so == null and Input.is_action_pressed("fast_forward")
	Engine.time_scale = 4.0 if ff else 1.0


func _update_rules(dt: float) -> void:
	if practice:
		if _practice_reset > 0.0:
			_practice_reset -= dt
			if _practice_reset <= 0.0:
				practice_reset_puck()
		return
	if _so:
		_so.update(dt)
		return
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
				var new_period := _between_periods
				if _between_periods:
					_between_periods = false
					clock = settings.ot_length(fixture.playoff) if overtime else settings.period_length()
				_start_faceoff(_pending_faceoff)
				if new_period:
					events.period_started.emit(period, _period_label())


# ---------------------------------------------------------------- players


func on_possession(s: Skater) -> void:
	_last_played = Vector2(s.position.x, s.position.z)
	stats.possessions += 1
	if s.team != _chain_team:
		_chain.clear()
		_chain_team = s.team
	if s.player and (_chain.is_empty() or _chain[-1] != s.player):
		_chain.append(s.player)


func on_shot(s: Skater, slap: bool) -> void:
	if _so:
		return  # shootout attempts aren't game shots
	_last_played = Vector2(s.position.x, s.position.z)
	stats.shots += 1
	team_shots[s.team] += 1
	_last_shooter = s
	events.shot.emit(s.team, s.player, slap)


## Over the glass: whistle, and face off in the zone it left from.
## The puck cleared the glass (Puck.left_rink): whistle, and face off at the
## nearest dot in the zone where it was last played. In a shootout the
## attempt is over; in practice the puck comes back.
func _on_puck_out(_at: Vector3) -> void:
	if state != State.PLAY:
		return
	if practice:
		_practice_reset = 1.0
		return
	if _so:
		_so.on_puck_out()
		return
	hud.show_message("OUT OF PLAY", 1.2)
	_whistle(nearest_dot(_last_played), "out_of_play")


func on_save(g: Goalie, frozen: bool) -> void:
	if state != State.PLAY:
		return
	if practice:
		if frozen:
			hud.show_message("SAVE", 1.0)
			_practice_reset = 1.0
		return
	if _so:
		_so.on_save()
		return
	stats.saves += 1
	_credit_shot(1 - g.team)
	events.save.emit(g.team, benches[g.team].goalie, frozen)
	if frozen:
		hud.show_message("SAVE", 1.2)
		_whistle(Vector2(g.side * Rink.DOT_X, Rink.DOT_Z * signf(puck.position.z if puck.position.z != 0.0 else 1.0)), "frozen")


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
			var imp := (1.0 + Contact.BODY_E) * closing * 0.5  # equal masses: half the closing speed each
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
			var dist := d.length()
			if dist >= r or dist < 0.0001:
				continue
			# two bodies with mass: they share the overlap and the impulse
			var n2 := d / dist
			var ws := Goalie.MASS / (Goalie.MASS + Skater.MASS)
			var p := (r - dist) * n2
			s.position += Vector3(p.x, 0, p.y) * ws
			g.pos2 -= p * (1.0 - ws)
			var closing := (Vector2(s.vel.x, s.vel.z) - g.vel2).dot(-n2)
			if closing > 0.0:
				var j := (1.0 + 0.2) * closing * Contact.reduced_mass(Skater.MASS, Goalie.MASS)
				s.vel += Vector3(n2.x, 0, n2.y) * j / Skater.MASS
				g.push(-n2 * j)


## Opponents colliding. The bump itself (the collision impulse along the
## line between them, from closing speed and their masses) was applied by
## _collide_bodies; a shoulder check adds the hitter's leg drive through the
## contact. The victim goes down if the jolt beats their balance (toughness,
## less while carving hard, stopping or dashing). A carrier who stays up keeps
## the puck only as far as their blade still holds it: their body has moved
## and the blade with it.
func _body_hit(hitter: Skater, victim: Skater, nrm: Vector3, closing: float) -> void:
	if victim.stun_timer > 0.0:
		return
	var impulse := (1.0 + Contact.BODY_E) * closing * Contact.reduced_mass(Skater.MASS, Skater.MASS)
	if hitter.check_timer > 0.0:
		var drive := hitter.profile.leg_drive * Contact.CHECK_TIME
		victim.vel += nrm * drive / Skater.MASS
		hitter.vel -= nrm * drive / Skater.MASS * 0.5  # (braced: the legs take the rest)
		impulse += drive
	var down := impulse / Skater.MASS > victim.profile.balance * victim.stability() * _braced(victim, hitter)
	stats.hits += 1
	if down:
		stats.knockdowns += 1
		victim.knock_down()
	hit_landed.emit(hitter, victim, impulse, down)


## A skater who sees the hit coming sets their feet and takes far more of
## it; one hit from the side or behind takes it as it comes.
func _braced(victim: Skater, hitter: Skater) -> float:
	var to := Vector3(hitter.position.x - victim.position.x, 0, hitter.position.z - victim.position.z)
	return BRACED if to.length() > 0.01 and victim.heading.dot(to.normalized()) > -0.2 else 1.0


func on_stick_lift(by: Skater, victim: Skater) -> void:
	stats.stick_lifts += 1
	stick_lifted.emit(by, victim)


## Hits feed the box score, and hard ones can injure. Physics impulses run
## ~50-200 for a bump and ~250-500 for a shoulder check; Injury wants a
## 2 (routine) .. 6+ (huge) impact scale.
func _on_hit_landed(hitter: Skater, victim: Skater, impulse: float, knocked_down: bool) -> void:
	if hitter.check_timer > 0.0 or knocked_down:
		box.hit(hitter.player)
		events.hit.emit(hitter.team, hitter.player, victim.player, impulse / 80.0, knocked_down)
	if victim.player == null or state != State.PLAY or impulse < 150.0:
		return
	var inj := Injury.roll_hit(hitter.skills, victim.skills, impulse / 80.0, 1.0 - victim.stamina, _rng)
	if inj == null:
		return
	var p := victim.player
	box.injuries.append({"pid": p.id, "injury": inj})
	events.injury.emit(victim.team, p, inj)
	benches[victim.team].injure(p)
	hud.show_message("%s hurt\n%s" % [p.short_name(), inj.describe()], 2.5)
	if career_mode and p == user_profile:
		# hurt: you're helped off (the AI skates your body to the bench)
		human_on_ice = false


## A team's bench gate nearer centre ice, where fresh skaters step on and
## new sticks are handed over: on the ice in front of the gap in the boards
## (the venue's gates, scripts/venue/rooms/shell.gd), home bench on the -X half.
func bench_spot(team: int) -> Vector2:
	return Vector2(-BENCH_GATES[0] if team == 0 else BENCH_GATES[0], -Rink.HALF_W + GATE_IN)


## The bench's far gate, where skaters coming off leave the ice.
func bench_exit(team: int) -> Vector2:
	return Vector2(-BENCH_GATES[1] if team == 0 else BENCH_GATES[1], -Rink.HALF_W + GATE_IN)


func on_stick_broken(s: Skater, cause: StringName) -> void:
	stats.sticks_broken += 1
	if s.rig:
		# the blade flies off and the shaft drops
		var away := s.heading * 3.0 + Vector3(randf_range(-2, 2), 2.5, randf_range(-2, 2))
		_debris.append(StickDebris.spawn(self, s.rig.blade, s.vel * 0.6 + away))
		_debris.append(StickDebris.spawn(self, s.rig.stick, s.vel * 0.8 + Vector3(0, 1.0, 0)))
	if s == human and not autoplay:
		hud.show_message("STICK BROKEN\nget a new one at the bench", 2.2)
	stick_broken.emit(s, s.stick_id, cause)


func on_new_stick(s: Skater) -> void:
	stick_replaced.emit(s)


func _check_stall(dt: float) -> void:
	if practice or _so:
		return
	if state != State.PLAY or puck.controller != null or puck.horizontal_speed() > 0.3:
		_stall = 0.0
		return
	_stall += dt
	if _stall > 8.0:
		_whistle(nearest_dot(Vector2(puck.position.x, puck.position.z)), "stall")


## The faceoff dot nearest `p` in its zone: an end-zone dot past the blue
## lines, otherwise a neutral-zone dot.
static func nearest_dot(p: Vector2) -> Vector2:
	var x := Rink.DOT_X if absf(p.x) > Rink.BLUE_X else Rink.NEUTRAL_DOT_X
	return Vector2(signf(p.x if p.x != 0.0 else 1.0) * x, signf(p.y if p.y != 0.0 else 1.0) * Rink.DOT_Z)


# ---------------------------------------------------------------- rules

func _on_goal(side: int) -> void:
	if state != State.PLAY:
		return
	if practice:
		if _practice_reset <= 0.0:
			hud.show_message("GOAL!", 1.2)
			_practice_reset = 1.2
		return
	if _so:
		_so.on_goal(side)
		return
	var scorer := 0 if side == attack_side(0) else 1
	score[scorer] += 1
	stats.goals += 1
	_credit_goal(scorer)
	events.score_changed.emit(score[0], score[1])
	hud.show_message("%s GOAL!" % _palettes[scorer].name, 2.8)
	state = State.STOPPAGE
	_state_timer = 3.0
	_pending_faceoff = Vector2.ZERO
	if overtime:
		_game_over()


func _whistle(spot: Vector2, reason := "whistle") -> void:
	stats.whistles += 1
	events.whistle.emit(reason)
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
		b.tick(0.0, team_skaters(b.team), true, true)
		if _change_lines(b, false):
			events.line_change.emit(b.team, b.on_ice(team_skaters(b.team)))
	if career_mode:
		_sync_human()
	puck.reset_at(Vector3(spot.x, 1.0, spot.y))
	puck.frozen = true
	events.faceoff.emit(spot)
	for d in _debris:
		d.queue_free()
	_debris.clear()
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
		if team_ai[0] or team_ai[1]:
			print("ai levels: ", team_ai.map(func(a): return a.level if a else -1.0),
				" shots ", team_shots, " possession ", team_possession.map(func(x): return roundi(x)))


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
	events.period_ended.emit(period, _period_label())
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
	_whistle(Vector2.ZERO, "period")
	_state_timer = settings.intermission_seconds
	for b in benches:
		for s in b.bodies.values():
			s.stamina = minf(1.0, s.stamina + 0.5)


## Tied after overtime: the shootout, played on the ice (Shootout).
func _shootout() -> void:
	shootout = true
	state = State.PLAY
	_so = Shootout.new(self)
	_so.start()


## Shootout: `s` takes the next attempt. Everyone else goes to the bench, the
## puck sits at centre ice and both goalies set up. You shoot when it's your
## player (career) or your side (exhibition); otherwise the AI does.
func shootout_shooter(s: Skater) -> void:
	for o in skaters.duplicate():
		_park(o)
	skaters.clear()
	skaters.append(s)
	var att := attack_side(s.team)
	s.place(Vector2(-att * 2.5, 0.0), Vector3(att, 0, 0))
	puck.reset_at(Vector3(0, 0, 0))
	puck.frozen = true
	for g in goalies:
		g.reset()
	if human:
		human.cancel_shot()
	human = s
	human_on_ice = (s.player == user_profile) if career_mode else s.team == 0


## The shootout is decided: the winner gets the deciding goal.
func shootout_over(winner: int) -> void:
	score[winner] += 1
	events.score_changed.emit(score[0], score[1])
	_game_over()


## Puts the current lines back on the ice (after a shootout), everyone else
## on the bench.
func _reset_lines() -> void:
	for s in skaters.duplicate():
		_park(s)
	skaters.clear()
	for b in benches:
		skaters.append_array(b.lineup_bodies(settings.skaters_on_ice))
	human = skaters[0]
	human_on_ice = true
	if career_mode:
		_sync_human()


func _game_over() -> void:
	state = State.OVER
	Engine.time_scale = 1.0
	var text := "TIE GAME"
	if score[0] != score[1]:
		text = "%s WINS" % _palettes[0 if score[0] > score[1] else 1].name
	if overtime and not shootout:
		text += " IN OT"
	if _so:
		text += " IN THE SHOOTOUT %d-%d" % _so.made
	var next := "R or Start > Continue for the career hub" if career_mode else "R to play again"
	hud.show_message("%s\n%s" % [text, next], 9999.0)
	events.game_over.emit(-1 if score[0] == score[1] else (0 if score[0] > score[1] else 1), text)
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
	if _so:
		_so = null
		_reset_lines()
	shootout = false
	box = BoxScore.new()
	clock = settings.period_length()
	hud.show_message("", 0.0)
	_start_faceoff(Vector2.ZERO)


# ---------------------------------------------------------------- practice & menu
# The Esc menu (PauseMenu) drives these.

func _start_practice() -> void:
	state = State.PLAY
	human.place(Vector2(-Rink.BLUE_X, 0.0), Vector3(1, 0, 0))
	practice_reset_puck()


## Puts the puck on your stick side, a stride ahead (practice: R / Start
## menu "Reset puck"). A broken stick gets swapped too.
func practice_reset_puck() -> void:
	_practice_reset = 0.0
	if human.stick_broken:
		StickWear.fresh(human)
		on_new_stick(human)
	var ahead := human.heading if human.heading.length() > 0.1 else Vector3(1, 0, 0)
	var p := human.position + ahead.normalized() * 1.2
	p.x = clampf(p.x, -Rink.GOAL_X + 1.0, Rink.GOAL_X - 1.0)
	p.z = clampf(p.z, -Rink.HALF_W + 1.0, Rink.HALF_W - 1.0)
	puck.reset_at(Vector3(p.x, 0.0, p.z))


func practice_has_goalie() -> bool:
	return not goalies.is_empty()


## Practice only: a goalie in the net you shoot at (+X), or none.
func set_practice_goalie(on: bool) -> void:
	if not practice or on == practice_has_goalie():
		return
	if on:
		var g := Goalie.new()
		g.setup(self, 1, _palettes[1])
		if benches[1].goalie:
			g.skill = benches[1].goalie.skills.goalie_skill()
		add_child(g)
		goalies.append(g)
		g.reset()
	else:
		for g in goalies:
			g.queue_free()
		goalies.clear()


## True once a career game's result has been recorded (game over).
func is_recorded() -> bool:
	return _finished


## Leaving now would throw away a career game in progress.
func leaving_loses_game() -> bool:
	return career_mode and not _finished


## Starts this match (or practice session) over. A career game restarts
## from the faceoff with nothing recorded; once it's over, it can't.
func restart() -> void:
	if practice:
		CareerState.start_practice()
	elif career_mode:
		if not _finished:
			CareerState.play_match(fixture)
	else:
		_new_game()


# ---------------------------------------------------------------- lines & stats

func _update_benches(dt: float) -> void:
	if state != State.PLAY or practice or _so:
		return
	var changed := false
	for b in benches:
		# change on the fly unless the puck is in our end
		var safe: bool = puck.position.x * attack_side(b.team) > -Rink.BLUE_X
		b.tick(dt, team_skaters(b.team), false, safe)
		if _change_lines(b, true):
			changed = true
			events.line_change.emit(b.team, b.on_ice(team_skaters(b.team)))
	if changed and career_mode:
		_sync_human()


## Brings bodies off and on for the lines the bench wants out. At a stoppage
## (`on_fly` false) they swap before the faceoff. On the fly a called skater
## (Skater.changing) heads for the bench's far gate, unless carrying the puck,
## and the fresh one steps out of the centre-ice gate the moment they reach it. Returns true
## when anyone changed.
func _change_lines(b: Bench, on_fly: bool) -> bool:
	var on := team_skaters(b.team)
	var changed := false
	for i in on.size():
		var s: Skater = on[i]
		var want := b.profile_for(i)
		if s.player == want or (on_fly and s == puck.controller):
			s.changing = false
			continue
		var fresh := b.body(want)
		if fresh in skaters:
			continue  # still out in another slot
		if not on_fly:
			_swap_body(s, fresh, false)
			changed = true
			continue
		if not s.changing:
			s.changing = true
			if s == human and human_on_ice and not autoplay:
				hud.show_message("LINE CHANGE\nskate to the bench door", 1.6)
		if Vector2(s.position.x, s.position.z).distance_to(bench_exit(b.team)) < DOOR_REACH:
			_swap_body(s, fresh, true)
			changed = true
	return changed


## `fresh` takes `out`'s place on the ice (and in `skaters`, so slots keep
## their order); `out` goes to stand on the bench. Through the door, the
## fresh skater steps onto the ice already moving.
func _swap_body(out: Skater, fresh: Skater, at_door: bool) -> void:
	skaters[skaters.find(out)] = fresh
	if puck.pass_target == out:
		puck.pass_target = null
	_park(out)
	fresh.changing = false
	fresh.ai_owner = null
	fresh.ai_react = -1.0
	fresh.ai_shoot_timer = 0.0
	if at_door:
		var d := bench_spot(fresh.team)
		fresh.place(d, Vector3(0, 0, 1))
		fresh.vel = Vector3(0, 0, DOOR_EXIT_SPEED)
	if out == human and not career_mode:
		# you take over whoever comes on in your slot
		human = fresh


## A new body for `p` (Bench.make_body), standing on the bench.
func _make_body(p: PlayerProfile, team: int, pal: Dictionary) -> Skater:
	var s := Skater.new()
	s.setup(self, team, p.number, pal)
	add_child(s)
	_park(s, benches[team].bodies.size())
	return s


## Stands a body behind the boards on its team's bench, facing the ice; a
## broken stick is swapped for a new one there (Skater.place).
func _park(s: Skater, seat := -1) -> void:
	if seat < 0:
		seat = benches[s.team].bodies.values().find(s)
	s.changing = false
	var x0: float = BENCH_X[s.team][0]
	var spot := Vector2(x0 + 0.35 + (seat % BENCH_ROW) * 0.66 * signf(BENCH_X[s.team][1] - x0),
		-Rink.HALF_W - 0.95 - floori(seat / float(BENCH_ROW)) * 0.7)
	s.place(spot, Vector3(0, 0, 1))


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
	events.goal.emit(team, scorer, assists)


# ---------------------------------------------------------------- scene

func _build_environment() -> void:
	var env := Look.make("arena")
	env.background_color = Color("24252b")
	env.ambient_light_color = Color(0.86, 0.89, 0.96)
	env.ambient_light_energy = 0.28
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


## The 220 degree arc the stick can reach, drawn on the ice under the player.
func _make_arc() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 44
	for i in steps:
		var pts := []
		for k in [i, i + 1]:
			var a := lerpf(-Skater.ARC_HALF, Skater.ARC_HALF, float(k) / steps)
			for r in [Skater.REACH_MIN, Skater.reach_limit(a)]:
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
