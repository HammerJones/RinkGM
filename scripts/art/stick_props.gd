class_name StickProps
extends RefCounted
## Real hockey sticks and everything that holds them (playtest notes #28, #35,
## #40), plus the pro shop's back-room kit (#34, #36): Bev's sharpener and
## the customer skate rack.
##
## Sticks are not props in the kit: each one is a StickProp (a light
## RigidBody3D that sleeps until something bumps it). This file builds their
## meshes and collision, picks variants (brand, colour, wood or composite,
## left or right curve, junior or senior, tape job), and places them in
## racks. The racks and the back-room kit are ordinary static voxel props
## (Props.IDS, three ages, shape-following collision) built here.
##
##   var v := StickProps.variant("warlock", 1, false, "black")
##   var mesh := StickProps.stick_mesh(v)          # cached, share it freely
##   StickProps.fill(k, room, "stick_rack_wall", pos, rot, variants, physics)
##
## Stick space: the shaft runs up +Y from the heel (the origin) to the butt;
## the blade leaves the heel at the stick's lie, toward +X and down, and its
## toe curves toward +Z for a left-handed curve (`hand` 1) or -Z (`hand` -1).

const V := Models.V
const SV := Models.STICK_V

## Static voxel props (Props.IDS lists these too).
const IDS := [
	"stick_rack_wall", "stick_rack_shop", "stick_rack_aframe", "stick_barrel", "stick_rack_team",
	"skate_sharpener", "skate_rack_tags", "tape_tower", "foot_measure", "shop_till", "puck_bin",
]

## Racks collide voxel for voxel, so the slots between dividers stay open.
const COLLISION_CELL := {
	"stick_rack_wall": 1, "stick_rack_shop": 1, "stick_rack_aframe": 1, "stick_barrel": 1,
	"stick_rack_team": 1, "skate_rack_tags": 1,
}

## Big flat machines merge their faces even at full detail.
const MERGED := ["skate_sharpener"]

# ---------------------------------------------------------------- stick models

## Stock lines from docs/world/PROSHOP.md, coloured from the brand logos in
## docs/world/LORE.md. "team" takes its colours from the variant.
const MODELS := {
	"shorewood": {"brand": "Shorewood", "line": "Lumberjack", "wood": true,
		"shaft": Color("d9b98a"), "band": Color("7b4a26"), "label": Color("2f5d50"), "blade": Color("c9a46a")},
	"shorewood_1952": {"brand": "Shorewood", "line": "1952", "wood": true,
		"shaft": Color("a8743f"), "band": Color("e8dcc0"), "label": Color("7b4a26"), "blade": Color("8a5a30")},
	"honest": {"brand": "Honest Hockey Co.", "line": "HC Standard", "wood": false,
		"shaft": Color("1d2b4f"), "band": Color("f5f1e6"), "label": Color("c9a66b")},
	"honest_plus": {"brand": "Honest Hockey Co.", "line": "HC Plus", "wood": false,
		"shaft": Color("c9a66b"), "band": Color("1d2b4f"), "label": Color("f5f1e6")},
	"kodiak": {"brand": "Kodiak", "line": "Trapper", "wood": false,
		"shaft": Color("1b1b1e"), "band": Color("a3262a"), "label": Color("e8dcc0")},
	"kodiak_grizzly": {"brand": "Kodiak", "line": "Grizzly Classic", "wood": false,
		"shaft": Color("5b3a1e"), "band": Color("e8dcc0"), "label": Color("a3262a")},
	"warlock": {"brand": "Warlock", "line": "HEX", "wood": false,
		"shaft": Color("121212"), "band": Color("9be22d"), "label": Color("6a1b9a")},
	"warlock_coven": {"brand": "Warlock", "line": "COVEN PRO", "wood": false,
		"shaft": Color("121212"), "band": Color("6a1b9a"), "label": Color("9be22d")},
	"warlock_necro": {"brand": "Warlock", "line": "NECRO-X ULTRALIGHT", "wood": false,
		"shaft": Color("4a1470"), "band": Color("121212"), "label": Color("9be22d")},
	"team": {"brand": "", "line": "team stick", "wood": false,
		"shaft": Color("1b1b1e"), "band": Color("c8191e"), "label": Color("ece7dc")},
}

const TAPES := ["white", "black", "none", "candy"]

const SENIOR_VOX := 84   # shaft voxels: 1.47 m
const JUNIOR_VOX := 66   # 1.16 m
const SHAFT_W := 0.04    # collision width of the shaft (the mesh is 0.035)
const LIE := deg_to_rad(45.0)  # blade angle below the shaft's normal
const CURVE := 0.03      # how far the toe bends off the blade's line
## Gap left under a stick's lowest point when it is placed at rest.
const REST_GAP := 0.004

