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

# the layout, as tools/propgen/zambelli.py has it, metres from the nose
const BLADE_Z := 3.80
const BODY_Y0 := 0.26  # the body's bounding box starts here (the axle knuckles)
const BODY_PIVOT_Z := 1.82  # the body's bounding box centre
const FRONT_AXLE := 0.80
const REAR_AXLE := 2.75
const WHEEL_R := 0.38
const WHEEL_X := 0.86
const COND_Z0 := 3.35  # the conditioner's front wall
const AUGER_Z := 3.55
const AUGER_R := 0.15
const AUGER_L := 2.0
const COND_H := 0.36
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

static var _snow_mat: StandardMaterial3D
static var _clear_mat: StandardMaterial3D

var cond_down := true
var speed := 0.0
var auger_on := false
var lift := 1.0  # 0 up, 1 down
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
var _snow_dirty := true
var _phase := 0.0


func _ready() -> void:
	trough.resize(BINS)
	trough.fill(0.0)
	_body = Node3D.new()
	_body.name = "Body"
	var body := _part("zambelli_body")
	body.position = Vector3(0.0, BODY_Y0, BODY_PIVOT_Z - BLADE_Z)
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
	add_child(_body)
	_cond = Node3D.new()
	_cond.name = "Conditioner"
	_cond.add_child(_part("zambelli_conditioner"))
	add_child(_cond)
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
		_lift.rotate_y(LIFT_RAD_S * dt)
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


## The blade's shavings this step: `ice_m3[b]` cubic metres of ice taken
## under bin `b` (0 at the -X end of the blade). They land in the trough
## as snow, SNOW_EXPAND times the room.
func feed(ice_m3: PackedFloat32Array) -> void:
	var n := mini(ice_m3.size(), BINS)
	var any := false
	for b in n:
		if ice_m3[b] > 0.0:
			trough[b] += ice_m3[b] * SNOW_EXPAND
			any = true
	if any:
		_snow_dirty = true


## The augers at work for `dt`: each half of the horizontal auger walks
## its snow toward the middle at the flights' feed rate; what reaches the
## middle piles at the vertical auger's foot, which lifts LIFT_M3S of it a
## second into the tank while the tank has room. A deeper cut than the
## lift can take, or a full tank, grows the pile.
func _carry(dt: float) -> void:
	var feed_m := AUGER_RAD_S / TAU * AUGER_PITCH * dt  # metres the flights advance
	var bin_w := AUGER_L / BINS
	var frac := minf(feed_m / bin_w, 1.0)
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
	var up := minf(pile_m3, minf(LIFT_M3S * dt, TANK_M3 - tank_m3))
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
	var bin_w := AUGER_L / BINS
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
		var x := -AUGER_L / 2 + b * bin_w
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


func _part(id: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ObjectCatalog.mesh(id)
	mi.material_override = PropMaterial.shared()
	mi.name = id
	return mi
