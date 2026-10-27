class_name OnIcePublicSkate
extends OnIceSession
## Public skate (docs/world/ON_ICE.md 2): as many people as SkateDemand says
## the day, the hour, the season, the weather and the price bring, going
## round counter-clockwise. Wobbly beginners hug the boards (and sometimes
## just hang on to them), kids zig-zag and play in the middle, couples skate
## holding hands, a speedy teen weaves through everybody. About half rent
## skates at the window first (SkateRental), lace up and come on at the bench
## gates; when they leave, the rentals come back to the counter. A good
## night (sharp, clean rentals, good ice, a short line) hooks a few into
## buying skates or hockey gear: skater_hooked.
##
## ctx extras: count (skaters; else SkateDemand), in_place (everyone already
## skating), rental (false: no counter), staff (clerks), first_public_skate.

const FLOW_AHEAD := 3.0

var rental: SkateRental
var demand := {}
var target_count := 0
var gus_working := false
var hooked := 0
var refunds := 0
var turned_away := 0

var _arrivals: Array = []   # {at, look, age, role, rent, partner_key}
var _lacing: Array = []     # {at, info}
var _waiting := {}          # rental customer id -> arrival record
var _think_t := 0.0
var _couples := {}          # partner_key -> first skater id
var _cfg := {}


func _spawn() -> void:
	_cfg = OnIceData.section("public_skate")
	var dctx := {"weekday": int(ctx.get("weekday", 6)), "hour": float(ctx.get("hour", 14.0)),
		"month": int(ctx.get("month", 10)), "dom": int(ctx.get("dom", 17)), "ice_rep": sim.ice_rep if sim else 50.0}
	for k in ["temp_c", "weather", "price", "line_minutes", "capacity"]:
		if ctx.has(k):
			dctx[k] = ctx[k]
	demand = SkateDemand.expected(dctx)
	target_count = int(ctx.get("count", SkateDemand.sample(dctx, rng)))
	target_count = clampi(target_count, 0, int(demand.capacity))
	crowd_falls = false
	_plan_arrivals(bool(ctx.get("in_place", ctx.get("fast", false))))
	if ctx.get("rental", true):
		rental = SkateRental.new()
		rental.name = "SkateRental"
		var looks: Array = []
		gus_working = _first_skate()
		if gus_working:
			var g := OnIceData.cast_look("gus_tremblay")
			var gl: Dictionary = (g.get("look", {}) as Dictionary).duplicate(true)
			gl["name"] = "Gus"
			gl["age"] = int(g.get("age", 71))
			gl["skates"] = false
			looks.append(gl)
		var staff := int(ctx.get("staff", 1 + target_count / 90))
		var places: Dictionary = venue.call("places") if venue and venue.has_method("places") else {}
		rental.setup({"staff": maxi(staff, looks.size()), "staff_looks": looks, "seed": rng.seed + 3, "places": places,
			"window": ctx.get("rental_window"),
			"return_rack": bool(ctx.get("return_rack", sim.get("return_rack") == true if sim else false))})
		rental.auto_run = false
		add_child(rental)
		rental.served.connect(_on_served)
		rental.refund_demanded.connect(func(info: Dictionary) -> void:
			refunds += 1
			refund_demanded.emit(info))
		if gus_working and world:
			world.flags["first_public_skate_done"] = true


## Gus works the window at the very first public skate.
func _first_skate() -> bool:
	if ctx.has("first_public_skate"):
		return bool(ctx.first_public_skate)
	if world and world.flags.has("first_public_skate_done"):
		return false
	if sim:
		var n := 0
		for e: Dictionary in sim.session_log:
			n += 1 if str(e.get("org", "")) == "public_skate" else 0
		return n <= 1
	return true


