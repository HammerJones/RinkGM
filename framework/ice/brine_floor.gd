class_name BrineFloor
extends RefCounted
## The brine floor under the ice: the pipe circuits cast into the concrete
## pad, the insulation under them, the warm loop that keeps the ground
## from freezing, and the ground itself.
##
## The pad is a grid of nodes, one per circuit across the sheet (a circuit
## is a pair of pipes, out and back, a PITCH apart) and NODE_M along it.
## Each node is four stacked temperatures: the slab top under the ice,
## the slab at the pipe plane, the sub-base under the insulation and the
## ground. Brine marches along each circuit from the headers at the x = 0
## end: out along one pipe, back along the other, warming as it goes, so
## the return end of a long circuit runs warmer than the supply end and a
## closed or air-locked circuit shows as a warm strip. Ground below 0 C
## heaves: a millimetre count per node the sheet lifts its ice by.
##
## Stepped in passes of STEP_S seconds of sim time, sub-stepped for
## stability; `step()` says when a pass ran so the caller can refresh
## the pad map and the heave.

const NODE_M := 2.0  # a node's length along the circuit, metres
const PITCH := 0.2  # circuit spacing across the sheet, metres: two pipes, out and back
const AREA := NODE_M * PITCH  # m2 of pad a node stands for
const CAP_TOP := 150000.0 * AREA  # J/K: 65 mm of concrete over the pipe plane
const CAP_PIPE := 150000.0 * AREA  # J/K: the concrete around the pipes
const CAP_SUB := 480000.0 * AREA  # J/K: the sub-base under the insulation
const CAP_GROUND := 1000000.0 * AREA  # J/K: the half metre of earth that follows the slab within days
const G_TOP := 29.0 * AREA  # W/K, pipe plane to slab top
const G_BRINE := 110.0 * AREA  # W/K, the two pipes' walls to the concrete, when brine runs
const G_INS := 1.0 * AREA  # W/K, through the insulation (thin, so a season of neglect plays out in weeks)
const G_WARM := 1.5 * AREA  # W/K, the warm loop's glycol to the sub-base, when it runs
const G_GROUND := 3.3 * AREA  # W/K, sub-base to ground
const G_DEEP := 0.25 * AREA  # W/K, ground to the deep earth
const G_LAT := 0.9 * NODE_M  # W/K between neighbouring circuits
const G_ALONG := 1.4 * PITCH * 0.13 / NODE_M  # W/K between neighbouring nodes along a circuit
const G_ICE := 5.76 * AREA  # W/K, the still air over the ice to the slab top, through 3 cm of ice
const DEEP_C := 4.0  # the deep earth
const WARM_C := 8.0  # the warm loop's glycol
const FLOW_WK := 930.0  # W/K: brine mass flow times its heat capacity, one circuit, pump full
const HEAVE_RATE := 2.0 / 86400.0  # mm/s per K the ground is below freezing
const HEAVE_STEP := 0.5  # mm of heave between lifts of the ice
const STEP_S := 20.0  # sim seconds between passes
const SUB_MAX := 240.0  # the longest explicit sub-step (the pipe node's time constant is ~1500 s)
const MAP_LO := -30.0  # the pad map's red channel spans MAP_LO..MAP_LO+MAP_SPAN C
const MAP_SPAN := 40.0

var nx := 0  # nodes along a circuit
var nc := 0  # circuits
var size := Vector2.ZERO  # metres the floor spans (nx * NODE_M, nc * PITCH)
var top := PackedFloat32Array()  # C, the slab top under the ice
var pipe := PackedFloat32Array()  # C, the slab at the pipe plane
var sub := PackedFloat32Array()  # C, under the insulation
var ground := PackedFloat32Array()  # C
var brine := PackedFloat32Array()  # C, the brine in the pipes over the node (out and back averaged)
var heave := PackedFloat32Array()  # mm the ground has lifted the pad
var q_wet := PackedFloat32Array()  # J a flood's heat has put into the slab top since the last pass
var valve := PackedFloat32Array()  # per circuit, 0 shut .. 1 open
var flow := PackedFloat32Array()  # per circuit, 0..1 of full flow in the last pass
var supply_c := -9.0  # the brine as it left the headers in the last pass
var return_c := -9.0  # the brine back at the headers, all running circuits mixed
var heat_w := 0.0  # W the brine carried out of the floor in the last pass
var open_share := 1.0  # the share of circuits open, for the header pressure
var heave_steps := PackedInt32Array()  # nodes whose heave crossed a HEAVE_STEP in the last pass
var passes := 0
var _acc := 0.0
var _q_b := PackedFloat32Array()  # W into the pipe plane from the brine, this pass
var _map: Image
var _tex: ImageTexture


