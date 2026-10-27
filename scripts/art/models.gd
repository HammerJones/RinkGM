class_name Models
extends RefCounted
## Procedural voxel models that match the reference renders in art/reference/.
## All character parts share one voxel size so they read as one model.

const V := 0.065  # metres per voxel for people and sticks

const SKIN := Color("c99a72")
const CAGE := Color("c4c4c4")
const CAGE_DARK := Color("8d8d8d")
const BOOT := Color("151517")
const STEEL := Color("a3a9ae")
const GLOVE := Color("18181b")
const TAPE := Color("efece4")
const TAPE_DARK := Color("cbc6bc")
const PUCK := Color("121214")
const NET_RED := Color("d0202a")
const NET_WHITE := Color("efede6")


static func palette(team: int) -> Dictionary:
	if team == 0:
		return {
			"name": "RED", "ui": Color("ec3b40"),
			"jersey": Color("c8191e"), "jersey_dark": Color("97121a"),
			"stripe": Color("19191c"), "stripe2": Color("ece7dc"),
			"crest": Color("efeae0"), "crest_inner": Color("19191c"),
			"pants": Color("1c2033"), "helmet": Color("141416"),
			"sock": Color("c8191e"), "sock_stripe": Color("19191c"), "sock_stripe2": Color("ece7dc"),
			"shaft": Color("1b1b1e"), "band": Color("c8191e"), "band2": Color("ece7dc"),
			"pad": Color("ece6da"), "pad_band": Color("c8191e"), "glove": Color("19191c"),
		}
	return {
		"name": "BLUE", "ui": Color("4a8ae8"),
		"jersey": Color("1f4f9a"), "jersey_dark": Color("173b75"),
		"stripe": Color("d6a321"), "stripe2": Color("173b75"),
		"crest": Color("d6a321"), "crest_inner": Color("f2ead2"),
		"pants": Color("15203f"), "helmet": Color("2557a8"),
		"sock": Color("1f4f9a"), "sock_stripe": Color("d6a321"), "sock_stripe2": Color("15203f"),
		"shaft": Color("a8763e"), "band": Color("6e4220"), "band2": Color("a8763e"),
		"pad": Color("ece6da"), "pad_band": Color("1f4f9a"), "glove": Color("8d5b2c"),
	}


## A full palette from two club colours (career teams).
static func team_palette(team_name: String, primary: Color, secondary: Color) -> Dictionary:
	var dark := primary.darkened(0.25)
	var trim := Color("19191c") if secondary.get_luminance() > 0.5 else Color("ece7dc")
	return {
		"name": team_name, "ui": primary.lightened(0.15),
		"jersey": primary, "jersey_dark": dark,
		"stripe": secondary, "stripe2": trim,
		"crest": secondary, "crest_inner": trim,
		"pants": primary.darkened(0.6), "helmet": primary.darkened(0.45),
		"sock": primary, "sock_stripe": secondary, "sock_stripe2": trim,
		"shaft": Color("1b1b1e"), "band": primary, "band2": secondary,
		"pad": Color("ece6da"), "pad_band": primary, "glove": primary.darkened(0.5),
	}


## Leg from hip joint (pivot) down to the skate blade. Goalies get pads.
static func leg(p: Dictionary, goalie: bool) -> VoxelModel:
	var m := VoxelModel.new(V)
	if goalie:
		m.box(1, 0, -1, 1, 1, 6, STEEL)
		m.box(0, 1, -1, 3, 1, 5, BOOT)
		m.box(-1, 1, -1, 5, 11, 4, p.pad)
		for y in [3, 6, 9]:
			m.box(-1, y, -1, 5, 1, 1, p.pad_band)
			m.box(-1, y, -1, 1, 1, 4, p.pad_band)
			m.box(3, y, -1, 1, 1, 4, p.pad_band)
		m.box(0, 7, -2, 3, 2, 1, p.pad)  # knee roll
		m.set_pivot(1.5, 12, 1.5)
	else:
		m.box(1, 0, -1, 1, 1, 6, STEEL)
		m.box(0, 1, -1, 3, 2, 5, BOOT)
		m.box(0, 3, 0, 3, 6, 4, p.sock)
		m.box(0, 5, 0, 3, 1, 4, p.sock_stripe)
		m.box(0, 6, 0, 3, 1, 4, p.sock_stripe2)
		m.box(0, 7, 0, 3, 1, 4, p.sock_stripe)
		m.box(0, 9, 0, 3, 3, 4, p.pants)
		m.set_pivot(1.5, 12, 2)
	return m


