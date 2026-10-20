class_name RinkPeople
extends Node3D
## Everyone in the building, live: fans in their seats, parents at the glass,
## skaters on the ice, the canteen line, the kid who won't stop asking about
## Doris. Each body is a Person with an NpcBrain; this node walks them along
## the PlaceMap, opens the doors they pass through, serves the canteen line,
## gives them solid bodies the puck and the owner bump into, and draws them
## all with one MultiMesh per body layer (PeopleArt).
##
##   var people := RinkPeople.new()
##   venue.add_child(people)
##   people.setup(venue, world, {"kind": "beer_league", ...})
##   people.populate(Attendance.who_comes(world.cast, ev, rng), true)
##
## Or let RinkLife run the building from the sim's clock and bookings:
## `people.drive(life, sim_minutes_per_second)`.
##
## Talk to someone: `var a := people.nearest(pos, 2.0)`, then
## `people.talk(a)` returns a Conversation (they stop and face you).
##
## Everyone came for a reason (Attendance): parents turn to follow their kid
## on the ice, wait in the lobby after and leave with them; groups arrive
## together by car (from the parking lot) or on foot (from the sidewalk).
##
## Outside controllers (an on-ice event, the tutorial) can take agents over:
## `claim(a, owner)` stops their brain, then `move_to`, `place` and
## `set_pose` drive them until `release(a)`. See "controllers" below.
##
## Cost: brains think in time slices (far agents less often), paths are
## budgeted per frame, MultiMesh instances are only rewritten for agents
## that moved or changed pose, and far agents draw fewer layers.

## A line somebody said (`at` in venue space, about head height). Sound and
## the walk's floating text both use it.
signal barked(person: Person, text: String, at: Vector3)
## About twice a second: how loud the crowd's chatter is near the focus,
## 0 (empty, silent) to 1 (a packed, talking house).
signal chatter(level: float)
## The crowd cheered (a goal; `strength` 0..1, `at` the middle of the cheer).
signal cheered(at: Vector3, strength: float)
## A crowd reaction that isn't a cheer: "gasp" (a fall), "clap" (a save),
## "zamboni" (the kids at the glass for the flood).
signal reacted(what: String, at: Vector3, strength: float)
## Someone walked in (`how`: "car", "foot") or went home.
signal person_arrived(person: Person, how: String)
signal person_left(person: Person)
## A claimed agent reached the point a controller sent them to.
signal agent_arrived(agent: Agent)

## In-game minutes per real second: how fast needs build and people dawdle.
## A match plays faster than the clock, so a fan gets peckish by the second
## intermission rather than never.
@export var time_scale := 0.5
@export var max_people := 900

const THINK_EVERY := 0.25   # seconds between a near brain's thoughts
const THINK_FAR := 1.2      # ... and a far one's
const NEAR := 28.0          # metres from the focus that count as near
const LOD_ITEM := 34.0      # beyond this, no held items
const LOD_HEAD := 80.0      # beyond this, bodies only
const THINKS_PER_FRAME := 90
const PATHS_PER_FRAME := 10
const PATH_BUDGET_US := 900  # ... or this much time, whichever comes first
const NAV_BATCH := 24        # paths per worker batch
## Far agents' instances are rewritten every few frames while they walk.
const FAR_WRITE_EVERY := 3
const WALK := 1.3
const SKATE := 3.2
const DOOR_REACH := 1.4
const SERVE_SECONDS := 6.0  # the canteen hands over a hot dog this often (real time)
const BARK_RANGE := 18.0
const CHAT_RANGE := 16.0    # small talk is only struck up this close to the focus
const STAFF_PLACES := {"canteen": "canteen", "pro_shop": "pro_shop", "skate_rental": "lobby", "office": "office",
	"zamboni_bay": "zamboni_bay", "plant_room": "plant_room", "lobby": "lobby", "bench": "bench", "penalty_box": "penalty_box"}
static var _HIDDEN := Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(0, -50, 0))

var map: PlaceMap
var world: StoryWorld
var event := {}
var phase := "before"
var agents: Array = []       # Agent
var focus: Node3D            # the camera or the walking owner: barks are heard near it
var rng := RandomNumberGenerator.new()
## Building-wide phase per session key (Agent.session); "" is `phase`.
var session_phase := {}
## Points of interest people turn to: "doris" (the resurfacer, set by
## whoever drives it), "puck". Venue space.
var poi := {}
## RinkLife driving the building from the sim (drive()), or null.
var life: RinkLife
## Sim minutes per real second while driven.
var sim_rate := 1.0
var stats := {"thinks": 0, "paths": 0, "writes": 0, "frame_us": 0}
## Time each part of the update into stats.sections (benchmarks).
var profile := false
## Another system drawing the ice (OnIceSession, scripts/world/events/):
## while one is set, players walk to the dressing room and hand off to it
## (`take(person)` when it has one) instead of skating here, and come back
## when it's cleared; spectators carry on watching.
var ice_controller: Object = null:
	set(c):
		ice_controller = c
		if c == null:
			_take_back_all()
		else:
			for a: Agent in agents:
				if a.brain.place == "ice" and a.delay <= 0.0 and not a.exiting and not a.owner_ref:
					_request_path(a)
## Search paths on worker threads (off: on the main thread, PATHS_PER_FRAME at most).
var threads := true
var _tick_us := 0

var _venue: Node3D
var _mm := {}                # layer key -> MultiMeshInstance3D
var _dirty := true
var _goal := false
var _seat_taken := {}
var _group_seat := {}        # group -> a seat index of the group
var _serve_t := 0.0
var _body: AnimatableBody3D
var _door_users := {}        # VenueDoor -> seconds since someone was near
var _talking: Agent
var _by_id := {}             # person id -> Agent
var _cursor := 0
var _path_q: Array = []      # agents waiting for a path
var _moving: Array = []      # agents with a path to walk
var _waking: Array = []      # agents not yet arrived (delay > 0)
var _lod_t := 0.0
var _chat_t := 0.0
var _chatter_t := 0.0
var _pending_lines: Array = []  # [seconds, Agent, text]
var _frame := 0
var _life_t := 0.0
var _door_at: Array = []     # Vector2 per map.doors entry, venue space
var _nav_task := -1          # WorkerThreadPool group task searching paths
var _nav_jobs: Array = []    # [Agent, route] in the running batch
var _nav_in: Array = []      # [from, to] global, per job
var _nav_out: Array = []     # PackedVector3Array per job, filled by the workers
var _nav_rid: RID
var _door_frame := -1000
var _staffed := false
var _staffed_t := 0.0


