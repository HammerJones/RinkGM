class_name TutorialGuide
extends Node
## Gus's first-day handoff (data/world/tutorial.json). On the owner's first
## morning Gus is still in town, waiting inside the front doors with two
## coffees before his flight to Florida. When the owner comes near he asks
## whether they want his help (his dialogue tree's tutorial_ask node):
##   yes: he walks ahead to each step's waypoint, says his piece, and moves on
##        when the step's done (a RinkSim job through RinkLife, a walk flag, a
##        room, a screen, a session, a flood, a quest, a signal);
##   no:  the tutorial is off for this career (saved), and he leaves.
## Talking to him mid-tutorial lets the owner skip a step or stop.
##
## The guide drives Gus as a claimed RinkPeople agent. Steps are data: other
## systems add theirs with `add_step()` and finish them with `notify()`.
##
##   var guide := TutorialGuide.create(people, life, venue, walker, story.flags)
##   add_child(guide)
##   guide.wants_talk.connect(func(a): talk_panel.show_conversation(people.talk(a, me)))

const PATH := "res://data/world/tutorial.json"
## Gus is in the building until his taxi (sim hour).
const LEAVES_AT := 14.0

## Gus wants a word: open a conversation with `agent`.
signal wants_talk(agent: RinkPeople.Agent)
signal step_started(step: Dictionary, index: int)
signal step_done(step: Dictionary, index: int)
## "done" (all steps), "declined" (no thanks), "stopped" (partway).
signal finished(how: String)

var data := {}
var steps: Array = []
var index := -1
var people: RinkPeople
var life: RinkLife
var world: StoryWorld
var venue: Node3D
var walker: Node3D
var agent: RinkPeople.Agent
## Where the choice is saved: the walk's flags (a career saves them), else
## WorldSettings "tutorial".
var flags := {}
var use_settings := false

var _asked := false
var _hits := {}            # "job:plant_round" -> true
var _marker: Label3D
var _face_t := 0.0
var _step_minute := 0
var _leaving := false


static func load_data() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var v = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return v if v is Dictionary else {}


## `flags_`: the dictionary the choice is saved in (WalkStory.flags inside a
## career); pass null to use WorldSettings.
static func create(people_: RinkPeople, life_: RinkLife, venue_: Node3D, walker_: Node3D, flags_ = null) -> TutorialGuide:
	var g := TutorialGuide.new()
	g.name = "TutorialGuide"
	g.people = people_
	g.life = life_
	g.world = life_.world if life_ else people_.world
	g.venue = venue_
	g.walker = walker_
	g.use_settings = flags_ == null
	g.flags = flags_ if flags_ != null else {}
	g.data = load_data()
	g.steps = g.data.get("steps", []).duplicate(true)
	if life_:
		life_.happened.connect(g._on_happened)
	return g


## "" (not asked yet), "on", "off" (declined), "done".
func state() -> String:
	if use_settings:
		return WorldSettings.get_string("tutorial")
	return str(flags.get("tutorial", ""))


func set_state(s: String) -> void:
	flags["tutorial"] = s
	if use_settings:
		WorldSettings.set_value("tutorial", s)


## Whether Gus should be here at all: the first day, before his taxi, and
## the owner hasn't turned him down or finished with him.
func wanted() -> bool:
	var st := state()
	if st in ["off", "done"]:
		return false
	var sim: RinkSim = world.sim if world else null
	if sim and (sim.day > 0 or sim.minute / 60.0 >= LEAVES_AT):
		return false
	return true


func _ready() -> void:
	if not wanted() or data.is_empty():
		return
	_spawn()
	if state() == "on":
		index = clampi(int(flags.get("tutorial_step", 0)), 0, steps.size() - 1)
		world.flags["tutorial_answered"] = true
		world.flags["tutorial_running"] = true
		_start_step()


func _spawn() -> void:
	var gus: Person = world.cast.person(str(data.get("guide", "gus_tremblay")))
	if gus == null or people == null:
		return
	var meet: Dictionary = data.get("meet", {})
	var at: Array = meet.get("at", [-44.2, 0.0, 1.6])
	agent = people.add_person(gus, "work", {"why": "tutorial", "for": "", "place": "lobby", "group": "solo:" + gus.id}, Vector3(float(at[0]), float(at[1]), float(at[2])), true)
	if agent == null:
		return
	people.claim(agent, self)
	people.place(agent, agent.pos, float(meet.get("yaw", PI * 0.5)))
	people.set_pose(agent, NpcBrain.Pose.SIP)
	world.flags["gus_here"] = true
	people.agent_arrived.connect(_on_arrived)


## Another system tells the guide something happened: ("job", {"job"}),
## ("screen", {"id"}), ("talk", {"to"}), ("signal", {"name"}).
func notify(kind: String, d: Dictionary) -> void:
	match kind:
		"job": _hits["job:" + str(d.get("job", ""))] = true
		"screen": _hits["screen:" + str(d.get("id", ""))] = true
		"talk": _hits["talk:" + str(d.get("to", ""))] = true
		"signal": _hits["signal:" + str(d.get("name", ""))] = true


## Adds a step after the step `after_id` (or at the end).
func add_step(step: Dictionary, after_id := "") -> void:
	var at := steps.size()
	for i in steps.size():
		if str(steps[i].get("id", "")) == after_id:
			at = i + 1
	steps.insert(at, step)
	if at <= index:
		index += 1


func current() -> Dictionary:
	return steps[index] if index >= 0 and index < steps.size() else {}


## The HUD line while it runs, or "".
func hud_line() -> String:
	if state() != "on" or current().is_empty():
		return ""
	return "GUS (%d/%d): %s" % [index + 1, steps.size(), str(current().get("hint", ""))]


