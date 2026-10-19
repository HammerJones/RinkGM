class_name WalkPeople
extends Node
## Everyone in the building for the venue walk (scripts/venue/venue_walk.gd),
## in place of the venue's old seated crowd: RinkPeople on the walk's own sim,
## driven by RinkLife, so the stands hold the people who came for what's on
## the ice, staff come in for their shifts and the rink rats drift in after
## school. T (or X on a pad) talks to whoever's nearest; overheard lines
## float over people's heads; on the first morning Gus offers to show the
## owner around (TutorialGuide).
##
## The walk adds it with one line (`WalkPeople.attach(self)`). Options:
##   --event=<kind>   a demo crowd for that event instead of the sim's
##                    bookings (people_walk.tscn), with --hour= --weekday=
##                    and --event-on=<seconds> (when play starts, default 45)
##   --no-people      keep the old seated crowd (VenueCrowd)
##   --shot=<png> --shot-after=<s>  save a screenshot and quit
##   --people-cam=x,y,z,lx,ly,lz   look from a fixed camera (with --shot)

## people_walk.tscn sets this so its walk always has an event crowd.
static var default_event := ""

const BARK_SECONDS := 4.5
const BARKS_MAX := 7

var walk: Node
var venue: Node3D
var walker: Node3D
var people: RinkPeople
var life: RinkLife
var world: StoryWorld
var panel: TalkPanel
var guide: TutorialGuide
var event_kind := ""
var _barks: Array = []      # [Label3D, seconds left]
var _shot := ""
var _shot_t := 20.0
var _layer: CanvasLayer


## Adds the walk's people. `walk_` is the venue walk (it has venue, walker,
## story and _label).
static func attach(walk_: Node) -> WalkPeople:
	var wp := WalkPeople.new()
	wp.name = "WalkPeople"
	wp.walk = walk_
	walk_.add_child(wp)
	return wp


func _ready() -> void:
	venue = walk.get("venue")
	walker = walk.get("walker")
	var story: WalkStory = walk.get("story")
	var hour := -1.0
	var wd := 6
	var on_after := 45.0
	event_kind = default_event
	var cam := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--event="):
			event_kind = a.trim_prefix("--event=")
		elif a.begins_with("--hour="):
			hour = a.trim_prefix("--hour=").to_float()
		elif a.begins_with("--weekday="):
			wd = a.trim_prefix("--weekday=").to_int()
		elif a.begins_with("--event-on="):
			on_after = a.trim_prefix("--event-on=").to_float()
		elif a.begins_with("--shot="):
			_shot = a.trim_prefix("--shot=")
		elif a.begins_with("--shot-after="):
			_shot_t = a.trim_prefix("--shot-after=").to_float()
		elif a.begins_with("--people-cam="):
			cam = a.trim_prefix("--people-cam=")
	# the old seated mannequins give way to people
	if venue.has_method("set_attendance"):
		venue.set_attendance(0.0)
	var crowd = venue.get("crowd")
	if crowd:
		crowd.visible = false
	var cast := Cast.load_region(1)
	people = RinkPeople.new()
	people.name = "People"
	if story and event_kind == "":
		life = RinkLife.create(story.sim, cast)
		world = life.world
		if story.life == null:
			story.life = life
		var link = story.link
		if link and link.career.world.has("people"):
			life.apply_state(link.career.world.people)
		tree_exiting.connect(_save)
		venue.add_child(people)
		people.setup(venue, world, {"kind": "", "weekday": story.sim.weekday(), "hour": story.sim.minute / 60.0})
		people.time_scale = 0.35
		people.set_phase("on")
		people.drive(life, WalkStory.TIME_SCALE)
		guide = TutorialGuide.create(people, life, venue, walker, story.flags if link else null)
		add_child(guide)
		guide.wants_talk.connect(_open_talk)
		if walk.has_signal("screen_requested"):
			walk.screen_requested.connect(func(id: String, _sim: RinkSim) -> void: guide.notify("screen", {"id": id}))
	else:
		if event_kind == "":
			event_kind = "public_skate"
		world = StoryWorld.create(cast)
		world.event_now = event_kind
		if hour < 0.0:
			hour = _usual_hour(event_kind)
		world.flags["_hour"] = hour
		world.flags["_day"] = wd
		var ev := {"kind": event_kind, "weekday": wd, "hour": hour, "hours": 2.0, "ice_rep": 60.0}
		venue.add_child(people)
		people.setup(venue, world, ev)
		ev.seats = people.map.seats.size()
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var came := Attendance.who_comes(cast, ev, rng)
		came.append_array(_staff_for(cast, wd, hour))
		people.populate(came, on_after <= 0.0)
		people.set_phase("on" if on_after <= 0.0 else "before")
		if on_after > 0.0:
			get_tree().create_timer(on_after).timeout.connect(func() -> void: people.set_phase("on"))
	world.owner_name = "Sam" if world.owner_name == "the owner" else world.owner_name
	people.focus = walker
	people.barked.connect(_on_bark)
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	panel = TalkPanel.new()
	panel.closed.connect(_on_talk_closed)
	_layer.add_child(panel)
	if cam != "":
		var v := cam.split_floats(",")
		_fixed_cam.call_deferred(Vector3(v[0], v[1], v[2]), Vector3(v[3], v[4], v[5]))
	print("walk people: %s, %d people" % [event_kind if event_kind != "" else "the sim's day", people.count()])


