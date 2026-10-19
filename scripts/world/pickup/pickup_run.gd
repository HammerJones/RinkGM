class_name PickupRun
extends Node3D
## Pickup basketball in the gym (Sean's playtest notes #32, #33). In peak
## hours (PickupSchedule) a few of the valley's people turn up through the
## gym doors, shoot around until there are enough of them, then run 3 on 3
## on the east half (6 to 9 people) or 5 on 5 full court (10 or more): to 11
## by ones and twos, check ball at the top, take it back past the arc after
## a defensive board, winners stay, shake hands and the next five come on.
##
## The players are real Person records from the Cast, read only: whoever's
## archetype plays rec sports (teens, beer leaguers, broomballers, shift
## workers...) and is free at that hour. They're drawn with PeopleArt's
## meshes in this node's own MultiMeshes, in lights and darks.
##
## The ball is a real RigidBody3D (PickupBall). Dribbles are carried, every
## shot, pass and rebound is free flight against this node's own collision
## layer (floor, gym walls, backboards, rims), so makes and misses come out
## of the physics, nudged by each shooter's touch.
##
## The player can join: walk up during a run and press E ("join next game",
## or straight in when a side is short). On the court the ball dribbles by
## itself; aim with the mouse (where you look) and hold left click for power,
## letting go with the bar in the band for the distance (the same hold-LMB
## power shot as Mechanics' solo PickupGame shootaround); right click passes. Walk off the
## court or press Esc to leave. Playing trains: `trained` fires at the end of
## each game you played and when you leave.
##
##   var g := PickupRun.new()
##   venue.add_child(g)            # venue coordinates, as in gym.gd
##   g.sim = sim                   # or set clock_* and clock_rate yourself
##   g.player_body = walker; g.player_eye = cam
##   # or: PickupRun.attach_to_walk(venue_walk) does all of that plus the HUD
##
## Sound hooks (the lead thread plays them; this node plays nothing):
## bounced (floor, dribbles, walls), squeaked (sneakers), swished, rim_hit,
## backboard_hit.

signal trained(skill_keys: Array, minutes: int, intensity: float)
signal bounced(at: Vector3, strength: float)
signal squeaked(at: Vector3, strength: float)
signal swished(at: Vector3)
signal rim_hit(at: Vector3, strength: float)
signal backboard_hit(at: Vector3, strength: float)
signal scored(team: int, points: int, score: Array)
signal game_started(mode: String)
signal game_over(winner: int, score: Array)
signal run_started(run: Dictionary)
signal run_ended()
signal player_joined(now: bool)
signal player_left()
## A line for the HUD ("CHECK.", "GAME. LIGHTS WIN 11-8").
signal said(text: String)

## The Skills keys pickup trains (Mechanics' canonical keys,
## scripts/career/skills.gd). Sean asked for agility, stamina and accuracy;
## Skills has no stamina, and toughness is what recovers fatigue
## (Progression.rest), so stamina trains toughness.
const TRAINS := ["agility", "toughness", "shot_accuracy"]
const STAMINA_KEY := "toughness"
const TO := 11
const HALF_END := 1          # 3 on 3 runs at the east hoop
## Who plays pickup, by archetype, and how keen they are.
const POOL := {"teen": 1.0, "rink_rat": 0.7, "beer_leaguer": 0.8, "broomballer": 0.9, "shift_worker": 0.75,
	"stick_and_puck_regular": 0.7, "date_night": 0.4, "coach": 0.6, "hockey_parent": 0.25, "learn_to_skate_adult": 0.2}
const AGES := Vector2i(14, 58)
const TEAM_NAMES := ["LIGHTS", "DARKS"]
const TEAM_SHIRTS := [["eeeeea", "d9d4c7"], ["2b2d33", "1d3557"]]
const SHORTS := ["1d1d22", "39424e", "15203f", "5e6a71", "3b5878", "6b1f2a"]

const RUN := 4.4             # m/s flat out, scaled by each player's speed
const JOG := 2.4
const WALK := 1.3
const ACCEL := 11.0
const CATCH_R := 0.72
const REACH := 2.45          # a standing reach; a jump adds JUMP_H
const WINDUP := 0.32         # gather to release
const JUMP_T := 0.6
const JUMP_H := 0.4
const POSS_MAX := 14.0
const POWER_FILL := 1.1      # seconds of holding left click to full power

class Hooper:
	var person: Person
	var look := {}
	var age := 30
	var me := false
	var team := -1
	var state := "arrive"    # arrive, wait, play, leave, gone
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var yaw := 0.0
	var goal := Vector3.ZERO
	var face := Vector3.INF
	var phase := 0.0
	var delay := 0.0
	var shoot := 0.5
	var handle := 0.5
	var speed := 1.0
	var defend := 0.5
	var passing := 0.5
	var will := 0.5
	var spot := 0
	var cut_t := 0.0
	var decide_t := 0.0
	var driving := false
	var shot_t := -1.0
	var jump_t := -1.0
	var squeak_t := 0.0
	var cheer_t := 0.0
	var mark := -1
	var keys := PackedStringArray()
	var scale := 1.0         # PeopleArt.body_scale, cached
	var target := Vector3.ZERO  # _goal(), refreshed a few times a second
	var gait_walk := 1.0     # gait cycles per metre walking / running
	var gait_run := 1.0


var sim: RinkSim
var cast: Cast
var seed := 1
## Without a sim: the clock this node keeps (minutes since midnight, the day,
## the weekday 0 = Sunday) and how fast it runs, in minutes per second.
var clock_day := 0
var clock_weekday := 2
var clock_minute := 17.0 * 60.0
var clock_rate := 0.0
var player_body: Node3D
var player_eye: Node3D
## The player's ratings 0..1 by Skills key (Mechanics can fill it from
## Skills.n); missing keys play as 0.5.
var player_skills := {}
var input_enabled := true
var busy_check := Callable()
var door_check := Callable()

var hoopers: Array = []      # Hooper
var teams := [[], []]        # indices into hoopers
var queue: Array = []        # waiting, in order (indices)
var mode := ""               # "", "shoot" (shooting around), "3v3", "5v5"
var stage := "idle"          # idle, shoot, check, live, pass, shot, loose, dead, inbound, handshake
var run := {}
var score := [0, 0]
var offense := 0
var holder := -1
var cleared := true
var poss_t := 0.0
var stage_t := 0.0
var games_played := 0
var player_idx := -1
var meter := -1.0            # seconds charging, or -1
var last_meter := {}         # {"power", "ideal", "band", "green"} of the last shot
var rng := RandomNumberGenerator.new()

var _ball: PickupBall
var _shot := {}
var _pass_to := -1
var _pass_from := -1
var _check_by := -1
var _ending := false
var _played := {}
var _runs: Array = []
var _runs_day := -1
var _dribble_u := 0.0
var _still_t := 0.0
var _off_t := 0.0
var _train := {}
var _steal_t := 0.0
var _winner := 0
var _mm := {}
var _dirty := true
var _prev_ball := Vector3.ZERO
var _chase: Array = []
var _tick := 0
var _run_t := 0.0


func _ready() -> void:
	_build_court()
	_ball = PickupBall.new()
	add_child(_ball)
	_ball.carry(PickupCourt.CART)
	_ball.hit.connect(_on_ball_hit)


## Wires a game into the venue walk (scripts/venue/venue_walk.gd): the walk's
## sim clock, walker, camera and a HUD. Null when the venue has no gym.
static func attach_to_walk(walk: Node) -> PickupRun:
	var venue: Node3D = walk.get("venue")
	if venue == null or not ("rooms" in venue) or not venue.rooms.has("gym"):
		return null
	var g := PickupRun.new()
	g.name = "Pickup"
	var story: Variant = walk.get("story")
	if story != null:
		g.sim = story.sim
		if story.life != null:
			g.cast = story.life.world.cast
	else:
		g.clock_rate = WalkStory.TIME_SCALE
	g.player_body = walk.get("walker")
	g.player_eye = walk.get("cam")
	if walk.has_method("_busy"):
		g.busy_check = Callable(walk, "_busy")
	var walker: Variant = walk.get("walker")
	# E stays the walk's when a door or a readable spot is in reach
	if walker != null and walker.has_method("nearest_door"):
		g.door_check = func() -> bool:
			return walker.nearest_door(venue) != null or (walk.has_method("_looked_at") and walk._looked_at() != null)
	venue.add_child(g)
	var hud := PickupHud.new()
	hud.game = g
	walk.add_child(hud)
	return g


