class_name StickDebris
extends Node3D
## A piece of a broken stick sliding and spinning to a stop on the ice. It's
## only for show: play goes on around it, and the game sweeps it up at the
## next faceoff.

var vel := Vector3.ZERO
var spin := 0.0


## Copies `part` (a piece of the skater's rig) where it is now, then lets it
## fly off with `v`.
static func spawn(parent: Node, part: Node3D, v: Vector3) -> StickDebris:
	var d := StickDebris.new()
	var piece := part.duplicate() as Node3D
	piece.transform = Transform3D.IDENTITY
	piece.visible = true
	d.add_child(piece)
	parent.add_child(d)
	d.global_transform = part.global_transform
	d.vel = v
	d.spin = randf_range(-14.0, 14.0)
	return d


func _physics_process(dt: float) -> void:
	vel.y -= Puck.GRAVITY * dt
	position += vel * dt
	if position.y <= 0.02:
		# it lands and slides
		position.y = 0.02
		vel.y = absf(vel.y) * 0.2 if absf(vel.y) > 1.0 else 0.0
		var flat := Vector2(vel.x, vel.z)
		flat = flat.move_toward(Vector2.ZERO, 4.0 * dt)
		vel.x = flat.x
		vel.z = flat.y
		spin = move_toward(spin, 0.0, 20.0 * dt)
		# topple flat: its length along the ice, its thin side down
		var b := transform.basis.orthonormalized()
		var along := Vector3(b.y.x, 0, b.y.z)
		if along.length() < 0.1:
			along = Vector3(b.x.x, 0, b.x.z)
		if along.length() > 0.01:
			along = along.normalized()
			var lie := Basis(along.cross(Vector3.UP), along, Vector3.UP)
			transform.basis = Basis(b.get_rotation_quaternion().slerp(lie.get_rotation_quaternion(), 1.0 - exp(-10.0 * dt)))
	rotate_y(spin * dt)
	if absf(position.x) > Rink.HALF_L or absf(position.z) > Rink.HALF_W - 0.2:
		position.x = clampf(position.x, -Rink.HALF_L, Rink.HALF_L)
		position.z = clampf(position.z, -Rink.HALF_W + 0.2, Rink.HALF_W - 0.2)
		vel.x *= -0.3
		vel.z *= -0.3
