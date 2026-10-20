class_name DorisModel
extends Node3D
## Doris as a working machine: a Zambelli 552 Electric, one for one with the
## real ice resurfacer of that layout (the reference and the control spec:
## Sean's /playtest/zamboni-552/SPEC.md, summarised in docs/world/ICE.md 4).
## Voxel body panels at the character voxel size; the controls, gauges and
## decals in fine voxels so they read from the seat.
##
## Model space (the same as before): front faces -Z, origin at the pivot
## 0.75 m ahead of the rear axle, the driver sits at the left rear (-X, +Z)
## behind the snow tank. Every part the driver or a mechanic moves is its own
## node, posed by apply() from the state vars below:
##
##   var d := DorisModel.new(Wear.WORN)
##   d.gear = 1; d.cond_down = true; d.flood = 0.65
##   d.tick(dt)        # eases the conditioner, the bin and the hatch
##   d.apply()         # poses every part
##
## Parts (see CONTROLS for the ones the driver works, by id):
##   steering wheel, accelerator and brake pedals, the F/N/R shifter in its
##   gated plate, the vertical and horizontal auger levers, the conditioner
##   lever, the bin lever, the flood and wash T-handle valves, the vertical
##   auger plunger, the blade level wheel, the wash pump rocker and the key on
##   the dash, the speed and charge gauges and the LCD; the snow tank (bin)
##   that tilts up to dump, its dump door, the conditioner on its lift, the
##   towel, the standpipe fill cap, and the service hatch on the right side
##   that opens onto her motor bay (the repair mini games work through it).
##
## Decals read ZAMBELLI: the in-world brand, an original wordmark (a slanted
## block face with a snowflake and an underline stroke), not the real one.

const V := Models.V           # 0.065 m: the body panels
const FINE := 0.016           # the controls and the dressing
const DECAL_V := 0.01         # the wordmark
const PX := 15                # pivot, body voxels (x: 30 wide, centred)
const PZ := 31                # pivot z: the nose is 31 voxels ahead of it
const AXLE_Z := 0.75          # the rear axle, model metres
## Where the driver's eye is, sitting in the seat.
const SEAT := Vector3(-0.55, 2.25, 1.12)
## The conditioner's travel, top to bottom (spec: about 5 to 6 s).
const COND_TRAVEL_S := 5.5
const COND_LIFT_M := 0.12
const BIN_TILT := 0.85        # radians, fully up
const BIN_TRAVEL_S := 3.0
const HATCH_SWING := 1.8
const HATCH_TRAVEL_S := 0.8
## The bin hinges at its front bottom edge; the hatch at its top edge.
const BIN_HINGE := Vector3(0.0, 11 * V, (1 - PZ) * V)
const DOOR_HINGE := Vector3(0.0, 21 * V, (0 - PZ) * V)
const HATCH_HINGE := Vector3((30 - PX) * V, 17 * V, 0.0)
## The service hatch opening, model metres (the motor bay behind it).
const HATCH_Z0 := (36 - PZ) * V
const HATCH_Z1 := (52 - PZ) * V
const HATCH_Y0 := 7 * V
const HATCH_Y1 := 17 * V

## The controls round the seat: [id, name, base (the part's pivot), grip
## (where the hand goes: what the crosshair picks), model metres].
const CONTROLS := [
	["gear", "FORWARD / NEUTRAL / REVERSE", Vector3(0.0, 1.495, 0.46), Vector3(0.0, 1.655, 0.46)],
	["auger_v", "VERTICAL AUGER", Vector3(0.07, 1.495, 0.68), Vector3(0.07, 1.685, 0.68)],
	["auger_h", "HORIZONTAL AUGER", Vector3(0.13, 1.495, 0.68), Vector3(0.13, 1.685, 0.68)],
	["conditioner", "CONDITIONER UP / DOWN", Vector3(0.21, 1.495, 0.68), Vector3(0.21, 1.685, 0.68)],
	["dump", "BIN UP / DOWN", Vector3(0.33, 1.495, 0.46), Vector3(0.33, 1.685, 0.46)],
	["valve", "FLOOD WATER", Vector3(0.17, 1.495, 0.95), Vector3(0.17, 1.625, 0.95)],
	["wash_valve", "WASH WATER", Vector3(0.88, 1.495, 0.62), Vector3(0.88, 1.625, 0.62)],
	["plunger", "VERTICAL AUGER PLUNGER", Vector3(0.40, 1.495, 0.74), Vector3(0.40, 1.945, 0.74)],
	["blade", "BLADE LEVEL WHEEL", Vector3(0.66, 1.495, 0.98), Vector3(0.66, 1.685, 0.98)],
	["wash", "WASH WATER PUMP", Vector3(-0.21, 1.505, 0.145), Vector3(-0.21, 1.505, 0.16)],
	["key", "KEY", Vector3(-0.12, 1.505, 0.145), Vector3(-0.12, 1.505, 0.16)],
	["fill", "STANDPIPE HOSE", Vector3(-0.86, 1.755, 0.06), Vector3(-0.86, 1.795, 0.06)],
	["towel", "TOWEL", Vector3(-0.87, 1.175, 1.2), Vector3(-0.89, 1.175, 1.2)],
]
## Parts that move but aren't picked: they follow the driving.
const STEER_AT := Vector3(-0.55, 1.725, 0.50)
const BRAKE_AT := Vector3(-0.78, 1.04, 0.50)
const ACCEL_AT := Vector3(-0.40, 1.04, 0.50)
const GAUGE_SPEED := Vector3(-0.80, 1.625, 0.132)
const GAUGE_CHARGE := Vector3(-0.30, 1.625, 0.132)
const LCD_AT := Vector3(-0.80, 1.405, 0.15)

