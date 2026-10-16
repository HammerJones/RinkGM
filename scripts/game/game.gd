extends Node3D
## Root of the demo: builds the rink and players, runs the fixed-step
## simulation (skaters -> body contact -> goalies -> puck substeps with stick
## and save checks) and the game rules (faceoffs, goals, whistles, clock).

const SKATERS_PER_TEAM := 3
const GAME_LENGTH := 300.0
const PUCK_SUBSTEPS := 4
const FACEOFF_OFFSETS := [Vector2(-0.95, 0.0), Vector2(-2.0, 4.0), Vector2(-6.5, -2.5)]

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
var clock := GAME_LENGTH
var state := State.FACEOFF
var time := 0.0

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
	_build_environment()
	rink = Rink.new()
	add_child(rink)
	puck = Puck.new()
	add_child(puck)
	puck.goal_scored.connect(_on_goal)
	for team in 2:
		var pal := Models.palette(team)
		_palettes.append(pal)
		for i in SKATERS_PER_TEAM:
			var s := Skater.new()
			s.setup(self, team, i, pal)
			add_child(s)
			skaters.append(s)
		var g := Goalie.new()
		g.setup(self, team, pal)
		add_child(g)
		goalies.append(g)
	human = skaters[0]
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
	if not autoplay:
		controller.update(dt)
	for s in skaters:
		if s != human or autoplay:
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
	_arc.visible = not autoplay
	_arc.transform = Transform3D(human.basis, human.position + Vector3(0, 0.015, 0))
	hud.set_score(_palettes[0].name, _palettes[1].name, score[0], score[1], clock)
	hud.set_stamina(human.stamina)
	hud.set_power(human.windup())


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
			if clock <= 0.0:
				clock = 0.0
				_game_over()
		State.STOPPAGE:
			if _state_timer <= 0.0:
				_start_faceoff(_pending_faceoff)


# ---------------------------------------------------------------- players

func _switch_player(to: Skater = null) -> void:
	if to == null:
		var p := Vector2(puck.position.x, puck.position.z)
		var best_d := INF
		for s in team_skaters(0):
			if s == human:
				continue
			var d := p.distance_to(Vector2(s.position.x, s.position.z))
			if d < best_d:
				best_d = d
				to = s
	if to == null or to == human:
		return
	human.cancel_shot()
	to.cancel_shot()
	human = to


func on_possession(s: Skater) -> void:
	stats.possessions += 1


func on_shot(_s: Skater, _slap: bool) -> void:
	stats.shots += 1


func on_save(g: Goalie, frozen: bool) -> void:
	if state != State.PLAY:
		return
	stats.saves += 1
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
	hud.show_message("%s GOAL!" % _palettes[scorer].name, 2.8)
	state = State.STOPPAGE
	_state_timer = 3.0
	_pending_faceoff = Vector2.ZERO


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
	if autoplay:
		print("autoplay stats: ", stats, " score ", score, " clock ", snappedf(clock, 0.1))


func _game_over() -> void:
	state = State.OVER
	var text := "TIE GAME"
	if score[0] != score[1]:
		text = "%s WINS" % _palettes[0 if score[0] > score[1] else 1].name
	hud.show_message("%s\nR / Start to play again" % text, 9999.0)


func _new_game() -> void:
	score = [0, 0]
	clock = GAME_LENGTH
	hud.show_message("", 0.0)
	_switch_player(skaters[0])
	_start_faceoff(Vector2.ZERO)


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
