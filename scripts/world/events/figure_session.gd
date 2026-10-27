class_name OnIceFigure
extends OnIceSession
## Figure skating (docs/world/ON_ICE.md 3).
##
## "figure" before 09:00: the 05:00 ice is the talented skaters working
## privately with coaches on their programmes: footwork sequences across the
## ice, jumps (a backward approach, take-off, rotations in the air, a
## landing on one foot gliding backwards, or a fall), scratch spins and long
## spirals; between elements they go back to the boards for a word with the
## coach. Later in the day the same kind is a class ("figure_class", also
## learn to skate): groups by skill, each with a coach, crossing the ice
## doing their level's elements. "figure_show": one skater at a time
## performs while the rest wait by the gate, and the crowd applauds.
##
## Figure skaters like warm, soft ice: satisfaction() reads the ice's
## surface temperature and thickness; flood_request() is the 04:45 heavy
## flood they want before the 05:00 session.

var mode := "morning"      # morning, class, show
var groups: Array = []     # class: {level, coach, skaters, area}
var _show := {}
var _cfg := {}


func _spawn() -> void:
	_cfg = OnIceData.section("figure")
	if controller == "figure_class" or kind == "learn_to_skate":
		mode = "class"
	elif controller == "figure_show":
		mode = "show"
	else:
		mode = "morning" if float(ctx.get("hour", 5.0)) < float(_cfg.get("morning_until_hour", 9.0)) else "class"
	crowd_falls = mode == "show"
	match mode:
		"morning": _spawn_morning()
		"class": _spawn_class()
		"show": _spawn_show()
	phase = "on"


func _spawn_morning() -> void:
	var r := OnIceData.roster("figure")
	var n := int(ctx.get("count", rng.randi_range(int(r.skaters[0]), int(r.skaters[1]))))
	var nc := rng.randi_range(int(r.coaches[0]), int(r.coaches[1]))
	var coaches: Array = []
	for i in nc:
		var c := add_skater("coach", rng.randi_range(30, 62), look_for("coach", 45), 0.75)
		c.pos = Vector2(-20.0 + i * 20.0, 12.0)
		c.on_ice = true
		coaches.append(c.id)
	for i in n:
		var age := rng.randi_range(int(r.ages[0]), int(r.ages[1]))
		var s := add_skater("figure", age, look_for("figure", age), rng.randf_range(0.72, 0.95))
		s.max_speed = rng.randf_range(5.5, 7.0)
		s.accel = 3.5
		s.fall_rate = 0.0
		s.pos = Vector2(rng.randf_range(-25.0, 25.0), rng.randf_range(-9.0, 9.0))
		s.task = {"coach": coaches[i % coaches.size()], "el": rng.randi() % 7, "state": "next"}


func _spawn_class() -> void:
	var r := OnIceData.roster("figure_class")
	var n := int(ctx.get("count", rng.randi_range(int(r.skaters[0]), int(r.skaters[1]))))
	var levels: Array = _cfg.get("class_levels", [])
	var third := Rink.LENGTH / maxf(levels.size(), 1)
	for li in levels.size():
		var lv: Dictionary = levels[li]
		var x0 := -Rink.HALF_L + third * li
		var area := Rect2(x0 + 1.5, -Rink.HALF_W + 1.5, third - 3.0, Rink.WIDTH - 3.0)
		var c := add_skater("coach", rng.randi_range(19, 55), look_for("coach", 30), 0.8)
		c.pos = area.get_center() + Vector2(0, -area.size.y * 0.42)
		var g := {"level": lv, "coach": c.id, "skaters": [], "area": area, "side": -1.0, "t": 0.0, "phase": "line", "el": 0}
		groups.append(g)
	for i in n:
		var gi := i % groups.size()
		var g2: Dictionary = groups[gi]
		var lv2: Dictionary = g2.level
		var sk: Array = lv2.get("skill", [0.1, 0.3])
		var adult := kind == "learn_to_skate" and rng.randf() < 0.35
		var age := rng.randi_range(25, 60) if adult else rng.randi_range(4 + gi * 2, 8 + gi * 3)
		var s := add_skater("figure" if gi == groups.size() - 1 else "kid", age, look_for("figure" if gi == groups.size() - 1 else "skater", age), rng.randf_range(float(sk[0]), float(sk[1])))
		s.group = gi
		s.box = g2.area
		s.pos = g2.area.get_center() + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-4.0, 4.0))
		s.fall_rate = lerpf(0.04, 0.0, s.skill * 1.5)
		g2.skaters.append(s.id)