## Lay the floor under a sheet `size_m` metres, everything at `start_c`
## above the insulation and a mild ground below it.
func setup(size_m: Vector2, start_c := -9.0) -> void:
	nx = maxi(ceili(size_m.x / NODE_M), 1)
	nc = maxi(ceili(size_m.y / PITCH), 1)
	size = Vector2(nx * NODE_M, nc * PITCH)
	var n := nx * nc
	top.resize(n)
	pipe.resize(n)
	sub.resize(n)
	ground.resize(n)
	brine.resize(n)
	heave.resize(n)
	q_wet.resize(n)
	_q_b.resize(n)
	top.fill(start_c + 0.6)
	pipe.fill(start_c + 0.3)
	sub.fill(2.0)
	ground.fill(4.0)
	brine.fill(start_c)
	heave.fill(0.0)
	q_wet.fill(0.0)
	valve.resize(nc)
	valve.fill(1.0)
	flow.resize(nc)
	flow.fill(1.0)
	supply_c = start_c
	return_c = start_c
	_map = Image.create(nx, nc, false, Image.FORMAT_RG8)
	_tex = ImageTexture.create_from_image(_map)


## The node under a point of the sheet, metres from the sheet's corner.
func node_at(xm: float, zm: float) -> int:
	var ix := clampi(int(xm / NODE_M), 0, nx - 1)
	var ic := clampi(int(zm / PITCH), 0, nc - 1)
	return ic * nx + ix


## The slab top's temperature under a point, C.
func top_at(xm: float, zm: float) -> float:
	return top[node_at(xm, zm)]


## How far the ground has lifted the pad under a point, mm.
func heave_at(xm: float, zm: float) -> float:
	return heave[node_at(xm, zm)]


## The circuit under a point, 0..nc-1.
func circuit_at(zm: float) -> int:
	return clampi(int(zm / PITCH), 0, nc - 1)


## A header valve: `open` 0..1 for one circuit.
func set_valve(circuit: int, open: float) -> void:
	valve[clampi(circuit, 0, nc - 1)] = clampf(open, 0.0, 1.0)


## The header is valved in `zones` groups of neighbouring circuits; set one.
func set_zone(zone: int, zones: int, open: float) -> void:
	for c in zone_circuits(zone, zones):
		set_valve(c, open)


## The circuits a zone valve feeds.
func zone_circuits(zone: int, zones: int) -> Array[int]:
	var out: Array[int] = []
	var c0 := zone * nc / zones
	var c1 := (zone + 1) * nc / zones
	for c in range(c0, c1):
		out.append(c)
	return out


## The coldest and warmest slab top, C.
func top_range() -> Vector2:
	var lo := INF
	var hi := -INF
	for t in top:
		lo = minf(lo, t)
		hi = maxf(hi, t)
	return Vector2(lo, hi)


## The coldest ground under the slab, C.
func ground_min() -> float:
	var lo := INF
	for t in ground:
		lo = minf(lo, t)
	return lo


## The most the ground has lifted the pad anywhere, mm.
func heave_max() -> float:
	var hi := 0.0
	for h in heave:
		hi = maxf(hi, h)
	return hi


## `dt` seconds of sim time with brine at `supply` C through the headers at
## `pump` 0..1 of full flow, the warm loop running or not, `air_c` over
## the ice. True when a pass ran.
func step(dt: float, supply: float, pump: float, warm_on: bool, air_c: float) -> bool:
	_acc += dt
	if _acc < STEP_S:
		return false
	var n := ceili(_acc / SUB_MAX)
	var sub_dt := _acc / n
	heave_steps.resize(0)
	for k in n:
		_pass(sub_dt, supply, pump, warm_on, air_c)
	_acc = 0.0
	passes += 1
	return true


