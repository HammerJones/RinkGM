class_name ResurfaceRun
extends RefCounted
## One driven resurface, as pure logic: Doris on the ice and in the bay, the
## blade, the augers and the snow tank, the wash water, the flood water and
## the towel, cell by cell on a copy of the ice. The drive scene
## (scripts/world/jobs/doris_drive.gd) and the tests step it; the result goes
## back to RinkSim.job("resurface", result). Numbers: docs/world/ICE.md 4.
##
## Rink metres throughout: x along the rink (the bay is past +x), y across
## (world z). `pos` is the middle of the rear axle, `heading` 0 faces +x.

## The machine.
const WHEELBASE := 1.96
const BODY_REAR := 1.30        # rear axle to the back of the body (the conditioner hangs behind)
const BODY_FRONT := 2.74       # rear axle to the nose
const BODY_HALF_W := 1.065
const COND_BACK := 1.15        # rear axle to the blade
const TOWEL_BACK := 1.75       # rear axle to the middle of the towel
const TOWEL_W := 2.0
const MAX_STEER := deg_to_rad(27.0)   # a 16 ft turn at the conditioner
const STEER_RATE := deg_to_rad(55.0)
const TOP_SPEED := 3.9         # 14 km/h
const REVERSE_SPEED := 1.4
const CUT_SPEED := 2.2         # 8 km/h, the speed the pattern is driven at
const ACCEL := 0.9
const BRAKE := 2.6
const LAT_GRIP := 2.4          # m/s2 on studded tyres before she slides wide
const MASS_EMPTY := 3150.0
## The blade: removal is about half the wheel's setting on hard ice (the
## conditioner rides on the blade and its runners), more on soft.
const BITE := 0.5
const SKIP_FROM_MM := 2.4      # 3/32 in: past this the blade jumps and chatters
## Flood water at 100% valve, L/s (gravity from the tank). 65% lays the full
## tank over the standard pattern at CUT_SPEED (tools/tests/test_ice.gd).
const FLOOD_Q100 := 3.75
const WASH_Q := 0.55
## What the augers lift, m3 of packed snow a second, before they choke.
const AUGER_CAP := 0.011
const TROUGH_M3 := 0.03         # what the horizontal auger's trough holds
const FILL_LPS := 18.0         # the bay's hot standpipe
const DUMP_SECONDS := 8.0
const UNJAM_SECONDS := 6.0
## The conditioner's lift, top to bottom (the 552: about 5 to 6 s).
const COND_TRAVEL_S := 5.5
## The bay, in rink metres (the venue's Zamboni bay, x 34 to 45.5).
const GATE_HALF := 1.75
const BAY_X0 := 34.2
const BAY_X1 := 45.3
const BAY_HALF := 4.8
const PIT := Vector2(44.05, -3.5)
const STANDPIPE := Vector2(40.2, 4.7)
const PARK := Vector2(39.7, 0.0)

var ice: IceSlab
var doris: ResurfacerSim
## Pose and motion.
var pos := Vector2(PARK.x, PARK.y)
var heading := PI       # nose toward the rink door
var speed := 0.0
var steer := 0.0
var sliding := false
var engine_on := true
var rpm := 850.0
## The controls (the drive scene moves them; the autopilot too).
var flood_valve := 0.0          # 0..1
var blade_mm := 0.0             # the blade wheel, 0 .. BLADE_MAX_MM
var wash_on := false
var cond_down := false          # the conditioner lever: down (cond_pos follows it)
var cond_pos := 0.0             # 0 up .. 1 down on the ice; it cuts only fully down
var gear := 1                   # the F/N/R shifter: 1, 0, -1 (the scene drives through it)
var auger_v := true             # the vertical auger's lever (lifts snow to the tank)
var auger_h := true             # the horizontal auger's (carries the cut to the vertical)
var wash_valve := 1.0           # the wash water T-handle, 0..1 (the pump is wash_on)
var towel_down := false         # the rag
var dump := false               # tank raised over the pit
var plunger := false            # held: clearing the vertical auger
var fill := false               # the standpipe hose in the tank
## Tanks and the bin.
var flood_l := 0.0
var wash_l := 0.0
var bin_m3 := 0.0
var flood_temp_c := 60.0
## What happened.
var time_s := 0.0
var dist_m := 0.0
var jammed := false
var jam_risk := 0.0
var jams := 0
var board_hits := 0
var snow_rate := 0.0            # m3 a second into the bin, smoothed (the window shows it)
var blade_quality := 1.0        # 1 a clean scrape, 0 jumping
var skipping := false
var flood_rate := 0.0           # L/s
var flood_state := "off"        # "off", "trickle", "good", "rush"
var water_laid_l := 0.0
var wash_used_l := 0.0
var ice_cut_m3 := 0.0
var snow_picked_m3 := 0.0
var snow_left_m3 := 0.0         # spilled or dropped by a jam
var dumped_m3 := 0.0
var fuel_used := 0.0
var gas_cost := 0.0
## Things the scene turns into signals and Gus's lines: "jam", "unjam",
## "bin_full", "flood_empty", "wash_empty", "board_hit", "dump_start",
## "dump_done", "filled", "on_ice", "off_ice", "slide".
var events: PackedStringArray = []

