class_name Zambelli
extends Node3D
## The ice demo's resurfacer, a Zambelli 552 assembled from the hero props
## tools/propgen/zambelli.py writes (the body, the conditioner, its
## horizontal auger, the vertical auger, four wheels), with the parts that
## move posed from a few state vars, and the snow the blade makes
## simulated through the conditioner: the shavings land in the trough in
## front of the blade, the horizontal auger carries them to the middle,
## the vertical auger lifts them into the tank. With `show_body` off only
## the conditioner is drawn, with the vertical auger standing in a clear
## tube and a clear tank above it, so the snow's whole path is in view.
##
## The node's origin is the blade's cutting edge on the ice, in the middle
## of the conditioner, so a pass places the node at the cut line; the
## machine faces -Z, so a pass along +X turns it by -PI/2. Local +X is
## then the pass's +Z side.
##
##   var z := Zambelli.new()
##   add_child(z)
##   z.cond_down = true   # the conditioner eases down over COND_TRAVEL_S
##   z.speed = 2.0        # m/s, turns the wheels
##   z.auger_on = true    # the augers turn and carry snow
##   z.feed(bins)         # m³ of ice shaved under each bin across the blade

# the layout, as tools/propgen/zambelli_glb.py prints it, metres from the
# nose (the props come from the bought model, split there)
const BLADE_Z := 3.519
const BODY_Y0 := 0.084  # the body's bounding box starts here
const BODY_PIVOT_Z := 2.142  # the body's bounding box centre
const BODY_X0 := 0.035  # ... and its centre across, off the machine's
# the console, from tools/propgen/zambelli_lever.py: each control's prop, what
# it is, where it turns in this frame (its foot: a lever's shaft, a valve's
# post, the handwheel's column), the prop's offset from there, the axis it
# turns about, and its aim box
const CONSOLE: Array[Dictionary] = [
	{
		"id": "zambelli_lever",
		"kind": ZambelliControls.Kind.AUGER_H,
		"name": "HORIZONTAL AUGER",
		"foot": Vector3(-0.339, 1.660, 0.169),
		"offset": Vector3(0.0, 0.0, -0.008),
		"axis": "x",
		"aim": Vector3(0.05, 0.3, 0.16),
	},
	{
		"id": "zambelli_lever_cond",
		"kind": ZambelliControls.Kind.COND,
		"name": "CONDITIONER",
		"foot": Vector3(-0.285, 1.660, 0.180),
		"offset": Vector3(0.0, 0.0, -0.039),
		"axis": "x",
		"aim": Vector3(0.05, 0.3, 0.16),
	},
	{
		"id": "zambelli_lever",
		"kind": ZambelliControls.Kind.AUGER_V,
		"name": "VERTICAL AUGER",
		"foot": Vector3(-0.161, 1.660, 0.169),
		"offset": Vector3(0.0, 0.0, -0.008),
		"axis": "x",
		"aim": Vector3(0.05, 0.3, 0.16),
	},
	{
		"id": "zambelli_lever_cond",
		"kind": ZambelliControls.Kind.BIN,
		"name": "BIN",
		"foot": Vector3(-0.107, 1.660, 0.180),
		"offset": Vector3(0.0, 0.0, -0.039),
		"axis": "x",
		"aim": Vector3(0.05, 0.3, 0.16),
	},
	{
		"id": "zambelli_drive",
		"kind": ZambelliControls.Kind.DRIVE,
		"name": "DRIVE SELECT",
		"foot": Vector3(-0.341, 1.660, -0.155),
		"offset": Vector3(0.0, 0.0, 0.056),
		"axis": "x",
		"aim": Vector3(0.12, 0.24, 0.2),
	},
	{
		"id": "zambelli_stalk",  # the vertical auger's plunger: no mechanic yet
		"kind": -1,
		"name": "",
		"foot": Vector3(-0.014, 1.660, 0.180),
		"offset": Vector3.ZERO,
		"axis": "",
		"aim": Vector3.ZERO,
	},
	{
		"id": "zambelli_handwheel",
		"kind": ZambelliControls.Kind.BLADE,
		"name": "BLADE",
		"foot": Vector3(-0.038, 1.660, 0.495),
		"offset": Vector3(0.0, 0.0, 0.006),
		"axis": "y",
		"aim": Vector3(0.3, 0.3, 0.3),
	},
	{
		"id": "zambelli_valve_flood",
		"kind": ZambelliControls.Kind.FLOOD,
		"name": "FLOOD WATER",
		"foot": Vector3(-0.194, 1.660, 0.399),
		"offset": Vector3(-0.077, 0.0, 0.0),
		"axis": "y",
		"aim": Vector3(0.22, 0.4, 0.1),
	},
	{
		"id": "",
		"kind": ZambelliControls.Kind.SEAT,
		"name": "OPERATOR'S SEAT",
		"foot": Vector3(-0.5, 1.66, 0.66),
		"offset": Vector3.ZERO,
		"axis": "",
		"aim": Vector3(0.5, 0.5, 0.5),
	},
	{
		"id": "zambelli_valve_wash",
		"kind": ZambelliControls.Kind.WASH,
		"name": "WASH WATER",
		"foot": Vector3(0.123, 1.660, 0.399),
		"offset": Vector3(0.076, 0.0, 0.0),
		"axis": "y",
		"aim": Vector3(0.22, 0.4, 0.1),
	},
]
const COND_PIVOT_Z := 3.689  # the conditioner's bounding box centre
const FRONT_AXLE := 0.725
const REAR_AXLE := 2.765
const WHEEL_R := 0.341
const WHEEL_X := 0.755
const COND_Z0 := 3.069  # the conditioner's front wall
const AUGER_Z := 3.269
const AUGER_R := 0.15
const AUGER_L := 2.0
const COND_W := 2.308  # the conditioner's width, from the bought model
const COND_LEFT := 0.152  # the conditioner 6 in wider on the operator's left (Sean's ask): the corners
const BLADE_X0 := -COND_W / 2 - COND_LEFT  # the blade's and the pipe's left end
const BLADE_X1 := COND_W / 2  # ... and right end
const BLADE_W := COND_W + COND_LEFT
const COND_H := 0.42
const COND_LIFT := 0.12  # the conditioner's travel, up
const COND_TRAVEL_S := 5.5
const AUGER_RAD_S := 7.0
const AUGER_PITCH := 0.26  # metres a flight advances a turn
const LIFT_L := 1.2
const LIFT_R := 0.2
const LIFT_RAD_S := 9.0
# the snow
const BINS := 42  # across the blade, 5 cm each
const SNOW_EXPAND := 2.5  # shavings take this much more room than the ice they were
const LIFT_M3S := 0.012  # the vertical auger's capacity: a 1 mm cut at 2 m/s keeps up
const TANK_M3 := 2.5  # the snow tank
const TANK_SIZE := Vector3(1.6, 0.9, 1.2)  # the clear tank of the rig
const TANK_Y := 1.5  # its floor
const ROLL_R := 0.34  # the roll of snow round the auger grows to this
const MAX_SPEED := 3.5  # m/s driven, about a resurfacer's flat out
const ACCEL := 1.4  # m/s² with the pedal down
const BRAKE := 3.0  # m/s² on the brake
const COAST := 0.6  # m/s² rolling with the pedal up
const STEER_MAX := deg_to_rad(32.0)  # the front wheels' lock
const STEER_RATE := 1.6  # rad/s the wheels turn toward the lock
const WHEELBASE := REAR_AXLE - FRONT_AXLE
const SEAT := Vector3(-0.5, 1.23, 0.7)  # where the operator's feet go, seated at the wheel
# the flood water: a pipe along the top of the conditioner's back wall,
# holes every two and a half inches, the streams down the wall to the towel
const WALL_Z := 0.612  # just behind the back wall's rear face, from the blade
const PIPE_L := BLADE_W - 0.1
const PIPE_X0 := BLADE_X0 + 0.05
const SLUSH_EXPAND := 1.3  # wet shavings: the wash water turns the snow to slush, which packs down
const PIPE_R := 0.022
const PIPE_Y := 0.06  # the pipe's axis over the ice, at the bottom of the back wall
const STREAM_GAP := 0.0635
const TOWEL_Z := 0.66  # the towel lies from here to 0.78