## Body proportions (agreed with Animations, 2026-10-18), in voxels: a
## 1.85 m adult is 28 V on skates and 27 V in shoes. Limbs hang down their
## local -Y from the joint pivot, as SkaterRig expects.
const THIGH_V := 6.5
const SHIN_V := 6.0
const SKATE_V := 1.5
const SHOE_V := 0.5
const UPPER_ARM_V := 5.0
const FOREARM_V := 5.5     # forearm plus hand
const SHOULDERS_V := 11.0
const HIP_SKATE_V := THIGH_V + SHIN_V + SKATE_V   # 14
const HIP_SHOE_V := THIGH_V + SHIN_V + SHOE_V     # 13


## Skater thigh: pants leg and the top of the sock, hip joint to knee.
static func thigh(p: Dictionary) -> VoxelModel:
	var m := VoxelModel.new(V)
	m.box(0, 0, 0, 3, 2, 4, p.sock)
	m.box(0, 1, 0, 3, 1, 4, p.sock_stripe2)
	m.box(0, 2, 0, 3, 5, 4, p.pants)
	m.set_pivot(1.5, THIGH_V, 2)
	return m


## Skater shin and skate, knee down to the blade. The blade runs along z.
static func shin(p: Dictionary) -> VoxelModel:
	var m := VoxelModel.new(V)
	m.box(1, 0, -2, 1, 1, 6, STEEL)
	m.box(0, 1, -2, 3, 2, 5, BOOT)
	m.box(0, 3, 0, 3, 5, 4, p.sock)
	m.box(0, 5, 0, 3, 1, 4, p.sock_stripe)
	m.box(0, 7, 0, 3, 1, 4, p.sock_stripe)  # knee
	m.set_pivot(1.5, SHIN_V + SKATE_V, 2)
	return m


## The same shin in shoes, for people on foot: knee pivot, 6 V + a 0.5 V
## sole. `p.trousers` and `p.shoe` colour it when given.
static func shin_shoe(p: Dictionary) -> VoxelModel:
	var m := VoxelModel.new(V)
	var shoe: Color = p.get("shoe", BOOT)
	var leg: Color = p.get("trousers", p.pants)
	m.box(0, 0, -2, 3, 1, 5, shoe)
	m.box(0, 1, 0, 3, 6, 3, leg)
	m.set_pivot(1.5, SHIN_V + SHOE_V, 1.5)
	return m


## Skater upper arm (shoulder to elbow) and forearm with glove (elbow to hand).
static func upper_arm(p: Dictionary) -> VoxelModel:
	var m := VoxelModel.new(V)
	m.box(0, 0, 0, 3, 5, 3, p.jersey)
	m.box(0, 0, 0, 3, 1, 3, p.stripe)
	m.set_pivot(1.5, UPPER_ARM_V, 1.5)
	return m


static func forearm(p: Dictionary) -> VoxelModel:
	var m := VoxelModel.new(V)
	m.box(0, 3, 0, 3, 3, 3, p.jersey_dark)
	m.box(0, 0, 0, 3, 3, 3, GLOVE)
	m.box(0, 3, 0, 3, 1, 3, p.jersey_dark.darkened(0.4))  # cuff
	m.set_pivot(1.5, FOREARM_V, 1.5)
	return m


