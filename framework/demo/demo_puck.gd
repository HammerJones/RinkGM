class_name DemoPuck
extends Puck
## The game's puck with one net: the game's physics stands a net on both
## goal lines, but the demo has only the east one (Sean: the fixed west
## net had to go), so the west goal line is open ice to shoot across.
## Everything else (ice, boards, glass, the east net's posts, bar, frame
## and mesh, and the goal there) is the game's own, except the boards'
## grazing touch: a puck running along the boards or round a corner at a
## shallow angle glides along them (Sean, 2026-10-27: the corners caught
## the puck), losing only a little; a square hit bounces as the game's.

const SIDE := 1  # the east net, the one the demo stands on the ice
const GLIDE_ANGLE := deg_to_rad(25.0)  # into the boards shallower than this: a glide, not a bounce
const GLIDE_KEEP := 0.985  # share of the speed kept per touch while gliding
const BOUNCE_E := 0.6  # the game's restitution off the boards
const BOUNCE_KEEP := 0.92


func _collide_boards() -> void:
	var r := Rink.confine(position, RADIUS)
	var n: Vector2 = r[1]
	if n == Vector2.ZERO:
		return
	position = r[0]
	var n3 := Vector3(n.x, 0.0, n.y)
	var vn := vel.dot(n3)
	if vn <= 0.0:
		return
	var flat := Vector2(vel.x, vel.z)
	var into := asin(clampf(vn / maxf(flat.length(), 0.001), 0.0, 1.0))
	boards_hit.emit(position, vn)
	if into < GLIDE_ANGLE:
		# along the boards: the normal part goes, the rest runs on
		vel -= n3 * vn
		vel *= GLIDE_KEEP
		return
	vel -= n3 * vn * (1.0 + BOUNCE_E)
	vel *= BOUNCE_KEEP


func _collide_nets(prev: Vector3) -> void:
	var speed := vel.length()
	if _collide_east():
		post_hit.emit(position, speed)
	if in_net_side != 0:
		return
	var gx: float = SIDE * Rink.GOAL_X
	var u: float = (position.x - gx) * SIDE
	var u_prev: float = (prev.x - gx) * SIDE
	if u <= RADIUS or u_prev > RADIUS or u > Rink.NET_DEPTH:
		return
	var at := prev.lerp(position, (RADIUS - u_prev) / (u - u_prev))
	if absf(at.z) < Rink.NET_HALF_W and at.y < Rink.NET_H:
		in_net_side = SIDE
		goal_scored.emit(SIDE)


## NetPhysics.collide for the east net alone.
func _collide_east() -> bool:
	var rang := false
	var gx: float = SIDE * Rink.GOAL_X
	var u: float = (position.x - gx) * SIDE
	if (
		u < -NetPhysics.MARGIN
		or u > Rink.NET_DEPTH + NetPhysics.MARGIN
		or absf(position.z) > Rink.NET_HALF_W + NetPhysics.MARGIN
		or position.y > Rink.NET_H + NetPhysics.MARGIN
	):
		return false
	for pz in [-Rink.NET_HALF_W - Rink.POST_R, Rink.NET_HALF_W + Rink.POST_R]:
		var post := Vector3(gx, clampf(position.y, 0.0, Rink.NET_H), pz)
		var c := Contact.sphere_sphere(position, RADIUS, post, Rink.POST_R)
		rang = NetPhysics._hit(self, c, NetPhysics.E_POST, NetPhysics.MU_POST) or rang
	var bar := Vector3(
		gx, Rink.NET_H + Rink.POST_R, clampf(position.z, -Rink.NET_HALF_W, Rink.NET_HALF_W)
	)
	var cb := Contact.sphere_sphere(position, RADIUS, bar, Rink.POST_R)
	rang = NetPhysics._hit(self, cb, NetPhysics.E_POST, NetPhysics.MU_POST) or rang
	for b in NetPhysics.boxes(SIDE):
		NetPhysics._hit(self, Contact.sphere_box(position, RADIUS, b[0], b[1]), b[2], b[3])
	return rang
