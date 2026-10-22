class_name IceEdger
extends Node3D
## The ice edger: a walk-behind machine (Sean's uploaded mower model
## voxelised, art/props/ice_edger.vox) with a spinning disc blade under
## its deck, tilted so its leading rim does the cutting, pushed by hand
## along the boards where the resurfacer cannot reach. Look at its
## handles and E takes them: W pushes, S pulls back, A and D turn it with
## your weight (slower with the blade in the ice), the wheel is the crank
## on the handle (counter-clockwise lowers the blade, the opposite of the
## Zambelli's handwheel, half a millimetre a notch) and TAB lifts the
## blade clear or sets it back to the crank's depth. The cut is
## `IceSheet.edge_sweep`: a `BLADE_R`-wide lane shaved `depth_mm` below
## the surface with striations circling the disc, and every `ARC_STEP`
## of travel the tilted rim rocks in and leaves a deep arc `ARC_W` wide
## (Sean: about 3.5 cm, every 5 cm or so) that a light flood evens out.
## The shavings fly `THROW` to its right as snow. It lives in the bay.

const BLADE_R := 0.23  # a 46 cm disc
const BLADE_Z := -0.15  # the disc's centre ahead of the machine's middle
const TILT := deg_to_rad(4.0)
const ARC_STEP := 0.05  # metres of travel between arcs
const ARC_W := 0.035
const ARC_MM := 1.2  # the arc's gouge beyond the set depth
const DEPTH_MAX := 4.0  # mm the crank can set
const CRANK_MM := 0.5  # a notch of the crank
const PUSH_SPEED := 0.9  # m/s pushed flat out
const PULL_SPEED := 0.5
const ACCEL := 1.4
const TURN_RATE := 0.8  # rad/s with the blade up
const TURN_RATE_CUT := 0.35  # rad/s with the blade in the ice
const THROW := 0.75  # metres to the right the shavings land (Sean: 2 to 3 ft)
const THROW_W := 0.5
const SNOW_EXPAND := 2.5
const HANDLES := Vector3(0.0, 0.05, 1.25)  # where you stand to push
const TAKE_REACH := 2.4
const SPIN := 120.0  # rad/s, for the look

var depth_mm := 1.0  # the crank's setting
var blade_down := false
var speed := 0.0
var shaved_mm := 0.0
var body: MeshInstance3D
var disc: MeshInstance3D
var crank: Node3D
var hull: AnimatableBody3D
var _since_arc := 0.0


func _ready() -> void:
	body = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = ObjectCatalog.mesh("ice_edger")
	body.material_override = PropMaterial.shared()
	add_child(body)
	# the disc under the deck, its front edge down
	disc = MeshInstance3D.new()
	disc.name = "Disc"
	var cyl := CylinderMesh.new()
	cyl.top_radius = BLADE_R
	cyl.bottom_radius = BLADE_R
	cyl.height = 0.008
	cyl.radial_segments = 24
	disc.mesh = cyl
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.72, 0.73, 0.75)
	steel.metallic = 0.8
	steel.roughness = 0.35
	disc.material_override = steel
	disc.position = Vector3(0.0, 0.03, BLADE_Z)
	disc.rotation.x = -TILT
	add_child(disc)
	# the crank on the handle: a hub, an arm and a knob, turned to the setting
	crank = Node3D.new()
	crank.name = "Crank"
	crank.position = Vector3(0.0, 0.98, 0.78)
	add_child(crank)
	var hub := MeshInstance3D.new()
	var hub_m := CylinderMesh.new()
	hub_m.top_radius = 0.025
	hub_m.bottom_radius = 0.025
	hub_m.height = 0.04
	hub.mesh = hub_m
	hub.rotation.x = PI / 2
	hub.material_override = steel
	crank.add_child(hub)
	var arm := MeshInstance3D.new()
	var arm_m := BoxMesh.new()
	arm_m.size = Vector3(0.02, 0.09, 0.015)
	arm.mesh = arm_m
	arm.position = Vector3(0.0, 0.045, 0.025)
	arm.material_override = steel
	crank.add_child(arm)
	var knob := MeshInstance3D.new()
	var knob_m := CylinderMesh.new()
	knob_m.top_radius = 0.012
	knob_m.bottom_radius = 0.012
	knob_m.height = 0.05
	knob.mesh = knob_m
	knob.rotation.x = PI / 2
	knob.position = Vector3(0.0, 0.085, 0.055)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.12, 0.12, 0.12)
	black.roughness = 0.7
	knob.material_override = black
	crank.add_child(knob)
	_pose_crank()
	hull = AnimatableBody3D.new()
	hull.name = "Hull"
	hull.sync_to_physics = false
	hull.collision_layer = Layers.bit(Layers.PROPS)
	hull.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.7, 1.0, 1.7)
	cs.shape = bs
	cs.position = Vector3(0.0, 0.5, 0.0)
	hull.add_child(cs)
	add_child(hull)