func _plan_arrivals(in_place: bool) -> void:
	var mix: Dictionary = OnIceData.roster("public_skate").get("mix", {})
	var share := float(_cfg.get("rental_share", 0.45))
	var i := 0
	while i < target_count:
		var role := _pick(mix)
		var age := 30
		match role:
			"kid": age = rng.randi_range(4, 12)
			"speedy_teen": age = rng.randi_range(14, 17)
			"beginner": age = rng.randi_range(6, 60) if rng.randf() < 0.6 else rng.randi_range(25, 70)
			"couple": age = rng.randi_range(17, 45)
			_: age = rng.randi_range(12, 72)
		var rent := rng.randf() < share * (1.4 if role in ["beginner", "kid", "couple"] else 0.6)
		var at := 0.0 if in_place else pow(rng.randf(), 1.6) * 1200.0
		var rec := {"at": at, "age": age, "role": role, "rent": rent, "look": _look(role, age)}
		if role == "couple" and i + 1 < target_count:
			var key := i
			rec["couple"] = key
			_arrivals.append(rec)
			var rec2 := {"at": at + 2.0, "age": clampi(age + rng.randi_range(-4, 4), 16, 80), "role": "couple", "rent": rent, "couple": key}
			rec2["look"] = _look("couple", int(rec2.age))
			_arrivals.append(rec2)
			i += 2
			continue
		_arrivals.append(rec)
		i += 1
	_arrivals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.at) < float(b.at))
	if in_place:
		for r: Dictionary in _arrivals:
			var s := _make_skater(r, {})
			s.pos = _random_spot(s)
			s.on_ice = true
			s.task["state"] = "skate"
		_arrivals.clear()


func _pick(mix: Dictionary) -> String:
	var x := rng.randf()
	var acc := 0.0
	for k in mix:
		acc += float(mix[k])
		if x <= acc:
			return str(k)
	return "regular"


func _look(role: String, age: int) -> Dictionary:
	var l := look_for("skater", age)
	if role == "speedy_teen":
		l.outfit = "hoodie"
		l.accessory = "none" if rng.randf() < 0.6 else "toque"
	if age < 9 and rng.randf() < 0.75:
		l.accessory = "helmet"
	return l


func _make_skater(r: Dictionary, pair: Dictionary) -> IceSkater:
	var role := str(r.role)
	var age := int(r.age)
	var skill := 0.5
	match role:
		"beginner": skill = rng.randf_range(0.05, 0.25)
		"kid": skill = rng.randf_range(0.2, 0.6)
		"speedy_teen": skill = rng.randf_range(0.8, 0.95)
		"couple": skill = rng.randf_range(0.35, 0.7)
		_: skill = rng.randf_range(0.35, 0.8)
	if pair.has("sharp"):
		skill *= lerpf(0.75, 1.0, float(pair.sharp))  # dull rentals
	var s := add_skater(role, age, r.look, skill)
	s.happy = float(r.get("happy", 0.75))
	match role:
		"beginner":
			s.lane = rng.randf_range(0.45, 0.8)
			s.max_speed = rng.randf_range(0.7, 1.4)
			s.fall_rate = rng.randf_range(0.02, 0.05)
		"kid":
			s.lane = rng.randf_range(1.2, 6.5)
			s.fall_rate = rng.randf_range(0.004, 0.02)
		"speedy_teen":
			s.lane = rng.randf_range(2.5, 6.0)
			s.max_speed = rng.randf_range(6.5, 8.0)
			s.fall_rate = 0.0
		"couple":
			s.lane = rng.randf_range(2.2, 3.8)
			s.max_speed = minf(s.max_speed, rng.randf_range(2.2, 3.0))
		_:
			s.lane = rng.randf_range(1.4, 5.0)
			s.max_speed = minf(s.max_speed, rng.randf_range(2.6, 4.2))
	var stay: Array = _cfg.get("stay_minutes", [35, 110])
	s.task = {"state": "enter", "stay": t + rng.randf_range(float(stay[0]), float(stay[1])) * 60.0,
		"pair": pair, "rented": not pair.is_empty(), "wander": rng.randf() < (0.3 if role == "kid" else 0.0)}
	if r.has("couple"):
		var key := int(r.couple)
		if _couples.has(key):
			var other := by_id(int(_couples[key]))
			if other:
				s.partner = other.id
				other.partner = s.id
				s.task["follow"] = other.id
				s.lane = other.lane
		else:
			_couples[key] = s.id
	return s