func _on_happened(what: String, d: Dictionary) -> void:
	if what == "job_done":
		notify("job", d)


func _process(dt: float) -> void:
	if agent == null or people == null or not agent in people.agents:
		return
	var me := _owner_pos()
	# the owner walks in: Gus asks
	if state() == "" and not _asked and me != Vector3.INF and me.distance_to(agent.pos) < float(data.get("meet", {}).get("reach", 4.5)):
		_asked = true
		wants_talk.emit(agent)
	if world.flags.has("tutorial_yes") and state() == "":
		set_state("on")
		world.flags["tutorial_running"] = true
		index = 0
		_start_step()
	elif world.flags.has("tutorial_no") and state() == "":
		set_state("off")
		_leave("declined")
	if state() == "on":
		if world.flags.has("tutorial_stop"):
			world.flags.erase("tutorial_stop")
			set_state("done")
			_leave("stopped")
			return
		if world.flags.has("tutorial_skip"):
			world.flags.erase("tutorial_skip")
			_next_step()
		elif not current().is_empty() and _step_done(current()):
			_say(str(current().get("done_say", "")))
			step_done.emit(current(), index)
			_next_step()
	_face_t -= dt
	if _face_t <= 0.0 and me != Vector3.INF and agent.step >= agent.path.size():
		_face_t = 0.6
		people.place(agent, agent.pos, atan2(-(me.x - agent.pos.x), -(me.z - agent.pos.z)))
	# taxi time
	if world.sim and world.sim.minute / 60.0 >= LEAVES_AT and not _leaving:
		if state() == "on":
			set_state("done")
		_leave("done")


func _owner_pos() -> Vector3:
	if walker == null or not is_instance_valid(walker) or not walker.is_inside_tree():
		return Vector3.INF
	return venue.global_transform.affine_inverse() * walker.global_position if venue else walker.global_position


func _next_step() -> void:
	index += 1
	flags["tutorial_step"] = index
	if index >= steps.size():
		set_state("done")
		world.flags.erase("tutorial_running")
		_leave("done")
		return
	_start_step()


func _start_step() -> void:
	var s := current()
	if s.is_empty():
		return
	_step_minute = world.sim.day * 1440 + world.sim.minute if world.sim else 0
	world.tokens["tutorial_hint"] = str(s.get("hint", ""))
	world.tokens["tutorial_say"] = str(s.get("say", ""))
	_say(str(s.get("say", "")))
	var to := _waypoint(s)
	if to != Vector3.INF:
		people.set_pose(agent, -1)
		people.move_to(agent, to + Vector3(0.9, 0, 0.9), RinkPeople.WALK * 1.1)
		_mark(to, str(s.get("label", "")))
	step_started.emit(s, index)


func _on_arrived(a: RinkPeople.Agent) -> void:
	if a != agent:
		return
	people.set_pose(agent, NpcBrain.Pose.SIP if not _leaving else NpcBrain.Pose.WALK)
	if _leaving:
		people.release(agent)
		agent.brain.send_home()
		people._request_path(agent)


func _waypoint(s: Dictionary) -> Vector3:
	var w = s.get("waypoint", "")
	if w is Array and w.size() == 3:
		return Vector3(float(w[0]), float(w[1]), float(w[2]))
	if people.map == null:
		return Vector3.INF
	return people.map.point(str(w), 0)


func _mark(at: Vector3, label: String) -> void:
	if _marker == null:
		_marker = Label3D.new()
		_marker.name = "TutorialMarker"
		_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_marker.no_depth_test = true
		_marker.fixed_size = true
		_marker.pixel_size = 0.0012
		_marker.font_size = 28
		_marker.outline_size = 8
		_marker.modulate = Color("f2c14e")
		(venue if venue else people).add_child(_marker)
	_marker.text = "v  %s  v" % label
	_marker.position = at + Vector3(0, 2.4, 0)
	_marker.visible = label != ""


func _say(text: String) -> void:
	if text == "" or agent == null:
		return
	people.barked.emit(agent.person, text, agent.pos + Vector3(0, 2.1, 0))


func _step_done(s: Dictionary) -> bool:
	for c in s.get("done", []):
		if _cond(c):
			return true
	return false


func _cond(c: Dictionary) -> bool:
	for k in c:
		var v = c[k]
		match k:
			"job": return _hits.has("job:" + str(v))
			"screen": return _hits.has("screen:" + str(v))
			"talk": return _hits.has("talk:" + str(v))
			"signal": return _hits.has("signal:" + str(v))
			"flag": return flags.has(str(v)) or world.flags.has(str(v))
			"quest": return world.quests.status(str(v[0])) == str(v[1])
			"room":
				var me := _owner_pos()
				if me == Vector3.INF or venue == null or not venue.has_method("room_at"):
					return false
				var r = venue.room_at(me + Vector3(0, 0.5, 0))
				return r != null and str(r.room_id) == str(v)
			"session":
				return world.event_now == str(v)
			"flood":
				if world.sim == null:
					return false
				for f in world.sim.flood_log:
					if f.get("ok", false) and int(f.get("day", -1)) * 1440 + int(f.get("minute", 0)) >= _step_minute:
						return true
				return false
	return false


func _leave(how: String) -> void:
	if _leaving:
		return
	_leaving = true
	world.flags.erase("gus_here")
	world.flags.erase("tutorial_running")
	if _marker:
		_marker.visible = false
	if how != "declined":
		_say(str(data.get("leave_line", "")))
	finished.emit(how)
	if agent and agent in people.agents:
		people.release(agent)
		agent.brain.send_home()
		people._request_path(agent)
