class_name TorqueWrench
extends RefCounted
## A click-type torque wrench on a Fastener (RINK_SIM 4.1 "torque: hold the
## click"). Turn input goes through pull(); the dial fills toward the set
## point and the wrench clicks when the fastener reaches it. The head breaks
## over for a few degrees after the click, so stopping on the click is easy,
## but keep pulling past that and the bolt goes on tightening: overtorque.
##
## Usage, once a tick while the grab is held:
##   wrench.pull(frame.turn)
##   if wrench.clicked_now: play the click, rumble the pad
##   dial shows wrench.dial()
## and on release (frame.grab_released) call wrench.release().

## The break-over after the click, in degrees of handle travel that don't
## turn the bolt.
const GIVE_DEG := 6.0
## One press of the dial adjust, ft-lb.
const DIAL_STEP := 1.0

var fastener: Fastener
var set_point := 35.0
var clicked := false          # has clicked since the last release
var clicked_now := false      # clicked on this pull
var overpulled := false       # kept pulling past the break-over
var _give := 0.0


func _init(f: Fastener = null, set_point_ := -1.0) -> void:
	fastener = f
	if set_point_ > 0.0:
		set_point = set_point_
	elif f and f.target_torque > 0.0:
		set_point = f.target_torque


## Turns the dial: + steps raise the set point.
func adjust(steps: int) -> void:
	set_point = clampf(set_point + steps * DIAL_STEP, 5.0, 150.0)


## 0..1 of the way to the set point (the needle; it can pass 1).
func dial() -> float:
	return fastener.torque() / set_point if fastener else 0.0


## Applies `turns` of handle travel; returns the turns the fastener took.
func pull(turns: float) -> float:
	clicked_now = false
	if fastener == null or turns == 0.0:
		return 0.0
	if turns < 0.0:
		# ratcheting back: the handle swings free
		return 0.0
	var deg := turns * 360.0
	if clicked:
		# the head is broken over: the first GIVE_DEG of travel is free
		var free := minf(deg, maxf(0.0, GIVE_DEG - _give))
		_give += free
		deg -= free
		if deg <= 0.0:
			return 0.0
		overpulled = true
		return fastener.turn(deg / 360.0, Fastener.Tool.TORQUE_WRENCH)
	var applied := 0.0
	# step so the click lands on the set point and not a tick later
	var to_click := INF
	if fastener.seated() and fastener.stiffness > 0.0:
		to_click = maxf(0.0, (set_point - fastener.torque()) / fastener.stiffness)
	elif not fastener.seated():
		to_click = (fastener.thread_turns - fastener.run) * 360.0 + set_point / maxf(fastener.stiffness, 0.0001)
	var first := minf(deg, to_click)
	applied += fastener.turn(first / 360.0, Fastener.Tool.TORQUE_WRENCH)
	deg -= first
	if fastener.torque() >= set_point - 0.001:
		clicked = true
		clicked_now = true
		_give = 0.0
		if deg > 0.0:
			applied += pull(deg / 360.0)
			clicked_now = true
	return applied


## Hands off the handle: the head resets for the next pull.
func release() -> void:
	clicked = false
	_give = 0.0