## Hockey pants. Pivot is at the hip joints.
static func pants(p: Dictionary, goalie: bool) -> VoxelModel:
	var m := VoxelModel.new(V)
	if goalie:
		m.box(0, 0, 0, 10, 4, 6, p.pants)
		m.box(0, 1, 0, 1, 2, 6, p.stripe)
		m.box(9, 1, 0, 1, 2, 6, p.stripe)
		m.set_pivot(5, 1, 3)
	else:
		m.box(0, 0, 0, 8, 4, 5, p.pants)
		m.box(0, 1, 0, 1, 2, 5, p.stripe)
		m.box(7, 1, 0, 1, 2, 5, p.stripe)
		m.set_pivot(4, 1, 2.5)
	return m


## Jersey with hem stripe, shoulder yoke, front crest and back number.
static func torso(p: Dictionary, goalie: bool) -> VoxelModel:
	var m := VoxelModel.new(V)
	if goalie:
		m.box(1, 0, 0, 10, 8, 6, p.jersey)
		m.box(0, 8, 0, 12, 2, 6, p.jersey)
		m.box(1, 1, 0, 10, 2, 6, p.stripe)
		m.box(0, 9, 0, 12, 1, 6, p.jersey_dark)
		m.box(4, 4, 0, 4, 4, 1, p.crest)
		m.box(5, 5, 0, 2, 2, 1, p.crest_inner)
		m.box(5, 4, 5, 2, 3, 1, p.crest)
		m.set_pivot(6, 0, 3)
	else:
		m.box(1, 0, 0, 9, 7, 5, p.jersey)
		m.box(0, 7, 0, 11, 2, 5, p.jersey)
		m.box(1, 1, 0, 9, 2, 5, p.stripe)
		m.box(0, 8, 0, 11, 1, 5, p.jersey_dark)
		m.box(3, 3, 0, 5, 4, 1, p.crest)
		m.box(4, 4, 0, 3, 2, 1, p.crest_inner)
		m.box(4, 3, 4, 3, 3, 1, p.crest)
		m.set_pivot(SHOULDERS_V * 0.5, 0, 2.5)
	return m


## Helmet with a cage over the face. Pivot at the neck.
static func head(p: Dictionary, goalie: bool) -> VoxelModel:
	var m := VoxelModel.new(V)
	if goalie:
		m.box(0, 0, 0, 6, 6, 6, p.helmet)
		m.box(1, 6, 1, 4, 1, 4, p.helmet)
		for x in range(1, 5):
			for y in range(0, 4):
				m.set_voxel(x, y, -1, CAGE if (x + y) % 2 == 0 else CAGE_DARK)
		m.set_pivot(3, 0, 3)
	else:
		m.box(1, 0, 1, 4, 3, 4, SKIN)
		m.box(0, 2, 0, 6, 4, 6, p.helmet)
		m.box(1, 6, 1, 4, 1, 4, p.helmet)
		for x in range(1, 5):
			for y in range(0, 3):
				m.set_voxel(x, y, 0, CAGE if (x + y) % 2 == 0 else SKIN)
		m.set_pivot(3, 0, 3)
	return m


## kind: "skater", "glove" (goalie catcher) or "blocker". Pivot at the shoulder.
static func arm(p: Dictionary, kind: String) -> VoxelModel:
	var m := VoxelModel.new(V)
	m.box(0, 3, 0, 3, 6, 3, p.jersey)
	m.box(0, 4, 0, 3, 1, 3, p.stripe)
	match kind:
		"glove":
			m.box(-1, -1, -1, 5, 5, 4, p.glove)
			m.box(0, 3, -1, 3, 1, 1, p.glove.darkened(0.25))
		"blocker":
			m.box(0, 0, 0, 3, 3, 3, GLOVE)
			m.box(3, -2, -1, 1, 7, 5, p.pad)
			m.box(3, 1, -1, 1, 1, 5, p.pad_band)
		_:
			m.box(0, 0, 0, 3, 3, 3, GLOVE)
	m.set_pivot(1.5, 9, 1.5)
	return m


