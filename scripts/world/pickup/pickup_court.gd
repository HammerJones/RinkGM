class_name PickupCourt
extends RefCounted
## The gym's court as the pickup game sees it, in venue coordinates. The
## numbers come from Rink environment's gym (scripts/venue/rec/gym.gd: the
## court is centred on CX, CZ, 28 x 13 m, a hoop on a wall arm at each end)
## and its room in RecPlan (the gym is x -32..2, z -60..-44, 8 m high).

const CX := -15.0
const CZ := -52.0
const HALF_L := 14.0
const HALF_W := 6.5
const ROOM := Rect2(-32.0, -60.0, 34.0, 16.0)
const ROOM_H := 8.0
const RIM_Y := 3.05
const RIM_R := 0.23
const BOARD_IN := 1.2       # backboard in from the baseline
const RIM_OUT := 0.38       # rim centre out from the board
const BOARD_Y := Vector2(2.9, 3.95)
const BOARD_HALF := 0.9
const THREE := 6.75
const THREE_SIDE := 6.0     # the straight part of the three-point line
## The gym doors from the corridor (RecPlan: "Gym west", "Gym east").
const DOORS := [Vector3(-25.0, 0, -44.0), Vector3(-5.0, 0, -44.0)]
## Where the ball lives between runs: on the ball cart in the east corner.
const CART := Vector3(1.0, 1.24, -44.85)
## The sideline in front of the folded bleachers, where the next game waits.
const BENCH_Z := -59.1

## Offence spots: [distance out from the hoop, sideways], mirrored per hoop.
## Top, wings, corners, elbows, blocks, the dunker spot.
const SPOTS := [[7.6, 0.0], [6.6, -3.9], [6.6, 3.9], [1.3, -6.1], [1.3, 6.1],
	[4.8, -2.3], [4.8, 2.3], [1.4, -2.1], [1.4, 2.1], [3.0, 0.0]]


## The rim centre of the hoop at `end` (-1 west, +1 east).
static func rim(end: int) -> Vector3:
	return Vector3(CX + end * (HALF_L - BOARD_IN - RIM_OUT), RIM_Y, CZ)


static func board_x(end: int) -> float:
	return CX + end * (HALF_L - BOARD_IN)


## A floor point `out` metres from the hoop toward mid-court and `side` across.
static func spot(end: int, out: float, side: float) -> Vector3:
	var r := rim(end)
	return Vector3(r.x - end * out, 0, CZ + side)


## Where the ball is checked: the top of the key, just beyond the arc.
static func check_spot(end: int) -> Vector3:
	return spot(end, THREE + 0.7, 0.0)


## Ones inside the arc, twos beyond it.
static func points_from(end: int, at: Vector3) -> int:
	if absf(at.z - CZ) >= THREE_SIDE - 0.05:
		return 2
	return 2 if dist_to_rim(end, at) > THREE else 1


static func dist_to_rim(end: int, at: Vector3) -> float:
	var r := rim(end)
	return Vector2(at.x - r.x, at.z - r.z).length()


## Is `p` on the court floor (with `margin` metres of out of bounds)?
## `half` > 0 is the east half only, < 0 the west half.
static func on_court(p: Vector3, margin := 0.0, half := 0) -> bool:
	var x0 := CX - HALF_L - margin
	var x1 := CX + HALF_L + margin
	if half > 0:
		x0 = CX - margin
	elif half < 0:
		x1 = CX + margin
	return p.x >= x0 and p.x <= x1 and absf(p.z - CZ) <= HALF_W + margin


static func in_room(p: Vector3, margin := 0.0) -> bool:
	return p.x >= ROOM.position.x + margin and p.x <= ROOM.end.x - margin \
		and p.z >= ROOM.position.y + margin and p.z <= ROOM.end.y - margin \
		and p.y > -0.5 and p.y < ROOM_H


static func clamp_in_room(p: Vector3, margin := 0.4) -> Vector3:
	return Vector3(clampf(p.x, ROOM.position.x + margin, ROOM.end.x - margin), p.y,
		clampf(p.z, ROOM.position.y + margin, ROOM.end.y - margin))
