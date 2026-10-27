class_name SnowPusher
extends Node3D
## The snow pusher: a three-foot white blade on a yellow shaft with a
## D-grip (Sean's photo; art/props/snow_pusher.vox from
## tools/propgen/snow_pusher.py, modelled in its pushing pose), hung on
## the bay wall. Look at it and E takes it: the blade rides ahead of your
## feet on the ice, and walking pushes it. Snow in the blade's path is
## swept up into it (`IceSheet.scoop()`), up to `CAPACITY`, the surplus
## rolling off the blade's ends; LMB sets the load down ahead as a mound
## (`IceSheet.mound()`), and so does pulling the blade back; RMB lifts the
## blade clear to walk over snow without moving it. The load is drawn in
## the blade. The demo (ice_demo.gd `_shovel()`) does the sweeping from
## `blade_ends()`; this is the prop, the state and the load.

const BLADE_W := 0.91  # 3 ft
const CAPACITY := 0.06  # m3 the blade carries: a roll of snow 30 cm tall along its 3 ft
const HOLD := Vector3(0.0, 0.0, -1.15)  # the blade's foot ahead of the pusher's feet
const LIFT := 0.25  # the blade carried clear of the snow
const TAKE_REACH := 2.6
const HANG_R := 0.8
const LEAN := deg_to_rad(52.0)  # the model's shaft from vertical

var held := false
var raised := false
var load := 0.0  # m3 in the blade
var prop: MeshInstance3D
var pile: MeshInstance3D
var last0 := Vector2.INF  # the blade's ends on the sheet last frame (sheet metres)
var last1 := Vector2.INF
var _hang_parent: Node3D
var _hang_pos := Vector3.ZERO
var _hang_rot := Vector3.ZERO


## Hangs it on a wall at `at` (world, the grip's hook), the blade's face
## toward `yaw`: the shaft stood vertical, the blade's foot out from the wall.
func build(at: Vector3, yaw: float) -> void:
	prop = MeshInstance3D.new()
	prop.name = "Pusher"
	prop.mesh = ObjectCatalog.mesh("snow_pusher")
	prop.material_override = PropMaterial.shared()
	add_child(prop)
	_hang_parent = self
	_hang_pos = at
	_hang_rot = Vector3(-LEAN, yaw, 0.0)
	prop.position = _hang_pos
	prop.rotation = _hang_rot
	pile = MeshInstance3D.new()
	pile.name = "Load"
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	sph.radial_segments = 24
	sph.rings = 12
	pile.mesh = sph
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.96, 0.98)
	white.roughness = 1.0
	pile.material_override = white
	pile.visible = false
	prop.add_child(pile)


## True when the view line from `origin` along `dir` meets the hung pusher within reach.
func aimed(origin: Vector3, dir: Vector3) -> bool:
	if held or prop == null:
		return false
	var centre := prop.global_position + Vector3(0.0, 0.6, 0.0)
	var to := centre - origin
	var t := to.dot(dir)
	if t < 0.0 or t > TAKE_REACH + HANG_R:
		return false
	return (to - dir * t).length() < HANG_R


func prompt() -> String:
	return "[E] TAKE THE SNOW PUSHER"


## In hand: the blade ahead of the feet, on the ice, square to the walk.
func take(walker: Node3D) -> void:
	held = true
	raised = false
	prop.reparent(walker, false)
	prop.position = HOLD
	prop.rotation = Vector3.ZERO
	last0 = Vector2.INF
	last1 = Vector2.INF


## Back on its hook; whatever was in the blade is set down by the caller first.
func hang() -> void:
	held = false
	prop.reparent(_hang_parent, false)
	prop.position = _hang_pos
	prop.rotation = _hang_rot
	last0 = Vector2.INF
	last1 = Vector2.INF


## The blade lifted clear of the snow, or set back down.
func toggle_raise() -> void:
	raised = not raised
	prop.position = HOLD + Vector3(0.0, LIFT if raised else 0.0, 0.0)
	last0 = Vector2.INF
	last1 = Vector2.INF


## The blade's two ends at the ground, world.
func blade_ends() -> Array[Vector3]:
	return [
		prop.to_global(Vector3(-BLADE_W / 2, 0.0, -0.05)),
		prop.to_global(Vector3(BLADE_W / 2, 0.0, -0.05))
	]


## The load changed: draw it in the blade, a roll of snow along the face.
func set_load(m3: float) -> void:
	load = clampf(m3, 0.0, CAPACITY)
	pile.visible = load > 0.001
	var f := load / CAPACITY
	pile.scale = Vector3(0.44 + 0.02 * f, 0.08 + 0.24 * f, 0.16 + 0.14 * f)
	pile.position = Vector3(0.0, 0.0, 0.08 - 0.1 * f)


func load_text() -> String:
	if not held:
		return "ON THE WALL"
	return "%.0f L%s" % [load * 1000.0, " (RAISED)" if raised else ""]
