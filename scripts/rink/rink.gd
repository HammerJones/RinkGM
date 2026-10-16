class_name Rink
extends Node3D
## NHL-sized rink: geometry used by the simulation (static helpers) and the
## visuals (ice texture, voxel boards, nets). The rink runs along X; z is across.

const LENGTH := 60.96
const WIDTH := 25.9
const CORNER_R := 8.5
const HALF_L := LENGTH * 0.5
const HALF_W := WIDTH * 0.5
const GOAL_X := HALF_L - 3.35
const BLUE_X := 7.62
const NET_HALF_W := 0.915
const NET_H := 1.22
const NET_DEPTH := 1.1
const POST_R := 0.035
const BOARD_H := 1.07
const DOT_X := GOAL_X - 6.1
const DOT_Z := 6.71
const NEUTRAL_DOT_X := BLUE_X - 1.5
const CIRCLE_R := 4.57
const CREASE_R := 1.83
const PX_PER_M := 10


## Signed distance from the rounded-rectangle boards (negative = inside).
static func sdf(p: Vector2) -> float:
	var q := Vector2(absf(p.x), absf(p.y)) - Vector2(HALF_L - CORNER_R, HALF_W - CORNER_R)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - CORNER_R


## Outward normal of the nearest board.
static func board_normal(p: Vector2) -> Vector2:
	var q := Vector2(absf(p.x), absf(p.y)) - Vector2(HALF_L - CORNER_R, HALF_W - CORNER_R)
	var n: Vector2
	if q.x > 0.0 and q.y > 0.0:
		n = q.normalized()
	elif q.x > q.y:
		n = Vector2(1, 0)
	else:
		n = Vector2(0, 1)
	return Vector2(n.x * signf(p.x if p.x != 0.0 else 1.0), n.y * signf(p.y if p.y != 0.0 else 1.0))


## Keeps a circle inside the boards. Returns the outward normal when it was
## pushed back (so callers can bounce), or Vector2.ZERO when there was no contact.
static func confine(node_pos: Vector3, radius: float) -> Array:
	var p := Vector2(node_pos.x, node_pos.z)
	var d := sdf(p)
	if d <= -radius:
		return [node_pos, Vector2.ZERO]
	var n := board_normal(p)
	p -= n * (d + radius)
	return [Vector3(p.x, node_pos.y, p.y), n]


## Pushes a circle (skater) out of the solid net frames behind each goal line.
static func push_out_of_nets(p: Vector2, radius: float) -> Vector2:
	for side in [-1, 1]:
		var x0 := minf(side * GOAL_X, side * (GOAL_X + NET_DEPTH))
		var x1 := maxf(side * GOAL_X, side * (GOAL_X + NET_DEPTH))
		var closest := Vector2(clampf(p.x, x0, x1), clampf(p.y, -NET_HALF_W - 0.05, NET_HALF_W + 0.05))
		var d := p - closest
		var dist := d.length()
		if dist < radius:
			if dist < 0.0001:
				d = Vector2(-side, 0)
				dist = 0.0
			p = closest + d.normalized() * radius
	return p


func _ready() -> void:
	_build_floor()
	_build_ice()
	_build_boards()
	_build_nets()


func _build_floor() -> void:
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(LENGTH + 30, WIDTH + 30)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("2a2b31")
	mat.roughness = 1.0
	floor_mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = floor_mesh
	mi.position.y = -0.02
	add_child(mi)