## Run the floor forward `seconds` of sim time in passes, for a view or a test.
func advance(seconds: float, supply: float, pump: float, warm_on: bool, air_c: float) -> void:
	var left := seconds
	while left > 0.0:
		var dt := minf(left, SUB_MAX)
		_acc += dt
		left -= dt
		if _acc >= STEP_S or left <= 0.0:
			_pass(_acc, supply, pump, warm_on, air_c)
			_acc = 0.0
			passes += 1


func _pass(dt: float, supply: float, pump: float, warm_on: bool, air_c: float) -> void:
	supply_c = supply
	_q_b.fill(0.0)
	var ua := G_BRINE / 2.0  # one pipe's share of a node
	var ret_sum := 0.0
	var mc_sum := 0.0
	var open_n := 0
	for c in nc:
		var f := clampf(pump * valve[c], 0.0, 1.0)
		flow[c] = f
		if valve[c] > 0.5:
			open_n += 1
		var row := c * nx
		if f < 0.005:
			for ix in nx:
				brine[row + ix] = pipe[row + ix]  # standing brine takes the slab's temperature
			continue
		var mc := FLOW_WK * f
		var k := exp(-ua / mc)  # the brine's approach to the slab over one node, one pipe
		var tb := supply
		# out along one pipe, from the headers at x = 0 to the far end
		for ix in nx:
			var i := row + ix
			var tn := pipe[i] + (tb - pipe[i]) * k
			_q_b[i] += mc * (tb - tn)
			brine[i] = (tb + tn) * 0.5
			tb = tn
		# and back along the other
		for ix in range(nx - 1, -1, -1):
			var i := row + ix
			var tn := pipe[i] + (tb - pipe[i]) * k
			_q_b[i] += mc * (tb - tn)
			brine[i] = (brine[i] + (tb + tn) * 0.5) * 0.5
			tb = tn
		ret_sum += tb * mc
		mc_sum += mc
	open_share = float(open_n) / nc
	if mc_sum > 0.0:
		return_c = ret_sum / mc_sum
		heat_w = mc_sum * (return_c - supply)
	else:
		return_c = supply
		heat_w = 0.0
	# the slab, the sub-base and the ground, one explicit step from the old temperatures
	var warm_g := G_WARM if warm_on else 0.0
	var last_c := nc - 1
	var last_x := nx - 1
	for c in nc:
		var row := c * nx
		for ix in nx:
			var i := row + ix
			var t := top[i]
			var p := pipe[i]
			var s := sub[i]
			var g := ground[i]
			var lat := 0.0
			if c > 0:
				lat += G_LAT * (pipe[i - nx] - p)
			if c < last_c:
				lat += G_LAT * (pipe[i + nx] - p)
			if ix > 0:
				lat += G_ALONG * (pipe[i - 1] - p)
			if ix < last_x:
				lat += G_ALONG * (pipe[i + 1] - p)
			var q_top := G_TOP * (p - t) + G_ICE * (air_c - t) + q_wet[i] / dt
			q_wet[i] = 0.0
			var q_pipe := G_TOP * (t - p) + _q_b[i] + G_INS * (s - p) + lat
			var q_sub := G_INS * (p - s) + G_GROUND * (g - s) + warm_g * (WARM_C - s)
			var q_ground := G_GROUND * (s - g) + G_DEEP * (DEEP_C - g)
			top[i] = t + q_top * dt / CAP_TOP
			pipe[i] = p + q_pipe * dt / CAP_PIPE
			sub[i] = s + q_sub * dt / CAP_SUB
			ground[i] = g + q_ground * dt / CAP_GROUND
			if g < 0.0:
				var h0 := int(heave[i] / HEAVE_STEP)
				heave[i] += HEAVE_RATE * -g * dt
				if int(heave[i] / HEAVE_STEP) != h0:
					heave_steps.append(i)


## The pad map, a texture over the floor: red the slab top's temperature
## ((C - MAP_LO) / MAP_SPAN), green the circuit's flow.
func map_texture() -> ImageTexture:
	for c in nc:
		var row := c * nx
		var f := flow[c]
		for ix in nx:
			var v := clampf((top[row + ix] - MAP_LO) / MAP_SPAN, 0.0, 1.0)
			_map.set_pixel(ix, c, Color(v, f, 0.0))
	_tex.update(_map)
	return _tex
