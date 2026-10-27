class_name ResurfaceAutopilot
extends RefCounted
## Drives a ResurfaceRun round the standard pattern the way a steady driver
## does: fill the tanks at the standpipe, out through the gate, conditioner
## down at the first lap, the controls set for the kind of cut, conditioner
## up when the loops are done, back to the bay, dump at the pit. Pure
## pursuit on the rear axle. For the tests, the previews and Earl.
##
##   var ap := ResurfaceAutopilot.new(run, ResurfaceAutopilot.NORMAL)
##   while not ap.done: ap.tick(1.0 / 30.0)

## Control settings per kind of cut (the blade wheel in mm: 1/16 in for a
## normal cut, which takes about half a tank of snow off 1/32 in of ice).
const NORMAL := {"kind": "normal", "valve": 0.65, "blade_mm": 1.5875, "wash": true, "towel": true}
const DRY := {"kind": "dry", "valve": 0.0, "blade_mm": 1.5875, "wash": false, "towel": false}
const FLOOD := {"kind": "flood", "valve": 0.65, "blade_mm": 0.0, "wash": false, "towel": true}
const LOOKAHEAD := 3.2

var run: ResurfaceRun
var settings := {}
var fill_first := true
var phase := "fill"   # fill, out, cut, home, dump, done
var done := false
var idx := 0
var points: Array[Vector2] = []
var marks := {}
## Overrides for the tests: a speed for the cut, and the dump skipped.
var cut_speed := ResurfaceRun.CUT_SPEED
var dump_at_end := true
var _mark_idx := {}
var _stuck := 0.0
var _reverse := 0.0
var _dump_tried := false
## The bin filled and jammed solid, and the cut was cut short.
var gave_up := false


func _init(r: ResurfaceRun, s := NORMAL) -> void:
	run = r
	settings = s
	var p := ResurfaceRun.standard_pattern()
	points = p.points
	marks = p.marks
	for i: int in marks:
		_mark_idx[str(marks[i])] = i


## One tick: sets the controls and drives. Returns the inputs it used.
func tick(dt: float) -> Dictionary:
	var throttle := 0.0
	var steer_in := 0.0
	var brake := 0.0
	match phase:
		"fill":
			run.fill = fill_first
			if not fill_first or (run.flood_l >= ResurfacerSim.FLOOD_TANK_L - 0.5 and run.wash_l >= ResurfacerSim.WASH_TANK_L - 0.5):
				run.fill = false
				phase = "out"
			brake = 1.0
		"out", "cut", "home":
			if phase == "out" and run.on_ice() and not run.cond_down:
				# lower her as she comes onto the ice: the lift takes 5 s
				run.cond_down = true
				run.auger_v = true
				run.auger_h = true
			if run.jammed and not gave_up:
				_clear_jam()
				brake = 1.0
			else:
				var d := _pursue(dt)
				throttle = d.throttle
				steer_in = d.steer
				_phase_marks()
		"dump":
			brake = 1.0
			if absf(run.speed) < 0.05:
				if not _dump_tried:
					_dump_tried = true
					run.dump = true
				elif not run.dump:
					phase = "done"
					done = true
		"done":
			brake = 1.0
			done = true
	if absf(throttle) > 0.01:
		run.gear = 1 if throttle > 0.0 else -1
	run.step(dt, throttle, steer_in, brake)
	return {"throttle": throttle, "steer": steer_in, "brake": brake}


func _phase_marks() -> void:
	var start: int = _mark_idx.get("start", 0)
	var cut_end: int = _mark_idx.get("cut_end", points.size() - 1)
	var park: int = _mark_idx.get("park", points.size() - 1)
	if phase == "out" and idx >= start + 2:
		phase = "cut"
		run.cond_down = true
		run.towel_down = bool(settings.towel)
		run.wash_on = bool(settings.wash)
		run.wash_valve = 1.0 if bool(settings.wash) else 0.0
		run.auger_v = true
		run.auger_h = true
		run.flood_valve = float(settings.valve)
		run.blade_mm = float(settings.blade_mm)
	elif phase == "cut" and idx > cut_end:
		_end_cut()
	elif phase == "home" and idx >= park - 1 and run.pos.distance_to(points[park]) < 1.2:
		if dump_at_end and run.bin_m3 > 0.0:
			phase = "dump"
		else:
			phase = "done"
			done = true


## Conditioner up, water off, and back to the gate.
func _end_cut() -> void:
	phase = "home"
	run.flood_valve = 0.0
	run.wash_on = false
	run.towel_down = false
	run.cond_down = false
	run.blade_mm = 0.0
	run.wash_valve = 0.0
	var gate: int = _mark_idx.get("gate", points.size() - 4)
	idx = maxi(idx, gate - 1) if gave_up else idx


func _clear_jam() -> void:
	run.cond_down = false
	if run.bin_fill() >= 0.98:
		# the tank's packed solid: no plunger clears that. Off home to dump.
		gave_up = true
		_end_cut()
		return
	run.plunger = true
	if not run.jammed:
		run.plunger = false


## Pure pursuit to a point LOOKAHEAD ahead on the path.
func _pursue(dt: float) -> Dictionary:
	if run.plunger and not run.jammed:
		run.plunger = false
		if phase == "cut":
			run.cond_down = true
	# the next waypoint is passed once it's close or behind (along the path)
	while idx < points.size() - 1:
		var a := points[idx]
		var b := points[idx + 1]
		if run.pos.distance_to(a) < 1.6 or (a - run.pos).dot(b - a) < 0.0:
			idx += 1
		else:
			break
	# the lookahead point: from where she is on the current leg, LOOKAHEAD
	# metres on along the path
	var a0 := points[maxi(idx - 1, 0)]
	var b0 := points[idx]
	var seg := b0 - a0
	var u := clampf((run.pos - a0).dot(seg) / maxf(seg.length_squared(), 0.0001), 0.0, 1.0)
	var at := a0 + seg * u
	var left := LOOKAHEAD
	var tgt := b0
	var k := idx
	var from := at
	while k < points.size():
		var dd := from.distance_to(points[k])
		if dd >= left:
			tgt = from + (points[k] - from) * (left / maxf(dd, 0.0001))
			break
		left -= dd
		from = points[k]
		tgt = points[k]
		k += 1
	var to := tgt - run.pos
	var alpha := wrapf(to.angle() - run.heading, -PI, PI)
	var ld := maxf(to.length(), 0.5)
	var steer := atan2(2.0 * ResurfaceRun.WHEELBASE * sin(alpha), ld)
	var want := cut_speed if phase == "cut" else 2.6
	if phase == "home" and run.in_bay():
		want = 1.0
	want = lerpf(want, 1.0, clampf(absf(alpha) / 0.9, 0.0, 1.0))
	if idx >= points.size() - 2:
		want = minf(want, maxf(run.pos.distance_to(points[-1]) * 0.8, 0.3))
	# boxed in against a wall: back up a little and try again
	if _reverse > 0.0:
		_reverse -= dt
		return {"throttle": -0.6, "steer": -clampf(steer / ResurfaceRun.MAX_STEER, -1.0, 1.0)}
	if absf(run.speed) < 0.05 and want > 0.5:
		_stuck += dt
	else:
		_stuck = maxf(_stuck - dt, 0.0)
	if _stuck > 1.0:
		_stuck = 0.0
		_reverse = 2.0
	return {"throttle": want / ResurfaceRun.TOP_SPEED, "steer": clampf(steer / ResurfaceRun.MAX_STEER, -1.0, 1.0)}