class Agent:
	var person: Person
	var brain: NpcBrain
	var pos := Vector3.ZERO
	var yaw := 0.0
	var path := PackedVector3Array()
	var step := 0
	var speed := WALK
	var phase := 0.0         # walk/skate cycle
	var think_t := 0.0       # seconds since the brain last thought
	var seat := -1
	var spot := 0            # which point of a place they use
	var queued_at := 0.0
	var shape: CollisionShape3D
	var keys := PackedStringArray()  # PeopleArt layer meshes
	var slots := PackedInt32Array()  # instance index in each layer's MultiMesh
	var base := Color()      # PeopleArt.instance_data, colours only
	var shown := -1          # pose last drawn
	var lod := 0             # 0 all layers, 1 no item, 2 body only
	var dirty := true        # its instances need writing
	var delay := 0.0         # seconds before they walk in
	var session := ""        # the session whose phase they follow
	var group := ""          # who they came with (Attendance)
	var reason := {}         # why they came (Attendance)
	var how := "car"         # car or foot: where they come from and go back to
	var exiting := false     # past the doors on the way to the car
	var leaving_told := false
	var owner_ref: WeakRef   # a controller that has claimed them, or null
	var hold_pose := -1      # a controller's pose
	var far := false
	var door_t := 0.0
	var shape_t := 0.0
	var handed := false       # skating in the ice controller's hands, not drawn here
	var rate_speed := -1.0
	var walk_rate := 0.0
	var skate_rate := 0.0


func _ready() -> void:
	_body = AnimatableBody3D.new()
	_body.name = "PeopleBodies"
	_body.sync_to_physics = false
	_body.collision_layer = 1 << (VenueKit.VENUE_LAYER - 1)
	_body.collision_mask = 0
	add_child(_body)
	WorldSound.attach(self)


## `ev`: the event (Attendance format). Builds the place map from the venue.
func setup(venue: Node3D, w: StoryWorld, ev: Dictionary) -> void:
	_venue = venue
	world = w
	event = ev
	rng.seed = hash(str(ev.get("kind", ""))) + int(ev.get("weekday", 0))
	# one walk graph per building: a second RinkPeople shares it
	map = venue.get_node_or_null("PlaceMap") as PlaceMap
	if map == null:
		map = PlaceMap.new()
		map.name = "PlaceMap"
		venue.add_child(map)
		map.build(venue)


## Run the building from the sim: RinkLife books the crowd for every session
## as its start comes up, staff come and go with their shifts, drop-ins wander
## in. `rate`: sim minutes per real second (the walk's clock).
func drive(l: RinkLife, rate: float) -> void:
	life = l
	sim_rate = maxf(rate, 0.0001)
	l.attach_live(self)


## The crowd for a match fixture (Career format), already in their seats:
## the valley's hockey fans first, then, for the big tiers, fans who drove in
## from out of town (generated people, still with names and opinions).
## `share`: the share of seats the venue expects filled.
static func for_match(venue: Node3D, fixture: Dictionary, share: float, w: StoryWorld = null) -> RinkPeople:
	var home = fixture.get("home", {})
	var tier := int(home.get("tier", 0)) if home is Dictionary else int(home.tier) if home else 0
	if w == null:
		w = StoryWorld.create(Cast.load_region(1))
	var kind := "beer_league" if tier < 3 else "senior_hockey"
	var ev := {"kind": kind, "weekday": 6 if tier >= 3 else 3, "hour": 19.5 if tier >= 3 else 21.5, "hours": 2.5,
		"pull": 0.6 + (0.3 if fixture.get("playoff", false) else 0.0), "ice_rep": 60.0}
	w.event_now = kind
	var people := RinkPeople.new()
	people.name = "People"
	venue.add_child(people)
	people.setup(venue, w, ev)
	ev.seats = people.map.seats.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(fixture.get("id", tier)))
	var came := Attendance.who_comes(w.cast, ev, rng)
	var want := int(round(people.map.seats.size() * share))
	var visitors := 0
	while came.size() < want and visitors < 2000:
		var batch := Townsfolk.generate({"archetypes": w.cast.archetypes.values().filter(func(a): return a.id in ["superfan", "hockey_parent", "beer_leaguer", "teen", "retiree_regular", "date_night"]),
			"surnames": ["Visitor"] if w.cast.archetypes.is_empty() else _surnames(w)}, "away_%d" % (visitors / 50), 50, rng.randi())
		for p in batch:
			if came.size() >= want:
				break
			w.cast.people[p.id] = p
			came.append({"person": p, "as": "watch", "reason": {"why": "fan", "for": "", "kind": kind, "group": "solo:" + p.id}})
		visitors += 50
		if batch.is_empty():
			break
	people.populate(came, true)
	people.set_phase("on")
	return people


static func _surnames(_w: StoryWorld) -> Array:
	var f := FileAccess.get_file_as_string(Cast.ARCHETYPES_PATH)
	var d = JSON.parse_string(f) if f != "" else {}
	return d.get("surnames", ["Visitor"]) if d is Dictionary else ["Visitor"]


## Puts everyone who came into the building. `in_place`: they're already at
## their spots (a match that starts on load); otherwise they walk in from the
## parking lot or the sidewalk over the next minute or two (each entry's
## "arrive", in minutes before the start, sets when, through `sim_rate`;
## without it, a random minute). `session`: the key whose phase they follow
## ("" for the building's `phase`). `kind`: the event kind (the setup event's
## by default). Returns the agents added.
func populate(came: Array, in_place := false, session := "", kind := "", start_in := 0.0) -> Array:
	if kind == "":
		kind = str(event.get("kind", ""))
	var added: Array = []
	var group_how := {}
	for e in came:
		if agents.size() >= max_people:
			break
		var p: Person = e.person
		if _by_id.has(p.id):
			continue
		var why: Dictionary = e.get("reason", {})
		var a := Agent.new()
		a.person = p
		a.reason = why
		a.group = str(e.get("group", why.get("group", "solo:" + p.id)))
		a.session = session
		a.brain = NpcBrain.make(p, e.as, kind, rng, world.cast.archetype(p.archetype) if world else {}, why)
		a.spot = rng.randi()
		if e.as == "work":
			var where := str(why.get("place", p.place_at(int(event.get("weekday", 0)), float(event.get("hour", 12.0)))))
			a.brain.home = STAFF_PLACES.get(where, "lobby")
			a.brain.place = a.brain.home
		if a.brain.home == "stands":
			a.seat = _take_seat(a)
			if a.seat < 0:
				a.brain.home = "glass"
				a.brain.place = "glass"
		a.speed = WALK * (0.8 if p.age >= 70 else (1.15 if p.is_kid() else 1.0))
		# the group shares a ride: whoever drives decides car or foot
		if not group_how.has(a.group) or (not p.is_kid() and p.commute == "car"):
			group_how[a.group] = "foot" if p.commute in ["foot", "bike"] else "car"
		# "arrive" is minutes before the start; the session starts in `start_in`
		var arrive := float(e.get("arrive", rng.randf_range(0.0, 30.0)))
		a.delay = maxf((start_in - arrive) / sim_rate, 0.0) if life else rng.randf_range(0.0, 60.0)
		if in_place or (life and start_in - arrive < -5.0):
			# already here: in their seat, at work, or (mid-session) on the ice
			a.delay = 0.0
			if a.brain.as_ == "play" and (start_in <= 0.0 if life else in_place):
				a.brain.activity = "skate"
				a.brain.place = "ice"
			a.pos = _target(a)
			if a.brain.place == "ice" and ice_taken():
				var room := map.point(a.brain.place_to_change(), a.spot)
				a.pos = room if room != Vector3.INF else a.pos
				_hand_off(a)
			a.brain.arrive()
		added.append(a)
		a.yaw = rng.randf() * TAU
		_add_shape(a)
		agents.append(a)
		_by_id[p.id] = a
	for a: Agent in added:
		a.how = group_how.get(a.group, "car")
		if not a.brain.arrived:
			# they come in from their car, or off the sidewalk, with their group
			var from := map.point("parking" if a.how == "car" else "street", hash(a.group))
			if from == Vector3.INF:
				from = map.point("entrance", a.spot)
			a.pos = from + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6)) if from != Vector3.INF else _target(a)
			if a.shape:
				a.shape.position = a.pos + Vector3(0, 0.85, 0)
			_request_path(a)
		if a.delay > 0.0:
			_waking.append(a)
	_dirty = true
	return added