var _cut_at := PackedFloat32Array()     # forward travel (m) when each fine cell last went under the blade
var _travel := 0.0                      # m driven forward; the blade only cuts moving forward
var _flood_at := PackedFloat32Array()   # ...and under the towel
var _covered := PackedByteArray()
var _covered_n := 0
var _water_cell := PackedFloat32Array() # L laid per cell, for the evenness score
var _recent := {}
var _settle_acc := 0.0
var _freeze_acc := 0.0
var _unjam_t := 0.0
var _dumping := false
var _trough_m3 := 0.0
var _was_on_ice := false
var _before := {}
var _rng := RandomNumberGenerator.new()


## A run on a copy of `ice_` with Doris `doris_` (her tanks, parts and blade
## setting), parked in the bay.
static func start(ice_: IceSlab, doris_: ResurfacerSim) -> ResurfaceRun:
	var r := ResurfaceRun.new()
	r.ice = ice_.copy()
	r.doris = doris_
	r.flood_l = doris_.flood_l
	r.wash_l = doris_.wash_l
	r.flood_temp_c = doris_.flood_temp_c
	r.engine_on = doris_.fault() == ""
	r._cut_at.resize(IceSlab.FCELLS)
	r._cut_at.fill(-1000.0)
	r._flood_at.resize(IceSlab.FCELLS)
	r._flood_at.fill(-1000.0)
	r._covered.resize(IceSlab.FCELLS)
	r._water_cell.resize(IceSlab.FCELLS)
	r._rng.seed = 525
	r._before = {"thickness": r.ice.thickness_mm, "level_sd": r.ice.level_sd_mm(), "gouge": r.ice.mean_gouge_mm(),
		"smooth": r.ice.felt_smoothness(), "level": r.ice.level_score(), "snow": r.ice.snow}
	return r


func fwd() -> Vector2:
	return Vector2(cos(heading), sin(heading))


## Left of the machine as the driver sits (rink y grows to the left of +x).
func left() -> Vector2:
	return Vector2(-sin(heading), cos(heading))


func blade_center() -> Vector2:
	return pos - fwd() * COND_BACK


func on_ice() -> bool:
	return Rink.sdf(blade_center()) < -0.2


func in_bay() -> bool:
	return pos.x > BAY_X0 - 0.5


## The snow tank's lip over the pit grate.
func at_pit() -> bool:
	return (pos + fwd() * 1.6).distance_to(PIT) < 2.2 and absf(speed) < 0.3


## Parked where the standpipe hose reaches the tank fillers.
func at_standpipe() -> bool:
	return pos.distance_to(STANDPIPE) < 5.0 and absf(speed) < 0.2


## The snow tank, 0 empty .. 1 full (over 1 the augers pack solid).
func bin_fill() -> float:
	return bin_m3 / ResurfacerSim.SNOW_TANK_M3


## The blade's real depth of cut on flat ice, mm.
func blade_eff_mm() -> float:
	var sharp := 0.55 + 0.45 * doris.part("blade").condition
	var soft := 1.0 + clampf((ice.surface_temp + 5.0) * 0.06, -0.2, 0.3)
	var holder := (doris.blade_height_mm - 1.0) * 0.5
	return maxf((blade_mm + holder) * BITE * sharp * soft, 0.0)


## Fraction of the standard pattern covered so far (inside the blade's reach).
func coverage() -> float:
	return float(_covered_n) / float(maxi(ice._inside_n - ice._ring_n, 1))


