extends Node
## Autoload that carries the career between the hub and the rink scenes:
## the loaded Career and the match the hub sent the player to.

const HUB_SCENE := "res://scenes/career_hub.tscn"
const RINK_SCENE := "res://scenes/main.tscn"
const OFFICE_SCENE := "res://scenes/ui/rink_office.tscn"

var career: Career
## The owner's rink running alongside the career (the "owner" slot), or null.
var rink: RinkLink
## Which Career.SLOTS entry is loaded ("career", "demo_low", "demo_mid").
var slot := "career"
## Career.next_user_game() for the game being played, or {} for an exhibition.
var fixture: Dictionary = {}
## The last round's summary (for the hub to show).
var last_round: Dictionary = {}
## True while the rink scene runs practice mode (see start_practice).
var practice := false


func load_or_null() -> Career:
	if career == null:
		career = Career.load_from(slot_path(slot))
		rink = RinkLink.resume(career) if career else null
	return career


func slot_path(s: String) -> String:
	return Career.SLOTS[s].path


func has_save(s: String) -> bool:
	return FileAccess.file_exists(slot_path(s))


## Switches slots (drops the loaded career; load_or_null() reads the new one).
func use_slot(s: String) -> void:
	if s == slot and career != null:
		return
	slot = s
	career = null
	rink = null
	last_round = {}


func delete_slot(s: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(s)))
	if s == slot:
		career = null
		rink = null
		last_round = {}


## Saves the loaded career to its slot (the dev menu calls this).
func save_career() -> void:
	if career:
		career.save()


func play_match(m: Dictionary) -> void:
	fixture = m
	practice = false
	get_tree().change_scene_to_file(RINK_SCENE)


## Practice: the user's skater alone on the ice with a puck (the loaded
## career's player, or a default skater without one). Nothing is recorded.
func start_practice() -> void:
	fixture = {}
	practice = true
	get_tree().change_scene_to_file(RINK_SCENE)


## Called by the rink when a career game ends: records it, sims the rest of
## the round and saves.
func finish_match(result: Dictionary) -> void:
	if career == null or fixture.is_empty():
		return
	last_round = play_round(result)
	career.save()
	fixture = {}


## Plays the career's current round, through the rink when one runs.
func play_round(result: Dictionary = {}) -> Dictionary:
	return rink.play_round(result) if rink else career.play_round(result)


## The owner's rink office (UI's office screens), for a career with a rink.
func open_office() -> void:
	get_tree().change_scene_to_file(OFFICE_SCENE)


func has_office() -> bool:
	return rink != null and ResourceLoader.exists(OFFICE_SCENE)


func back_to_hub() -> void:
	fixture = {}
	practice = false
	get_tree().change_scene_to_file(HUB_SCENE)
