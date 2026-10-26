class_name IceTouch
extends RefCounted
## What the sheet does to a loose puck (Sean's ask, 2026-10-26): the game's
## `Puck.integrate` slides on one drag for clean ice; this reads the column
## under the puck each substep and adds the rest. Loose snow drags it hard
## and a pile stops it. A wet film is slick; a pool holds a slow puck and
## lets a fast one skim. Slush (water on snow) drags like snow and wanders
## the heading. A set crust is rough: more drag and little hops at speed.
## The surface's slope (ruts, gouges, ridges) is just gravity: the puck
## rolls downhill, so a rut holds it and a ridge kicks it. A puck that
## came through snow carries a load of it for a moment, keeping part of
## the drag and leaving a faint trail; a wet puck leaves a streak.
##
##   var touch := IceTouch.new()
##   touch.apply(puck, sheet, to_sheet, dt)  # after puck.integrate(dt)
##   touch.surface  # "CLEAN", "WET", "POOL", "SNOW", "SLUSH", "CRUST", "PILE"

const SNOW_DRAG := 1.2  # m/s2 per mm of loose snow
const SNOW_CAP := 4.0  # mm of snow past which it drags no harder (it rides on top)
const PILE := 50.0  # mm of snow that is a pile: the puck buries itself and stops
const FILM_SLICK := 0.7  # drag share on a wet film (under the sheet's FILM_PIN)
const POOL_SLOW := 1.3  # drag share in a pool, slow (the water holds it)
const POOL_FAST := 0.5  # ... fast (it skims)
const SLOW_V := 2.0
const FAST_V := 6.0
const SLUSH_KICK := 0.3  # m/s2 sideways, wandering
const CRUST_DRAG := 1.5  # drag share on a set crust
const CRUST_MIN := 0.2  # mm of crust that counts
const HOP_V := 0.2  # m/s upward, a hop off a rough crust
const HOP_EVERY := 0.15  # s
const HOP_SPEED := 4.0  # m/s: slower than this it rattles without hopping
const LOAD_DECAY := 2.0  # s for a carried snow load to fall off
const LOAD_KEEP := 0.4  # share of the snow drag a loaded puck keeps on clean ice
const TRAIL_MM := 0.05  # snow a loaded puck leaves per TRAIL_STEP
const TRAIL_STEP := 0.05  # m
const STREAK_MM := 0.02  # water a wet puck leaves
const SLOPE_R := 0.04  # m either side of the puck the surface is sampled for its slope
const G := 9.8

var surface := "CLEAN"
var snow_load := 0.0  # 0..1 of snow riding on the puck
var wet_load := 0.0
var drag := 0.0  # m/s2 the ice added last step (HUD, tests)
var rng := RandomNumberGenerator.new()
var _kick := 0.0
var _hop_t := 0.0
var _trail_d := 0.0
var _last_at := Vector2.INF


func _init() -> void:
	rng.seed = 11


## A fresh puck (reset, back in play): nothing carried, no trail.
func clear() -> void:
	snow_load = 0.0
	wet_load = 0.0
	surface = "CLEAN"
	drag = 0.0
	_kick = 0.0
	_hop_t = 0.0
	_trail_d = 0.0
	_last_at = Vector2.INF