static func allowed(p: Vector2) -> bool:
	if Rink.sdf(p) < -0.02:
		return true
	if p.x > Rink.HALF_L - 1.0 and p.x < BAY_X0 + 0.4 and absf(p.y) < GATE_HALF:
		return true
	return p.x >= BAY_X0 and p.x <= BAY_X1 and absf(p.y) <= BAY_HALF


func _body_ok(p: Vector2, h: float) -> bool:
	var f := Vector2(cos(h), sin(h))
	var l := Vector2(-sin(h), cos(h))
	for c: Vector2 in [p + f * BODY_FRONT + l * BODY_HALF_W, p + f * BODY_FRONT - l * BODY_HALF_W,
			p - f * BODY_REAR + l * BODY_HALF_W, p - f * BODY_REAR - l * BODY_HALF_W, p - f * (COND_BACK + 0.2)]:
		if not allowed(c):
			return false
	return true


func mass() -> float:
	return MASS_EMPTY + flood_l + wash_l + bin_m3 * ResurfacerSim.SNOW_PACK * 1000.0


# ------------------------------------------------------------------ the step

## One tick: `throttle` -1 (reverse) .. 1, `steer_in` -1 (right) .. 1 (left),
## `brake` 0..1.
func step(dt: float, throttle: float, steer_in: float, brake := 0.0) -> void:
	time_s += dt
	cond_pos = move_toward(cond_pos, 1.0 if cond_down else 0.0, dt / COND_TRAVEL_S)
	_drive(dt, throttle, steer_in, brake)
	_tanks(dt)
	var oi := on_ice()
	if oi != _was_on_ice:
		events.append("on_ice" if oi else "off_ice")
		_was_on_ice = oi
	if oi:
		_conditioner(dt)
	else:
		flood_rate = 0.0
		flood_state = "off"
		snow_rate = lerpf(snow_rate, 0.0, clampf(dt * 2.0, 0.0, 1.0))
		if flood_valve > 0.0 and flood_l > 0.0 and not in_bay():
			_spill(dt)  # the valve open off the ice: down the gate
	_settle_acc += dt
	_freeze_acc += dt
	if _settle_acc >= 0.5:
		_settle_acc = 0.0
		if not _recent.is_empty():
			ice.settle(1, PackedInt32Array(_recent.keys()))
			var keep := {}
			for i: int in _recent:
				if time_s - _flood_at[i] < 8.0:
					keep[i] = true
			_recent = keep
	if _freeze_acc >= 4.0:
		ice.freeze(_freeze_acc)
		_freeze_acc = 0.0
	# engine: idle, the pedal, and the load of the augers
	var load := (0.25 if cond_down else 0.0) + snow_rate / AUGER_CAP * 0.3
	var want_rpm := (850.0 + 1700.0 * absf(throttle) + 500.0 * load) if engine_on else 0.0
	rpm = lerpf(rpm, want_rpm, clampf(dt * 3.0, 0.0, 1.0))
	fuel_used += dt * (0.045 / 720.0) * (0.6 + 0.4 * rpm / 2500.0)


func _drive(dt: float, throttle: float, steer_in: float, brake: float) -> void:
	steer = move_toward(steer, clampf(steer_in, -1.0, 1.0) * MAX_STEER, STEER_RATE * dt)
	var target := 0.0
	if engine_on and not _dumping:
		target = throttle * (TOP_SPEED if throttle >= 0.0 else REVERSE_SPEED)
	var acc := ACCEL * MASS_EMPTY / mass()
	if brake > 0.05:
		speed = move_toward(speed, 0.0, BRAKE * brake * dt)
	else:
		var gaining := absf(target) > absf(speed) and (signf(target) == signf(speed) or speed == 0.0)
		# the hydrostat holds her back when the pedal comes up
		speed = move_toward(speed, target, (acc if gaining else BRAKE * 0.5) * dt)
	var k := tan(steer) / WHEELBASE
	sliding = false
	if absf(speed * speed * k) > LAT_GRIP:
		k = signf(k) * LAT_GRIP / maxf(speed * speed, 0.01)
		sliding = true
		if not events.has("slide"):
			events.append("slide")
	var h := heading + speed * k * dt
	var mv := Vector2(cos(h), sin(h)) * speed * dt
	var p := pos + mv
	if _body_ok(p, h):
		dist_m += absf(speed) * dt
		_travel += maxf(speed, 0.0) * dt
		pos = p
		heading = wrapf(h, -PI, PI)
		return
	# against the boards: she scrapes along them if she meets them at a slant,
	# and stops dead (and marks the paint) if she meets them square on
	var n := Rink.board_normal(pos + fwd() * (BODY_FRONT if speed >= 0.0 else -BODY_REAR))
	var along := mv - n * maxf(mv.dot(n), 0.0)
	var square := mv.length() > 0.0001 and mv.normalized().dot(n) > 0.75
	if not square and _body_ok(pos + along, heading):
		pos += along
		dist_m += along.length()
		if speed > 0.0:
			_travel += along.length()
		speed *= 0.97
		return
	if absf(speed) > 0.6:
		board_hits += 1
		events.append("board_hit")
	speed = 0.0


