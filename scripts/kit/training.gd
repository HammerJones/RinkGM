class_name Training
extends RefCounted
## Off-ice training on the rink's own equipment. A weight-room machine works
## its skills in 15-minute sets that move the clock on (playtest #29), and
## a pickup game in the gym trains agility, stamina and accuracy from how
## you actually played (#33). Both run on the career's progression (the same
## XP, age curve and potential ceilings as practice and games) and cost the
## owner hours and fatigue on the rink sim.
##
## A tired body learns less: the gains fade as the owner's fatigue climbs.
## There's no daily cap (W27): every set takes 15 minutes of the owner's
## day, so the rink's schedule is what limits how much they train.

const SET_MIN := 15
const SET_FATIGUE := 2.5          # owner fatigue (0..100) per set

## Machine id -> {name, xp per set by skill, effort}. Ids match the venue's
## use spots (`data.train`); WEIGHT_ROOM lists what the room has today.
const MACHINES := {
	"squat_rack": {"name": "Squat rack", "xp": {"speed": 2.2, "toughness": 1.6, "shot_power": 0.6}, "effort": 1.3},
	"bench": {"name": "Bench press", "xp": {"shot_power": 1.8, "hitting": 1.6, "toughness": 0.6}, "effort": 1.1},
	"dumbbells": {"name": "Dumbbells", "xp": {"shot_power": 1.0, "shot_release": 1.2, "hitting": 0.8}, "effort": 1.0},
	"treadmill": {"name": "Treadmill", "xp": {"stamina": 2.6, "speed": 0.8}, "effort": 1.2},
	"bike": {"name": "Stationary bike", "xp": {"stamina": 2.4, "agility": 0.4}, "effort": 1.0},
	"universal": {"name": "Universal machine", "xp": {"hitting": 1.0, "shot_power": 1.0, "toughness": 1.0}, "effort": 1.0},
	"slide_board": {"name": "Slide board", "xp": {"agility": 2.2, "speed": 1.0, "stamina": 0.8}, "effort": 1.2},
	"leg_press": {"name": "Leg press", "xp": {"speed": 1.8, "toughness": 1.2, "stamina": 0.4}, "effort": 1.2},
	"cable_crossover": {"name": "Cable crossover", "xp": {"hitting": 1.2, "shot_power": 1.0, "agility": 0.4}, "effort": 1.0},
	"lat_pulldown": {"name": "Lat pulldown", "xp": {"shot_power": 1.0, "hitting": 1.0, "stick_handling": 0.4}, "effort": 1.0},
	"wrist_roller": {"name": "Wrist roller", "xp": {"shot_release": 1.8, "stick_handling": 1.2, "shot_accuracy": 0.6}, "effort": 0.6},
}
const WEIGHT_ROOM := ["squat_rack", "bench", "dumbbells", "treadmill", "bike", "universal"]

## A pickup game's skills and the XP per minute played at full effort.
const PICKUP := {
	"basketball": {"name": "Pickup basketball", "xp_per_min": {"agility": 0.16, "stamina": 0.2}, "accuracy_per_make": 1.4, "effort_per_min": 0.2},
}

## How much of a set sticks with the owner this tired (0..100), 0..1.
static func freshness(owner_fatigue: float) -> float:
	return clampf(1.0 - maxf(owner_fatigue - 30.0, 0.0) / 70.0, 0.15, 1.0)


## One 15-minute set on `machine`: the player's skills grow, the owner's
## hours and fatigue go up, and `advance` (RinkLink.advance, or the sim's)
## moves the clock. Returns {"ok", "machine", "gains": {skill: delta},
## "text"}.
func do_set(machine: String, player: PlayerProfile, sim: RinkSim, advance: Callable = Callable()) -> Dictionary:
	if not MACHINES.has(machine):
		return {"ok": false, "text": "Nothing to train on here."}
	var m: Dictionary = MACHINES[machine]
	var q := freshness(sim.fatigue)
	var xp := {}
	for k in m.xp:
		xp[k] = float(m.xp[k]) * q
	var gains := Progression.apply_xp(player, xp)
	sim.owner_trained(SET_MIN, SET_FATIGUE * float(m.effort))
	if advance.is_valid():
		advance.call(SET_MIN)
	else:
		sim.advance(SET_MIN)
	return {"ok": true, "machine": machine, "gains": gains, "text": _set_text(m.name, gains, q)}


static func _set_text(name: String, gains: Dictionary, q: float) -> String:
	if gains.is_empty() or q <= 0.0:
		return "%s: 15 minutes. Nothing more sticks." % name
	var best := ""
	for k in gains:
		if best == "" or float(gains[k]) > float(gains[best]):
			best = k
	var tired := " You're tired: it sticks less." if q < 0.7 else ""
	return "%s: 15 minutes. %s +%.2f.%s" % [name, Skills.LABELS.get(best, best), float(gains[best]), tired]


## World's TrainingSpot / NPC pickup game signal `trained(skill_keys,
## minutes, intensity)`: `intensity` 0..1 of a full effort, XP spread evenly
## over the keys at a weight set's rate. Only the clock and fatigue; World's
## node decides how long it took. Returns {"gains", "text"}.
func trained(skill_keys: Array, minutes: int, intensity: float, player: PlayerProfile, sim: RinkSim, advance: Callable = Callable()) -> Dictionary:
	var sets := maxi(1, minutes / SET_MIN)
	var q := freshness(sim.fatigue) * clampf(intensity, 0.0, 1.0)
	var xp := {}
	for k in skill_keys:
		xp[k] = 4.0 / maxf(skill_keys.size(), 1.0) * sets * q
	var gains := Progression.apply_xp(player, xp) if q > 0.0 else {}
	sim.owner_trained(minutes, SET_FATIGUE * sets * clampf(intensity, 0.2, 1.5))
	if advance.is_valid():
		advance.call(minutes)
	else:
		sim.advance(minutes)
	return {"gains": gains, "text": _set_text("Training", gains, q)}


## A finished pickup game: `minutes` played, `shots`/`makes` from the shooting.
## Returns {"gains", "text"}.
func pickup(kind: String, minutes: int, shots: int, makes: int, player: PlayerProfile, sim: RinkSim, advance: Callable = Callable()) -> Dictionary:
	var spec: Dictionary = PICKUP.get(kind, PICKUP.basketball)
	var q := freshness(sim.fatigue)
	var xp := {}
	for k in spec.xp_per_min:
		xp[k] = float(spec.xp_per_min[k]) * minutes * q
	# shooting practice: every make counts, misses a little
	xp["shot_accuracy"] = (float(spec.accuracy_per_make) * makes + 0.3 * (shots - makes)) * q
	var gains := Progression.apply_xp(player, xp)
	sim.owner_trained(minutes, float(spec.effort_per_min) * minutes)
	if advance.is_valid():
		advance.call(minutes)
	else:
		sim.advance(minutes)
	return {"gains": gains, "text": "%s: %d minutes, %d of %d shots in." % [spec.name, minutes, makes, shots]}


## Training keeps no state of its own now; the save slot stays for later.
func to_dict() -> Dictionary:
	return {}


static func from_dict(_d: Dictionary) -> Training:
	return Training.new()
