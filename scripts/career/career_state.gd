extends Node
## Autoload that carries the career between the hub and the rink scenes:
## the loaded Career and the match the hub sent the player to.

const HUB_SCENE := "res://scenes/career_hub.tscn"
const RINK_SCENE := "res://scenes/main.tscn"

var career: Career
## Which Career.SLOTS entry is loaded ("career", "demo_low", "demo_mid").
var slot := "career"
## Career.next_user_game() for the game being played, or {} for an exhibition.
var fixture: Dictionary = {}
## The last round's summary (for the hub to show).
var last_round: Dictionary = {}


func load_or_null() -> Career:
	if career == null:
		career = Career.load_from(slot_path(slot))
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
	last_round = {}


func delete_slot(s: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(s)))
	if s == slot:
		career = null
		last_round = {}


## Saves the loaded career to its slot (the dev menu calls this).
func save_career() -> void:
	if career:
		career.save()


func play_match(m: Dictionary) -> void:
	fixture = m
	get_tree().change_scene_to_file(RINK_SCENE)


## Called by the rink when a career game ends: records it, sims the rest of
## the round and saves.
func finish_match(result: Dictionary) -> void:
	if career == null or fixture.is_empty():
		return
	last_round = career.play_round(result)
	career.save()
	fixture = {}


func back_to_hub() -> void:
	fixture = {}
	get_tree().change_scene_to_file(HUB_SCENE)
