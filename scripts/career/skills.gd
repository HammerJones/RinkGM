class_name Skills
extends RefCounted
## A player's ratings on a 1..100 scale, plus the curves that turn them into
## the numbers the on-ice simulation uses. This is the one place where a
## rating becomes a speed, a turn rate or an error angle, so balance tuning
## between the physics and the career side happens here.
##
## `values` hold the trained rating; `modifiers` hold temporary changes
## (injuries, fatigue, equipment later on). Physics reads `eff()`.

const SKATER_KEYS := [
	"speed",           # top speed: 14 mph at 1, 25 mph at 100 (sprinting)
	"agility",         # turn rate, edge grip, balance while turning
	"stick_handling",  # blade speed, how tightly the puck stays on the blade
	"shot_accuracy",   # aim error
	"shot_power",      # puck speed
	"shot_release",    # how long a shot takes to load, and how good an instant one is
	"pass_quality",    # pass accuracy, receiving, tape-to-tape for the target
	"hitting",         # how hard checks land
	"toughness",       # staying up through contact, injury resistance
]
const GOALIE_KEYS := ["reflexes", "positioning", "rebound_control", "glove", "toughness"]

const LABELS := {
	"speed": "Speed", "agility": "Agility", "stick_handling": "Stick handling",
	"shot_accuracy": "Shot accuracy", "shot_power": "Shot power", "shot_release": "Shot release",
	"pass_quality": "Passing", "hitting": "Hitting", "toughness": "Toughness",
	"reflexes": "Reflexes", "positioning": "Positioning", "rebound_control": "Rebound control",
	"glove": "Glove",
}

## Overall-rating weights by position. Keys missing from a position count 0.
const WEIGHTS := {
	"F": {"speed": 1.2, "agility": 1.0, "stick_handling": 1.2, "shot_accuracy": 1.1, "shot_power": 0.8,
		"shot_release": 1.0, "pass_quality": 1.1, "hitting": 0.4, "toughness": 0.5},
	"D": {"speed": 0.9, "agility": 1.0, "stick_handling": 0.8, "shot_accuracy": 0.6, "shot_power": 1.0,
		"shot_release": 0.5, "pass_quality": 1.2, "hitting": 1.1, "toughness": 1.0},
	"G": {"reflexes": 1.3, "positioning": 1.2, "rebound_control": 0.9, "glove": 1.0, "toughness": 0.4},
}

const MPH := 0.44704
const SPRINT_FACTOR := 1.12  # Skater sprints at top_speed * this

var values := {}
var modifiers := {}


static func create(keys: Array, base: float, spread: float, rng: RandomNumberGenerator) -> Skills:
	var s := Skills.new()
	for k in keys:
		s.values[k] = clampf(base + rng.randfn(0.0, spread), 1.0, 100.0)
	return s


## Effective rating (trained value plus temporary modifiers), 1..100.
func eff(key: String) -> float:
	return clampf(values.get(key, 50.0) + modifiers.get(key, 0.0), 1.0, 100.0)


## Effective rating as 0..1, the input to every curve below.
func n(key: String) -> float:
	return (eff(key) - 1.0) / 99.0


func is_goalie() -> bool:
	return values.has("reflexes")


func overall(group: String) -> float:
	var w: Dictionary = WEIGHTS[group]
	var total := 0.0
	var sum_w := 0.0
	for k in w:
		if values.has(k):
			total += eff(k) * w[k]
			sum_w += w[k]
	return total / maxf(sum_w, 0.001)


# ------------------------------------------------------------ skating

## Absolute top speed in m/s while sprinting (25 mph for a 100 skater).
func max_speed() -> float:
	return lerpf(14.0, 25.0, n("speed")) * MPH


## Cruising top speed the skater model uses (sprint multiplies it).
func top_speed() -> float:
	return max_speed() / SPRINT_FACTOR


func accel() -> float:
	return lerpf(5.0, 7.8, n("speed") * 0.6 + n("agility") * 0.4)


## Multiplier on how fast the skater can swing their heading.
func turn_mult() -> float:
	return lerpf(0.75, 1.3, n("agility"))