## Staff on shift for a demo event: the canteen, the pro shop, the office.
func _staff_for(cast: Cast, wd: int, hour: float) -> Array:
	var out: Array = []
	for id in ["lorraine_duffy", "josie_bautista", "bev_kowalchuk", "earl_bratt"]:
		var p: Person = cast.person(id)
		if p and not p.on_shift(wd, hour):
			var place: String = {"lorraine_duffy": "canteen", "josie_bautista": "canteen", "bev_kowalchuk": "pro_shop", "earl_bratt": "zamboni_bay"}[id]
			out.append({"person": p, "as": "work", "reason": {"why": "work", "place": place, "until": hour + 3.0}})
	return out


func _fixed_cam(from: Vector3, at: Vector3) -> void:
	await get_tree().process_frame
	var c := Camera3D.new()
	c.fov = 62.0
	c.far = 300.0
	venue.add_child(c)
	c.look_at_from_position(from, at, Vector3.UP)
	c.current = true
	people.focus = c


## When this kind of event usually happens, from the contracts.
func _usual_hour(kind: String) -> float:
	for o in RinkContracts.ORGS:
		if o.get("event", "") == kind:
			return float(o.slots[0][1])
	return 13.0


func _save() -> void:
	var story: WalkStory = walk.get("story") if is_instance_valid(walk) else null
	if life and story and story.link:
		story.link.career.world["people"] = life.state()


func _unhandled_input(e: InputEvent) -> void:
	if panel == null or panel.visible:
		return
	if (e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_T) \
			or (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_X):
		var a := people.nearest(_me(), 2.5)
		if a:
			_open_talk(a)
			get_viewport().set_input_as_handled()


func _me() -> Vector3:
	return venue.global_transform.affine_inverse() * walker.global_position


func _open_talk(a: RinkPeople.Agent) -> void:
	if panel.visible:
		return
	walker.set("wish", Vector3.ZERO)
	panel.show_conversation(people.talk(a, _me()))
	if guide:
		guide.notify("talk", {"to": a.person.id})
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_talk_closed() -> void:
	people.end_talk()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_bark(p: Person, text: String, at: Vector3) -> void:
	if _barks.size() >= BARKS_MAX:
		var old = _barks.pop_front()
		old[0].queue_free()
	var l := Label3D.new()
	l.text = "%s: %s" % [p.known_as, text]
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.0035
	l.width = 900.0
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.outline_size = 8
	l.position = at
	venue.add_child(l)
	_barks.append([l, BARK_SECONDS])


func _process(dt: float) -> void:
	if panel and panel.visible:
		walker.set("wish", Vector3.ZERO)
	else:
		var label: Label = walk.get("_label")
		if label:
			var a := people.nearest(_me(), 2.5)
			if a:
				label.text += "\n[T] TALK TO %s" % a.person.known_as.to_upper()
			if guide and guide.hud_line() != "":
				label.text += "\n" + guide.hud_line()
	for b in _barks.duplicate():
		b[1] -= dt
		if b[1] <= 0.0:
			b[0].queue_free()
			_barks.erase(b)
		elif b[1] < 1.0:
			b[0].modulate.a = b[1]
	if _shot != "":
		_shot_t -= dt
		if _shot_t <= 0.0:
			var img := get_viewport().get_texture().get_image()
			img.save_png(_shot)
			print("walk people: saved %s (%d people, %.1f ms people update)" % [_shot, people.count(), people.stats.frame_us / 1000.0])
			_shot = ""
			get_tree().quit()
