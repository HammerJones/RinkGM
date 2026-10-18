class_name PeopleArt
extends RefCounted
## Voxel bodies for everyone in the building: fans, parents, staff, refs,
## skaters, kids and grandparents (docs/world/PEOPLE.md). Hundreds share a few
## meshes: the geometry depends only on the body's *shape* (age band, build,
## outfit, hair, accessory, skates) and everything else (colours, pose, the
## walk cycle, height) comes per instance from MultiMesh custom data, read by
## one shared vertex shader.
##
##   var key := PeopleArt.shape_key(look, age)        # geometry only
##   var mm := PeopleArt.multimesh(key, 1)            # or your own MultiMesh
##   mm.set_instance_transform(0, Transform3D(Basis(Vector3.UP, yaw), feet))
##   mm.set_instance_custom_data(0, PeopleArt.instance_data(look, PeopleArt.Pose.WALK, 0.3, age))
##
## For crowds, layer_keys() splits a person into body, head and held-item
## meshes; draw each layer as its own MultiMesh with the same transforms and
## custom data. Layers multiply far less, so a stand of 400 fans is a few
## dozen draws instead of hundreds.
##
## Proportions are shared with SkaterRig (the Animations thread): the adult
## joint heights below are the contract. Mesh pivot is on the floor between
## the feet (blade bottom on skates), front faces -Z, +X is the person's right.

const V := Models.V

# ---------------------------------------------------------------- proportions
# Adult joint heights and lengths in voxels (V), in shoes. On skates
# everything above the foot rises by SKATE - SHOE. Limbs hang down their
# local -Y from the joint, like SkaterRig's parts.
const SHOE := 0.5        # sole
const SKATE := 1.5       # blade and holder
const SHIN := 6.0        # knee to the top of the foot
const THIGH := 6.5       # hip joint to knee joint
const KNEE := SHOE + SHIN         # 6.5
const HIP := KNEE + THIGH         # 13
const NECK := 21.0                # top of the torso, base of the head
const SHOULDER := 20.5            # shoulder joint height
const UPPER_ARM := 5.0
const FOREARM := 5.5              # forearm plus hand
const ELBOW := SHOULDER - UPPER_ARM   # 15.5
const HEAD := 5.0
const HEIGHT := 27.0              # crown of the hair, in shoes (28 on skates)
const SHOULDER_W := 11.0          # outside of one arm to the other (average build)
const SHOULDER_X := 4.5           # arm centre from the body's centre line

## Seat top height the SIT poses sit on (Props "arena_seat": 7 V).
const SEAT_H := 7 * V

# ---------------------------------------------------------------- vocabulary
const BUILDS := ["slim", "average", "stocky", "big"]
const HAIRS := ["short", "long", "bun", "bald", "ponytail", "curly", "buzz", "mullet", "toque_hair"]
const OUTFITS := ["casual", "parka", "hoodie", "team_jacket", "hockey_gear", "goalie_gear",
	"figure_dress", "figure_warmup", "ref_stripes", "coach_tracksuit", "staff_polo",
	"canteen_apron", "shop_apron", "coveralls", "suit", "cardigan", "school_jacket", "work_jacket"]
const ACCESSORIES := ["none", "toque", "ball_cap", "scarf", "glasses", "reading_glasses",
	"coffee", "foam_finger", "cowbell", "clipboard", "whistle", "camera", "thermos", "blanket",
	"sign", "helmet", "skates_over_shoulder", "stick", "programme", "knitting", "headset"]
## Geometry bands. Elders (70+) share the adult geometry; the shader stoops them.
const BANDS := ["toddler", "child", "teen", "adult"]
const SKATE_OUTFITS := ["hockey_gear", "goalie_gear", "figure_dress", "figure_warmup", "ref_stripes"]
const _HATS := ["toque", "ball_cap", "helmet", "headset"]
const _FACE := ["glasses", "reading_glasses"]
const _LONGISH := ["long", "bun", "ponytail", "curly", "mullet"]

## Poses, set per instance. SWEEP is WORK. SIT_* keep the seated legs and
## swap the upper body. `moving` in instance_data() puts walking legs under
## the standing upper-body poses (TALK, CARRY, QUEUE, WAVE, CLAP).
enum Pose { STAND, WALK, SIT, SKATE, SKATE_WOBBLY, SPIN, CHEER, CLAP, TALK, WAVE, QUEUE,
	CARRY, WORK, FALL, SIT_CLAP, SIT_CHEER }
const POSE := Pose
const SWEEP := Pose.WORK

## Colour slots (UV.x) and body parts (UV.y).
enum { FIXED, SKIN, PRIMARY, SECONDARY, HAIR, ACCENT }
enum { TORSO, HEAD_PART, THIGH_L, THIGH_R, SHIN_L, SHIN_R, UPPER_L, UPPER_R, FORE_L, FORE_R,
	HELD, BOX, PHONE }

# ---------------------------------------------------------------- palette
## 64 clothing colours (ART.md's old and club palettes, team colours, common
## clothes), then 16 hair colours, then the 4 skin tones. Authored in sRGB.
const PALETTE := [
	"eeeeea", "d9d4c7", "c9c2b0", "a8a294", "8c8c8c", "6d7b8c", "5e6a71", "39424e",
	"2b2d33", "1d1d22", "3e4249", "b9c0c6", "8f9498", "d0202a", "c8191e", "97121a",
	"8a2f2f", "6b1f2a", "e25822", "c8642a", "ff7a1a", "b8732d", "d9a62e", "d6a321",
	"e8c547", "d4e157", "7d8a3a", "3e6b3a", "2e8b57", "1e5631", "3c8d4e", "8bc34a",
	"8fbfa8", "59613a", "2a9d8f", "0e7c86", "2ec4b6", "a9d3e0", "7fb3d5", "3a86c8",
	"1e90ff", "1f4f9a", "1c4e80", "1d3557", "15203f", "2f5e8a", "3b5878", "00b4d8",
	"5c3d7a", "4b2a7b", "a58fcf", "e58fb0", "d6407f", "7a2335", "9a6b3f", "5b3a22",
	"6b4423", "c9a66b", "b7a37a", "d9b98a", "e3d9bf", "8c2f1c", "6f3b1f", "e2725b",
]
const HAIR_COLORS := [
	"1a1714", "2b2220", "3a2a1e", "5a3b24", "7a4a2a", "8f6a44", "8a3b1f", "b8622d",
	"c98a5a", "a8864f", "d4b06a", "e8dcb0", "8a8a8a", "b5b5b5", "e8e6e0", "d67aa3",
]
const SKINS := ["f1c7a5", "d9a37e", "a86f4c", "6b4430"]

## Trousers (the accent slot) when the look gives no third colour.
const _ACCENT_DEFAULT := {
	"casual": "3b5878", "parka": "2b2d33", "hoodie": "15203f", "team_jacket": "3b5878",
	"hockey_gear": "15203f", "goalie_gear": "15203f", "figure_dress": "d9b98a",
	"figure_warmup": "1d1d22", "ref_stripes": "1d1d22", "coach_tracksuit": "1d3557",
	"staff_polo": "b7a37a", "canteen_apron": "2b2d33", "shop_apron": "3b5878",
	"coveralls": "39424e", "suit": "2b2d33", "cardigan": "6b4423", "school_jacket": "3b5878",
	"work_jacket": "3b5878",
}

# Fixed colours.
const _EYE := Color("231a16")
const _SNEAKER := Color("e8e4da")
const _SHOE := Color("2b2522")
const _BROWN_SHOE := Color("5b3a22")
const _WORK_BOOT := Color("6b4a2e")
const _BOOT := Models.BOOT
const _FIG_BOOT := Color("f4f2ec")
const _STEEL := Models.STEEL
const _GLOVE := Models.GLOVE
const _WHITE := Color("eeeeea")
const _BLACK := Color("1d1d22")
const _PAD := Color("ece6da")
const _CAGE := Models.CAGE
const _ORANGE := Color("e8661f")
const _CARD := Color("b88a52")

static var _cache := {}
static var _material: ShaderMaterial
static var _quant := {}


# ================================================================ public API

## The geometry key of one person: one mesh per key, shared by everyone with
## that shape. Colours, pose and height are not in it (they're per instance).
## Format: "<body>|<head>|<item>", each a layer key (see layer_keys()).
static func shape_key(look: Dictionary, age: int) -> String:
	var k := layer_keys(look, age)
	return "%s|%s|%s" % [k[0], k[1], k[2] if k.size() > 2 else "-"]


## The person split into layer meshes, for crowds: [body, head] plus the held
## or worn item when there is one. Draw each with the same instance data.
static func layer_keys(look: Dictionary, age: int) -> PackedStringArray:
	var n := _norm(look, age)
	var out := PackedStringArray()
	out.append("B:%s:%s:%s:%d" % [n.band, n.build, n.outfit, n.lift])
	out.append("H:%s:%s:%s:%s" % [n.band, n.hair, n.hat, n.face])
	if n.item != "none":
		out.append("I:%s:%s:%s:%s" % [n.band, _width(n.band, n.build), _bulk(n.outfit), n.item])
	return out


## The mesh for a shape key or a layer key. Cached; greedy-merged; carries
## the shared material. See docs/ART.md "People" for the vertex layout.
static func mesh(key: String) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var parts: Array = []
	var layers := key.split("|")
	for layer in layers:
		if layer != "-":
			parts.append_array(_layer_parts(layer))
	# every layer carries the same hip data, so layers drawn alone still pose alike
	var f := layers[0].split(":")
	var band := f[1] if f.size() > 2 else "adult"
	var d := _dims(band, _BUILDS_OF[band][0], "casual")
	var m := _commit(parts, d.hip, d.hip - d.knee)
	_cache[key] = m
	return m


