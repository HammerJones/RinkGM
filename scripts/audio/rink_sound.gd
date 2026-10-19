class_name RinkSound
extends RefCounted
## Static helpers for the venue's sounds (assets/audio, made by
## art/tools/synth_sounds.py): load a stream by name (loops marked), make looping emitters, and fire one-shots at a point in the world.
##
##     RinkSound.play_at(self, "door_close_latch", global_position, -10.0)
##
## Sound is off with `-- --mute`, and in headless runs (tests, CI) unless
## `-- --sound` asks for it, so nothing here touches a headless test.

const DIR := "res://assets/audio/"
## Streams that loop: their loop points are set when first loaded.
const LOOPS := ["arena_room", "plant_room", "fluorescent_buzz", "lobby_room", "crowd_murmur",
	"skates_ice", "zamboni_idle"]
const VARIANTS := {"footstep_rubber": 4, "footstep_concrete": 4, "footstep_tile": 3}

static var _enabled := -1  # -1 not decided yet, 0 off, 1 on


static func enabled() -> bool:
	if _enabled < 0:
		var args := OS.get_cmdline_user_args()
		var on := not ("--mute" in args) and (DisplayServer.get_name() != "headless" or "--sound" in args)
		_enabled = 1 if on else 0
	return _enabled == 1


## The stream called `name` (a file in assets/audio without .wav), or null.
## (Godot's resource cache shares one copy while anything holds it; no cache
## of our own, so nothing is left alive at exit.)
static func stream(name: String) -> AudioStream:
	var path := DIR + name + ".wav"
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if s == null:
		push_warning("RinkSound: no sound '%s'" % name)
	elif s is AudioStreamWAV and name in LOOPS:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = roundi(w.get_length() * w.mix_rate)
	return s


## "footstep_tile" -> one of its numbered takes at random; other names as is.
static func variant(name: String) -> String:
	if VARIANTS.has(name):
		return "%s_%d" % [name, randi_range(1, VARIANTS[name])]
	return name


## Plays a one-shot at world position `pos` with the pitch varied by +-6%,
## from a player that frees itself when done. Distances are metres: full
## level within `unit` m, inaudible past `reach` m. Returns the player (or
## null when sound is off).
static func play_at(parent: Node, name: String, pos: Vector3, db := 0.0, pitch := 1.0,
		unit := 3.0, reach := 35.0) -> AudioStreamPlayer3D:
	if not enabled() or parent == null or not parent.is_inside_tree():
		return null
	var s := stream(variant(name))
	if s == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = db
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.unit_size = unit
	p.max_distance = reach
	p.attenuation_filter_cutoff_hz = 6000.0
	p.finished.connect(p.queue_free)
	p.tree_exiting.connect(p.stop)
	parent.add_child(p)
	p.global_position = pos
	p.play()
	return p


## Plays a one-shot everywhere at once (no position), e.g. the crowd's roar.
static func play_flat(parent: Node, name: String, db := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	if not enabled() or parent == null or not parent.is_inside_tree():
		return null
	var s := stream(variant(name))
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = db
	p.pitch_scale = pitch * randf_range(0.97, 1.03)
	p.finished.connect(p.queue_free)
	p.tree_exiting.connect(p.stop)
	parent.add_child(p)
	p.play()
	return p


## A looping positional emitter (not yet in the tree, not yet playing):
## add it, place it, then start it with `start_loop`.
static func emitter(name: String, db: float, unit: float, reach: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = name.to_pascal_case()
	p.stream = stream(name)
	p.volume_db = db
	p.unit_size = unit
	p.max_distance = reach
	p.attenuation_filter_cutoff_hz = 4000.0
	return p


## Starts a looping player at a random point in its loop, so several
## emitters of one sound don't play in step.
static func start_loop(p: Node) -> void:
	if p == null or not p.is_inside_tree() or p.get("stream") == null or p.playing:
		return
	p.play(randf() * p.stream.get_length())


## Footstep surface for a room id: tile in the lobbies, offices, washrooms
## and dressing rooms; concrete in the plant, the bay, utility rooms and
## the workshop; rubber matting everywhere around the ice.
static func floor_kind(room_id: String) -> String:
	match room_id:
		"lobby", "office", "rec_lobby", "rec_offices", "pro_shop", "rec_washrooms", "rec_officials", \
				"community_room", "locker_home", "locker_away":
			return "tile"
		"plant_room", "zamboni_bay", "rec_electrical", "rec_boiler", "rec_storage", "workshop", \
				"rec_hall", "rec_link", "rec_site":
			return "concrete"
	if room_id.begins_with("locker_"):
		return "tile"
	return "rubber"
