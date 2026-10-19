class_name IceBalance
extends RefCounted
## Walking the ice in shoes (playtest #19): half walking speed, and a dot
## that wobbles around a circle. The player pushes it back with the mouse or
## the right stick. If it sits outside the circle too long the owner goes
## down: the load drops and a sore day or two follows (Injury.slip). It runs
## only while the walker is on the ice without skates or Gus's crampons,
## and stops the moment they step off.
##
## The dot is a little mass on a spring-less plate: an Ornstein-Uhlenbeck
## push (smooth random gusts, stronger walking fast or carrying a net), the
## player's push, and damping. The circle is the safe zone in the unit disc.

const SPEED_SCALE := 0.5      # walking speed on the ice in shoes
const CIRCLE_R := 0.38        # the safe circle, in the unit disc
const FALL_TIME := 1.4        # seconds outside before the owner goes down
const RECOVER_RATE := 1.5     # outside-time drains this fast once back in
const PUSH := 5.5             # how hard full input pushes the dot
const DAMPING := 2.6
const GUST_RATE := 1.8        # how quickly the gusts change direction
## Gust strength standing still, plus per m/s walked and per load unit
## (a large net is about 1, a mini net 0.4).
const GUST_BASE := 0.6
const GUST_PER_SPEED := 0.5
const GUST_PER_LOAD := 0.9

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var out_time := 0.0
## 0..1: how steady the owner is (agility and fatigue). 0.5 is average.
var steadiness := 0.5
var _gust := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


static func create(seed_ := 0, steadiness_ := 0.5) -> IceBalance:
	var b := IceBalance.new()
	b._rng.seed = seed_ if seed_ != 0 else randi()
	b.steadiness = clampf(steadiness_, 0.0, 1.0)
	return b


## Whether the game should run: on the ice, in shoes, no crampons strapped on.
static func needed(on_ice: bool, crampons: bool, skates := false) -> bool:
	return on_ice and not crampons and not skates


## One step. `input` is the player's push in -1..1 (mouse delta scaled, or
## the right stick), `speed` the walker's ground speed in m/s, `load` what
## they carry. Returns "fell" on the tick the owner goes down, else "".
func tick(dt: float, input: Vector2, speed: float, load := 0.0) -> String:
	var strength := (GUST_BASE + GUST_PER_SPEED * speed + GUST_PER_LOAD * load) * lerpf(1.35, 0.7, steadiness)
	# Ornstein-Uhlenbeck: the gust drifts back toward zero and gets kicked
	var kick := Vector2(_rng.randfn(0.0, 1.0), _rng.randfn(0.0, 1.0))
	_gust += -_gust * GUST_RATE * dt + kick * strength * sqrt(2.0 * GUST_RATE * dt)
	var control := PUSH * lerpf(0.8, 1.2, steadiness)
	vel += (_gust + input.limit_length(1.0) * control - vel * DAMPING) * dt
	pos += vel * dt
	if pos.length() > 1.0:  # the plate's rim
		pos = pos.normalized()
		vel = vel.slide(pos)
	if pos.length() > CIRCLE_R:
		out_time += dt
	else:
		out_time = maxf(0.0, out_time - RECOVER_RATE * dt)
	if out_time >= FALL_TIME:
		reset()
		return "fell"
	return ""


## 0..1 how close the owner is to going down, for the HUD.
func danger() -> float:
	return clampf(out_time / FALL_TIME, 0.0, 1.0)


func reset() -> void:
	pos = Vector2.ZERO
	vel = Vector2.ZERO
	_gust = Vector2.ZERO
	out_time = 0.0
