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
const SPRING_HZ := 14.0  # the hands' spring: tight, the stick is in the hands (Sean: no rubber band)
const SPRING_HZ_FAST := 24.0  # ... at response 1 (stick level 10): less inertia, faster
const ARC := deg_to_rad(100.0)  # the stick stays in front of you: past this it was behind and stuck (Sean)
const SPEED_CAP := Vector2(8.0, 14.0)  # reach/s the stick target may move, at response 0 and 1
const DAMP_WEAK := 0.7  # damping ratio at stick handling 0
const DAMP_GOOD := 1.0  # ... at 100 (no overshoot)
const SPRING_SUBSTEPS := 8
const SWING_MIN := 600.0  # px/s a stroke must reach to count as a swing
const SWING_REST := 0.12  # share of the peak the hand slows to at the end of the swing
const SWING_REST_TICKS := 3
const SWING_FORWARD := 0.5  # share of the peak speed that must be forward: a pull back is a windup
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
## 0..1, how much quicker than the base spring the stick answers (the skill's level past 5).
var response := 0.0
## Fires when a swing ends: Callable() with no arguments (the demo releases the shot).
var on_swing_end := Callable()
var swings := 0  # swings released so far (tests)
var _vel := Vector2.ZERO
var _accum := Vector2.ZERO
var _scripted := false
var _peak := 0.0
var _peak_fwd := 0.0  # the hand's forward speed at the peak
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
	want = in_front(want)
	# the weight: a mass on a spring to the target
	var k := pow(TAU * lerpf(SPRING_HZ, SPRING_HZ_FAST, clampf(response, 0.0, 1.0)), 2.0)
	var zeta := lerpf(DAMP_WEAK, DAMP_GOOD, clampf(skill, 0.0, 1.0))
	var cdamp := 2.0 * zeta * sqrt(k)
	var prev := stick
	var sdt := dt / SPRING_SUBSTEPS  # a stiff spring, stepped fine enough to stay stable
	var cap := lerpf(SPEED_CAP.x, SPEED_CAP.y, clampf(response, 0.0, 1.0))
	for i in SPRING_SUBSTEPS:
		_vel += (k * (want - stick) - cdamp * _vel) * sdt
		_vel = _vel.limit_length(cap)  # the hands have a top speed: no snap across the body
		stick += _vel * sdt
		_edges()
	var world := right * stick.x + fwd * stick.y
	c.stick = world
	var dw := stick - prev
	c.stick_move = right * dw.x + fwd * dw.y
	# the view leans into a hard sweep
	var side := hand_px.x / maxf(dt, 0.0001)
	pull = lerpf(pull, -clampf(side / PULL_PX, -1.0, 1.0) * PULL_RAD, 1.0 - exp(-PULL_DECAY * dt))
	_watch_swing(tracing, dt)


## The reach's edge and the arc's: the stick stops there and keeps the
## hand's speed along the edge, no wall to push into and no snap back.
func _edges() -> void:
	if stick.length() > 1.0:
		var n := stick.normalized()
		stick = n
		var out := _vel.dot(n)
		if out > 0.0:
			_vel -= n * out
	if stick.length() < 0.05:
		return
	var a := atan2(stick.x, stick.y)  # from straight ahead, + to the right
	if absf(a) > ARC:
		var lim := signf(a) * ARC
		stick = Vector2(sin(lim), cos(lim)) * stick.length()
		var round_dir := Vector2(cos(lim), -sin(lim)) * signf(a)  # further round
		var into := _vel.dot(round_dir)
		if into > 0.0:
			_vel -= round_dir * into


## `p` brought inside the ARC (its length kept).
static func in_front(p: Vector2) -> Vector2:
	if p.length() < 0.05:
		return p
	var a := atan2(p.x, p.y)
	if absf(a) <= ARC:
		return p
	var lim := signf(a) * ARC
	return Vector2(sin(lim), cos(lim)) * p.length()


## A swing: the stroke's speed climbs past SWING_MIN, then the hand rests.
## Only a forward stroke is the swing: a fast pull back that rests is the
## windup of a wrist or a snap shot (Sean: it was read as a pass), and the
## trace goes on to the stroke that follows.
func _watch_swing(tracing: bool, dt: float) -> void:
	if not tracing:
		_tracing = false
		_peak = 0.0
		_rest_ticks = 0
		return
	if not _tracing:
		_tracing = true
		_peak = 0.0
		_rest_ticks = 0
	if hand_speed > _peak:
		_peak = hand_speed
		_peak_fwd = hand_px.y / maxf(dt, 0.0001)
	if _peak >= SWING_MIN and hand_speed < _peak * SWING_REST:
		_rest_ticks += 1
		if _rest_ticks >= SWING_REST_TICKS:
			var forward := _peak_fwd > _peak * SWING_FORWARD
			_peak = 0.0
			_rest_ticks = 0
			if forward:
				swings += 1
				if on_swing_end.is_valid():
					on_swing_end.call()
	else:
		_rest_ticks = 0
