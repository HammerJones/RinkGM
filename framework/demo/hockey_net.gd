class_name HockeyNet
extends Node3D
## The game's hockey net (Models.net(): 6 ft by 4 ft, 1.1 m deep). It starts
## in the bay; look at it and E picks it up (it rides ahead of you), E again
## sets it down where you stand, facing the way you face. Nothing is pinned:
## it stays wherever it was carried.

const W := 1.83
const H := 1.22
const D := 1.1
const TAKE_REACH := 2.6
const AIM_R := 1.1
const CARRY := Vector3(0.0, 0.0, -1.7)

var carried := false
var _floor_parent: Node3D


func _ready() -> void:
	# the game's own net (Models.net(): red frame, white mesh, its mouth
	# at z 0 facing -Z, the depth going +Z, pivot on the goal line)
	var mi := MeshInstance3D.new()
	mi.name = "Net"
	mi.mesh = Models.net().build_mesh()
	add_child(mi)
	_floor_parent = get_parent()


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