static var _snow_mat: StandardMaterial3D
static var _clear_mat: StandardMaterial3D
static var _water_mat: StandardMaterial3D

var cond_down := true
var speed := 0.0
var auger_on := false  # the horizontal auger
var lift_on := false  # the vertical auger
var lift := 1.0  # 0 up, 1 down
var drive := 1  # 0 forward, 1 neutral, 2 reverse: the drive select lever
var bin_up := false  # the snow tank tipped up (it dumps on the way)
var blade_mm := -0.5  # the blade's edge from the conditioner's bottom: - cuts
var flood := 0.0  # the flood water valve, 0 closed to 1 wide open
var wash := 0.0  # the wash water valve
var controls: ZambelliControls
var steer := 0.0  # the front wheels' angle, + to the left
var hull: AnimatableBody3D
var console_pivots: Array[Node3D] = []  # the console's props, on their pivots (hidden for a body shot)
var show_body := false:
	set(v):
		show_body = v
		if is_inside_tree():
			_apply_body()
## m³ of snow under each bin of the blade, waiting for the auger
var trough := PackedFloat32Array()
## m³ of snow at the vertical auger's foot, waiting to go up
var pile_m3 := 0.0
## m³ of snow in the tank
var tank_m3 := 0.0
## m³/s going up the vertical auger right now
var lift_flow := 0.0