## One more person, now (the tutorial's Gus, a late arrival). `at`: where
## they appear (venue space; INF walks them in from outside).
func add_person(p: Person, as_: String, why := {}, at := Vector3.INF, in_place := false) -> Agent:
	var added := populate([{"person": p, "as": as_, "reason": why, "arrive": 0.0}], in_place)
	if added.is_empty():
		return _by_id.get(p.id)
	var a: Agent = added[0]
	a.delay = 0.0
	_waking.erase(a)
	if at != Vector3.INF:
		a.pos = at
		a.path = PackedVector3Array()
		_moving.erase(a)
		_path_q.erase(a)
		a.brain.arrive()
	if a.shape:
		a.shape.position = a.pos + Vector3(0, 0.85, 0)
	a.dirty = true
	return a


func set_phase(p: String) -> void:
	phase = p


## The phase `a` lives by.
func phase_of(a: Agent) -> String:
	return phase if a.session == "" else str(session_phase.get(a.session, "before"))


## The crowd heard a goal: brains cheer on their next thought. `scorer`: the
## person id who scored, so their family goes wild.
func goal(scorer := "") -> void:
	_goal = true
	var n := 0
	var mid := Vector3.ZERO
	for a: Agent in agents:
		if a.brain.as_ != "watch" or a.delay > 0.0 or a.owner_ref:
			continue
		a.brain.react("goal", scorer != "" and a.brain.watch_for == scorer)
		a.dirty = true
		n += 1
		mid += a.pos
	if n > 0:
		cheered.emit(mid / n, clampf(n / 150.0, 0.15, 1.0))


## Someone on the ice went down: their people react, the stands gasp.
func fell(person_id: String) -> void:
	var at := Vector3.ZERO
	var x: Agent = _by_id.get(person_id)
	if x:
		at = x.pos
	var n := 0
	for a: Agent in agents:
		if a.brain.as_ != "watch" or a.delay > 0.0:
			continue
		var mine := a.brain.watch_for == person_id
		if mine or a.pos.distance_to(at) < 25.0:
			a.brain.react("fall", mine)
			a.dirty = true
			n += 1
			if a.brain.bark_topic != "":
				_bark(a)
	if n > 0:
		reacted.emit("gasp", at, clampf(n / 80.0, 0.1, 1.0))


func count() -> int:
	return agents.size()


func agent_of(person_id: String) -> Agent:
	return _by_id.get(person_id)


## Agents that are in the building now (walked in), optionally only those
## `pred(a)` accepts.
func present(pred := Callable()) -> Array:
	return agents.filter(func(a): return a.delay <= 0.0 and (not pred.is_valid() or pred.call(a)))


func nearest(at: Vector3, reach := 2.5) -> Agent:
	var best: Agent = null
	var bd := reach
	for a: Agent in agents:
		if a.delay > 0.0:
			continue
		var d := a.pos.distance_to(at)
		if d < bd:
			best = a
			bd = d
	return best


## Starts a conversation with `a`; they stop and face the speaker at `from`.
func talk(a: Agent, from := Vector3.INF) -> Conversation:
	_talking = a
	a.dirty = true
	if from != Vector3.INF:
		a.yaw = atan2(-(from.x - a.pos.x), -(from.z - a.pos.z))
	world.quests.notify("talk", {"to": a.person.id})
	var why := a.reason.duplicate()
	why["activity"] = a.brain.activity
	return Conversation.open(world, a.person, why)


func end_talk() -> void:
	if _talking:
		_talking.dirty = true
	_talking = null


## How the night went for everyone still here, for Attendance.settle.
func extras(session := "") -> Dictionary:
	var out := {}
	for a: Agent in agents:
		if session != "" and a.session != session:
			continue
		var v := a.brain.verdict()
		if not v.is_empty():
			out[a.person.id] = v
	return out


func longest_line() -> float:
	var m := 0.0
	for a: Agent in agents:
		m = maxf(m, a.brain.line_minutes)
	return m


## `a` heads home now, and everyone who came for them goes too.
func send_home(a: Agent) -> void:
	a.brain.send_home()
	_request_path(a)
	if a.brain.as_ == "play" and not a.leaving_told:
		a.leaving_told = true
		_tell_group_leaving(a)


## Everyone in `group` heads home (an event let them go, a kid got hurt).
func send_group_home(group: String) -> void:
	for a: Agent in agents:
		if a.group == group and not a.owner_ref:
			a.brain.send_home()
			_request_path(a)


# --------------------------------------------------------------- controllers

## Hand `a` to an outside controller (an on-ice event, a drill, the tutorial):
## their brain stops, and they only move when the controller says. Returns
## false if somebody else already has them.
func claim(a: Agent, by: Object) -> bool:
	if a.owner_ref and a.owner_ref.get_ref() != null and a.owner_ref.get_ref() != by:
		return false
	a.owner_ref = weakref(by)
	a.dirty = true
	return true


func release(a: Agent) -> void:
	a.owner_ref = null
	a.hold_pose = -1
	a.dirty = true
	if is_instance_valid(map):
		_request_path(a)