## One substep, after `puck.integrate(dt)`: `to_sheet` maps a world point to
## sheet metres. Nothing happens to a frozen, flying or out-of-play puck.
func apply(puck: Puck, sheet: IceSheet, to_sheet: Callable, dt: float) -> void:
	_hop_t = maxf(0.0, _hop_t - dt)
	snow_load = maxf(0.0, snow_load - dt / LOAD_DECAY)
	wet_load = maxf(0.0, wet_load - dt / LOAD_DECAY)
	drag = 0.0
	if puck.frozen or puck.out_of_play or puck.position.y > 0.01:
		return
	var a: Vector2 = to_sheet.call(puck.position)
	var c := sheet.cell_at(a)
	if not sheet.in_bounds(c.x, c.y) or not sheet.is_ice(c.x, c.y):
		surface = "OFF"
		return
	var i := sheet.index(c.x, c.y)
	var snow: float = sheet.snow[i]
	var water: float = sheet.water[i] * (1.0 - sheet.frozen[i])
	var crust: float = sheet.crust[i]
	var v2 := Vector2(puck.vel.x, puck.vel.z)
	var s := v2.length()
	var base := 0.12 + 0.035 * s  # the game's own drag, already taken this step
	var extra := 0.0
	var slush := water > 0.1 and snow > 0.3
	surface = "CLEAN"
	if snow >= PILE:
		surface = "PILE"
		snow_load = 1.0
		puck.vel = Vector3.ZERO
		drag = s / maxf(dt, 0.001)
		return
	if snow > 0.05:
		surface = "SLUSH" if slush else "SNOW"
		snow_load = maxf(snow_load, minf(snow, SNOW_CAP) / SNOW_CAP)
		extra += SNOW_DRAG * minf(snow, SNOW_CAP)
	elif snow_load > 0.0:
		extra += LOAD_KEEP * SNOW_DRAG * SNOW_CAP * snow_load
	if water > 0.05 and not slush:
		wet_load = 1.0
		var share := FILM_SLICK
		if water >= IceSheet.POOL_RUNS:
			surface = "POOL"
			share = lerpf(POOL_SLOW, POOL_FAST, clampf((s - SLOW_V) / (FAST_V - SLOW_V), 0.0, 1.0))
		elif water >= IceSheet.FILM_PIN:
			surface = "WET"
		else:
			surface = "WET"
		extra += (share - 1.0) * base
	elif water > 0.05 and slush:
		wet_load = 1.0
	if crust > CRUST_MIN and snow <= 0.05 and water <= 0.05:
		surface = "CRUST"
		extra += (CRUST_DRAG - 1.0) * base
		if s > HOP_SPEED and _hop_t <= 0.0:
			puck.vel.y = HOP_V
			_hop_t = HOP_EVERY
	# the drag: a share of the speed goes, never past a stop
	if s > 0.0:
		var ns := s - extra * dt
		if extra < 0.0:
			ns = s - extra * dt  # a slick surface gives a little back
		ns = maxf(0.0, ns)
		v2 *= ns / s
	drag = extra
	# slush wanders: a sideways kick that drifts
	if slush and s > 0.2:
		_kick = lerpf(_kick, rng.randf_range(-1.0, 1.0), 0.15)
		var perp := Vector2(-v2.y, v2.x).normalized()
		v2 += perp * _kick * SLUSH_KICK * dt
	else:
		_kick = 0.0
	# the slope under the puck: gravity down it (ruts hold, ridges kick)
	var hx := _top(sheet, to_sheet.call(puck.position + Vector3(SLOPE_R, 0.0, 0.0)))
	var hx0 := _top(sheet, to_sheet.call(puck.position - Vector3(SLOPE_R, 0.0, 0.0)))
	var hz := _top(sheet, to_sheet.call(puck.position + Vector3(0.0, 0.0, SLOPE_R)))
	var hz0 := _top(sheet, to_sheet.call(puck.position - Vector3(0.0, 0.0, SLOPE_R)))
	var slope := Vector2(hx - hx0, hz - hz0) * 0.001 / (2.0 * SLOPE_R)
	v2 -= slope * G * dt
	puck.vel.x = v2.x
	puck.vel.z = v2.y
	# what it carries off: a trail of snow, a streak of water
	if _last_at.is_finite():
		_trail_d += a.distance_to(_last_at)
	_last_at = a
	if _trail_d >= TRAIL_STEP:
		_trail_d = 0.0
		if snow_load > 0.05 and snow <= 0.05:
			sheet.add_snow(a, sheet.cell * 2.0, TRAIL_MM * snow_load)
		if wet_load > 0.05 and water <= 0.05:
			var h := sheet.cell * 0.5
			sheet.lay_film(a.x - h, a.x + h, a.y - h, a.y + h, STREAK_MM * wet_load)


## The surface height (mm) of the column at sheet point `p`: ice, crust and
## snow up, gouge down; off the ice, the neighbour's level (no false slope).
static func _top(sheet: IceSheet, p: Vector2) -> float:
	var c := sheet.cell_at(p)
	if not sheet.in_bounds(c.x, c.y) or not sheet.is_ice(c.x, c.y):
		return 0.0
	var i := sheet.index(c.x, c.y)
	return sheet.ice[i] + sheet.crust[i] + sheet.snow[i] - sheet.gouge[i]
