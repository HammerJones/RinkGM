class_name WorldSound
extends Node3D
## World's sound: plays what World's scenes signal through the venue's sound
## system (RinkSound one-shots and looping emitters, VenueSound's crowd).
## The scenes stay silent themselves; each hooks itself up with one line:
##
##   WorldSound.attach(self)          # OnIceSession, RinkPeople, PickupRun
##   WorldSound.attach(self, body)    # DorisDrive, IceHand: loops ride `body`
##   WorldSound.hook_stick(self)      # StickProp.knocked
##
## What plays (assets/audio, made by art/tools/synth_sounds.py):
##   on the ice   blade_carve -> blade_carve_N, stop_spray, puck_hit -> puck_
##                stick/boards/post/pad/net, glass -> glass_rattle, whistle -> ref_whistle,
##                coach_whistle, crowd_reaction -> the roar (VenueSound.cheer),
##                crowd_applause or crowd_ooh, skater_fell -> body_fall
##   pickup       bounced -> ball_bounce_N, squeaked -> sneaker_squeak_N,
##                swished -> net_swish, rim_hit -> rim_clang, backboard_hit ->
##                backboard_bang, scored -> a shout (voice_bark_N)
##   people       chatter(level) -> the hall_chatter loop's level, cheered ->
##                the roar, reacted -> crowd_gasp / crowd_applause / crowd_ooh,
##                barked -> voice_bark_N at their head
##   sticks       knocked -> stick_clatter_N
##   Doris        engine(rpm) -> zamboni_idle loop pitched by rpm, blade_scrape
##                -> blade_scrape loop (blade_skip when skipping), flood_flow
##                -> flood_water loop, wash_pump, auger(jammed) -> auger_grind,
##                hose -> hose_fill (loops), bin_dump (one-shot)
##   ice hand     hose / hose_flow -> hose_spray loop, edger -> edger_motor
##                loop, chipper -> ice_chip_N
##
## Busy signals are rate limited per sound (GAP, shared by every hub, so a
## goal the session and the stands both report roars once) and one-shots
## beyond earshot of the camera are skipped. Each loop is one player that
## fades to a new level, and stops a beat after its signal goes quiet.
##
## Sound is off in headless runs (RinkSound.enabled), so attach() adds
## nothing there. Tests set `recording`: then hooks attach, nothing plays,
## and every call lands in `heard` ({sound, ...}).

static var recording := false
static var heard: Array[Dictionary] = []
static var _next := {}

## Seconds between two plays of a sound family.
const GAP := {"blade_carve": 0.07, "stop_spray": 0.15, "puck": 0.04, "whistle": 0.3, "body_fall": 0.2,
	"ball_bounce": 0.05, "sneaker_squeak": 0.12, "hoop": 0.06, "shout": 1.0, "voice_bark": 0.4,
	"crowd": 1.2, "cheer": 2.5, "stick_clatter": 0.08, "blade_skip": 0.3, "ice_chip": 0.1}
const PUCK := {"stick": "puck_stick", "boards": "puck_boards", "post": "puck_post", "glass": "glass_rattle", "pad": "puck_pad",
	"goalie": "puck_pad", "skate": "puck_pad", "net": "puck_net", "pylon": "puck_stick"}
## Fades of the loops, dB a second.
const FADE := 40.0
const OFF_DB := -60.0

var source: Node
## Where the loops play: Doris's body, the ice hand's worker; else here.
var anchor: Node3D
var _loops := {}      # sound -> AudioStreamPlayer3D / AudioStreamPlayer
var _want_db := {}    # sound -> target dB (OFF_DB: fade out and stop)
var _keep := {}       # sound -> seconds left before an un-refreshed loop stops
var _hoop := Vector3.ZERO


static func wanted() -> bool:
	return recording or RinkSound.enabled()


## Hooks `e`'s sound signals (by which signals it has). Null when sound is off.
static func attach(e: Node, anchor_: Node3D = null) -> WorldSound:
	if e == null or not wanted():
		return null
	var w := WorldSound.new()
	w.name = "WorldSound"
	w.source = e
	w.anchor = anchor_
	e.add_child(w)
	w._hook(e)
	return w