func is_claimed(a: Agent) -> bool:
	return a.owner_ref != null and a.owner_ref.get_ref() != null


## Walk (or skate, on the ice) a claimed agent to `to` (venue space) along
## the walk graph; agent_arrived fires when they get there.
func move_to(a: Agent, to: Vector3, speed := -1.0) -> void:
	if PlaceMap.on_ice(a.pos) or PlaceMap.on_ice(to):
		a.path = PackedVector3Array([a.pos, to])
	else:
		a.path = map.path(a.pos, to)
	a.step = 0
	a.speed = speed if speed > 0.0 else (SKATE if PlaceMap.on_ice(to) else WALK)
	if not a in _moving:
		_moving.append(a)


## Put a claimed agent exactly here, facing `yaw` (a drill moves skaters
## itself every frame). Pass `phase` to advance their stride.
func place(a: Agent, pos: Vector3, yaw: float, phase_ := -1.0) -> void:
	a.pos = pos
	a.yaw = yaw
	if phase_ >= 0.0:
		a.phase = phase_
	a.path = PackedVector3Array()
	a.dirty = true
	if a.shape:
		a.shape.position = pos + Vector3(0, 0.85, 0)


## Hold a pose (NpcBrain.Pose) while claimed; -1 goes back to the brain's.
func set_pose(a: Agent, pose: int) -> void:
	a.hold_pose = pose
	a.dirty = true


## The agents skating in a session (or everyone on the ice), for an event
## controller to take over.
func on_ice(session := "") -> Array:
	return agents.filter(func(a): return a.delay <= 0.0 and (session == "" or a.session == session) \
		and a.brain.as_ == "play" and PlaceMap.on_ice(a.pos) and not a.handed)


## True while an external controller has the ice.
func ice_taken() -> bool:
	return ice_controller != null and is_instance_valid(ice_controller)


## `a` reached the dressing room on the way to the ice: the controller has
## them now; they wait here, unseen, until it lets them go.
func _hand_off(a: Agent) -> void:
	a.handed = true
	a.dirty = true
	a.path = PackedVector3Array()
	if a.shape:
		a.shape.position = a.pos + Vector3(0, -5.0, 0)
	if ice_controller.has_method("take"):
		ice_controller.take(a.person)


func _take_back(a: Agent) -> void:
	if not a.handed:
		return
	a.handed = false
	a.dirty = true
	if a.shape:
		a.shape.position = a.pos + Vector3(0, 0.85, 0)


func _take_back_all() -> void:
	for a: Agent in agents:
		if a.handed:
			_take_back(a)
			_request_path(a)


# ------------------------------------------------------------------- update

func _process(dt: float) -> void:
	if map == null:
		return
	var t0 := Time.get_ticks_usec()
	_tick_us = t0
	_frame += 1
	if life:
		_life_t -= dt
		if _life_t <= 0.0:
			_life_t = 0.5
			life.tick_live(self)
	var ice_wet := world != null and world.sim != null and world.sim.ice.wetness() > 0.25
	_staffed_t -= dt
	if _staffed_t <= 0.0:
		_staffed_t = 0.5
		_staffed = _canteen_staffed()
	var base_ctx := {"goal": _goal, "air_c": 7.0, "canteen_open": _staffed, "ice_wet": ice_wet}
	_goal = false
	_wake(dt)
	_tick("wake")
	_think_slice(dt, base_ctx)
	_tick("think")
	_paths()
	_tick("paths")
	_move_all(dt)
	_tick("move")
	_serve(dt)
	_doors(dt)
	_small_talk(dt)
	_lines(dt)
	_lod(dt)
	_chatter(dt)
	_tick("misc")
	var gone: Array = []
	for a: Agent in agents:
		if a.brain.is_gone() and not a.owner_ref:
			gone.append(a)
	for a in gone:
		_remove(a)
	_tick("remove")
	_draw()
	_tick("draw")
	stats.frame_us = Time.get_ticks_usec() - t0


## Per-section timing when `profile` is on (stats.sections, microseconds).
func _tick(section: String) -> void:
	if not profile:
		return
	var now := Time.get_ticks_usec()
	var secs: Dictionary = stats.get("sections", {})
	secs[section] = int(secs.get(section, 0)) + now - _tick_us
	stats["sections"] = secs
	_tick_us = now


## People still on their way in appear when their time comes.
func _wake(dt: float) -> void:
	if _waking.is_empty():
		return
	var still: Array = []
	for a: Agent in _waking:
		a.delay -= dt
		if a.delay > 0.0:
			still.append(a)
			continue
		a.dirty = true
		person_arrived.emit(a.person, a.how)
		if rng.randf() < 0.08:
			a.brain.bark_topic = "arrive_" + a.how
			_bark(a)
	_waking = still


## Brains think in slices: each frame visits a share of the agents, far ones
## less often, and at most THINKS_PER_FRAME of them actually think.
func _think_slice(dt: float, base_ctx: Dictionary) -> void:
	var n := agents.size()
	if n == 0:
		return
	for a: Agent in agents:
		a.think_t += dt
	var slice := maxi(ceili(n / 6.0), 24)
	var thinks := 0
	var fpos := _focus_pos()
	for i in mini(slice, n):
		if thinks >= THINKS_PER_FRAME:
			break
		_cursor = (_cursor + 1) % n
		var a: Agent = agents[_cursor]
		if a.delay > 0.0 or a.owner_ref:
			continue
		if a.brain.as_ == "play" and a.brain.activity == "leave" and not a.leaving_told:
			a.leaving_told = true
			_tell_group_leaving(a)
		var interval := THINK_FAR if a.far else THINK_EVERY
		var urgent: bool = base_ctx.goal
		if a.think_t < interval and not urgent:
			continue
		var elapsed := a.think_t
		a.think_t = 0.0
		thinks += 1
		var ctx := base_ctx.duplicate()
		ctx.phase = phase_of(a)
		var target: Agent = _by_id.get(a.brain.watch_for) if a.brain.watch_for != "" else null
		var target_on_ice := target != null and target.delay <= 0.0 and (target.handed or PlaceMap.on_ice(target.pos))
		if a != _talking and a.brain.think(elapsed * time_scale, ctx):
			_request_path(a)
		if a.brain.fidget(elapsed, target_on_ice):
			a.dirty = true
		if a.brain.arrived and a.step >= a.path.size():
			_face_target(a, target)
		if a.brain.as_ == "play" and a.brain.activity == "leave" and not a.leaving_told:
			a.leaving_told = true
			_tell_group_leaving(a)
		if a.brain.bark_topic != "":
			_bark(a)
	stats.thinks = thinks


