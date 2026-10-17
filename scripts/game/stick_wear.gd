class_name StickWear
extends RefCounted
## Sticks wear out and break. Every hard load on a stick is a `stress`, about
## 1 for a full slapshot: a slapshot or one-timer, blocking a hot puck with
## the blade, a hard poke, being stick-lifted, falling on it. Each one wears
## the stick a little (`Skater.stick_health`, 1 new .. 0 worn out; the
## shop's condition 100..0) and may snap it. The odds climb steeply as a stick
## wears and drop with a more durable one.
##
## A standard stick (`Skater.stick_durability` 1) in new condition breaks
## about 2% of the time over a game's worth of ice time (15 minutes), so a
## shop stick's durability is 0.02 / its `break_per_game`: wood (0.006) about
## 3.3, the NECRO-X (0.05) 0.4.
##
## A skater with a broken stick drops the pieces and can't touch the puck
## until they get a new one: stop at their bench door (Game.bench_spot) for
## a moment, or pick one up at the next faceoff. Each break is reported
## through Game.stick_broken, and the pieces lie on the ice until the
## whistle.

const WEAR := 0.02         # health a standard stick loses per unit of stress
const BREAK := 0.0028      # chance a new standard stick snaps per unit of stress (~7 units per 15 min on ice)
const WORN_BREAK := 8.0    # ... and how many times likelier when worn out
const BENCH_STOP := 0.5    # seconds stopped at the bench door to be handed a new stick
const BENCH_REACH := 1.8   # how close to the bench door that is (m)

## Shop durability for a stick that breaks `break_per_game` of the time.
static func durability_for(break_per_game: float) -> float:
	return 0.02 / maxf(break_per_game, 0.0005)


## Puts `amount` of load on the stick. Returns true if it snapped.
## `cause` is &"slapshot" (any shot), &"block", &"slash" (stick on stick),
## &"lift" or &"check" (knocked down onto it).
static func stress(s: Skater, amount: float, cause: StringName) -> bool:
	if s.stick_broken or amount <= 0.0:
		return false
	var dur := maxf(s.stick_durability, 0.1)
	var worn := 1.0 - s.stick_health
	s.stick_health = maxf(0.0, s.stick_health - amount * WEAR / dur)
	if randf() >= amount * BREAK * (1.0 + WORN_BREAK * worn * worn) / dur:
		return false
	snap(s, cause)
	return true


## Breaks the stick now. The puck comes off the blade on the next step.
static func snap(s: Skater, cause: StringName) -> void:
	s.stick_broken = true
	s.stick_health = 0.0
	s.game.on_stick_broken(s, cause)


## A new stick from the bench.
static func fresh(s: Skater) -> void:
	s.stick_broken = false
	s.stick_health = 1.0
	s.bench_wait = 0.0


## Per step for a skater without a stick: hands them a new one once they've
## stopped at their bench door.
static func update(s: Skater, dt: float) -> void:
	if not s.stick_broken:
		return
	var door: Vector2 = s.game.bench_spot(s.team)
	if Vector2(s.position.x, s.position.z).distance_to(door) < BENCH_REACH and s.speed() < 2.5:
		s.bench_wait += dt
		if s.bench_wait >= BENCH_STOP:
			fresh(s)
			s.game.on_new_stick(s)
	else:
		s.bench_wait = 0.0