func _tanks(dt: float) -> void:
	# the standpipe: hot flood water and the wash tank both top up
	if fill and at_standpipe():
		var add := FILL_LPS * dt
		var was_full := flood_l >= ResurfacerSim.FLOOD_TANK_L - 0.1 and wash_l >= ResurfacerSim.WASH_TANK_L - 0.1
		var df := minf(add, ResurfacerSim.FLOOD_TANK_L - flood_l)
		flood_l += df
		gas_cost += ResurfacerSim.heat_cost(df, flood_temp_c)
		wash_l = minf(wash_l + add * 0.35, ResurfacerSim.WASH_TANK_L)
		if not was_full and flood_l >= ResurfacerSim.FLOOD_TANK_L - 0.1 and wash_l >= ResurfacerSim.WASH_TANK_L - 0.1:
			events.append("filled")
	# the dump: tank up over the pit
	if dump and not _dumping and bin_m3 > 0.01:
		if at_pit():
			_dumping = true
			events.append("dump_start")
		else:
			events.append("dump_refused")
			dump = false
	if _dumping:
		var out := minf(ResurfacerSim.SNOW_TANK_M3 / DUMP_SECONDS * dt, bin_m3)
		bin_m3 -= out
		dumped_m3 += out
		if bin_m3 <= 0.001:
			bin_m3 = 0.0
			_dumping = false
			dump = false
			events.append("dump_done")
			if jammed and jam_risk >= 1.0:
				jammed = false
				jam_risk = 0.2
				events.append("unjam")
	# the plunger clears a choked vertical auger (conditioner up)
	if jammed and plunger and cond_pos <= 0.0 and bin_fill() < 0.98:
		_unjam_t += dt
		if _unjam_t >= UNJAM_SECONDS:
			jammed = false
			jam_risk = 0.25
			_unjam_t = 0.0
			events.append("unjam")
	else:
		_unjam_t = 0.0


func _spill(dt: float) -> void:
	var l := minf(flood_valve * FLOOD_Q100 * dt, flood_l)
	flood_l -= l