## A watcher turns toward the person they came for (seated: within the
## seat's arc), or the resurfacer when it's out.
func _face_target(a: Agent, target: Agent) -> void:
	var look := Vector3.INF
	if target and target.handed:
		look = Vector3.ZERO  # out there somewhere: the ice
	elif target and target.delay <= 0.0 and target.pos.distance_to(a.pos) < 70.0:
		look = target.pos
	elif str(a.reason.get("why", "")) == "zamboni" and poi.has("doris"):
		look = poi.doris
	if look == Vector3.INF or a == _talking:
		return
	var want := atan2(-(look.x - a.pos.x), -(look.z - a.pos.z))
	if a.seat >= 0 and a.brain.place == "stands":
		var f: Vector3 = map.seats[a.seat][1]
		var face := atan2(-f.x, -f.z)
		want = face + clampf(wrapf(want - face, -PI, PI), -0.9, 0.9)
	if absf(wrapf(want - a.yaw, -PI, PI)) > 0.08:
		a.yaw = lerp_angle(a.yaw, want, 0.5)
		a.dirty = true


## A player is heading out: everyone who came for them goes with them.
func _tell_group_leaving(player: Agent) -> void:
	for a: Agent in agents:
		if a != player and a.brain.watch_for == player.person.id and not a.owner_ref:
			a.brain.person_left()
			_request_path(a)
			if rng.randf() < 0.3:
				a.brain.bark_topic = "leave_together"
				_bark(a)


func _request_path(a: Agent) -> void:
	if not a in _path_q:
		_path_q.append(a)


## At most PATHS_PER_FRAME path searches a frame; the rest wait their turn.
## Paths are searched on worker threads, a batch at a time: the agents in
## the batch stand still for a frame or two, the main thread never waits.
## Without a baked walk mesh (or threads) they're worked out here.
func _paths() -> void:
	var done := 0
	if _nav_task >= 0:
		if not WorkerThreadPool.is_group_task_completed(_nav_task):
			return
		WorkerThreadPool.wait_for_group_task_completion(_nav_task)
		_nav_task = -1
		var inv := _venue.global_transform.affine_inverse() if _venue else Transform3D.IDENTITY
		for i in _nav_jobs.size():
			var job: Array = _nav_jobs[i]
			var a: Agent = job[0]
			if not a in agents:
				continue
			var r: Dictionary = job[1]
			var mid: PackedVector3Array = _nav_out[i]
			if mid.is_empty():
				mid = PackedVector3Array([r.from, r.to])
			else:
				for k in mid.size():
					mid[k] = inv * mid[k]
			_apply_route(a, r, mid)
			done += 1
		_nav_jobs.clear()
		_nav_out.clear()
	var threaded := map.baked and map.is_inside_tree() and threads
	var t0 := Time.get_ticks_usec()
	var batch := 0
	while not _path_q.is_empty() and batch < NAV_BATCH:
		if not threaded and done > 0 and (done >= PATHS_PER_FRAME or Time.get_ticks_usec() - t0 >= PATH_BUDGET_US):
			break
		var a: Agent = _path_q.pop_front()
		if not a in agents:
			continue
		var r := _route(a)
		if r.is_empty():
			continue
		if not r.nav:
			_apply_route(a, r, PackedVector3Array())
		elif threaded:
			_nav_jobs.append([a, r])
			batch += 1
		else:
			_apply_route(a, r, map.path(r.from, r.to))
		done += 1
	if not _nav_jobs.is_empty():
		var xf := _venue.global_transform if _venue else Transform3D.IDENTITY
		_nav_rid = map.get_world_3d().navigation_map
		_nav_out.resize(_nav_jobs.size())
		_nav_in.resize(_nav_jobs.size())
		for i in _nav_jobs.size():
			var r: Dictionary = _nav_jobs[i][1]
			_nav_in[i] = [xf * r.from, xf * r.to]
			_nav_out[i] = PackedVector3Array()
		_nav_task = WorkerThreadPool.add_group_task(_nav_one, _nav_jobs.size(), -1, false, "people paths")
	stats.paths = done


func _nav_one(i: int) -> void:
	var ends: Array = _nav_in[i]
	_nav_out[i] = NavigationServer3D.map_get_path(_nav_rid, ends[0], ends[1], true)


func _exit_tree() -> void:
	if _nav_task >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_nav_task)
		_nav_task = -1


func _plan(a: Agent) -> void:
	var r := _route(a)
	if not r.is_empty():
		_apply_route(a, r, map.path(r.from, r.to) if r.nav else PackedVector3Array())


## Where `a` walks next: {"nav": a walk-mesh leg from `from` to `to` is
## needed, "pre" and "post": straight bits before and after it (the bench
## gate and the ice)}; {} when there's nowhere to go.
func _route(a: Agent) -> Dictionary:
	var to := _target(a)
	if a.exiting:
		to = map.point("parking" if a.how == "car" else "street", hash(a.group))
	if to == Vector3.INF:
		a.path = PackedVector3Array()
		a.brain.arrive()
		return {}
	if a.brain.place == "ice" and not a.exiting and ice_taken():
		if a.handed:
			return {}
		var room := map.point(a.brain.place_to_change(), a.spot)
		if room == Vector3.INF or a.pos.distance_to(room) < 1.0 or PlaceMap.on_ice(a.pos):
			# already skating when the controller took over: it has them now
			if room != Vector3.INF:
				a.pos = room
			_hand_off(a)
			return {}
		return _stand_legs({"nav": true, "from": a.pos, "to": room, "pre": PackedVector3Array(), "post": PackedVector3Array()})
	if a.brain.place == "ice" and not a.exiting:
		if PlaceMap.on_ice(a.pos):
			return {"nav": false, "pre": PackedVector3Array([a.pos, to]), "post": PackedVector3Array()}
		var gate := map.point("bench", a.spot)
		var door := Vector3(signf(gate.x) * 3.05 if gate.x != 0.0 else 3.05, 0, signf(gate.z) * 12.6)
		if gate == Vector3.INF:
			return {"nav": false, "pre": PackedVector3Array([a.pos, door, to]), "post": PackedVector3Array()}
		return {"nav": true, "from": a.pos, "to": gate, "pre": PackedVector3Array(), "post": PackedVector3Array([door, to])}
	if PlaceMap.on_ice(a.pos):
		var gate := Vector3(3.05, 0, -12.6)
		return _stand_legs({"nav": true, "from": gate, "to": to, "pre": PackedVector3Array([a.pos]), "post": PackedVector3Array()})
	return _stand_legs({"nav": true, "from": a.pos, "to": to, "pre": PackedVector3Array(), "post": PackedVector3Array()})