## Stick with its heel at the origin, shaft along +Y and blade along +X.
static func stick(p: Dictionary, goalie: bool) -> VoxelModel:
	var m := VoxelModel.new(V)
	m.jitter = 0.06
	var length := 24
	var shaft: Color = p.pad if goalie else p.shaft
	for y in length:
		m.set_voxel(0, y, 0, shaft)
	# tape bands like the reference sticks
	for y in [10, 11, 14, 15]:
		m.set_voxel(0, y, 0, p.pad_band if goalie else p.band)
	for y in [12, 13]:
		m.set_voxel(0, y, 0, p.stripe if goalie else p.band2)
	m.box(0, length - 2, 0, 1, 2, 1, TAPE)
	if goalie:
		m.box(0, 1, 0, 2, 9, 1, p.pad)
		m.box(0, 4, 0, 2, 2, 1, p.pad_band)
		for x in range(0, 8):
			for y in range(0, 2):
				m.set_voxel(x, y, 0, TAPE if (x + y) % 2 == 0 else TAPE_DARK)
	else:
		for x in range(0, 6):
			for y in range(0, 2):
				m.set_voxel(x, y, 0, TAPE if (x + y) % 2 == 0 else TAPE_DARK)
	m.set_pivot(0.5, 0, 0.5)
	return m


## Skater stick, two parts on a finer grid so it reads as a real stick: the
## shaft (heel at the pivot, butt end up +Y) and the blade.
const STICK_V := 0.0175
const SHAFT_VOX := 84


static func shaft(p: Dictionary) -> VoxelModel:
	var m := VoxelModel.new(STICK_V)
	m.jitter = 0.03
	var top := SHAFT_VOX
	m.box(0, 0, 0, 2, top, 2, p.shaft)
	# tapered hosel down into the blade
	m.box(0, 0, 0, 2, 4, 2, p.shaft.darkened(0.15))
	# team graphics on the upper shaft
	m.box(0, top - 30, 0, 2, 3, 2, p.band)
	m.box(0, top - 27, 0, 2, 1, 2, p.band2)
	m.box(0, top - 26, 0, 2, 3, 2, p.band)
	# taped grip and knob at the butt end
	for y in range(top - 10, top):
		m.box(0, y, 0, 2, 1, 2, TAPE if y % 2 == 0 else TAPE_DARK)
	m.box(-1, top, -1, 4, 2, 4, TAPE)
	m.set_pivot(1, 0, 1)
	return m


## Blade lying along +X from heel to toe, +Z is the forehand face; the toe
## curves towards the forehand. Pivot is the middle of the blade on the ice,
## where the puck sits. The heel is a smooth curve up into a hosel at the
## stick's lie (an obtuse heel, about 133°), and the shaft starts where the
## hosel ends (`blade_heel`).
const BLADE_LIE_DEG := 47.0  # hosel angle off the ice
const BLADE_PIVOT := Vector3(8.5, 0, 0.5)
static var blade_heel := _heel_sweep(null, {})  # shaft joint, metres from the blade pivot


static func blade(p: Dictionary) -> VoxelModel:
	var m := VoxelModel.new(STICK_V)
	m.jitter = 0.03
	var length := 17
	for x in range(3, length):
		var bend := 0 if x < 10 else (1 if x < 14 else 2)
		var h := 4 if x < length - 2 else (3 if x == length - 2 else 2)
		for y in h:
			var c: Color = p.shaft
			if x < length - 1:
				c = TAPE if (x + y) % 2 == 0 else TAPE_DARK
			m.set_voxel(x, y, bend, c)
	_heel_sweep(m, p)
	m.set_pivot(BLADE_PIVOT.x, BLADE_PIVOT.y, BLADE_PIVOT.z)
	return m