## A MultiMesh ready for people of one key: 3D transforms and custom data on.
static func multimesh(key: String, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh(key)
	mm.instance_count = count
	return mm


## The shared material. Every people mesh already carries it.
static func material() -> ShaderMaterial:
	if _material == null:
		var sh := Shader.new()
		sh.code = _SHADER
		_material = ShaderMaterial.new()
		_material.shader = sh
		var pal := PackedVector3Array()
		for list in [PALETTE, HAIR_COLORS, SKINS]:
			for hex in list:
				var c := Color(hex)
				pal.append(Vector3(c.r, c.g, c.b))
		_material.set_shader_parameter("palette", pal)
		_material.set_shader_parameter("seat_height", SEAT_H)
		_material.set_shader_parameter("adult_hip", HIP * V)
		_material.set_shader_parameter("walk_speed", WALK_SPEED)
		_material.set_shader_parameter("run_speed", RUN_SPEED_REF)
		for k in _GAIT:
			_material.set_shader_parameter(k, gait(k))
	return _material


## Gait numbers shared with SkaterRig: AnimTuning.current()'s value when it
## has the property, else the default here (so a person who swaps from the
## crowd onto the jointed rig keeps the same walk). refresh_gait() re-reads
## them after the anim studio changes AnimTuning.
const _GAIT := {
	"walk_cadence": 1.8, "walk_cadence_run": 2.8, "walk_duty": 0.62, "walk_duty_run": 0.38,
	"walk_lift": 0.08, "walk_bob": 0.02, "walk_arm_swing": 0.35, "walk_width": 0.14,
	"crouch_hips": 0.22, "sit_lean": 0.08,
}
const WALK_SPEED := 1.3     # m/s, RinkPeople.WALK: the walk cycle is built for it
const RUN_SPEED := 2.2      # above this instance_data() switches to the run
const RUN_SPEED_REF := 3.0  # m/s the run cycle is built for


static func gait(key: String) -> float:
	var t: Variant = AnimTuning.current()
	var v: Variant = t.get(key) if t else null
	return float(v) if v != null else float(_GAIT[key])


## Re-reads AnimTuning into the shared material (the anim studio calls it
## after a tweak).
static func refresh_gait() -> void:
	if _material:
		for k in _GAIT:
			_material.set_shader_parameter(k, gait(k))


## Gait cycles per second for someone walking at `speed` m/s, so planted feet
## don't slide: at WALK_SPEED an adult does walk_cadence / 2 cycles a second;
## shorter legs take shorter strides, so kids cycle faster at the same speed.
static func walk_phase_rate(speed: float, look := {}, age := 35) -> float:
	var run := speed > RUN_SPEED
	var cad := gait("walk_cadence_run" if run else "walk_cadence")
	var cycle := (RUN_SPEED_REF if run else WALK_SPEED) / (cad * 0.5)  # metres per cycle
	return speed / (cycle * _leg_ratio(look, age))


## Skating stride cycles per second (one push from each leg per cycle), from
## AnimTuning's stride_cadence, a little quicker the faster they go.
static func skate_phase_rate(speed: float) -> float:
	var t: Variant = AnimTuning.current()
	var cad: Variant = t.get("stride_cadence") if t else null
	return (float(cad) if cad != null else 1.7) * 0.5 * clampf(speed / 3.2, 0.6, 1.4)


## A body's leg length (hip height, as drawn) against the adult contract.
static func _leg_ratio(look: Dictionary, age: int) -> float:
	var n := _norm(look, age)
	var d := _dims(n.band, n.build, n.outfit)
	return d.hip / HIP * body_scale(look, age)


## Everything per instance in one Color for MultiMesh.set_instance_custom_data:
## pose, cycle phase (0..1), walking legs, colours, skin, height and a seed.
## Each channel is an integer under 2048, exact even as a half float.
##   r = pose << 7 | moving << 6 | phase (0..63)
##   g = skates << 10 | primary << 4 | scale step (0..15: 0.70 + 0.04 * step)
##   b = secondary << 5 | hair colour << 1 | elder
##   a = accent << 5 | skin << 3 | run << 2 | seed (0..3)
## `phase` is the gait cycle for WALK, SKATE and walking legs: advance it by
## walk_phase_rate(speed) or skate_phase_rate(speed) cycles a second. Other
## poses animate on their own clock and use it only to stagger people.
## `speed` above RUN_SPEED switches the walk to a run.
static func instance_data(look: Dictionary, pose: int, phase: float, age := -1, moving := false, speed := 0.0) -> Color:
	if age < 0:
		age = int(look.get("age", 35))
	var cols: Array = look.get("colors", [])
	var outfit := str(look.get("outfit", "casual"))
	var pri := _nearest(str(cols[0]) if cols.size() > 0 else "6d7b8c", PALETTE)
	var sec := _nearest(str(cols[1]) if cols.size() > 1 else "d9d4c7", PALETTE)
	var acc_hex: String = str(look.get("accent", cols[2] if cols.size() > 2 else _ACCENT_DEFAULT.get(outfit, "3b5878")))
	var acc := _nearest(acc_hex, PALETTE)
	var hair := _nearest(_hair_hex(look), HAIR_COLORS)
	var skin := clampi(int(look.get("skin", 1)), 0, 3)
	var step := clampi(roundi((body_scale(look, age) - 0.70) / 0.04), 0, 15)
	var ph := posmod(roundi(phase * 64.0), 64)
	var seed := posmod(hash(str(look.get("id", look.get("name", "")))), 4)
	var run := 1 if speed > RUN_SPEED else 0
	var elder := 1 if age >= 70 else 0
	var skates: int = _norm(look, age).lift
	return Color(
		float((clampi(pose, 0, 15) << 7) | ((1 if moving else 0) << 6) | ph),
		float((skates << 10) | (pri << 4) | step),
		float((sec << 5) | (hair << 1) | elder),
		float((acc << 5) | (skin << 3) | (run << 2) | seed))


## Unpacks instance_data() (for tests and debugging).
static func decode(c: Color) -> Dictionary:
	var r := roundi(c.r)
	var g := roundi(c.g)
	var b := roundi(c.b)
	var a := roundi(c.a)
	return {
		"pose": r >> 7, "moving": (r >> 6) & 1 == 1, "phase": float(r & 63) / 64.0,
		"skates": (g >> 10) & 1 == 1, "primary": (g >> 4) & 63, "scale": 0.70 + 0.04 * float(g & 15),
		"secondary": b >> 5, "hair": (b >> 1) & 15, "elder": b & 1 == 1,
		"accent": a >> 5, "skin": (a >> 3) & 3, "run": (a >> 2) & 1 == 1, "seed": a & 3,
	}


## Overall size the shader applies: the look's height for adults, growth
## within the age band for kids (a 5-year-old and an 11-year-old share a mesh).
static func body_scale(look: Dictionary, age: int) -> float:
	var h := clampf(float(look.get("height", 1.0)), 0.85, 1.12)
	var band := _band(age)
	var s := h
	if band != "adult":
		s = (_grown(age) / _BAND_H[band]) * (1.0 + (h - 1.0) * 0.5)
	elif age >= 70:
		s *= 0.97
	return clampf(s, 0.70, 1.30)


## Eye height above the pivot when standing, metres.
static func eye_height(look: Dictionary, age: int) -> float:
	var n := _norm(look, age)
	var d := _dims(n.band, n.build, n.outfit)
	var stoop := 0.96 if age >= 70 else 1.0
	return (d.neck + 2.5 + n.lift * (SKATE - SHOE)) * V * body_scale(look, age) * stoop


## Where the pivot goes for a SIT pose, relative to the seat point (the top
## centre of the seat, seat facing -Z). The shader lowers the hips onto a seat
## SEAT_H above the pivot, so the pivot is the floor under the seat; deep
## builds sit a little forward so their backs clear the backrest.
static func seat_offset(look: Dictionary, age: int) -> Vector3:
	var n := _norm(look, age)
	var d := _dims(n.band, n.build, n.outfit)
	var back: float = d.td * 0.5 * V * body_scale(look, age)
	return Vector3(0, -SEAT_H, minf(0.0, 0.15 - back))


## Collision radius (a cylinder round the pivot), metres.
static func body_radius(look: Dictionary, age: int) -> float:
	var n := _norm(look, age)
	var d := _dims(n.band, n.build, n.outfit)
	return maxf(d.tw * 0.5 + d.aw * 0.6, d.td * 0.5 + 1.0) * V * body_scale(look, age)


## A plausible random look (for tests, review sheets and filler crowds).
## `where`: "stands" (spectators), "ice" (public skate) or "staff".
static func random_look(rng: RandomNumberGenerator, age: int, where := "stands") -> Dictionary:
	var band := _band(age)
	var pick := func(a: Array) -> Variant: return a[rng.randi() % a.size()]
	var outfit: String
	var acc := "none"
	match where:
		"ice":
			outfit = pick.call(["casual", "parka", "hoodie", "figure_warmup", "school_jacket", "team_jacket"])
		"staff":
			outfit = pick.call(["staff_polo", "canteen_apron", "coveralls", "shop_apron", "coach_tracksuit", "ref_stripes"])
		_:
			outfit = pick.call(["casual", "casual", "parka", "parka", "hoodie", "team_jacket", "team_jacket",
				"cardigan", "school_jacket", "coach_tracksuit", "work_jacket"])
	if rng.randf() < 0.45:
		acc = pick.call(["toque", "toque", "ball_cap", "scarf", "glasses", "coffee", "coffee",
			"foam_finger", "thermos", "programme", "blanket", "reading_glasses", "cowbell", "camera"])
	if band == "toddler" or band == "child":
		if where == "ice":
			acc = "helmet" if rng.randf() < 0.7 else acc
		elif acc in ["coffee", "reading_glasses", "thermos", "blanket", "programme"]:
			acc = "toque"
	var hairs: Array = HAIRS.slice(0, 8)
	var look := {
		"build": pick.call(BUILDS), "height": rng.randf_range(0.88, 1.10), "skin": rng.randi() % 4,
		"hair": pick.call(hairs), "hair_color": pick.call(HAIR_COLORS if age < 60 else HAIR_COLORS.slice(11, 15)),
		"outfit": outfit, "colors": [pick.call(PALETTE), pick.call(PALETTE)], "accessory": acc,
	}
	if where == "ice":
		look.skates = true
	return look


static func band_of(age: int) -> String:
	if age >= 70:
		return "elder"
	return _band(age)


# ================================================================ looks → shape

static func _band(age: int) -> String:
	if age < 5:
		return "toddler"
	if age < 12:
		return "child"
	if age < 18:
		return "teen"
	return "adult"


# Typical height by age (m), and each band mesh's own height in shoes (m).
const _BAND_H := {"toddler": 15.5 * V, "child": 20.0 * V, "teen": 25.0 * V, "adult": HEIGHT * V}


static func _grown(age: int) -> float:
	var t := [0.75, 0.87, 0.95, 1.02, 1.09, 1.15, 1.22, 1.28, 1.33, 1.39, 1.44, 1.50, 1.56, 1.63, 1.68, 1.71, 1.73]
	return t[clampi(age, 1, 17) - 1] if age < 18 else HEIGHT * V


## The look reduced to what changes geometry, with combinations collapsed
## where they can't be told apart (hair under a helmet, kids' builds).
static func _norm(look: Dictionary, age: int) -> Dictionary:
	var band := _band(age)
	var build := str(look.get("build", "average"))
	if not build in BUILDS:
		build = "average"
	match band:
		"toddler": build = "average"
		"child": build = "slim" if build in ["slim", "average"] else "stocky"
		"teen": build = "slim" if build in ["slim", "average"] else "stocky"
	var outfit := str(look.get("outfit", "casual"))
	if not outfit in OUTFITS:
		outfit = "casual"
	var acc := str(look.get("accessory", "none"))
	if not acc in ACCESSORIES:
		acc = "none"
	var hair := _hair_shape(str(look.get("hair", "short")))
	var skates: bool = bool(look.get("skates", outfit in SKATE_OUTFITS))
	var hat := "none"
	var face := "none"
	if acc in _HATS:
		hat = acc
	elif acc in _FACE:
		face = acc
	if hair == "toque_hair":
		hair = "short"
		if hat == "none":
			hat = "toque"
	if outfit == "goalie_gear":
		hat = "mask"
	# hair a hat hides: only what shows below it
	if hat in ["toque", "ball_cap"]:
		hair = "long" if hair in _LONGISH else ("none" if hair in ["bald", "buzz"] else "short")
	elif hat in ["helmet", "mask"]:
		hair = "long" if hair in _LONGISH else "none"
		face = "none"
	var item := acc if not (acc in _HATS or acc in _FACE) else "none"
	return {"band": band, "build": build, "outfit": outfit, "lift": 1 if skates else 0,
		"hair": hair, "hat": hat, "face": face, "item": item}


static func _hair_shape(h: String) -> String:
	if h in HAIRS:
		return h
	for s in HAIRS:  # "grey_bun" -> bun
		if h.ends_with(s) or h.begins_with(s):
			return s
	return "short"


static func _hair_hex(look: Dictionary) -> String:
	if look.has("hair_color"):
		return str(look.hair_color)
	var h := str(look.get("hair", ""))
	for word in [["grey", "8a8a8a"], ["gray", "8a8a8a"], ["white", "e8e6e0"], ["silver", "b5b5b5"],
			["blond", "d4b06a"], ["red", "b8622d"], ["black", "1a1714"]]:
		if h.contains(word[0]):
			return word[1]
	return "3a2a1e"


## Nearest palette entry to a hex colour (redmean distance), cached.
static func _nearest(hex: String, list: Array) -> int:
	var key := "%d/%s" % [list.size(), hex]
	if _quant.has(key):
		return _quant[key]
	var c := Color(hex.trim_prefix("#"))
	var best := 0
	var best_d := INF
	for i in list.size():
		var p := Color(list[i])
		var rm := (c.r + p.r) * 0.5
		var d := (2.0 + rm) * pow(c.r - p.r, 2) + 4.0 * pow(c.g - p.g, 2) + (3.0 - rm) * pow(c.b - p.b, 2)
		if d < best_d:
			best_d = d
			best = i
	_quant[key] = best
	return best


## Builds per band after _norm() collapses them.
const _BUILDS_OF := {"toddler": ["average"], "child": ["slim", "stocky"], "teen": ["slim", "stocky"],
	"adult": ["slim", "average", "stocky", "big"]}


## Held and worn items fit two widths per band (a quarter voxel off at most).
static func _width(band: String, build: String) -> String:
	return "wide" if build in ["stocky", "big"] else "narrow"


## Outfits that bulk the body out (and so move the hands).
static func _bulk(outfit: String) -> String:
	match outfit:
		"hockey_gear": return "pad"
		"goalie_gear": return "goalie"
		"parka": return "parka"
	return "plain"


# Per band: shin, thigh, torso (hip to neck) and arm lengths in V. The adult
# row is the shared contract above; kids have shorter limbs and the same
# 5 V head, which is what makes them read as kids.
const _BAND := {
	"toddler": {"shin": 2.5, "thigh": 2.5, "torso": 4.0, "upper": 2.0, "fore": 2.5, "ld": 3},
	"child": {"shin": 4.0, "thigh": 4.0, "torso": 5.5, "upper": 3.0, "fore": 3.5, "ld": 3},
	"teen": {"shin": 5.5, "thigh": 6.0, "torso": 7.0, "upper": 4.5, "fore": 5.0, "ld": 3},
	"adult": {"shin": SHIN, "thigh": THIGH, "torso": NECK - HIP, "upper": UPPER_ARM, "fore": FOREARM, "ld": 3},
}
# Per band and build: torso width and depth, arm width, leg width, leg
# centre x (all V). The average adult is 7 + 2 x 2 = 11 V across the shoulders.
const _BUILD := {
	"toddler/average": [5, 4, 2, 2, 1.25],
	"child/slim": [5, 3, 2, 2, 1.25], "child/stocky": [6, 4, 2, 2, 1.5],
	"teen/slim": [6, 4, 2, 2, 1.5], "teen/stocky": [7, 4, 2, 3, 2.0],
	"adult/slim": [6, 3, 2, 2, 1.5], "adult/average": [7, 4, 2, 3, 2.0],
	"adult/stocky": [8, 5, 2, 3, 2.5], "adult/big": [9, 5, 2, 4, 2.5],
}


## Joint heights and widths of one body, in V, model space.
## Skates don't change these: a skating body hangs its blades below the
## pivot and the shader lifts the whole person by SKATE - SHOE, so heads and
## held items fit skaters and walkers alike.
static func _dims(band: String, build: String, outfit: String) -> Dictionary:
	var b: Dictionary = _BAND[band]
	var w: Array = _BUILD["%s/%s" % [band, build]]
	var foot := SHOE
	var d := {"band": band, "build": build, "foot": foot,
		"tw": w[0], "td": w[1], "aw": w[2], "lw": w[3], "lx": w[4], "ld": b.ld,
		"thigh_w": w[3], "belly": build == "big"}
	match _bulk(outfit):
		"pad":
			d.tw += 1
			d.td += 1
			d.aw += 1
			if d.lx - (d.lw + 1) * 0.5 >= -0.01:
				d.thigh_w = d.lw + 1
		"goalie":
			d.tw += 2
			d.td += 2
			d.aw += 1
			d.lx += 1.0
			d.lw += 1
			d.thigh_w = d.lw
			d.ld += 1
		"parka":
			d.tw += 1
			d.td += 1
	d.knee = foot + b.shin
	d.hip = d.knee + b.thigh
	d.neck = d.hip + b.torso
	d.shoulder = d.neck - 0.5
	d.elbow = d.shoulder - b.upper
	d.hand0 = d.elbow - b.fore
	d.ax = d.tw * 0.5 + d.aw * 0.5
	return d


# ================================================================ parts

## One rigid piece of the body on its own voxel grid. Voxel (i, j, k) covers
## origin + (i, j, k) * cell, in V, model space. `joint`/`length` are what
## the shader bends it by (see _commit()).
class Part:
	var id: int
	var origin: Vector3
	var cell := Vector3.ONE
	var joint := Vector3.ZERO
	var length := 0.0
	var vox := {}  # Vector3i -> [slot, Color]

	func _init(id_: int, origin_: Vector3, joint_ := Vector3.ZERO, length_ := 0.0, cell_ := Vector3.ONE) -> void:
		id = id_
		origin = origin_
		joint = joint_
		length = length_
		cell = cell_

	func box(x: int, y: int, z: int, sx: int, sy: int, sz: int, mat: Array) -> Part:
		for i in sx:
			for j in sy:
				for k in sz:
					vox[Vector3i(x + i, y + j, z + k)] = mat
		return self

	## Recolours voxels that exist; never adds any.
	func paint(x: int, y: int, z: int, sx: int, sy: int, sz: int, mat: Array) -> Part:
		for i in sx:
			for j in sy:
				for k in sz:
					var p := Vector3i(x + i, y + j, z + k)
					if vox.has(p):
						vox[p] = mat
		return self

	## Recolours the frontmost voxel of each column in x/y range (belly or not).
	func paint_front(x: int, y: int, sx: int, sy: int, mat: Array) -> Part:
		for i in sx:
			for j in sy:
				for k in range(-4, 12):
					var p := Vector3i(x + i, y + j, k)
					if vox.has(p):
						vox[p] = mat
						break
		return self


static func _m(slot: int, shade := 1.0) -> Array:
	return [slot, Color(shade, shade, shade)]


static func _fx(c: Color) -> Array:
	return [FIXED, c]


static func _layer_parts(layer: String) -> Array:
	var f := layer.split(":")
	match f[0]:
		"B": return _body(f[1], f[2], f[3], int(f[4]))
		"H": return _head(f[1], f[2], f[3], f[4])
		"I": return _item(f[1], f[2], f[3], f[4])
	push_error("PeopleArt: bad key '%s'" % layer)
	return []


## Rows of the torso grid: from one voxel under the hip to the neck.
static func _torso_rows(d: Dictionary) -> int:
	return roundi(d.neck - d.hip + 1.0)


# ---------------------------------------------------------------- body layer

static func _body(band: String, build: String, outfit: String, lift: int) -> Array:
	var d := _dims(band, build, outfit)
	d.lift = lift
	var parts: Array = []
	var st := _style(outfit)
	if lift and not outfit in SKATE_OUTFITS:
		st.shoe = _fx(_BOOT)  # rental skates at public skate
	var hipj := Vector3(0, d.hip, 0)
	# torso: two rows of trousers (the pelvis), then the shirt
	var rows := _torso_rows(d)
	var torso := Part.new(TORSO, Vector3(-d.tw * 0.5, d.hip - 1.0, -d.td * 0.5), hipj)
	torso.box(0, 0, 0, d.tw, rows, d.td, st.shirt)
	torso.box(0, 0, 0, d.tw, 2, d.td, st.legs)
	if d.belly:
		torso.box(1, 2, -1, d.tw - 2, 4, 1, st.shirt)
	parts.append(torso)
	# legs: thigh from the knee to just inside the pelvis; shin and foot
	for side: int in [-1, 1]:
		var r := side > 0
		var x: float = side * d.lx
		var hj := Vector3(x, d.hip, 0)
		var th_rows := ceili(d.hip + 0.5 - d.knee)
		var thigh := Part.new(THIGH_R if r else THIGH_L, Vector3(x - d.thigh_w * 0.5, d.knee, -d.ld * 0.5), hj, d.hip - d.knee)
		thigh.box(0, 0, 0, d.thigh_w, th_rows, d.ld, st.thigh)
		parts.append(thigh)
		var sh_rows := roundi(d.knee - d.foot)
		var shin := Part.new(SHIN_R if r else SHIN_L, Vector3(x - d.lw * 0.5, d.foot, -d.ld * 0.5), hj, d.hip - d.knee)
		shin.box(0, 0, 0, d.lw, sh_rows, d.ld, st.legs)
		parts.append(shin)
		parts.append_array(_foot(d, x, r, hj, st))
		# arms: upper from the elbow to the neck, forearm and hand below
		var ax: float = side * d.ax
		var sj := Vector3(ax, d.shoulder, 0)
		var up_rows := maxi(2, roundi(d.neck - d.elbow))
		var upper := Part.new(UPPER_R if r else UPPER_L, Vector3(ax - d.aw * 0.5, d.elbow, -d.aw * 0.5), sj, d.shoulder - d.elbow,
			Vector3(1, (d.neck - d.elbow) / up_rows, 1))
		upper.box(0, 0, 0, d.aw, up_rows, d.aw, st.upper)
		parts.append(upper)
		var fo_rows := maxi(3, roundi(d.elbow - d.hand0))
		var fore := Part.new(FORE_R if r else FORE_L, Vector3(ax - d.aw * 0.5, d.hand0, -d.aw * 0.5), sj, d.shoulder - d.elbow,
			Vector3(1, (d.elbow - d.hand0) / fo_rows, 1))
		fore.box(0, 0, 0, d.aw, fo_rows, d.aw, st.fore)
		fore.box(0, 0, 0, d.aw, 2 if fo_rows > 3 else 1, d.aw, st.hand)
		parts.append(fore)
		_dress_limbs(outfit, d, side, thigh, shin, upper, fore, st)
	_dress_torso(outfit, d, torso, parts, st)
	parts.append_array(_pose_props(d))
	return parts


## Slot or colour for each body region, per outfit.
static func _style(outfit: String) -> Dictionary:
	var p := _m(PRIMARY)
	var s := _m(SECONDARY)
	var a := _m(ACCENT)
	var skin := _m(SKIN)
	var st := {"shirt": p, "upper": p, "fore": p, "hand": skin, "legs": a, "thigh": a, "shoe": _fx(_SNEAKER)}
	match outfit:
		"parka":
			st.shoe = _fx(_WORK_BOOT)
		"hockey_gear":
			st.legs = p  # socks over the shin pads
			st.hand = _fx(_GLOVE)
			st.shoe = _fx(_BOOT)
		"goalie_gear":
			st.legs = _fx(_PAD)
			st.thigh = _fx(_PAD)
			st.hand = _fx(_GLOVE)
			st.shoe = _fx(_BOOT)
		"figure_dress":
			st.legs = _m(SKIN, 0.93)  # skin-tone tights
			st.thigh = st.legs
			st.shoe = _fx(_FIG_BOOT)
		"figure_warmup":
			st.legs = _fx(_BLACK)
			st.thigh = st.legs
			st.shoe = _fx(_FIG_BOOT)
		"ref_stripes":
			st.shirt = _fx(_WHITE)
			st.upper = _fx(_WHITE)
			st.fore = _fx(_WHITE)
			st.legs = _fx(_BLACK)
			st.thigh = st.legs
			st.shoe = _fx(_BOOT)
		"coach_tracksuit":
			st.legs = _m(PRIMARY, 0.9)
			st.thigh = st.legs
		"staff_polo":
			st.fore = skin  # short sleeves
			st.shoe = _fx(_SHOE)
		"canteen_apron":
			st.shoe = _fx(_SHOE)
		"shop_apron":
			st.fore = skin  # sleeves rolled up
			st.shoe = _fx(_BROWN_SHOE)
		"coveralls":
			st.legs = p
			st.thigh = p
			st.shoe = _fx(_WORK_BOOT)
		"work_jacket":
			st.shoe = _fx(_WORK_BOOT)
		"suit":
			st.legs = _m(PRIMARY, 0.85)
			st.thigh = st.legs
			st.shoe = _fx(_SHOE)
		"cardigan":
			st.shoe = _fx(_BROWN_SHOE)
		"school_jacket":
			st.upper = s
			st.fore = s
	return st


## Shoe or skate under one shin: a sole half a voxel thick with the toe out
## front, or a skate boot on a steel blade.
static func _foot(d: Dictionary, x: float, r: bool, hj: Vector3, st: Dictionary) -> Array:
	var id := SHIN_R if r else SHIN_L
	var out: Array = []
	var L: float = d.hip - d.knee
	var z0: float = -d.ld * 0.5
	if d.lift:
		# boot: the bottom shin rows, a voxel of boot under them with the toe,
		# then the blade, hanging below the pivot (the shader lifts skaters)
		var drop := SHOE - SKATE
		var boot := Part.new(id, Vector3(x - d.lw * 0.5, drop + 0.5, z0 - 1.0), hj, L)
		boot.box(0, 0, 0, d.lw, 1, d.ld + 1, st.shoe)
		out.append(boot)
		var blade := Part.new(id, Vector3(x - 0.5, drop, z0 - 1.5), hj, L, Vector3(1, 0.5, 1))
		blade.box(0, 0, 0, 1, 1, d.ld + 2, _fx(_STEEL))
		out.append(blade)
	else:
		var sole := Part.new(id, Vector3(x - d.lw * 0.5, 0.0, z0 - 1.0), hj, L, Vector3(1, SHOE, 1))
		sole.box(0, 0, 0, d.lw, 1, d.ld + 1, st.shoe)
		out.append(sole)
		var toe := Part.new(id, Vector3(x - d.lw * 0.5, SHOE, z0 - 1.0), hj, L)
		toe.box(0, 0, 0, d.lw, 1, 1, st.shoe)
		out.append(toe)
	return out


## Outfit details on the limbs: shoe tops, stripes, pads, gloves.
static func _dress_limbs(outfit: String, d: Dictionary, side: int, thigh: Part, shin: Part, upper: Part, fore: Part, st: Dictionary) -> void:
	var outer: int = d.aw - 1 if side > 0 else 0
	var leg_out: int = d.lw - 1 if side > 0 else 0
	# shoe and skate-boot tops on the shin
	shin.paint(0, 0, -1, d.lw, 2 if d.lift else 1, d.ld + 1, st.shoe)
	if d.lift and outfit in ["figure_dress"]:
		shin.paint(0, 2, 0, d.lw, 1, d.ld, st.shoe)
	match outfit:
		"casual":
			upper.paint(0, 2, 0, d.aw, 1, d.aw, _m(SECONDARY))
		"hockey_gear":
			shin.paint(0, 3, 0, d.lw, 1, d.ld, _m(SECONDARY))
			shin.paint(0, 4, 0, d.lw, 1, d.ld, _fx(_WHITE))
			thigh.paint(leg_out, 2, 0, 1, 3, d.ld, _m(SECONDARY))
			fore.paint(0, 2, 0, d.aw, 1, d.aw, _m(PRIMARY, 0.6))  # glove cuff
			upper.paint(0, 1, 0, d.aw, 1, d.aw, _m(SECONDARY))
		"goalie_gear":
			for y in [1, 3]:
				shin.paint(0, y + 1, 0, d.lw, 1, d.ld, _m(PRIMARY))
			thigh.paint(0, 2, 0, d.thigh_w, 1, d.ld, _m(PRIMARY))
			if side > 0:  # blocker on the right, catcher on the left
				fore.box(d.aw, -1, -1, 1, 5, d.aw + 2, _fx(_PAD))
				fore.paint(d.aw, 1, -1, 1, 1, d.aw + 2, _m(PRIMARY))
			else:
				fore.box(-1, -1, -1, d.aw + 2, 3, d.aw + 2, _m(PRIMARY, 0.75))
				fore.box(0, 2, -1, d.aw, 1, 1, _fx(_GLOVE))
		"figure_dress", "figure_warmup":
			upper.paint(outer, 0, 0, 1, 9, d.aw, _m(SECONDARY) if outfit == "figure_warmup" else _m(PRIMARY))
		"ref_stripes":
			for p in [upper, fore]:
				for x in d.aw:
					if (x + (1 if side > 0 else 0)) % 2 == 0:
						p.paint(x, 0, 0, 1, 9, d.aw, _fx(_BLACK))
			fore.paint(0, 0, 0, d.aw, 2, d.aw, _m(SKIN))
			upper.paint(0, 2, 0, d.aw, 1, d.aw, _fx(_ORANGE))  # armband
		"coach_tracksuit":
			upper.paint(outer, 0, 0, 1, 9, d.aw, _m(SECONDARY))
			fore.paint(outer, 2, 0, 1, 9, d.aw, _m(SECONDARY))
			shin.paint(leg_out, 1, 0, 1, 9, d.ld, _m(SECONDARY))
			thigh.paint(leg_out, 0, 0, 1, 9, d.ld, _m(SECONDARY))
		"staff_polo":
			upper.paint(0, 0, 0, d.aw, 1, d.aw, _m(SECONDARY))  # sleeve hem
		"coveralls":
			shin.paint(0, 2, 0, d.lw, 1, d.ld, _m(SECONDARY))  # reflective band
		"school_jacket", "team_jacket":
			fore.paint(0, 2, 0, d.aw, 1, d.aw, _m(SECONDARY, 0.8))  # ribbed cuff
		"work_jacket":
			fore.paint(0, 2, 0, d.aw, 1, d.aw, _m(PRIMARY, 0.8))
		"parka":
			fore.paint(0, 2, 0, d.aw, 1, d.aw, _m(SECONDARY))


## Outfit details on the torso.
static func _dress_torso(outfit: String, d: Dictionary, t: Part, parts: Array, st: Dictionary) -> void:
	var rows := _torso_rows(d)
	var tw: int = d.tw
	var td: int = d.td
	var top := rows - 1
	var mid := tw / 2  # left of centre on even widths
	var cw := 1 if tw % 2 else 2  # centre columns
	var cx := (tw - cw) / 2
	match outfit:
		"casual":
			t.box(0, top - 3, 0, tw, 1, td, _m(SECONDARY))  # sweater band
			t.box(0, 2, 0, tw, 1, td, _fx(Color("3a2e26")))  # belt
		"parka":
			# long coat over the hips, zip, pockets, fur-trimmed hood
			t.box(-0, -2, 0, tw, 4, td, _m(PRIMARY))
			t.paint_front(cx, -2, cw, rows + 2, _fx(Color("2b2d33")))
			t.paint_front(1, 1, 1, 1, _m(PRIMARY, 0.75))
			t.paint_front(tw - 2, 1, 1, 1, _m(PRIMARY, 0.75))
			t.box(1, top, 0, tw - 2, 1, 1, _m(SECONDARY))  # collar trim
			parts.append(Part.new(TORSO, Vector3(-(tw - 2) * 0.5, d.neck - 1.5, td * 0.5)).box(0, 0, 0, tw - 2, 2, 1, _m(SECONDARY)))
		"hoodie":
			t.paint_front(1, 2, tw - 2, 2, _m(PRIMARY, 0.82))  # kangaroo pocket
			t.paint_front(mid - 1, top - 1, 1, 1, _fx(_WHITE))
			t.paint_front(mid + (1 if tw % 2 else 0), top - 1, 1, 1, _fx(_WHITE))
			parts.append(Part.new(TORSO, Vector3(-(tw - 2) * 0.5, d.neck - 1.0, td * 0.5)).box(0, 0, 0, tw - 2, 2, 1, _m(PRIMARY, 0.9)))
		"team_jacket":
			t.box(0, top - 1, 0, tw, 2, td, _m(SECONDARY))  # yoke
			t.paint_front(cx, 4, cw, 2, _m(SECONDARY))  # crest
			t.box(0, 2, 0, tw, 1, td, _m(SECONDARY, 0.8))  # hem
		"school_jacket":
			t.box(0, 2, 0, tw, 1, td, _m(SECONDARY))
			t.box(0, top, 0, tw, 1, td, _m(SECONDARY))
			t.paint_front(1, top - 3, 2, 2, _m(SECONDARY))  # letter on the chest
		"hockey_gear":
			t.box(0, 3, 0, tw, 2, td, _m(SECONDARY))  # hem stripes
			t.box(0, 4, 0, tw, 1, td, _fx(_WHITE))
			t.box(0, top, 0, tw, 1, td, _m(PRIMARY, 0.72))  # yoke
			t.paint_front(cx, top - 3, cw, 2, _m(SECONDARY))  # crest
			t.box(-0, 0, 0, tw, 3, td, _m(ACCENT))  # pants
			t.box(0, 1, 0, 1, 1, td, _m(SECONDARY))
			t.box(tw - 1, 1, 0, 1, 1, td, _m(SECONDARY))
		"goalie_gear":
			t.box(0, 3, 0, tw, 2, td, _m(SECONDARY))
			t.box(0, top, 0, tw, 1, td, _m(PRIMARY, 0.72))
			t.paint_front(cx, top - 3, cw, 2, _m(SECONDARY))
			t.box(0, 0, 0, tw, 3, td, _m(ACCENT))
		"figure_dress":
			t.box(0, 0, 0, tw, 2, td, _m(PRIMARY))
			t.box(-1, 0, -1, tw + 2, 1, td + 2, _m(PRIMARY))  # skirt
			t.box(-1, -1, -1, tw + 2, 1, td + 2, _m(SECONDARY))
			t.paint_front(cx, top - 2, cw, 1, _m(SECONDARY))  # sequins
			t.paint_front(1, top - 4, 1, 1, _m(SECONDARY))
			t.paint_front(tw - 2, top - 4, 1, 1, _m(SECONDARY))
		"figure_warmup":
			t.paint_front(cx, 2, cw, rows, _m(SECONDARY))  # zip stripe
			t.box(0, 0, 0, tw, 2, td, _fx(_BLACK))
		"ref_stripes":
			for x in tw:
				if x % 2 == 1:
					t.paint(x, 2, 0, 1, rows, td, _fx(_BLACK))
			t.box(0, top, 0, tw, 1, td, _fx(_BLACK))  # collar
		"coach_tracksuit":
			t.paint_front(cx, 2, cw, rows, _m(SECONDARY, 0.9))  # zip
			t.box(0, top, 0, tw, 1, td, _m(SECONDARY))
		"staff_polo":
			t.box(0, top, 0, tw, 1, td, _m(SECONDARY))  # collar
			t.paint_front(cx, top - 2, cw, 2, _m(SECONDARY))  # placket
			t.paint_front(1, top - 3, 1, 1, _fx(_WHITE))  # name badge
			t.box(0, 2, 0, tw, 1, td, _fx(Color("3a2e26")))
		"canteen_apron", "shop_apron":
			var ap := _m(SECONDARY) if outfit == "canteen_apron" else _m(SECONDARY, 0.85)
			var bib := top - 1 if outfit == "shop_apron" else top - 3
			t.paint_front(1, 0, tw - 2, bib, ap)
			t.box(1, -3, -1, tw - 2, 3, 1, ap)  # skirt of the apron
			t.paint_front(cx, top - 1, cw, 2, ap)  # neck strap
			if outfit == "shop_apron":
				t.paint_front(1, 3, tw - 2, 1, _m(SECONDARY, 0.65))  # pocket
				t.paint_front(2, 4, 1, 1, _fx(Color("d9a62e")))  # a pencil
		"coveralls":
			t.box(0, top - 3, 0, tw, 1, td, _m(SECONDARY))  # reflective band
			t.paint_front(cx, 0, cw, rows, _m(PRIMARY, 0.8))  # zip
			t.paint_front(1, top - 2, 2, 1, _m(PRIMARY, 0.75))  # chest pocket
		"suit":
			t.paint_front(cx - (1 if cw == 1 else 0), top - 2, cw + (2 if cw == 1 else 0), 3, _fx(_WHITE))
			t.paint_front(cx, top - 4, cw, 4, _m(SECONDARY))  # tie
			t.paint_front(cx, top, cw, 1, _fx(_WHITE))
		"work_jacket":
			# canvas chore coat: corduroy collar, button placket, chest pockets
			t.box(0, 1, 0, tw, rows - 1, td, _m(PRIMARY))
			t.box(0, top, 0, tw, 1, td, _m(SECONDARY))
			t.paint_front(cx, 1, cw, rows - 2, _m(PRIMARY, 0.72))
			t.paint_front(1, top - 3, 1, 2, _m(PRIMARY, 0.82))
			t.paint_front(tw - 2, top - 3, 1, 2, _m(PRIMARY, 0.82))
			t.paint_front(1, 2, 1, 1, _m(PRIMARY, 0.82))
			t.paint_front(tw - 2, 2, 1, 1, _m(PRIMARY, 0.82))
		"cardigan":
			t.paint_front(cx, 2, cw, rows, _m(SECONDARY))  # shirt showing
			t.paint_front(cx - 1, 4, 1, 1, _fx(Color("d9d4c7")))  # buttons
			t.paint_front(cx - 1, 6, 1, 1, _fx(Color("d9d4c7")))


## The box a CARRY pose holds and the phone a QUEUE pose checks. Every body
## has them; the shader collapses them to a point in the other poses.
static func _pose_props(d: Dictionary) -> Array:
	var out: Array = []
	# hands at the CARRY angles (shoulder 50 deg forward, elbow 40 more)
	var up: float = d.shoulder - d.elbow
	var fore: float = d.elbow - d.hand0
	var elbow := Vector3(0, d.shoulder - up * cos(deg_to_rad(50.0)), -up * sin(deg_to_rad(50.0)))
	var bw: int = maxi(3, roundi(d.ax * 2.0 - d.aw))
	var bh := 3 if d.band in ["teen", "adult"] else 2
	var bd := maxi(2, roundi(fore - 1.0))
	var c := Vector3(0, elbow.y + d.aw * 0.5 + bh * 0.5, elbow.z - fore * 0.55)
	var box := Part.new(BOX, c - Vector3(bw, bh, bd) * 0.5, c)
	box.box(0, 0, 0, bw, bh, bd, _fx(_CARD))
	box.paint(0, bh - 1, 0, bw, 1, bd, _fx(_CARD.lightened(0.15)))
	out.append(box)
	var sj := Vector3(-d.ax, d.shoulder, 0)
	var phone := Part.new(PHONE, Vector3(-d.ax - 0.5, d.hand0 + 0.5, -d.aw * 0.5 - 1.0), sj, d.shoulder - d.elbow)
	phone.box(0, 0, 0, 1, 2, 1, _fx(Color("16171a")))
	out.append(phone)
	return out


# ---------------------------------------------------------------- head layer

static func _head(band: String, hair: String, hat: String, face: String) -> Array:
	var d := _dims(band, _BUILDS_OF[band][0], "casual")
	var nj := Vector3(0, d.neck, 0)
	var h := Part.new(HEAD_PART, Vector3(-2.5, d.neck, -2.5), nj)
	var hr := _m(HAIR)
	h.box(0, 0, 0, 5, 5, 5, _m(SKIN))
	h.box(2, 1, -1, 1, 1, 1, _m(SKIN, 0.94))  # nose
	h.paint(1, 2, 0, 1, 1, 1, _fx(_EYE))
	h.paint(3, 2, 0, 1, 1, 1, _fx(_EYE))
	var capped := hat == "none" or hat == "headset"
	match hair:
		"short", "long", "bun", "ponytail", "mullet":
			if capped:
				h.paint(0, 4, 0, 5, 1, 5, hr)
				h.box(0, 5, 0, 5, 1, 5, hr)
			h.paint(0, 2, 4, 5, 3, 1, hr)
			h.paint(0, 3, 1, 1, 2, 4, hr)
			h.paint(4, 3, 1, 1, 2, 4, hr)
		"buzz":
			h.paint(0, 4, 0, 5, 1, 5, hr)
			h.paint(0, 3, 4, 5, 1, 1, hr)
		"bald":
			h.paint(0, 2, 4, 5, 2, 1, hr)
			h.paint(0, 2, 2, 1, 2, 3, hr)
			h.paint(4, 2, 2, 1, 2, 3, hr)
		"curly":
			h.box(-1, 3, 0, 7, 3, 6, hr)
			h.box(-1, 1, 4, 7, 2, 2, hr)
			h.box(0, 6, 1, 5, 1, 4, hr)
	match hair:
		"long":
			h.box(0, 0, 5, 5, 6 if capped else 4, 1, hr)
			h.box(-1, 1, 1, 1, 4, 5, hr)
			h.box(5, 1, 1, 1, 4, 5, hr)
			if capped:
				h.box(-1, 5, 1, 7, 1, 5, hr)
		"bun":
			h.box(1, 6, 2, 3, 2, 2, hr)
		"ponytail":
			h.box(2, 0, 5, 1, 5, 1, hr)
			h.box(2, 3, 6, 1, 1, 1, hr)
		"mullet":
			h.box(1, 0, 5, 3, 4, 1, hr)
	match hat:
		"toque":
			h.box(0, 3, 0, 5, 2, 5, _m(SECONDARY, 0.82))  # cuff
			h.box(0, 5, 0, 5, 1, 5, _m(SECONDARY))
			h.box(1, 6, 1, 3, 1, 3, _m(SECONDARY))
			h.box(2, 7, 2, 1, 1, 1, _m(PRIMARY))  # pompom
		"ball_cap":
			h.box(0, 4, 0, 5, 2, 5, _m(SECONDARY))
			h.box(1, 4, -2, 3, 1, 2, _m(SECONDARY, 0.8))  # brim
			h.paint(2, 4, 0, 1, 1, 1, _m(PRIMARY))  # logo
		"helmet":
			h.box(-1, 3, 0, 7, 3, 6, _m(ACCENT))
			h.box(0, 6, 1, 5, 1, 4, _m(ACCENT))
			if band == "adult":
				h.box(0, 2, -1, 5, 1, 1, _fx(Color("a9d3e0")))  # visor
			else:
				for x in 5:  # cage
					for y in 3:
						if x % 2 == 0 or y == 0:
							h.box(x, y, -1, 1, 1, 1, _fx(_CAGE))
		"mask":
			h.box(0, 0, 0, 5, 6, 5, _fx(_PAD))
			h.box(-1, 2, 1, 7, 3, 4, _fx(_PAD))
			h.paint(0, 5, 0, 5, 1, 5, _m(PRIMARY))
			for x in 5:
				for y in 4:
					if x % 2 == 0 or y % 2 == 0:
						h.box(x, y, -1, 1, 1, 1, _fx(_CAGE if (x + y) % 2 == 0 else Models.CAGE_DARK))
		"headset":
			var dark := _fx(Color("26272b"))
			var y_top := 6 if hair in ["short", "long", "bun", "ponytail", "mullet", "curly"] else 5
			h.box(-1, 2, 1, 1, 2, 2, dark)
			h.box(5, 2, 1, 1, 2, 2, dark)
			h.box(-1, 4, 2, 1, y_top - 4, 1, dark)
			h.box(5, 4, 2, 1, y_top - 4, 1, dark)
			h.box(0, y_top, 2, 5, 1, 1, dark)
			h.box(-1, 1, -1, 1, 1, 2, dark)  # mic
	match face:
		"glasses":
			for x in 5:
				h.box(x, 2, -1, 1, 1, 1, _fx(Color("a9d3e0")) if x == 1 or x == 3 else _fx(Color("1d1d22")))
		"reading_glasses":
			h.box(1, 1, -1, 1, 1, 1, _fx(Color("c9a66b")))
			h.box(3, 1, -1, 1, 1, 1, _fx(Color("c9a66b")))
	return [h]


# ---------------------------------------------------------------- item layer

static func _item(band: String, width: String, bulk: String, item: String) -> Array:
	var outfit: String = {"pad": "hockey_gear", "goalie": "goalie_gear", "parka": "parka"}.get(bulk, "casual")
	var builds: Array = _BUILDS_OF[band]
	# narrow: the band's first build; wide: its stockiest-but-one (adult stocky)
	var build: String = builds[0] if width == "narrow" else builds[mini(2, builds.size() - 1)]
	if band == "adult" and width == "narrow":
		build = "average"
	var d := _dims(band, build, outfit)
	var sj := Vector3(d.ax, d.shoulder, 0)
	var L: float = d.shoulder - d.elbow
	var hx: float = d.ax
	var hy: float = d.hand0
	var fz: float = -d.aw * 0.5  # front of the hand
	var held := func(o: Vector3) -> Part: return Part.new(HELD, o, sj, L)
	var tw: int = d.tw
	var td: int = d.td
	var top: float = d.neck
	match item:
		"coffee":
			var p: Part = held.call(Vector3(hx - 1, hy, fz - 2))
			p.box(0, 0, 0, 2, 3, 2, _fx(Color("f2f0ea")))
			p.box(0, 1, 0, 2, 1, 2, _fx(Color("8a5a3a")))
			p.box(0, 3, 0, 2, 1, 2, _fx(Color("3a3a3a")))
			return [p]
		"foam_finger":
			var p: Part = held.call(Vector3(hx - 1.5, hy - 2, fz - 1))
			p.box(0, 0, 0, 3, 3, 1, _m(PRIMARY))
			p.box(1, -3, 0, 1, 3, 1, _m(PRIMARY))
			p.paint(0, 2, 0, 3, 1, 1, _m(SECONDARY))
			return [p]
		"cowbell":
			var p: Part = held.call(Vector3(hx - 1, hy - 3, fz - 1))
			p.box(0, 0, 0, 2, 3, 2, _fx(Color("b8a26a")))
			p.box(0, 0, 0, 2, 1, 2, _fx(Color("8a7a4a")))
			return [p]
		"clipboard":
			var p: Part = held.call(Vector3(hx - 1.5, hy - 1, fz - 1))
			p.box(0, 0, 0, 3, 4, 1, _fx(Color("9a6b3f")))
			p.paint(0, 0, 0, 3, 3, 1, _fx(Color("f2f0ea")))
			p.paint(1, 3, 0, 1, 1, 1, _fx(_STEEL))
			return [p]
		"camera":
			var p: Part = held.call(Vector3(hx - 1.5, hy, fz - 2))
			p.box(0, 0, 0, 3, 2, 2, _fx(Color("1d1d22")))
			p.box(1, 0, -1, 1, 1, 1, _fx(Color("3e4249")))
			return [p]
		"thermos":
			var p: Part = held.call(Vector3(hx - 1, hy - 1, fz - 2))
			p.box(0, 0, 0, 2, 4, 2, _m(SECONDARY))
			p.box(0, 4, 0, 2, 1, 2, _fx(_STEEL))
			return [p]
		"programme":
			var p: Part = held.call(Vector3(hx - 1, hy, fz - 1))
			p.box(0, 0, 0, 2, 3, 1, _m(SECONDARY))
			p.paint(0, 2, 0, 2, 1, 1, _fx(_WHITE))
			return [p]
		"sign":
			# board hangs below the fist at rest and rises overhead in a cheer;
			# small kids get a shorter stick so it clears the floor
			var y0 := maxf(hy - 9.0, 0.5)
			var p: Part = held.call(Vector3(hx - 0.5, y0 + 4.0, fz - 1))
			p.box(0, 0, 0, 1, maxi(2, roundi(hy - y0 - 3.0)), 1, _fx(Color("9a6b3f")))
			var b: Part = held.call(Vector3(hx - 3.5, y0, fz - 2))
			b.box(0, 0, 0, 7, 4, 1, _fx(_WHITE))
			b.paint(0, 0, 0, 7, 1, 1, _m(SECONDARY))
			b.paint(0, 3, 0, 7, 1, 1, _m(SECONDARY))
			b.paint(2, 1, 0, 1, 2, 1, _m(PRIMARY))
			b.paint(4, 1, 0, 1, 2, 1, _m(PRIMARY))
			return [p, b]
		"stick":
			var p: Part = held.call(Vector3(hx - 0.5, 0.0, fz - 1))
			p.box(0, 0, 0, 1, roundi(hy) + 3, 1, _fx(Color("1b1b1e")))
			p.box(0, 0, -3, 1, 1, 3, _fx(Models.TAPE))
			p.paint(0, roundi(hy) + 2, 0, 1, 1, 1, _fx(Models.TAPE))
			return [p]
		"knitting":
			var p: Part = held.call(Vector3(hx - 2, hy, fz - 1))
			p.box(0, 0, 0, 3, 2, 1, _m(SECONDARY))
			p.box(0, 2, 0, 1, 2, 1, _fx(Color("d9d4c7")))
			p.box(2, 2, 0, 1, 2, 1, _fx(Color("d9d4c7")))
			p.box(3, -1, -1, 2, 2, 2, _m(SECONDARY, 0.85))  # the ball
			return [p]
		"scarf":
			var ws := 6 if tw != 6 else 7
			var ds := td + 2 if td != 3 else 6
			var s := Part.new(TORSO, Vector3(-ws * 0.5, top - 1.0, -ds * 0.5))
			s.box(0, 0, 0, ws, 2, ds, _m(SECONDARY))
			s.paint(0, 0, 0, ws, 1, ds, _m(SECONDARY, 0.82))
			s.box(1, -4, 0, 2, 4, 1, _m(SECONDARY))
			s.paint(1, -4, 0, 2, 1, 1, _m(PRIMARY))
			return [s]
		"whistle":
			var w := Part.new(TORSO, Vector3(-1.5, top - 4.0, -td * 0.5 - 1.0))
			w.box(0, 1, 0, 1, 3, 1, _fx(_BLACK))
			w.box(2, 1, 0, 1, 3, 1, _fx(_BLACK))
			w.box(0, 0, 0, 3, 1, 1, _fx(_STEEL))
			return [w]
		"blanket":
			var b := Part.new(TORSO, Vector3(-(tw + 2) * 0.5, d.hip - 2.0, td * 0.5))
			var hgt := roundi(top - d.hip + 3.0)
			b.box(0, 0, 0, tw + 2, hgt, 1, _m(SECONDARY))
			b.box(0, hgt - 1, -2, tw + 2, 1, 2, _m(SECONDARY))
			for y in range(1, hgt, 3):
				b.paint(0, y, 0, tw + 2, 1, 1, _m(SECONDARY, 0.7))
			for x in range(1, tw + 2, 3):
				b.paint(x, 0, 0, 1, hgt - 1, 1, _m(SECONDARY, 0.7))
			return [b]
		"skates_over_shoulder":
			var x := tw * 0.5 - 2.0
			var s := Part.new(TORSO, Vector3(x, top - 4.0, -td * 0.5 - 2.0))
			s.box(0, 0, 0, 2, 3, 2, _fx(_BOOT))
			s.box(0, -1, 0, 2, 1, 2, _fx(_STEEL))
			s.box(0, 0, td + 2, 2, 3, 2, _fx(_BOOT))
			s.box(0, -1, td + 2, 2, 1, 2, _fx(_STEEL))
			s.box(0, 4, 1, 1, 1, td + 2, _fx(Models.TAPE))  # laces over the shoulder
			s.box(0, 3, 1, 1, 1, 1, _fx(Models.TAPE))
			s.box(0, 3, td + 2, 1, 1, 1, _fx(Models.TAPE))
			return [s]
	return []


# ================================================================ meshing

const _DIRS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]