## The stand rows are steps the walk mesh can't climb: a seat is reached
## from the walkway at the foot of its column, straight up the rows (and
## left the same way down).
func _stand_legs(r: Dictionary) -> Dictionary:
	var f0 := _stand_foot(r.from)
	if f0 != Vector3.INF:
		var pre: PackedVector3Array = r.pre.duplicate()
		pre.append_array(PackedVector3Array([r.from, f0]))
		r.pre = pre
		r.from = f0
	var f1 := _stand_foot(r.to)
	if f1 != Vector3.INF:
		var post := PackedVector3Array([f1, r.to])
		post.append_array(r.post)
		r.post = post
		r.to = f1
	return r


## The walkway spot below a point in the side stands, or INF when `p`
## isn't up in the stands.
static func _stand_foot(p: Vector3) -> Vector3:
	if p.y < 0.6 or absf(p.z) < Venue.STAND_FRONT - 0.3:
		return Vector3.INF
	return Vector3(p.x, 0.0, signf(p.z) * (Venue.STAND_FRONT - 0.9))


func _apply_route(a: Agent, r: Dictionary, mid: PackedVector3Array) -> void:
	if a.handed:
		_take_back(a)
	var path: PackedVector3Array = r.pre.duplicate()
	path.append_array(mid)
	path.append_array(r.post)
	a.path = path
	a.step = 0
	a.speed = SKATE if a.brain.place == "ice" and a.brain.pose != NpcBrain.Pose.SKATE_WOBBLY else WALK * (0.8 if a.person.age >= 70 else 1.0)
	if a.brain.place == "ice" and a.brain.pose == NpcBrain.Pose.SKATE_WOBBLY:
		a.speed = 0.9
	if not a in _moving:
		_moving.append(a)
	a.dirty = true


## Where `a` should stand for their current place.
func _target(a: Agent) -> Vector3:
	var place := a.brain.place
	if place == "stands" and a.seat >= 0:
		return map.seats[a.seat][0] + _seat_offset(a)
	if place == "canteen":
		var line := _line()
		var i := line.find(a)
		return map.point("canteen", i if i >= 0 else line.size())
	if place == "ice":
		a.spot += 1
		return map.ice_point(a.spot)
	if place == "lobby" and a.brain.activity == "wait_for":
		# the group waits together
		return map.point("lobby", hash(a.group)) + Vector3(fmod(a.spot * 0.37, 1.2) - 0.6, 0, fmod(a.spot * 0.71, 1.2) - 0.6)
	if a.brain.as_ == "work" and not place in ["hall", "ice", "stands", "away"]:
		# one worker per work point; with none free, a round of the hall
		var w := map.claim(place, a.person.id)
		return w if w != Vector3.INF else map.point("hall", a.spot)
	map.release(a.person.id)
	var p := map.point(place, a.spot)
	if p == Vector3.INF and place in ["hall", "vending"]:
		p = map.point("lobby", a.spot)
	return p


func _seat_offset(a: Agent) -> Vector3:
	return PeopleArt.seat_offset(a.person.look, a.person.age)


func _move_all(dt: float) -> void:
	if _moving.is_empty():
		return
	var still: Array = []
	for a: Agent in _moving:
		if a.delay > 0.0:
			still.append(a)
			continue
		if a == _talking:
			still.append(a)
			continue
		_move(a, dt)
		if a.step < a.path.size():
			still.append(a)
	_moving = still


func _move(a: Agent, dt: float) -> void:
	if a.step >= a.path.size():
		return
	var to := a.path[a.step]
	var d := to - a.pos
	var flat := Vector3(d.x, 0, d.z)
	var stepd := a.speed * dt
	if flat.length() <= stepd:
		a.pos = to
		a.step += 1
		if a.step >= a.path.size():
			a.dirty = true
			_arrived(a)
		return
	var dir := flat.normalized()
	a.pos += dir * stepd
	a.pos.y = lerpf(a.pos.y, to.y, clampf(stepd / maxf(flat.length(), 0.01), 0.0, 1.0))
	a.yaw = lerp_angle(a.yaw, atan2(-dir.x, -dir.z), clampf(dt * 8.0, 0.0, 1.0))
	if a.rate_speed != a.speed:
		# the stride rate only changes with the speed: work it out once
		a.rate_speed = a.speed
		a.walk_rate = PeopleArt.walk_phase_rate(a.speed, a.person.look, a.person.age)
		a.skate_rate = PeopleArt.skate_phase_rate(a.speed)
	a.phase = fmod(a.phase + dt * (a.skate_rate if PlaceMap.on_ice(a.pos) else a.walk_rate), 1.0)
	a.door_t -= dt
	if a.door_t <= 0.0:
		a.door_t = 0.25
		_open_doors_near(a)
	# bodies the owner and the puck bump into: near ones keep up, far ones lag
	a.shape_t -= dt
	if a.shape and a.shape_t <= 0.0:
		a.shape_t = 0.0 if not a.far else 0.5
		a.shape.position = a.pos + Vector3(0, 0.85, 0)


func _arrived(a: Agent) -> void:
	a.path = PackedVector3Array()
	if a.owner_ref:
		agent_arrived.emit(a)
		return
	if a.brain.place == "ice" and ice_taken() and not a.handed and not a.exiting:
		_hand_off(a)
		a.brain.arrive()
		return
	if a.brain.place == "stands" and a.seat >= 0:
		var f: Vector3 = map.seats[a.seat][1]
		a.yaw = atan2(-f.x, -f.z)
	elif a.brain.place == "glass":
		a.yaw = atan2(a.pos.x * 0.2, a.pos.z)  # look at the ice
	if a.brain.activity == "queue":
		a.queued_at = Time.get_ticks_msec() / 1000.0
	if a.brain.activity == "leave":
		# through the doors, then back to the car or off down the sidewalk
		var out := map.point("parking" if a.how == "car" else "street", hash(a.group))
		if not a.exiting and out != Vector3.INF and a.pos.distance_to(out) > 2.0:
			a.exiting = true
			_request_path(a)
			return
	a.brain.arrive()
	if a.brain.activity == "leave":
		a.brain.arrived = true


func _line() -> Array:
	var line := agents.filter(func(x): return x.brain.activity == "queue")
	line.sort_custom(func(x, y): return x.queued_at < y.queued_at if x.brain.arrived and y.brain.arrived else x.brain.arrived)
	return line


func _canteen_staffed() -> bool:
	for a: Agent in agents:
		if a.brain.as_ == "work" and a.brain.home == "canteen" and a.delay <= 0.0:
			return true
	return false