## Sweeps the heel from the blade's back end round a curve and up the hosel,
## tapering from the blade's 4 x 1 section to the shaft's 2 x 2. Adds the
## pieces to `m` when given; returns the hosel's top in metres from the pivot.
static func _heel_sweep(m: VoxelModel, p: Dictionary) -> Vector3:
	const STEP := 0.25
	const RADIUS := 3.0
	const HOSEL := 4.5
	var lie := deg_to_rad(BLADE_LIE_DEG)
	var arc := RADIUS * lie
	var total := 0.75 + arc + HOSEL
	var pos := Vector2(2.75, 2.0)  # mid-height, just behind the blade's grid voxels
	var s := 0.0
	while s <= total:
		var turn := clampf((s - 0.75) / arc, 0.0, 1.0) * lie
		var dir := Vector2(-cos(turn), sin(turn))
		var k := clampf(s / total, 0.0, 1.0)
		if m:
			var h := lerpf(4.0, 2.0, k)
			var t := lerpf(1.0, 2.0, k)
			var tangent := Vector3(dir.x, dir.y, 0)
			var basis := Basis(tangent, Vector3.BACK.cross(tangent), Vector3.BACK)
			m.add_oriented(Vector3(pos.x, pos.y, 0.5), basis, Vector3(STEP * 2.0, h, t), p.shaft)
		pos += dir * STEP
		s += STEP
	return (Vector3(pos.x, pos.y, 0.5) - BLADE_PIVOT) * STICK_V


## The puck: drawn at twice regulation size (15.2 x 5.1 cm) so it reads at
## game camera distances (Sean, P13). Physics keeps the regulation 3 in x 1 in
## (Puck.RADIUS). Inch voxels, rounded. Pivot at the centre of its bottom face.
const PUCK_DIAMETER := 0.1524
const PUCK_HEIGHT := 0.0508
const _PUCK_V := 0.0254


static func puck() -> VoxelModel:
	var m := VoxelModel.new(_PUCK_V)
	m.jitter = 0.0
	for x in 6:
		for z in 6:
			if (x == 0 or x == 5) and (z == 0 or z == 5):
				continue  # corners off: round enough at this size
			for y in 2:
				m.set_voxel(x, y, z, PUCK)
	return m.set_pivot(3.0, 0, 3.0)


## Goal net, opening at z=0 facing -Z and depth going +Z. Pivot at the
## centre of the goal line. Posts are 1.83 m apart and 1.22 m tall.
static func net() -> VoxelModel:
	var m := VoxelModel.new(0.061)
	m.jitter = 0.03
	var w := 30
	var h := 20
	for y in h:
		m.set_voxel(0, y, 0, NET_RED)
		m.set_voxel(w, y, 0, NET_RED)
	for x in w + 1:
		m.set_voxel(x, h - 1, 0, NET_RED)
	# base frame on the ice
	for z in range(1, 19):
		m.set_voxel(0, 0, z, NET_WHITE)
		m.set_voxel(w, 0, z, NET_WHITE)
	for x in w + 1:
		m.set_voxel(x, 0, 18, NET_WHITE)
	# mesh: sides, slanted back and roof, every other voxel
	for y in range(1, h):
		var depth := int(18 - y * 0.5)
		for z in range(1, depth + 1):
			if (y + z) % 2 == 0:
				m.set_voxel(0, y, z, NET_WHITE)
				m.set_voxel(w, y, z, NET_WHITE)
		for x in range(1, w):
			if (x + y) % 2 == 0:
				m.set_voxel(x, y, depth, NET_WHITE)
	var top_depth := int(18 - (h - 1) * 0.5)
	for x in range(1, w):
		for z in range(1, top_depth):
			if (x + z) % 2 == 0:
				m.set_voxel(x, h - 1, z, NET_WHITE)
	return m.set_pivot(15.5, 0, 0.5)