## Multiplier on edge grip (how quickly sideways slide is killed).
func grip_mult() -> float:
	return lerpf(0.85, 1.2, n("agility"))


## Turning faster than this (rad/s) while carrying starts to work the puck loose.
func safe_turn_rate() -> float:
	return lerpf(2.6, 6.0, n("agility") * 0.6 + n("stick_handling") * 0.4)


## Chance per second of losing the puck at a given turn rate.
func turn_puck_loss(yaw_rate: float) -> float:
	var over := absf(yaw_rate) / safe_turn_rate() - 1.0
	return 0.0 if over <= 0.0 else clampf(over * 2.5, 0.0, 6.0)


## Balance, 0.5..1.5: higher keeps a skater on their feet. Sharp turns lower it.
func balance(yaw_rate: float) -> float:
	var b := lerpf(0.75, 1.35, n("toughness") * 0.6 + n("agility") * 0.4)
	var over := maxf(0.0, absf(yaw_rate) / safe_turn_rate() - 0.6)
	return clampf(b * (1.0 - 0.35 * minf(over, 1.0)), 0.5, 1.5)


# ------------------------------------------------------------ stick and puck

## Multiplier on blade speed and on the puck spring (the demo's `handling`).
func handling() -> float:
	return lerpf(0.72, 1.3, n("stick_handling"))


# ------------------------------------------------------------ shooting

## Seconds of wind-up for a full-quality wrist shot.
func release_time() -> float:
	return lerpf(0.5, 0.14, n("shot_release"))


## Seconds of wind-up for a full slapshot.
func slap_windup_time() -> float:
	return lerpf(1.1, 0.55, n("shot_release") * 0.6 + n("shot_power") * 0.4)


## Shot quality 0..1 after winding for `t` seconds. An instant shot gets the
## floor, which rises with release skill, so good shooters have a real snap.
func shot_quality(t: float) -> float:
	var floor_q := lerpf(0.2, 0.75, n("shot_release"))
	return lerpf(floor_q, 1.0, clampf(t / release_time(), 0.0, 1.0))


## Multiplier on puck speed. Quality scales a wrist shot from weak to full.
func shot_speed_mult(quality := 1.0) -> float:
	return lerpf(0.78, 1.18, n("shot_power")) * lerpf(0.55, 1.0, quality)


## Max aim error (radians) for a shot of the given quality.
func shot_error(quality := 1.0) -> float:
	return lerpf(0.085, 0.012, n("shot_accuracy")) * lerpf(2.2, 1.0, quality)


# ------------------------------------------------------------ passing

## Max aim error (radians) on a pass.
func pass_error() -> float:
	return lerpf(0.11, 0.004, n("pass_quality"))


## Multiplier on the relative speed a skater can still trap.
func receive_mult() -> float:
	return lerpf(0.72, 1.45, n("pass_quality") * 0.7 + n("stick_handling") * 0.3)


## Extra trap allowance (m/s) the intended target gets, set by the passer.
## At 100 a pass is effectively always caught by the player it was meant for.
func tape_to_tape_bonus() -> float:
	return lerpf(2.0, 30.0, pow(n("pass_quality"), 2.0))


# ------------------------------------------------------------ contact

## Multiplier on how hard this skater's checks land.
func hit_power() -> float:
	return lerpf(0.6, 1.5, n("hitting"))


## 0..1, scales the chance a hard hit injures this player (lower is better).
func injury_risk() -> float:
	return lerpf(1.6, 0.35, n("toughness"))


# ------------------------------------------------------------ goalies

## The demo goalie's 0..1 `skill`.
func goalie_skill() -> float:
	var g := (n("reflexes") * 1.3 + n("positioning") * 1.2 + n("glove") + n("rebound_control") * 0.9) / 4.4
	return lerpf(0.45, 0.8, g)


# ------------------------------------------------------------ save data

func to_dict() -> Dictionary:
	return {"values": values.duplicate(), "modifiers": modifiers.duplicate()}


static func from_dict(d: Dictionary) -> Skills:
	var s := Skills.new()
	s.values = d.get("values", {}).duplicate()
	s.modifiers = d.get("modifiers", {}).duplicate()
	return s
