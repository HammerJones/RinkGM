class_name RinkPeople
extends Node3D
## Everyone in the building, live: fans in their seats, parents at the glass,
## skaters on the ice, the canteen line, the kid who won't stop asking about
## Doris. Each body is a Person with an NpcBrain; this node walks them along
## the PlaceMap, opens the doors they pass through, serves the canteen line,
## gives them solid bodies the puck and the owner bump into, and draws them
## all with one MultiMesh per body shape (PeopleArt).
##
##   var people := RinkPeople.new()
##   venue.add_child(people)
##   people.setup(venue, world, {"kind": "beer_league", ...})
##   people.populate(Attendance.who_comes(world.cast, ev, rng), true)
##
## Talk to someone: `var a := people.nearest(pos, 2.0)`, then
## `people.talk(a)` returns a Conversation (they stop and face you).

signal barked(person: Person, text: String, at: Vector3)

## In-game minutes per real second: how fast needs build and people dawdle.
## A match plays faster than the clock, so a fan gets peckish by the second
## intermission rather than never.
@export var time_scale := 0.5
@export var max_people := 900

const THINK_EVERY := 0.25   # seconds between a brain's thoughts
const WALK := 1.3
const SKATE := 3.2
const DOOR_REACH := 1.4
const SERVE_SECONDS := 6.0  # the canteen hands over a hot dog this often (real time)
const BARK_RANGE := 18.0
const STAFF_PLACES := {"canteen": "canteen", "pro_shop": "pro_shop", "skate_rental": "lobby", "office": "office",
	"zamboni_bay": "zamboni_bay", "plant_room": "plant_room", "lobby": "lobby", "bench": "bench", "penalty_box": "penalty_box"}

var map: PlaceMap
var world: StoryWorld
var event := {}
var phase := "before"
var agents: Array = []       # Agent
var focus: Node3D            # the camera or the walking owner: barks are heard near it
var rng := RandomNumberGenerator.new()

var _venue: Node3D
var _mm := {}                # shape key -> MultiMeshInstance3D
var _dirty := true
var _goal := false
var _seat_taken := {}
var _serve_t := 0.0
var _body: AnimatableBody3D
var _door_users := {}        # VenueDoor -> seconds since someone was near
var _talking: Agent


class Agent:
	var person: Person
	var brain: NpcBrain
	var pos := Vector3.ZERO
	var yaw := 0.0
	var path := PackedVector3Array()
	var step := 0
	var speed := WALK
	var phase := 0.0         # walk/skate cycle
	var think_t := 0.0
	var seat := -1
	var spot := 0            # which point of a place they use
	var queued_at := 0.0
	var shape: CollisionShape3D
	var keys := PackedStringArray()  # PeopleArt layer meshes
	var delay := 0.0         # seconds before they walk in


func _ready() -> void:
	_body = AnimatableBody3D.new()
	_body.name = "PeopleBodies"
	_body.sync_to_physics = false
	_body.collision_layer = 1 << (VenueKit.VENUE_LAYER - 1)
	_body.collision_mask = 0
	add_child(_body)


## `ev`: the event (Attendance format). Builds the place map from the venue.
func setup(venue: Node3D, w: StoryWorld, ev: Dictionary) -> void:
	_venue = venue
	world = w
	event = ev
	rng.seed = hash(str(ev.get("kind", ""))) + int(ev.get("weekday", 0))
	map = PlaceMap.new()
	map.name = "PlaceMap"
	venue.add_child(map)
	map.build(venue)


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
			came.append({"person": p, "as": "watch"})
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
## entrance over the next minute or two.
func populate(came: Array, in_place := false) -> void:
	var kind := str(event.get("kind", ""))
	for e in came:
		if agents.size() >= max_people:
			break
		var p: Person = e.person
		var a := Agent.new()
		a.person = p
		a.brain = NpcBrain.make(p, e.as, kind, rng, world.cast.archetype(p.archetype) if world else {})
		a.spot = rng.randi()
		if e.as == "work":
			var where := p.place_at(int(event.get("weekday", 0)), float(event.get("hour", 12.0)))
			a.brain.home = STAFF_PLACES.get(where, "lobby")
			a.brain.place = a.brain.home
		if a.brain.home == "stands":
			a.seat = _take_seat(a)
			if a.seat < 0:
				a.brain.home = "glass"
				a.brain.place = "glass"
		a.speed = WALK * (0.8 if p.age >= 70 else (1.15 if p.is_kid() else 1.0))
		var start := _target(a)
		if in_place or e.as == "work":
			a.pos = start
			a.brain.arrive()
		else:
			a.pos = map.point("entrance", a.spot)
			if a.pos == Vector3.INF:
				a.pos = start
			a.delay = rng.randf_range(0.0, 60.0)
			_plan(a)
		a.yaw = rng.randf() * TAU
		_add_shape(a)
		agents.append(a)
	_dirty = true