## State. Set these, then apply() (tick() eases the slow ones).
var age: int = Wear.WORN
var steer := 0.0              # -1 full right .. 1 full left
var accel := 0.0              # pedal, 0..1
var brake := 0.0
var gear := 0                 # 1 forward, 0 neutral, -1 reverse
var auger_v := false
var auger_h := false
var cond_down := false        # the lever's ask; cond_pos follows it
var cond_pos := 0.0           # 0 up .. 1 down on the ice
var bin_up := false           # the bin lever's ask; bin_pos follows
var bin_pos := 0.0
var flood := 0.0              # T-handle, 0 shut .. 1 (90 deg back) open
var wash_valve := 0.0
var plunger := false          # held down
var blade_turns := 0.0        # turns of the wheel from the stop (clockwise = lower)
var wash_pump := false
var key_on := true
var fill_open := false
var towel_down := false
var hatch_open := 0.0         # 0 shut .. 1 swung up
var hatch_want := false
var speed := 0.0              # m/s, for the speedo
var charge := 0.85            # battery, 0..1

## Nodes: the body mesh is always the first child.
var body_mesh: MeshInstance3D
var lcd: Label3D
var bay_parts: Node3D         # the motor bay's contents behind the hatch
var _parts := {}              # id -> Node3D (the moving piece)
var _bin: Node3D
var _door: Node3D
var _cond: Node3D
var _towel: Node3D
var _hatch: Node3D
var _steer: Node3D
var _accel: Node3D
var _brake: Node3D
var _needle_speed: Node3D
var _needle_charge: Node3D
var _plunger_knob: Node3D

static var _cache := {}


func _init(age_: int = Wear.WORN) -> void:
	age = age_
	name = "Doris"
	add_to_group("doris_model")
	_build()
	apply()


# ---------------------------------------------------------------- the API

## The grip point of control `id`, model metres (Vector3.INF if unknown).
static func grip(id: String) -> Vector3:
	for c in CONTROLS:
		if c[0] == id:
			return c[3]
	return Vector3.INF


static func control_name(id: String) -> String:
	for c in CONTROLS:
		if c[0] == id:
			return c[1]
	return id.to_upper()


static func control_ids() -> Array:
	var out: Array = []
	for c in CONTROLS:
		out.append(c[0])
	return out


## The frame a repair mini game sits in when it plays through the hatch, in
## model space: its +Z runs into Doris (the job's view looks along +Z), its
## +X toward her rear, its origin on the floor 0.2 m out from the side panel
## level with the middle of the opening. JobScene.place_in() uses it.
static func hatch_frame() -> Transform3D:
	var b := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
	return Transform3D(b, Vector3((30 - PX) * V - 0.2, 0.0, (HATCH_Z0 + HATCH_Z1) * 0.5))


## Where to stand to open the hatch: outside her right side, model metres.
static func hatch_stand() -> Vector3:
	return Vector3((30 - PX) * V + 0.75, 0.0, (HATCH_Z0 + HATCH_Z1) * 0.5)


## Eases the conditioner and the bin toward what's asked.
func tick(dt: float) -> void:
	cond_pos = move_toward(cond_pos, 1.0 if cond_down else 0.0, dt / COND_TRAVEL_S)
	bin_pos = move_toward(bin_pos, 1.0 if bin_up else 0.0, dt / BIN_TRAVEL_S)


## A repair through the hatch (JobScene in place): the hatch swings up and
## her own motor bay makes way for the job's parts; false shuts it.
func open_for_service(on: bool) -> void:
	hatch_want = on
	if bay_parts:
		bay_parts.visible = not on


## The hatch swings on its own, parked in the bay or not.
func _process(dt: float) -> void:
	var want := 1.0 if hatch_want else 0.0
	if hatch_open != want:
		hatch_open = move_toward(hatch_open, want, dt / HATCH_TRAVEL_S)
		if _hatch:
			_hatch.rotation.z = hatch_open * HATCH_SWING


## Poses every moving part from the state.
func apply() -> void:
	if _steer:
		_steer.rotation.y = steer * 2.4
	if _accel:
		_accel.rotation.x = lerpf(0.55, 0.15, clampf(accel, 0.0, 1.0))
	if _brake:
		_brake.rotation.x = lerpf(0.55, 0.15, clampf(brake, 0.0, 1.0))
	_tilt("gear", -0.38 * float(gear))
	_tilt("auger_v", -0.4 if auger_v else 0.3)
	_tilt("auger_h", -0.4 if auger_h else 0.3)
	# the conditioner and bin levers are spring centred: pushed forward while
	# she rises, pulled back while she lowers, upright when she's there
	var cond_want := 1.0 if cond_down else 0.0
	_tilt("conditioner", 0.0 if absf(cond_pos - cond_want) < 0.001 else (0.45 if cond_down else -0.45))
	var bin_want := 1.0 if bin_up else 0.0
	_tilt("dump", 0.0 if absf(bin_pos - bin_want) < 0.001 else (-0.45 if bin_up else 0.45))
	_tilt("valve", clampf(flood, 0.0, 1.0) * PI * 0.5)
	_tilt("wash_valve", clampf(wash_valve, 0.0, 1.0) * PI * 0.5)
	if _plunger_knob:
		_plunger_knob.position.y = -0.08 if plunger else 0.0
	var bw: Node3D = _parts.get("blade")
	if bw:
		bw.rotation.y = -blade_turns * TAU
	_tilt("wash", 0.3 if wash_pump else -0.3)
	var k: Node3D = _parts.get("key")
	if k:
		k.rotation.z = -0.9 if key_on else 0.0
	var fc: Node3D = _parts.get("fill")
	if fc:
		fc.rotation.z = 1.4 if fill_open else 0.0
	var tw: Node3D = _parts.get("towel")
	if tw:
		tw.position.y = -0.1 if towel_down else 0.0
	if _needle_speed:
		_needle_speed.rotation.z = lerpf(2.2, -2.2, clampf(absf(speed) / 3.9, 0.0, 1.0))
	if _needle_charge:
		_needle_charge.rotation.z = lerpf(2.2, -2.2, clampf(charge, 0.0, 1.0))
	if _cond:
		_cond.position.y = (1.0 - cond_pos) * COND_LIFT_M
	if _towel:
		var on_ice := towel_down and cond_pos > 0.9
		_towel.rotation.x = 0.0 if on_ice else -1.25
	if _bin:
		_bin.rotation.x = -bin_pos * BIN_TILT
	if _door:
		_door.rotation.x = clampf((bin_pos - 0.15) / 0.5, 0.0, 1.0) * 1.2
	if _hatch:
		_hatch.rotation.z = hatch_open * HATCH_SWING