var _cond: Node3D
var _auger: Node3D
var _lift: Node3D
var _lift_rig: Node3D
var _body: Node3D
var _wheels: Array[Node3D] = []
var _snow: MeshInstance3D
var _pile: MeshInstance3D
var _tank_snow: MeshInstance3D
var _puffs: MultiMeshInstance3D
var _streams: MultiMeshInstance3D
var _snow_dirty := true
var _phase := 0.0
var _ripple := 0.0


func _ready() -> void:
	trough.resize(BINS)
	trough.fill(0.0)
	_body = Node3D.new()
	_body.name = "Body"
	var body := _part("zambelli_body")
	body.position = Vector3(BODY_X0, BODY_Y0, BODY_PIVOT_Z - BLADE_Z)
	_body.add_child(body)
	for z: float in [FRONT_AXLE, REAR_AXLE]:
		for x: float in [-WHEEL_X, WHEEL_X]:
			var hub := Node3D.new()
			hub.position = Vector3(x, WHEEL_R, z - BLADE_Z)
			var w := _part("zambelli_wheel")
			w.position = Vector3(0.0, -WHEEL_R, 0.0)
			hub.add_child(w)
			_body.add_child(hub)
			_wheels.append(hub)
	controls = ZambelliControls.new()
	controls.name = "Controls"
	controls.machine = self
	_body.add_child(controls)
	for c in CONSOLE:
		var pivot := Node3D.new()
		pivot.name = c.id if c.id != "" else "Seat"
		pivot.position = c.foot
		if c.id != "":
			var part := _part(c.id)
			part.position = c.offset
			pivot.add_child(part)
		else:
			pivot.name = "Seat"
		_body.add_child(pivot)
		console_pivots.append(pivot)
		if c.kind >= 0:
			var aim: Vector3 = c.aim
			controls.add_control(
				c.kind, c.name, pivot, c.axis, aim, Vector3(c.offset.x, aim.y / 2, c.offset.z)
			)
	add_child(_body)
	_cond = Node3D.new()
	_cond.name = "Conditioner"
	var cond := _part("zambelli_conditioner")
	cond.position = Vector3(-COND_LEFT / 2, 0.0, COND_PIVOT_Z - BLADE_Z)  # the prop is centred on itself
	_cond.add_child(cond)
	_make_flood(_cond)
	add_child(_cond)
	hull = _make_hull()
	add_child(hull)
	_auger = Node3D.new()
	var auger := _part("zambelli_auger")
	auger.position = Vector3(0.0, -AUGER_R - 0.01, 0.0)  # the shaft on the holder's origin
	_auger.add_child(auger)
	_auger.position = Vector3(0.0, AUGER_R + 0.01, AUGER_Z - BLADE_Z)
	add_child(_auger)
	_snow = MeshInstance3D.new()
	_snow.material_override = snow_material()
	_cond.add_child(_snow)
	_pile = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 12
	ball.rings = 6
	_pile.mesh = ball
	_pile.material_override = snow_material()
	_pile.visible = false
	_cond.add_child(_pile)
	_lift_rig = _make_rig()
	add_child(_lift_rig)
	_apply_body()