## Greedy-meshes every part into one indexed surface. Per vertex:
##   VERTEX, NORMAL   rest pose, metres
##   COLOR            fixed colour (slot 0) or a shade multiplier for the slot
##   UV               (slot, part id)
##   UV2              (hip joint height, thigh length), metres
##   CUSTOM0          (joint x, y, z, upper limb length), metres: the hip for
##                    legs, the shoulder for arms and held things, the neck
##                    for the head; the knee/elbow is joint - (0, length, 0)
static func _commit(parts: Array, hip: float, thigh: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var cus := PackedFloat32Array()
	var idx := PackedInt32Array()
	for p0 in parts:
		var p: Part = p0
		var uv2 := Vector2(hip, thigh) * V
		var cu := [p.joint.x * V, p.joint.y * V, p.joint.z * V, p.length * V]
		for i in 6:
			var dir: Vector3i = _DIRS[i]
			var dd := 0 if dir.x != 0 else (1 if dir.y != 0 else 2)
			var ua := (dd + 1) % 3
			var va := (dd + 2) % 3
			var positive := dir[dd] > 0
			var layers := {}
			for key in p.vox:
				var q: Vector3i = key
				if p.vox.has(q + dir):
					continue
				var k: int = q[dd]
				if not layers.has(k):
					layers[k] = {}
				layers[k][Vector2i(q[ua], q[va])] = p.vox[q]
			var n := Vector3(dir)
			for k in layers:
				var mask: Dictionary = layers[k]
				var keys := mask.keys()
				keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
				var used := {}
				for key in keys:
					var s: Vector2i = key
					if used.has(s):
						continue
					var mat: Array = mask[s]
					var w := 1
					while _same(mask, s + Vector2i(w, 0), mat) and not used.has(s + Vector2i(w, 0)):
						w += 1
					var h := 1
					var grow := true
					while grow:
						for x in w:
							var q2 := s + Vector2i(x, h)
							if not _same(mask, q2, mat) or used.has(q2):
								grow = false
								break
						if grow:
							h += 1
					for x in w:
						for y in h:
							used[s + Vector2i(x, y)] = true
					var plane := float(k + 1) if positive else float(k)
					var corners: Array[Vector3] = []
					for uv in [Vector2(s.x, s.y), Vector2(s.x + w, s.y), Vector2(s.x + w, s.y + h), Vector2(s.x, s.y + h)]:
						var v3 := Vector3.ZERO
						v3[dd] = plane
						v3[ua] = uv.x
						v3[va] = uv.y
						corners.append((p.origin + v3 * p.cell) * V)
					var base := verts.size()
					for c in corners:
						verts.append(c)
						norms.append(n)
						cols.append(mat[1])
						uvs.append(Vector2(mat[0], p.id))
						uv2s.append(uv2)
						cus.append_array(cu)
					if (corners[1] - corners[0]).cross(corners[2] - corners[0]).dot(n) > 0.0:
						idx.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
					else:
						idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var m := ArrayMesh.new()
	if verts.is_empty():
		return m
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_CUSTOM0] = cus
	arrays[Mesh.ARRAY_INDEX] = idx
	var fmt := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, fmt)
	m.surface_set_material(0, material())
	# room for every pose: arms overhead, a cheer jump, a fall, the tallest scale
	m.custom_aabb = AABB(Vector3(-1.5, -0.3, -1.5), Vector3(3.0, 3.4, 3.0))
	return m