func set_phase(p: String) -> void:
	phase = p


## The crowd heard a goal: brains cheer on their next thought.
func goal() -> void:
	_goal = true


func count() -> int:
	return agents.size()


func nearest(at: Vector3, reach := 2.5) -> Agent:
	var best: Agent = null
	var bd := reach
	for a: Agent in agents:
		var d := a.pos.distance_to(at)
		if d < bd and a.delay <= 0.0:
			best = a
			bd = d
	return best


## Starts a conversation with `a`; they stop and face the speaker at `from`.
func talk(a: Agent, from := Vector3.INF) -> Conversation:
	_talking = a
	if from != Vector3.INF:
		a.yaw = atan2(-(from.x - a.pos.x), -(from.z - a.pos.z))
	world.quests.notify("talk", {"to": a.person.id})
	return Conversation.open(world, a.person)


func end_talk() -> void:
	_talking = null


## How the night went for everyone still here, for Attendance.settle.
func extras() -> Dictionary:
	var out := {}
	for a: Agent in agents:
		var v := a.brain.verdict()
		if not v.is_empty():
			out[a.person.id] = v
	return out


func longest_line() -> float:
	var m := 0.0
	for a: Agent in agents:
		m = maxf(m, a.brain.line_minutes)
	return m


# ------------------------------------------------------------------- update

func _process(dt: float) -> void:
	if map == null:
		return
	var minutes := dt * time_scale
	var ctx := {"phase": phase, "goal": _goal, "air_c": 7.0, "canteen_open": _canteen_staffed(),
		"ice_wet": world != null and world.sim != null and world.sim.ice.wetness() > 0.25}
	_goal = false
	var gone: Array = []
	for a: Agent in agents:
		if a.delay > 0.0:
			a.delay -= dt
			continue
		a.think_t -= dt
		if a.think_t <= 0.0 or ctx.goal:
			var mins := minutes + (THINK_EVERY * time_scale if a.think_t <= 0.0 else 0.0)
			a.think_t = THINK_EVERY * rng.randf_range(0.8, 1.2)
			if a != _talking and a.brain.think(mins, ctx):
				_plan(a)
		_move(a, dt)
		if a.brain.bark_topic != "":
			_bark(a)
		if a.brain.is_gone():
			gone.append(a)
	_serve(dt)
	_doors(dt)
	for a in gone:
		_remove(a)
	_draw()


func _plan(a: Agent) -> void:
	var to := _target(a)
	if to == Vector3.INF:
		a.path = PackedVector3Array()
		a.brain.arrive()
		return
	if a.brain.place == "ice":
		if PlaceMap.on_ice(a.pos):
			a.path = PackedVector3Array([a.pos, to])
		else:
			var gate := map.point("bench", a.spot)
			var door := Vector3(signf(gate.x) * 3.05 if gate.x != 0.0 else 3.05, 0, signf(gate.z) * 12.6)
			a.path = map.path(a.pos, gate) if gate != Vector3.INF else PackedVector3Array([a.pos])
			a.path.append_array(PackedVector3Array([door, to]))
	elif PlaceMap.on_ice(a.pos):
		var gate := Vector3(3.05, 0, -12.6)
		a.path = PackedVector3Array([a.pos, gate])
		a.path.append_array(map.path(gate, to))
	else:
		a.path = map.path(a.pos, to)
	a.step = 0
	a.speed = SKATE if a.brain.place == "ice" and a.brain.pose != NpcBrain.Pose.SKATE_WOBBLY else WALK
	if a.brain.place == "ice" and a.brain.pose == NpcBrain.Pose.SKATE_WOBBLY:
		a.speed = 0.9


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
	return map.point(place, a.spot)


func _seat_offset(a: Agent) -> Vector3:
	return PeopleArt.seat_offset(a.person.look, a.person.age)


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
			_arrived(a)
		return
	var dir := flat.normalized()
	a.pos += dir * stepd
	a.pos.y = lerpf(a.pos.y, to.y, clampf(stepd / maxf(flat.length(), 0.01), 0.0, 1.0))
	a.yaw = lerp_angle(a.yaw, atan2(-dir.x, -dir.z), clampf(dt * 8.0, 0.0, 1.0))
	var rate := PeopleArt.skate_phase_rate(a.speed) if PlaceMap.on_ice(a.pos) else PeopleArt.walk_phase_rate(a.speed, a.person.look, a.person.age)
	a.phase = fmod(a.phase + dt * rate, 1.0)
	_open_doors_near(a)
	if a.shape:
		a.shape.position = a.pos + Vector3(0, 0.85, 0)


