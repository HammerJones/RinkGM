class_name Skills
extends RefCounted
## A player's ratings on a 1..100 scale: the single store every system reads
## (on the ice through Skater.skill() and the physics' PhysicsProfile, which
## owns the rating-to-physics curves).
##
## `values` hold the trained rating; `modifiers` hold temporary changes
## (injuries, fatigue, equipment later on). Everything reads `eff()`, so a
## hurt or tired player is slower on the ice with no extra plumbing.

const SKATER_KEYS := [
	"speed",           # top speed (PhysicsProfile: 12 mph at 1, 25 mph at 100)
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
## Off-ice conditioning a skater trains in the gym and pickup games
## (playtest #29, #33). Kept out of SKATER_KEYS so generated rosters, their
## random draws and the overall rating stay as they were: stamina is derived
## from speed and toughness when a player is made or an old save loads.
const CONDITIONING := ["stamina"]

const LABELS := {
	"speed": "Speed", "agility": "Agility", "stick_handling": "Stick handling",
	"shot_accuracy": "Shot accuracy", "shot_power": "Shot power", "shot_release": "Shot release",
	"pass_quality": "Passing", "hitting": "Hitting", "toughness": "Toughness",
	"reflexes": "Reflexes", "positioning": "Positioning", "rebound_control": "Rebound control",
	"glove": "Glove", "stamina": "Stamina",
}

## Overall-rating weights by position. Keys missing from a position count 0.
const WEIGHTS := {
	"F": {"speed": 1.2, "agility": 1.0, "stick_handling": 1.2, "shot_accuracy": 1.1, "shot_power": 0.8,
		"shot_release": 1.0, "pass_quality": 1.1, "hitting": 0.4, "toughness": 0.5},
	"D": {"speed": 0.9, "agility": 1.0, "stick_handling": 0.8, "shot_accuracy": 0.6, "shot_power": 1.0,
		"shot_release": 0.5, "pass_quality": 1.2, "hitting": 1.1, "toughness": 1.0},
	"G": {"reflexes": 1.3, "positioning": 1.2, "rebound_control": 0.9, "glove": 1.0, "toughness": 0.4},
}

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


## Fills in conditioning a skater doesn't have yet (new or old saves),
## from speed and toughness; no random draws.
func derive_conditioning() -> void:
	if is_goalie() or values.has("stamina"):
		return
	values["stamina"] = clampf((float(values.get("speed", 50.0)) + float(values.get("toughness", 50.0))) * 0.5, 1.0, 100.0)


## 0.75 (fit) .. 1.25 (gassed): how fast games and work tire this player.
func tire_rate() -> float:
	return lerpf(1.25, 0.75, n("stamina")) if values.has("stamina") else 1.0


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


# ------------------------------------------------------------ career formulas

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
	s.derive_conditioning()
	return s