func _process(dt: float) -> void:
	if blade_down or absf(speed) > 0.01:
		disc.rotate_object_local(Vector3.UP, SPIN * dt)


## True when the view line meets the handles within reach.
func aimed(origin: Vector3, dir: Vector3) -> bool:
	var centre := to_global(Vector3(0.0, 0.9, 0.7))
	var to := centre - origin
	var t := to.dot(dir)
	if t < 0.0 or t > TAKE_REACH:
		return false
	return (to - dir * t).length() < 0.45


## A notch of the crank: up is clockwise and raises the blade, down is
## counter-clockwise and lowers it (the opposite of the Zambelli's wheel).
func crank_notch(up: bool) -> void:
	depth_mm = clampf(depth_mm + (-CRANK_MM if up else CRANK_MM), 0.0, DEPTH_MAX)
	_pose_crank()


func toggle_blade() -> void:
	blade_down = not blade_down


## A step of pushing: `push` 1 forward, -1 back; `turn` 1 left .. -1 right.
## Returns the disc centre's path on the ground, [before, after] (world),
## or [] when it did not move.
func step(dt: float, push: float, turn: float) -> Array[Vector3]:
	var want := push * (PUSH_SPEED if push > 0.0 else PULL_SPEED)
	speed = move_toward(speed, want, ACCEL * dt)
	if absf(speed) < 0.003:
		speed = 0.0
	var rate := TURN_RATE_CUT if blade_down else TURN_RATE
	if turn != 0.0:
		rotate_y(turn * rate * dt)
	if speed == 0.0:
		return []
	var before := to_global(Vector3(0.0, 0.0, BLADE_Z))
	global_position += -global_transform.basis.z * speed * dt
	var after := to_global(Vector3(0.0, 0.0, BLADE_Z))
	return [before, after]


## The blade over the ice from `a` to `b` (sheet metres, the disc's
## centre): shaves the lane, rocks an arc in every ARC_STEP, throws the
## shavings to the right. Returns the millimetres shaved.
func cut(sheet: IceSheet, a: Vector2, b: Vector2) -> float:
	if not blade_down:
		return 0.0
	var ds := a.distance_to(b)
	_since_arc += ds
	var arcs := 0
	while _since_arc >= ARC_STEP:
		_since_arc -= ARC_STEP
		arcs += 1
	var dir := (b - a).normalized() if ds > 1e-6 else Vector2.RIGHT
	var took := sheet.edge_sweep(
		a, b, BLADE_R, depth_mm, ARC_MM + depth_mm * 0.3 if arcs > 0 else 0.0, ARC_W
	)
	shaved_mm += took
	if took > 0.0:
		# shavings: mm summed over cells -> m3 of ice -> snow, landing to the right
		var m3 := took * 0.001 * sheet.cell * sheet.cell
		var area := PI * (THROW_W / 2) * (THROW_W / 2)
		var mm := m3 * SNOW_EXPAND / area * 1000.0
		var right := Vector2(-dir.y, dir.x)  # right of the travel, in sheet coords (x right, z down)
		var land := b + right * randf_range(THROW - 0.15, THROW + 0.15)
		sheet.add_snow(land, THROW_W, mm)
	return took


func state_text() -> String:
	return (
		"EDGER: BLADE %s, CRANK %.1f MM   SHAVED %.0f MM"
		% ["DOWN" if blade_down else "UP", depth_mm, shaved_mm]
	)


func _pose_crank() -> void:
	# counter-clockwise (seen from behind, looking along -z) as it lowers
	crank.rotation.z = depth_mm / CRANK_MM * TAU / 8.0
