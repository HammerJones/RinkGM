class_name ZamboniBay
extends Node3D
## The resurfacer's bay off the +X end of the rink: a concrete pad past
## the end boards under a roof, walled on three sides, lit by its own
## lamp, with a pair of board-height doors in the end boards that swing
## outward (into the bay) on hinges at their outer edges. E on either
## leaf swings both. The demo's boards clamp (`IceDemo._inside_the_boards`)
## lets the machine through the doorway only while they stand open
## (`DOOR_W` wide, with `BAY_D` by `BAY_W` of floor beyond), and the
## leaves carry colliders of their own for the walker. The bay is sized
## for the doors' swing plus the machine and the edger, which lives here.

const DOOR_W := 3.6  # the opening, between the hinges
const LEAF_W := DOOR_W / 2
const BAY_D := 9.0  # metres of floor past the boards
const BAY_W := 8.0
const WALL_H := 3.2
const WALL_T := 0.2
const BACK_DOOR_Z := -2.0  # the door through the back wall to the plant room: its middle
const BACK_DOOR_W := 1.0
const BACK_DOOR_H := 2.1
const OPEN_RAD := deg_to_rad(100.0)  # a leaf swung fully out lies a little past square
const SWING_S := 2.2  # seconds to swing
const AIM_REACH := 3.0
const WALL := Color("8f8c84")
const ROOF := Color("3a3b3f")
const FLOOR := Color("6f7174")

var open := 0.0  # 0 shut .. 1 wide
var want_open := false
var hinge_x := 0.0  # world x of the hinge line (the boards' outer face)
var _leaves: Array[Node3D] = []
var _board_h := 1.07
var _board_t := 0.1
var _kick_h := 0.2
var _board_colour := Color("f2f0ea")
var _kick_colour := Color("e8c23a")


## Builds the bay past the end boards at world `hinge_x` (the boards' outer
## face), centred on z = 0. Board sizes and colours come from the demo so
## the leaves match the boards they sit in.
func build(
	at_x: float, board_h: float, board_t: float, kick_h: float, board: Color, kick: Color
) -> void:
	hinge_x = at_x
	_board_h = board_h
	_board_t = board_t
	_kick_h = kick_h
	_board_colour = board
	_kick_colour = kick
	var shell := StaticBody3D.new()
	shell.name = "Shell"
	shell.collision_layer = Layers.bit(Layers.VENUE)
	shell.collision_mask = 0
	add_child(shell)
	var x0 := hinge_x
	var mid := x0 + BAY_D / 2
	# the pad: concrete, its top level with the ice
	_box(shell, Vector3(mid, -0.1, 0.0), Vector3(BAY_D, 0.2, BAY_W), FLOOR)
	# three walls and the two returns beside the doorway, above the boards;
	# the back wall has a door through to the plant room
	var bx := x0 + BAY_D + WALL_T / 2
	var zn := -BAY_W / 2 - WALL_T  # the back wall's north end
	var zs := BAY_W / 2 + WALL_T
	var dn := BACK_DOOR_Z - BACK_DOOR_W / 2
	var ds := BACK_DOOR_Z + BACK_DOOR_W / 2
	_box(shell, Vector3(bx, WALL_H / 2, (zn + dn) / 2), Vector3(WALL_T, WALL_H, dn - zn), WALL)
	_box(shell, Vector3(bx, WALL_H / 2, (ds + zs) / 2), Vector3(WALL_T, WALL_H, zs - ds), WALL)
	_box(
		shell,
		Vector3(bx, (BACK_DOOR_H + WALL_H) / 2, BACK_DOOR_Z),
		Vector3(WALL_T, WALL_H - BACK_DOOR_H, BACK_DOOR_W),
		WALL
	)
	for s: float in [-1.0, 1.0]:
		_box(
			shell,
			Vector3(mid + WALL_T / 2, WALL_H / 2, s * (BAY_W + WALL_T) / 2),
			Vector3(BAY_D + WALL_T, WALL_H, WALL_T),
			WALL
		)
		var ret_w := (BAY_W - DOOR_W) / 2
		_box(
			shell,
			Vector3(x0 + WALL_T / 2, WALL_H / 2, s * (DOOR_W / 2 + ret_w / 2)),
			Vector3(WALL_T, WALL_H, ret_w),
			WALL
		)
	# the header over the doorway, from well above the machine to the roof
	_box(
		shell,
		Vector3(x0 + WALL_T / 2, (WALL_H + 2.6) / 2, 0.0),
		Vector3(WALL_T, WALL_H - 2.6, DOOR_W),
		WALL
	)
	_box(
		shell,
		Vector3(mid + WALL_T / 2, WALL_H + 0.1, 0.0),
		Vector3(BAY_D + WALL_T, 0.2, BAY_W + 2 * WALL_T),
		ROOF
	)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(mid, WALL_H - 0.3, 0.0)
	lamp.light_color = Color(1.0, 0.93, 0.8)
	lamp.light_energy = 2.5
	lamp.omni_range = 9.0
	lamp.shadow_enabled = false
	add_child(lamp)
	# the leaves: a hinge at each side of the opening, the leaf reaching to the middle
	for s: float in [-1.0, 1.0]:
		var hinge := AnimatableBody3D.new()
		hinge.name = "Leaf%s" % ("N" if s < 0.0 else "S")
		hinge.sync_to_physics = false
		hinge.collision_layer = Layers.bit(Layers.VENUE)
		hinge.collision_mask = 0
		hinge.set_meta("bay_door", true)
		hinge.position = Vector3(hinge_x, 0.0, s * DOOR_W / 2)
		var zc := -s * LEAF_W / 2  # the leaf's middle, toward the doorway's centre
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(_board_t, _board_h, LEAF_W)
		cs.shape = bs
		cs.position = Vector3(0.0, _board_h / 2, zc)
		hinge.add_child(cs)
		_mesh(
			hinge,
			Vector3(0.0, _kick_h / 2, zc),
			Vector3(_board_t + 0.01, _kick_h, LEAF_W),
			_kick_colour
		)
		_mesh(
			hinge,
			Vector3(0.0, _kick_h + (_board_h - _kick_h) / 2, zc),
			Vector3(_board_t, _board_h - _kick_h, LEAF_W),
			_board_colour
		)
		# a hinge strap and a handle, so the leaf reads as a door
		_mesh(
			hinge,
			Vector3(0.0, _board_h * 0.5, 0.0),
			Vector3(_board_t + 0.03, _board_h * 0.9, 0.06),
			Color("5a5d63")
		)
		_mesh(
			hinge,
			Vector3(-_board_t / 2 - 0.02, _board_h * 0.85, zc * 1.7),
			Vector3(0.04, 0.03, 0.18),
			Color("5a5d63")
		)
		add_child(hinge)
		_leaves.append(hinge)


