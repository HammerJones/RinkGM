class_name VenueSound
extends Node3D
## The building's sound, built by the Venue as its child "Sound" (venue
## space; only when RinkSound.enabled(), so headless runs and `--mute` have
## none). Layers:
##
## - room tone: the arena's HVAC and fans, or the lobby's quieter air and
##   vending machine, as flat (non-positional) loops crossfaded by the room
##   the camera is in (Venue.room_at), so walls keep rooms apart;
## - point sources: the ice plant's compressors, the ballast buzz of the old
##   tubes in the lobby and dressing rooms, the crowd over the stands
##   (louder with attendance), skaters on the ice, Doris resurfacing;
## - one-shots: `cheer(amount)` for goals, `lamps_switched(on)` for the
##   ice lights' breakers, and the match puck's contacts (`watch_puck`):
##   the boards' thud, the glass rattling when it's hit high or cleared,
##   a post's ping.
##
## `set_event(kind)` says what's on the ice and so which layers play:
## "none", "public_skate", "practice", "game", "figure", "broomball",
## "resurface". The walk starts at "none"; Venue.bind_game sets "game".

## Per event: [crowd murmur share, skaters share, resurfacer on].
const EVENTS := {
	"none": [0.0, 0.0, false],
	"public_skate": [0.35, 1.0, false],
	"practice": [0.12, 0.8, false],
	"game": [1.0, 0.85, false],
	"figure": [0.45, 0.45, false],
	"broomball": [0.4, 0.0, false],
	"resurface": [0.2, 0.0, true],
}
## Room tone gains [arena, lobby] by the room the listener is in; rooms not
## listed are around the ice ([1, 0]).
const ROOM_TONE := {
	"lobby": [0.12, 1.0], "office": [0.08, 0.75], "locker_home": [0.25, 0.55], "locker_away": [0.25, 0.55],
	"zamboni_bay": [0.5, 0.0], "plant_room": [0.2, 0.0],
	"rec_lobby": [0.0, 1.0], "rec_offices": [0.0, 0.8], "pro_shop": [0.0, 0.85], "rec_washrooms": [0.0, 0.6],
	"rec_hall": [0.15, 0.7], "rec_link": [0.3, 0.6], "gym": [0.0, 0.5], "weight_room": [0.0, 0.6],
	"community_room": [0.0, 0.7], "workshop": [0.1, 0.3],
}
const ARENA_DB := -12.0
const LOBBY_DB := -14.0
## The ice lighting panel by the lobby's street wall (lobby.gd).
const PANEL := Vector3(-45.3, 1.45, -2.3)

var venue: Venue
var event := "none"
var _arena: AudioStreamPlayer
var _lobby: AudioStreamPlayer
var _crowd: Array[AudioStreamPlayer3D] = []
var _skates: Array[AudioStreamPlayer3D] = []
var _zamboni: AudioStreamPlayer3D
var _gain := {"arena": 1.0, "lobby": 0.0, "crowd": 0.0, "skates": 0.0}
var _want := {"arena": 1.0, "lobby": 0.0, "crowd": 0.0, "skates": 0.0}
var _hype := 0.0
var _tick := 0.0
var _age := 0.0
var _lap := 0.0
## The match puck (watch_puck) and its velocity last physics frame.
var _puck: Node3D
var _puck_vel := Vector3.ZERO
var _next_contact := 0.0

## Puck contacts -> sounds (assets/audio, art/tools/synth_sounds.py).
const CONTACTS := {"boards": "puck_boards", "glass": "glass_rattle", "post": "puck_post", "out": "glass_rattle"}
## Normal speed (m/s) into the boards below which a touch makes no sound
## (a puck carried along the boards, or nudged off them).
const BOARD_MIN_SPEED := 1.5
## Tests: with `recording` on nothing plays and contacts land in `heard`.
static var recording := false
static var heard: Array[Dictionary] = []


func _init(v: Venue = null) -> void:
	venue = v
	name = "Sound"


