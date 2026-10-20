class_name OnIceSession
extends Node3D
## What's happening on the ice right now, as real bodies: the controller for
## one session, picked by its event kind (docs/world/ON_ICE.md). It spawns
## the skaters, coaches, refs and gear the event needs and drives them every
## frame: public skate counter-clockwise laps, figure routines, pee-wee
## stations behind the divider pads, high school team drills, stick and
## puck, ambient hockey games and broomball in sneakers.
##
##   var s := OnIceSession.create("public_skate", {"sim": sim, "venue": venue, "hour": 14.0})
##   venue.add_child(s)       # venue space: the rink is centred on the origin
##   s.step(dt)               # or leave auto_run on and it runs itself
##
##   OnIceSession.for_sim(sim, venue)  # the controller for sim.session_now(), or null
##
## Sound hooks (the lead thread connects; nothing here plays audio):
## blade_carve(pos, speed) once per stride, stop_spray(pos, speed) for a
## hockey stop, puck_hit(pos, what, speed) for boards / post / pylon / pad /
## net / skate / stick / goalie, whistle(pos) for a ref, coach_whistle(pos),
## crowd_reaction(kind, strength) and skater_fell(pos, role).
##
## For other threads: nets_needed(full, mini) when a practice is waiting for
## nets (Mechanics' nets job), setup_needed(task) for divider pads and the
## puck bucket, skater_hooked(info) when a public skater wants their own
## skates or hockey gear (the pro shop, Mechanics), refund_demanded(info).

signal blade_carve(pos: Vector3, speed: float)
signal stop_spray(pos: Vector3, speed: float)
signal puck_hit(pos: Vector3, what: String, speed: float)
signal whistle(pos: Vector3)
signal coach_whistle(pos: Vector3)
signal crowd_reaction(kind: String, strength: float)
signal skater_fell(pos: Vector3, role: String)
signal nets_needed(full: int, mini: int)
signal setup_needed(task: Dictionary)
signal skater_hooked(info: Dictionary)
signal refund_demanded(info: Dictionary)
signal finished()

## Zamboni gate in the +X end boards and the two bench gates (-Z side).
const GATES := [
	{"id": "zamboni", "in": Vector2(29.4, 0.0), "out": Vector2(31.7, 0.0)},
	{"id": "home_bench", "in": Vector2(-3.0, -11.9), "out": Vector2(-3.0, -13.9)},
	{"id": "away_bench", "in": Vector2(3.0, -11.9), "out": Vector2(3.0, -13.9)},
]
const WEAR_EVERY := 0.5

var kind := ""
var controller := ""
var ctx := {}
var sim: RinkSim
var ice: Object          # IceSlab (or anything with the same fields)
var venue: Node3D
var world: StoryWorld
var skaters: Array = []  # IceSkater
var gear: IceGear
var rng := RandomNumberGenerator.new()
var t := 0.0
var duration := 7200.0
var auto_run := true
var time_scale := 1.0
var phase := "setup"     # the controller's own phases; "done" at the end
var rack_gear := Vector2(32.7, -3.4)
var rack_pads := Vector2(32.7, 3.4)
var crowd_falls := false # games and shows: the crowd notices a fall

var _by_id := {}
var _next_id := 1
var _draw: OnIceDraw
var _wear_t := 0.0
var _hooks := {}
var _listen_carve := false


## The controller for an event kind. ctx (all optional): sim, ice, venue,
## world, weekday, hour, month, dom, hours, count (skaters), seed, fast
## (gear already out), came (Attendance list: real people skate), staff.
static func create(kind_: String, ctx_ := {}) -> OnIceSession:
	var c := OnIceData.controller_for(kind_)
	var s: OnIceSession
	match c:
		"public_skate": s = OnIcePublicSkate.new()
		"figure", "figure_class", "figure_show": s = OnIceFigure.new()
		"broomball": s = OnIceBroomball.new()
		"peewee_practice", "team_practice", "stick_and_puck": s = OnIcePractice.new()
		"game": s = OnIceGame.new()
		_: s = OnIcePublicSkate.new()
	s.name = "OnIce_" + kind_
	s.kind = kind_
	s.controller = c
	s._setup_common(ctx_)
	s._spawn()
	return s