# ------------------------------------------------------------------ clock

func now_minute() -> int:
	return sim.minute if sim else int(clock_minute)


func now_day() -> int:
	return sim.day if sim else clock_day


func now_weekday() -> int:
	return sim.weekday() if sim else clock_weekday


func _clock_f() -> float:
	return float(sim.day * 1440 + sim.minute) if sim else clock_day * 1440.0 + clock_minute


func _tick_clock(dt: float) -> void:
	if sim or clock_rate <= 0.0:
		return
	clock_minute += clock_rate * dt
	while clock_minute >= 1440.0:
		clock_minute -= 1440.0
		clock_day += 1
		clock_weekday = (clock_weekday + 1) % 7


## Today's runs (PickupSchedule).
func runs_today() -> Array:
	if now_day() != _runs_day:
		_runs_day = now_day()
		_runs = PickupSchedule.sessions(seed, _runs_day, now_weekday())
	return _runs


func is_on() -> bool:
	return not run.is_empty()


# ------------------------------------------------------------------- loop

func _physics_process(dt: float) -> void:
	_tick_clock(dt)
	_update_run()
	if run.is_empty() and hoopers.is_empty():
		return
	stage_t += dt
	_run_t += dt
	_update_player(dt)
	_update_stage(dt)
	_tick += 1
	if _tick % 3 == 0 or stage in ["loose", "inbound"]:
		_chase = _find_chasers()
	for i in hoopers.size():
		_move(i, dt)
	_update_ball(dt)
	_cleanup()


func _process(_dt: float) -> void:
	_draw()


func _update_run() -> void:
	var r := PickupSchedule.at(runs_today(), now_minute())
	if run.is_empty():
		if not r.is_empty() and not _played.has("%d:%d" % [int(r.day), int(r.start)]):
			_open_run(r)
		return
	if not _ending and (now_day() != int(run.day) or now_minute() >= int(run.end)):
		_ending = true
	if _ending:
		var late := (_clock_f() - (int(run.day) * 1440.0 + float(run.end))) > 40.0
		if stage in ["idle", "shoot"] or mode == "shoot" or mode == "" or late:
			_close_run()


func _open_run(r: Dictionary) -> void:
	run = r
	_played["%d:%d" % [int(r.day), int(r.start)]] = true
	_ending = false
	_run_t = 0.0
	rng.seed = int(r.seed)
	score = [0, 0]
	mode = "shoot"
	stage = "shoot"
	stage_t = 0.0
	queue.clear()
	teams = [[], []]
	var who := pick_players(int(r.turnout))
	for k in who.size():
		var h := _make_hooper(who[k])
		var door: Vector3 = PickupCourt.DOORS[rng.randi() % PickupCourt.DOORS.size()]
		h.pos = door + Vector3(rng.randf_range(-0.6, 0.6), 0, -0.7)
		h.delay = 0.0 if k < 2 else rng.randf_range(2.0, 45.0)
		h.state = "arrive"
		hoopers.append(h)
	_dirty = true
	run_started.emit(r)


## Everyone heads home after the last game; the ball goes back on the cart.
func _close_run() -> void:
	if player_idx >= 0:
		say("THAT'S THE LAST GAME. GOOD RUN.")
		leave()
	for h: Hooper in hoopers:
		if not h.me and h.state != "gone":
			h.state = "leave"
			h.team = -1
			h.shot_t = -1.0
			h.jump_t = -1.0
			h.delay = rng.randf_range(0.0, 6.0)
	queue.clear()
	teams = [[], []]
	holder = -1
	mode = ""
	stage = "idle"
	run = {}
	_ending = false
	_ball.carry(PickupCourt.CART)
	run_ended.emit()


## Who turns up for a run: `n` people from the Cast, free at this hour, in
## the age range, weighted by how much their archetype plays rec sports (or
## an interest or a like that says basketball). Read only.
func pick_players(n: int) -> Array:
	if cast == null:
		cast = Cast.load_region(seed)
	var hour := now_minute() / 60.0
	var wd := now_weekday()
	var keyed: Array = []
	for p: Person in cast.people.values():
		if p.age < AGES.x or p.age > AGES.y:
			continue
		var w := float(POOL.get(p.archetype, 0.0))
		w = maxf(w, maxf(p.interest("pickup", "play"), p.interest("basketball", "play")))
		for l in p.likes:
			var s := str(l).to_lower()
			if "basketball" in s or "hoops" in s or "pickup" in s:
				w = maxf(w, 1.0)
		if w <= 0.0 or not p.is_free(wd, hour):
			continue
		keyed.append([pow(rng.randf(), 1.0 / w), p])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var out: Array = []
	for k in mini(n, keyed.size()):
		out.append(keyed[k][1])
	return out


func _make_hooper(p: Person) -> Hooper:
	var h := Hooper.new()
	h.person = p
	h.age = p.age if p else 30
	var r := RandomNumberGenerator.new()
	r.seed = hash((p.id if p else "you") + ":hoops")
	var youth := 1.0 - clampf(absf(h.age - 24.0) / 34.0, 0.0, 1.0)
	var look: Dictionary = p.look.duplicate(true) if p else {}
	var build := str(look.get("build", "average"))
	h.shoot = clampf(r.randf_range(0.15, 0.85) + 0.15 * youth, 0.05, 0.95)
	h.handle = clampf(r.randf_range(0.2, 0.8) + 0.2 * youth, 0.05, 0.95)
	h.defend = clampf(r.randf_range(0.2, 0.8) + 0.15 * youth, 0.05, 0.95)
	h.passing = clampf(r.randf_range(0.2, 0.9), 0.05, 0.95)
	h.speed = lerpf(0.72, 1.06, youth) * (0.92 if build in ["big", "stocky"] else 1.0)
	h.will = clampf(r.randf_range(0.2, 0.8) + (p.trait_value("nerve") - 0.5) * 0.4 if p else 0.5, 0.1, 0.95)
	# gym clothes: their own t-shirt over shorts and sneakers until they pick a side
	look["name"] = p.name if p else "you"
	look["outfit"] = "casual"
	var acc := str(look.get("accessory", "none"))
	look["accessory"] = acc if acc in ["glasses", "ball_cap"] else "none"
	if str(look.get("hair", "short")) == "toque_hair":
		look["hair"] = "short"
	var cols: Array = look.get("colors", ["6d7b8c", "d9d4c7"]).duplicate()
	while cols.size() < 2:
		cols.append("d9d4c7")
	look["own"] = [str(cols[0]), str(cols[1])]
	look["colors"] = [str(cols[0]), str(cols[1]), SHORTS[r.randi() % SHORTS.size()]]
	h.look = look
	h.scale = PeopleArt.body_scale(look, h.age)
	h.gait_walk = PeopleArt.walk_phase_rate(1.0, look, h.age)
	var fast := PeopleArt.RUN_SPEED + 0.5
	h.gait_run = PeopleArt.walk_phase_rate(fast, look, h.age) / fast
	return h


func _hooper(i: int) -> Hooper:
	return hoopers[i] if i >= 0 and i < hoopers.size() else null


func team_size() -> int:
	return 5 if mode == "5v5" else 3


func attack_end(team: int) -> int:
	if mode == "5v5":
		return 1 if team == 0 else -1
	return HALF_END


func _on_court(i: int) -> bool:
	var h := _hooper(i)
	return h != null and h.state == "play" and h.team >= 0


func _set_team(i: int, t: int) -> void:
	var h := _hooper(i)
	h.team = t
	h.state = "play" if t >= 0 else "wait"
	var own: Array = h.look.get("own", ["6d7b8c", "d9d4c7"])
	var shirt: Array = TEAM_SHIRTS[t] if t >= 0 else own
	h.look["colors"] = [shirt[0], shirt[1], h.look.colors[2]]


# ---------------------------------------------------------------- games

## Starts a game from the waiting line when there are enough people.
func _try_start() -> void:
	var ready: Array = []
	for i in queue:
		if _hooper(i).state == "wait":
			ready.append(i)
	var size := 5 if ready.size() >= 10 else (3 if ready.size() >= 6 else 0)
	if size == 0:
		return
	# with more still coming in they shoot around a bit longer for full court
	if size == 3 and _run_t < 75.0:
		for h: Hooper in hoopers:
			if h.state == "arrive" and not h.me:
				return
	mode = "5v5" if size == 5 else "3v3"
	var picks: Array = ready.slice(0, size * 2)
	for i in picks:
		queue.erase(i)
	_snake(picks, size)
	_start_game(rng.randi() % 2)


