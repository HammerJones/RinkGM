class_name Fastener
extends RefCounted
## A bolt, nut, spark plug or spin-on filter being run down and tightened by
## the turn input (JobInput.Frame.turn). It models the feel the RINK_SIM 4.1
## verbs need and grades the result with the doc's quality math; the job
## scene decides what the grade does to the sim.
##
##   run-down   `thread_turns` free turns until it seats; the first
##              `hand_start` of them must be by hand or it cross-threads
##   seated     torque rises with the angle past the seat (`stiffness`,
##              ft-lb per degree); a hand can't turn past `hand_limit`, which
##              is "hand tight"
##   spec       either a torque (blade bolts 35 ft-lb, housing bolts 25, plugs
##              15) or hand tight plus a part turn (a filter: + 3/4; a gasket
##              plug: + 1/4)
##
## Usage: f.turn(frame.turn, Fastener.Tool.HAND); later f.grade(skill).

enum Tool { HAND, RATCHET, TORQUE_WRENCH }

var thread_turns := 6.0
var hand_start := 1.5
var stiffness := 1.0          # ft-lb per degree past the seat
var hand_limit := 4.0         # ft-lb: how tight fingers get it
## Spec: a torque target (ft-lb), or hand tight plus `plus_turns`.
var target_torque := 0.0
var torque_tol := 3.0
var plus_turns := 0.0
var turns_tol := 1.0 / 16.0

var run := 0.0                # turns run down so far (0 = just started)
var past_seat := 0.0          # degrees turned past the seat
var cross_threaded := false
var stalled := false          # the hand can't turn it any further


## Presets from RINK_SIM 4.2, 4.7 and 4.8.
static func blade_bolt() -> Fastener:
	var f := Fastener.new()
	f.thread_turns = 5.0
	f.stiffness = 0.9
	f.target_torque = 35.0
	f.torque_tol = 3.5
	return f


static func housing_bolt() -> Fastener:
	var f := Fastener.new()
	f.thread_turns = 4.0
	f.stiffness = 0.8
	f.target_torque = 25.0
	f.torque_tol = 2.5
	return f


static func spark_plug() -> Fastener:
	var f := Fastener.new()
	f.thread_turns = 7.0
	f.hand_start = 2.0
	f.stiffness = 0.12          # the crush washer gives
	f.hand_limit = 3.0
	f.target_torque = 15.0
	f.torque_tol = 2.0
	return f


static func oil_filter() -> Fastener:
	var f := Fastener.new()
	f.thread_turns = 4.0
	f.hand_start = 4.0          # spun on by hand all the way
	f.stiffness = 0.04          # the rubber gasket
	f.hand_limit = 6.0
	f.plus_turns = 0.75
	f.turns_tol = 1.0 / 8.0
	return f


func seated() -> bool:
	return run >= thread_turns


## The torque on it now, ft-lb (0 while it's still running down).
func torque() -> float:
	return past_seat * stiffness


## 0..1 of the way to hand tight: what the hand feels as it snugs up.
func effort() -> float:
	return clampf(torque() / maxf(hand_limit, 0.01), 0.0, 1.0)


## Degrees past the seat where it's hand tight.
func hand_tight_deg() -> float:
	return hand_limit / stiffness


## Turns past hand tight (negative before it gets there).
func turns_past_hand_tight() -> float:
	return (past_seat - hand_tight_deg()) / 360.0


## Applies `turns` (+ tightens, - loosens) with `tool`; returns the turns
## that actually happened (a hand stalls at hand tight).
func turn(turns: float, tool: Tool) -> float:
	stalled = false
	if turns == 0.0:
		return 0.0
	if turns > 0.0 and tool != Tool.HAND and run < hand_start and not seated():
		# a wrench before the threads have caught by hand
		cross_threaded = true
	var left := turns
	if left > 0.0 and not seated():
		var take := minf(left, thread_turns - run)
		run += take
		left -= take
	if left > 0.0:
		var deg := left * 360.0
		if tool == Tool.HAND:
			var room := maxf(0.0, hand_tight_deg() - past_seat)
			if deg > room:
				stalled = true
				left -= (deg - room) / 360.0
				deg = room
		past_seat += deg
	elif left < 0.0:
		var deg := -left * 360.0
		var back := minf(deg, past_seat)
		past_seat -= back
		left += back / 360.0
		run = maxf(0.0, run + left)
		left = 0.0
	return turns - left if turns > 0.0 else turns


## The step score, 0.7..1.0 (RINK_SIM 4.1): 1.0 on target, 0.85 at the edge
## of tolerance, 0.7 outside it with a flag. Skill 0.3 is the base window,
## 0.9 widens it 1.6 times.
func grade(skill := 0.3) -> Dictionary:
	var widen := lerpf(1.0, 1.6, clampf((skill - 0.3) / 0.6, 0.0, 1.0))
	var err := 0.0
	var tol := 1.0
	if target_torque > 0.0:
		err = torque() - target_torque
		tol = torque_tol * widen
	else:
		err = turns_past_hand_tight() - plus_turns
		tol = turns_tol * widen
	var flags: Array[StringName] = []
	if cross_threaded:
		flags.append(&"cross_threaded")
	var score := 1.0 - 0.15 * absf(err) / tol
	if absf(err) > tol:
		score = 0.7
		flags.append(&"bolt_overtorqued" if err > 0.0 else &"bolt_undertorqued")
	if not seated():
		score = 0.7
		if not flags.has(&"bolt_undertorqued"):
			flags.append(&"bolt_undertorqued")
	if cross_threaded:
		score = minf(score, 0.7)
	return {"score": clampf(score, 0.7, 1.0), "error": err, "tolerance": tol, "flags": flags}
