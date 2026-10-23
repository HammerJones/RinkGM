class_name DemoPuck
extends Puck
## The game's puck with one net: the game's physics stands a net on both
## goal lines, but the demo has only the east one (Sean: the fixed west
## net had to go), so the west goal line is open ice to shoot across.
## Everything else (ice, boards, glass, the east net's posts, bar, frame
## and mesh, and the goal there) is the game's own.

const SIDE := 1  # the east net, the one the demo stands on the ice


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
