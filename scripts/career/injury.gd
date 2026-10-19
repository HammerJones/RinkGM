class_name Injury
extends RefCounted
## An injury: where, how bad, how many games it keeps a player out, and which
## skills it drags down while it heals (players can come back before they are
## fully healed, at reduced ratings). Severe ones can leave a permanent mark.

enum Severity { DAY_TO_DAY, MINOR, MODERATE, MAJOR }

const SEVERITY_NAMES := ["Day-to-day", "Minor", "Moderate", "Major"]
## games out: [min, max] per severity
const GAMES_OUT := [[0, 0], [1, 2], [3, 5], [6, 14]]
## skill penalty at the start of recovery per severity (fades to 0 when healed)
const PENALTY := [4.0, 8.0, 12.0, 18.0]

## body part -> skills it affects
const PARTS := {
	"knee": ["speed", "agility"],
	"ankle": ["speed", "agility"],
	"groin": ["speed", "agility", "shot_power"],
	"shoulder": ["hitting", "shot_power", "pass_quality"],
	"wrist": ["shot_accuracy", "shot_release", "stick_handling"],
	"hand": ["stick_handling", "pass_quality", "shot_accuracy"],
	"ribs": ["hitting", "toughness", "shot_power"],
	"back": ["speed", "hitting", "shot_power"],
	"concussion": ["agility", "stick_handling", "pass_quality", "shot_accuracy"],
}

var part := ""
var severity := Severity.MINOR
var games_out := 0
var games_total := 0
var permanent := {}  # skill -> loss applied when the injury happened
## Day-counted injuries (a slip on the ice in shoes): out for `days_out`
## more days, whatever the game schedule.
var days_out := 0
var days_total := 0


func describe() -> String:
	return "%s %s" % [SEVERITY_NAMES[severity], "concussion" if part == "concussion" else part + " injury"]


func is_healed() -> bool:
	return games_out <= 0 and _penalty_scale() <= 0.0


func can_play() -> bool:
	return games_out <= 0 and days_out <= 0


## Temporary skill modifiers for the current point in recovery.
func modifiers() -> Dictionary:
	var m := {}
	var p: float = -PENALTY[severity] * _penalty_scale()
	if p == 0.0:
		return m
	for k in PARTS[part]:
		m[k] = p
	return m


## Day-to-day injuries still bite for a couple of games after the player is back.
func _penalty_scale() -> float:
	if days_total > 0:
		return clampf(float(days_out) / float(days_total), 0.0, 1.0)
	var tail := 2
	var total := games_total + tail
	var left := games_out + tail
	return clampf(float(left) / float(total), 0.0, 1.0) if left > 0 else 0.0


## One game passed (played or missed).
func tick_game() -> void:
	games_out -= 1
	if games_out < -2:
		games_out = -2


## One day passed: day-counted injuries heal by the day.
func tick_day() -> void:
	if days_out > 0:
		days_out -= 1


# ------------------------------------------------------------ the model

## Chance that a hit injures the victim. `impact` is the effective hit
## strength the physics computed (closing speed times hit power over balance,
## roughly 2 for a routine knockdown, 6+ for a big open-ice hit). A routine
## hit is ~0.2%, a big one ~1%, so a player gets hurt every couple of dozen
## games, mostly day-to-day.
static func hit_chance(attacker: Skills, victim: Skills, impact: float, fatigue: float) -> float:
	var base := 0.0015 * pow(maxf(impact, 0.0) / 2.5, 2.0)
	var hitter := lerpf(0.8, 1.3, attacker.n("hitting")) if attacker else 1.0
	var tired := 1.0 + 0.6 * clampf(fatigue, 0.0, 1.0)
	return clampf(base * hitter * victim.injury_risk() * tired, 0.0, 0.08)


## Rolls an injury from a hit, or returns null.
static func roll_hit(attacker: Skills, victim: Skills, impact: float, fatigue: float, rng: RandomNumberGenerator) -> Injury:
	if rng.randf() >= hit_chance(attacker, victim, impact, fatigue):
		return null
	return create(rng, impact)


## Background wear per game for sim games (blocked shots, falls, pucks to the face).
static func roll_wear(victim: Skills, rng: RandomNumberGenerator) -> Injury:
	if rng.randf() >= 0.006 * victim.injury_risk():
		return null
	return create(rng, 2.0)


static func create(rng: RandomNumberGenerator, impact: float) -> Injury:
	var inj := Injury.new()
	var r := rng.randf() + clampf((impact - 3.0) * 0.05, 0.0, 0.2)
	if r < 0.45:
		inj.severity = Severity.DAY_TO_DAY
	elif r < 0.78:
		inj.severity = Severity.MINOR
	elif r < 0.95:
		inj.severity = Severity.MODERATE
	else:
		inj.severity = Severity.MAJOR
	var parts := PARTS.keys()
	inj.part = parts[rng.randi() % parts.size()]
	var range_: Array = GAMES_OUT[inj.severity]
	inj.games_out = rng.randi_range(range_[0], range_[1])
	inj.games_total = inj.games_out
	if inj.severity == Severity.MAJOR and rng.randf() < 0.4:
		for k in PARTS[inj.part]:
			inj.permanent[k] = -rng.randf_range(1.0, 4.0)
	return inj


## A slip on the ice in shoes (IceBalance): a minor knock that keeps the
## owner sore for a day or two.
static func slip(rng: RandomNumberGenerator) -> Injury:
	var inj := Injury.new()
	inj.severity = Severity.MINOR
	inj.part = ["back", "wrist", "knee"][rng.randi() % 3]
	inj.days_out = rng.randi_range(1, 2)
	inj.days_total = inj.days_out
	return inj


func to_dict() -> Dictionary:
	return {"part": part, "severity": severity, "games_out": games_out, "games_total": games_total, "permanent": permanent,
		"days_out": days_out, "days_total": days_total}


static func from_dict(d: Dictionary) -> Injury:
	var inj := Injury.new()
	inj.part = d.part
	inj.severity = int(d.severity)
	inj.games_out = int(d.games_out)
	inj.games_total = int(d.games_total)
	inj.permanent = d.get("permanent", {})
	inj.days_out = int(d.get("days_out", 0))
	inj.days_total = int(d.get("days_total", 0))
	return inj