## Splits `picks` into two even sides, best player first, snake order.
func _snake(picks: Array, size: int) -> void:
	picks.sort_custom(func(a: int, b: int) -> bool: return _rating(a) > _rating(b))
	teams = [[], []]
	for k in picks.size():
		var t := 0 if (k % 4 == 0 or k % 4 == 3) else 1
		if teams[t].size() >= size:
			t = 1 - t
		teams[t].append(picks[k])
	for t in 2:
		for i in teams[t]:
			_set_team(i, t)


func _rating(i: int) -> float:
	var h := _hooper(i)
	if h.me:
		return 0.5 + 0.2 * _skill("shot_accuracy")
	return h.shoot + h.handle + h.defend + h.speed * 0.5


func _start_game(first: int) -> void:
	score = [0, 0]
	_assign_marks()
	for t in 2:
		for k in teams[t].size():
			var h := _hooper(teams[t][k])
			h.spot = k
			h.cut_t = rng.randf_range(1.0, 4.0)
	if player_idx >= 0 and _on_court(player_idx):
		_train_start()
	game_started.emit(mode)
	say("%s ON %s. %s BALL." % [str(teams[0].size()), str(teams[1].size()), TEAM_NAMES[first]])
	_new_possession(first, "check")


func _assign_marks() -> void:
	for t in 2:
		for k in teams[t].size():
			var other: Array = teams[1 - t]
			_hooper(teams[t][k]).mark = other[k] if k < other.size() else -1


## The other side's ball: checked at the top on the half court, taken out
## from under the basket full court.
func _new_possession(team: int, how: String) -> void:
	offense = team
	poss_t = 0.0
	cleared = true
	_shot = {}
	stage_t = 0.0
	var off: Array = teams[team]
	if off.is_empty():
		return
	var pick: int = off[0]
	var best := -1.0
	for i in off:
		var h := _hooper(i)
		var v := h.handle + rng.randf() * 0.4 + (0.3 if h.me else 0.0)
		if v > best:
			best = v
			pick = i
	if how == "check" and mode != "5v5":
		stage = "check"
		# whoever on the other side is nearest the ball picks it up and checks it
		_check_by = -1
		var near := 99.0
		for i in teams[1 - team]:
			var dd := _flat(_hooper(i).pos - _ball.position)
			if dd < near:
				near = dd
				_check_by = i
		holder = _check_by if _check_by >= 0 else pick
		_hooper(pick).decide_t = 9.0
		_pass_to = pick
	else:
		stage = "inbound"
		holder = -1
		_pass_to = pick
		_check_by = -1


func _scored(team: int, pts: int) -> void:
	score[team] += pts
	scored.emit(team, pts, score.duplicate())
	if _shot.has("shooter"):
		var s := _hooper(int(_shot.shooter))
		if s:
			s.cheer_t = 1.2
	stage = "dead"
	stage_t = 0.0
	if score[team] >= TO:
		say("GAME. %s WIN %d-%d." % [TEAM_NAMES[team], score[team], score[1 - team]])
	else:
		say("%s %d   %s %d" % [TEAM_NAMES[0], score[0], TEAM_NAMES[1], score[1]])


func _game_over(winner: int) -> void:
	games_played += 1
	_winner = winner
	stage = "handshake"
	stage_t = 0.0
	holder = -1
	game_over.emit(winner, score.duplicate())
	if player_idx >= 0 and _on_court(player_idx):
		_emit_training()
	for i in teams[winner]:
		_hooper(i).cheer_t = 1.5


## Winners stay; losers go to the back of the line; the next side comes on.
## A side short of people is filled from the losers, so whoever called next
## (the player too) always gets on, and someone sits.
func _rotate() -> void:
	var w := _winner
	var losers: Array = teams[1 - w].duplicate()
	var winners: Array = teams[w].duplicate()
	for i in losers:
		_set_team(i, -1)
		queue.append(i)
	if _ending:
		for i in winners:
			_set_team(i, -1)
			queue.append(i)
		teams = [[], []]
		_close_run()
		return
	var present := winners.size() + queue.size()
	var size := 5 if present >= 10 else (3 if present >= 6 else 0)
	if size == 0:
		for i in winners:
			_set_team(i, -1)
			queue.append(i)
		teams = [[], []]
		mode = "shoot"
		stage = "shoot"
		return
	if size != team_size() or winners.size() != size:
		var all: Array = winners + queue.slice(0, size * 2 - winners.size())
		for i in all:
			queue.erase(i)
		mode = "5v5" if size == 5 else "3v3"
		_snake(all, size)
		_start_game(rng.randi() % 2)
		return
	var challengers: Array = queue.slice(0, size)
	for i in challengers:
		queue.erase(i)
	teams[1 - w] = challengers
	for i in challengers:
		_set_team(i, 1 - w)
	_start_game(1 - w)


# ----------------------------------------------------------------- stages

func _update_stage(dt: float) -> void:
	_steal_t -= dt
	for i in hoopers.size():
		var h: Hooper = hoopers[i]
		if h.state == "arrive" and h.delay <= 0.0 and h.pos.distance_to(_goal(i)) < 0.6:
			h.state = "wait"
			queue.append(i)
	match stage:
		"shoot":
			_shootaround(dt)
			if not _ending:
				_try_start()
		"check":
			if holder < 0:
				stage = "live"
			elif holder == _pass_to:
				stage = "live"
				_hooper(holder).decide_t = rng.randf_range(0.3, 0.7)
			elif stage_t > 1.6 or (_hooper(_pass_to) and _hooper(holder).pos.distance_to(_hooper(_pass_to).pos) < 2.2 and stage_t > 0.9):
				if _hooper(holder).me:
					if stage_t > 2.5:
						_pass(holder, _pass_to)
				else:
					_pass(holder, _pass_to)
					say("CHECK.")
		"live":
			poss_t += dt
			if holder >= 0:
				_run_holder(holder, dt)
		"dead":
			if stage_t > 1.5:
				var t := 0 if score[0] >= TO else (1 if score[1] >= TO else -1)
				if t >= 0:
					_game_over(t)
				else:
					var last := int(_shot.get("team", offense))
					_new_possession(1 - last, "check")
		"handshake":
			if stage_t > 5.0:
				_rotate()
		"loose", "inbound", "pass", "shot":
			poss_t += dt
	_tick_shots(dt)


func _shootaround(dt: float) -> void:
	if holder >= 0:
		var h := _hooper(holder)
		if h.me:
			return
		h.decide_t -= dt
		if h.shot_t < 0.0 and (h.decide_t <= 0.0 or h.pos.distance_to(h.goal) < 0.4):
			_start_shot(holder)


## The ball handler's head: drive, swing it, pull up, or work for a look.
func _run_holder(i: int, dt: float) -> void:
	var h := _hooper(i)
	if h.me or h.shot_t >= 0.0:
		return
	var end := attack_end(h.team)
	var d := PickupCourt.dist_to_rim(end, h.pos)
	if mode == "3v3" and not cleared:
		if d > PickupCourt.THREE + 0.2:
			cleared = true
		else:
			h.goal = PickupCourt.check_spot(end) + Vector3(0, 0, clampf(h.pos.z - PickupCourt.CZ, -3.0, 3.0))
			return
	# under or behind the rim there's no shot: step out to the block first
	var out := (PickupCourt.rim(end).x - h.pos.x) * end
	if d < 1.0 or out < 0.5:
		h.driving = true
		h.goal = PickupCourt.spot(end, 1.4, signf(h.pos.z - PickupCourt.CZ + 0.01) * 0.8)
		return
	if h.driving and d < 1.7:
		_start_shot(i)
		return
	h.decide_t -= dt
	if h.decide_t > 0.0:
		return
	h.decide_t = rng.randf_range(0.35, 0.85)
	var open := _openness(i)
	var p_shot := (0.16 + 0.035 * poss_t) * (0.6 + h.will) * (1.0 if open > 1.4 else 0.35)
	if d > 7.6:
		p_shot *= 0.12
	if poss_t > POSS_MAX:
		p_shot = 1.0 if d < 7.8 else 0.0
	if d < 1.7 or rng.randf() < p_shot:
		_start_shot(i)
		return
	var r := _best_receiver(i)
	if r >= 0 and rng.randf() < 0.45 * (0.6 + h.passing):
		_pass(i, r)
		return
	if (open > 1.1 and rng.randf() < 0.45 * (0.5 + h.handle)) or poss_t > POSS_MAX:
		h.driving = true
		h.goal = PickupCourt.spot(end, 0.9, signf(h.pos.z - PickupCourt.CZ + 0.01) * 0.7)
	else:
		h.driving = false
		var s: Array = PickupCourt.SPOTS[rng.randi() % 7]
		h.goal = PickupCourt.spot(end, float(s[0]), float(s[1]))