## The conditioner and the towel over the ice this tick.
func _conditioner(dt: float) -> void:
	var down := cond_pos >= 1.0
	var f := fwd()
	var l := left()
	var bc := blade_center()
	var eff := blade_eff_mm() if down else 0.0
	var chatter := doris.chatter()
	skipping = down and (blade_mm > SKIP_FROM_MM or chatter > 0.15)
	var skip_amt := 0.0
	if skipping:
		skip_amt = clampf((blade_mm - SKIP_FROM_MM) / 0.8 + chatter, 0.15, 1.0)
	blade_quality = 1.0 - skip_amt if down and eff > 0.0 else 1.0
	var snow_m3 := 0.0
	var n := 9
	var half := ResurfacerSim.BLADE_W_M * 0.5
	if down:
		# the shoes ride the high spots across the blade; it cuts down from there
		var idx := PackedInt32Array()
		var lv := PackedFloat32Array()
		var ref_max := -1e9
		var ref_sum := 0.0
		for k in n:
			var off := -half + (k + 0.5) * (2.0 * half / n)
			var i := IceSlab.cell_at(bc + l * off)
			idx.append(i)
			var v := ice.level_at(i)
			lv.append(v)
			ref_max = maxf(ref_max, v)
			ref_sum += v
		var ref := ref_sum / n + 0.3 * (ref_max - ref_sum / n)
		for k in n:
			var i := idx[k]
			if ice.inside[i] == 0 or ice.board_m[i] < IceSlab.BLADE_REACH:
				continue
			# a cell is cut once as the blade passes over it going forward, so
			# the snow taken up is blade depth x width x forward speed, and a
			# parked or reversing machine cuts nothing
			if speed <= 0.02 or _travel - _cut_at[i] < IceSlab.CX:
				continue
			_cut_at[i] = _travel
			if _covered[i] == 0:
				_covered[i] = 1
				_covered_n += 1
			var off := -half + (k + 0.5) * (2.0 * half / n)
			var cut := 0.0
			if eff > 0.0:
				cut = clampf(lv[k] - (ref - eff) + doris.blade_level_mm * off / half * 0.5, 0.0, eff * 1.5)
				if skipping:
					cut *= 1.0 + _rng.randf_range(-0.7, 0.7) * skip_amt
				cut = minf(cut, ice.t[i])
			var loose := ice.s[i]
			ice.t[i] -= cut
			ice.g[i] = maxf(ice.g[i] - cut, 0.0)
			ice.s[i] = 0.0
			var ice_m3 := cut / 1000.0 * IceSlab.CELL_AREA
			var snow := ice_m3 * 0.917 / ResurfacerSim.SNOW_PACK + loose / 1000.0 * IceSlab.CELL_AREA * 0.5
			ice_cut_m3 += ice_m3
			if eff > 0.0:
				ice.ang[i] = fposmod(heading, PI) / PI
				ice.stri[i] = clampf(0.3 + skip_amt * 0.7, 0.0, 1.0)
				ice.r[i] = ice.r[i] * 0.35 + 0.03 + skip_amt * 0.12
			if jammed or not auger_h:
				# nothing goes up: it's left behind to be flooded into lumps
				ice.s[i] += snow * 1000.0 / IceSlab.CELL_AREA
				ice.r[i] = minf(ice.r[i] + 0.25, 1.0)
				snow_left_m3 += snow
			else:
				snow_m3 += snow
			if washing():
				ice.r[i] *= 0.92  # the wash bar lifts the grit
		ice.touch_around(bc, 1.6)
	# the augers and the tank: the horizontal auger's trough holds a couple of
	# seconds of snow; the vertical one lifts AUGER_CAP a second out of it
	var rate := snow_m3 / maxf(dt, 0.0001)
	if not jammed:
		_trough_m3 += snow_m3
		var lift := minf(_trough_m3, AUGER_CAP * dt) if auger_v else 0.0
		_trough_m3 -= lift
		bin_m3 += lift
		snow_picked_m3 += lift
		if _trough_m3 > TROUGH_M3:
			var spill := _trough_m3 - TROUGH_M3
			_trough_m3 = TROUGH_M3
			snow_left_m3 += spill
			_drop_snow(bc, l, spill)
			jam_risk += spill / (AUGER_CAP * 0.5) * 0.15
	elif snow_m3 > 0.0:
		pass  # left on the ice above
	snow_rate = lerpf(snow_rate, rate if not jammed and auger_v else 0.0, clampf(dt * 1.5, 0.0, 1.0))
	if down and not jammed:
		var flooding := flood_valve > 0.0 and flood_l > 0.0
		if flooding and not washing():
			jam_risk += dt * 0.0035 * clampf(rate / 0.0035, 0.2, 3.0)  # wet slush, no wash to carry it
		if bin_fill() > 0.92:
			jam_risk += dt * 0.08
		if bin_fill() >= 1.0:
			jam_risk = 1.0
		if jam_risk < 1.0 and not flooding:
			jam_risk = maxf(jam_risk - dt * 0.01, 0.0)
		if jam_risk >= 1.0:
			jammed = true
			jams += 1
			events.append("jam" if bin_fill() < 0.98 else "bin_full")
	# wash water: sprayed ahead of the blade and vacuumed back into the tank
	if washing():
		var used := minf(WASH_Q * wash_valve * dt, wash_l)
		wash_l -= used
		wash_used_l += used
		if wash_l <= 0.0:
			events.append("wash_empty")
		if not down:
			# no squeegee down: cold dirty wash water left on the ice
			for k in 5:
				var i := IceSlab.cell_at(bc + l * (-half + (k + 0.5) * (2.0 * half / 5.0)))
				ice.add_water(i, used / 5.0 / IceSlab.CELL_AREA, 10.0)
				ice.r[i] = minf(ice.r[i] + 0.02, 1.0)
		elif down:
			ice.cleanliness = minf(ice.cleanliness + used * 0.0012, 1.0)
	# flood water through the spreader pipe, smoothed by the towel
	flood_rate = 0.0
	if flood_valve > 0.0 and flood_l > 0.0:
		var q := flood_valve * FLOOD_Q100
		var lit := minf(q * dt, flood_l)
		flood_l -= lit
		flood_rate = lit / maxf(dt, 0.0001)
		water_laid_l += lit
		if flood_l <= 0.0:
			events.append("flood_empty")
		var tc := pos - f * TOWEL_BACK
		var towel_q := doris.part("towel").condition
		var m := 10
		var tw := TOWEL_W * 0.5
		for k in m:
			# towel up: the water comes out of the spreader pipe's holes in stripes
			if not towel_down and k % 3 != 1:
				continue
			var share := lit / float(m if towel_down else 3)
			var i := IceSlab.cell_at(tc + l * (-tw + (k + 0.5) * (2.0 * tw / m)))
			if ice.inside[i] == 0:
				continue
			var mm := share / IceSlab.CELL_AREA
			ice.add_water(i, mm, flood_temp_c)
			_water_cell[i] += share
			_flood_at[i] = time_s
			_recent[i] = true
			if towel_down:
				var bond := clampf((flood_temp_c - 25.0) / 40.0, 0.0, 1.0)
				ice.r[i] = ice.r[i] * (1.0 - 0.06 * towel_q * (0.6 + 0.4 * bond))
				if flood_temp_c < 30.0:
					ice.r[i] = minf(ice.r[i] + 0.002, 1.0)  # cold water: air in it, cloudy
				ice.stri[i] *= 0.985  # the towel softens the cut lines
			else:
				ice.r[i] = minf(ice.r[i] + 0.004, 1.0)
		ice.touch_around(tc, 1.6)
		gas_cost += 0.0  # paid at the standpipe when the tank was heated
	_flood_feel()