func _spawn_show() -> void:
	var r := OnIceData.roster("figure_show")
	var n := int(ctx.get("count", rng.randi_range(int(r.skaters[0]), int(r.skaters[1]))))
	var c := add_skater("coach", 48, look_for("coach", 48), 0.7)
	c.pos = Vector2(-1.0, -12.0)
	for i in n:
		var age := rng.randi_range(int(r.ages[0]), int(r.ages[1]))
		var s := add_skater("figure", age, look_for("figure", age), rng.randf_range(0.55, 0.92))
		s.pos = Vector2(-6.0 + (i % 6) * 0.9, -11.6 + (i / 6) * 0.9)
		s.max_speed = rng.randf_range(5.0, 6.5)
		s.fall_rate = 0.0
		s.task = {"state": "wait", "el": 0}
	_show = {"order": skaters.filter(func(x: IceSkater) -> bool: return x.role == "figure").map(func(x: IceSkater) -> int: return x.id), "i": 0, "t": 0.0, "phase": "intro"}


# ------------------------------------------------------------------ think

func _think(dt: float) -> void:
	match mode:
		"morning": _morning(dt)
		"class": _class(dt)
		"show": _show_step(dt)


func _morning(dt: float) -> void:
	for s: IceSkater in skaters:
		if s.role == "coach":
			_coach_watch(s)
		elif s.role == "figure":
			_element(s, dt)


func _coach_watch(c: IceSkater) -> void:
	# stands by the boards, drifting to watch their skaters
	var mine: Array = skaters.filter(func(x: IceSkater) -> bool: return x.task.get("coach", -1) == c.id)
	var watch := Vector2.ZERO
	for m: IceSkater in mine:
		watch += m.pos
	if not mine.is_empty():
		watch /= mine.size()
	var spot := Vector2(clampf(watch.x, -24.0, 24.0), 11.6 if c.pos.y > 0.0 else -11.6)
	c.go(spot, 1.5, 1.5)
	c.face = (watch - c.pos).normalized()


## Works through the programme: footwork, jumps, spins, spirals, a chat.
func _element(s: IceSkater, dt: float) -> void:
	if s.down():
		s.lift = 0.0
		s.spin_rate = 0.0
		s.pose_lock = -1
		return
	var tk := s.task
	tk["t"] = float(tk.get("t", 0.0)) + dt
	var routine: Array = _cfg.get("routine", ["footwork", "jump", "spin", "spiral"])
	match str(tk.state):
		"next":
			tk.el = (int(tk.el) + 1) % (routine.size() + 1)
			tk.t = 0.0
			s.pose_lock = -1
			s.spin_rate = 0.0
			s.backward = false
			if int(tk.el) == routine.size():
				tk.state = "coach"
			else:
				tk.state = str(routine[int(tk.el)])
				_start_element(s, tk)
		"coach":
			var c := by_id(int(tk.coach))
			if c:
				var spot := c.pos + (Vector2(0, -1) if c.pos.y > 0.0 else Vector2(0, 1)) * 1.1
				s.go(spot, 3.0, 0.5)
				if s.at_target(0.8):
					s.face = (c.pos - s.pos).normalized()
					s.pose_lock = PeopleArt.Pose.TALK
					c.pose_lock = PeopleArt.Pose.TALK
					if float(tk.t) > float(tk.get("talk", 12.0)):
						c.pose_lock = -1
						tk.state = "next"
			else:
				tk.state = "next"
		"footwork":
			# a serpentine step sequence the length of the ice
			var pts: Array = tk.pts
			if pts.is_empty() or float(tk.t) > float(tk.dur):
				tk.state = "next"
				return
			s.go(pts[0], s.max_speed * 0.55, 1.0)
			s.phase = fmod(s.phase + dt * 1.2, 1.0)  # busy feet
			if s.at_target(1.0):
				pts.pop_front()
				s.backward = not s.backward if rng.randf() < 0.4 else s.backward
				blade_carve.emit(s.pos3(), s.vel.length())
		"jump":
			_jump(s, tk, dt)
		"spin":
			if not tk.get("in", false):
				s.go(tk.spot, s.max_speed * 0.6, 0.6)
				if s.at_target(0.8):
					tk["in"] = true
					tk.t = 0.0
			else:
				s.speed_want = 0.0
				s.vel *= 0.9
				s.pose_lock = PeopleArt.Pose.SPIN
				if float(tk.t) > float(tk.dur):
					s.pose_lock = -1
					blade_carve.emit(s.pos3(), 3.0)
					tk.state = "next"
		"spiral":
			# one long glide on one foot, arms out
			s.go(tk.spot, s.max_speed * 0.65, 1.5)
			s.pose_lock = PeopleArt.Pose.WAVE if s.vel.length() > 2.0 else -1
			if s.at_target(1.5) or float(tk.t) > float(tk.dur):
				s.pose_lock = -1
				tk.state = "next"