## How far the nearest opponent is.
func _openness(i: int) -> float:
	var h := _hooper(i)
	var best := 99.0
	for j in teams[1 - h.team] if h.team >= 0 else []:
		best = minf(best, _flat(_hooper(j).pos - h.pos))
	return best


func _best_receiver(i: int) -> int:
	var h := _hooper(i)
	var best := -1
	var bv := 0.0
	var end := attack_end(h.team)
	for j in teams[h.team]:
		if j == i:
			continue
		var r := _hooper(j)
		var open := _openness(j)
		if open < 1.4:
			continue
		var dist := _flat(r.pos - h.pos)
		if dist > 12.0 or dist < 1.5:
			continue
		var v := open * 0.5 + (8.0 - PickupCourt.dist_to_rim(end, r.pos)) * 0.2 + rng.randf()
		if _lane_blocked(h.pos, r.pos, h.team):
			v -= 2.5
		if r.me:
			v += 0.8
		if v > bv:
			bv = v
			best = j
	return best if bv > 0.4 else -1


func _lane_blocked(a: Vector3, b: Vector3, team: int) -> bool:
	for j in teams[1 - team]:
		var p := _hooper(j).pos
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var ap := Vector2(p.x - a.x, p.z - a.z)
		var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.01), 0.0, 1.0)
		if (ap - ab * t).length() < 0.6 and t > 0.1 and t < 0.9:
			return true
	return false


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _start_shot(i: int) -> void:
	var h := _hooper(i)
	h.shot_t = 0.0
	h.driving = false
	h.jump_t = 0.0 if PickupCourt.dist_to_rim(_shoot_end(h), h.pos) > 1.8 else -1.0


func _shoot_end(h: Hooper) -> int:
	if mode == "shoot" or h.team < 0:
		return HALF_END if h.pos.x > PickupCourt.CX - 4.0 else -1
	return attack_end(h.team)


## Counts down jump shots and jumps; lets the ball go at the top.
func _tick_shots(dt: float) -> void:
	for i in hoopers.size():
		var h: Hooper = hoopers[i]
		h.cheer_t -= dt
		h.squeak_t -= dt
		if h.jump_t >= 0.0:
			h.jump_t += dt
			if h.jump_t > JUMP_T:
				h.jump_t = -1.0
		if h.shot_t >= 0.0:
			h.shot_t += dt
			if h.shot_t >= WINDUP and holder == i:
				_release_npc_shot(i)
			if h.shot_t > WINDUP + 0.35:
				h.shot_t = -1.0


func _jump_y(h: Hooper) -> float:
	return sin(PI * clampf(h.jump_t / JUMP_T, 0.0, 1.0)) * JUMP_H if h.jump_t >= 0.0 else 0.0


func _release_npc_shot(i: int) -> void:
	var h := _hooper(i)
	var end := _shoot_end(h)
	var d := PickupCourt.dist_to_rim(end, h.pos)
	var layup := d < 1.8
	var pts := PickupCourt.points_from(end, h.pos)
	var p := lerpf(0.55, 0.85, h.shoot) if layup else lerpf(0.30, 0.6, h.shoot) * clampf(1.2 - d / 13.0, 0.5, 1.05)
	if pts == 2:
		p *= 0.8
	var open := _openness(i)
	if open < 1.0:
		p *= 0.65
	elif open < 1.6:
		p *= 0.85
	var rim := PickupCourt.rim(end)
	var target := rim
	if rng.randf() < p:
		target += Vector3(rng.randfn(0.0, 0.025), 0, rng.randfn(0.0, 0.025))
	else:
		var a := rng.randf() * TAU
		target += Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.17, 0.32)
	var from := h.pos + Vector3(0, 2.05 * h.scale + _jump_y(h), 0) + _fwd(h.yaw) * 0.25
	_launch_shot(i, from, target, flight_time(from, target, 52.0 if layup else 47.0), pts)


func _launch_shot(i: int, from: Vector3, target: Vector3, t: float, pts: int) -> void:
	var h := _hooper(i)
	var v := _ballistic(from, target, t)
	var end := _shoot_end(h)
	var to_rim := (PickupCourt.rim(end) - from)
	var side := Vector3(to_rim.z, 0, -to_rim.x).normalized()
	_ball.launch(from, v, side * -8.0)  # backspin
	if mode == "3v3" and not cleared and h.team == offense:
		pts = 0  # didn't take it back: doesn't count
	_shot = {"shooter": i, "team": h.team, "points": pts, "end": end, "touched": false, "t": 0.0}
	holder = -1
	if mode != "shoot":
		stage = "shot"
	stage_t = 0.0
	_still_t = 0.0


## How long a shot from `from` takes to drop into `to` at `angle` degrees
## below the horizontal: a real arc, steep enough to clear the front rim.
static func flight_time(from: Vector3, to: Vector3, angle: float) -> float:
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var d := Vector2(to.x - from.x, to.z - from.z).length()
	var h := to.y - from.y
	return sqrt(maxf(2.0 * (h + d * tan(deg_to_rad(angle))) / g, 0.05))


func _ballistic(from: Vector3, to: Vector3, t: float) -> Vector3:
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var v := (to - from) / t
	# the physics step adds its own half step of gravity (semi-implicit Euler)
	var step := Engine.time_scale / float(Engine.physics_ticks_per_second)
	v.y += 0.5 * g * t + 0.5 * g * step
	return v


func _pass(from_i: int, to_i: int) -> void:
	var a := _hooper(from_i)
	var b := _hooper(to_i)
	var from := a.pos + Vector3(0, 1.25, 0) + _fwd(a.yaw) * 0.3
	var dist := _flat(b.pos - a.pos)
	var t := dist / 8.5 + 0.12
	var at := b.pos + b.vel * t * 0.8 + Vector3(0, 1.15, 0)
	at += Vector3(rng.randfn(0.0, 0.25), 0, rng.randfn(0.0, 0.25)) * (1.0 - a.passing)
	_ball.launch(from, _ballistic(from, at, t), Vector3.ZERO)
	holder = -1
	_pass_from = from_i
	_pass_to = to_i
	if stage != "check":
		stage = "pass"
	else:
		stage = "pass"
		_shot = {"check": true}
	stage_t = 0.0
	a.yaw = atan2(-(b.pos.x - a.pos.x), -(b.pos.z - a.pos.z))


## Someone has the ball: the other side's board or steal changes ends.
func _give(i: int, how: String) -> void:
	var h := _hooper(i)
	holder = i
	_still_t = 0.0
	h.goal = h.pos
	h.decide_t = rng.randf_range(0.25, 0.6)
	h.driving = false
	if h.me:
		_train["touches"] = int(_train.get("touches", 0)) + 1
	if mode == "shoot" or h.team < 0:
		stage = "shoot"
		var s: Array = PickupCourt.SPOTS[rng.randi() % PickupCourt.SPOTS.size()]
		h.goal = PickupCourt.spot(HALF_END, maxf(1.5, float(s[0]) * rng.randf_range(0.6, 1.0)), float(s[1]))
		h.decide_t = rng.randf_range(1.5, 4.0)
		return
	var was_check := _shot.has("check")
	if h.team != offense:
		offense = h.team
		poss_t = 0.0
		cleared = mode == "5v5"
		if mode == "3v3" and how in ["rebound", "steal"]:
			say("TAKE IT BACK.")
	elif how == "rebound":
		poss_t = minf(poss_t, 5.0)
	if was_check:
		cleared = true
	_shot = {}
	stage = "live"
	stage_t = 0.0


# ------------------------------------------------------------------- ball

func _update_ball(dt: float) -> void:
	var b := _ball.position
	if holder >= 0:
		_carry(holder, dt)
	else:
		_free_ball(dt, b)
	_prev_ball = _ball.position


