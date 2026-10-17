class_name MoveUnlocks
extends RefCounted
## When a player learns each shot and stick move (Controls' Moves catalog in
## scripts/game/moves.gd). Moves are stored by name ("SNAP") so saves don't
## depend on enum order; Moves owns what each one does on the ice.
##
## A move unlocks once every listed rating reaches its threshold and any
## required move is known. Ratings only climb through games and practice, so
## the tree reads as a skill path: release and accuracy give the snapshot,
## power the slapshot, and so on.

const STARTER := ["QUICK", "WRIST", "BACKHAND"]

const RULES := {
	"SNAP": {"skills": {"shot_release": 45.0, "shot_accuracy": 40.0}},
	"SLAP": {"skills": {"shot_power": 50.0}},
	"TOE_DRAG": {"skills": {"stick_handling": 50.0, "agility": 45.0}},
	"ONE_TIMER": {"skills": {"shot_release": 55.0, "pass_quality": 50.0}, "needs": ["SLAP"]},
	"LACROSSE": {"skills": {"stick_handling": 70.0, "agility": 60.0}, "needs": ["TOE_DRAG"]},
}

## In unlock order, for the hub's list.
const ORDER := ["QUICK", "WRIST", "BACKHAND", "SNAP", "SLAP", "TOE_DRAG", "ONE_TIMER", "LACROSSE"]

const LABELS := {
	"QUICK": "Quick shot", "WRIST": "Wrist shot", "BACKHAND": "Backhand", "SNAP": "Snapshot",
	"SLAP": "Slapshot", "ONE_TIMER": "One-timer", "TOE_DRAG": "Toe drag", "LACROSSE": "Lacrosse",
}


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