func _process(dt: float) -> void:
	var target := 1.0 if cond_down else 0.0
	lift = move_toward(lift, target, dt / COND_TRAVEL_S)
	_cond.position.y = COND_LIFT * (1.0 - lift)
	_auger.position.y = AUGER_R + 0.01 + COND_LIFT * (1.0 - lift)
	if auger_on:
		_auger.rotate_x(AUGER_RAD_S * dt)
	if lift_on:
		_lift.rotate_y(LIFT_RAD_S * dt)
	if auger_on or lift_on:
		_carry(dt)
	else:
		lift_flow = 0.0
	if speed != 0.0:
		for hub in _wheels:
			hub.rotate_x(-speed * dt / WHEEL_R)
	if _snow_dirty:
		_snow_dirty = false
		_draw_snow()
	_draw_puffs(dt)
	_draw_flood(dt)


## The blade's shavings this step: `ice_m3[b]` cubic metres of ice taken
## under bin `b` (0 at the -X end of the blade). They land in the trough
## as snow, SNOW_EXPAND times the room.
func feed(ice_m3: PackedFloat32Array) -> void:
	var n := mini(ice_m3.size(), BINS)
	var any := false
	for b in n:
		if ice_m3[b] > 0.0:
			trough[b] += ice_m3[b] * lerpf(SNOW_EXPAND, SLUSH_EXPAND, wash)
			any = true
	if any:
		_snow_dirty = true


## The augers at work for `dt`: each half of the horizontal auger walks
## its snow toward the middle at the flights' feed rate; what reaches the
## middle piles at the vertical auger's foot, which lifts LIFT_M3S of it a
## second into the tank while the tank has room. A deeper cut than the
## lift can take, or a full tank, grows the pile. Each auger only works
## with its lever on.
func _carry(dt: float) -> void:
	var feed_m := AUGER_RAD_S / TAU * AUGER_PITCH * dt  # metres the flights advance
	var bin_w := BLADE_W / BINS
	var frac := minf(feed_m / bin_w, 1.0) if auger_on else 0.0
	var half := BINS / 2
	var moved := false
	for b in half - 1:  # the -X half: bins step toward half - 1
		var m := trough[b] * frac
		if m > 0.0:
			trough[b] -= m
			trough[b + 1] += m
			moved = true
	for b in range(BINS - 1, half, -1):
		var m := trough[b] * frac
		if m > 0.0:
			trough[b] -= m
			trough[b - 1] += m
			moved = true
	for b: int in [half - 1, half]:
		var m := trough[b] * frac
		if m > 0.0:
			trough[b] -= m
			pile_m3 += m
			moved = true
	var up := minf(pile_m3, minf(LIFT_M3S * dt, TANK_M3 - tank_m3)) if lift_on else 0.0
	pile_m3 -= up
	tank_m3 += up
	lift_flow = up / dt if dt > 0.0 else 0.0
	if moved or up > 0.0:
		_snow_dirty = true


## m³ of snow in the trough, all bins.
func trough_m3() -> float:
	var s := 0.0
	for b in BINS:
		s += trough[b]
	return s


## The bin lever: tipping the tank up dumps it.
func set_bin(up: bool) -> void:
	bin_up = up
	if up:
		dump()


## Empties the tank (the dump at the end of the pass). Returns the m³.
func dump() -> float:
	var v := tank_m3
	tank_m3 = 0.0
	_snow_dirty = true
	return v


## Jumps the conditioner to where it is heading (a screenshot, a test).
func settle() -> void:
	lift = 1.0 if cond_down else 0.0
	_process(0.0)


## The conditioner is at the ice (its travel done) when this is true.
func is_down() -> bool:
	return cond_down and lift >= 0.999


func _apply_body() -> void:
	_body.visible = show_body
	_lift_rig.visible = not show_body