func _carry(i: int, dt: float) -> void:
	var h := _hooper(i)
	var fwd := _fwd(h.yaw)
	var right := Vector3(-fwd.z, 0, fwd.x)
	var sc := h.scale if not h.me else 1.0
	if h.me:
		fwd = _aim_flat()
		right = Vector3(-fwd.z, 0, fwd.x)
	if h.shot_t >= 0.0 or (h.me and meter >= 0.0):
		var k := clampf(h.shot_t / WINDUP, 0.0, 1.0) if not h.me else 1.0
		_hold(h.pos + fwd * 0.28 + Vector3(0, lerpf(1.1, 2.05, k) * sc + _jump_y(h), 0))
		return
	if stage == "check" and i == _check_by:
		_hold(h.pos + fwd * 0.3 + Vector3(0, 1.1 * sc, 0))
		return
	var speed := _flat(h.vel)
	var rate := 1.6 + clampf(speed / RUN, 0.0, 1.0) * 0.8
	var u0 := _dribble_u
	_dribble_u = fmod(_dribble_u + dt * rate, 1.0)
	if u0 < 0.5 and _dribble_u >= 0.5:
		bounced.emit(h.pos + right * 0.32 + fwd * 0.38, 0.35 + 0.2 * clampf(speed / RUN, 0.0, 1.0))
	var s := absf(2.0 * _dribble_u - 1.0)
	var hand := (0.82 if not h.me else 1.0) * sc
	var y := PickupBall.RADIUS + (hand - PickupBall.RADIUS) * (1.0 - (1.0 - s) * (1.0 - s))
	var out := 0.3 + 0.08 * clampf(speed / RUN, 0.0, 1.0)
	if h.me:
		out = 0.85  # out in front, so a first-person view sees the top of each bounce
	_hold(h.pos + right * (0.3 if not h.me else 0.28) + fwd * out + Vector3(0, y, 0))
	_ball.spin_with(h.vel, dt)


## The ball in a hand, never through the gym wall.
func _hold(at: Vector3) -> void:
	_ball.carry(PickupCourt.clamp_in_room(at, PickupBall.RADIUS + 0.02))


func _free_ball(dt: float, b: Vector3) -> void:
	var v := _ball.linear_velocity
	# made it? down through a ring
	for end in [-1, 1]:
		var rim := PickupCourt.rim(end)
		if _prev_ball.y >= rim.y and b.y < rim.y and v.y < 0.0 and Vector2(b.x - rim.x, b.z - rim.z).length() < PickupCourt.RIM_R - 0.05:
			_made(end, rim)
		# the net takes the pace off it
		if Vector2(b.x - rim.x, b.z - rim.z).length() < PickupCourt.RIM_R and b.y < rim.y and b.y > rim.y - 0.45:
			_ball.linear_velocity = Vector3(v.x * 0.85, v.y * 0.97, v.z * 0.85)
	if not _shot.is_empty() and not _shot.has("check"):
		_shot.t = float(_shot.t) + dt
		if stage == "shot" and (bool(_shot.touched) or b.y < PickupCourt.RIM_Y - 0.6 or float(_shot.t) > 3.0):
			stage = "loose"
			stage_t = 0.0
	if stage == "pass" and stage_t > 2.2:
		stage = "loose"
	# off the top of the board or sat on the rim: someone knocks it down
	if v.length() < 0.15 and b.y > 2.0:
		_still_t += dt
		if _still_t > 1.0:
			_ball.launch(b + Vector3(0, 0.05, 0), Vector3(rng.randf_range(-1, 1), -0.5, rng.randf_range(-1, 1)))
			_still_t = 0.0
	else:
		_still_t = 0.0
	if not PickupCourt.in_room(b, -0.3):
		_ball.launch(Vector3(PickupCourt.CX, 1.0, PickupCourt.CZ), Vector3.ZERO)
	if stage in ["loose", "pass", "inbound", "shoot"] or (mode == "shoot" and holder < 0):
		_try_catch(b)


func _made(end: int, rim: Vector3) -> void:
	var touched := bool(_shot.get("touched", false))
	if not touched:
		swished.emit(rim)
	if mode == "shoot" or _shot.is_empty() or _shot.has("check"):
		stage = "shoot" if mode == "shoot" else stage
		return
	if int(_shot.get("end", end)) != end:
		return
	var pts := int(_shot.get("points", 1))
	var team := int(_shot.get("team", -1))
	if team < 0:
		return
	if pts == 0:
		say("DOESN'T COUNT. TAKE IT BACK.")
		stage = "loose"
		return
	if _hooper(int(_shot.shooter)) and _hooper(int(_shot.shooter)).me:
		_train["makes"] = int(_train.get("makes", 0)) + 1
	_scored(team, pts)


func _try_catch(b: Vector3) -> void:
	if b.y > REACH + JUMP_H + 0.2:
		return
	var best := -1
	var bd := 99.0
	for i in hoopers.size():
		var h: Hooper = hoopers[i]
		if h.delay > 0.0 or h.state == "leave" or h.state == "gone" or h.state == "arrive":
			continue
		if mode == "shoot" or stage == "shoot":
			if h.state != "wait" and h.state != "play":
				continue
		elif not _on_court(i):
			continue
		if stage == "inbound" and h.team != offense:
			continue
		if stage == "pass" and i == _pass_from and stage_t < 0.35:
			continue
		# a shot on its way up is nobody's yet
		if _shot.has("shooter") and not bool(_shot.touched) and float(_shot.t) < 0.6:
			continue
		var d := _flat(h.pos - b)
		var r := CATCH_R
		if h.me:
			r = 1.1 if stage == "pass" and i == _pass_to else 0.95
		elif stage == "pass" and i != _pass_to:
			if h.team == _hooper(_pass_from).team:
				continue
			r = 0.45 * (0.6 + h.defend)
		var reach := REACH * (h.scale if not h.me else 1.0) + _jump_y(h)
		if d < r and b.y < reach and d < bd:
			best = i
			bd = d
		# go up for it
		if not h.me and d < 1.2 and b.y > 2.0 and b.y < 3.2 and h.jump_t < 0.0 and _ball.linear_velocity.y < 0.5:
			h.jump_t = 0.0
	if best < 0:
		return
	var how := "rebound"
	if stage == "pass":
		how = "pass" if best == _pass_to or _hooper(best).team == _hooper(_pass_from).team else "steal"
	elif stage == "inbound":
		how = "inbound"
	_give(best, how)


func _on_ball_hit(kind: String, at: Vector3, s: float) -> void:
	var local := to_local(at)
	match kind:
		"rim":
			rim_hit.emit(local, s)
			if not _shot.is_empty():
				_shot.touched = true
		"board":
			backboard_hit.emit(local, s)
			if not _shot.is_empty():
				_shot.touched = true
		_:
			bounced.emit(local, s)
			if kind == "floor" and stage == "shot":
				_shot.touched = true


# --------------------------------------------------------------- movement