func _build_ice() -> void:
	var w := int(LENGTH * PX_PER_M)
	var h := int(WIDTH * PX_PER_M)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ice := Color("e4e1d8")
	var red := Color("d42a30")
	var blue := Color("2f5eb0")
	var crease := Color("8fc1e3")
	for j in h:
		for i in w:
			var x := (i + 0.5) / PX_PER_M - HALF_L
			var z := (j + 0.5) / PX_PER_M - HALF_W
			var c := _ice_color(x, z, ice, red, blue, crease)
			var n := rng.randf_range(-0.035, 0.02)
			img.set_pixel(i, j, Color(clampf(c.r + n, 0, 1), clampf(c.g + n, 0, 1), clampf(c.b + n, 0, 1)))
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.55
	mat.metallic_specular = 0.35
	var plane := PlaneMesh.new()
	plane.size = Vector2(LENGTH, WIDTH)
	plane.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _ice_color(x: float, z: float, ice: Color, red: Color, blue: Color, crease: Color) -> Color:
	var p := Vector2(x, z)
	if sdf(p) > 0.0:
		return Color("2a2b31")
	var ax := absf(x)
	var az := absf(z)
	var half_line := 0.5 / PX_PER_M + 0.01
	var ring := 0.09
	# goal crease (in front of the goal line)
	var to_net := Vector2(ax - GOAL_X, z)
	if ax <= GOAL_X and to_net.length() < CREASE_R:
		if to_net.length() > CREASE_R - 0.1:
			return red
		return crease
	if absf(ax - GOAL_X) < half_line:
		return red
	if ax < 0.15:
		return red
	if absf(ax - BLUE_X) < 0.15:
		return blue
	var dc := p.length()
	if dc < 0.15 or absf(dc - CIRCLE_R) < ring:
		return blue
	var dot := Vector2(ax - DOT_X, az - DOT_Z).length()
	if dot < 0.3 or absf(dot - CIRCLE_R) < ring:
		return red
	if Vector2(ax - NEUTRAL_DOT_X, az - DOT_Z).length() < 0.3:
		return red
	return ice


## Boards are oriented voxels: one column of three boxes every 15 cm around the
## rounded perimeter, each rotated to the board's tangent.
func _build_boards() -> void:
	var b := VoxelMeshBuilder.new()
	var step := 0.15
	var kick := Color("b8921f")
	var wall := Color("8f877b")
	var cap := Color("2c5aa3")
	var i := 0
	for sample in _perimeter(step):
		var pos: Vector2 = sample[0]
		var tangent: Vector2 = sample[1]
		var n := Vector2(tangent.y, -tangent.x)
		if n.dot(pos) < 0.0:
			n = -n
		var basis := Basis(Vector3(tangent.x, 0, tangent.y), Vector3.UP, Vector3(n.x, 0, n.y))
		var key := Vector2i(i, 0)
		i += 1
		_board_box(b, pos, n, basis, step, 0.0, 0.2, 0.2, VoxelMeshBuilder.jitter_color(kick, key, 0.05))
		_board_box(b, pos, n, basis, step, 0.2, BOARD_H - 0.08, 0.18, VoxelMeshBuilder.jitter_color(wall, key, 0.07))
		_board_box(b, pos, n, basis, step, BOARD_H - 0.08, BOARD_H + 0.04, 0.32, VoxelMeshBuilder.jitter_color(cap, key, 0.04))
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	add_child(mi)


func _board_box(b: VoxelMeshBuilder, pos: Vector2, n: Vector2, basis: Basis, step: float, y0: float, y1: float, thick: float, col: Color) -> void:
	var center := Vector3(pos.x + n.x * thick * 0.5, (y0 + y1) * 0.5, pos.y + n.y * thick * 0.5)
	var scaled := Basis(basis.x * (step * 1.04), basis.y * (y1 - y0), basis.z * thick)
	b.add_box(Transform3D(scaled, center), col)


## Samples the board line: [[position, unit tangent], ...].
func _perimeter(step: float) -> Array:
	var out := []
	var sx := HALF_L - CORNER_R
	var sz := HALF_W - CORNER_R
	# straight edges
	var x := -sx
	while x < sx:
		out.append([Vector2(x + step * 0.5, -HALF_W), Vector2(1, 0)])
		out.append([Vector2(x + step * 0.5, HALF_W), Vector2(1, 0)])
		x += step
	var z := -sz
	while z < sz:
		out.append([Vector2(-HALF_L, z + step * 0.5), Vector2(0, 1)])
		out.append([Vector2(HALF_L, z + step * 0.5), Vector2(0, 1)])
		z += step
	# corners
	var arc_steps := int(ceil(CORNER_R * PI * 0.5 / step))
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			var c := Vector2(cx * sx, cz * sz)
			for k in arc_steps:
				var a := (k + 0.5) / arc_steps * PI * 0.5
				var dir := Vector2(cx * cos(a), cz * sin(a))
				out.append([c + dir * CORNER_R, Vector2(-dir.y, dir.x)])
	return out


func _build_nets() -> void:
	var mesh := Models.net().build_mesh()
	for side in [-1, 1]:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = Vector3(side * GOAL_X, 0, 0)
		mi.rotation.y = side * PI * 0.5
		add_child(mi)
