class_name IcePlant
extends RefCounted
## The ice plant: two compressor stages chilling a tank of calcium chloride
## brine, the pump that sends it through the floor's headers, and the warm
## loop under the slab. Run by hand from the plant room: a set point, a
## mode switch per stage (off, auto, hand), the pump and its speed, the
## warm loop, and a reset button per stage for its trips.
##
## Auto staging holds the tank at the set point with hysteresis and a
## minimum run and rest time. A stage trips on low suction (the brine far
## below its design, or no flow through the chiller for a while) and on
## high head (a hot condenser on a hot day); a tripped stage stays off
## through a lockout and until its cause has gone and the button is pressed.

enum Mode { OFF, AUTO, HAND }
enum Trip { NONE, LOW_SUCTION, HIGH_HEAD }

const STAGES := 2
const STAGE_KW := 175.0  # kW of cooling a stage pulls at design brine
const COP := 2.8  # kW of cooling per kW of electricity
const TANK_LITRES := 9000.0
const TANK_JK := TANK_LITRES * 1.2 * 2900.0  # J/K: brine's density and heat capacity
const HYST := 1.0  # K about the set point a stage cycles over
const STAGE2_LAG := 1.5  # K above the set point the second stage joins
const MIN_CYCLE := 180.0  # seconds a stage stays as it is after a change
const LOCKOUT := 180.0  # seconds a tripped stage cannot be reset
const LOW_SUCTION_C := -14.0  # brine this cold trips a stage
const NO_FLOW_S := 20.0  # seconds a stage runs with no brine flow before it trips
const HEAD_TRIP_C := 32.0  # outside air this warm trips a running stage on head pressure
const SET_MIN := -12.0
const SET_MAX := -4.0
const MODE_NAMES := ["OFF", "AUTO", "HAND"]
const TRIP_NAMES := ["", "LOW SUCTION", "HIGH HEAD"]

var pad: BrineFloor
var set_point := -9.0
var stage_mode: Array[int] = [Mode.AUTO, Mode.AUTO]
var stage_on: Array[bool] = [false, false]
var stage_t: Array[float] = [MIN_CYCLE, MIN_CYCLE]  # seconds since the stage last changed
var trip: Array[int] = [Trip.NONE, Trip.NONE]
var lockout: Array[float] = [0.0, 0.0]
var hours: Array[float] = [0.0, 0.0]  # the hour meters
var pump_on := true
var pump_speed := 0.8  # 0..1 of full flow
var warm_on := true
var tank_c := -9.0  # the brine in the tank: what the headers get
var outside_c := 12.0  # at the condenser
var kwh := 0.0
var cooling_kw := 0.0  # the stages' pull in the last step
var no_flow_t := 0.0


## The plant for a sheet `size_m` metres, brine and floor at `start_c`.
func setup(size_m: Vector2, start_c := -9.0) -> void:
	set_point = start_c
	tank_c = start_c
	pad = BrineFloor.new()
	pad.setup(size_m, start_c)


## Brine flow through the headers, 0..1 of full.
func flow() -> float:
	return pump_speed if pump_on else 0.0


## The brine leaving the plant, C.
func supply_c() -> float:
	return tank_c


## The brine back from the floor, C.
func return_c() -> float:
	return pad.return_c


## The pump's discharge pressure, kPa: rises with speed, and when the header's
## valves are shut against it.
func header_kpa() -> float:
	var f := flow()
	if f <= 0.0:
		return 0.0
	return 40.0 + 180.0 * f * f * (1.0 + 1.5 * (1.0 - pad.open_share))


## A stage's pull now, kW: its design at -9 C brine, more when the brine is warm.
func stage_kw(s: int) -> float:
	if not stage_on[s]:
		return 0.0
	return STAGE_KW * clampf(1.0 + 0.03 * (tank_c + 9.0), 0.5, 1.3)


## Turn the set point `notches` half degrees.
func turn_set_point(notches: float) -> void:
	set_point = clampf(set_point + 0.5 * notches, SET_MIN, SET_MAX)


## A stage's mode switch: off, auto, hand, round.
func cycle_mode(s: int) -> void:
	stage_mode[s] = (stage_mode[s] + 1) % 3


