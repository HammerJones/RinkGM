class_name Moves
extends RefCounted
## The catalog of shots and stick moves, and the stick pattern that performs
## each one. Patterns are traced with the right stick (or the mouse) in the
## skater's own frame: 0 deg is straight ahead, + is the forehand side, - the
## backhand, and the blade reaches 110 deg either way.
##
## Who does what:
##   * this catalog and StickGestures (scripts/input/) recognise the pattern
##     and set Skater.Controls.move_id
##   * physics (MovePhysics, Skater) runs the move: blade path, puck, shot
##   * mechanics decides who has learned which move (Skater.knows)
##
## `executor` says how a move runs: "windup" moves are the stick's own shot
## mechanics (no move id is sent), "move" ids are MovePhysics entries, and
## "proposed" moves have no physics yet (the recogniser skips them).

const CATALOG := [
	{"id": &"quick_shot", "name": "Quick shot", "starter": true, "executor": "windup",
		"pad": "Flick the right stick forward from neutral",
		"mouse": "Flick the mouse forward"},
	{"id": &"wrist_shot", "name": "Wrist shot", "starter": true, "executor": "windup",
		"pad": "Draw the stick back past your forehand hip, then sweep it forward",
		"mouse": "Same with the mouse"},
	{"id": &"backhand", "name": "Backhand", "starter": true, "executor": "windup",
		"pad": "Draw the stick back past your backhand hip, then sweep it forward",
		"mouse": "Same with the mouse"},
	{"id": &"slapshot", "name": "Slapshot", "starter": false, "executor": "windup",
		"pad": "Hold LT and draw the stick back on the forehand, then forward",
		"mouse": "Hold right click and draw back, then forward"},
	{"id": &"one_timer", "name": "One-timer", "starter": false, "executor": "windup",
		"pad": "Slapshot wind-up without the puck; push forward as the pass arrives",
		"mouse": "Same with right click and the mouse"},
	{"id": &"snap_shot", "name": "Snapshot", "starter": false, "executor": "move",
		"pad": "Pull the stick out to the forehand side, then snap it all the way forward",
		"mouse": "Mouse out to the forehand side, then snap it forward"},
	{"id": &"backhand_shot", "name": "Backhand snap", "starter": false, "executor": "move",
		"pad": "Pull the stick out to the backhand side, then snap it all the way forward",
		"mouse": "Mouse out to the backhand side, then snap it forward"},
	{"id": &"quick_deke", "name": "Quick deke", "starter": false, "executor": "move",
		"pad": "Whip the stick forehand, backhand, forehand in one quick motion",
		"mouse": "Same with the mouse"},
	{"id": &"toe_drag", "name": "Toe drag", "starter": false, "executor": "move",
		"pad": "Hold RT, stick out front, pull it back across to the backhand",
		"mouse": "Hold left click, mouse forward, pull it back across"},
	{"id": &"toe_drag_shot", "name": "Toe drag shot", "starter": false, "executor": "move",
		"pad": "Hold LT and RT, stick out front, pull it back across to the backhand",
		"mouse": "Hold both buttons, mouse forward, pull it back across"},
	{"id": &"lacrosse", "name": "Lacrosse", "starter": false, "executor": "proposed",
		"pad": "Hold RT, sweep from the backhand round to the forehand, then push forward",
		"mouse": "Same with left click and the mouse"},
]


static func info(id: StringName) -> Dictionary:
	for m in CATALOG:
		if m["id"] == id:
			return m
	return {}


static func display_name(id: StringName) -> String:
	return info(id).get("name", String(id))


static func starters() -> Array[StringName]:
	var out: Array[StringName] = []
	for m in CATALOG:
		if m["starter"]:
			out.append(m["id"])
	return out
