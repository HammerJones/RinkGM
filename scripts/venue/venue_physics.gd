class_name VenuePhysics
## Where the rink's own physics hands over to the building. Below the top of
## the glass the boards keep the puck in (Rink.confine); a puck that clears
## the glass, or goes over the boards in front of a bench, is out of play and
## flies into the building, bouncing off the venue's colliders (stands, seats,
## fans, benches, walls, floor) on physics layer 2. Hockey physics owns the
## puck; it asks `clears_glass` each step and, once out, `contact` for the
## building. The game owns the whistle. All static, no venue node needed.

const SIDE_GLASS := 1.2    # above the boards along the sides
const BOX_GLASS := 1.4     # in front of the penalty boxes
const END_GLASS := 2.4     # ends and corners
const BENCH_GAPS := [[-11.4, -2.6], [2.6, 11.4]]  # open over the player benches
const BOX_HALF := 5.8
const RESTITUTION := 0.35
const SLIDE := 0.7         # tangential speed kept on a bounce


static func board_top() -> float:
	return Rink.BOARD_H + 0.04


## Height of the glass above the boards at board point `p` with outward
## normal `n` (0 in front of the benches, where there is none).
static func glass_height(p: Vector2, n: Vector2) -> float:
	if n.y < -0.99:
		for g in BENCH_GAPS:
			if p.x > g[0] and p.x < g[1]:
				return 0.0
	if absf(n.y) > 0.99:
		return BOX_GLASS if n.y > 0.0 and absf(p.x) < BOX_HALF else SIDE_GLASS
	return END_GLASS


## Top of the glass (metres above the ice) at the board nearest `p`.
static func glass_top(p: Vector2) -> float:
	return board_top() + glass_height(p, Rink.board_normal(p))


## True when a puck at `pos` touching the boards is above the glass there.
static func clears_glass(pos: Vector3, radius: float) -> bool:
	var p := Vector2(pos.x, pos.z)
	return Rink.sdf(p) > -radius and pos.y - radius > glass_top(p)


## The venue's answer for a puck that is out of play, for Hockey physics to
## call once `clears_glass` is true (the boards stay in charge below it).
## Sweeps the puck's move this step, `pos` to `pos + vel * dt`, against the
## building's colliders (stands, seat rows, fans, benches, walls, floor) and
## returns the first contact, or an empty Dictionary when the move is clear:
##   point        Vector3  puck centre at contact (surface + normal * radius)
##   normal       Vector3  surface normal, pointing back toward the puck
##   fraction     float    how far along the move (0..1) it touched
##   restitution  float    normal speed kept on the bounce
##   friction     float    share of the tangential speed kept
## `bounce()` applies it if the caller has no contact model of its own.
static func contact(space: PhysicsDirectSpaceState3D, pos: Vector3, vel: Vector3, radius: float, dt: float) -> Dictionary:
	if space == null:
		return {}
	var move := vel * dt
	var len := move.length()
	if len < 0.00001:
		return {}
	var dir := move / len
	var q := PhysicsRayQueryParameters3D.create(pos, pos + move + dir * radius, 1 << (VenueKit.VENUE_LAYER - 1))
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return {}
	var n: Vector3 = hit.normal
	var at: Vector3 = hit.position + n * radius
	return {
		"point": at, "normal": n, "fraction": clampf((at - pos).dot(dir) / len, 0.0, 1.0),
		"restitution": RESTITUTION, "friction": SLIDE,
	}


## Velocity after a `contact()`: the normal part reflected by its
## restitution, the tangential part kept by its friction; a slow landing on a
## floor or tread settles instead of chattering.
static func bounce(vel: Vector3, c: Dictionary) -> Vector3:
	var n: Vector3 = c.normal
	var vn := vel.dot(n)
	if vn >= 0.0:
		return vel
	var out: Vector3 = (vel - n * vn) * float(c.friction) - n * vn * float(c.restitution)
	if n.y > 0.7 and absf(vn) < 1.0:
		out.y = 0.0
	return out
