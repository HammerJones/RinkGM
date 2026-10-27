class_name NetPhysics
extends RefCounted
## The two goals as solid objects for the puck: iron posts and crossbar
## (cylinders, lively), and the frame and netting as boxes taken from the
## net's own voxel model (Models.net(), the net drawn on the ice), so the
## puck bounces off the net you see. The netting gives: a puck driven into
## it dies there, one off the base frame skips back out.

const E_POST := 0.7
const MU_POST := 0.1
const E_MESH := 0.1
const MU_MESH := 0.6
const E_FRAME := 0.4
const MU_FRAME := 0.2
const FRAME_TOP := 0.13       # m: boxes lower than this are the base frame on the ice
## Boxes are clipped to start this far behind the goal line, so the coarse
## netting boxes never stand in the goal mouth (the posts are exact cylinders).
const BEHIND := 0.1
const MARGIN := 0.25

static var _boxes := {}  # side -> Array of [Transform3D, half extents, e, mu]


## The collision boxes of the net at `side`'s end, in world space.
static func boxes(side: int) -> Array:
	if not _boxes.has(side):
		var placed := Transform3D(Basis(Vector3.UP, side * PI * 0.5), Vector3(side * Rink.GOAL_X, 0, 0))
		var out := []
		for b: AABB in Models.net().collision_boxes(2):
			var z0 := maxf(b.position.z, BEHIND)
			var z1 := b.end.z
			if z1 <= z0:
				continue
			var lo := Vector3(b.position.x, b.position.y, z0)
			var size := Vector3(b.size.x, b.size.y, z1 - z0)
			var frame := lo.y + size.y <= FRAME_TOP
			out.append([placed * Transform3D(Basis.IDENTITY, lo + size * 0.5), size * 0.5,
				E_FRAME if frame else E_MESH, MU_FRAME if frame else MU_MESH])
		_boxes[side] = out
	return _boxes[side]


## Pushes the puck out of anything of either net it overlaps and bounces it.
## Returns true if it rang off a post or the crossbar.
static func collide(puck: Puck) -> bool:
	var rang := false
	var p := puck.position
	for side in [-1, 1]:
		var gx: float = side * Rink.GOAL_X
		var u: float = (p.x - gx) * side
		if u < -MARGIN or u > Rink.NET_DEPTH + MARGIN or absf(p.z) > Rink.NET_HALF_W + MARGIN or p.y > Rink.NET_H + MARGIN:
			continue
		for pz in [-Rink.NET_HALF_W - Rink.POST_R, Rink.NET_HALF_W + Rink.POST_R]:
			var post := Vector3(gx, clampf(puck.position.y, 0.0, Rink.NET_H), pz)
			rang = _hit(puck, Contact.sphere_sphere(puck.position, Puck.RADIUS, post, Rink.POST_R), E_POST, MU_POST) or rang
		var bar := Vector3(gx, Rink.NET_H + Rink.POST_R, clampf(puck.position.z, -Rink.NET_HALF_W, Rink.NET_HALF_W))
		rang = _hit(puck, Contact.sphere_sphere(puck.position, Puck.RADIUS, bar, Rink.POST_R), E_POST, MU_POST) or rang
		for b in boxes(side):
			_hit(puck, Contact.sphere_box(puck.position, Puck.RADIUS, b[0], b[1]), b[2], b[3])
	return rang


## Resolves one contact; true if the puck was coming in hard enough to ring.
static func _hit(puck: Puck, c: Dictionary, e: float, mu: float) -> bool:
	if c.is_empty():
		return false
	var n: Vector3 = c["n"]
	puck.position += n * c["depth"]
	var vn := puck.vel.dot(n)
	puck.vel = Contact.bounce(puck.vel, n, Vector3.ZERO, e, mu)
	return vn < -1.0