func _tilt(id: String, a: float) -> void:
	var p: Node3D = _parts.get(id)
	if p:
		p.rotation.x = a


## Every mesh in Doris: for the shadow setting and the tests.
func meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


# ---------------------------------------------------------------- build

func _build() -> void:
	body_mesh = _mi(_mesh("body", age), self)
	body_mesh.name = "Body"
	# the snow tank on its hinge, with its dump door
	_bin = _pivot(self, BIN_HINGE)
	_bin.name = "Bin"
	_mi(_mesh("bin", age), _bin).position = -BIN_HINGE
	_door = _pivot(_bin, DOOR_HINGE - BIN_HINGE)
	_door.name = "DumpDoor"
	_mi(_mesh("door", age), _door).position = -DOOR_HINGE
	for side in [-1, 1]:
		var dm := _mi(_decal_mesh(), _bin)
		dm.position = Vector3(side * ((30 - PX) * V + 0.002), 23.5 * V, -1.05) - BIN_HINGE
		dm.rotation.y = PI * 0.5 if side < 0 else -PI * 0.5
		dm.scale = Vector3(1.4, 1.4, 1.0)
	var front := _mi(_decal_mesh(), _bin)
	front.position = Vector3(0.0, 27.0 * V, (0 - PZ) * V - 0.012) - BIN_HINGE
	# the conditioner on its lift, the towel hanging off it
	_cond = _pivot(self, Vector3.ZERO)
	_cond.name = "Conditioner"
	_mi(_mesh("cond", age), _cond)
	var cd := _mi(_decal_mesh(), _cond)
	cd.position = Vector3(0.0, 5.0 * V, (61 - PZ) * V + 0.002)
	cd.rotation.y = PI
	cd.scale = Vector3(0.6, 0.6, 1.0)
	_towel = _pivot(_cond, Vector3(0.0, V, (61 - PZ) * V))
	_towel.name = "Towel"
	_mi(_mesh("towel", age), _towel).position = -Vector3(0.0, V, (61 - PZ) * V)
	# the service hatch and the motor bay behind it
	_hatch = _pivot(self, HATCH_HINGE)
	_hatch.name = "Hatch"
	_mi(_mesh("hatch", age), _hatch).position = -HATCH_HINGE
	bay_parts = Node3D.new()
	bay_parts.name = "MotorBay"
	add_child(bay_parts)
	_mi(_mesh("motor_bay", age), bay_parts)
	# the cockpit's fixed dressing (gates, bezels, columns), then the parts
	_mi(_mesh("dressing", age), self).name = "Dressing"
	_build_controls()


func _build_controls() -> void:
	for c in CONTROLS:
		var id: String = c[0]
		var base: Vector3 = c[2]
		var p := _pivot(self, base)
		p.name = "Ctl_" + id
		_parts[id] = p
		match id:
			"gear":
				_mi(_part_mesh("shift_lever"), p)
			"auger_v", "auger_h":
				_mi(_part_mesh("lever_black"), p)
			"conditioner":
				_mi(_part_mesh("lever_green"), p)
			"dump":
				_mi(_part_mesh("lever_amber"), p)
			"valve", "wash_valve":
				_mi(_part_mesh("t_handle"), p)
			"plunger":
				_mi(_part_mesh("plunger_rod"), p)
				_plunger_knob = _pivot(p, Vector3.ZERO)
				_mi(_part_mesh("plunger_knob"), _plunger_knob)
			"blade":
				_mi(_part_mesh("hand_wheel"), p).position.y = 0.19
			"wash":
				_mi(_part_mesh("rocker"), p)
			"key":
				_mi(_part_mesh("key"), p)
			"fill":
				_mi(_part_mesh("fill_cap"), p)
			"towel":
				_mi(_part_mesh("pull"), p)
	# the steering wheel, tilted to the driver
	var tilt := _pivot(self, STEER_AT)
	tilt.rotation.x = 0.6
	_steer = _pivot(tilt, Vector3.ZERO)
	_steer.name = "SteeringWheel"
	_mi(_part_mesh("steering_wheel"), _steer)
	_accel = _pivot(self, ACCEL_AT)
	_accel.name = "Accelerator"
	_mi(_part_mesh("pedal_long"), _accel)
	_brake = _pivot(self, BRAKE_AT)
	_brake.name = "Brake"
	_mi(_part_mesh("pedal_square"), _brake)
	_needle_speed = _pivot(self, GAUGE_SPEED + Vector3(0, 0, 0.03))
	_mi(_part_mesh("needle"), _needle_speed)
	_needle_charge = _pivot(self, GAUGE_CHARGE + Vector3(0, 0, 0.03))
	_mi(_part_mesh("needle"), _needle_charge)
	for g in [[GAUGE_SPEED, "KM/H"], [GAUGE_CHARGE, "CHARGE"]]:
		_label(str(g[1]), (g[0] as Vector3) + Vector3(0, -0.045, 0.035), 0.0006, Color("e8e4da"))
	lcd = _label("", LCD_AT, 0.0007, RinkOS.READOUT)
	lcd.name = "Dash"
	lcd.font = RinkOS.TERM_FONT
	_label("WASH  KEY", Vector3(-0.165, 1.55, 0.147), 0.0005, Color("e8e4da"))