func _fwd(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func _bench_spot(k: int) -> Vector3:
	k = maxi(k, 0)
	if mode == "5v5":
		return Vector3(PickupCourt.CX - 5.0 + (k % 12) * 0.9, 0, PickupCourt.BENCH_Z)
	return Vector3(PickupCourt.CX - 2.5 - (k % 10) * 0.9, 0, PickupCourt.BENCH_Z)


## Where hooper `i` wants to be right now, and (in face) what to look at.
func _goal(i: int) -> Vector3:
	var h: Hooper = hoopers[i]
	h.face = Vector3.INF
	match h.state:
		"arrive":
			var a := _bench_spot(queue.size() + i % 4)
			h.face = a + Vector3(0, 0, 3.0)
			return a
		"wait":
			var k := queue.find(i)
			var s := _bench_spot(k if k >= 0 else queue.size() + i % 4)
			if mode == "shoot" or stage == "shoot":
				return _shootaround_goal(i, s)
			h.face = s + Vector3(0, 0, 3.0)
			return s
		"leave":
			return _nearest_door(h.pos)
	# on the court
	if stage == "handshake":
		# pair up across the line at the top of the key and shake hands
		var t := h.team
		var k: int = teams[t].find(i)
		var line := Vector3(PickupCourt.CX + 3.0 + k * 1.2, 0, PickupCourt.CZ + (-0.4 if t == 0 else 0.4))
		h.face = line + Vector3(0, 0, 1.0 if t == 0 else -1.0)
		return line
	var end := attack_end(h.team)
	var off := h.team == offense
	if i == holder:
		h.face = PickupCourt.rim(end)
		if stage == "check" and i == _check_by:
			var m := _hooper(_pass_to)
			if m:
				h.face = m.pos
			var cs := PickupCourt.check_spot(attack_end(offense))
			return cs + _toward_rim(attack_end(offense), cs) * 1.2
		return h.goal
	var ball := _ball.position
	if stage == "loose" or (stage == "inbound" and off):
		if _chasers().has(i):
			h.face = ball
			var lead := _ball.linear_velocity * 0.25
			return Vector3(ball.x + lead.x, 0, ball.z + lead.z)
	if off:
		if stage == "check" and i == _pass_to:
			h.face = PickupCourt.rim(end)
			return PickupCourt.check_spot(end)
		if stage == "shot" and h.spot % 3 == 0:
			return PickupCourt.spot(end, 1.6, 1.0 if h.spot % 2 == 0 else -1.0)
		var s: Array = PickupCourt.SPOTS[h.spot % PickupCourt.SPOTS.size()]
		h.face = ball
		return PickupCourt.spot(end, float(s[0]), float(s[1]))
	# defence: between your man and the rim
	var dend := attack_end(offense)
	var man := _hooper(h.mark)
	if man == null or not _on_court(h.mark):
		man = _hooper(holder) if holder >= 0 else null
	if man == null:
		return PickupCourt.spot(dend, 2.5, 0.0)
	h.face = man.pos
	if stage == "shot":
		return man.pos.lerp(PickupCourt.spot(dend, 0.0, 0.0), 0.35)
	var gap := 1.0 if h.mark == holder else 1.8
	var to_rim := _toward_rim(dend, man.pos)
	var g := man.pos + to_rim * gap
	if holder >= 0 and h.mark != holder:
		g = g.lerp(_hooper(holder).pos, 0.15)  # sag toward the ball
	return g


func _toward_rim(end: int, p: Vector3) -> Vector3:
	var r := PickupCourt.rim(end)
	var d := Vector3(r.x - p.x, 0, r.z - p.z)
	return d.normalized() if d.length() > 0.01 else Vector3.ZERO


func _shootaround_goal(i: int, bench: Vector3) -> Vector3:
	var h: Hooper = hoopers[i]
	if i == holder:
		h.face = PickupCourt.rim(HALF_END)
		return h.goal
	if holder < 0 and _chasers().has(i):
		h.face = _ball.position
		return Vector3(_ball.position.x, 0, _ball.position.z)
	# the rest stand round the arc waiting for a rebound
	var k := queue.find(i)
	var a := -1.2 + (k % 6) * 0.48
	var p := PickupCourt.spot(HALF_END, 4.5 + (k % 3) * 0.8, 0.0)
	p.z = PickupCourt.CZ + sin(a) * 4.5
	p.x = PickupCourt.rim(HALF_END).x - cos(a) * 4.8
	h.face = PickupCourt.rim(HALF_END)
	return p if stage_t > 2.0 or k >= 0 else bench


func _chasers() -> Array:
	return _chase


## The two or three nearest the loose ball go after it.
func _find_chasers() -> Array:
	var b := _ball.position
	var c: Array = []
	for i in hoopers.size():
		var h: Hooper = hoopers[i]
		if h.me or h.delay > 0.0:
			continue
		var ok := (_on_court(i) and (stage != "inbound" or h.team == offense)) or ((mode == "shoot" or stage == "shoot") and h.state == "wait")
		if ok:
			c.append([_flat(h.pos - b), i])
	c.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var out: Array = []
	for k in mini(3 if stage == "loose" else 1, c.size()):
		out.append(c[k][1])
	return out


func _nearest_door(p: Vector3) -> Vector3:
	var best: Vector3 = PickupCourt.DOORS[0]
	for d: Vector3 in PickupCourt.DOORS:
		if d.distance_to(p) < best.distance_to(p):
			best = d
	return best + Vector3(0, 0, -0.3)


func _move(i: int, dt: float) -> void:
	var h: Hooper = hoopers[i]
	if h.me or h.state == "gone":
		return
	if h.delay > 0.0:
		h.delay -= dt
		return
	# where to go, thought over about 40 times a second (staggered)
	if (_tick + i) % 3 == 0 or h.target == Vector3.ZERO:
		h.target = _goal(i)
	var g := h.target
	if h.state == "leave" and _flat(g - h.pos) < 0.5:
		h.state = "gone"
		_dirty = true
		return
	var to := Vector3(g.x - h.pos.x, 0, g.z - h.pos.z)
	var playing := h.state == "play" and stage in ["live", "pass", "shot", "loose", "inbound", "check"]
	var top := WALK
	if playing:
		top = RUN * h.speed if stage in ["loose", "inbound", "pass"] or i == holder or to.length() > 2.5 else JOG * h.speed
	elif mode == "shoot" or stage == "shoot":
		top = JOG * h.speed
	var want := Vector3.ZERO
	if to.length() > 0.08 and h.shot_t < 0.0:
		want = to.normalized() * minf(top, to.length() * 3.0)
	# don't stand inside each other
	for j in hoopers.size():
		if j == i:
			continue
		var o: Hooper = hoopers[j]
		if o.state == "gone" or o.delay > 0.0:
			continue
		var d := Vector3(h.pos.x - o.pos.x, 0, h.pos.z - o.pos.z)
		var l := d.length()
		if l < 0.6 and l > 0.001:
			want += d / l * (0.6 - l) * 6.0
	var prev := h.vel
	h.vel = h.vel.move_toward(want, ACCEL * dt)
	h.pos += h.vel * dt
	h.pos = PickupCourt.clamp_in_room(h.pos)
	h.pos.y = 0.0
	var acc := (h.vel - prev).length() / maxf(dt, 0.0001)
	var speed := _flat(h.vel)
	if playing and h.squeak_t <= 0.0 and speed > 1.8 and acc > ACCEL * 0.8 and prev.normalized().dot(want.normalized()) < 0.4:
		squeaked.emit(h.pos, clampf(speed / RUN, 0.2, 1.0))
		h.squeak_t = rng.randf_range(1.0, 2.6)
	if speed > 0.5 and (h.face == Vector3.INF or speed > 2.6):
		h.yaw = lerp_angle(h.yaw, atan2(-h.vel.x, -h.vel.z), clampf(dt * 10.0, 0.0, 1.0))
	elif h.face != Vector3.INF:
		h.yaw = lerp_angle(h.yaw, atan2(-(h.face.x - h.pos.x), -(h.face.z - h.pos.z)), clampf(dt * 6.0, 0.0, 1.0))
	h.phase = fmod(h.phase + dt * speed * (h.gait_run if speed > PeopleArt.RUN_SPEED else h.gait_walk), 1.0)
	# off-ball cuts
	if playing and h.team == offense and i != holder:
		h.cut_t -= dt
		if h.cut_t <= 0.0:
			h.cut_t = rng.randf_range(2.0, 5.0)
			h.spot = _free_spot(h.team, h.spot)


func _free_spot(team: int, cur: int) -> int:
	var taken := {}
	for j in teams[team]:
		taken[_hooper(j).spot % PickupCourt.SPOTS.size()] = true
	for t in 8:
		var s := rng.randi() % PickupCourt.SPOTS.size()
		if not taken.has(s):
			return s
	return cur


func _cleanup() -> void:
	if not run.is_empty():
		return
	var any := false
	for h: Hooper in hoopers:
		if h.state != "gone":
			any = true
	if not any:
		hoopers.clear()
		player_idx = -1
		_dirty = true


# ----------------------------------------------------------------- player

## "now", "next" or "" (nothing to join, or already on).
func can_join() -> String:
	if run.is_empty() or _ending or player_idx >= 0 or player_body == null:
		return ""
	var p := _player_pos()
	if not PickupCourt.in_room(p, 0.2) or not PickupCourt.on_court(p, 2.0):
		return ""
	if mode == "shoot" or stage == "shoot":
		return "now"
	if stage == "handshake":
		return "next"
	for t in 2:
		if teams[t].size() < team_size():
			return "now"
	return "next"


## The player joins: onto a short side now, else first in line for the next
## game (they called next).
func join() -> bool:
	var how := can_join()
	if how == "":
		return false
	var h := _make_hooper(null)
	h.me = true
	h.pos = _player_pos()
	h.state = "wait"
	h.delay = 0.0
	hoopers.append(h)
	player_idx = hoopers.size() - 1
	_train = {}
	var placed := false
	if how == "now" and mode in ["3v3", "5v5"] and stage != "handshake":
		for t in 2:
			if not placed and teams[t].size() < team_size():
				teams[t].append(player_idx)
				_set_team(player_idx, t)
				_assign_marks()
				placed = true
				_train_start()
				say("YOU'RE IN. %s." % TEAM_NAMES[t])
	if not placed:
		queue.insert(0, player_idx)
		if how == "now":
			say("SHOOT AROUND. YOU'RE IN THE NEXT GAME.")
		else:
			say("YOU'VE GOT NEXT.")
	player_joined.emit(how == "now")
	_dirty = true
	return true


func leave() -> void:
	if player_idx < 0:
		return
	var i := player_idx
	var h := _hooper(i)
	if holder == i:
		_ball.launch(_ball.position, Vector3(0, -0.5, 0))
		holder = -1
		if stage in ["live", "check"]:
			stage = "loose"
	if _on_court(i):
		_emit_training()
		var t := h.team
		teams[t].erase(i)
		# someone from the line takes your spot
		for k in queue.size():
			var j: int = queue[k]
			if j != i and _hooper(j).state == "wait":
				queue.remove_at(k)
				teams[t].append(j)
				_set_team(j, t)
				break
		_assign_marks()
	queue.erase(i)
	h.state = "gone"
	h.team = -1
	player_idx = -1
	meter = -1.0
	player_left.emit()
	say("YOU'RE OUT.")
	_dirty = true


func is_playing() -> bool:
	return player_idx >= 0 and _on_court(player_idx)


func player_has_ball() -> bool:
	return player_idx >= 0 and holder == player_idx


func _player_pos() -> Vector3:
	if player_body == null:
		return Vector3.INF
	var p := to_local(player_body.global_position)
	return Vector3(p.x, 0.0, p.z)


## Where the player is looking, flat, in venue coordinates.
func _aim_flat() -> Vector3:
	var f := _aim_dir()
	var flat := Vector3(f.x, 0, f.z)
	return flat.normalized() if flat.length() > 0.01 else Vector3(1, 0, 0)


func _aim_dir() -> Vector3:
	var n: Node3D = player_eye if player_eye else player_body
	if n == null:
		return Vector3(1, 0, 0)
	return (global_transform.basis.inverse() * -n.global_transform.basis.z).normalized()


func _skill(key: String) -> float:
	return clampf(float(player_skills.get(key, 0.5)), 0.0, 1.0)


func _update_player(dt: float) -> void:
	if player_idx < 0:
		return
	var h := _hooper(player_idx)
	var p := _player_pos()
	if p == Vector3.INF:
		return
	var moved := _flat(p - h.pos)
	h.vel = (p - h.pos) / maxf(dt, 0.0001)
	h.pos = p
	h.yaw = atan2(-_aim_flat().x, -_aim_flat().z)
	if meter >= 0.0:
		meter += dt
	if _on_court(player_idx):
		_train["dist"] = float(_train.get("dist", 0.0)) + minf(moved, 0.2)
		_train["secs"] = float(_train.get("secs", 0.0)) + dt
		var half := HALF_END if mode == "3v3" else 0
		if not PickupCourt.on_court(p, 1.5, half) and stage not in ["handshake", "dead"]:
			_off_t += dt
			if _off_t > 2.5:
				leave()
		else:
			_off_t = 0.0
	elif h.state == "wait" and not PickupCourt.in_room(p, 0.0):
		leave()  # walked out of the gym while waiting


## Shot power 0..1: it builds while left click is held.
func meter_value() -> float:
	if meter < 0.0:
		return 0.0
	return clampf(meter / POWER_FILL, 0.0, 1.0)


## The right power for a shot from here: [centre, half width].
func meter_band() -> Vector2:
	if player_idx < 0:
		return Vector2(0.7, 0.08)
	var h := _hooper(player_idx)
	var d := PickupCourt.dist_to_rim(_shoot_end(h), h.pos)
	return Vector2(clampf(0.45 + d * 0.06, 0.5, 0.95), lerpf(0.045, 0.11, _skill("shot_accuracy")))


## Left click down: start building power with the ball, or reach for a steal.
func shoot_press() -> void:
	if player_idx < 0:
		return
	if holder == player_idx:
		if stage == "check":
			_pass(player_idx, _pass_to)
		else:
			meter = 0.0
		return
	var h := _hooper(player_idx)
	if holder >= 0 and _steal_t <= 0.0 and _hooper(holder).team != h.team and _flat(_hooper(holder).pos - h.pos) < 1.4:
		_steal_t = 0.8
		if rng.randf() < 0.18 + 0.3 * _skill("agility"):
			var from := _hooper(holder).pos + Vector3(0, 0.6, 0)
			_ball.launch(from, (h.pos - from).normalized() * 2.0 + Vector3(0, 1.5, 0))
			holder = -1
			stage = "loose"
			_shot = {}
			say("POKED IT LOOSE.")


## Left click up: let the shot go with the power built so far.
func shoot_release() -> void:
	if meter < 0.0 or holder != player_idx:
		meter = -1.0
		return
	var power := meter_value()
	meter = -1.0
	player_shot(power)


## The player's shot with `power` 0..1 (how long they held) and the aim
## from where they look: off the line by however far the look is off the
## rim, long or short by how far the power is off the band.
func player_shot(power: float) -> void:
	var h := _hooper(player_idx)
	if h == null or holder != player_idx:
		return
	var end := _shoot_end(h)
	var rim := PickupCourt.rim(end)
	var d := PickupCourt.dist_to_rim(end, h.pos)
	var band := meter_band()
	var miss := power - band.x
	var green := absf(miss) <= band.y
	var aim := _aim_flat()
	var to := Vector3(rim.x - h.pos.x, 0, rim.z - h.pos.z).normalized()
	var acc := _skill("shot_accuracy")
	var target := h.pos + aim * d
	target.y = rim.y
	if green:
		target = rim.lerp(target, 0.35)
		miss = 0.0
	target += to * miss * d * 0.55
	var noise := lerpf(0.11, 0.03, acc) * (0.5 if green else 1.0)
	target += Vector3(rng.randfn(0.0, noise), 0, rng.randfn(0.0, noise))
	var from := h.pos + Vector3(0, 2.0, 0) + aim * 0.3
	last_meter = {"power": power, "ideal": band.x, "band": band.y, "green": green}
	_train["shots"] = int(_train.get("shots", 0)) + 1
	_launch_shot(player_idx, from, target, flight_time(from, target, 52.0 if d < 1.8 else 47.0), PickupCourt.points_from(end, h.pos))


## Right click: pass to the teammate nearest where you're looking.
func pass_press() -> void:
	if holder != player_idx or player_idx < 0:
		return
	if stage == "check":
		_pass(player_idx, _pass_to)
		return
	var h := _hooper(player_idx)
	var aim := _aim_flat()
	var best := -1
	var bv := -2.0
	for j in teams[h.team] if h.team >= 0 else []:
		if j == player_idx:
			continue
		var to := _hooper(j).pos - h.pos
		var v := aim.dot(Vector3(to.x, 0, to.z).normalized()) - _flat(to) * 0.02
		if v > bv:
			bv = v
			best = j
	if best >= 0:
		meter = -1.0
		_pass(player_idx, best)


func _train_start() -> void:
	_train = {"start": _clock_f(), "dist": 0.0, "secs": 0.0, "touches": 0, "shots": 0, "makes": 0}


## The player's work since the last report: minutes on the session clock
## (at least one) and how hard it was, from how much they ran and how
## involved they were.
func _emit_training() -> void:
	var secs := float(_train.get("secs", 0.0))
	if secs < 15.0:
		_train_start()
		return
	var mins := _clock_f() - float(_train.get("start", _clock_f()))
	if mins <= 0.0:
		mins = secs / 60.0
	var run_rate := float(_train.get("dist", 0.0)) / maxf(secs, 1.0)
	var involved := int(_train.get("touches", 0)) * 0.03 + int(_train.get("shots", 0)) * 0.04
	var intensity := clampf(0.3 + 0.5 * clampf(run_rate / 2.5, 0.0, 1.0) + involved, 0.0, 1.0)
	trained.emit(TRAINS.duplicate(), maxi(1, roundi(mins)), intensity)
	_train_start()


func say(text: String) -> void:
	said.emit(text)


## The line the HUD shows near the crosshair, or "".
func prompt() -> String:
	var j := can_join()
	if j == "now":
		return "[E] JOIN THE GAME" if mode in ["3v3", "5v5"] else "[E] SHOOT AROUND (NEXT GAME)"
	if j == "next":
		return "[E] JOIN NEXT GAME"
	if player_has_ball():
		return "[LMB] HOLD TO SHOOT   [RMB] PASS   [ESC] LEAVE"
	if is_playing():
		return "[LMB] STEAL   [ESC] LEAVE"
	if player_idx >= 0:
		return "WAITING FOR NEXT   [ESC] LEAVE"
	return ""


func score_text() -> String:
	if mode in ["3v3", "5v5"]:
		return "PICKUP %s   %s %d - %d %s   TO %d" % [mode.replace("v", " ON "), TEAM_NAMES[0], score[0], score[1], TEAM_NAMES[1], TO]
	if mode == "shoot":
		return "PICKUP: SHOOTING AROUND (%d HERE)" % queue.size()
	return ""


func _unhandled_input(e: InputEvent) -> void:
	if not input_enabled or run.is_empty() and player_idx < 0:
		return
	if busy_check.is_valid() and busy_check.call():
		return
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_E and can_join() != "" and not (door_check.is_valid() and door_check.call()):
			join()
			get_viewport().set_input_as_handled()
		elif e.keycode == KEY_ESCAPE and player_idx >= 0:
			leave()
			get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton and player_idx >= 0:
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				shoot_press()
			else:
				shoot_release()
			get_viewport().set_input_as_handled()
		elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
			pass_press()
			get_viewport().set_input_as_handled()
	elif e is InputEventJoypadButton:
		if e.button_index == JOY_BUTTON_A and e.pressed and can_join() != "":
			join()
			get_viewport().set_input_as_handled()
		elif player_idx >= 0 and e.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			if e.pressed:
				shoot_press()
			else:
				shoot_release()
			get_viewport().set_input_as_handled()
		elif player_idx >= 0 and e.button_index == JOY_BUTTON_LEFT_SHOULDER and e.pressed:
			pass_press()
			get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ court

## This node's own collision for the ball: the gym's floor, walls and
## ceiling, both backboards and both rims (a ring of small spheres), on
## PickupBall.LAYER only.
func _build_court() -> void:
	var r := PickupCourt.ROOM
	var cx := r.position.x + r.size.x * 0.5
	var cz := r.position.y + r.size.y * 0.5
	_static("floor", [[Vector3(r.size.x + 2.0, 0.4, r.size.y + 2.0), Vector3(cx, -0.2, cz)]])
	var h := PickupCourt.ROOM_H
	_static("wall", [
		[Vector3(0.4, h, r.size.y + 2.0), Vector3(r.position.x - 0.2, h * 0.5, cz)],
		[Vector3(0.4, h, r.size.y + 2.0), Vector3(r.end.x + 0.2, h * 0.5, cz)],
		[Vector3(r.size.x + 2.0, h, 0.4), Vector3(cx, h * 0.5, r.position.y - 0.2)],
		[Vector3(r.size.x + 2.0, h, 0.4), Vector3(cx, h * 0.5, r.end.y + 0.2)],
		[Vector3(r.size.x + 2.0, 0.4, r.size.y + 2.0), Vector3(cx, h + 0.2, cz)],
	])
	for end in [-1, 1]:
		var by := PickupCourt.BOARD_Y
		_static("board", [[Vector3(0.06, by.y - by.x, PickupCourt.BOARD_HALF * 2.0),
			Vector3(PickupCourt.board_x(end), (by.x + by.y) * 0.5, PickupCourt.CZ)]])
		var rim := PickupCourt.rim(end)
		var body := _static("rim", [])
		for k in 18:
			var a := TAU * k / 18.0
			var cs := CollisionShape3D.new()
			var s := SphereShape3D.new()
			s.radius = 0.02
			cs.shape = s
			cs.position = rim + Vector3(cos(a), 0, sin(a)) * (PickupCourt.RIM_R + 0.005)
			body.add_child(cs)


func _static(kind: String, boxes: Array) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = "Court_" + kind
	b.collision_layer = PickupBall.LAYER
	b.collision_mask = 0
	b.set_meta("court", kind)
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.55 if kind == "rim" else (0.5 if kind == "board" else 0.6)
	pm.friction = 0.6
	b.physics_material_override = pm
	for bx: Array in boxes:
		var cs := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = bx[0]
		cs.shape = s
		cs.position = bx[1]
		b.add_child(cs)
	add_child(b)
	return b


# ------------------------------------------------------------------- draw

func _pose(i: int) -> int:
	var h: Hooper = hoopers[i]
	var speed := _flat(h.vel)
	if h.shot_t >= 0.0 or h.jump_t >= 0.0 or h.cheer_t > 0.0:
		return PeopleArt.Pose.CHEER
	if stage == "handshake" and h.state == "play":
		return PeopleArt.Pose.TALK
	if h.state == "play" and h.team >= 0 and h.team != offense and speed < 1.4 and stage in ["live", "check", "pass"]:
		return PeopleArt.Pose.WORK  # down in a stance, hands active
	if speed > 0.25:
		return PeopleArt.Pose.WALK
	if h.state == "wait" and stage == "dead":
		return PeopleArt.Pose.CLAP
	return PeopleArt.Pose.STAND


func _draw() -> void:
	if _dirty:
		_rebuild()
	var filled := {}
	for i in hoopers.size():
		var h: Hooper = hoopers[i]
		if h.keys.is_empty():
			continue
		var speed := _flat(h.vel)
		var moving := speed > 0.25
		var pose := _pose(i)
		var xf := Transform3D(Basis(Vector3.UP, h.yaw), h.pos + Vector3(0, _jump_y(h), 0))
		if h.delay > 0.0:
			xf = Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(0, -50, 0))
		var data := PeopleArt.instance_data(h.look, pose, h.phase, h.age, moving and pose != PeopleArt.Pose.CHEER, speed)
		for key in h.keys:
			var mm: MultiMesh = _mm[key].multimesh
			var k := int(filled.get(key, 0))
			filled[key] = k + 1
			mm.set_instance_transform(k, xf)
			mm.set_instance_custom_data(k, data)