## The rig that stands in for the body: the vertical auger in a clear
## tube up from the middle of the conditioner, the clear tank above it on
## two posts, the snow level inside it.
func _make_rig() -> Node3D:
	var rig := Node3D.new()
	rig.name = "Rig"
	var zc := AUGER_Z - BLADE_Z
	_lift = Node3D.new()
	var screw := _part("zambelli_lift")
	# built along X with its pivot under the shaft; stood up, and shifted so
	# the shaft runs through the holder's origin (what the holder spins about)
	screw.rotation.z = PI / 2
	screw.position = Vector3(LIFT_R + 0.01, -LIFT_L / 2, 0.0)
	_lift.add_child(screw)
	_lift.position = Vector3(0.0, COND_H + LIFT_L / 2 + 0.05, zc)
	rig.add_child(_lift)
	var tube := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = LIFT_R + 0.03
	cyl.bottom_radius = LIFT_R + 0.03
	cyl.height = LIFT_L + 0.1
	cyl.radial_segments = 20
	tube.mesh = cyl
	tube.material_override = clear_material()
	tube.position = Vector3(0.0, COND_H + LIFT_L / 2 + 0.05, zc)
	rig.add_child(tube)
	var spout := MeshInstance3D.new()
	var sp := BoxMesh.new()
	sp.size = Vector3(0.3, 0.2, 0.5)
	spout.mesh = sp
	spout.material_override = clear_material()
	spout.position = Vector3(0.0, COND_H + LIFT_L + 0.1, zc - 0.3)
	rig.add_child(spout)
	var tank := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = TANK_SIZE
	tank.mesh = tb
	tank.material_override = clear_material()
	tank.position = Vector3(0.0, TANK_Y + TANK_SIZE.y / 2, zc - 0.5 - TANK_SIZE.z / 2)
	rig.add_child(tank)
	_tank_snow = MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(TANK_SIZE.x - 0.04, 1.0, TANK_SIZE.z - 0.04)
	_tank_snow.mesh = sb
	_tank_snow.material_override = snow_material()
	_tank_snow.visible = false
	rig.add_child(_tank_snow)
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.55, 0.56, 0.58)
	post_mat.roughness = 0.5
	for x: float in [-0.7, 0.7]:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.06, TANK_Y - COND_H, 0.06)
		post.mesh = pm
		post.material_override = post_mat
		post.position = Vector3(x, COND_H + (TANK_Y - COND_H) / 2, zc - 0.6)
		rig.add_child(post)
	_puffs = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var puff := SphereMesh.new()
	puff.radius = 0.035
	puff.height = 0.07
	puff.radial_segments = 6
	puff.rings = 3
	mm.mesh = puff
	mm.instance_count = 16
	mm.visible_instance_count = 0
	_puffs.multimesh = mm
	_puffs.material_override = snow_material()
	_puffs.position = Vector3(0.0, 0.0, zc)
	rig.add_child(_puffs)
	return rig


## The snow in the conditioner: a roll round the auger whose cross-section
## at each bin holds that bin's volume (a half-disc), the pile at the
## middle a mound, the tank's level a slab. The roll's mesh is rebuilt
## when the snow moves: BINS stations of seven vertices.
func _draw_snow() -> void:
	var bin_w := BLADE_W / BINS
	var zc := AUGER_Z - BLADE_Z
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 10
	var rows: Array[PackedVector3Array] = []
	for b in BINS + 1:
		var v := 0.0
		if b == 0:
			v = trough[0]
		elif b == BINS:
			v = trough[BINS - 1]
		else:
			v = (trough[b - 1] + trough[b]) * 0.5
		# the roll is round the auger: its flights show through a little
		# snow, more buries them
		var r := 0.0
		if v > 0.0:
			r = minf(AUGER_R + 0.04 + sqrt(2.0 * v / bin_w / PI), ROLL_R)
		var x := BLADE_X0 + b * bin_w
		var ring := PackedVector3Array()
		for k in segs + 1:  # round the auger's axis, cut off at the ice
			var a := PI - TAU * k / segs
			ring.append(Vector3(x, maxf(AUGER_R + 0.01 + r * sin(a), 0.01), zc + r * cos(a)))
		rows.append(ring)
	var any := false
	for b in BINS:
		for k in segs:
			var p0 := rows[b][k]
			var p1 := rows[b][k + 1]
			var p2 := rows[b + 1][k]
			var p3 := rows[b + 1][k + 1]
			if p0.y + p1.y + p2.y + p3.y <= 0.05:
				continue
			any = true
			for p: Vector3 in [p0, p1, p2, p2, p1, p3]:
				var out := Vector3(0.0, p.y - AUGER_R - 0.01, p.z - zc)
				st.set_normal(out.normalized() if out.length() > 0.001 else Vector3.UP)
				st.add_vertex(p)
	_snow.visible = any
	if any:
		_snow.mesh = st.commit()
	var pr := pow(3.0 * pile_m3 / TAU, 1.0 / 3.0) if pile_m3 > 0.0 else 0.0
	_pile.visible = pr > 0.01
	if _pile.visible:
		_pile.scale = Vector3(pr * 1.3, pr, pr * 1.1)
		_pile.position = Vector3(0.0, pr * 0.15, zc)
	var fill := tank_m3 / (TANK_SIZE.x * TANK_SIZE.z)
	_tank_snow.visible = fill > 0.005
	if _tank_snow.visible:
		var h := minf(fill, TANK_SIZE.y - 0.03)
		_tank_snow.scale = Vector3(1.0, h, 1.0)
		var zc_t := AUGER_Z - BLADE_Z - 0.5 - TANK_SIZE.z / 2
		_tank_snow.position = Vector3(0.0, TANK_Y + 0.02 + h / 2, zc_t)


