class_name MoveUnlocks
extends RefCounted
## When a player learns each shot and stick move. Ids are Controls' catalog
## ids (scripts/core/moves.gd, e.g. &"snap_shot"), saved as plain strings;
## the catalog and physics own what each move does on the ice, and they ask
## Skater.knows(id) before running one.
##
## A move unlocks once every listed rating reaches its threshold and any
## required move is known. Ratings only climb through games and practice, so
## the tree reads as a skill path: release and accuracy give the snapshot,
## power the slapshot, and so on.

const STARTER := ["quick_shot", "wrist_shot", "backhand"]

const RULES := {
	"snap_shot": {"skills": {"shot_release": 45.0, "shot_accuracy": 40.0}},
	"slapshot": {"skills": {"shot_power": 50.0}},
	"quick_deke": {"skills": {"stick_handling": 45.0, "agility": 45.0}},
	"backhand_shot": {"skills": {"shot_release": 50.0, "stick_handling": 45.0}, "needs": ["snap_shot"]},
	"toe_drag": {"skills": {"stick_handling": 52.0, "agility": 48.0}, "needs": ["quick_deke"]},
	"one_timer": {"skills": {"shot_release": 55.0, "pass_quality": 50.0}, "needs": ["slapshot"]},
	"toe_drag_shot": {"skills": {"stick_handling": 60.0, "shot_release": 55.0}, "needs": ["toe_drag", "snap_shot"]},
	"lacrosse": {"skills": {"stick_handling": 70.0, "agility": 60.0}, "needs": ["toe_drag"]},
}

## In unlock order, for the hub's list.
const ORDER := ["quick_shot", "wrist_shot", "backhand", "snap_shot", "slapshot", "quick_deke",
	"backhand_shot", "toe_drag", "one_timer", "toe_drag_shot", "lacrosse"]

const LABELS := {
	"quick_shot": "Quick shot", "wrist_shot": "Wrist shot", "backhand": "Backhand",
	"snap_shot": "Snapshot", "slapshot": "Slapshot", "quick_deke": "Quick deke",
	"backhand_shot": "Backhand snap", "toe_drag": "Toe drag", "one_timer": "One-timer",
	"toe_drag_shot": "Toe drag shot", "lacrosse": "Lacrosse",
}

## Saves from before the ids matched Controls' catalog.
const OLD_NAMES := {"QUICK": "quick_shot", "WRIST": "wrist_shot", "BACKHAND": "backhand",
	"SNAP": "snap_shot", "SLAP": "slapshot", "ONE_TIMER": "one_timer", "TOE_DRAG": "toe_drag", "LACROSSE": "lacrosse"}


## Catalog id -> Controls' Moves enum name, until the catalog's ids reach
## the physics branch. Moves this table doesn't list aren't playable yet.
const ENUM_NAMES := {"quick_shot": "QUICK", "wrist_shot": "WRIST", "backhand": "BACKHAND",
	"snap_shot": "SNAP", "slapshot": "SLAP", "one_timer": "ONE_TIMER", "toe_drag": "TOE_DRAG", "lacrosse": "LACROSSE"}


## The `Skater.moves` set (Moves enum id -> true) for a list of learned ids.
static func to_move_ids(learned: Array) -> Dictionary:
	var consts: Dictionary = (Moves as Script).get_script_constant_map()
	var out := {}
	for m in learned:
		var en: String = ENUM_NAMES.get(m, "")
		if en != "" and consts.has(en):
			out[consts[en]] = true
	return out


static func can_learn(p: PlayerProfile, move: String) -> bool:
	if not RULES.has(move):
		return STARTER.has(move)
	var rule: Dictionary = RULES[move]
	for m in rule.get("needs", []):
		if not p.moves.has(m):
			return false
	for k in rule.skills:
		if p.skills.values.get(k, 0.0) < rule.skills[k]:
			return false
	return true


## Learns everything the player now qualifies for; returns the new names.
## Trained values count (not injury-reduced ones): you don't forget a move.
static func check(p: PlayerProfile) -> Array:
	if p.is_goalie():
		return []
	var learned: Array = []
	for m in ORDER:
		if not p.moves.has(m) and can_learn(p, m):
			p.moves.append(m)
			learned.append(m)
	return learned


## What's still needed for `move`, e.g. "Shot power 50 (now 43)".
static func requirement_text(p: PlayerProfile, move: String) -> String:
	if not RULES.has(move):
		return ""
	var parts: Array = []
	var rule: Dictionary = RULES[move]
	for m in rule.get("needs", []):
		if not p.moves.has(m):
			parts.append("learn %s" % LABELS[m])
	for k in rule.skills:
		var v: float = p.skills.values.get(k, 0.0)
		if v < rule.skills[k]:
			parts.append("%s %d (now %d)" % [Skills.LABELS[k], int(rule.skills[k]), int(v)])
	return ", ".join(parts)
