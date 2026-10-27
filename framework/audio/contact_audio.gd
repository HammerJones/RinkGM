class_name ContactAudio
extends Node
## Every prop that hits something makes the sound its material makes. One
## node listens to the fields' `contact` signals and plays a one-shot
## through WorldSound (the game's sound hub, with its rate limits and
## earshot check), picked by the prop's manifest `sound` and the closing
## speed: a tap below SOFT m/s is quiet, a throw is loud.
##
##   var audio := ContactAudio.new()
##   add_child(audio)
##   audio.listen(field)          # or audio.listen_objects(world_objects)
##
## Materials and the recordings in assets/audio (CC0, art/tools/synth_sounds.py):
##   wood -> stick_clatter_N   metal -> breaker_clunk / bin_dump   plastic ->
##   ball_bounce_N (pitched up)   ceramic, glass -> glass_rattle   rubber ->
##   ball_bounce_N   cloth, paper -> body_fall (quiet)
## Unknown materials fall back to wood.

const SOFT := 0.6
const LOUD := 5.0
const SOUNDS := {
	"wood":
	{"names": ["stick_clatter_1", "stick_clatter_2", "stick_clatter_3"], "pitch": 1.0, "db": 0.0},
	"metal": {"names": ["breaker_clunk", "bin_dump"], "pitch": 1.1, "db": 0.0},
	"plastic":
	{"names": ["ball_bounce_1", "ball_bounce_2", "ball_bounce_3"], "pitch": 1.5, "db": -3.0},
	"rubber":
	{"names": ["ball_bounce_1", "ball_bounce_2", "ball_bounce_3"], "pitch": 1.0, "db": -2.0},
	"ceramic": {"names": ["glass_rattle"], "pitch": 1.2, "db": 0.0},
	"glass": {"names": ["glass_rattle"], "pitch": 1.0, "db": 0.0},
	"cloth": {"names": ["body_fall"], "pitch": 1.3, "db": -8.0},
	"paper": {"names": ["body_fall"], "pitch": 1.6, "db": -12.0},
}

## Every contact played, newest last, for tests and the dev menu:
## [prop, sound, speed].
var log: Array = []
var log_max := 32


func listen(field: PropField) -> void:
	if not field.contact.is_connected(_on_contact):
		field.contact.connect(_on_contact)


func listen_objects(objects: WorldObjects) -> void:
	for f in objects.fields:
		listen(f)
	objects.spawned.connect(func(row: PropRow) -> void: listen(objects._field_of(row)))


func _on_contact(row: PropRow, _other: Node, speed: float, at: Vector3) -> void:
	if speed < SOFT * 0.5:
		return
	var material := ObjectCatalog.sound(String(row.prop))
	var spec: Dictionary = SOUNDS.get(material, SOUNDS["wood"])
	var names: Array = spec.names
	var name: String = names[randi() % names.size()]
	var loud := clampf((speed - SOFT) / (LOUD - SOFT), 0.0, 1.0)
	var db: float = spec.db - 14.0 * (1.0 - loud)
	var pitch: float = spec.pitch * randf_range(0.94, 1.06)
	log.append([String(row.prop), name, speed])
	if log.size() > log_max:
		log.pop_front()
	if WorldSound.wanted():
		WorldSound.play(self, name, at, db, pitch)