## The snow going up the tube: puffs riding the flights, as many as the
## flow calls for, dropping into the tank's mouth at the top.
func _draw_puffs(dt: float) -> void:
	var mm := _puffs.multimesh
	var n := 0
	if lift_flow > 0.0:
		n = clampi(int(ceil(lift_flow / LIFT_M3S * 16.0)), 2, 16)
	mm.visible_instance_count = n
	if n == 0:
		return
	_phase = fmod(_phase + dt * LIFT_RAD_S / TAU * AUGER_PITCH / (LIFT_L + 0.5), 1.0)
	for i in n:
		var t := fmod(_phase + float(i) / 16.0, 1.0)
		var y := COND_H + 0.05 + t * (LIFT_L + 0.3)
		var pos: Vector3
		if y < COND_H + LIFT_L + 0.05:
			var a := t * 30.0
			pos = Vector3(cos(a) * (LIFT_R - 0.06), y, sin(a) * (LIFT_R - 0.06))
		else:
			pos = Vector3(0.0, COND_H + LIFT_L + 0.1, -(y - COND_H - LIFT_L - 0.05) * 2.5)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))


## The flood pipe and its water: the pipe on brackets along the top of
## the back wall, a stream from each hole down the wall's face, and the
## wet sheet they merge into on the way to the towel.
func _make_flood(parent: Node3D) -> void:
	var pipe_mat := StandardMaterial3D.new()
	pipe_mat.albedo_color = Color(0.72, 0.74, 0.77)
	pipe_mat.metallic = 0.5
	pipe_mat.roughness = 0.45
	var pipe := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = PIPE_R
	cyl.bottom_radius = PIPE_R
	cyl.height = PIPE_L + 0.06
	cyl.radial_segments = 16
	pipe.mesh = cyl
	pipe.material_override = pipe_mat
	pipe.rotation.z = PI / 2
	pipe.position = Vector3(PIPE_X0 + PIPE_L / 2, PIPE_Y, WALL_Z + PIPE_R)
	parent.add_child(pipe)
	for x: float in [PIPE_X0 - 0.01, PIPE_X0 + PIPE_L / 2, PIPE_X0 + PIPE_L + 0.01]:
		var br := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.03, 0.05, 0.05)
		br.mesh = bm
		br.material_override = pipe_mat
		br.position = Vector3(x, PIPE_Y + 0.01, WALL_Z + 0.012)
		parent.add_child(br)
	_streams = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var drop := CylinderMesh.new()
	drop.top_radius = 1.0
	drop.bottom_radius = 1.0
	drop.height = 1.0
	drop.radial_segments = 8
	mm.mesh = drop
	mm.instance_count = int(PIPE_L / STREAM_GAP) + 1
	mm.visible_instance_count = 0
	_streams.multimesh = mm
	_streams.material_override = water_material()
	parent.add_child(_streams)


## The streams for the valve's opening: as many holes as the pipe has,
## each a thread of water from the pipe to the towel, thicker and
## straighter the more the valve is open, a little waver in each; the
## sheet on the wall shows once they merge.
func _draw_flood(dt: float) -> void:
	var mm := _streams.multimesh
	if flood <= 0.0 or not cond_down:
		mm.visible_instance_count = 0
		return
	_ripple = fmod(_ripple + dt * 9.0, TAU)
	var n := mm.instance_count
	mm.visible_instance_count = n
	# each stream sprays down from the pipe's underside to the ice,
	# thicker and steadier the wider the valve
	var top := PIPE_Y - PIPE_R + 0.004
	var bottom := 0.002
	var r := 0.0025 + 0.005 * flood
	for i in n:
		var x := PIPE_X0 + i * STREAM_GAP
		var waver := 0.004 * sin(_ripple + i * 1.7) * (1.2 - flood)
		var h := top - bottom
		var t := Transform3D(
			Basis.IDENTITY.scaled(Vector3(r, h, r)),
			Vector3(x + waver, bottom + h / 2, WALL_Z + PIPE_R)
		)
		mm.set_instance_transform(i, t)