## The canteen hands over one order every few seconds; the line shuffles up.
func _serve(dt: float) -> void:
	_serve_t += dt
	if _serve_t < SERVE_SECONDS:
		return
	_serve_t = 0.0
	var line := _line()
	if line.is_empty() or not line[0].brain.arrived or not _canteen_staffed():
		return
	var a: Agent = line[0]
	a.brain.served()
	_request_path(a)
	for i in range(1, line.size()):
		if line[i].brain.arrived:
			_request_path(line[i])


func _take_seat(a: Agent) -> int:
	var seats := map.seats
	if seats.is_empty():
		return -1
	# families and friends sit together: next to someone from the group
	if _group_seat.has(a.group):
		var g: int = _group_seat[a.group]
		for off in [1, -1, 2, -2, 3, -3, 4, -4]:
			var j: int = g + off
			if j >= 0 and j < seats.size() and not _seat_taken.has(j) and (seats[j][0] as Vector3).distance_to(seats[g][0]) < 2.6:
				_seat_taken[j] = a
				return j
	# near centre ice and low down first
	for t in 24:
		var i := rng.randi() % seats.size()
		var p: Vector3 = seats[i][0]
		var w := 1.0 / (1.0 + absf(p.x) * 0.09) / (1.0 + p.y * 0.18)
		if not _seat_taken.has(i) and rng.randf() < w * 1.5:
			_seat_taken[i] = a
			_group_seat[a.group] = i
			return i
	for i in seats.size():
		if not _seat_taken.has(i):
			_seat_taken[i] = a
			_group_seat[a.group] = i
			return i
	return -1


func _open_doors_near(a: Agent) -> void:
	if _door_at.size() != map.doors.size() or Engine.get_process_frames() - _door_frame > 120:
		# where the doors are, in venue space (doors don't move, mostly)
		_door_frame = Engine.get_process_frames()
		_door_at.clear()
		var inv := _venue.global_transform.affine_inverse() if _venue else Transform3D.IDENTITY
		for d in map.doors:
			var dp: Vector3 = inv * d.global_position if is_instance_valid(d) and d.is_inside_tree() else Vector3.INF
			_door_at.append(Vector2(dp.x, dp.z))
	var me := Vector2(a.pos.x, a.pos.z)
	for i in _door_at.size():
		if me.distance_squared_to(_door_at[i]) < DOOR_REACH * DOOR_REACH:
			var d = map.doors[i]
			if not is_instance_valid(d):
				continue
			if not d.is_open:
				d.open()
			_door_users[d] = 0.0


## Doors swing shut a couple of seconds after the last person goes through.
func _doors(dt: float) -> void:
	for d in _door_users.keys():
		_door_users[d] += dt
		if _door_users[d] > 2.5:
			if is_instance_valid(d) and d.is_open:
				d.close()
			_door_users.erase(d)


func _focus_pos() -> Vector3:
	if focus and is_instance_valid(focus) and focus.is_inside_tree():
		return (_venue.global_transform.affine_inverse() if _venue else Transform3D.IDENTITY) * focus.global_position
	return Vector3.INF


func _bark(a: Agent) -> void:
	var topic := a.brain.bark_topic
	a.brain.bark_topic = ""
	if world == null:
		return
	var fp := _focus_pos()
	if fp != Vector3.INF and fp.distance_to(a.pos) > BARK_RANGE:
		return
	var text := Conversation.bark(world, a.person, topic, a.reason)
	if text != "":
		barked.emit(a.person, text, a.pos + Vector3(0, 2.0, 0))


## Two people standing or sitting near each other strike up a conversation
## now and then: they face each other, gesture, and trade a couple of lines
## the owner can overhear.
func _small_talk(dt: float) -> void:
	_chat_t -= dt
	if _chat_t > 0.0:
		return
	_chat_t = rng.randf_range(1.2, 2.5)
	var fp := _focus_pos()
	# end the chats that have run their course
	for a: Agent in agents:
		if a.brain.chat_with != "" and a.brain.idle_left <= 0.0:
			a.brain.chat_with = ""
	var near: Array = []
	for a: Agent in agents:
		if a.delay > 0.0 or a.owner_ref or a == _talking or not a.brain.arrived or not a.brain.activity in NpcBrain.STILL:
			continue
		if a.brain.as_ == "work" or a.brain.chat_with != "":
			continue
		if fp != Vector3.INF and a.pos.distance_to(fp) > CHAT_RANGE:
			continue
		near.append(a)
	if near.size() < 2:
		return
	var a: Agent = near[rng.randi() % near.size()]
	var best: Agent = null
	var bd := 2.4
	for b: Agent in near:
		if b == a:
			continue
		var d := a.pos.distance_to(b.pos)
		var known := b.group == a.group or b.person.id in a.person.friends or b.person.id in a.person.family
		if d < bd and (known or d < 1.5):
			best = b
			bd = d
	if best == null:
		return
	var ex := _exchange(a, best)
	if ex.is_empty():
		return
	var secs := rng.randf_range(5.0, 9.0)
	for pair in [[a, best], [best, a]]:
		var x: Agent = pair[0]
		var y: Agent = pair[1]
		x.brain.chat_with = y.person.id
		x.brain.idle_pose = NpcBrain.Pose.TALK if not x.brain.pose in NpcBrain.SEATED else NpcBrain.Pose.SIT
		x.brain.idle_left = secs
		if x.seat < 0:
			x.yaw = atan2(-(y.pos.x - x.pos.x), -(y.pos.z - x.pos.z))
		x.dirty = true
	var head := Vector3(0, 2.0, 0)
	barked.emit(a.person, world.fill(str(ex[0]), a.person), a.pos + head)
	if ex.size() > 1:
		_pending_lines.append([2.6, best, world.fill(str(ex[1]), best.person)])


## A two-line exchange that suits the pair (parents, teens, kids, elders).
func _exchange(a: Agent, b: Agent) -> Array:
	var all: Array = Conversation._load(Conversation.LIFE).get("small_talk", [])
	if all.is_empty() or world == null:
		return []
	var tags := ["any"]
	for x in [a, b]:
		var p: Person = x.person
		if p.age < 13:
			tags.append("kid")
		elif p.age < 20:
			tags.append("teen")
		elif p.age >= 65:
			tags.append("elder")
		if p.age >= 20:
			tags.append("adult")
		if str(x.reason.get("why", "")) in ["parent", "grandparent"] or p.archetype in ["hockey_parent", "figure_parent", "coffee_coach"]:
			tags.append("parent")
	var fits := all.filter(func(e): return str(e.get("who", "any")) in tags \
		and (str(e.get("who", "any")) in ["any", "adult", "parent"] or tags.count(str(e.who)) >= 2 or str(e.who) == "elder" and tags.has("elder")))
	if fits.is_empty():
		return []
	return fits[rng.randi() % fits.size()].get("lines", [])


