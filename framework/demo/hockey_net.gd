class_name HockeyNet
extends Node3D
## A hockey net from primitives (red pipe, white mesh): 6 ft by 4 ft, a
## metre deep. It starts in the bay; look at it and E picks it up (it
## rides ahead of you), E again sets it down where you stand, facing the
## way you face. Nothing is pinned: it stays wherever it was carried.

const W := 1.83
const H := 1.22
const D := 1.0
const PIPE_R := 0.025
const TAKE_REACH := 2.6
const AIM_R := 1.1
const CARRY := Vector3(0.0, 0.0, -1.7)

var carried := false
var _floor_parent: Node3D


func _ready() -> void:
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.12, 0.1)
	red.roughness = 0.5
	var mesh := StandardMaterial3D.new()
	mesh.albedo_color = Color(0.95, 0.95, 0.95, 0.45)
	mesh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.roughness = 1.0
	# the front frame: two posts and the crossbar, the goal line at z 0
	for x: float in [-W / 2, W / 2]:
		_pipe(Vector3(x, 0.0, 0.0), Vector3(x, H, 0.0), red)
		# the base pipe back along each side, curving in: straight here
		_pipe(Vector3(x, 0.0, 0.0), Vector3(x * 0.8, 0.0, D), red)
		# the top bar back from the crossbar to the back frame
		_pipe(Vector3(x, H, 0.0), Vector3(x * 0.8, H * 0.55, D * 0.6), red)
		_pipe(Vector3(x * 0.8, H * 0.55, D * 0.6), Vector3(x * 0.8, 0.0, D), red)
	_pipe(Vector3(-W / 2, H, 0.0), Vector3(W / 2, H, 0.0), red)
	_pipe(Vector3(-W / 2 * 0.8, 0.0, D), Vector3(W / 2 * 0.8, 0.0, D), red)
	_pipe(Vector3(-W / 2 * 0.8, H * 0.55, D * 0.6), Vector3(W / 2 * 0.8, H * 0.55, D * 0.6), red)
	# the mesh: the back, the sides and the top as thin panels
	_panel(
		[
			Vector3(-W / 2 * 0.8, 0.0, D),
			Vector3(W / 2 * 0.8, 0.0, D),
			Vector3(W / 2 * 0.8, H * 0.55, D * 0.6),
			Vector3(-W / 2 * 0.8, H * 0.55, D * 0.6)
		],
		mesh
	)
	_panel(
		[
			Vector3(-W / 2 * 0.8, H * 0.55, D * 0.6),
			Vector3(W / 2 * 0.8, H * 0.55, D * 0.6),
			Vector3(W / 2, H, 0.0),
			Vector3(-W / 2, H, 0.0)
		],
		mesh
	)
	for x: float in [-W / 2, W / 2]:
		_panel(
			[
				Vector3(x, 0.0, 0.0),
				Vector3(x * 0.8, 0.0, D),
				Vector3(x * 0.8, H * 0.55, D * 0.6),
				Vector3(x, H, 0.0)
			],
			mesh
		)
	_floor_parent = get_parent()


func _pipe(a: Vector3, b: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = PIPE_R
	cyl.bottom_radius = PIPE_R
	cyl.height = a.distance_to(b)
	cyl.radial_segments = 10
	mi.mesh = cyl
	mi.material_override = mat
	mi.position = (a + b) / 2
	var dir := (b - a).normalized()
	if absf(dir.dot(Vector3.UP)) < 0.999:
		mi.basis = Basis.looking_at(dir, Vector3.UP).rotated(
			Basis.looking_at(dir, Vector3.UP).x, PI / 2
		)
	add_child(mi)


func _panel(pts: Array, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in [0, 1, 2, 0, 2, 3]:
		st.add_vertex(pts[k])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)


## True when the view line from `origin` along `dir` meets the net within reach.
func aimed(origin: Vector3, dir: Vector3) -> bool:
	if carried:
		return false
	var centre := to_global(Vector3(0.0, H / 2, D / 2))
	var to := centre - origin
	var t := to.dot(dir)
	if t < 0.0 or t > TAKE_REACH + AIM_R:
		return false
	return (to - dir * t).length() < AIM_R


func prompt() -> String:
	return "[E] PICK UP THE NET"


## Carried ahead of the walker, its mouth toward them.
func carry(walker: Node3D) -> void:
	carried = true
	reparent(walker, false)
	position = CARRY
	rotation = Vector3(0.0, PI, 0.0)


## Set down where it is, on the ice, facing the way the carrier faces.
func set_down() -> void:
	carried = false
	var yaw := global_rotation.y
	var at := global_position
	reparent(_floor_parent, false)
	global_position = Vector3(at.x, 0.0, at.z)
	global_rotation = Vector3(0.0, yaw, 0.0)


## True when `world` is inside the net: past the goal line, between the
## posts and short of the back mesh.
func holds(world: Vector3) -> bool:
	var l := to_local(world)
	return absf(l.x) < W / 2 * 0.92 and l.z > 0.05 and l.z < D * 0.9 and l.y < H
