extends "res://scripts/venue/venue_walk.gd"
## The venue walk with its people: pick an event and walk around among
## everyone who came for it. Talk to anyone.
##
##   godot --path . res://scenes/world/people_walk.tscn -- --event=figure_practice [--hour=6] [--weekday=2]
##
## Walk as in the venue walk; T / X talks to whoever is nearest, 1-9 or
## arrows and Enter pick what to say. `--event=` takes any kind from
## data/world/events.json; `--shot=<png>` saves a screenshot after
## `--shot-after=` seconds (default 20) from `--venue-cam=` and quits.

var people: RinkPeople
var world: StoryWorld
var panel: TalkPanel
var _barks: Array = []      # [Label3D, seconds left]
var _shot := ""
var _shot_t := 20.0


func _ready() -> void:
	super._ready()
	var kind := "public_skate"
	var hour := -1.0
	var wd := 6
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--event="):
			kind = a.trim_prefix("--event=")
		elif a.begins_with("--hour="):
			hour = a.trim_prefix("--hour=").to_float()
		elif a.begins_with("--weekday="):
			wd = a.trim_prefix("--weekday=").to_int()
		elif a.begins_with("--shot="):
			_shot = a.trim_prefix("--shot=")
		elif a.begins_with("--shot-after="):
			_shot_t = a.trim_prefix("--shot-after=").to_float()
	var cast := Cast.load_region(1)
	world = StoryWorld.create(cast)
	world.owner_name = "Sam"
	world.event_now = kind
	if hour < 0.0:
		hour = _usual_hour(kind)
	world.flags["_hour"] = hour
	world.flags["_day"] = wd
	var ev := {"kind": kind, "weekday": wd, "hour": hour, "hours": 2.0, "ice_rep": 60.0}
	people = RinkPeople.new()
	people.name = "People"
	venue.add_child(people)
	people.setup(venue, world, ev)
	ev.seats = people.map.seats.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	people.populate(Attendance.who_comes(cast, ev, rng), false)
	people.set_phase("before")
	people.focus = walker
	people.barked.connect(_on_bark)
	panel = TalkPanel.new()
	panel.closed.connect(_on_talk_closed)
	_label.get_parent().add_child(panel)
	get_tree().create_timer(45.0).timeout.connect(func(): people.set_phase("on"))
	print("people walk: %s, %d people came" % [kind, people.count()])


## When this kind of event usually happens, from the contracts.
func _usual_hour(kind: String) -> float:
	for o in RinkContracts.ORGS:
		if o.get("event", "") == kind:
			return float(o.slots[0][1])
	return 13.0


func _unhandled_input(e: InputEvent) -> void:
	if panel and panel.visible:
		return
	if (e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_T) \
			or (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_X):
		_talk()
		return
	super._unhandled_input(e)


func _talk() -> void:
	var me := venue.global_transform.affine_inverse() * walker.global_position
	var a := people.nearest(me, 2.5)
	if a == null:
		return
	walker.wish = Vector3.ZERO
	panel.show_conversation(people.talk(a, me))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_talk_closed() -> void:
	people.end_talk()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_bark(p: Person, text: String, at: Vector3) -> void:
	var l := Label3D.new()
	l.text = "%s: %s" % [p.known_as, text]
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.004
	l.width = 900.0
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.outline_size = 8
	l.position = at
	venue.add_child(l)
	_barks.append([l, 4.0])


func _process(dt: float) -> void:
	if panel and panel.visible:
		walker.wish = Vector3.ZERO
	else:
		super._process(dt)
		var me := venue.global_transform.affine_inverse() * walker.global_position
		var a := people.nearest(me, 2.5)
		if a:
			_label.text += "\n[T] TALK TO %s" % a.person.known_as.to_upper()
	for b in _barks.duplicate():
		b[1] -= dt
		if b[1] <= 0.0:
			b[0].queue_free()
			_barks.erase(b)
	if _shot != "":
		_shot_t -= dt
		if _shot_t <= 0.0:
			var img := get_viewport().get_texture().get_image()
			img.save_png(_shot)
			print("people walk: saved %s" % _shot)
			get_tree().quit()