static var _meshes := {}
static var _shapes := {}


## A stick variant: `model` a key of MODELS, `hand` 1 (left curve) or -1
## (right), `junior`, `tape` one of TAPES. `colors` overrides the model's
## shaft / band / label (team sticks).
static func variant(model: String, hand := 1, junior := false, tape := "white", colors := {}) -> Dictionary:
	var v := {"model": model, "hand": 1 if hand >= 0 else -1, "junior": junior, "tape": tape}
	if not colors.is_empty():
		v["colors"] = colors
	return v


## A team stick in a club's colours (Models.palette / team_palette).
static func team_variant(pal: Dictionary, hand := 1, tape := "white") -> Dictionary:
	var shaft: Color = pal.get("shaft", Color("1b1b1e"))
	var band: Color = pal.get("band", Color("c8191e"))
	var band2: Color = pal.get("band2", Color("ece7dc"))
	return variant("team", hand, false, tape, {"shaft": shaft, "band": band, "label": band2})


## A deterministic mixed variant from `pool` (model keys) for slot `i`.
static func pick(pool: Array, seed: int, i: int, junior_share := 0.15) -> Dictionary:
	var h := absi(hash(Vector3i(seed, i, 41)))
	var model: String = pool[h % pool.size()]
	var hand := 1 if (h >> 4) % 3 != 0 else -1   # most shooters are lefties here
	var junior := float((h >> 7) % 100) / 100.0 < junior_share
	var tapes := ["white", "black", "black", "none", "candy", "white"]
	var tape: String = tapes[(h >> 11) % tapes.size()]
	if MODELS[model].wood and tape == "candy":
		tape = "white"
	return variant(model, hand, junior, tape)


## A dressing room's or bench's sticks for `n` slots, about `filled` of them
## used: mostly team sticks in the club's colours (`pal`), the rest whatever
## players bought, all taped.
static func room_mix(pal: Dictionary, seed: int, n: int, filled: int, team_share := 0.6) -> Array:
	var out := []
	var tapes := ["white", "black", "black", "white", "candy"]
	for i in n:
		var h := absi(hash(Vector3i(seed, i, 7)))
		if posmod(hash(Vector2i(seed, i)), n) < n - filled:
			out.append({})
			continue
		var hand := 1 if (h >> 3) % 3 != 0 else -1
		if float(h % 100) / 100.0 < team_share:
			out.append(team_variant(pal, hand, tapes[(h >> 9) % tapes.size()]))
		else:
			out.append(pick(["honest", "kodiak", "warlock", "shorewood", "kodiak_grizzly", "warlock_coven"], seed, i, 0.1))
	return out


static func key(v: Dictionary) -> String:
	var c: Dictionary = v.get("colors", {})
	var cs := ""
	for k in ["shaft", "band", "label"]:
		if c.has(k):
			cs += (c[k] as Color).to_html(false)
	return "%s/%d/%d/%s/%s" % [v.model, v.hand, int(v.junior), v.tape, cs]


static func spec(v: Dictionary) -> Dictionary:
	var s: Dictionary = MODELS.get(v.get("model", "team"), MODELS["team"]).duplicate()
	var c: Dictionary = v.get("colors", {})
	for k in c:
		s[k] = c[k]
	if not s.has("blade"):
		s["blade"] = s.shaft
	return s


## "Warlock HEX, left curve, senior, black tape".
static func describe(v: Dictionary) -> String:
	var s := spec(v)
	var who: String = ("%s %s" % [s.brand, s.line]).strip_edges()
	return "%s, %s curve, %s, %s" % [who, "left" if v.hand > 0 else "right", "junior" if v.junior else "senior",
		"no tape" if v.tape == "none" else ("%s tape" % v.tape)]


static func shaft_vox(v: Dictionary) -> int:
	return JUNIOR_VOX if v.get("junior", false) else SENIOR_VOX


## Blade length, height and thickness (metres).
static func blade_size(v: Dictionary) -> Vector3:
	return Vector3(0.25, 0.065, 0.018) if v.get("junior", false) else Vector3(0.30, 0.075, 0.018)


static func _blade_dir() -> Vector3:
	return Vector3(cos(-LIE), sin(-LIE), 0)


static func _blade_up() -> Vector3:
	return Vector3(sin(LIE), cos(LIE), 0)