static func water_material() -> StandardMaterial3D:
	if _water_mat == null:
		_water_mat = StandardMaterial3D.new()
		_water_mat.albedo_color = Color(0.8, 0.9, 1.0, 0.6)
		_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_water_mat.roughness = 0.05
		_water_mat.metallic_specular = 0.9
		_water_mat.emission_enabled = true
		_water_mat.emission = Color(0.32, 0.42, 0.55)
		_water_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _water_mat


static func snow_material() -> StandardMaterial3D:
	if _snow_mat == null:
		_snow_mat = StandardMaterial3D.new()
		_snow_mat.albedo_color = Color(0.93, 0.94, 0.96)
		_snow_mat.roughness = 1.0
		_snow_mat.metallic_specular = 0.1
		_snow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		# snow stays bright in the trough's shadow: a little self-light
		_snow_mat.emission_enabled = true
		_snow_mat.emission = Color(0.42, 0.43, 0.46)
	return _snow_mat


static func clear_material() -> StandardMaterial3D:
	if _clear_mat == null:
		_clear_mat = StandardMaterial3D.new()
		_clear_mat.albedo_color = Color(0.7, 0.84, 0.95, 0.3)
		_clear_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_clear_mat.roughness = 0.1
		_clear_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _clear_mat


## The machine as something to walk into: boxes for the body and the
## conditioner on the props layer, moved with the machine each physics
## frame so it shoves a walker in its way.
func _make_hull() -> AnimatableBody3D:
	var h := AnimatableBody3D.new()
	h.name = "Hull"
	h.sync_to_physics = true
	h.collision_layer = Layers.bit(Layers.PROPS)
	h.collision_mask = 0
	for box: Array in [
		[Vector3(2.3, 2.2, 4.28), Vector3(0.0, BODY_Y0 + 1.1, BODY_PIVOT_Z - BLADE_Z)],
		[Vector3(BLADE_W, 0.5, 0.9), Vector3((BLADE_X0 + BLADE_X1) / 2, 0.25, 0.3)],
	]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = box[0]
		cs.shape = bs
		cs.position = box[1]
		h.add_child(cs)
	return h


## A frame of driving: `pedal` is the accelerator (0..1) and `brake`
## (0..1) from the operator, `turn` the wheel (-1 right .. +1 left); the
## drive select lever gives the direction. Moves the machine with a
## bicycle model pivoting on the rear axle and returns the blade's edge
## before and after, in the parent's frame, as [a0, a1, b0, b1] (the 0
## end at the blade's -X), or an empty array when it did not move.
func drive_step(dt: float, pedal: float, brake: float, turn: float) -> Array[Vector3]:
	var dir := 1.0 if drive == 0 else (-1.0 if drive == 2 else 0.0)
	var want := dir * pedal
	if want != 0.0 and signf(want) == signf(speed) or speed == 0.0:
		speed = move_toward(speed, want * MAX_SPEED, ACCEL * dt)
	else:
		speed = move_toward(speed, 0.0, BRAKE * dt)
	if brake > 0.0:
		speed = move_toward(speed, 0.0, BRAKE * brake * dt)
	elif pedal == 0.0:
		speed = move_toward(speed, 0.0, COAST * dt)
	steer = move_toward(steer, turn * STEER_MAX, STEER_RATE * dt)
	if absf(speed) < 0.001:
		speed = 0.0
		return []
	var a0 := to_global(Vector3(BLADE_X0, 0.0, 0.0))
	var a1 := to_global(Vector3(BLADE_X1, 0.0, 0.0))
	var fwd := -global_transform.basis.z
	var rear := global_position + fwd * (BLADE_Z - REAR_AXLE)
	var ds := speed * dt
	rear += fwd * ds
	if steer != 0.0:
		rotate_y(ds / WHEELBASE * tan(steer))
	fwd = -global_transform.basis.z
	global_position = rear - fwd * (BLADE_Z - REAR_AXLE)
	var b0 := to_global(Vector3(BLADE_X0, 0.0, 0.0))
	var b1 := to_global(Vector3(BLADE_X1, 0.0, 0.0))
	return [a0, a1, b0, b1]


func _part(id: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ObjectCatalog.mesh(id)
	mi.material_override = PropMaterial.shared()
	mi.name = id
	return mi