## The controller for whatever RinkSim has on the ice now ({} -> null).
static func for_sim(sim_: RinkSim, venue_: Node3D = null, extra := {}) -> OnIceSession:
	var sess := sim_.session_now()
	if sess.is_empty():
		return null
	var o := RinkContracts.org(str(sess.get("org", "")))
	var k := str(o.get("event", "public_skate"))
	var dt := sim_.date_of(sim_.day)
	var c := {"sim": sim_, "venue": venue_, "weekday": sim_.weekday(), "hour": float(sess.start), "hours": float(sess.hours),
		"month": int(dt.month), "dom": int(dt.dom), "org": str(sess.get("org", "")), "seed": sim_.day * 31 + int(float(sess.start) * 4.0)}
	c.merge(extra, true)
	return create(k, c)


func _setup_common(c: Dictionary) -> void:
	ctx = c
	sim = c.get("sim")
	ice = c.get("ice", sim.ice if sim else null)
	venue = c.get("venue")
	world = c.get("world")
	rng.seed = int(c.get("seed", hash(kind) + int(c.get("weekday", 0)) * 13 + int(float(c.get("hour", 12.0)) * 7)))
	duration = float(c.get("hours", 2.0)) * 3600.0
	var eq: Dictionary = OnIceData.section("equipment")
	rack_gear = OnIceData.v2(eq.get("rack_gear"), rack_gear)
	rack_pads = OnIceData.v2(eq.get("rack_pads"), rack_pads)
	gear = IceGear.new()
	gear.name = "Gear"
	gear.rng.seed = rng.seed + 1
	add_child(gear)
	gear.puck_hit.connect(func(p: Vector3, w: String, sp: float) -> void: puck_hit.emit(p, w, sp))
	gear.goal.connect(_on_goal)
	gear.save.connect(_on_save)
	gear.add_prop("rack_gear", rack_gear, PI * 0.5)
	gear.add_prop("rack_pads", rack_pads, PI * 0.5)
	_draw = OnIceDraw.new(self, "OnIce")
	_hooks = {"fell": on_fell, "stride": _on_stride, "bump": bump}


## Subclasses put their people and gear out here.
func _spawn() -> void:
	pass


## Subclasses decide what everybody does here, every step.
func _think(_dt: float) -> void:
	pass


func _physics_process(dt: float) -> void:
	if auto_run:
		step(dt * time_scale)


func _process(_dt: float) -> void:
	_draw.draw(skaters)


## Runs the session forward `dt` seconds.
func step(dt: float) -> void:
	if phase == "done":
		return
	t += dt
	_listen_carve = blade_carve.get_connections().size() > 0
	_think(dt)
	OnIceMotion.step(skaters, dt, rng, gear.nets, _hooks)
	gear.step(dt, skaters)
	_wear(dt)
	if t >= duration and phase != "done":
		_end()


func _end() -> void:
	phase = "done"
	finished.emit()


## Runs `seconds` of the session in `dt` steps (tests, a skipped clock).
func run_for(seconds: float, dt := 1.0 / 30.0) -> void:
	var n := int(ceil(seconds / dt))
	for i in n:
		step(dt)


# ------------------------------------------------------------- the people

func add_skater(role: String, age: int, look: Dictionary, skill: float) -> IceSkater:
	var s := IceSkater.make(_next_id, role, age, look, skill)
	_next_id += 1
	skaters.append(s)
	_by_id[s.id] = s
	_draw.mark_dirty()
	return s


func remove_skater(s: IceSkater) -> void:
	if s.puck >= 0 and s.puck < gear.pucks.size():
		gear.pucks[s.puck].owner = -1
	skaters.erase(s)
	_by_id.erase(s.id)
	_draw.mark_dirty()