func _arrived(a: Agent) -> void:
	a.path = PackedVector3Array()
	if a.brain.place == "stands" and a.seat >= 0:
		var f: Vector3 = map.seats[a.seat][1]
		a.yaw = atan2(-f.x, -f.z)
	elif a.brain.place == "glass":
		a.yaw = atan2(a.pos.x * 0.2, a.pos.z)  # look at the ice
	if a.brain.activity == "queue":
		a.queued_at = Time.get_ticks_msec() / 1000.0
	a.brain.arrive()
	if a.brain.activity == "leave":
		a.brain.arrived = true


func _line() -> Array:
	var line := agents.filter(func(x): return x.brain.activity == "queue")
	line.sort_custom(func(x, y): return x.queued_at < y.queued_at if x.brain.arrived and y.brain.arrived else x.brain.arrived)
	return line


func _canteen_staffed() -> bool:
	for a: Agent in agents:
		if a.brain.as_ == "work" and a.brain.home == "canteen":
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
	_plan(a)
	for i in range(1, line.size()):
		if line[i].brain.arrived:
			line[i].path = map.path(line[i].pos, map.point("canteen", i - 1))
			line[i].step = 0


func _take_seat(a: Agent) -> int:
	var seats := map.seats
	if seats.is_empty():
		return -1
	# near centre ice and low down first, families together-ish
	for t in 24:
		var i := rng.randi() % seats.size()
		var p: Vector3 = seats[i][0]
		var w := 1.0 / (1.0 + absf(p.x) * 0.09) / (1.0 + p.y * 0.18)
		if not _seat_taken.has(i) and rng.randf() < w * 1.5:
			_seat_taken[i] = a
			return i
	for i in seats.size():
		if not _seat_taken.has(i):
			_seat_taken[i] = a
			return i
	return -1


func _open_doors_near(a: Agent) -> void:
	for d in map.doors:
		if not is_instance_valid(d):
			continue
		var dp: Vector3 = d.global_position
		if _venue:
			dp = _venue.global_transform.affine_inverse() * dp
		if Vector2(dp.x - a.pos.x, dp.z - a.pos.z).length() < DOOR_REACH:
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


func _bark(a: Agent) -> void:
	var topic := a.brain.bark_topic
	a.brain.bark_topic = ""
	if world == null or (focus and focus.global_position.distance_to(global_transform * a.pos) > BARK_RANGE):
		return
	var text := Conversation.bark(world, a.person, topic)
	if text != "":
		barked.emit(a.person, text, a.pos + Vector3(0, 2.0, 0))


func _remove(a: Agent) -> void:
	if a.seat >= 0:
		_seat_taken.erase(a.seat)
	if a.shape:
		a.shape.queue_free()
	agents.erase(a)
	_dirty = true


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
	var filled := {}  # layer key -> next instance
	for a: Agent in agents:
		var pose := a.brain.pose
		var moving := a.step < a.path.size() and a.delay <= 0.0
		if a == _talking:
			pose = NpcBrain.Pose.TALK
		elif moving and pose in [NpcBrain.Pose.SIT, NpcBrain.Pose.QUEUE, NpcBrain.Pose.SKATE, NpcBrain.Pose.SKATE_WOBBLY, NpcBrain.Pose.SPIN, NpcBrain.Pose.FALL]:
			pose = (NpcBrain.Pose.SKATE if a.speed >= SKATE else NpcBrain.Pose.SKATE_WOBBLY) if PlaceMap.on_ice(a.pos) else NpcBrain.Pose.WALK
		var xf := Transform3D(Basis(Vector3.UP, a.yaw), a.pos)
		if a.delay > 0.0:
			xf = Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(0, -50, 0))
		var data := PeopleArt.instance_data(a.person.look, pose, a.phase, a.person.age, moving, a.speed if moving else 0.0)
		for key in a.keys:
			var mm: MultiMesh = _mm[key].multimesh
			var i := int(filled.get(key, 0))
			filled[key] = i + 1
			mm.set_instance_transform(i, xf)
			mm.set_instance_custom_data(i, data)


## One MultiMesh per body, head and held-item mesh (PeopleArt.layer_keys), so
## a stand full of different people needs a few dozen draws, not hundreds.
func _rebuild() -> void:
	_dirty = false
	var counts := {}
	for a: Agent in agents:
		a.keys = PeopleArt.layer_keys(a.person.look, a.person.age)
		for key in a.keys:
			counts[key] = int(counts.get(key, 0)) + 1
	for key in _mm.keys():
		if not counts.has(key):
			_mm[key].queue_free()
			_mm.erase(key)
	for key in counts:
		if not _mm.has(key):
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "People_" + str(key).validate_node_name()
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.multimesh = PeopleArt.multimesh(key, counts[key])
			add_child(mmi)
			_mm[key] = mmi
		var m: MultiMesh = _mm[key].multimesh
		if m.instance_count != counts[key]:
			m.instance_count = counts[key]