## A stick clatters when knocked over (no node of its own: there are hundreds).
static func hook_stick(s: Node3D) -> void:
	if wanted() and s.has_signal("knocked"):
		s.knocked.connect(func(_by: Node) -> void: _stick_knocked(s))


static func _stick_knocked(s: Node3D) -> void:
	if is_instance_valid(s) and s.is_inside_tree():
		play(s.get_parent(), "stick_clatter", s.global_position, -10.0, 1.0, 2.0, 22.0)


## Tests: forget what was heard and the rate limits.
static func reset() -> void:
	heard.clear()
	_next.clear()


## A one-shot at `at` (global), unless its family (`key`, default the name)
## played under GAP ago or the camera is out of `reach`.
static func play(parent: Node, name: String, at: Vector3, db := 0.0, pitch := 1.0, unit := 3.0,
		reach := 35.0, key := "") -> void:
	if parent == null:
		return
	if not recording and _far(parent, at, reach):
		return
	if not _due(key if key != "" else name):
		return
	if recording:
		heard.append({"sound": name, "at": at, "db": db, "pitch": pitch})
		return
	RinkSound.play_at(parent, name, at, db, pitch, unit, reach)


static func _due(key: String) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(_next.get(key, -1.0)):
		return false
	_next[key] = now + float(GAP.get(key, 0.0))
	return true


static func _far(n: Node, at: Vector3, reach: float) -> bool:
	if not n.is_inside_tree():
		return true
	var cam := n.get_viewport().get_camera_3d()
	return cam != null and cam.global_position.distance_to(at) > reach


