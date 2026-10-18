class_name HandPump
extends RefCounted
## The oil hand pump (RINK_SIM 4.2 step 11: pump in new oil to half the
## sight glass). The handle position comes from JobInput.Frame.pump, 0 down
## .. 1 up; each downstroke delivers oil in proportion to its travel, so
## partial strokes count. Pump too fast and it slips (sucks air): the stroke
## delivers only part of its oil and `slipping` is set for the feedback.
##
## Usage, once a tick while the grab is held:
##   pump.stroke(frame.pump, dt)
##   sight glass shows pump.level()
## then grade(skill) when the player calls it done.

## Litres per full downstroke.
var stroke_l := 0.25
## Handle travel per second above which it slips (a full downstroke faster
## than a third of a second sucks air).
var max_rate := 3.0
## Oil already in the sump, and the level that reads half the sight glass.
var litres := 0.0
var target_l := 30.0
var tol_l := 1.0
## The sight glass spans this much oil, centred on the target.
var glass_l := 4.0

var slipping := false
var _handle := NAN


func _init(start_l := 0.0, target := 30.0) -> void:
	litres = start_l
	target_l = target


## Moves the handle to `handle` (0..1); returns the litres delivered.
func stroke(handle: float, dt: float) -> float:
	handle = clampf(handle, 0.0, 1.0)
	slipping = false
	if is_nan(_handle):
		_handle = handle
		return 0.0
	var travel := _handle - handle   # + while pushing down
	_handle = handle
	if travel <= 0.0:
		return 0.0
	var eff := 1.0
	var rate := travel / maxf(dt, 0.0001)
	if rate > max_rate:
		slipping = true
		eff = clampf(max_rate / rate, 0.2, 1.0) * 0.6
	var l := travel * stroke_l * eff
	litres += l
	return l


## 0..1 up the sight glass (0.5 is the mark; it can sit off either end).
func level() -> float:
	return 0.5 + (litres - target_l) / glass_l


## The step score per RINK_SIM 4.1. Overfilling causes carry-over and foaming.
func grade(skill := 0.3) -> Dictionary:
	var widen := lerpf(1.0, 1.6, clampf((skill - 0.3) / 0.6, 0.0, 1.0))
	var tol := tol_l * widen
	var err := litres - target_l
	var flags: Array[StringName] = []
	var score := 1.0 - 0.15 * absf(err) / tol
	if absf(err) > tol:
		score = 0.7
		flags.append(&"oil_overfilled" if err > 0.0 else &"oil_underfilled")
	return {"score": clampf(score, 0.7, 1.0), "error": err, "tolerance": tol, "flags": flags}