func by_id(sid: int) -> IceSkater:
	return _by_id.get(sid)


func count_role(role: String) -> int:
	var n := 0
	for s: IceSkater in skaters:
		n += 1 if s.role == role and not s.hidden else 0
	return n


func roles() -> Dictionary:
	var out := {}
	for s: IceSkater in skaters:
		if not s.hidden:
			out[s.role] = int(out.get(s.role, 0)) + 1
	return out


func on_ice_count() -> int:
	var n := 0
	for s: IceSkater in skaters:
		n += 1 if s.on_ice and not s.hidden else 0
	return n


## A look for someone on the ice in this role (PeopleArt look dictionary).
func look_for(role: String, age: int, extra := {}) -> Dictionary:
	var l := PeopleArt.random_look(rng, age, "ice")
	l["skates"] = true
	match role:
		"coach":
			l.outfit = "coach_tracksuit"
			l.accessory = "whistle" if rng.randf() < 0.6 else "clipboard"
		"ref":
			l.outfit = "ref_stripes"
			l.accessory = "whistle"
			l.colors = ["eeeeea", "1d1d22"]
		"player", "goalie":
			l.outfit = "goalie_gear" if role == "goalie" else "hockey_gear"
			l.accessory = "stick"
		"figure":
			l.outfit = "figure_dress" if rng.randf() < 0.6 else "figure_warmup"
			l.accessory = "none"
			l.hair = "bun" if rng.randf() < 0.6 else l.hair
		"broomball":
			l.outfit = ["hoodie", "casual", "team_jacket"][rng.randi() % 3]
			l.accessory = "stick"   # the broom
			l.skates = false
		"employee", "customer":
			l.skates = false
			if role == "employee":
				l.outfit = "staff_polo"
				l.accessory = "none"
	l["name"] = "%s %s" % [Names.first(rng), Names.last(rng)]
	l.merge(extra, true)
	return l


## The rink-space zone a skater is kept in (pee-wee pads); Rect2() for none.
func zone_of(_s: IceSkater) -> Rect2:
	return Rect2()


## Walks or skates `s` toward `to`, through a gate when one end is off the ice.
func route(s: IceSkater, to: Vector2, spd: float) -> void:
	var to_on := Rink.sdf(to) < -0.2
	if s.on_ice == to_on:
		s.go(to, spd if s.on_ice else minf(spd, 1.5), 0.5)
		return
	var gate: Dictionary = GATES[0]
	var bd := INF
	for g: Dictionary in GATES:
		var d := (g.out as Vector2).distance_to(to if not to_on else s.pos)
		if d < bd:
			bd = d
			gate = g
	var gin: Vector2 = gate.in
	var gout: Vector2 = gate.out
	if s.on_ice:
		if s.pos.distance_to(gin) < 0.9:
			s.on_ice = false
			s.go(gout, 1.4, 0.4)
		else:
			s.go(gin, spd, 0.6)
	else:
		if Rink.sdf(s.pos) < -s.radius - 0.05:
			s.on_ice = true
			s.go(to, spd, 0.5)
		elif s.pos.distance_to(gout) < 0.6 or _in_gate(s.pos, gin, gout):
			s.go(gin + (gin - gout).normalized() * 0.8, 1.4, 0.3)
		else:
			s.go(gout, 1.5, 0.4)


func _in_gate(p: Vector2, a: Vector2, b: Vector2) -> bool:
	var ab := b - a
	var tt := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * tt) < 0.7


## Brings someone onto the ice at a gate from the walkway behind it.
func enter_at_gate(s: IceSkater, gate_id := "zamboni") -> void:
	for g: Dictionary in GATES:
		if g.id == gate_id:
			var gout: Vector2 = g.out
			s.pos = gout
			s.on_ice = false
			s.hidden = false
			return


# ------------------------------------------------------------ the gear