## `e` is untyped: the signals are looked up on whatever it is.
func _hook(e) -> void:
	if e.has_signal("blade_carve"):  # OnIceSession
		e.blade_carve.connect(func(p: Vector3, sp: float) -> void:
			if sp > 0.4:
				play(self, "blade_carve", _at(p), -18.0 + 8.0 * clampf(sp / 8.0, 0.0, 1.0), randf_range(0.9, 1.1), 3.0, 28.0))
		e.stop_spray.connect(func(p: Vector3, sp: float) -> void:
			play(self, "stop_spray", _at(p), -10.0 + 6.0 * clampf(sp / 8.0, 0.0, 1.0), 1.0, 4.0, 40.0))
		e.puck_hit.connect(_on_puck)
		e.whistle.connect(func(p: Vector3) -> void: play(self, "ref_whistle", _at(p + Vector3(0, 1.7, 0)), -4.0, 1.0, 10.0, 90.0, "whistle"))
		e.coach_whistle.connect(func(p: Vector3) -> void: play(self, "coach_whistle", _at(p + Vector3(0, 1.7, 0)), -8.0, 1.0, 8.0, 70.0, "whistle"))
		e.crowd_reaction.connect(_on_crowd)
		e.skater_fell.connect(func(p: Vector3, _role: String) -> void: play(self, "body_fall", _at(p), -6.0, 1.0, 4.0, 40.0))
	if e.has_signal("swished"):  # PickupRun (its PickupBall's hits come through it)
		e.bounced.connect(func(p: Vector3, s: float) -> void: play(self, "ball_bounce", _at(p), -20.0 + 16.0 * s, 1.0, 3.0, 30.0))
		e.squeaked.connect(func(p: Vector3, s: float) -> void: play(self, "sneaker_squeak", _at(p), -22.0 + 12.0 * s, 1.0, 2.5, 25.0))
		e.swished.connect(func(p: Vector3) -> void:
			_hoop = p
			play(self, "net_swish", _at(p), -6.0, 1.0, 3.0, 30.0, "hoop"))
		e.rim_hit.connect(func(p: Vector3, s: float) -> void:
			_hoop = p
			play(self, "rim_clang", _at(p), -16.0 + 14.0 * s, 1.0, 4.0, 40.0, "hoop"))
		e.backboard_hit.connect(func(p: Vector3, s: float) -> void: play(self, "backboard_bang", _at(p), -14.0 + 12.0 * s, 1.0, 4.0, 40.0, "hoop"))
		e.scored.connect(func(_team: int, _pts: int, _score: Array) -> void:
			play(self, "voice_bark", _at(_hoop + Vector3(0, -1.2, 0)), -6.0, 1.2, 4.0, 35.0, "shout"))
	if e.has_signal("chatter"):  # RinkPeople
		e.chatter.connect(func(level: float) -> void:
			_loop("hall_chatter", level > 0.03, -18.0 + linear_to_db(maxf(level, 0.03)), 1.0, true))
		e.cheered.connect(func(_at_: Vector3, s: float) -> void: _cheer(s))
		e.reacted.connect(_on_reacted)
		e.barked.connect(func(_p: Object, _text: String, at: Vector3) -> void:
			play(self, "voice_bark", _at(at), -10.0, randf_range(0.88, 1.15), 2.0, 18.0))
	if e.has_signal("bin_dump"):  # DorisDrive
		e.engine.connect(func(rpm: float) -> void:
			_loop("zamboni_idle", rpm > 50.0, -10.0 + 6.0 * clampf((rpm - 850.0) / 1700.0, 0.0, 1.0), clampf(rpm / 850.0, 0.5, 2.2)))
		e.blade_scrape.connect(func(q: float, skipping: bool) -> void:
			_loop("blade_scrape", true, -14.0 + 4.0 * clampf(q, 0.0, 1.0), 1.0, false, 0.6)
			if skipping:
				play(self, "blade_skip", _anchor_at(), -8.0, 1.0, 3.0, 25.0))
		e.flood_flow.connect(func(rate: float, state: String) -> void:
			_loop("flood_water", rate > 0.0 and state != "off", -16.0 + 10.0 * clampf(rate / 3.75, 0.0, 1.0)))
		e.wash_pump.connect(func(on: bool) -> void: _loop("wash_pump", on, -16.0))
		e.auger.connect(func(jammed: bool) -> void: _loop("auger_grind", jammed, -8.0))
		e.hose.connect(func(on: bool) -> void: _loop("hose_fill", on, -10.0))
		e.bin_dump.connect(func() -> void: play(self, "bin_dump", _anchor_at(), -4.0, 1.0, 4.0, 40.0))
	if e.has_signal("chipper"):  # IceHand
		e.hose.connect(func(on: bool) -> void: _loop("hose_spray", on, -12.0))
		e.hose_flow.connect(func(rate: float) -> void:
			_loop("hose_spray", rate > 0.0, -18.0 + 8.0 * clampf(rate, 0.0, 1.0)))
		e.edger.connect(func(on: bool, load: float) -> void:
			_loop("edger_motor", on, -10.0 + 4.0 * load, 1.0 - 0.08 * load))
		e.chipper.connect(func(hit: float) -> void:
			play(self, "ice_chip", _anchor_at(), -10.0 + 6.0 * clampf(hit / 2.0, 0.0, 1.0), 1.0, 2.0, 20.0))


func _on_puck(p: Vector3, what: String, sp: float) -> void:
	var s := clampf(sp / 30.0, 0.0, 1.0) if sp > 0.0 else 0.2
	play(self, str(PUCK.get(what, "puck_stick")), _at(p), -16.0 + 14.0 * s, 1.0, 3.0, 40.0, "puck")


## The stands react to the ice: the roar for a goal (VenueSound's), applause, an "ooh".
func _on_crowd(kind: String, strength: float) -> void:
	match kind:
		"goal", "final":
			_cheer(strength)
		"applause", "save", "period_end":
			_flat("crowd_applause", -8.0 + linear_to_db(maxf(strength, 0.1)), 1.0)
		"giggle":
			_flat("crowd_ooh", -16.0 + linear_to_db(maxf(strength, 0.1)), 1.35)
		_:  # "ooh", "hit"
			_flat("crowd_ooh", -8.0 + linear_to_db(maxf(strength, 0.1)), 1.0)


