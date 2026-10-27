class_name Contact
extends RefCounted
## Collision helpers shared by everything in play: the puck off blades,
## pads, boards and bodies, and bodies off each other. Each contact is an
## impulse along the contact normal (restitution) plus Coulomb friction
## along the surface, worked out from the two objects' velocities.

const PUCK_MASS := 0.17   # kg
## Effective mass of a blade being swung through the puck: blade, shaft and
## the hands driving it. Much heavier than the puck, so it hands over most
## of its speed.
const BLADE_MASS := 0.9
const BODY_E := 0.1       # restitution between two skaters' bodies (padding and give: barely bouncy)
const CHECK_TIME := 0.12  # s a shoulder check drives through the contact


## A body moving at `v` hits a surface moving at `surface_v`. `n` points out
## of the surface toward the body. Returns the body's new velocity, with
## restitution `e` along `n` and friction `mu` against the slip along the
## surface. `share` scales the impulse for a surface that isn't infinitely
## heavy (see `share_of`).
static func bounce(v: Vector3, n: Vector3, surface_v: Vector3, e: float, mu: float, share := 1.0) -> Vector3:
	var rel := v - surface_v
	var vn := rel.dot(n)
	if vn >= 0.0:
		return v
	var jn := -(1.0 + e) * vn * share
	var slip := rel - n * vn
	var s := slip.length()
	var out := v + n * jn
	if s > 0.0001:
		out -= slip / s * minf(mu * jn, s * share)
	return out


## The share of a collision's impulse the light body `m` takes against `big`:
## big/(big+m), 1 for an immovable surface.
static func share_of(m: float, big: float) -> float:
	return big / (big + m)


## Reduced mass of two colliding bodies.
static func reduced_mass(m1: float, m2: float) -> float:
	return m1 * m2 / (m1 + m2)


## A sphere (centre `c`, radius `r`) against a box of half extents `half`
## placed by `xf`. Returns {"n": world normal out of the box, "depth": m,
## "point": world contact point} or {} if they don't touch.
static func sphere_box(c: Vector3, r: float, xf: Transform3D, half: Vector3) -> Dictionary:
	var l := xf.affine_inverse() * c
	var q := Vector3(clampf(l.x, -half.x, half.x), clampf(l.y, -half.y, half.y), clampf(l.z, -half.z, half.z))
	var d := l - q
	var dist := d.length()
	if dist > r:
		return {}
	var n_local: Vector3
	var depth: float
	if dist > 0.00001:
		n_local = d / dist
		depth = r - dist
	else:
		# centre inside the box: out through the nearest face
		var gap := half - l.abs()
		if gap.x <= gap.y and gap.x <= gap.z:
			n_local = Vector3(signf(l.x) if l.x != 0.0 else 1.0, 0, 0)
			depth = gap.x + r
		elif gap.y <= gap.z:
			n_local = Vector3(0, signf(l.y) if l.y != 0.0 else 1.0, 0)
			depth = gap.y + r
		else:
			n_local = Vector3(0, 0, signf(l.z) if l.z != 0.0 else 1.0)
			depth = gap.z + r
	return {"n": (xf.basis * n_local).normalized(), "depth": depth, "point": xf * q}


## A sphere against another sphere (centre `o`, radius `ro`), same result.
static func sphere_sphere(c: Vector3, r: float, o: Vector3, ro: float) -> Dictionary:
	var d := c - o
	var dist := d.length()
	if dist > r + ro or dist < 0.00001:
		return {}
	var n := d / dist
	return {"n": n, "depth": r + ro - dist, "point": o + n * ro}