static func _same(mask: Dictionary, at: Vector2i, mat: Array) -> bool:
	if not mask.has(at):
		return false
	var o: Array = mask[at]
	return o[0] == mat[0] and o[1] == mat[1]


# ================================================================ shader

## Poses the body per vertex from INSTANCE_CUSTOM (see instance_data()).
## Chain: shin about the knee, then the leg about the hip; forearm about the
## elbow, then the arm about the shoulder; head about the neck; the upper body
## about the waist; then the root (bob, jump, sit, spin) and the scale.
const _SHADER := """
shader_type spatial;
render_mode cull_back;

uniform vec3 palette[84];
uniform float seat_height = 0.455;
uniform float time_scale = 1.0;
// gait, shared with SkaterRig through AnimTuning (set in PeopleArt.material())
uniform float walk_cadence = 1.8;      // steps per second at walk_speed
uniform float walk_cadence_run = 2.8;
uniform float walk_duty = 0.62;        // share of the cycle a foot is planted
uniform float walk_duty_run = 0.38;
uniform float walk_lift = 0.08;        // swing foot clearance, m
uniform float walk_bob = 0.02;         // hip bob, m
uniform float walk_arm_swing = 0.35;   // rad each way
uniform float walk_width = 0.14;       // between the feet, m
uniform float walk_speed = 1.3;        // m/s the walk cycle is built for
uniform float run_speed = 3.0;
uniform float crouch_hips = 0.22;      // WORK: hips drop, m
uniform float sit_lean = 0.08;         // SIT: torso lean, rad
uniform float adult_hip = 0.845;       // PeopleArt.HIP in metres

// Two-bone leg IK: hip pitch and knee bend that put the foot at (dz forward,
// dy up) from the hip joint.
vec2 leg_ik(float dz, float dy, float lt, float ls) {
	float d = clamp(length(vec2(dz, dy)), 0.01, lt + ls - 0.0005);
	float a0 = atan(dz, -dy);
	float a1 = acos(clamp((lt * lt + d * d - ls * ls) / (2.0 * lt * d), -1.0, 1.0));
	float k = acos(clamp((lt * lt + ls * ls - d * d) / (2.0 * lt * ls), -1.0, 1.0));
	return vec2(a0 + a1, 3.14159265 - k);
}

const float D = 0.0174533;
const float TWO_PI = 6.2831853;
const float VX = 0.065;

mat3 rx(float a) { float c = cos(a), s = sin(a); return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c)); }
mat3 ry(float a) { float c = cos(a), s = sin(a); return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c)); }
mat3 rz(float a) { float c = cos(a), s = sin(a); return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0)); }

void vertex() {
	int ir = int(INSTANCE_CUSTOM.r + 0.5);
	int ig = int(INSTANCE_CUSTOM.g + 0.5);
	int ib = int(INSTANCE_CUSTOM.b + 0.5);
	int ia = int(INSTANCE_CUSTOM.a + 0.5);
	int pose = ir >> 7;
	bool moving = ((ir >> 6) & 1) == 1;
	float phase = float(ir & 63) / 64.0;
	float scale = 0.70 + 0.04 * float(ig & 15);
	bool skates = ((ig >> 10) & 1) == 1;
	bool elder = (ib & 1) == 1;
	bool run = ((ia >> 2) & 1) == 1;
	// per-person randomness for idle motion and cloth tone (not the phase,
	// which walkers advance every frame)
	float seed = fract(sin(float(INSTANCE_ID) * 12.9898 + float(ia & 3) * 3.1) * 43758.5453);

	// ---- colour
	int slot = int(UV.x + 0.5);
	vec3 c = COLOR.rgb;
	if (slot == 1) c *= palette[80 + ((ia >> 3) & 3)];
	else if (slot == 2) c *= palette[(ig >> 4) & 63];
	else if (slot == 3) c *= palette[ib >> 5];
	else if (slot == 4) c *= palette[64 + ((ib >> 1) & 15)];
	else if (slot == 5) c *= palette[ia >> 5];
	if (slot >= 2) c *= 0.95 + 0.1 * fract(seed * 7.3);
	COLOR.rgb = pow(clamp(c, 0.0, 1.0), vec3(2.2));

	// ---- body data
	int part = int(UV.y + 0.5);
	// skaters stand on their blades: everything rises by SKATE - SHOE
	float lift = skates ? VX : 0.0;
	vec3 J = CUSTOM0.xyz + vec3(0.0, lift, 0.0);
	float L = CUSTOM0.w;
	float hipY = UV2.x + lift;
	float Lt = UV2.y;
	float S = hipY - Lt;  // knee joint height (shin + foot)
	float kid = clamp((0.8 - hipY) / 0.45, 0.0, 1.0);  // 0 adult .. 1 toddler

	float t = TIME * time_scale + seed * 17.0;
	float tt = t;
	float m = hipY / adult_hip;  // leg length against an adult's: strides scale with it

	// pose angles (radians): legs, arms, waist, head, root
	float hpL = 0.0, hpR = 0.0, hrL = 0.0, hrR = 0.0, kL = 2.0 * D, kR = 2.0 * D;
	float spL = 0.0, spR = 0.0, srL = 5.0 * D, srR = 5.0 * D, syL = 0.0, syR = 0.0;
	float eL = 10.0 * D, eR = 10.0 * D, erL = 0.0, erR = 0.0;
	float lean = 0.0, wroll = 0.0, twist = 0.0, nod = 0.0, hyaw = 0.0;
	vec3 root = vec3(0.0);
	float spin = 0.0, waddle = 0.0;
	bool sit = pose == 2 || pose == 14 || pose == 15;
	bool idle = pose != 5 && pose != 13;
	bool walk_legs = pose == 1 || (moving && (pose == 0 || pose == 7 || pose == 8 || pose == 9 || pose == 10 || pose == 11));
	bool solve = !sit && pose != 13 && pose != 12 && !walk_legs;
	float jump = 0.0;

	// idle life: breathing, weight shifts, looking around
	if (idle) {
		float slow = sin(tt * 0.33 + seed * 6.0);
		lean += 1.2 * D * sin(tt * 1.7);
		hyaw = 0.35 * sin(tt * 0.21) * sin(tt * 0.13 + 2.0);
		nod += 0.05 * sin(tt * 0.41);
		spL += 2.5 * D * sin(tt * 0.9);
		spR += 2.5 * D * sin(tt * 0.9 + 1.3);
		if (!walk_legs && !sit) {
			root.x += 0.012 * slow;
			wroll -= 1.5 * D * slow;
			kL += max(0.0, slow) * 7.0 * D;
			kR += max(0.0, -slow) * 7.0 * D;
			hpL += max(0.0, slow) * 3.5 * D;
			hpR += max(0.0, -slow) * 3.5 * D;
		}
	}
	float half_w = 0.0;
	if (walk_legs) {
		// phase is the gait cycle (RinkPeople advances it by walk_phase_rate()).
		// A planted foot slides back at the walk speed for `duty` of the cycle,
		// then swings forward lifted; the legs reach it by IK.
		float cad = run ? walk_cadence_run : walk_cadence;
		float duty = run ? walk_duty_run : walk_duty;
		float cyc_len = (run ? run_speed : walk_speed) / (cad * 0.5) * m;
		float stride = cyc_len * duty;
		float h = sqrt(max(hipY * hipY - stride * stride * 0.25, 0.01)) * 0.995;
		h -= walk_bob * m * (0.5 - 0.5 * cos(2.0 * TWO_PI * (phase - duty * 0.5)));
		root.y += h - hipY;
		half_w = walk_width * 0.5 * m;
		for (int side = 0; side < 2; side++) {
			float u = fract(phase + (side == 1 ? 0.5 : 0.0));
			float dz, dy = -h;
			if (u < duty) {
				dz = stride * (0.5 - u / duty);
			} else {
				float sw = (u - duty) / (1.0 - duty);
				dz = stride * (smoothstep(0.0, 1.0, sw) - 0.5);
				dy += walk_lift * m * sin(3.14159265 * sw);
			}
			vec2 ik = leg_ik(dz, dy, Lt, S);
			float arm = -walk_arm_swing * cos(TWO_PI * u);
			if (side == 0) { hpL = ik.x; kL = ik.y; spL = arm; } else { hpR = ik.x; kR = ik.y; spR = arm; }
		}
		eL = run ? 80.0 * D : 16.0 * D; eR = eL;
		lean += run ? 9.0 * D : 2.0 * D;
		twist = 4.0 * D * sin(TWO_PI * phase);
		waddle = kid > 0.8 ? 5.0 * D * sin(TWO_PI * phase) : 0.0;
	}
	if (pose == 3) {  // SKATE: glide and push, leaning in
		float sk = TWO_PI * phase;  // advanced by skate_phase_rate()
		float pl = max(0.0, sin(sk)), pr = max(0.0, -sin(sk));
		hpL = mix(42.0, 10.0, pl) * D; kL = mix(28.0, 6.0, pl) * D; hrL = 26.0 * D * pl;
		hpR = mix(42.0, 10.0, pr) * D; kR = mix(28.0, 6.0, pr) * D; hrR = 26.0 * D * pr;
		lean = 28.0 * D;
		nod = -18.0 * D;
		spL = -26.0 * D * sin(sk) + 10.0 * D; spR = 26.0 * D * sin(sk) + 10.0 * D;
		syL = 14.0 * D; syR = 14.0 * D;
		eL = 25.0 * D; eR = 25.0 * D;
		root.x = 0.05 * (pl - pr);
		wroll = 5.0 * D * (pr - pl);
	} else if (pose == 4) {  // SKATE_WOBBLY: knees locked, arms out, shuffling
		float sk = TWO_PI * phase;
		hpL = 8.0 * D * sin(sk); hpR = -8.0 * D * sin(sk);
		kL = 2.0 * D; kR = 2.0 * D;
		hrL = 6.0 * D; hrR = 6.0 * D;
		srL = (72.0 + 14.0 * sin(t * 3.3)) * D; srR = (72.0 + 14.0 * sin(t * 3.1 + 2.0)) * D;
		spL = 18.0 * D; spR = 18.0 * D;
		eL = 12.0 * D; eR = 12.0 * D;
		wroll = (7.0 * sin(t * 2.7) + 4.0 * sin(t * 4.3)) * D;
		lean = -5.0 * D + 6.0 * D * sin(t * 1.9);
		nod = 22.0 * D;
		hyaw = 0.0;
	} else if (pose == 5) {  // SPIN: scratch spin, arms in
		spin = t * 13.0 + phase * TWO_PI;
		spL = 72.0 * D; spR = 72.0 * D;
		syL = 40.0 * D; syR = 40.0 * D;
		eL = 95.0 * D; eR = 95.0 * D;
		hpL = 18.0 * D; hrL = -12.0 * D; kL = 40.0 * D;
	} else if (pose == 6 || pose == 15) {  // CHEER (SIT_CHEER keeps the seat)
		float jp = max(0.0, sin(TWO_PI * (t * 1.4 + phase)));
		if (pose == 6) {
			jump = (0.13 + kid * 0.06) * pow(jp, 0.7);
			kL = 22.0 * D * (1.0 - jp); kR = kL;
			hpL = kL * 0.6; hpR = hpL;
		} else {
			root.y += 0.03 * jp;
		}
		spL = (162.0 + 12.0 * sin(t * 7.0)) * D; spR = (162.0 + 12.0 * sin(t * 7.0 + 1.5)) * D;
		srL = -22.0 * D; srR = -22.0 * D;  // raised arms splay out in a V
		eL = 12.0 * D; eR = 12.0 * D;
		nod = -16.0 * D;
	} else if (pose == 7 || pose == 14) {  // CLAP (SIT_CLAP)
		float cl = 0.5 + 0.5 * sin(t * 14.0);
		spL = 58.0 * D; spR = 58.0 * D;
		syL = (34.0 + 12.0 * cl) * D; syR = syL;
		eL = 58.0 * D; eR = 58.0 * D;
		srL = 0.0; srR = 0.0;
	} else if (pose == 8) {  // TALK: gesturing
		spR = (28.0 + 12.0 * sin(t * 2.3)) * D;
		eR = (70.0 + 25.0 * sin(t * 3.1 + 1.0)) * D;
		syR = 18.0 * D;
		spL = (14.0 + 8.0 * sin(t * 1.7)) * D;
		eL = (25.0 + 35.0 * max(0.0, sin(t * 0.9))) * D;
		nod = 6.0 * D * sin(t * 3.0);
		twist = 6.0 * D * sin(t * 0.7);
	} else if (pose == 9) {  // WAVE
		srR = 140.0 * D;
		spR = 10.0 * D;
		eR = 15.0 * D;
		erR = 28.0 * D * sin(t * 9.0);
		nod = -4.0 * D;
		wroll = -3.0 * D;
	} else if (pose == 10) {  // QUEUE: weight on one hip, checking the phone
		float look_up = smoothstep(0.75, 0.95, sin(tt * 0.4));
		spL = 32.0 * D; eL = 88.0 * D; syL = 28.0 * D;
		nod = mix(28.0, -2.0, look_up) * D;
		hyaw *= look_up;
		if (!walk_legs) {
			float sh = sin(tt * 0.18);
			root.x += 0.025 * sh;
			wroll -= 3.0 * D * sh;
			kL += max(0.0, sh) * 14.0 * D;
			kR += max(0.0, -sh) * 14.0 * D;
		}
	} else if (pose == 11) {  // CARRY: box in both hands
		spL = 50.0 * D; spR = 50.0 * D;
		eL = 40.0 * D; eR = 40.0 * D;
		srL = 0.0; srR = 0.0;
		lean -= 3.0 * D;
	} else if (pose == 12) {  // WORK / SWEEP: bent over, arms working
		float wk = sin(t * 2.6 + phase * TWO_PI);
		lean = 34.0 * D;
		nod = -14.0 * D;
		// hips drop by crouch_hips (AnimTuning), feet planted a little staggered
		float h = max(hipY - crouch_hips * m, hipY * 0.55);
		vec2 l = leg_ik(0.06 * m, -h, Lt, S);
		vec2 r = leg_ik(-0.04 * m, -h, Lt, S);
		hpL = l.x; kL = l.y; hpR = r.x; kR = r.y;
		root.y += h - hipY;
		spL = (42.0 + 22.0 * wk) * D; spR = (42.0 + 22.0 * wk) * D;
		syL = (16.0 + 14.0 * wk) * D; syR = (16.0 - 14.0 * wk) * D;
		eL = 28.0 * D; eR = 28.0 * D;
		twist = 10.0 * D * wk;
	} else if (pose == 13) {  // FALL: sat on the ice
		hpL = 84.0 * D; hpR = 80.0 * D; kL = 14.0 * D; kR = 55.0 * D;
		hrL = 10.0 * D; hrR = 10.0 * D;
		lean = -18.0 * D;
		spL = -38.0 * D; spR = -38.0 * D; srL = 16.0 * D; srR = 16.0 * D; eL = 4.0 * D; eR = 4.0 * D;
		hyaw = 10.0 * D * sin(t * 2.0);
		nod = 8.0 * D;
		root.y = 1.6 * VX - hipY;
	}
	if (sit) {
		hpL = (80.0 + 3.0 * sin(tt * 0.3)) * D; hpR = (80.0 - 3.0 * sin(tt * 0.3)) * D;
		if (pose == 2) {
			spL = 30.0 * D; spR = 30.0 * D; eL = 48.0 * D; eR = 48.0 * D;
			syL = 12.0 * D; syR = 12.0 * D; srL = 2.0 * D; srR = 2.0 * D;
		}
		lean += sit_lean;
		root.y += seat_height / scale + 1.5 * VX - hipY;
	}
	if (elder) {
		lean += 11.0 * D;
		nod -= 9.0 * D;
		if (solve) { kL += 6.0 * D; kR += 6.0 * D; }
		spL += 6.0 * D; spR += 6.0 * D;
	}
	// keep the lower foot on the floor: the hips sink as the legs bend
	if (solve) {
		float hl = cos(hrL) * (Lt * cos(hpL) + S * cos(hpL - kL));
		float hr = cos(hrR) * (Lt * cos(hpR) + S * cos(hpR - kR));
		root.y += max(hl, hr) - hipY + jump;
	}

	// ---- pose the vertex
	vec3 v = VERTEX + vec3(0.0, lift, 0.0);
	vec3 n = NORMAL;
	if ((part == 11 && pose != 11) || (part == 12 && pose != 10)) {
		v = J;  // the CARRY box and QUEUE phone only exist in their poses
	}
	if (part >= 2 && part <= 5) {
		bool right = part == 3 || part == 5;
		float side = right ? 1.0 : -1.0;
		float hp = right ? hpR : hpL;
		float hr = right ? hrR : hrL;
		if (walk_legs) hr = atan(half_w - abs(J.x), hipY);  // feet walk_width apart
		if (part >= 4) {
			float kb = right ? kR : kL;
			if (sit) {
				// shins reach for the floor if they can, or dangle and swing
				float knee_y = hipY + root.y - Lt * cos(hp);
				float reach = knee_y / S;
				float th = reach < 1.0 ? acos(clamp(reach, 0.0, 1.0)) : 0.0;
				if (reach >= 1.0) th = 14.0 * D * sin(tt * 2.6 + side) * kid;
				kb = hp - th;
			}
			vec3 K = J - vec3(0.0, L, 0.0);
			mat3 mk = rx(-kb);
			v = K + mk * (v - K);
			n = mk * n;
		}
		mat3 mh = rz(hr * side) * rx(hp);
		v = J + mh * (v - J);
		n = mh * n;
	} else if (part >= 6 && part != 11) {
		bool right = part == 7 || part == 9 || part == 10;
		float side = right ? 1.0 : -1.0;
		if (part >= 8) {
			vec3 EL = J - vec3(0.0, L, 0.0);
			mat3 me = rz((right ? erR : erL) * side) * rx(right ? eR : eL);
			v = EL + me * (v - EL);
			n = me * n;
		}
		mat3 ms = ry((right ? syR : syL) * side) * rz((right ? srR : srL) * side) * rx(right ? spR : spL);
		v = J + ms * (v - J);
		n = ms * n;
	}
	if (part == 1) {
		mat3 mn = ry(hyaw) * rx(-nod);
		v = J + mn * (v - J);
		n = mn * n;
	}
	if (part < 2 || part >= 6) {
		vec3 W = vec3(0.0, hipY, 0.0);
		mat3 mw = ry(twist) * rz(wroll) * rx(-lean);
		v = W + mw * (v - W);
		n = mw * n;
	}
	mat3 mr = ry(spin) * rz(waddle);
	v = mr * v + root;
	n = mr * n;
	VERTEX = v * scale;
	NORMAL = n;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.88;
}
"""