func _ready() -> void:
	if not RinkSound.enabled():
		return
	_arena = _flat("arena_room", ARENA_DB)
	_lobby = _flat("lobby_room", -80.0)
	# the ice plant: two compressors along the outside wall
	for p in [Vector3(42.8, 1.0, 18.4), Vector3(42.8, 1.0, 24.6)]:
		_point("plant_room", p, -2.0, 3.0, 24.0)
	# old tubes humming over the lobby and the dressing rooms
	for p in [Vector3(-40.0, 3.9, -6.0), Vector3(-40.0, 3.9, 6.0), Vector3(-37.0, 3.9, 11.0),
			Vector3(40.0, 3.3, -9.5), Vector3(40.0, 3.3, 9.5)]:
		_point("fluorescent_buzz", p, -24.0, 1.2, 9.0)
	if venue and venue.has_wings():
		_point("lobby_room", Vector3(-39.0, 2.5, -37.0), -12.0, 6.0, 20.0)
		_point("fluorescent_buzz", Vector3(-2.0, 3.0, -42.0), -24.0, 1.2, 9.0)
	for x in [-14.0, 14.0]:
		for z in [-21.5, 21.5]:
			_crowd.append(_point("crowd_murmur", Vector3(x, 3.5, z), -80.0, 14.0, 60.0))
	for x in [-16.0, 16.0]:
		_skates.append(_point("skates_ice", Vector3(x, 0.6, 0.0), -80.0, 10.0, 55.0))
	_zamboni = _point("zamboni_idle", Vector3(0, 1.0, 0), -6.0, 6.0, 50.0, false)
	set_event(event)


func _exit_tree() -> void:
	for c in get_children():
		if c is AudioStreamPlayer or c is AudioStreamPlayer3D:
			c.stop()