## A stage's reset button: clears its trip when the lockout is over and the
## cause has gone. True when it did.
func reset(s: int) -> bool:
	if trip[s] == Trip.NONE:
		return false
	if lockout[s] > 0.0:
		return false
	match trip[s]:
		Trip.LOW_SUCTION:
			if flow() < 0.05 or tank_c < LOW_SUCTION_C + 1.0:
				return false
		Trip.HIGH_HEAD:
			if outside_c > HEAD_TRIP_C - 2.0:
				return false
	trip[s] = Trip.NONE
	no_flow_t = 0.0
	stage_t[s] = MIN_CYCLE
	return true


func stage_text(s: int) -> String:
	if trip[s] != Trip.NONE:
		return "TRIP %s" % TRIP_NAMES[trip[s]]
	return "%s %s" % [MODE_NAMES[stage_mode[s]], "RUN" if stage_on[s] else "IDLE"]


## One line of the plant for the HUD.
func text() -> String:
	return (
		(
			"PLANT SET %.1f C   SUPPLY %.1f   RETURN %.1f   STAGE 1 %s   STAGE 2 %s   "
			+ "PUMP %s %.0f%% %.0f KPA   WARM LOOP %s   GROUND %.1f C   HEAVE %.1f MM   %.0f KWH"
		)
		% [
			set_point,
			supply_c(),
			return_c(),
			stage_text(0),
			stage_text(1),
			"ON" if pump_on else "OFF",
			pump_speed * 100.0,
			header_kpa(),
			"ON" if warm_on else "OFF",
			pad.ground_min(),
			pad.heave_max(),
			kwh
		]
	)


## `dt` seconds of sim time, `air_c` over the ice. True when the floor ran a pass.
func step(dt: float, air_c: float) -> bool:
	var f := flow()
	var any_on := stage_on[0] or stage_on[1]
	# trips
	if any_on and f < 0.05:
		no_flow_t += dt
	else:
		no_flow_t = 0.0
	for s in STAGES:
		lockout[s] = maxf(lockout[s] - dt, 0.0)
		stage_t[s] += dt
		if stage_on[s]:
			if no_flow_t > NO_FLOW_S or tank_c < LOW_SUCTION_C:
				_trip(s, Trip.LOW_SUCTION)
			elif outside_c > HEAD_TRIP_C:
				_trip(s, Trip.HIGH_HEAD)
	# staging
	for s in STAGES:
		var want := stage_on[s]
		match stage_mode[s]:
			Mode.OFF:
				want = false
			Mode.HAND:
				want = true
			Mode.AUTO:
				var on_above := set_point + HYST / 2.0 + (STAGE2_LAG if s == 1 else 0.0)
				var off_below := set_point - HYST / 2.0 + (STAGE2_LAG if s == 1 else 0.0)
				if tank_c > on_above:
					want = true
				elif tank_c < off_below:
					want = false
		if trip[s] != Trip.NONE:
			want = false
		if want != stage_on[s] and (stage_t[s] >= MIN_CYCLE or not want):
			stage_on[s] = want
			stage_t[s] = 0.0
	# the tank: the stages pull heat out, the floor's return brings it back
	cooling_kw = 0.0
	for s in STAGES:
		var kw := stage_kw(s)
		cooling_kw += kw
		if stage_on[s]:
			hours[s] += dt / 3600.0
			kwh += kw / COP * dt / 3600.0
	var back := pad.heat_w if f > 0.0 else 0.0
	tank_c += (back - cooling_kw * 1000.0) * dt / TANK_JK
	tank_c = clampf(tank_c, -25.0, 20.0)
	return pad.step(dt, tank_c, f, warm_on, air_c)


## Run the plant and the floor forward `seconds` of sim time in big steps.
func advance(seconds: float, air_c: float) -> void:
	var left := seconds
	while left > 0.0:
		var dt := minf(left, BrineFloor.SUB_MAX)
		step(dt, air_c)
		left -= dt


func _trip(s: int, why: int) -> void:
	trip[s] = why
	stage_on[s] = false
	stage_t[s] = 0.0
	lockout[s] = LOCKOUT