## The nets out on the ice per Mechanics' nets job: sim.get("nets_on_ice")
## when it exists (a count of full-size nets, {"full", "mini"} or a list of
## {"size"}), otherwise all of them ("assumed": true).
func nets_out() -> Dictionary:
	var eq: Dictionary = OnIceData.section("equipment")
	var full := int(eq.get("full_nets", 4))
	var mini := int(eq.get("mini_nets", 8))
	if ctx.has("nets_on_ice"):
		return _nets_from(ctx.nets_on_ice, mini)
	var v: Variant = sim.get("nets_on_ice") if sim else null
	if v == null:
		return {"full": full, "mini": mini, "assumed": true}
	return _nets_from(v, mini)


static func _nets_from(v: Variant, mini_default: int) -> Dictionary:
	if v is int or v is float:
		return {"full": int(v), "mini": mini_default}
	if v is Dictionary:
		return {"full": int(v.get("full", 0)), "mini": int(v.get("mini", mini_default))}
	if v is Array:
		var f := 0
		var m := 0
		for e in v:
			if e is Dictionary and str(e.get("size", "full")) == "mini":
				m += 1
			else:
				f += 1
		return {"full": f, "mini": m if m > 0 else mini_default}
	return {"full": 4, "mini": mini_default}


# ------------------------------------------------------------ the ice

func ice_temp() -> float:
	var v: Variant = ice.get("surface_temp") if ice else null
	return float(v) if v != null else -4.5


func ice_thickness() -> float:
	var v: Variant = ice.get("thickness_mm") if ice else null
	return float(v) if v != null else 40.0


func ice_snow() -> float:
	var v: Variant = ice.get("snow") if ice else null
	return float(v) if v != null else 0.3


func ice_wet() -> float:
	if ice and ice.has_method("wetness"):
		return float(ice.call("wetness"))
	return 0.0


func ice_rating(use: String) -> float:
	if ice and ice.has_method("rating"):
		return float(ice.call("rating", use))
	return 60.0


## Skaters mark the ice: ice.wear(pos, amount) when the ice sim has it.
## amount: metres skated x 0.01, a hockey stop 0.05, a fall 0.02.
func _wear(dt: float) -> void:
	_wear_t += dt
	for s: IceSkater in skaters:
		if s.on_ice and not s.hidden:
			s.wear_acc += s.vel.length() * dt * 0.01
	if _wear_t < WEAR_EVERY:
		return
	_wear_t = 0.0
	var can := ice != null and ice.has_method("wear")
	for s2: IceSkater in skaters:
		if s2.wear_acc > 0.0:
			if can:
				ice.call("wear", s2.pos3(), s2.wear_acc)
			s2.wear_acc = 0.0


func _ice_mark(at: Vector3, amount: float) -> void:
	if ice and ice.has_method("wear"):
		ice.call("wear", at, amount)


# ------------------------------------------------------------ events

func hockey_stop(s: IceSkater) -> void:
	var sp := s.vel.length()
	s.speed_want = 0.0
	if s.shoes or not s.on_ice:
		return
	stop_spray.emit(s.pos3(), sp)
	blade_carve.emit(s.pos3(), sp)
	_ice_mark(s.pos3(), 0.05)


func on_fell(s: IceSkater) -> void:
	skater_fell.emit(s.pos3(), s.role)
	_ice_mark(s.pos3(), 0.02)
	if crowd_falls:
		crowd_reaction.emit("ooh", 0.3)


func bump(a: IceSkater, _b: IceSkater, speed: float) -> void:
	if speed > 3.0 and crowd_falls:
		crowd_reaction.emit("hit", clampf(speed / 8.0, 0.2, 1.0))
	if a.on_ice:
		blade_carve.emit(a.pos3(), speed)


func shot_taken(_s: IceSkater) -> void:
	pass


func _on_stride(s: IceSkater) -> void:
	if _listen_carve:
		blade_carve.emit(s.pos3(), s.vel.length())


func _on_goal(_net: int, _puck: int) -> void:
	pass


func _on_save(_net: int, _puck: int) -> void:
	pass
