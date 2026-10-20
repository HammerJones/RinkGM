class_name TierAI
extends RefCounted
## How well a league *plays* as a group, separate from player ratings: a
## skilled skater can still land in a scrambly beer league. The on-ice AI
## (skater_ai.gd, goalie.gd) reads these through `game.tier_ai`.
##
## Values come from the `ai` block of each tier in LeagueTiers; for_level()
## blends between tiers so the dev menu can dial in anything from 0 (Beer
## League D) to 5 (Minor League Pro).

## Delay in seconds before an AI player reacts to a possession change.
var reaction := 0.3
## Seconds between a puck carrier's decisions (shoot / pass / carry).
var decide_min := 0.2
var decide_max := 0.4
## 0..1 reading of passing options. Low sees only nearby or obvious mates and
## forces passes into traffic; high finds the open man across the ice.
var vision := 0.5
## 0..1 leading loose pucks and passes, stepping into lanes.
var anticipation := 0.5
## 0..1 positional structure. Low means two or three players swarm the puck
## and backchecking is lazy; high means lanes, gaps and a set net-front.
var discipline := 0.5
## 0..1 how often players finish checks and lift sticks.
var aggression := 0.5
## 0..1 shot choice. Low shoots from anywhere; high waits for a lane.
var shot_selection := 0.5
## 0..1 how readily players use the dash.
var dash_use := 0.5
## Multiplier on the goalie's reaction delay (above 1 is slower).
var goalie_reaction := 1.0
## 0..1 how square and deep the goalie plays.
var goalie_positioning := 0.5
## The tier level this was built for (fractional when blended).
var level := 0.0

const FIELDS := ["reaction", "decide_min", "decide_max", "vision", "anticipation", "discipline",
	"aggression", "shot_selection", "dash_use", "goalie_reaction", "goalie_positioning"]


static func for_tier(t: int) -> TierAI:
	return for_level(float(t))


## Blends the two nearest tiers' settings (level 2.5 sits halfway between
## Beer League A and Senior AAA).
static func for_level(x: float) -> TierAI:
	x = clampf(x, 0.0, float(LeagueTiers.count() - 1))
	var lo := int(floor(x))
	var hi := mini(lo + 1, LeagueTiers.count() - 1)
	var a: Dictionary = LeagueTiers.get_tier(lo).ai
	var b: Dictionary = LeagueTiers.get_tier(hi).ai
	var ai := TierAI.new()
	for f in FIELDS:
		ai.set(f, lerpf(a[f], b[f], x - lo))
	ai.level = x
	return ai


func to_dict() -> Dictionary:
	var d := {"level": level}
	for f in FIELDS:
		d[f] = get(f)
	return d


func describe() -> String:
	var parts := []
	for f in FIELDS:
		parts.append("%s %.2f" % [f, get(f)])
	return "level %.1f: %s" % [level, ", ".join(parts)]