func _label(text: String, at: Vector3, px: float, col: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = RinkOS.PIXEL_FONT
	l.font_size = 16
	l.pixel_size = px
	l.modulate = col
	l.shaded = false
	l.outline_size = 0
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.position = at
	add_child(l)
	return l


func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	parent.add_child(n)
	return n


func _mi(mesh: Mesh, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = Look.cast()
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------- meshes

static func _mesh(id: String, a: int) -> ArrayMesh:
	var key := "%s/%d" % [id, a]
	if not _cache.has(key):
		var m: VoxelModel = null
		match id:
			"body": m = Wear.weather(_body(a), a, 552)
			"bin": m = Wear.weather(_bin_model(a), a, 553)
			"door": m = _door_model(a)
			"cond": m = Wear.weather(_cond_model(a), a, 554)
			"towel": m = _towel_model(a)
			"hatch": m = _hatch_model(a)
			"motor_bay": m = _motor_bay(a)
			"dressing": m = _dressing(a)
		_cache[key] = m.build_mesh_merged() if id in ["body", "bin", "cond"] else m.build_mesh()
	return _cache[key]


static func _part_mesh(id: String) -> ArrayMesh:
	var key := "part/" + id
	if not _cache.has(key):
		_cache[key] = _part(id).build_mesh()
	return _cache[key]


static func _decal_mesh() -> ArrayMesh:
	if not _cache.has("decal"):
		_cache["decal"] = _decal().build_mesh()
	return _cache["decal"]


## The whole machine as one voxel model, parked: the bin down, the
## conditioner up, the hatch shut. Props' "resurfacer" (the bay prop, the
## blade-change diorama) is this.
static func static_model(a: int) -> VoxelModel:
	var m := _body(a)
	for part in [_bin_model(a), _door_model(a), _cond_model(a), _hatch_model(a)]:
		var pm: VoxelModel = part
		for p in pm.voxels:
			m.voxels[p] = pm.voxels[p]
	# the towel folded up on the conditioner
	m.box(1, 7, 57, 28, 1, 3, _towel_col(a))
	return m


# ---------------------------------------------------------------- colours

static func _paint(a: int) -> Color:
	return [Color("8a4b31"), Color("97543a"), Wear.NAVY][a]


static func _trim(a: int) -> Color:
	return Color("1c1d20") if a != Wear.RENOVATED else Color("15161a")


static func _towel_col(a: int) -> Color:
	return Wear.PAPER if a == Wear.RENOVATED else Wear.OLD_CREAM.darkened(0.25)


# ---------------------------------------------------------------- the body

static func _cyl_y(m: VoxelModel, cx: float, cz: float, y: int, h: int, r: float, c: Color) -> void:
	for x in range(int(floor(cx - r)), int(ceil(cx + r)) + 1):
		for z in range(int(floor(cz - r)), int(ceil(cz + r)) + 1):
			if Vector2(x + 0.5 - cx, z + 0.5 - cz).length() <= r:
				m.box(x, y, z, 1, h, 1, c)


## The chassis, the water tanks, the wheels, the cockpit (deck, dash, seat,
## control block, auger housing) and the right-hand motor box with its
## hatch opening. Voxel x 0..29 (left to right), z 0 nose .. 54 rear.
static func _body(a: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	m.jitter = 0.03
	var paint := _paint(a)
	var trim := _trim(a)
	var steel := Wear.OLD_STEEL if a == Wear.WORN else Wear.STEEL
	# the wheels: studded tyres, steel rims, set in wells
	for z0 in [8, 38]:
		for x0 in [1, 25]:
			m.box(x0, 1, z0, 4, 7, 9, Wear.RUBBER)
			m.box(x0, 0, z0 + 1, 4, 9, 7, Wear.RUBBER)
			var hx: int = x0 if x0 < 15 else x0 + 3
			m.box(hx, 3, z0 + 3, 1, 3, 3, steel)
			m.set_voxel(hx, 4, z0 + 4, trim)
	# the frame and the water tanks under everything
	m.box(5, 2, 4, 20, 4, 50, Wear.CHARCOAL)
	m.box(0, 5, 1, 30, 6, 54, paint)
	for z0 in [7, 37]:
		m.clear_box(0, 5, z0, 6, 5, 11)
		m.clear_box(24, 5, z0, 6, 5, 11)
		m.box(5, 5, z0, 1, 5, 11, trim)
		m.box(24, 5, z0, 1, 5, 11, trim)
		m.box(0, 10, z0, 6, 1, 11, trim)
		m.box(24, 10, z0, 6, 1, 11, trim)
	m.box(0, 5, 0, 30, 3, 1, trim)  # the front bumper
	m.box(0, 5, 54, 30, 6, 1, trim)  # the rear guard
	for x in [1, 27]:
		m.box(x, 8, 55, 2, 2, 1, Color("b3201c"))  # tail lamps
	# the cockpit sits up over the rear wheels: the body under it to y 15,
	# the deck's diamond plate on top, behind the tank, on the left
	m.box(0, 11, 30, 30, 5, 25, paint)
	for x in range(0, 14):
		for z in range(30, 54):
			m.set_voxel(x, 15, z, steel.darkened(0.15) if (x + z) % 3 == 0 else steel.darkened(0.3))
	m.box(-1, 6, 40, 1, 1, 4, steel)  # the driver's steps
	m.box(-1, 11, 40, 1, 1, 4, steel)
	# the dash on the tank's back wall, the gauge panel facing the driver
	m.box(0, 16, 30, 14, 11, 3, paint)
	m.box(0, 26, 32, 14, 1, 1, trim)
	m.box(1, 18, 32, 12, 7, 1, trim)
	# the seat on its box, and the grab rail on its left
	var seat := Wear.NAVY if a == Wear.RENOVATED else Color("2c2d31")
	m.box(2, 16, 45, 9, 3, 8, trim)
	m.box(2, 19, 44, 9, 2, 9, seat)
	m.box(2, 21, 52, 9, 9, 2, seat)
	m.box(3, 22, 52, 7, 7, 1, seat.lightened(0.06))
	m.box(0, 17, 46, 1, 1, 6, steel)
	m.box(0, 16, 46, 1, 1, 1, steel)
	m.box(0, 16, 51, 1, 1, 1, steel)
	if a == Wear.WORN:
		m.box(4, 21, 46, 2, 1, 2, Wear.OLD_CREAM.darkened(0.3))  # foam through the vinyl
	elif a == Wear.REPAIRED:
		m.box(5, 21, 47, 3, 1, 3, Wear.DUCT_TAPE)
	# the control block right of the seat
	m.box(14, 5, 37, 8, 18, 11, paint)
	m.box(14, 22, 37, 8, 1, 11, trim)
	# the auger housing: the round tower with the vertical auger in it
	_cyl_y(m, 17.5, 33.5, 16, 16, 4.2, paint)
	_cyl_y(m, 17.5, 33.5, 21, 1, 4.6, trim)
	_cyl_y(m, 17.5, 33.5, 27, 1, 4.6, trim)
	_cyl_y(m, 17.5, 33.5, 32, 2, 3.0, trim)
	_cyl_y(m, 17.5, 33.5, 34, 2, 1.8, Wear.CHARCOAL)  # the auger motor
	m.box(17, 36, 33, 1, 1, 1, steel)
	# the right-hand box: high by the tank, a shelf behind for the blade wheel
	m.box(22, 5, 30, 8, 22, 7, paint)
	m.box(22, 5, 37, 8, 18, 17, paint)
	m.box(22, 22, 37, 8, 1, 17, trim)
	m.box(22, 26, 30, 8, 1, 7, trim)
	# the blue work lamp on the right side, the amber beacon on the high box
	m.box(30, 12, 32, 1, 2, 2, Color("3a7bd5"))
	m.box(26, 27, 32, 1, 1, 1, trim)
	m.set_voxel(26, 28, 32, Color("e08a1e") if a != Wear.RENOVATED else Wear.LED)
	# the motor bay behind the hatch: a dark box (the hatch is its own part)
	m.clear_box(23, 7, 36, 7, 10, 16)
	m.box(22, 6, 35, 1, 12, 18, Wear.CHARCOAL)
	m.box(23, 6, 36, 7, 1, 16, Wear.CHARCOAL)
	m.box(23, 7, 35, 7, 10, 1, Wear.CHARCOAL)
	m.box(23, 7, 52, 7, 10, 1, Wear.CHARCOAL)
	# the side panels' seams and the step on the left
	for z in [16, 30]:
		m.box(0, 5, z, 1, 6, 1, paint.darkened(0.18))
		m.box(29, 5, z, 1, 6, 1, paint.darkened(0.18))
	if a == Wear.WORN:
		Wear.rust(m, paint, 0.03, 552)
		Wear.rust(m, steel, 0.12, 553)
	return m.set_pivot(PX, 0, PZ)


## The snow tank: the tall box ahead of the driver, tilting up on its front
## hinge to dump. Lid, raked top edges, the side strake, headlamps, the
## fill ports.
static func _bin_model(a: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	m.jitter = 0.03
	var paint := _paint(a)
	var trim := _trim(a)
	m.box(0, 11, 1, 30, 20, 29, paint)
	# rounded top edges and a raked nose top
	m.clear_box(0, 30, 1, 1, 1, 29)
	m.clear_box(29, 30, 1, 1, 1, 29)
	m.clear_box(0, 30, 1, 30, 1, 2)
	m.clear_box(0, 29, 1, 30, 1, 1)
	# the lid with its seams and the two fill ports
	m.box(1, 31, 4, 28, 1, 24, paint.darkened(0.1))
	m.box(1, 31, 15, 28, 1, 1, trim)
	m.box(6, 32, 8, 3, 1, 3, Color("2f5eb0"))
	m.box(21, 32, 8, 3, 1, 3, Color("2f5eb0"))
	# the black decal band the wordmark sits on, both sides
	for x in [0, 29]:
		m.box(x, 21, 3, 1, 5, 25, trim)
		# the strake: a raised crease running down to the front
		for z in range(3, 28):
			var y := 28 - int((27 - z) * 0.18)
			m.set_voxel(x, y, z, paint.lightened(0.08))
	# headlamps either side of the dump door, the door frame
	var lamp := Wear.LED if a == Wear.RENOVATED else Wear.SODIUM
	m.box(1, 23, 0, 4, 2, 1, lamp)
	m.box(25, 23, 0, 4, 2, 1, lamp)
	m.box(1, 21, 0, 28, 1, 1, trim)
	m.box(8, 25, 0, 14, 4, 1, trim)  # the front decal panel
	return m.set_pivot(PX, 0, PZ)


## The dump door at the bottom of the tank's front.
static func _door_model(a: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var paint := _paint(a)
	m.box(2, 12, 0, 26, 9, 1, paint.darkened(0.06))
	m.box(2, 12, 0, 26, 1, 1, _trim(a))
	for x in [5, 24]:
		m.box(x, 14, -1, 1, 5, 1, Wear.OLD_STEEL)  # the latches
	return m.set_pivot(PX, 0, PZ)


## The conditioner: the box behind the rear wheels that carries the blade,
## the horizontal auger, the wash bar and the flood pipe, on its lift arms.
static func _cond_model(a: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	m.jitter = 0.03
	var trim := _trim(a)
	var steel := Wear.OLD_STEEL if a == Wear.WORN else Wear.STEEL
	m.box(-1, 1, 55, 32, 5, 6, Wear.CHARCOAL)
	m.box(-1, 6, 55, 32, 1, 6, steel.darkened(0.2))
	m.box(-1, 0, 55, 1, 1, 6, steel)   # the runners
	m.box(30, 0, 55, 1, 1, 6, steel)
	m.box(0, 0, 58, 30, 1, 1, Wear.STEEL)  # the blade's edge
	m.box(0, 0, 60, 30, 1, 1, Wear.RUBBER)  # the squeegee
	m.box(0, 2, 61, 30, 1, 1, Color("6f7d86"))  # the flood pipe
	for x in [6, 22]:
		m.box(x, 6, 52, 2, 4, 3, steel)  # lift arms
	m.box(13, 6, 53, 4, 3, 2, trim)  # the hydraulic cylinder
	return m.set_pivot(PX, 0, PZ)


## The towel: a heavy cloth dragged flat behind the conditioner. Pivot at
## its front edge.
static func _towel_model(a: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var c := _towel_col(a)
	m.box(1, 0, 61, 28, 1, 9, c)
	for x in range(2, 28, 4):
		m.set_voxel(x, 0, 69, c.darkened(0.15))
	return m.set_pivot(PX, 0, PZ)


## The service hatch on the right side, hinged at its top edge.
static func _hatch_model(a: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var paint := _paint(a)
	m.box(29, 7, 36, 1, 10, 16, paint.darkened(0.04))
	for y in [9, 11, 13]:
		m.box(30, y, 39, 1, 1, 9, paint.darkened(0.25))  # louvres
	m.box(30, 15, 50, 1, 1, 1, Wear.OLD_STEEL)  # the latch
	m.box(30, 16, 37, 1, 1, 14, _trim(a))  # the hinge
	return m.set_pivot(PX, 0, PZ)


## What the hatch shows: the drive motor, its controller, the contactor
## board and the cables. Fine voxels, model metres.
static func _motor_bay(a: int) -> VoxelModel:
	var m := VoxelModel.new(0.02)
	m.jitter = 0.03
	var x0 := int(round(((22 + 1) - PX) * V / 0.02))
	var y0 := int(round(7 * V / 0.02))
	var z0 := int(round((36 - PZ) * V / 0.02))
	# the motor: a drum lying fore and aft, its end bell and the drive belt
	for z in range(z0 + 4, z0 + 30):
		for x in range(x0 + 2, x0 + 20):
			for y in range(y0, y0 + 18):
				if Vector2(x + 0.5 - (x0 + 11), y + 0.5 - (y0 + 9)).length() <= 8.5:
					m.set_voxel(x, y, z, Color("3b4a58") if z % 6 != 0 else Color("2c3742"))
	m.box(x0 + 6, y0 + 4, z0 + 30, 10, 10, 2, Wear.OLD_STEEL)
	# the controller and its fins, the contactor board with its red buttons
	m.box(x0 + 2, y0 + 20, z0 + 4, 18, 10, 18, Wear.CHARCOAL)
	for z in range(z0 + 5, z0 + 21, 3):
		m.box(x0 + 20, y0 + 21, z, 1, 8, 1, Wear.OLD_STEEL)
	m.box(x0 + 2, y0 + 2, z0 + 36, 18, 26, 2, Color("33373c"))
	for k in 3:
		m.box(x0 + 6 + k * 5, y0 + 18, z0 + 35, 2, 2, 1, Color("c22a24"))
	# the battery cables: thick, one red one black, down into the tray
	m.box(x0 + 8, y0 + 18, z0 + 22, 2, 2, 14, Color("b02a20"))
	m.box(x0 + 12, y0 + 18, z0 + 22, 2, 2, 14, Wear.RUBBER)
	m.box(x0 + 3, y0 + 30, z0 + 8, 6, 1, 4, Wear.PAPER)  # a SERVICE tag
	if a == Wear.WORN:
		m.box(x0 + 4, y0, z0 + 2, 16, 1, 40, Color("3a2e22"))  # grime in the tray
	return m


# ---------------------------------------------------------------- dressing

static func _fbox(m: VoxelModel, at: Vector3, sx: int, sy: int, sz: int, c: Color) -> void:
	m.box(int(round(at.x / FINE - sx * 0.5)), int(round(at.y / FINE)), int(round(at.z / FINE - sz * 0.5)), sx, sy, sz, c)


static func _fdisc_z(m: VoxelModel, at: Vector3, r: float, c: Color, depth := 1) -> void:
	var cx := at.x / FINE
	var cy := at.y / FINE
	var z := int(round(at.z / FINE))
	for x in range(int(floor(cx - r)), int(ceil(cx + r)) + 1):
		for y in range(int(floor(cy - r)), int(ceil(cy + r)) + 1):
			if Vector2(x + 0.5 - cx, y + 0.5 - cy).length() <= r:
				m.box(x, y, z, 1, 1, depth, c)


## The cockpit's fixed fine parts: the shift gate, the lever boots, the
## gauge bezels, the steering and blade wheel columns, the valve bodies.
static func _dressing(a: int) -> VoxelModel:
	var m := VoxelModel.new(FINE)
	m.jitter = 0.03
	var chrome := Color("c3c9ce")
	var black := Color("141518")
	# the shift gate: a black plate with its slot and F N R stamped beside
	_fbox(m, Vector3(0.0, 1.495, 0.46), 6, 1, 12, black)
	_fbox(m, Vector3(0.0, 1.511, 0.46), 1, 1, 9, Color("050506"))
	for i in 3:
		_fbox(m, Vector3(0.03, 1.511, 0.40 + i * 0.06), 1, 1, 1, Wear.PAPER)
	# boots for the four levers, the plunger guide, the valve bodies
	for id in ["auger_v", "auger_h", "conditioner", "dump"]:
		_fbox(m, grip(id) * Vector3(1, 0, 1) + Vector3(0, 1.495, 0), 3, 1, 3, black)
	_fbox(m, Vector3(0.40, 1.495, 0.74), 3, 2, 3, chrome)
	for id in ["valve", "wash_valve"]:
		_fbox(m, grip(id) * Vector3(1, 0, 1) + Vector3(0, 1.495, 0), 4, 2, 4, Color("8a8f94"))
	# a label plate for the lever bank: the four in a row, stencilled
	_fbox(m, Vector3(0.14, 1.495, 0.60), 14, 1, 3, Wear.PAPER.darkened(0.1))
	# the blade wheel's column and its plate
	_fbox(m, Vector3(0.66, 1.495, 0.98), 2, 12, 2, Color("3a3b3e"))
	_fbox(m, Vector3(0.66, 1.495, 0.98), 6, 1, 6, Wear.PAPER.darkened(0.15))
	# the gauge bezels and faces
	for g: Vector3 in [GAUGE_SPEED, GAUGE_CHARGE]:
		_fdisc_z(m, g, 3.6, chrome)
		_fdisc_z(m, g + Vector3(0, 0, FINE), 3.0, Color("0d0e10"))
		var cx := g.x / FINE
		var cy := g.y / FINE
		for k in 7:
			var ang := lerpf(2.2, -2.2, k / 6.0) + PI * 0.5
			m.set_voxel(int(floor(cx + cos(ang) * 2.3)), int(floor(cy + sin(ang) * 2.3)), int(round(g.z / FINE)) + 1, Color("e8e4da"))
	# the LCD's window, the switch panel with its row of rockers
	_fbox(m, LCD_AT - Vector3(0, 0.02, 0.004), 10, 3, 1, Color("0b1a12"))
	_fbox(m, Vector3(-0.26, 1.475, 0.131), 14, 5, 1, black)
	for k in 3:
		_fbox(m, Vector3(-0.36 + k * 0.03, 1.49, 0.147), 1, 2, 1, Color("2a2b2e"))
	# the snowflake badge in the wheel's hub, the steering column
	var from := Vector3(-0.55, 1.375, 0.14)
	var to := STEER_AT - Vector3(0, 0.03, 0.03)
	for k in 14:
		var p := from.lerp(to, k / 13.0)
		_fbox(m, p, 2, 2, 2, black)
	# the hose fill cap's collar, the towel pull's bracket
	_fbox(m, Vector3(-0.86, 1.755, 0.06), 6, 1, 6, Color("8a8f94"))
	_fbox(m, Vector3(-0.855, 1.145, 1.2), 1, 4, 3, Color("8a8f94"))
	if a == Wear.WORN:
		_fbox(m, Vector3(0.24, 1.511, 0.88), 4, 1, 3, Color("3a2210"))  # a coffee ring of oil
	return m


# ---------------------------------------------------------------- the parts

## One moving part in fine voxels, pivot at its base (where it turns).
static func _part(id: String) -> VoxelModel:
	var m := VoxelModel.new(FINE)
	m.jitter = 0.02
	var black := Color("141518")
	var chrome := Color("c3c9ce")
	match id:
		"shift_lever":
			m.box(0, 0, 0, 1, 9, 1, chrome)
			m.box(-1, 9, -1, 3, 3, 3, black)
			m.set_voxel(0, 12, 0, black)
		"lever_black", "lever_green", "lever_amber":
			var knob: Color = {"lever_black": black, "lever_green": Color("2f8a3c"), "lever_amber": Color("d4a83a")}[id]
			m.box(0, 0, 0, 1, 9, 1, chrome)
			m.box(0, 9, -1, 1, 4, 2, knob)
			m.box(-1, 10, -1, 3, 2, 2, knob)
		"t_handle":
			m.box(0, 0, 0, 1, 7, 1, chrome)
			m.box(-4, 7, 0, 9, 1, 1, Color("c22a24"))
			m.box(-4, 8, 0, 2, 1, 1, Color("c22a24"))
			m.box(3, 8, 0, 2, 1, 1, Color("c22a24"))
		"plunger_rod":
			m.box(0, 0, 0, 1, 26, 1, Color("3a3b3e"))
		"plunger_knob":
			m.box(-1, 26, -1, 3, 4, 3, black)
			m.box(-2, 27, -1, 5, 2, 3, black)
			m.box(-1, 27, -2, 3, 2, 5, black)
		"hand_wheel":
			for k in 28:
				var ang := k * TAU / 28.0
				m.set_voxel(int(floor(cos(ang) * 8.5)), 0, int(floor(sin(ang) * 8.5)), black)
			for k in 4:
				var ang := k * PI * 0.5 + PI * 0.25
				for r in range(1, 8):
					m.set_voxel(int(floor(cos(ang) * r)), 0, int(floor(sin(ang) * r)), Color("3a3b3e"))
			m.box(-1, -1, -1, 2, 2, 2, Color("3a3b3e"))
			m.box(7, 1, 0, 1, 3, 1, black)  # the spinner knob
		"steering_wheel":
			for k in 40:
				var ang := k * TAU / 40.0
				m.set_voxel(int(floor(cos(ang) * 12.0)), 0, int(floor(sin(ang) * 12.0)), black)
				m.set_voxel(int(floor(cos(ang) * 12.0)), 1, int(floor(sin(ang) * 12.0)), black)
			for ang in [PI * 0.5, PI * 0.5 + TAU / 3.0, PI * 0.5 - TAU / 3.0]:
				for r in range(2, 12):
					m.set_voxel(int(floor(cos(ang) * r)), 0, int(floor(sin(ang) * r)), Color("2a2b2e"))
			m.box(-2, 0, -2, 4, 2, 4, Color("2a2b2e"))
			# the hub's snowflake, a six-armed star
			for ang in [0.0, PI / 3.0, 2.0 * PI / 3.0]:
				for r in [-1, 0, 1]:
					m.set_voxel(int(round(cos(ang) * r)), 2, int(round(sin(ang) * r)), Wear.PAPER)
			m.box(9, 1, -1, 2, 3, 2, black)  # the spinner knob
		"pedal_long":
			m.box(-3, 0, -14, 6, 1, 14, Color("2a2b2e"))
			for z in range(-13, 0, 2):
				m.box(-2, 1, z, 4, 1, 1, black)
		"pedal_square":
			m.box(-3, 0, -6, 6, 1, 6, Color("2a2b2e"))
			m.box(-2, 1, -5, 4, 1, 4, black)
			m.box(0, -3, -1, 1, 3, 1, chrome)
		"needle":
			m.box(0, 0, 0, 1, 3, 1, Color("e04a2a"))
		"rocker":
			m.box(-1, -1, 0, 2, 3, 1, black)
			m.box(-1, 1, 1, 2, 1, 1, Color("2f8a3c"))
		"key":
			m.box(-1, -1, 0, 2, 2, 1, Color("8a8f94"))
			m.box(0, -2, 1, 1, 4, 1, Wear.OLD_GOLD)
			m.box(-1, 2, 1, 3, 2, 1, Wear.OLD_GOLD)
		"fill_cap":
			m.box(-2, 0, -2, 5, 2, 5, Color("2f5eb0"))
			m.box(-1, 2, 0, 3, 1, 1, Color("2f5eb0").darkened(0.3))
		"pull":
			m.box(-1, -1, -1, 1, 2, 2, Color("8a8f94"))
			m.box(-2, -2, -2, 1, 4, 4, Color("d4a83a"))
	return m


# ---------------------------------------------------------------- the decal

## The ZAMBELLI wordmark (original to this game): a slanted heavy block face
## in cream on black, a red underline stroke rising to the right with a
## snowflake at its tail, ELECTRIC set small in amber beneath. Reads along
## -X facing -Z (Props.letters' convention); pivot at its centre.
const _WORD := {
	"Z": ["111111", "000011", "000110", "001100", "011000", "110000", "111111"],
	"A": ["011110", "110011", "110011", "111111", "110011", "110011", "110011"],
	"M": ["1100011", "1110111", "1111111", "1101011", "1100011", "1100011", "1100011"],
	"B": ["111110", "110011", "110011", "111110", "110011", "110011", "111110"],
	"E": ["111111", "110000", "110000", "111110", "110000", "110000", "111111"],
	"L": ["110000", "110000", "110000", "110000", "110000", "110000", "111111"],
	"I": ["11", "11", "11", "11", "11", "11", "11"],
}
const _SMALL := {
	"E": ["111", "100", "110", "100", "111"], "L": ["100", "100", "100", "100", "111"],
	"C": ["111", "100", "100", "100", "111"], "T": ["111", "010", "010", "010", "010"],
	"R": ["110", "101", "110", "101", "101"], "I": ["1", "1", "1", "1", "1"],
}


static func _decal() -> VoxelModel:
	var m := VoxelModel.new(DECAL_V)
	m.jitter = 0.0
	var cream := Color("f1e6c8")
	var red := Color("c8322a")
	var amber := Color("e0a530")
	var ink := Color("121214")
	# the backing plate
	var w := 70
	m.box(-(w + 6), -9, 1, w + 10, 21, 1, ink)
	# the wordmark, slanted: each row slides right a voxel per two rows up
	var x := 0
	for ch in "ZAMBELLI":
		var g: Array = _WORD[ch]
		var gw: int = (g[0] as String).length()
		for row in 7:
			var line: String = g[row]
			var shear := int((6 - row) * 0.5)
			for col in gw:
				if line[col] == "1":
					m.set_voxel(-(x + col + shear), 10 - row, 0, cream)
		x += gw + 1
	# the underline stroke rising to the right, the snowflake at its end
	for k in w:
		m.set_voxel(-k, 2 + int(k / 24.0), 0, red)
		m.set_voxel(-k, 1 + int(k / 24.0), 0, red)
	var sx := -(w + 1)
	for d in range(-3, 4):
		m.set_voxel(sx + d, 4, 0, cream)
		m.set_voxel(sx, 4 + d, 0, cream)
		if absi(d) <= 2:
			m.set_voxel(sx + d, 4 + d, 0, cream)
			m.set_voxel(sx + d, 4 - d, 0, cream)
	# ELECTRIC, small, under the stroke
	x = 10
	for ch in "ELECTRIC":
		var g2: Array = _SMALL[ch]
		var gw2: int = (g2[0] as String).length()
		for row in 5:
			var line2: String = g2[row]
			for col in gw2:
				if line2[col] == "1":
					m.set_voxel(-(x + col), -2 - row, 0, amber)
		x += gw2 + 1
	return m.set_pivot(-w * 0.5, 0, 0.5)
