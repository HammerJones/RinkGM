class_name LeagueRules
extends RefCounted
## How each level plays a game (canvas "On-ice activities", Hockey > Games).
## Modelled on real leagues:
##
## - Adult rec / beer league (USA Hockey and Hockey Canada adult rec play):
##   running time, with the clock stopped for the last minute of every
##   period and the last three of the third. A five-goal lead keeps it
##   running anyway (the mercy rule). Regular-season ties stand. Playoffs
##   go to a short overtime, then a shootout. No body checking. Two officials.
## - Senior AAA (Hockey Canada senior): stop time throughout, a five-minute
##   overtime then a shootout in the regular season, full 20-minute
##   sudden-death periods in the playoffs. Body checking. Three officials.
## - Semi-pro and minor pro (ECHL, AHL): stop time, overtime then a shootout
##   in the regular season, 20-minute sudden-death playoff overtime. Four
##   officials.
## - The rink's other hockey (World's on-ice events): minor hockey house
##   league is running time, three 12s, ties stand, no checking under 13.
##   High school is stop time, three 15s, an eight-minute sudden-death
##   overtime, then a tie.
##
## The clock windows are in the minutes of a 20-minute period. Game scales
## them to the career's period length, so a 5-minute period stops for its
## last 15 seconds.

const FULL_PERIOD := 20.0

const BEER_LEAGUE := {
	"name": "Adult rec", "clock": "running", "stop_last": 1.0, "stop_last_final": 3.0, "mercy_goals": 5,
	"ties": true, "regular_ot": false, "shootout": true, "playoff_ot": "short", "checking": false,
	"officials": 2, "warmup": 3.0, "slot_hours": 1.25, "periods": [15.0, 15.0, 15.0],
}
const SENIOR := {
	"name": "Senior AAA", "clock": "stop", "stop_last": 0.0, "stop_last_final": 0.0, "mercy_goals": 0,
	"ties": false, "regular_ot": true, "shootout": true, "playoff_ot": "full", "checking": true,
	"officials": 3, "warmup": 5.0, "slot_hours": 2.0, "periods": [20.0, 20.0, 20.0],
}
const PRO := {
	"name": "Pro", "clock": "stop", "stop_last": 0.0, "stop_last_final": 0.0, "mercy_goals": 0,
	"ties": false, "regular_ot": true, "shootout": true, "playoff_ot": "full", "checking": true,
	"officials": 4, "warmup": 5.0, "slot_hours": 2.5, "periods": [20.0, 20.0, 20.0],
}
const MINOR_HOUSE := {
	"name": "Minor hockey house league", "clock": "running", "stop_last": 1.0, "stop_last_final": 2.0, "mercy_goals": 5,
	"ties": true, "regular_ot": false, "shootout": false, "playoff_ot": "short", "checking": false,
	"officials": 2, "warmup": 3.0, "slot_hours": 1.0, "periods": [12.0, 12.0, 12.0],
}
const HIGH_SCHOOL := {
	"name": "High school", "clock": "stop", "stop_last": 0.0, "stop_last_final": 0.0, "mercy_goals": 0,
	"ties": true, "regular_ot": true, "shootout": false, "playoff_ot": "full", "checking": true,
	"officials": 3, "warmup": 5.0, "slot_hours": 1.5, "periods": [15.0, 15.0, 15.0],
}


## The rules for career tier `tier` (LeagueTiers): BL-D, BL-C, BL-A, Senior
## AAA, Semi-Pro, Minor League Pro.
static func for_tier(tier: int) -> Dictionary:
	if tier <= 2:
		return BEER_LEAGUE
	if tier == 3:
		return SENIOR
	return PRO


## The rules for a kind of event the rink hosts (EventCatalog ids).
static func for_event(kind: String) -> Dictionary:
	match kind:
		"beer_league_game":
			return BEER_LEAGUE
		"senior_game":
			return SENIOR
		"pro_game":
			return PRO
		"minor_game":
			return MINOR_HOUSE
		"high_school_game":
			return HIGH_SCHOOL
	return {}


## Whether the clock runs through stoppages at this point of the game.
## `left` is the seconds left in the period, `period_len` the period's full
## length in seconds, `final` true in the last regulation period, `lead`
## the goal difference.
static func clock_runs_in_stoppage(rules: Dictionary, left: float, period_len: float, final: bool, overtime: bool, lead: int) -> bool:
	if str(rules.get("clock", "stop")) != "running" or overtime:
		return false
	var mercy := int(rules.get("mercy_goals", 0))
	if mercy > 0 and absi(lead) >= mercy:
		return true
	var window := float(rules.get("stop_last_final", 0.0) if final else rules.get("stop_last", 0.0))
	return left > window * 60.0 * period_len / (FULL_PERIOD * 60.0)


## What happens when regulation ends tied: "tie", "overtime" or "shootout".
## `ot_played` is true once an overtime has already been played.
static func after_tie(rules: Dictionary, playoff: bool, ot_played: bool) -> String:
	if rules.is_empty():  # no level known: the old career behaviour
		return "overtime" if playoff or not ot_played else "shootout"
	if playoff:
		if str(rules.get("playoff_ot", "full")) == "full" or not ot_played:
			return "overtime"
		return "shootout" if bool(rules.get("shootout", true)) else "overtime"
	if not ot_played and bool(rules.get("regular_ot", false)):
		return "overtime"
	if bool(rules.get("ties", false)):
		return "tie"
	return "shootout" if bool(rules.get("shootout", true)) else "tie"


## One line for the hub and the scorekeeper's sheet.
static func describe(rules: Dictionary) -> String:
	var clock := "running time, stopped late in periods" if str(rules.clock) == "running" else "stop time"
	var tie: String
	if bool(rules.get("regular_ot", false)):
		tie = "overtime then a shootout" if bool(rules.shootout) else "overtime, then a tie"
	else:
		tie = "ties stand"
	var po := "sudden-death playoff overtime" if str(rules.playoff_ot) == "full" else "playoff overtime then a shootout"
	return "%s: %s, %s, %s, %s." % [rules.name, clock, tie, po, "body checking" if bool(rules.checking) else "no body checking"]
