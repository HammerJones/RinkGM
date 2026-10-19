extends "res://scripts/venue/venue_walk.gd"
## Walk the building while an on-ice event runs (OnIceSession): a public
## skate with the rental line, pee-wee stations behind the pads, a high
## school practice, 05:00 figure skating, broomball, an ambient game.
##
##   godot --path . res://scenes/world/on_ice_walk.tscn -- --free-walk --event=minor_hockey
##     [--hour=5 --weekday=6 --month=12 --dom=24 --count=120 --line=12 --warm=30]
##     [--shot=out.png --shot-after=4 (frames) --cam=x,y,z,lx,ly,lz]
##
## --warm=S runs the session S seconds before the first frame (pads laid,
## drills going); --line=N puts N more people in the rental line. The rink's
## own nets are hidden: the event's nets are real objects (OnIceSession.gear).
## --booth=1 puts the rental at the ticket booth window from on_ice.json
## (-34.3, -14.7) when this base's Venue.places() still has the old spot.
## R at the rental window: serve the front customer (asks the size, grabs it).

var session: OnIceSession
var _shot := ""
var _shot_frames := 4
var _info: Label


func _ready() -> void:
	super._ready()
	var kind := "public_skate"
	var c := {"venue": venue, "weekday": 6, "hour": -1.0, "month": 10, "dom": 17}
	var warm := 0.0
	var line := 0
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv.size() < 2:
			continue
		match kv[0]:
			"event": kind = kv[1]
			"hour": c.hour = kv[1].to_float()
			"weekday": c.weekday = kv[1].to_int()
			"month": c.month = kv[1].to_int()
			"dom": c.dom = kv[1].to_int()
			"count": c["count"] = kv[1].to_int()
			"staff": c["staff"] = kv[1].to_int()
			"warm": warm = kv[1].to_float()
			"line": line = kv[1].to_int()
			"shot": _shot = kv[1]
			"shot-after": _shot_frames = kv[1].to_int()
			"fast": c["fast"] = kv[1] == "1"
			"in-place": c["in_place"] = kv[1] == "1"
			"cam": _fixed_cam(kv[1])
			"booth":
				if kv[1] == "1":
					c["rental_window"] = OnIceData.v2(OnIceData.section("rental").get("window"))
	if float(c.hour) < 0.0:
		c.hour = _usual_hour(kind)
	c["seed"] = 11
	_hide_rink_nets()
	session = OnIceSession.create(kind, c)
	venue.add_child(session)
	session.run_for(warm, 1.0 / 20.0)
	var ps := session as OnIcePublicSkate
	if ps and ps.rental and line > 0:
		for i in line:
			var age := ps.rng.randi_range(5, 60)
			var l := PeopleArt.random_look(ps.rng, age, "stands")
			ps.rental.enqueue(l, age, "", ps.rental.LINE_START + ps.rental.LINE_STEP * (ps.rental.line.size() + 0.0))
		for i in 200:
			ps.rental.step(0.05)
	_info = Label.new()
	_info.position = Vector2(16, 680)
	_info.add_theme_color_override("font_color", RinkOS.READOUT)
	_info.add_theme_color_override("font_shadow_color", Color.BLACK)
	_label.get_parent().add_child(_info)
	print("on-ice walk: %s (%s), %d people" % [kind, session.controller, session.skaters.size()])


## A fixed camera at x,y,z looking at lx,ly,lz (venue space), for screenshots.
func _fixed_cam(spec: String) -> void:
	var f := spec.split_floats(",")
	if f.size() < 6:
		return
	var c3 := Camera3D.new()
	c3.fov = 62.0
	c3.near = 0.05
	add_child(c3)
	c3.look_at_from_position(Vector3(f[0], f[1], f[2]), Vector3(f[3], f[4], f[5]))
	c3.current = true


func _usual_hour(kind: String) -> float:
	for o in RinkContracts.ORGS:
		if o.get("event", "") == kind:
			return float(o.slots[0][1])
	return 14.0


func _hide_rink_nets() -> void:
	for n in get_children():
		if n is Rink:
			for m in n.get_children():
				if m is MeshInstance3D and absf(absf(m.position.x) - Rink.GOAL_X) < 0.01:
					m.visible = false


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_R:
		var ps := session as OnIcePublicSkate
		if ps and ps.rental:
			var b := ps.rental.player_begin()
			if not b.is_empty():
				ps.rental.player_grab(str(b.size))
				var h := ps.rental.player_hand()
				print("rental: %s wanted %s, got %s" % [b.name, b.size, str(h.get("got", ""))])
		return
	super._unhandled_input(e)


func _process(dt: float) -> void:
	super._process(dt)
	if session and _info:
		var txt := "%s  %s  t=%.0fs  on ice %d" % [session.kind, session.phase, session.t, session.on_ice_count()]
		var ps := session as OnIcePublicSkate
		if ps and ps.rental:
			txt += "  line %d  pile %d  stock %d" % [ps.rental.line.size(), ps.rental.pile.size(), ps.rental.total_stock()]
		var gm := session as OnIceGame
		if gm:
			txt += "  %s  %d-%d  P%d" % [gm.game_phase, gm.score[0], gm.score[1], gm.period]
		_info.text = txt
	if _shot != "":
		_shot_frames -= 1
		if _shot_frames <= 0:
			var img := get_viewport().get_texture().get_image()
			img.save_png(_shot)
			print("on-ice walk: saved %s" % _shot)
			_shot = ""
			get_tree().quit()