## How the flood sounds: the water per metre against what keeps the sheet
## level at the 65% standard.
## Wash water going down: the pump on, the valve open, water in the tank.
func washing() -> bool:
	return wash_on and wash_l > 0.0 and wash_valve > 0.05


func _flood_feel() -> void:
	if flood_rate <= 0.0:
		flood_state = "off"
		return
	var std := 0.65 * FLOOD_Q100 / CUT_SPEED
	var now := flood_rate / maxf(absf(speed), 0.3)
	var k := now / std
	flood_state = "trickle" if k < 0.7 else ("rush" if k > 1.4 else "good")


func _drop_snow(bc: Vector2, l: Vector2, m3: float) -> void:
	for k in 4:
		var i := IceSlab.cell_at(bc + l * (-0.8 + k * 0.53))
		if ice.inside[i] == 1:
			ice.s[i] += m3 / 4.0 * 1000.0 / IceSlab.CELL_AREA


func drain_events() -> PackedStringArray:
	var e := events
	events = PackedStringArray()
	return e


# ------------------------------------------------------------------ the result

## The job result for RinkSim.job("resurface", ...): quality and what the cut
## did, plus the worked ice itself (`ice_state`) and Doris's tanks after.
func result() -> Dictionary:
	ice.freeze(0.0)
	ice.resync()
	var cov := coverage()
	var even := _evenness()
	var wet := flood_coverage()
	var smooth_after := ice.felt_smoothness()
	var kind := "normal"
	if water_laid_l < 30.0 and ice_cut_m3 > 0.05:
		kind = "dry"
	elif ice_cut_m3 < 0.05 and water_laid_l > 30.0:
		kind = "flood"
	elif ice_cut_m3 < 0.05 and water_laid_l <= 30.0:
		kind = "none"
	var q := 0.32 * clampf(cov / 0.92, 0.0, 1.0) * (1.0 if kind == "dry" else lerpf(0.5, 1.0, wet)) + 0.28 * smooth_after + 0.15 * even + 0.1 * clampf(1.0 - ice.snow * 2.0, 0.0, 1.0) \
		+ 0.1 * (0.0 if jams > 0 else 1.0) + 0.05 * (1.0 if board_hits == 0 else 0.0)
	if kind == "dry" or kind == "flood":
		q = 0.45 * clampf(cov / 0.92, 0.0, 1.0) + 0.3 * (even if kind == "flood" else blade_quality) + 0.15 * (0.0 if jams > 0 else 1.0) + 0.1 * (1.0 if board_hits == 0 else 0.0)
	return {
		"quality": clampf(q, 0.0, 1.0),
		"kind": kind,
		"ice_state": ice,
		"thickness_change_mm": ice.thickness_mm - float(_before.thickness),
		"flatness": ice.level_score(),
		"flatness_before": float(_before.level),
		"level_sd_mm": ice.level_sd_mm(),
		"level_sd_before_mm": float(_before.level_sd),
		"gouge_before_mm": float(_before.gouge),
		"gouge_after_mm": ice.mean_gouge_mm(),
		"smooth_after": smooth_after,
		"coverage": cov,
		"evenness": even,
		"flood_coverage": wet,
		"jam": jams > 0,
		"jams": jams,
		"board_hits": board_hits,
		"water_l": water_laid_l,
		"wash_l": wash_used_l,
		"ice_cut_mm": ice_cut_m3 * 1000.0 / (float(ice._inside_n) * IceSlab.CELL_AREA),
		"snow_m3": snow_picked_m3,
		"snow_left_m3": snow_left_m3,
		"bin_m3": bin_m3,
		"dumped_m3": dumped_m3,
		"flood_l_left": flood_l,
		"wash_l_left": wash_l,
		"flood_temp_c": flood_temp_c,
		"gas_cost": gas_cost,
		"fuel_used": fuel_used,
		"minutes": time_s / 60.0,
		"complete": cov >= 0.9 and jams == 0 and (kind == "dry" or kind == "none" or wet >= 0.9),
	}