func _random_spot(s: IceSkater) -> Vector2:
	for k in 30:
		var p := Vector2(rng.randf_range(-Rink.HALF_L + 1.0, Rink.HALF_L - 1.0), rng.randf_range(-Rink.HALF_W + 1.0, Rink.HALF_W - 1.0))
		if Rink.sdf(p) < -s.lane * 0.5 - 0.4:
			return p
	return Vector2.ZERO


# ------------------------------------------------------------------- think

func _think(dt: float) -> void:
	if rental:
		rental.step(dt)
	while not _arrivals.is_empty() and float(_arrivals[0].at) <= t:
		var r: Dictionary = _arrivals.pop_front()
		if r.rent and rental:
			var c := rental.enqueue(r.look, int(r.age))
			_waiting[c.id] = r
		else:
			var lace: Array = _cfg.get("lace_seconds", [40, 90])
			_lacing.append({"at": t + rng.randf_range(float(lace[0]), float(lace[1])), "rec": r, "pair": {}})
	var still: Array = []
	for l: Dictionary in _lacing:
		if float(l.at) <= t:
			var s := _make_skater(l.rec, l.pair)
			enter_at_gate(s, "home_bench" if rng.randf() < 0.5 else "away_bench")
		else:
			still.append(l)
	_lacing = still
	_think_t -= dt
	var think := _think_t <= 0.0
	if think:
		_think_t = 0.25
	var gone: Array = []
	for s: IceSkater in skaters:
		if s.hidden:
			continue
		var st := str(s.task.get("state", "skate"))
		match st:
			"enter":
				var to := _flow_target(s) if s.on_ice else Vector2(s.pos.x, -10.5)
				route(s, to, 1.2)
				if s.on_ice and Rink.sdf(s.pos) < -1.0:
					s.task.state = "skate"
			"skate":
				if think:
					_skate(s)
				if t > float(s.task.stay) or phase == "closing":
					s.task.state = "leave"
			"hold_boards":
				s.speed_want = 0.0
				s.pose_lock = PeopleArt.Pose.STAND
				if t > float(s.task.until):
					s.pose_lock = -1
					s.task.state = "skate"
			"leave":
				var gate: Vector2 = GATES[1].out if s.pos.x < 0.0 else GATES[2].out
				route(s, gate + Vector2(0, -0.6), 2.0)
				if not s.on_ice and s.pos.distance_to(gate) < 1.0:
					gone.append(s)
	for s2: IceSkater in gone:
		_leave(s2)


## Where on the CCW track this skater is heading next.
func _flow_target(s: IceSkater) -> Vector2:
	var lane := s.lane + sin(t * 0.05 + s.id) * 0.4
	var f := flow(s.pos, maxf(lane, 0.45))
	var ahead := FLOW_AHEAD + s.vel.length() * 0.6
	return f[0] + f[1] * ahead