## The stick's voxel model (stick space, see the header).
static func stick_model(v: Dictionary) -> VoxelModel:
	var s := spec(v)
	var m := VoxelModel.new(SV)
	m.jitter = 0.03
	var n := shaft_vox(v)
	var shaft: Color = s.shaft
	var wood: bool = s.wood
	for y in n:
		for x in 2:
			for z in 2:
				var c := shaft
				if wood and posmod(hash(Vector3i(x + z * 3, y / 3, 5)), 5) == 0:
					c = shaft.darkened(0.14)  # grain
				m.set_voxel(x, y, z, c)
	m.box(0, 0, 0, 2, 4, 2, shaft.darkened(0.18))  # the hosel
	var band: Color = s.band
	var label: Color = s.label
	# the brand graphic on the upper shaft, a band low down
	var top := n
	m.box(0, top - 36, 0, 2, 12, 2, label)
	m.box(0, top - 37, 0, 2, 1, 2, band)
	m.box(0, top - 24, 0, 2, 2, 2, band)
	m.box(0, 12, 0, 2, 2, 2, band)
	if wood:
		m.box(0, top - 31, 0, 2, 2, 2, band)
	# the tape job at the butt
	var tape: String = v.get("tape", "white")
	match tape:
		"none":
			m.box(0, top, 0, 2, 1, 2, Color("2b2d33"))  # bare end cap
		_:
			var t1 := Models.TAPE if tape != "black" else Color("1d1e21")
			var t2 := Models.TAPE_DARK if tape != "black" else Color("2e3034")
			for y in range(top - 11, top):
				var c := t1 if y % 2 == 0 else t2
				if tape == "candy" and posmod(y, 4) < 2:
					c = band
				m.box(0, y, 0, 2, 1, 2, c)
			m.box(-1, top, -1, 4, 2, 4, t1)  # the knob
	m.set_pivot(1, 0, 1)
	# the blade: three pieces bending toward the curve, taped heel to toe
	var bs := blade_size(v)
	var bd := _blade_dir()
	var bu := _blade_up()
	var hand := float(v.get("hand", 1))
	var tape_c := Models.TAPE if tape == "white" or tape == "candy" else (Color("1d1e21") if tape == "black" else Color(s.blade))
	var lens := [bs.x * 0.38, bs.x * 0.34, bs.x * 0.28]
	var bends := [0.0, 0.14, 0.32]
	var p := Vector3.ZERO
	for i in 3:
		var bend: float = bends[i]
		var d := (Basis(bu, -hand * bend) * bd).normalized()
		var basis := Basis(d, bu, d.cross(bu))
		var l: float = lens[i]
		var centre := p + d * (l * 0.5) - bu * (bs.y * 0.5)
		var c := tape_c
		if i == 2:
			l -= 0.02
			centre = p + d * (l * 0.5) - bu * (bs.y * 0.5)
			var tip := p + d * (l + 0.01) - bu * (bs.y * 0.5)
			m.add_oriented(tip / SV + m.pivot, basis, Vector3(0.02, bs.y * 0.92, bs.z) / SV, Color(s.blade))
		m.add_oriented(centre / SV + m.pivot, basis, Vector3(l + 0.004, bs.y, bs.z) / SV, c)
		p += d * l
	# the heel: a short block joining the shaft to the blade
	m.add_oriented(Vector3(0, -0.012, 0) / SV + m.pivot, Basis(Vector3.BACK, -LIE * 0.5), Vector3(0.04, 0.05, 0.03) / SV, shaft.darkened(0.18))
	return m


## One merged mesh per variant, built on first use.
static func stick_mesh(v: Dictionary) -> ArrayMesh:
	var k := key(v)
	if not _meshes.has(k):
		_meshes[k] = stick_model(v).build_mesh_merged()
	return _meshes[k]


## The stick's collision: [Transform3D, size] boxes in stick space (shaft and
## blade; the curve is folded into the blade box's thickness).
static func collision(v: Dictionary) -> Array:
	var length := (shaft_vox(v) + 2) * SV
	var bs := blade_size(v)
	var bd := _blade_dir()
	var bu := _blade_up()
	var hand := float(v.get("hand", 1))
	var z := bd.cross(bu)
	var centre := bd * (bs.x * 0.5) - bu * (bs.y * 0.5) + z * (hand * CURVE * 0.5)
	return [
		[Transform3D(Basis.IDENTITY, Vector3(0, length * 0.5, 0)), Vector3(SHAFT_W, length, SHAFT_W)],
		[Transform3D(Basis(bd, bu, z), centre), Vector3(bs.x, bs.y, bs.z + CURVE)],
	]


## Shared BoxShape3D resources for a variant's collision (all sticks of one
## size share theirs).
static func shapes(v: Dictionary) -> Array[BoxShape3D]:
	var k := "%d/%d" % [int(v.get("junior", false)), int(v.get("hand", 1))]
	if not _shapes.has(k):
		var out: Array[BoxShape3D] = []
		for b in collision(v):
			var s := BoxShape3D.new()
			s.size = b[1]
			out.append(s)
		_shapes[k] = out
	return _shapes[k]