## Fraction of the cells the blade went over that got flood water too (an
## empty tank partway round leaves the rest dry-cut).
func flood_coverage() -> float:
	if _covered_n == 0:
		return 0.0
	var n := 0
	for i in IceSlab.FCELLS:
		if _covered[i] == 1 and _water_cell[i] > 0.0:
			n += 1
	return float(n) / float(_covered_n)


## 1 when every covered cell got the same water, 0 when it went on in puddles.
func _evenness() -> float:
	# over patches of 4 x 4 cells (about a square metre: the scale a puddle
	# or a dry streak shows at), every cell of which was under the blade
	var n := 0
	var sum := 0.0
	var sq := 0.0
	for pz in range(0, IceSlab.FD - 3, 4):
		for px in range(0, IceSlab.FW - 3, 4):
			var v := 0.0
			var ok := true
			for dz in 4:
				for dx in 4:
					var i := (pz + dz) * IceSlab.FW + px + dx
					if _covered[i] == 0:
						ok = false
						break
					v += _water_cell[i]
				if not ok:
					break
			if not ok:
				continue
			sum += v
			sq += v * v
			n += 1
	if n == 0 or sum <= 0.0:
		return 0.0
	var mean := sum / n
	var sd := sqrt(maxf(sq / n - mean * mean, 0.0))
	return clampf(1.0 - sd / maxf(mean, 0.0001) * 0.6, 0.0, 1.0)


# ------------------------------------------------------------------ the pattern

## The standard pattern Doris's drivers use (docs/world/ICE.md 4.3): out of
## the gate, two laps around the boards, down the middle, then overlapping
## loops out to the second lap, and back to the gate. Waypoints of the rear
## axle, rink metres; `marks` names the points where the driver changes
## something ({index: "start"/"cut_end"/"gate"/"park"}).
const LAP1 := 1.42   # conditioner centre from the boards on the first lap, m
const STRIP := 1.62  # a blade width less the overlap
const STRIP_X := 21.5
const CORNER_INSET := 2.0


## The spacing of the loop lanes: five a side, the outer one overlapping the
## second lap by most of a blade.
static func lane_strip() -> float:
	return (Rink.HALF_W - LAP1 - STRIP - 1.45) / 5.0