func _skate(s: IceSkater) -> void:
	if s.down():
		return
	var follow := int(s.task.get("follow", -1))
	if follow >= 0:
		var lead := by_id(follow)
		if lead and not lead.hidden and lead.on_ice:
			# hand in hand on the leader's outside
			var fwd := lead.vel.normalized() if lead.vel.length() > 0.3 else lead.forward()
			var right := Vector2(-fwd.y, fwd.x)
			var spot := lead.pos + right * (lead.radius + s.radius + 0.02) + fwd * 0.1
			s.go(spot, lead.max_speed * 1.2 + 0.4, 0.05)
			s.max_speed = maxf(s.max_speed, lead.max_speed * 1.25)
			return
		s.task.erase("follow")
		s.partner = -1
	if s.role == "speedy_teen" and rng.randf() < 0.03:
		s.lane = rng.randf_range(1.5, 7.0)
	if s.role == "beginner" and Rink.sdf(s.pos) > -1.1 and rng.randf() < 0.02:
		s.task.state = "hold_boards"
		s.task.until = t + rng.randf_range(3.0, 9.0)
		s.face = Rink.board_normal(s.pos)
		return
	if s.task.get("wander", false):
		if not s.task.has("spot") or s.at_target(1.0) or rng.randf() < 0.01:
			s.task.spot = Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-6.0, 6.0))
		s.go(s.task.spot, s.max_speed * 0.7, 1.0)
		return
	s.go(_flow_target(s), s.max_speed * rng.randf_range(0.85, 1.0), 0.5)


## The closest point on the track `inset` metres in from the boards and the
## counter-clockwise (seen from above) direction there.
static func flow(p: Vector2, inset: float) -> Array:
	var r := maxf(Rink.CORNER_R - inset, 0.6)
	var hx := Rink.HALF_L - inset
	var hz := Rink.HALF_W - inset
	var q := Vector2(absf(p.x), absf(p.y)) - Vector2(hx - r, hz - r)
	var sx := signf(p.x) if p.x != 0.0 else 1.0
	var sz := signf(p.y) if p.y != 0.0 else 1.0
	var n: Vector2
	var d: float
	if q.x > 0.0 and q.y > 0.0:
		n = Vector2(q.x * sx, q.y * sz).normalized()
		d = q.length() - r
	elif q.x > q.y:
		n = Vector2(sx, 0)
		d = q.x - r
	else:
		n = Vector2(0, sz)
		d = q.y - r
	var closest := p - n * d
	return [closest, Vector2(n.y, -n.x)]


func _leave(s: IceSkater) -> void:
	s.hidden = true
	s.task.state = "gone"
	var pair: Dictionary = s.task.get("pair", {})
	# how was it?
	var ice_q := ice_rating("public") / 100.0
	var gear_q := (float(pair.sharp) + float(pair.clean)) * 0.5 if not pair.is_empty() else 0.75
	var xp := 0.45 * ice_q + 0.3 * gear_q + 0.25 * s.happy
	s.task["experience"] = xp
	if xp > 0.6 and rng.randf() < (xp - 0.6) * 0.7:
		hooked += 1
		var wants := "hockey_gear" if (s.age < 18 and rng.randf() < 0.55) or rng.randf() < 0.2 else "skates"
		var info := {"name": s.name, "age": s.age, "wants": wants, "experience": xp, "rented": not pair.is_empty(), "person": s.person_id}
		skater_hooked.emit(info)
		if world:
			world.flags["pro_shop_leads"] = int(world.flags.get("pro_shop_leads", 0)) + 1
			world.flags["hooked_" + wants] = int(world.flags.get("hooked_" + wants, 0)) + 1
	if not pair.is_empty() and rental:
		rental.return_pair(pair, s.look, s.age)


func _on_served(c: IceSkater, info: Dictionary) -> void:
	var r: Dictionary = _waiting.get(c.id, {})
	_waiting.erase(c.id)
	if r.is_empty():
		return
	if str(info.get("size_got", "")) == "":
		turned_away += 1
		return
	r = r.duplicate()
	r["happy"] = c.happy
	var lace: Array = _cfg.get("lace_seconds", [40, 90])
	_lacing.append({"at": t + rng.randf_range(float(lace[0]), float(lace[1])) + 20.0, "rec": r, "pair": info.pair})


## Everybody off: the session is over (skaters head for the gates).
func close() -> void:
	phase = "closing"


func _end() -> void:
	super._end()