func _on_reacted(what: String, at: Vector3, strength: float) -> void:
	var db := -6.0 + linear_to_db(maxf(strength, 0.1))
	match what:
		"gasp":
			play(self, "crowd_gasp", _at(at), db, 1.0, 12.0, 70.0, "crowd")
		"clap":
			play(self, "crowd_applause", _at(at), db, 1.0, 12.0, 70.0, "crowd")
		"zamboni":  # the kids at the glass
			play(self, "crowd_ooh", _at(at), db - 4.0, 1.3, 6.0, 40.0, "crowd")
		_:
			play(self, "crowd_ooh", _at(at), db, 1.0, 12.0, 70.0, "crowd")


## A goal's roar: the venue's (it knows how full the house is), else our own.
func _cheer(strength: float) -> void:
	if not _due("cheer"):
		return
	var vs := _venue_sound()
	if recording:
		heard.append({"sound": "crowd_cheer", "via": "venue" if vs else "flat", "db": strength})
	elif vs:
		vs.cheer(strength)
	else:
		RinkSound.play_flat(self, "crowd_cheer", -6.0 + linear_to_db(maxf(strength, 0.05)))


func _flat(name: String, db: float, pitch: float) -> void:
	if not _due("crowd"):
		return
	if recording:
		heard.append({"sound": name, "db": db, "pitch": pitch})
	else:
		RinkSound.play_flat(self, name, db, pitch)


func _venue_sound() -> VenueSound:
	var n := source
	while n:
		var s: Variant = n.get("sound")
		if s is VenueSound:
			return s
		n = n.get_parent()
	return null


## A position in the source's space, in the world's.
func _at(p: Vector3) -> Vector3:
	var s := source as Node3D
	return s.to_global(p) if s and s.is_inside_tree() else p


func _anchor_at() -> Vector3:
	var a := anchor if anchor and is_instance_valid(anchor) else self
	return a.global_position + Vector3(0, 0.6, 0) if a.is_inside_tree() else Vector3.ZERO


## Starts, re-levels or stops the loop `name` (one player each). `keep`: a
## loop whose signal repeats while it's on (blade_scrape) stops `keep`
## seconds after the last one. `flat`: no position (the chatter round you).
func _loop(name: String, on: bool, db := 0.0, pitch := 1.0, flat := false, keep := 0.0) -> void:
	if recording:
		heard.append({"sound": name, "loop": on, "db": db, "pitch": pitch})
	var p: Node = _loops.get(name)
	if p != null and not is_instance_valid(p):
		p = null
	if not on:
		if p:
			_want_db[name] = OFF_DB
		return
	if p == null:
		if flat:
			var f := AudioStreamPlayer.new()
			f.stream = RinkSound.stream(name)
			p = f
		else:
			p = RinkSound.emitter(name, db, 4.0, 45.0)
		p.name = name.to_pascal_case()
		p.set("volume_db", OFF_DB)
		var host: Node = anchor if anchor and is_instance_valid(anchor) else self
		host.add_child(p)
		if not flat:
			(p as Node3D).position = Vector3(0, 0.6, 0) if host == anchor else Vector3.ZERO
		_loops[name] = p
	_want_db[name] = db
	p.set("pitch_scale", pitch)
	if keep > 0.0:
		_keep[name] = keep
	if not recording and not bool(p.get("playing")):
		RinkSound.start_loop(p)


## How many loop players there are (tests: one per sound, however busy).
func loop_count() -> int:
	return _loops.size()


func _process(dt: float) -> void:
	for name: String in _loops.keys():
		var p: Node = _loops[name]
		if not is_instance_valid(p):
			_loops.erase(name)
			continue
		if _keep.has(name):
			_keep[name] = float(_keep[name]) - dt
			if float(_keep[name]) <= 0.0:
				_keep.erase(name)
				_want_db[name] = OFF_DB
		var want: float = _want_db.get(name, OFF_DB)
		var v: float = move_toward(float(p.get("volume_db")), want, FADE * dt)
		p.set("volume_db", v)
		if want <= OFF_DB and v <= OFF_DB and bool(p.get("playing")):
			p.call("stop")


func _exit_tree() -> void:
	for p: Node in _loops.values():
		if is_instance_valid(p) and bool(p.get("playing")):
			p.call("stop")