func _flat(stream: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = stream.to_pascal_case()
	p.stream = RinkSound.stream(stream)
	p.volume_db = db
	add_child(p)
	RinkSound.start_loop(p)
	return p


func _point(stream: String, pos: Vector3, db: float, unit: float, reach: float, play := true) -> AudioStreamPlayer3D:
	var p := RinkSound.emitter(stream, db, unit, reach)
	p.position = pos
	add_child(p)
	if play:
		RinkSound.start_loop(p)
	return p


## What's on the ice: sets which layers play and how loud (see EVENTS).
func set_event(kind: String) -> void:
	if kind == "":
		kind = "none"
	if not EVENTS.has(kind):
		kind = _layers_for(kind)
	if not EVENTS.has(kind):
		push_warning("VenueSound: unknown event '%s'" % kind)
		kind = "none"
	event = kind
	if not is_inside_tree() or _arena == null:
		return
	var e: Array = EVENTS[kind]
	_want.crowd = e[0]
	_want.skates = e[1]
	if e[2]:
		RinkSound.start_loop(_zamboni)
	elif _zamboni:
		_zamboni.stop()


## A booking's event kind (RinkContracts: "minor_hockey", "beer_league"...)
## -> the layers of the on-ice controller that runs it (on_ice.json).
static func _layers_for(kind: String) -> String:
	var c := OnIceData.controller_for(kind)
	if c.begins_with("figure"):
		return "figure"
	if c in ["peewee_practice", "team_practice", "stick_and_puck"]:
		return "practice"
	return c


## Listens to a match puck (Puck): its `post_hit` and `left_rink` signals,
## and, since the puck has no boards signal, its velocity turning round at
## the boards each physics frame (board_hit). Venue.bind_game calls this.
func watch_puck(p: Node3D) -> void:
	if p == null or _puck == p:
		return
	_puck = p
	_puck_vel = p.get("vel")
	if p.has_signal("post_hit"):
		p.post_hit.connect(func() -> void:
			var v: Vector3 = p.get("vel")
			puck_contact("post", p.global_position, v.length()))
	if p.has_signal("left_rink"):
		p.left_rink.connect(func(_at: Vector3) -> void:
			var v: Vector3 = p.get("vel")
			puck_contact("out", p.global_position, v.length()))


## Normal speed (m/s) of a puck at `pos` (rink space) that hit the boards
## between two frames' velocities, or 0.0: near the boards, it was going
## out fast enough and is now coming back.
static func board_hit(pos: Vector3, before: Vector3, after: Vector3) -> float:
	var p := Vector2(pos.x, pos.z)
	if Rink.sdf(p) < -0.25:
		return 0.0
	var n := Rink.board_normal(p)
	var n3 := Vector3(n.x, 0.0, n.y)
	var vin := before.dot(n3)
	return vin if vin >= BOARD_MIN_SPEED and after.dot(n3) < 0.0 else 0.0


## "glass" above the top of the boards at `pos`, else "boards".
static func board_kind(pos: Vector3) -> String:
	return "glass" if pos.y > VenuePhysics.board_top() else "boards"


## A puck contact `what` (CONTACTS) at `at` (global) at `speed` m/s: louder
## and a touch lower for a harder hit. Rate limited so a puck chattering in
## a corner doesn't machine-gun.
func puck_contact(what: String, at: Vector3, speed: float) -> void:
	var sound: String = CONTACTS.get(what, "")
	if sound == "":
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _next_contact:
		return
	_next_contact = now + 0.05
	var k := clampf(speed / 30.0, 0.0, 1.0)
	var db := -14.0 + 14.0 * k - (6.0 if what == "out" else 0.0)
	if recording:
		heard.append({"sound": sound, "what": what, "at": at, "db": db})
		return
	if _arena == null:
		return
	RinkSound.play_at(self, sound, at, db, lerpf(1.06, 0.94, k), 4.0, 50.0)


func _physics_process(_dt: float) -> void:
	if _puck == null or not is_instance_valid(_puck):
		return
	var v: Vector3 = _puck.get("vel")
	if not bool(_puck.get("frozen")) and not bool(_puck.get("out_of_play")):
		var sp := board_hit(_puck.position, _puck_vel, v)
		if sp > 0.0:
			puck_contact(board_kind(_puck.position), _puck.global_position, sp)
	_puck_vel = v


## A goal or a big moment: the stands roar, `amount` 0..1 (a home goal is
## 1, a polite visitors' one about 0.25), scaled by how full the house is.
func cheer(amount: float) -> void:
	if _arena == null or amount <= 0.0:
		return
	var att := venue.attendance if venue else 0.3
	var loud := clampf(amount, 0.0, 1.0) * sqrt(clampf(att, 0.02, 1.0))
	_hype = maxf(_hype, loud)
	RinkSound.play_flat(self, "crowd_cheer", -6.0 + linear_to_db(maxf(loud, 0.05)), lerpf(1.08, 0.97, loud))


## The ice lights' breakers thrown at the panel: a clunk, and when they go
## on, the metal halides striking over the ice.
func lamps_switched(on: bool) -> void:
	if _arena == null or _age < 1.5:  # not for the walk's first sync of the building
		return
	RinkSound.play_at(self, "breaker_clunk", to_global(PANEL), -6.0, 1.0, 2.0, 25.0)
	if on:
		RinkSound.play_at(self, "lamp_strike", to_global(PANEL + Vector3(0.0, 1.8, 0.4)), -14.0, 1.0, 2.0, 20.0)
		for i in 3:
			_strike_later(0.25 + i * 0.35, to_global(Vector3(-24.0 + i * 24.0, 9.5, 0.0)))


func _strike_later(delay: float, at: Vector3) -> void:
	await get_tree().create_timer(delay).timeout
	if is_inside_tree():
		RinkSound.play_at(self, "lamp_strike", at, -8.0, randf_range(0.9, 1.1), 10.0, 70.0)


func _process(dt: float) -> void:
	if _arena == null:
		return
	_age += dt
	_tick -= dt
	if _tick <= 0.0:
		_tick = 0.25
		_listen()
	_hype = move_toward(_hype, 0.0, dt * 0.15)
	var k := minf(1.0, dt * 1.5)
	for key in _gain:
		_gain[key] = lerpf(_gain[key], _want[key], k)
	_arena.volume_db = ARENA_DB + linear_to_db(maxf(_gain.arena, 0.001))
	_lobby.volume_db = LOBBY_DB + linear_to_db(maxf(_gain.lobby, 0.001))
	var att := venue.attendance if venue else 0.3
	var c: float = _gain.crowd * sqrt(clampf(att, 0.0, 1.0)) * (1.0 + _hype * 1.5)
	for p in _crowd:
		p.volume_db = -4.0 + linear_to_db(maxf(c, 0.001))
	for p in _skates:
		p.volume_db = -6.0 + linear_to_db(maxf(_gain.skates, 0.001))
	if _zamboni and _zamboni.playing:
		# Doris laps the ice: an oval round the rink
		_lap += dt * 0.09
		_zamboni.position = Vector3(cos(_lap) * 22.0, 1.0, sin(_lap) * 8.5)


## Picks the room tone by the room the camera is in.
func _listen() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or venue == null:
		return
	var r := venue.room_at(venue.to_local(cam.global_position))
	var id := r.room_id if r else ""
	var g: Array = ROOM_TONE.get(id, [0.05, 0.6] if id.begins_with("locker_") or id.begins_with("rec_") else [1.0, 0.0])
	_want.arena = g[0]
	_want.lobby = g[1]
