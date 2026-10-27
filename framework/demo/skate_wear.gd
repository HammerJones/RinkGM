class_name SkateWear
extends RefCounted
## What skating does to the ice, as marks on the IceSheet. A skater is
## two blades `BLADE_GAP` apart: gliding leaves faint lines along the
## travel (the state texture's striations, re-angled), a push-off chips
## the ice where the back foot drives (a short, shallow gouge with a
## puff of snow), a turn harder than the edges like gouges the outside
## blade's line deeper the harder it is, and a stop shaves the ice
## across the blades and throws the shavings ahead as a pile of snow.
## Everything scales with speed; a slow glide leaves nearly nothing.

const BLADE_GAP := 0.24  # metres between the two skates' lines
const BLADE_W := 0.02  # a blade's line: one cell of the sheet (a real blade is 3 mm)
const GLIDE_V := 6.0  # m/s at which a glide's lines read fully
const GRIP_G := 4.5  # m/s2 of lateral pull past which a turn's edge gouges
const GOUGE_PER_G := 0.12  # mm of gouge per m/s2 past that, per metre travelled
const STOP_SNOW := 0.9  # mm of snow a stop throws per (m/s of speed x m/s2 of braking x s)
const STOP_THROW := 0.6  # metres ahead the pile lands
const STRIDE_CHIP := 0.06  # metres across a push-off's chip
const STRIDE_MM := 0.4  # its depth


## A glide from `a` to `b` (sheet metres, the skater's centre) heading
## `dir` at `v` m/s: two faint lines, one per blade.
static func glide(sheet: IceSheet, a: Vector2, b: Vector2, dir: Vector2, v: float) -> void:
	if a.distance_to(b) < 0.005 or v < 0.3:
		return
	var right := Vector2(-dir.y, dir.x) * (BLADE_GAP / 2)
	var strength := clampf(v / GLIDE_V, 0.15, 1.0) * 0.5
	sheet.stroke(a - right, b - right, BLADE_W, strength, 0.0, 0.0)
	sheet.stroke(a + right, b + right, BLADE_W, strength, 0.0, 0.0)


## A turn: the velocity swung by `lat_g` m/s2 over the step from `a` to
## `b`, `left` true when turning left (the right skate is outside).
static func turn(
	sheet: IceSheet, a: Vector2, b: Vector2, dir: Vector2, lat_g: float, left: bool
) -> void:
	var past := lat_g - GRIP_G
	if past <= 0.0 or a.distance_to(b) < 0.005:
		return
	var right := Vector2(-dir.y, dir.x) * (BLADE_GAP / 2)
	var outer_a := a + right if left else a - right
	var outer_b := b + right if left else b - right
	var depth := past * GOUGE_PER_G * a.distance_to(b) * 10.0  # per step, read as the trench's depth
	sheet.stroke(outer_a, outer_b, BLADE_W, 1.0, clampf(depth, 0.1, 2.5), 0.15)


## A stop: braking `decel` m/s2 from `v` m/s over `dt`, the blades
## across the travel at `at` heading `dir`: a scrape across both blades
## and the shavings thrown ahead.
static func stop(
	sheet: IceSheet, at: Vector2, dir: Vector2, v: float, decel: float, dt: float
) -> void:
	if v < 0.5 or decel <= 0.0:
		return
	var right := Vector2(-dir.y, dir.x)
	var half := right * 0.35
	sheet.stroke(at - half, at + half, 0.02, 1.0, 0.25, 0.0)
	var mm := STOP_SNOW * v * decel * dt
	sheet.add_snow(at + dir * STOP_THROW, 0.7, mm)


## A push-off: the back foot's chip, `side` -1 left foot, 1 right.
static func stride(sheet: IceSheet, at: Vector2, dir: Vector2, side: float, v: float) -> void:
	var right := Vector2(-dir.y, dir.x)
	var foot := at + right * (side * BLADE_GAP / 2 + side * 0.08) - dir * 0.3
	sheet.chip(foot, STRIDE_CHIP, STRIDE_MM * clampf(0.5 + v / 8.0, 0.5, 1.2), 0.08)