func _lines(dt: float) -> void:
	if _pending_lines.is_empty():
		return
	var still: Array = []
	for l in _pending_lines:
		l[0] -= dt
		if l[0] > 0.0:
			still.append(l)
		elif l[1] in agents:
			barked.emit(l[1].person, str(l[2]), l[1].pos + Vector3(0, 2.0, 0))
	_pending_lines = still


## Near and far, every half second: far agents think less and draw fewer layers.
func _lod(dt: float) -> void:
	_lod_t -= dt
	if _lod_t > 0.0:
		return
	_lod_t = 0.5
	var fp := _focus_pos()
	if fp == Vector3.INF:
		return
	for a: Agent in agents:
		var d := a.pos.distance_to(fp)
		a.far = d > NEAR
		var lod := 0 if d < LOD_ITEM else (1 if d < LOD_HEAD else 2)
		if lod != a.lod:
			a.lod = lod
			a.dirty = true


## How loud the crowd is around the focus, for Sound.
func _chatter(dt: float) -> void:
	_chatter_t -= dt
	if _chatter_t > 0.0:
		return
	_chatter_t = 0.5
	var fp := _focus_pos()
	var level := 0.0
	for a: Agent in agents:
		if a.delay > 0.0:
			continue
		var d := a.pos.distance_to(fp) if fp != Vector3.INF else 20.0
		var w := 1.0 / (1.0 + d * d / 120.0)
		var loud := 1.0
		var shown := a.brain.shown_pose()
		if shown in [NpcBrain.Pose.CHEER, NpcBrain.Pose.SIT_CHEER]:
			loud = 4.0
		elif shown in [NpcBrain.Pose.TALK, NpcBrain.Pose.CLAP, NpcBrain.Pose.SIT_CLAP]:
			loud = 2.0
		elif a.brain.as_ == "play" or shown in [NpcBrain.Pose.SIT_PHONE, NpcBrain.Pose.QUEUE]:
			loud = 0.4
		level += w * loud
	chatter.emit(clampf(level / 40.0, 0.0, 1.0))


func _remove(a: Agent) -> void:
	if map:
		map.release(a.person.id)
	if a.seat >= 0:
		_seat_taken.erase(a.seat)
	if a.shape:
		a.shape.queue_free()
	agents.erase(a)
	_by_id.erase(a.person.id)
	_moving.erase(a)
	_path_q.erase(a)
	_waking.erase(a)
	if a == _talking:
		_talking = null
	_cursor = 0
	_dirty = true
	person_left.emit(a.person)
	# a player who went home: their people go too
	for b: Agent in agents:
		if b.brain.watch_for == a.person.id and not b.brain.their_left:
			b.brain.person_left()
			_request_path(b)


func _add_shape(a: Agent) -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	var h := 1.7 if not a.person.is_kid() else clampf(0.7 + a.person.age * 0.07, 0.8, 1.7)
	cap.radius = 0.25 if not a.person.is_kid() else 0.18
	cap.height = h
	cs.shape = cap
	cs.position = a.pos + Vector3(0, h * 0.5, 0)
	_body.add_child(cs)
	a.shape = cs


# --------------------------------------------------------------------- draw

func _draw() -> void:
	if _dirty:
		_rebuild()
	var writes := 0
	var frame := Engine.get_process_frames()
	for a: Agent in agents:
		var moving := a.step < a.path.size() and a.delay <= 0.0
		if not a.dirty and not moving:
			continue
		if not a.dirty and a.lod > 0 and (frame + a.spot) % FAR_WRITE_EVERY != 0:
			continue
		a.dirty = false
		writes += 1
		var pose := a.brain.shown_pose()
		if a.hold_pose >= 0:
			pose = a.hold_pose
		elif a == _talking:
			pose = NpcBrain.Pose.TALK if not a.brain.pose in NpcBrain.SEATED else NpcBrain.Pose.SIT
		elif moving and pose in [NpcBrain.Pose.SIT, NpcBrain.Pose.QUEUE, NpcBrain.Pose.SKATE, NpcBrain.Pose.SKATE_WOBBLY,
				NpcBrain.Pose.SPIN, NpcBrain.Pose.FALL, NpcBrain.Pose.SIT_PHONE, NpcBrain.Pose.SIT_SIP, NpcBrain.Pose.LEAN,
				NpcBrain.Pose.STRETCH, NpcBrain.Pose.SIT_CLAP, NpcBrain.Pose.SIT_CHEER, NpcBrain.Pose.CHEER]:
			pose = (NpcBrain.Pose.SKATE if a.speed >= SKATE else NpcBrain.Pose.SKATE_WOBBLY) if PlaceMap.on_ice(a.pos) else NpcBrain.Pose.WALK
		var xf := Transform3D(Basis(Vector3.UP, a.yaw), a.pos)
		if a.delay > 0.0 or a.handed:
			xf = _HIDDEN
		var data := PeopleArt.with_pose(a.base, pose, a.phase, moving, a.speed if moving else 0.0)
		for k in a.keys.size():
			var mm: MultiMesh = _mm[a.keys[k]].multimesh
			var hide := (k == 1 and a.lod >= 2) or (k == 2 and a.lod >= 1)
			mm.set_instance_transform(a.slots[k], _HIDDEN if hide else xf)
			mm.set_instance_custom_data(a.slots[k], data)
	stats.writes = writes


## One MultiMesh per body, head and held-item mesh (PeopleArt.layer_keys), so
## a stand full of different people needs a few dozen draws, not hundreds.
## Every agent keeps a fixed instance slot in each of its layers until the
## next rebuild, so only the ones that change need writing.
func _rebuild() -> void:
	_dirty = false
	var counts := {}
	for a: Agent in agents:
		if a.keys.is_empty():
			a.keys = PeopleArt.layer_keys(a.person.look, a.person.age)
			var look: Dictionary = a.person.look.duplicate()
			look["id"] = a.person.id
			a.base = PeopleArt.instance_data(look, 0, 0.0, a.person.age)
		a.slots.resize(a.keys.size())
		for k in a.keys.size():
			var key: String = a.keys[k]
			a.slots[k] = int(counts.get(key, 0))
			counts[key] = a.slots[k] + 1
		a.dirty = true
	for key in _mm.keys():
		if not counts.has(key):
			_mm[key].queue_free()
			_mm.erase(key)
	for key in counts:
		if not _mm.has(key):
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "People_" + str(key).validate_node_name()
			mmi.cast_shadow = Look.cast()
			mmi.multimesh = PeopleArt.multimesh(key, counts[key])
			add_child(mmi)
			_mm[key] = mmi
		var m: MultiMesh = _mm[key].multimesh
		if m.instance_count != counts[key]:
			m.instance_count = counts[key]
