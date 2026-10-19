class_name TrainingSpot
extends VenueSpot
## A weight-room machine the player can train on (playtest #29). It is a USE
## spot, so the walker finds it like any other (VenueWalker.nearest_spot) and
## the prompt reads "USE  BENCH PRESS". Using it is one 15-minute set: the
## sim clock moves on a step and `trained` fires with the skills the machine
## works. Mechanics hooks `trained` to Skills; nothing here touches ratings.
##
##   for s in get_tree().get_nodes_in_group(TrainingSpot.GROUP):
##       s.trained.connect(_on_trained)
##
## The spots are rebuilt with their room (a renovation swaps them), so hook
## new ones as they enter the tree (SceneTree.node_added) or re-scan the group.
## Sound can hook the same signal for the clank of the plates.

## Fired once per set: Skills keys (Skills.SKATER_KEYS), the minutes the set
## took and how hard the machine works them (0..1, better kit is higher).
signal trained(skill_keys: Array, minutes: int, intensity: float)

const GROUP := "training_spots"
const SET_MIN := 15  # RinkSim.STEP_MIN: one set is one sim step

## Canonical Skills keys this machine works.
var skill_keys: Array = []
## 0..1: how much a set does. A worn machine does less than a renovated one.
var intensity := 1.0
## Minutes one use takes (a multiple of RinkSim.STEP_MIN).
var minutes := SET_MIN
## Sets done on this spot since it was built.
var sets := 0


static func make_training(id_: String, label_: String, keys: Array, intensity_ := 1.0, reach_ := 1.4) -> TrainingSpot:
	var s := TrainingSpot.new()
	s.kind = VenueSpot.Kind.USE
	s.id = id_
	s.label = label_
	s.reach = reach_
	s.skill_keys = keys.duplicate()
	s.intensity = clampf(intensity_, 0.0, 1.0)
	s.data = {"training": keys.duplicate(), "intensity": s.intensity}
	s.name = "Spot_%s" % id_
	s.add_to_group("venue_spots")
	s.add_to_group(GROUP)
	return s


func prompt() -> String:
	return "TRAIN  %s  (%d MIN)" % [label.to_upper(), minutes]


## One set: moves `clock` on by `minutes` in 15-minute steps when there is
## one (a RinkSim, or a RinkLink, whose advance stops for the owner's game),
## then emits `trained`. Returns {"toast": text, "game_due": bool}.
func train(clock: Object = null) -> Dictionary:
	var game_due := false
	if clock != null and clock.has_method("advance"):
		var left := minutes
		while left > 0:
			var step := mini(left, SET_MIN)
			var r: Variant = clock.call("advance", step)
			left -= step
			if r is bool and r:
				game_due = true
				break
	sets += 1
	trained.emit(skill_keys.duplicate(), minutes, intensity)
	var names: Array[String] = []
	for k: String in skill_keys:
		names.append(String(Skills.LABELS.get(k, k)).to_upper())
	return {"toast": "%s: %d MIN  //  %s" % [label.to_upper(), minutes, ", ".join(names)], "game_due": game_due}