func _start_element(s: IceSkater, tk: Dictionary) -> void:
	var el: Dictionary = _cfg.get("elements", {}).get(str(tk.state), {})
	var secs: Array = el.get("seconds", [4.0, 8.0])
	tk.dur = rng.randf_range(float(secs[0]), float(secs[1]))
	match str(tk.state):
		"footwork":
			var pts: Array = []
			var x := -22.0 if s.pos.x > 0.0 else 22.0
			var dirx := -signf(x)
			var z := rng.randf_range(-5.0, 5.0)
			for k in 7:
				pts.append(Vector2(x + dirx * k * 7.0, z + (3.0 if k % 2 == 0 else -3.0)))
			tk.pts = pts
		"jump":
			# approach: a backward curve into the take-off
			var take := Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(-6.0, 6.0))
			tk.take = take
			tk.approach = take + Vector2(rng.randf_range(-9.0, 9.0), rng.randf_range(-4.0, 4.0)).normalized() * 8.0
			tk.phase = "approach"
			var air: Array = el.get("air", [0.45, 0.75])
			tk.air = rng.randf_range(float(air[0]), float(air[1]))
		"spin":
			tk.spot = Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-7.0, 7.0))
			tk["in"] = false
		"spiral":
			var side := -1.0 if s.pos.x > 0.0 else 1.0
			tk.spot = Vector2(side * 20.0, rng.randf_range(-6.0, 6.0))


func _jump(s: IceSkater, tk: Dictionary, dt: float) -> void:
	match str(tk.phase):
		"approach":
			s.go(tk.approach, s.max_speed * 0.6, 1.2)
			if s.at_target(1.5) or float(tk.t) > 12.0:
				tk.phase = "run"
				tk.t = 0.0
		"run":
			s.backward = true
			s.go(tk.take, s.max_speed * 0.75, 0.8)
			if s.at_target(1.0) or float(tk.t) > 8.0:
				tk.phase = "air"
				tk.t = 0.0
				blade_carve.emit(s.pos3(), s.vel.length())
		"air":
			var air := float(tk.air)
			var u := clampf(float(tk.t) / air, 0.0, 1.0)
			s.lift = 4.0 * 0.45 * u * (1.0 - u) * (air / 0.6)
			s.pose_lock = PeopleArt.Pose.SPIN
			s.speed_want = s.vel.length()
			s.target = s.pos + s.vel
			if u >= 1.0:
				s.lift = 0.0
				s.pose_lock = -1
				# landed, or on the ice: the harder the jump, the likelier the fall
				var p_fall := clampf(0.38 - s.skill * 0.35 + (air - 0.5) * 0.4, 0.03, 0.5)
				_ice_mark(s.pos3(), 0.04)
				if rng.randf() < p_fall:
					s.fall(rng)
					on_fell(s)
					tk.state = "next"
				else:
					stop_spray.emit(s.pos3(), s.vel.length())
					tk.phase = "land"
					tk.t = 0.0
		"land":
			# glide out backwards on one foot
			s.backward = true
			s.go(s.pos + s.vel.normalized() * 4.0, s.max_speed * 0.5, 0.5)
			s.pose_lock = PeopleArt.Pose.WAVE
			if float(tk.t) > 1.6:
				s.pose_lock = -1
				s.backward = false
				tk.state = "next"
	if s.lift <= 0.0 and dt > 0.0:
		s.lift = 0.0


func _class(dt: float) -> void:
	for g: Dictionary in groups:
		g.t = float(g.t) + dt
		var c := by_id(int(g.coach))
		var area: Rect2 = g.area
		var side: float = g.side
		var elements: Array = g.level.get("elements", ["march"])
		var el := str(elements[int(g.el) % elements.size()])
		if c:
			var cspot := Vector2(area.get_center().x - side * area.size.x * 0.48, area.get_center().y)
			c.go(cspot, 2.0, 0.5)
			c.face = Vector2(side, 0)
		var ids: Array = g.skaters
		match str(g.phase):
			"line":
				for k in ids.size():
					var s := by_id(ids[k])
					if s and not s.down():
						s.pose_lock = -1
						s.go(Vector2(area.get_center().x + side * area.size.x * 0.42, area.position.y + area.size.y * (float(k) + 0.5) / maxf(ids.size(), 1)), 1.5, 0.3)
						s.face = Vector2(-side, 0)
				if float(g.t) > 6.0:
					g.phase = "cross"
					g.t = 0.0
					coach_whistle.emit(c.pos3() if c else Vector3.ZERO)
			"cross":
				var all_there := true
				for k in ids.size():
					var s2 := by_id(ids[k])
					if s2 == null:
						continue
					var goal := Vector2(area.get_center().x - side * area.size.x * 0.42, area.position.y + area.size.y * (float(k) + 0.5) / maxf(ids.size(), 1))
					var spd := lerpf(0.6, 3.5, s2.skill)
					if el in ["two_foot_spin", "scratch_spin"] and absf(s2.pos.x - area.get_center().x) < 0.8:
						s2.pose_lock = PeopleArt.Pose.SPIN
					elif el == "spiral" or el == "one_foot_glide":
						s2.pose_lock = PeopleArt.Pose.WAVE if s2.vel.length() > 1.0 else -1
					elif el in ["march", "dip"]:
						s2.pose_lock = PeopleArt.Pose.SKATE_WOBBLY if s2.vel.length() > 0.3 else -1
					else:
						s2.pose_lock = -1
					s2.backward = el in ["backward_wiggles"]
					s2.go(goal, spd, 0.6)
					if el == "fall_and_get_up" and rng.randf() < 0.004 and not s2.down():
						s2.fall(rng)  # on purpose: it's a lesson
					if s2.pos.distance_to(goal) > 1.0:
						all_there = false
				if all_there or float(g.t) > 40.0:
					g.side = -side
					g.phase = "line"
					g.t = 0.0
					g.el = int(g.el) + 1