func toggle() -> void:
	want_open = not want_open


func _process(dt: float) -> void:
	var target := 1.0 if want_open else 0.0
	if open == target:
		return
	open = move_toward(open, target, dt / SWING_S)
	for k in _leaves.size():
		var s := -1.0 if k == 0 else 1.0
		# the -z leaf swings +yaw to go outward (+x); the +z leaf the other way
		_leaves[k].rotation.y = -s * open * OPEN_RAD


## True when the view line from `origin` along `dir` meets a leaf within
## reach: the leaf's box in its hinge's space, a slab test on each axis.
func aimed(origin: Vector3, dir: Vector3) -> bool:
	for k in _leaves.size():
		var s := -1.0 if k == 0 else 1.0
		var leaf := _leaves[k]
		var o := leaf.to_local(origin)
		var v := leaf.global_transform.basis.inverse() * dir
		var lo := Vector3(-_board_t, 0.0, minf(0.0, -s * LEAF_W))
		var hi := Vector3(_board_t, _board_h, maxf(0.0, -s * LEAF_W))
		var t0 := 0.0
		var t1 := AIM_REACH
		var hit := true
		for a in 3:
			if absf(v[a]) < 1e-6:
				if o[a] < lo[a] or o[a] > hi[a]:
					hit = false
					break
				continue
			var ta := (lo[a] - o[a]) / v[a]
			var tb := (hi[a] - o[a]) / v[a]
			t0 = maxf(t0, minf(ta, tb))
			t1 = minf(t1, maxf(ta, tb))
			if t0 > t1:
				hit = false
				break
		if hit:
			return true
	return false


func prompt() -> String:
	return "[E] %s THE BAY DOORS" % ("CLOSE" if want_open else "OPEN")


func _box(body: StaticBody3D, at: Vector3, size: Vector3, colour: Color) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = at
	body.add_child(cs)
	_mesh(body, at, size, colour)


func _mesh(parent: Node3D, at: Vector3, size: Vector3, colour: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.9
	mi.material_override = mat
	parent.add_child(mi)