static func standard_pattern() -> Dictionary:
	var pts: Array[Vector2] = []
	var marks := {}
	pts.append(PARK + Vector2(-1.0, 0.0))
	pts.append(Vector2(BAY_X0 - 0.5, 0.0))
	pts.append(Vector2(Rink.HALF_L + 0.3, 0.0))
	marks[pts.size() - 1] = "start"
	# in through the gate and swing onto the first lap along the far side
	pts.append(Vector2(Rink.HALF_L - 3.0, 0.6))
	pts.append(Vector2(Rink.HALF_L - LAP1 - 0.6, 3.2))
	_lap(pts, LAP1, true)
	# the second lap, a blade width in
	_lap(pts, LAP1 + STRIP, false)
	# down the middle
	pts.append(Vector2(Rink.HALF_L - LAP1 - STRIP * 2.6, -0.6))
	pts.append(Vector2(STRIP_X, 0.0))
	pts.append(Vector2(-STRIP_X, 0.0))
	# the loops: lanes a strip apart out to the second lap, driven as
	# overlapping ovals so each turn is wider than her circle (5 or 6 lanes
	# across): -5, +1, -4, +2 ... -1, +5
	var lane := lane_strip()
	var order := [-5, 1, -4, 2, -3, 3, -2, 4, -1, 5]
	var y_prev := 0.0
	var at_neg := true
	for j: int in order:
		var y := j * lane
		var end_x := -STRIP_X if at_neg else STRIP_X
		_turn(pts, Vector2(end_x, y_prev), Vector2(end_x, y), -1.0 if at_neg else 1.0)
		pts.append(Vector2(STRIP_X if at_neg else -STRIP_X, y))
		at_neg = not at_neg
		y_prev = y
	marks[pts.size() - 1] = "cut_end"
	# back up the middle to the gate, conditioner up
	_turn(pts, Vector2(-STRIP_X, y_prev), Vector2(-STRIP_X, 0.0), -1.0)
	pts.append(Vector2(Rink.HALF_L - 4.0, 0.0))
	marks[pts.size() - 1] = "gate"
	pts.append(Vector2(Rink.HALF_L + 1.5, 0.0))
	pts.append(Vector2(BAY_X0 + 1.5, -0.8))
	pts.append(Vector2(PIT.x - 2.6, PIT.y + 0.7))
	marks[pts.size() - 1] = "park"
	return {"points": pts, "marks": marks}


## One lap of the boards `inset` m in, anticlockwise (+y along the +x end),
## starting from the +x end's far corner. `close` finishes along the +x end
## back to where it began (the first lap), else it stops at the near corner.
static func _lap(pts: Array[Vector2], inset: float, close: bool) -> void:
	var hx := Rink.HALF_L - inset
	var hy := Rink.HALF_W - inset
	# in the corners the nose swings wide of the conditioner: hold off a bit
	var r := Rink.CORNER_R - maxf(inset, CORNER_INSET)
	var cx := Rink.HALF_L - Rink.CORNER_R
	var cy := Rink.HALF_W - Rink.CORNER_R
	for q in 4:
		var sx := 1.0 if q == 0 or q == 3 else -1.0
		var sy := 1.0 if q < 2 else -1.0
		var a0 := q * PI * 0.5
		# the middle of the straight before this corner (the line eases out
		# to the boards between the corners), then its arc
		if q == 1:
			pts.append(Vector2(cx * 0.5, hy))
			pts.append(Vector2(-cx * 0.5, hy))
		elif q == 2:
			pts.append(Vector2(-hx, 0.0))
		elif q == 3:
			pts.append(Vector2(-cx * 0.5, -hy))
			pts.append(Vector2(cx * 0.5, -hy))
		for a in range(0, 10):
			var t := a0 + a / 9.0 * PI * 0.5
			pts.append(Vector2(sx * cx + r * cos(t), sy * cy + r * sin(t)))
	pts.append(Vector2(hx, -1.0))
	if close:
		pts.append(Vector2(hx, 0.0))
		pts.append(Vector2(hx - 0.4, cy * 0.8))
		pts.append(Vector2(hx - STRIP * 0.6, cy + 0.8))


## A turn at the end of the strips from `a` to `b`, bulging out toward `side`
## (-1 the -x end): wide enough for Doris's 16 ft circle.
static func _turn(pts: Array[Vector2], a: Vector2, b: Vector2, side: float) -> void:
	var ry := (b.y - a.y) * 0.5
	var rx := 5.0
	var cy := (a.y + b.y) * 0.5
	for k in range(1, 8):
		var t := k / 8.0 * PI
		pts.append(Vector2(a.x + side * rx * sin(t), cy - ry * cos(t)))