# ---------------------------------------------------------------- placing sticks

## Where a rack holds its sticks, in the rack's space (metres from its
## pivot): the point the shaft passes through (`at`), the way its top end
## leans (`lean_to`, horizontal) and by how much (`lean`, radians from
## upright), where the toe points (`out`), blade up or down (`up`), and the
## height its lowest point rests on (`floor`).
static func slots(id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match id:
		"stick_rack_wall":
			var pv := Vector3(15, 0, 3)
			for gx in range(2, 29, 2):
				out.append(_slot(_vx(gx + 0.5, 17.5, 4, pv) + Vector3(0, 0, -0.035), Vector3.BACK, 10.0, Vector3.FORWARD, false, 0.0))
		"stick_rack_shop":
			var pv := Vector3(15.5, 0, 3)
			for k in 10:
				var at := _vx(3 * k + 2, 15.5, 4, pv) + Vector3(0, 0, -0.035)
				var butt := _vx(3 * k + 2, 1, 2.5, pv)
				var lean := atan2(at.z - butt.z, at.y - butt.y)
				out.append(_slot(at, Vector3.BACK, rad_to_deg(lean), Vector3.FORWARD, true, butt.y))
		"stick_rack_aframe":
			var pv := Vector3(13, 0, 5)
			for gx in range(1, 24, 2):
				var front := (gx - 1) % 4 == 0
				if front:
					out.append(_slot(_vx(gx + 0.5, 17, 4, pv) + Vector3(0, 0.07, 0), Vector3.BACK, 25.0, Vector3.FORWARD, false, 0.0))
				else:
					out.append(_slot(_vx(gx + 0.5, 17, 6, pv) + Vector3(0, 0.07, 0), Vector3.FORWARD, 25.0, Vector3.BACK, false, 0.0))
		"stick_barrel":
			var n := 6
			var r0 := 0.075
			var r1 := 0.12
			var y1 := 0.75
			for i in n:
				var a := TAU * (i + 0.25) / n
				var dir := Vector3(cos(a), 0, sin(a))
				var lean := atan2(r1 - r0, y1 - V)
				out.append(_slot(dir * r1 + Vector3(0, y1, 0), dir, rad_to_deg(lean), dir, true, V))
		"stick_rack_team":
			var pv := Vector3(14, 0, 4)
			for gx in range(2, 25, 2):
				out.append(_slot(_vx(gx + 0.5, 18.5, 6, pv) + Vector3(0, 0, -0.035), Vector3.BACK, 10.0, Vector3.FORWARD, false, 0.0))
	return out


static func _slot(at: Vector3, lean_to: Vector3, lean_deg: float, toe: Vector3, up: bool, floor_y: float) -> Dictionary:
	return {"at": at, "lean_to": lean_to, "lean": deg_to_rad(lean_deg), "out": toe, "up": up, "floor": floor_y}


static func _vx(x: float, y: float, z: float, pivot: Vector3) -> Vector3:
	return (Vector3(x, y, z) - pivot) * V


## A stick's transform resting in `slot` (in the slot's space).
static func pose(v: Dictionary, slot: Dictionary) -> Transform3D:
	var lean: float = slot.lean
	var lean_to: Vector3 = slot.lean_to
	var a := (Vector3.UP * cos(lean) + lean_to * sin(lean)).normalized()
	var y := -a if slot.up else a
	var toe: Vector3 = slot.out
	var x := (toe - y * toe.dot(y)).normalized()
	var b := Basis(x, y, x.cross(y))
	var lowest := INF
	for box in collision(v):
		var xf: Transform3D = box[0]
		var size: Vector3 = box[1]
		for i in 8:
			var c := Vector3(size.x * ((i & 1) - 0.5), size.y * (((i >> 1) & 1) - 0.5), size.z * (((i >> 2) & 1) - 0.5))
			lowest = minf(lowest, (b * (xf * c)).y)
	var at: Vector3 = slot.at
	var floor_y: float = slot.floor
	var t := (at.y + lowest - floor_y - REST_GAP) / y.y
	return Transform3D(b, at - y * t)


## A stick leaning on a wall or the boards: its shaft touches the top edge
## at `at` (world), leaning toward `lean_to`, toe pointing away.
static func lean_slot(at: Vector3, lean_to: Vector3, lean_deg := 12.0, floor_y := 0.0) -> Dictionary:
	return _slot(at, lean_to, lean_deg, -lean_to, false, floor_y)


## Places rack `id` at `pos` (turned by `rot_y`, front -Z like every prop)
## and stands `variants` in its slots (one per slot, in order; an empty
## Dictionary leaves that slot empty). With `physics` the sticks are real
## StickProp bodies in one StickField under the room; without, they are
## static copies of the shared meshes (match venues). Returns the sticks
## (empty when static).
static func fill(k: VenueKit, id: String, pos: Vector3, rot_y: float, variants: Array, physics: bool, field: StickField = null) -> Array[StickProp]:
	k.prop(id, pos, rot_y)
	var xf := Transform3D(Basis(Vector3.UP, rot_y), pos)
	var list: Array[Dictionary] = slots(id)
	var poses: Array[Transform3D] = []
	var vs: Array[Dictionary] = []
	for i in mini(variants.size(), list.size()):
		var v: Dictionary = variants[i]
		if v.is_empty():
			continue
		poses.append(xf * pose(v, list[i]))
		vs.append(v)
	return place(k, vs, poses, physics, field)


## Sticks at world poses: StickProp bodies (physics) or static copies.
static func place(k: VenueKit, vs: Array[Dictionary], poses: Array[Transform3D], physics: bool, field: StickField = null) -> Array[StickProp]:
	var made: Array[StickProp] = []
	if not physics:
		# a match: the sticks are scenery, one merged mesh per rack
		var meshes: Array[ArrayMesh] = []
		for v in vs:
			meshes.append(stick_mesh(v))
		var merged := StickField.merge(meshes, poses)
		if merged:
			var mi := MeshInstance3D.new()
			mi.name = "Sticks"
			mi.mesh = merged
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			k.add(mi)
		return made
	var f := field
	if f == null:
		f = StickField.new()
		f.name = "Sticks"
		k.add(f)
	for i in vs.size():
		var s := StickProp.make(vs[i])
		s.transform = poses[i]
		f.add_stick(s)
		made.append(s)
	return made


## True when a room should use physics sticks: always in the walk (the venue
## has the recreation wing), never in a match.
static func walkable(room: VenueRoom) -> bool:
	return room.venue != null and room.venue.has_method("has_wings") and bool(room.venue.call("has_wings"))


# ---------------------------------------------------------------- static props

static func build(id: String, age: int) -> VoxelModel:
	match id:
		"stick_rack_wall": return _rack_wall(age)
		"stick_rack_shop": return _rack_shop(age)
		"stick_rack_aframe": return _rack_aframe(age)
		"stick_barrel": return _barrel(age)
		"stick_rack_team": return _rack_team(age)
		"skate_sharpener": return _sharpener(age)
		"skate_rack_tags": return _skate_rack(age)
		"tape_tower": return _tape_tower(age)
		"foot_measure": return _foot_measure(age)
		"shop_till": return _till(age)
		"puck_bin": return _puck_bin(age)
	return null


static func _by_age(age: int, worn: Variant, repaired: Variant, renovated: Variant) -> Variant:
	return [worn, repaired, renovated][clampi(age, 0, 2)]


## Wall-mounted slot rack, 1.95 m: a back rail on two stand-off posts with
## fourteen dowel dividers; blades stand on the floor in front.
static func _rack_wall(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var frame: Color = _by_age(age, Wear.OLD_WOOD_DARK, Wear.PLYWOOD, Wear.CHARCOAL)
	var tooth: Color = _by_age(age, Wear.OLD_WOOD, Wear.NEW_WOOD, Wear.RUBBER)
	for x in [0, 29]:
		m.box(x, 0, 4, 1, 18, 2, frame)
	m.box(15, 9, 5, 1, 9, 1, frame)  # a middle stand-off behind the rail
	m.box(0, 16, 4, 30, 2, 1, frame)
	for x in range(1, 28, 2):
		m.box(x, 17, 1, 1, 1, 3, tooth)
	if age == Wear.REPAIRED:
		m.box(6, 16, 4, 5, 2, 1, Wear.NEW_WOOD)  # a replaced length of rail
		m.box(13, 17, 1, 1, 1, 3, Wear.DUCT_TAPE)  # a taped-on dowel
	elif age == Wear.RENOVATED:
		m.box(0, 16, 4, 30, 1, 1, Wear.NAVY)
	return m.set_pivot(15, 0, 3)


## The pro shop's retail rack, 2 m: sticks stand blade up, butt ends in a
## divided floor tray, shafts held in a slotted rail; a brand header on top.
static func _rack_shop(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var steel: Color = _by_age(age, Wear.OLD_STEEL, Color("6d7276"), Wear.CHARCOAL)
	var tray: Color = _by_age(age, Color("3a3d44"), Color("3a3d44"), Wear.RUBBER)
	var header: Color = _by_age(age, Wear.OLD_CREAM, Wear.PAPER, Wear.WHITE)
	m.box(0, 0, 0, 31, 1, 6, tray)
	for x in range(0, 31, 3):
		m.box(x, 1, 0, 1, 1, 4, steel)  # cell dividers
	m.box(0, 1, 0, 31, 1, 1, steel)  # front lip
	m.box(0, 1, 4, 31, 1, 1, steel)  # back of the tray
	for x in [0, 30]:
		m.box(x, 1, 4, 1, 29, 2, steel)
	m.box(15, 2, 5, 1, 27, 1, steel)
	m.box(0, 14, 4, 31, 2, 1, steel)
	for x in range(0, 31, 3):
		m.box(x, 15, 1, 1, 1, 3, steel)
		m.set_voxel(x, 15, 0, Color("f2c230") if x % 6 == 0 else Wear.PAPER)  # price tags
	m.box(0, 28, 4, 31, 2, 2, header)
	m.box(0, 28, 3, 31, 1, 1, steel)
	if age == Wear.WORN:
		m.box(9, 28, 4, 4, 1, 1, Wear.GRIME)
	elif age == Wear.RENOVATED:
		m.box(0, 30, 4, 31, 1, 2, Wear.RED)
	return m.set_pivot(15.5, 0, 3)


## A floor A-frame, 1.7 m: a ridge rail with pegs on top; sticks lean in
## from both sides into alternate gaps.
static func _rack_aframe(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var tube: Color = _by_age(age, Wear.OLD_STEEL, Color("a7adaf"), Wear.NAVY)
	var peg: Color = _by_age(age, Wear.OLD_STEEL.darkened(0.2), Wear.RED, Wear.WHITE)
	m.box(0, 15, 4, 26, 2, 2, tube)
	for x in range(0, 25, 2):
		m.box(x, 17, 4, 1, 2, 2, peg)
	for x in [0, 25]:
		for y in 16:
			var dz := int(round(4.0 * (15 - y) / 15.0))
			m.set_voxel(x, y, 4 - dz, tube)
			m.set_voxel(x, y, 5 + dz, tube)
		m.box(x, 0, 0, 1, 1, 10, tube)  # feet
	m.box(0, 3, 1, 26, 1, 1, tube)
	m.box(0, 3, 8, 26, 1, 1, tube)
	if age == Wear.WORN:
		Wear.rust(m, Wear.OLD_STEEL, 0.12, 3)
	return m.set_pivot(13, 0, 5)


## A corner barrel for loose sticks, blade up: an old whisky barrel, a blue
## drum, or a steel bin with the club's band.
static func _barrel(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var body: Color = _by_age(age, Wear.OLD_WOOD, Color("2f5f8f"), Wear.STEEL)
	var hoop: Color = _by_age(age, Wear.RUST_DARK, Color("234a70"), Wear.NAVY)
	for i in 9:
		for j in 9:
			var d := Vector2(i + 0.5 - 4.5, j + 0.5 - 4.5).length()
			if d >= 4.5:
				continue
			m.set_voxel(i, 0, j, body.darkened(0.2))
			if d < 3.2:
				continue
			for y in range(1, 12):
				var c := body
				if y in [2, 6, 10]:
					c = hoop
				elif age == Wear.WORN and (i + j) % 3 == 0:
					c = Wear.OLD_WOOD_DARK  # staves
				m.set_voxel(i, y, j, c)
	return m.set_pivot(4.5, 0, 4.5)


## A team rack, 1.8 m: a stand-off rail in team paint on two feet, slotted
## dowels, and a front bar with a strip of white tape and a name per slot.
static func _rack_team(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var paint: Color = _by_age(age, Wear.OLD_ORANGE, Wear.OLD_GOLD, Wear.NAVY)
	var wood: Color = _by_age(age, Wear.OLD_WOOD_DARK, Wear.PLYWOOD, Wear.CHARCOAL)
	for x in [0, 27]:
		m.box(x, 0, 0, 1, 1, 8, wood)
		m.box(x, 0, 6, 1, 19, 2, wood)
		m.box(x, 16, 2, 1, 1, 4, wood)  # brackets for the name bar
	m.box(0, 17, 6, 28, 2, 1, paint)
	for x in range(1, 26, 2):
		m.box(x, 18, 3, 1, 1, 3, wood)
	m.box(0, 16, 2, 28, 1, 1, paint)
	# the name tape: white tape across the bar, a scrawl over each slot
	for x in range(1, 27):
		var c := Wear.PAPER
		if x % 2 == 0 and posmod(hash(Vector2i(x, age)), 3) != 0:
			c = Color("1d1e21")
		m.set_voxel(x, 16, 1, c)
	return m.set_pivot(14, 0, 4)


## Bev's skate sharpener: a floor-standing grinder on a steel cabinet (a
## Blademaster-style machine), wheel guard, the holder's slide rail, a
## dresser, a lamp, and a canister dust collector with its hose. Worn it is
## Old Bertha in 1970s machinery green; renovated a new charcoal-and-blue one.
static func _sharpener(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var body: Color = _by_age(age, Color("4f6e5d"), Color("4f6e5d"), Wear.CHARCOAL)
	var trim: Color = _by_age(age, Color("3a5446"), Color("f2c230"), Color("2457a6"))
	var top: Color = _by_age(age, Wear.OLD_STEEL, Color("a7adaf"), Wear.STEEL)
	var hose := Color("2b2d33")
	# cabinet with two doors and a kick plate
	m.box(6, 0, 1, 20, 14, 9, body)
	m.box(6, 0, 0, 20, 1, 10, Wear.RUBBER)
	m.box(7, 2, 0, 8, 10, 1, body.darkened(0.12))
	m.box(17, 2, 0, 8, 10, 1, body.darkened(0.12))
	m.set_voxel(14, 7, 0, top)
	m.set_voxel(17, 7, 0, top)
	m.box(6, 14, 0, 20, 1, 10, top)
	# the wheel guard and the wheel showing in its mouth
	m.box(17, 15, 3, 7, 7, 6, body)
	m.box(18, 16, 2, 5, 5, 1, Color("1b1d22"))
	m.box(19, 17, 2, 3, 3, 1, Color("d8d6cc"))
	m.box(16, 18, 5, 1, 2, 2, top)  # the motor shaft housing
	m.box(9, 22, 4, 12, 1, 2, trim)  # the dresser bar over the wheel
	# the holder slide: a rail along the front, the clamp on it
	m.box(7, 15, 1, 10, 1, 1, top)
	m.box(10, 16, 0, 3, 2, 3, trim)
	m.box(11, 18, 1, 1, 1, 1, Color("d0202a"))  # the clamp knob
	# controls on the front
	m.box(24, 10, 0, 2, 3, 1, Color("6d7276"))
	m.set_voxel(24, 12, -1, Color("41d161"))
	m.set_voxel(25, 11, -1, Color("e8332a"))
	# lamp on a post
	m.box(8, 15, 7, 1, 9, 1, top)
	m.box(8, 24, 4, 1, 1, 4, top)
	m.box(7, 23, 3, 3, 1, 2, trim)
	# the dust collector: a canister on the left, its hose up and over
	for i in 6:
		for j in 6:
			var d := Vector2(i + 0.5 - 3.0, j + 0.5 - 3.0).length()
			if d > 3.0:
				continue
			for y in 13:
				var c := Color("5e6a71") if age != Wear.RENOVATED else Color("2457a6")
				if y == 0 or y == 12:
					c = Color("3a3d44")
				m.set_voxel(i, y, j + 2, c)
	m.box(2, 13, 4, 2, 2, 2, Color("3a3d44"))
	for y in range(15, 21):
		m.set_voxel(2, y, 5, hose if y % 2 == 0 else hose.lightened(0.12))
	for x in range(2, 18):
		m.set_voxel(x, 21, 5, hose if x % 2 == 0 else hose.lightened(0.12))
	if age == Wear.WORN:
		Wear.rust(m, Color("4f6e5d"), 0.06, 9)
		m.box(6, 14, 0, 3, 1, 3, Color("4a2a12"))  # an oil stain on the top
	return m.set_pivot(13, 0, 5)


## The customer skate rack: a wire unit of three shelves, a pair of skates
## per bay with a paper tag on a string (name, hollow, due).
static func _skate_rack(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var wire: Color = _by_age(age, Wear.OLD_STEEL, Color("b8bcc2"), Wear.CHARCOAL)
	for x in [0, 17]:
		for z in [0, 5]:
			m.box(x, 0, z, 1, 26, 1, wire)
	var boots := [Color("1b1d22"), Color("2b2d33"), Color("eeeeea"), Color("1d3557"), Color("5b3a1e"), Color("1b1d22")]
	var tags := [Wear.PAPER, Color("f2c230"), Color("f2a0b0"), Color("9be2a0")]
	var bay := 0
	for shelf in 3:
		var y := shelf * 8 + 1
		m.box(0, y, 0, 18, 1, 6, wire)
		if shelf == 2:
			m.box(0, 25, 0, 18, 1, 6, wire)
		for p in 3:
			var x := 1 + p * 6
			if (shelf + p + age) % 5 == 4:
				bay += 1
				continue  # an empty bay
			var boot: Color = boots[(bay * 7 + age) % boots.size()]
			for s in 2:
				var sx := x + s * 3
				m.box(sx, y + 1, 1, 2, 1, 4, Color("d8d6cc") if posmod(bay, 2) == 0 else Color("1b1d22"))  # holder
				m.box(sx, y + 2, 1, 2, 3, 4, boot)
				m.box(sx, y + 4, 3, 2, 2, 2, boot.lightened(0.15))  # the cuff
			# the tag hangs off the shelf lip by its string
			m.set_voxel(x + 2, y, -1, Wear.DUCT_TAPE)
			m.set_voxel(x + 2, y - 1, -1, tags[bay % tags.size()])
			bay += 1
	return m.set_pivot(9, 0, 3)


## A spinner tower of tape rolls by the counter.
static func _tape_tower(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var pole: Color = _by_age(age, Wear.OLD_STEEL, Color("b8bcc2"), Wear.CHARCOAL)
	m.box(0, 0, 0, 6, 1, 6, pole)
	m.box(2, 1, 2, 2, 24, 2, pole)
	var cols := [Models.TAPE, Color("1d1e21"), Color("3f6fa8"), Color("c8191e"), Color("f2c230"), Color("2a7a4a")]
	for row in 5:
		var y := 4 + row * 4
		for side in 4:
			var c: Color = cols[(row * 4 + side + age) % cols.size()]
			match side:
				0: m.box(2, y, 0, 2, 2, 2, c)
				1: m.box(2, y, 4, 2, 2, 2, c)
				2: m.box(0, y, 2, 2, 2, 2, c)
				3: m.box(4, y, 2, 2, 2, 2, c)
	m.box(1, 25, 1, 4, 2, 4, Color("f2c230") if age != Wear.RENOVATED else Wear.RED)  # the Gripley's header
	m.set_voxel(2, 26, 0, Color("1a1a1a"))
	m.set_voxel(3, 26, 0, Color("1a1a1a"))
	return m.set_pivot(3, 0, 3)


## A foot measuring board on the floor by the fitting bench.
static func _foot_measure(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var plate: Color = _by_age(age, Color("6d7276"), Color("8f9498"), Wear.CHARCOAL)
	m.box(0, 0, 0, 3, 1, 6, plate)
	for z in range(1, 6, 2):
		m.set_voxel(1, 1, z, Color("1b1d22"))
	m.box(0, 1, 0, 3, 1, 1, plate.darkened(0.2))  # heel cup
	m.box(2, 1, 3, 1, 1, 1, Color("d0202a"))  # the slider
	return m.set_pivot(1.5, 0, 3)


## The till: a 1970s register (worn) or a till with a card reader.
static func _till(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var body: Color = _by_age(age, Color("8a7a5a"), Color("8a7a5a"), Wear.CHARCOAL)
	m.box(0, 0, 0, 7, 2, 6, body)
	m.box(0, 2, 2, 7, 1, 4, body)
	m.box(1, 2, 0, 5, 1, 2, Color("d8d6cc"))  # keys
	m.box(2, 3, 4, 3, 2, 1, body.darkened(0.2))
	m.box(2, 4, 3, 3, 1, 1, Color("1b3a2a") if age != Wear.RENOVATED else Color("0f2a3a"))  # display
	if age == Wear.RENOVATED:
		m.box(7, 0, 1, 1, 2, 2, Color("1b1d22"))  # card reader
	return m.set_pivot(3.5, 0, 3)


## A wire bin of loose pucks.
static func _puck_bin(age: int) -> VoxelModel:
	var m := VoxelModel.new(V)
	var wire: Color = _by_age(age, Wear.OLD_STEEL, Color("b8bcc2"), Wear.CHARCOAL)
	m.box(0, 0, 0, 8, 1, 8, wire)
	for y in range(1, 9):
		for i in 8:
			if (i + y) % 2 == 0:
				m.set_voxel(i, y, 0, wire)
				m.set_voxel(i, y, 7, wire)
				m.set_voxel(0, y, i, wire)
				m.set_voxel(7, y, i, wire)
	m.box(0, 9, 0, 8, 1, 1, wire)
	m.box(0, 9, 7, 8, 1, 1, wire)
	m.box(0, 9, 0, 1, 1, 8, wire)
	m.box(7, 9, 0, 1, 1, 8, wire)
	m.box(1, 1, 1, 6, 6, 6, Models.PUCK)
	for i in 6:
		m.set_voxel(1 + i, 7, 1 + (i * 3) % 6, Models.PUCK)
	return m.set_pivot(4, 0, 4)