func _show_step(dt: float) -> void:
	_show.t = float(_show.t) + dt
	var order: Array = _show.order
	if order.is_empty():
		return
	var cur := by_id(order[int(_show.i) % order.size()])
	for s: IceSkater in skaters:
		if s.role == "figure" and s != cur:
			var k := order.find(s.id)
			s.go(Vector2(-6.0 + (k % 6) * 0.9, -11.5 + (k / 6) * 0.9), 2.0, 0.3)
			s.face = Vector2(0, 1)
			s.pose_lock = -1
	if cur == null:
		return
	match str(_show.phase):
		"intro":
			cur.go(Vector2(0, 0), 3.0, 0.6)
			if cur.at_target(0.8) or float(_show.t) > 15.0:
				cur.speed_want = 0.0
				cur.pose_lock = PeopleArt.Pose.WAVE
				if float(_show.t) > 18.0:
					_show.phase = "skate"
					_show.t = 0.0
					cur.pose_lock = -1
					cur.task = {"state": "next", "el": -1, "coach": -1}
		"skate":
			_element(cur, dt)
			if str(cur.task.get("state", "")) == "coach":
				cur.task.state = "next"
				cur.task.el = -1
			if float(_show.t) > 150.0:
				_show.phase = "bow"
				_show.t = 0.0
				crowd_reaction.emit("applause", 0.8)
		"bow":
			cur.lift = 0.0
			cur.spin_rate = 0.0
			cur.go(Vector2(0, 2.0), 2.0, 0.5)
			cur.face = Vector2(0, 1)
			cur.pose_lock = PeopleArt.Pose.WAVE
			if float(_show.t) > 6.0:
				cur.pose_lock = -1
				_show.i = int(_show.i) + 1
				_show.phase = "intro"
				_show.t = 0.0


# --------------------------------------------------------------- the ice

## How happy figure skaters are with the ice, 0..1, and why: warm (about
## -3.5 C at the surface) and thick, soft ice. {} fields read 0 when the ice
## doesn't say.
static func ice_satisfaction(ice_: Object) -> Dictionary:
	var cfg := OnIceData.section("figure")
	var temp_v: Variant = ice_.get("surface_temp") if ice_ else null
	var thick_v: Variant = ice_.get("thickness_mm") if ice_ else null
	var ideal := float(cfg.get("ideal_temp_c", -3.5))
	var th: Array = cfg.get("ideal_thickness_mm", [36.0, 50.0])
	var temp := float(temp_v) if temp_v != null else ideal - 1.5
	var thick := float(thick_v) if thick_v != null else 40.0
	var t_score := clampf(1.0 - absf(temp - ideal) / 2.5, 0.0, 1.0)
	if temp < ideal:
		t_score = clampf(1.0 - (ideal - temp) / 2.0, 0.0, 1.0)  # hard, cold ice is worse than warm
	var k_score := 1.0
	if thick < float(th[0]):
		k_score = clampf(1.0 - (float(th[0]) - thick) / 15.0, 0.0, 1.0)
	elif thick > float(th[1]):
		k_score = clampf(1.0 - (thick - float(th[1])) / 25.0, 0.0, 1.0)
	var note := "soft and warm, perfect for jumps" if t_score > 0.8 else ("too hard: edges skip on landings" if temp < ideal else "a touch slushy")
	return {"score": t_score * 0.65 + k_score * 0.35, "temp": t_score, "thickness": k_score, "temp_c": temp, "thickness_mm": thick, "note": note}


func satisfaction() -> Dictionary:
	return ice_satisfaction(ice)


## The flood figure skaters want: a heavy one at 04:45 for the 05:00 ice.
static func flood_request() -> Dictionary:
	var cfg := OnIceData.section("figure")
	return {"minute": int(cfg.get("flood_minute", 285)), "kind": str(cfg.get("flood_kind", "heavy")), "for": "figure_practice"}