func _rebuild() -> void:
	_dirty = false
	var counts := {}
	for h: Hooper in hoopers:
		h.keys = PackedStringArray()
		if h.me or h.state == "gone":
			continue
		h.keys = PeopleArt.layer_keys(h.look, h.age)
		for key in h.keys:
			counts[key] = int(counts.get(key, 0)) + 1
	for key in _mm.keys():
		if not counts.has(key):
			_mm[key].queue_free()
			_mm.erase(key)
	for key in counts:
		if not _mm.has(key):
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Hoopers_" + str(key).validate_node_name()
			mmi.multimesh = PeopleArt.multimesh(key, counts[key])
			add_child(mmi)
			_mm[key] = mmi
		var m: MultiMesh = _mm[key].multimesh
		if m.instance_count != counts[key]:
			m.instance_count = counts[key]


func ball() -> PickupBall:
	return _ball


## Playtests and screenshots: opens the day's next run now, with everyone
## already in the gym.
func start_now() -> void:
	if run.is_empty():
		var runs := runs_today()
		var r: Dictionary = runs[0] if not runs.is_empty() else {}
		for x: Dictionary in runs:
			if int(x.end) > now_minute():
				r = x
				break
		if r.is_empty():
			return
		clock_minute = float(r.start) + 1.0
		if sim:
			sim.minute = int(r.start) + 1
		_open_run(r)
	for i in hoopers.size():
		var h: Hooper = hoopers[i]
		if h.state == "arrive":
			h.delay = 0.0
			h.pos = _bench_spot(queue.size())
			h.state = "wait"
			queue.append(i)
	_run_t = 999.0


## Playtests and screenshots: the player gets the ball (on the court).
func hand_ball_to_player() -> void:
	if is_playing() and stage not in ["handshake", "dead"]:
		if offense != _hooper(player_idx).team:
			offense = _hooper(player_idx).team
		cleared = true
		_give(player_idx, "pass")
