class_name IceGauges
extends RefCounted
## The arithmetic of the ice measuring tools, kept apart from their popups so
## the tests can check it (docs/world/ICE.md 3).
##
## The dial caliper (a "Mitsutoya" 505 pattern): the beam is graduated in
## whole millimetres (or tenths of an inch), and the dial's needle goes once
## round per millimetre, 50 divisions of 0.02 mm (or once per 0.1 in, 100
## divisions of 0.001 in). The reading is the last beam line the jaw has
## passed plus the dial.
##
## The survey rod: an E-pattern rod in centimetres with millimetre ticks, held
## on the ice; the rotating laser's red line crosses it at the height of the
## laser plane over the ice. A higher spot of ice reads lower on the rod.

const MM_PER_IN := 25.4
## Metric dial: one revolution per mm, 50 divisions.
const DIAL_MM_PER_REV := 1.0
const DIAL_MM_DIVS := 50
## Imperial dial: one revolution per 0.1 in, 100 divisions.
const DIAL_IN_PER_REV := 0.1
const DIAL_IN_DIVS := 100
const CALIPER_RANGE_MM := 150.0


## What the caliper shows for a jaw opening of `mm`:
## {"beam": last beam line passed (mm, or tenths of an inch), "dial": the
##  needle's division (0..49 or 0..99, fractional), "needle": the needle's
##  angle (radians clockwise from the top), "value": the reading (mm or in,
##  rounded to the graduation), "text"}.
static func caliper(mm: float, metric := true) -> Dictionary:
	var m := clampf(mm, 0.0, CALIPER_RANGE_MM)
	if metric:
		var beam := floorf(m / DIAL_MM_PER_REV + 1e-6) * DIAL_MM_PER_REV
		var frac := (m - beam) / DIAL_MM_PER_REV
		var div := frac * DIAL_MM_DIVS
		var v := beam + roundf(div) * (DIAL_MM_PER_REV / DIAL_MM_DIVS)
		return {"beam": beam, "dial": div, "needle": frac * TAU, "value": v, "text": "%.2f mm" % v, "metric": true}
	var inch := m / MM_PER_IN
	var beam_i := floorf(inch / DIAL_IN_PER_REV + 1e-6) * DIAL_IN_PER_REV
	var frac_i := (inch - beam_i) / DIAL_IN_PER_REV
	var div_i := frac_i * DIAL_IN_DIVS
	var vi := beam_i + roundf(div_i) * (DIAL_IN_PER_REV / DIAL_IN_DIVS)
	return {"beam": beam_i, "dial": div_i, "needle": frac_i * TAU, "value": vi, "text": "%.3f in" % vi, "metric": false}


## Reads a caliper back the way the player does: the beam line plus the
## dial division, in mm.
static func caliper_mm(beam: float, dial_div: float, metric := true) -> float:
	if metric:
		return beam + dial_div * (DIAL_MM_PER_REV / DIAL_MM_DIVS)
	return (beam + dial_div * (DIAL_IN_PER_REV / DIAL_IN_DIVS)) * MM_PER_IN


## What a rod reading of `mm` shows: {"cm": the E block the line crosses,
## "mm": the tick within it, "text"}.
static func rod(mm: float) -> Dictionary:
	var v := roundf(mm)
	return {"cm": int(floorf(v / 10.0)), "mm": int(posmod(int(v), 10)), "value": v, "text": "%d.%d cm" % [int(floorf(v / 10.0)), int(posmod(int(v), 10))]}


## How much higher the ice is at a spot than at the reference, mm, from the
## two rod readings (the laser plane is level, so a lower reading is a
## higher surface).
static func rise_mm(rod_ref_mm: float, rod_here_mm: float) -> float:
	return rod_ref_mm - rod_here_mm


## The depth of ice over a plate from the drill hole: the caliper's depth rod
## from the surface down to the plate.
static func plate_depth(ice: IceSlab, id: String, metric := true) -> Dictionary:
	return caliper(ice.plate_depth_mm(id), metric)


## The lidar scan: the ice surface's height over its mean, per coarse block of
## `step` fine cells, mm (what the tablet colours). {"w", "h", "values":
## PackedFloat32Array, "min", "max"}.
static func lidar(ice: IceSlab, step := 4, noise := 0.25, rng: RandomNumberGenerator = null) -> Dictionary:
	ice.flush()
	var w := IceSlab.FW / step
	var h := IceSlab.FD / step
	var vals := PackedFloat32Array()
	vals.resize(w * h)
	var sum := 0.0
	var n := 0
	for bz in h:
		for bx in w:
			var acc := 0.0
			var c := 0
			for dz in step:
				for dx in step:
					var i := (bz * step + dz) * IceSlab.FW + bx * step + dx
					if ice.inside[i] == 1:
						acc += ice.level_at(i)
						c += 1
			if c > 0:
				var v := acc / c + (rng.randfn(0.0, noise) if rng else 0.0)
				vals[bz * w + bx] = v
				sum += v
				n += 1
			else:
				vals[bz * w + bx] = NAN
	var mean := sum / maxf(n, 1)
	var lo := 1e9
	var hi := -1e9
	for k in vals.size():
		if not is_nan(vals[k]):
			vals[k] -= mean
			lo = minf(lo, vals[k])
			hi = maxf(hi, vals[k])
	return {"w": w, "h": h, "values": vals, "min": lo, "max": hi, "step": step}
