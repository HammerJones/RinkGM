class_name DemoHands
extends Node
## The mouse as hands, not as a place for the blade (Sean's ask,
## 2026-10-26). The game's PlayerInput folds mouse motion into a stick
## position and throws the hand's speed away; this reads the motion again
## as a velocity and uses it three ways, all on top of HumanController's
## controls, nothing in the game's scripts changed:
##   lead     the blade's target is pushed ahead along the hand's motion, so
##            a flick goes further and faster than a slow draw;
##   weight   the target is carried by a mass on a spring, damped by the
##            stick-handling rating: a good player's stick arrives where the
##            hand is, a weak one's overshoots and rings;
##   swing    a shot drawn with RMB releases when the swing stops (the hand
##            comes to rest after a fast stroke), not only when RMB is let
##            go: the puck leaves at the end of the stroke.
## The view is pulled a little the way of a hard sweep, so the hands are
## felt in the eyes too.

const LEAD_S := 0.08  # s of hand motion the blade's target leads by
const SPRING_HZ := 6.0  # the hands' spring
const DAMP_WEAK := 0.45  # damping ratio at stick handling 0
const DAMP_GOOD := 1.0  # ... at 100 (no overshoot)
const SWING_MIN := 600.0  # px/s a stroke must reach to count as a swing
const SWING_REST := 0.12  # share of the peak the hand slows to at the end of the swing
const SWING_REST_TICKS := 3
const PULL_RAD := deg_to_rad(3.0)  # the view's pull at PULL_PX px/s
const PULL_PX := 2000.0
const PULL_DECAY := 8.0  # 1/s

## Mouse motion this tick in screen px (x right, y up), from the devices or `feed`.
var hand_px := Vector2.ZERO
## The hand's speed, px/s, after the last `shape`.
var hand_speed := 0.0
## Where the hands' weight has the stick (screen space, unit circle), after `shape`.
var stick := Vector2.ZERO
## The view's pull (radians about the up axis) this tick.
var pull := 0.0
## Fires when a swing ends: Callable() with no arguments (the demo releases the shot).
var on_swing_end := Callable()
var swings := 0  # swings released so far (tests)
var _vel := Vector2.ZERO
var _accum := Vector2.ZERO
var _scripted := false
var _peak := 0.0
var _rest_ticks := 0
var _tracing := false


func _ready() -> void:
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_accum += Vector2(event.relative.x, -event.relative.y)


## Tests and views feed the hand instead of the mouse: `px` this tick.
func feed(px: Vector2) -> void:
	_scripted = true
	_accum = px


## One tick, after the controller filled `c` from the devices: the hand's
## velocity leads and weights the stick target, and the swing is watched.
## `sens` is PlayerInput.mouse_sensitivity (stick units per px); `skill` the
## skater's stick handling 0..1; `tracing` whether RMB is drawing a shot.
func shape(
	c: Skater.Controls, s: Skater, dt: float, sens: float, skill: float, tracing: bool
) -> void:
	hand_px = _accum
	_accum = Vector2.ZERO
	hand_speed = hand_px.length() / maxf(dt, 0.0001)
	# the stick target the controller set, back in screen space (x right, y forward)
	var right := Vector2(s.right_vec().x, s.right_vec().z)
	var fwd := Vector2(s.heading.x, s.heading.z)
	var raw := Vector2(c.stick.dot(right), c.stick.dot(fwd))
	var want := raw
	if not tracing:
		want = (raw + hand_px / maxf(dt, 0.0001) * sens * LEAD_S).limit_length(1.0)
	# the weight: a mass on a spring to the target
	var k := pow(TAU * SPRING_HZ, 2.0)
	var zeta := lerpf(DAMP_WEAK, DAMP_GOOD, clampf(skill, 0.0, 1.0))
	var cdamp := 2.0 * zeta * sqrt(k)
	_vel += (k * (want - stick) - cdamp * _vel) * dt
	var prev := stick
	stick = (stick + _vel * dt).limit_length(1.0)
	var world := right * stick.x + fwd * stick.y
	c.stick = world
	var dw := stick - prev
	c.stick_move = right * dw.x + fwd * dw.y
	# the view leans into a hard sweep
	var side := hand_px.x / maxf(dt, 0.0001)
	pull = lerpf(pull, -clampf(side / PULL_PX, -1.0, 1.0) * PULL_RAD, 1.0 - exp(-PULL_DECAY * dt))
	_watch_swing(tracing)


## A swing: the stroke's speed climbs past SWING_MIN, then the hand rests.
func _watch_swing(tracing: bool) -> void:
	if not tracing:
		_tracing = false
		_peak = 0.0
		_rest_ticks = 0
		return
	if not _tracing:
		_tracing = true
		_peak = 0.0
		_rest_ticks = 0
	_peak = maxf(_peak, hand_speed)
	if _peak >= SWING_MIN and hand_speed < _peak * SWING_REST:
		_rest_ticks += 1
		if _rest_ticks >= SWING_REST_TICKS:
			swings += 1
			_peak = 0.0
			_rest_ticks = 0
			if on_swing_end.is_valid():
				on_swing_end.call()
	else:
		_rest_ticks = 0
