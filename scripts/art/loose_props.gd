class_name LooseProps
extends RefCounted
## The building's loose things: what a person on foot can pick up, carry and
## drop (PropGrab, LooseProp). Two kinds:
##
##   * small things modelled here at a fine voxel (cups, bottles, cans, a
##     mug, pucks, a cone, boxes, a folding chair, tools, a clipboard, tape,
##     a paint can, a bucket, a helmet, a skate, a spray bottle, a first aid
##     kit, a water cooler), all in SMALL;
##   * Props kit pieces that are loose by nature (a trash can, the toolbox,
##     the shop vac, an extinguisher, the step ladder, cones, puck buckets,
##     hockey bags...), all in KIT: VenueKit.prop() sends these here itself,
##     so every room that already places one gets a loose one.
##
## Everything else (walls, counters, benches, stalls, machines, doors) stays
## a fixed part of the building.
##
##   k.loose("coffee_cup", Vector3(-40.1, 1.05, -11.3), 0.4)   # a room's build
##   LooseProps.body("puck", age)    # a LooseProp, for a walk
##   LooseProps.mesh("puck", age)    # cached; pivot on its base, front -Z
##
## A match venue draws static copies (the kit merges small ones into the
## room's mesh, kit pieces stay in its MultiMesh) and leaves PLACES out; a
## walk gets bodies in the room's StickField, which draws the resting ones as
## one mesh.
##
## PLACES is the extra clutter a walk finds across the building (lobby,
## stands, offices, workshop, bay, dressing rooms...), added to each room by
## furnish() after its own build. Venue space; y is about the surface it
## stands on (a walk's props drop onto it on their first step).

## Small things: [voxel size, mass kg, label].
const SMALL := {
	"coffee_cup": [0.016, 0.25, "COFFEE CUP"],
	"soda_cup": [0.018, 0.35, "SODA CUP"],
	"water_bottle": [0.016, 0.5, "WATER BOTTLE"],
	"sport_bottle": [0.018, 0.6, "WATER BOTTLE"],
	"soda_can": [0.016, 0.35, "POP CAN"],
	"mug": [0.016, 0.35, "MUG"],
	"puck": [0.0127, 0.17, "PUCK"],
	"cone": [0.025, 0.4, "CONE"],
	"box_small": [0.05, 1.5, "BOX"],
	"box_large": [0.05, 4.0, "BOX"],
	"folding_chair": [0.05, 3.5, "CHAIR"],
	"wrench": [0.02, 0.4, "WRENCH"],
	"hammer": [0.02, 0.6, "HAMMER"],
	"clipboard": [0.02, 0.3, "CLIPBOARD"],
	"tape_roll": [0.012, 0.1, "ROLL OF TAPE"],
	"paint_can": [0.025, 4.0, "PAINT CAN"],
	"bucket": [0.03, 1.5, "BUCKET"],
	"helmet": [0.022, 0.6, "HELMET"],
	"skate": [0.02, 0.9, "SKATE"],
	"spray_bottle": [0.016, 0.5, "SPRAY BOTTLE"],
	"first_aid_kit": [0.03, 1.0, "FIRST AID KIT"],
	"water_cooler": [0.03, 3.0, "WATER COOLER"],
}

## Props kit pieces that are loose: [mass kg, label].
const KIT := {
	"trash_can": [6.0, "TRASH CAN"],
	"toolbox": [40.0, "TOOLBOX"],
	"shop_vac": [9.0, "SHOP VAC"],
	"fire_extinguisher": [6.0, "FIRE EXTINGUISHER"],
	"step_ladder": [7.0, "STEP LADDER"],
	"pylon_stack": [3.0, "STACK OF PYLONS"],
	"puck_bucket": [8.0, "PUCK BUCKET"],
	"skate_cones": [2.0, "CONES"],
	"hockey_bags": [10.0, "HOCKEY BAGS"],
	"broom_bin": [5.0, "BROOM BIN"],
	"goalie_pads": [8.0, "GOALIE PADS"],
	"foot_measure": [1.0, "FOOT MEASURE"],
}

static var _meshes := {}
static var _models := {}
static var _boxes := {}


static func is_loose(id: String) -> bool:
	return SMALL.has(id) or KIT.has(id)


static func is_small(id: String) -> bool:
	return SMALL.has(id)


static func mass(id: String) -> float:
	return float(SMALL[id][1]) if SMALL.has(id) else float(KIT.get(id, [1.0])[0])


static func label(id: String) -> String:
	return str(SMALL[id][2]) if SMALL.has(id) else str(KIT.get(id, [0, id.to_upper()])[1])


## The model of a small thing at `age` (cached; don't change it).
static func model(id: String, age: int) -> VoxelModel:
	var key := "%s/%d" % [id, age]
	if not _models.has(key):
		_models[key] = _build(id, age)
	return _models[key]


static func mesh(id: String, age: int) -> ArrayMesh:
	if KIT.has(id):
		return Props.mesh(id, age)
	var key := "%s/%d" % [id, age]
	if not _meshes.has(key):
		var m := model(id, age)
		_meshes[key] = m.build_mesh() if m else null
	return _meshes[key]


## The one box a loose body collides with, in the mesh's space.
static func box(id: String, age: int) -> AABB:
	var key := "%s/%d" % [id, age]
	if not _boxes.has(key):
		var out := AABB()
		if KIT.has(id):
			var first := true
			for b in Props.collision_boxes(id, age):
				out = b if first else out.merge(b)
				first = false
		else:
			var m := mesh(id, age)
			out = m.get_aabb() if m else AABB(Vector3(-0.05, 0, -0.05), Vector3.ONE * 0.1)
		_boxes[key] = out
	return _boxes[key]


## A loose body of `id` at `age` (not yet placed or in a field).
static func body(id: String, age: int) -> LooseProp:
	return LooseProp.make(id, mesh(id, age), box(id, age), mass(id), label(id))


# ---------------------------------------------------------------- placing

## Extra loose things for a walk, per room: [id, Vector3 (venue space, on
## the surface it stands on), turn about Y]. Surfaces were found by casting
## down through each room (counter 1.17, desks 0.75, lobby benches 0.45...).
const PLACES := {
	"lobby": [
		# the snack bar counter, between the till, the urn and the popcorn
		["coffee_cup", Vector3(-41.0, 1.17, -11.3), 0.4],
		["soda_cup", Vector3(-40.8, 1.17, -11.62), 0.0],
		["coffee_cup", Vector3(-38.3, 1.17, -11.25), 1.3],
		["soda_can", Vector3(-39.5, 1.17, -11.62), 0.7],
		["soda_cup", Vector3(-41.95, 1.17, -11.6), 0.0],
		# the back shelf
		["box_small", Vector3(-40.5, 0.95, -13.4), 0.05],
		["mug", Vector3(-38.2, 0.95, -13.4), 2.0],
		["water_bottle", Vector3(-37.7, 0.95, -13.3), 0.0],
		["water_bottle", Vector3(-37.55, 0.95, -13.5), 0.0],
		# the benches and the viewing window's sill
		["coffee_cup", Vector3(-39.2, 0.45, -2.5), 0.9],
		["sport_bottle", Vector3(-38.0, 0.45, -2.4), 0.0],
		["soda_can", Vector3(-37.6, 0.45, 2.45), 2.2],
		["coffee_cup", Vector3(-34.15, 1.0, -1.2), 0.3],
		["soda_cup", Vector3(-34.15, 1.0, 3.1), 0.0],
		# a dropped puck by the rink doors
		["puck", Vector3(-35.6, 0.0, 4.4), 0.0],
	],
	"office": [
		["mug", Vector3(-41.3, 5.25, -11.6), 0.6],
		["clipboard", Vector3(-41.4, 5.25, -10.15), 0.2],
		["coffee_cup", Vector3(-42.4, 5.25, -9.95), 0.0],
		["box_small", Vector3(-44.9, 4.5, -11.8), 0.3],
	],
	"stands_bench": [
		# cups and bottles left on the seats
		["coffee_cup", Vector3(-20.0, 1.35, -17.9), 0.0],
		["soda_cup", Vector3(-13.2, 1.35, -17.85), 0.0],
		["coffee_cup", Vector3(1.1, 1.35, -17.9), 0.0],
		["soda_can", Vector3(6.5, 1.35, -17.9), 1.0],
		["soda_cup", Vector3(19.8, 1.35, -17.9), 0.0],
		["water_bottle", Vector3(-6.0, 1.77, -18.8), 0.0],
		["coffee_cup", Vector3(12.4, 1.77, -18.8), 0.0],
	],
	"stands_box": [
		["coffee_cup", Vector3(-15.0, 1.35, 17.9), 0.0],
		["soda_cup", Vector3(8.0, 1.35, 17.9), 0.0],
		["soda_can", Vector3(14.6, 1.35, 17.85), 0.5],
	],
	"zamboni_bay": [
		# the bench by the door to the arena
		["wrench", Vector3(35.6, 0.9, -4.45), 0.3],
		["hammer", Vector3(36.4, 0.9, -4.5), -0.2],
		["spray_bottle", Vector3(37.2, 0.9, -4.4), 0.0],
		["coffee_cup", Vector3(38.1, 0.9, -4.3), 0.0],
		# the cubbies at the back
		["paint_can", Vector3(35.45, 0.85, 4.25), 0.0],
		["bucket", Vector3(36.2, 0.85, 4.25), 0.4],
		["box_small", Vector3(36.9, 0.85, 4.25), 0.0],
		["first_aid_kit", Vector3(44.7, 0.82, 3.7), PI],
	],
	"locker_home": [
		["puck", Vector3(39.0, 0.0, -9.5), 0.0],
		["puck", Vector3(39.4, 0.0, -9.2), 0.0],
		["tape_roll", Vector3(38.2, 0.0, -8.6), 0.0],
		["helmet", Vector3(37.5, 0.0, -10.2), 0.8],
		["skate", Vector3(40.0, 0.0, -8.2), 1.9],
		["water_bottle", Vector3(41.0, 0.0, -9.6), 0.0],
	],
	"locker_away": [
		["puck", Vector3(39.0, 0.0, 9.5), 0.0],
		["tape_roll", Vector3(38.4, 0.0, 8.7), 0.0],
		["sport_bottle", Vector3(40.6, 0.0, 9.6), 0.0],
		["helmet", Vector3(37.6, 0.0, 10.0), 2.4],
	],
	"locker_3": [
		["puck", Vector3(4.0, 0.0, -35.0), 0.0],
		["tape_roll", Vector3(3.5, 0.0, -34.4), 0.0],
		["sport_bottle", Vector3(4.6, 0.0, -35.6), 0.0],
		["skate", Vector3(3.0, 0.0, -35.8), 1.2],
	],
	"locker_4": [
		["puck", Vector3(12.0, 0.0, -35.0), 0.0],
		["helmet", Vector3(11.5, 0.0, -34.3), 0.4],
		["water_bottle", Vector3(12.6, 0.0, -35.8), 0.0],
	],
	"locker_5": [
		["puck", Vector3(20.0, 0.0, -35.0), 0.0],
		["tape_roll", Vector3(19.4, 0.0, -34.5), 0.0],
		["sport_bottle", Vector3(20.6, 0.0, -35.4), 0.0],
	],
	"locker_6": [
		["puck", Vector3(26.5, 0.0, -34.0), 0.0],
		["puck", Vector3(26.0, 0.0, -33.6), 0.0],
		["sport_bottle", Vector3(26.9, 0.0, -33.4), 0.0],
	],
	"rec_offices": [
		# the three desks
		["mug", Vector3(-43.0, 0.75, -49.0), 0.5],
		["clipboard", Vector3(-44.0, 0.75, -49.2), 0.1],
		["coffee_cup", Vector3(-39.8, 0.75, -49.3), 0.0],
		["soda_can", Vector3(-40.8, 0.75, -48.95), 0.0],
		["mug", Vector3(-33.9, 0.75, -49.0), 2.6],
		# the meeting table
		["coffee_cup", Vector3(-42.5, 0.75, -56.0), 0.0],
		["coffee_cup", Vector3(-40.0, 0.75, -57.1), 0.0],
		["water_bottle", Vector3(-38.6, 0.75, -55.9), 0.0],
		["water_bottle", Vector3(-41.4, 0.75, -55.85), 0.0],
		["clipboard", Vector3(-37.3, 0.75, -56.5), 0.3],
		["mug", Vector3(-39.3, 0.75, -56.9), 1.0],
		# the kitchenette counter
		["coffee_cup", Vector3(-33.6, 0.9, -59.4), 0.0],
		["mug", Vector3(-34.2, 0.9, -59.35), 0.2],
	],
	"workshop": [
		# on the workbenches
		["wrench", Vector3(34.2, 0.91, -59.2), 0.2],
		["mug", Vector3(33.6, 0.91, -59.3), 0.0],
		["hammer", Vector3(34.4, 0.91, -59.45), 0.1],
		["spray_bottle", Vector3(33.9, 0.91, -59.45), 0.0],
		# on the floor: paint, a bucket, a box, cones in the loading bay
		["paint_can", Vector3(40.0, 0.0, -46.0), 0.0],
		["bucket", Vector3(41.0, 0.0, -45.6), 0.0],
		["box_large", Vector3(43.5, 0.0, -57.5), 0.2],
		["box_small", Vector3(42.6, 0.0, -57.6), -0.3],
		["cone", Vector3(44.2, 0.0, -53.6), 0.0],
		["cone", Vector3(44.2, 0.0, -52.4), 0.0],
	],
	"rec_lobby": [
		["clipboard", Vector3(-35.5, 1.05, -40.6), -0.2],
		["sport_bottle", Vector3(-45.25, 0.45, -41.5), 0.0],
		["coffee_cup", Vector3(-45.2, 0.45, -33.0), 0.0],
		["soda_can", Vector3(-45.25, 0.45, -40.6), 0.0],
	],
	"community_room": [
		["coffee_cup", Vector3(19.0, 0.74, -52.1), 0.0],
		["soda_can", Vector3(23.5, 0.74, -48.9), 0.0],
		["mug", Vector3(28.0, 0.74, -52.0), 1.4],
		["water_bottle", Vector3(24.5, 0.74, -52.2), 0.0],
		["box_large", Vector3(30.5, 0.8, -58.5), 0.1],
		["folding_chair", Vector3(20.0, 0.8, -57.5), PI],
	],
	"rec_officials": [
		["water_bottle", Vector3(-11.7, 0.45, -32.0), 0.0],
		["clipboard", Vector3(-8.7, 0.6, -31.5), 0.0],
		["first_aid_kit", Vector3(-8.7, 0.6, -32.2), 0.0],
	],
	"pro_shop": [
		["coffee_cup", Vector3(-25.0, 1.0, -33.5), 0.0],
		["tape_roll", Vector3(-27.5, 1.0, -33.6), 0.0],
		["tape_roll", Vector3(-27.3, 1.0, -33.4), 0.0],
		["puck", Vector3(-26.4, 1.0, -33.7), 0.0],
		["skate", Vector3(-31.0, 0.45, -36.2), PI * 0.5],
	],
	"weight_room": [
		["spray_bottle", Vector3(5.0, 1.0, -59.85), 0.0],
		["water_bottle", Vector3(11.8, 1.0, -59.85), 0.0],
	],
	"benches": [
		["water_cooler", Vector3(-10.8, 0.0, -14.6), 0.0],
		["water_cooler", Vector3(10.8, 0.0, -14.6), 0.0],
		["puck", Vector3(-6.0, 0.0, -14.8), 0.0],
	],
}


## Adds `room`'s PLACES to its kit (VenueRoom.rebuild calls it after build).
## Only on a walk: a match venue keeps its budget for the crowd.
static func furnish(room: VenueRoom, k: VenueKit) -> void:
	if not StickProps.walkable(room):
		return
	for p: Array in PLACES.get(room.room_id, []):
		k.loose(p[0], p[1], p[2] if p.size() > 2 else 0.0)


## How many extra loose things PLACES adds across the building.
static func placed_count() -> int:
	var n := 0
	for id in PLACES:
		n += (PLACES[id] as Array).size()
	return n


# ---------------------------------------------------------------- models

static func _build(id: String, age: int) -> VoxelModel:
	var s: float = SMALL[id][0] if SMALL.has(id) else 0.02
	var m := VoxelModel.new(s)
	m.jitter = 0.03
	var worn := age == VenueRoom.Age.WORN
	var new := age == VenueRoom.Age.RENOVATED
	match id:
		"coffee_cup":
			_disc(m, 5, 0, 6, Color("f1eee4"))
			_disc(m, 5, 2, 2, Color("8a5a30"))  # the sleeve
			_disc(m, 5, 6, 1, Color("3b2a20") if not new else Color("eeeeea"))  # lid
			m.set_voxel(3, 7, 2, Color("2a2a2a"))  # sip hole
			return m.set_pivot(2.5, 0, 2.5)
		"soda_cup":
			_disc(m, 5, 0, 8, Color("eeeeea"))
			_disc(m, 5, 2, 3, Color("c8191e"))
			_disc(m, 5, 8, 1, Color("f4f4f4"))
			m.box(2, 9, 2, 1, 4, 1, Color("e83a3a"))  # straw
			return m.set_pivot(2.5, 0, 2.5)
		"water_bottle":
			_disc(m, 4, 0, 11, Color("9cc9de"))
			_disc(m, 4, 4, 3, Color("2f6fb7"))  # label
			m.box(1, 11, 1, 2, 2, 2, Color("b6dbe8"))
			m.box(1, 13, 1, 2, 1, 2, Color("2f6fb7"))  # cap
			return m.set_pivot(2, 0, 2)
		"sport_bottle":
			var c := Color("2f9a4f") if worn else Color("c8191e")
			_disc(m, 4, 0, 10, c)
			_disc(m, 4, 3, 1, c.darkened(0.3))
			m.box(0, 10, 0, 4, 1, 4, Color("1e1f22"))
			m.box(1, 11, 1, 2, 2, 1, Color("1e1f22"))  # the spout
			return m.set_pivot(2, 0, 2)
		"soda_can":
			_disc(m, 4, 0, 7, Color("c8191e") if age != 1 else Color("2f6fb7"))
			_disc(m, 4, 0, 1, Color("c0c4c8"))
			_disc(m, 4, 6, 1, Color("c0c4c8"))
			m.set_voxel(1, 3, 0, Color("eeeeea")).set_voxel(2, 3, 0, Color("eeeeea"))
			return m.set_pivot(2, 0, 2)
		"mug":
			var c := Color("e3d9bf") if worn else (Color("1d3557") if new else Color("eeeeea"))
			_disc(m, 5, 0, 5, c)
			m.clear_box(1, 2, 1, 3, 3, 3)
			m.box(1, 4, 1, 3, 1, 3, Color("4a2c18"))  # cold coffee
			m.box(5, 1, 2, 1, 3, 1, c)  # handle
			return m.set_pivot(2.5, 0, 2.5)
		"puck":
			_disc(m, 6, 0, 2, Color("141416"))
			return m.set_pivot(3, 0, 3)
		"cone":
			var o := Color("ee6a1a")
			m.box(0, 0, 0, 9, 1, 9, o.darkened(0.15))
			for i in 5:
				var w := 7 - i
				var off := (9 - w) / 2
				var c := Color("eeeeea") if i == 2 else o
				_disc_at(m, off, 1 + i * 2, off, w, 2, c)
			return m.set_pivot(4.5, 0, 4.5)
		"box_small", "box_large":
			var big := id == "box_large"
			var sx := 10 if big else 7
			var sy := 8 if big else 5
			var sz := 8 if big else 6
			var card := Color("b08a5a").darkened(0.1 if worn else 0.0)
			m.box(0, 0, 0, sx, sy, sz, card)
			m.box(0, sy - 1, sz / 2, sx, 1, 1, Color("c8b48a"))  # the tape over the flaps
			m.box(1, sy - 3, -1, 3, 2, 1, Wear.PAPER)  # label
			if big:
				m.box(1, sy - 3, -1, 3, 1, 1, Color("2a2a2a"))
			return m.set_pivot(sx * 0.5, 0, sz * 0.5)
		"folding_chair":
			var seat: Color = [Color("a8a08a"), Color("7d8287"), Color("2b2d33")][age]
			var leg := Color("6e7378")
			for x: int in [0, 8]:
				for z: int in [0, 7]:
					m.box(x, 0, z, 1, 8, 1, leg)
			m.box(0, 8, 0, 9, 1, 8, seat)
			m.box(0, 9, 7, 1, 7, 1, leg)
			m.box(8, 9, 7, 1, 7, 1, leg)
			m.box(0, 12, 7, 9, 4, 1, seat)  # the back
			return m.set_pivot(4.5, 0, 4)
		"wrench":
			var ch := Color("c4c8ca")
			m.box(2, 0, 1, 10, 1, 1, ch)
			m.box(0, 0, 0, 3, 1, 3, ch)
			m.clear_box(0, 0, 1, 1, 1, 1)  # open jaw
			m.box(11, 0, 0, 3, 1, 3, ch.darkened(0.1))
			return m.set_pivot(7, 0, 1.5)
		"hammer":
			m.box(0, 0, 1, 12, 1, 1, Color("b08a5a") if worn else Color("1e1f22"))
			m.box(12, 0, 0, 2, 2, 4, Color("5f6466"))
			m.box(12, 0, 4, 2, 1, 1, Color("5f6466"))  # claw
			return m.set_pivot(7, 0, 2)
		"clipboard":
			m.box(0, 0, 0, 11, 1, 15, Color("8a6a45"))
			m.box(1, 1, 1, 9, 1, 12, Wear.PAPER)
			for r in 4:
				m.box(2, 1, 3 + r * 2, 6 - r % 2 * 2, 1, 1, Color("6a6a6a"))  # writing
			m.box(3, 1, 13, 5, 1, 2, Color("c4c8ca"))  # the clip
			return m.set_pivot(5.5, 0, 7.5)
		"tape_roll":
			var t := Color("eeeeea") if age != 1 else Color("1e1f22")
			_disc(m, 6, 0, 2, t)
			m.clear_box(2, 0, 2, 2, 2, 2)
			return m.set_pivot(3, 0, 3)
		"paint_can":
			_disc(m, 7, 0, 8, Color("b9c0c6"))
			_disc(m, 7, 2, 4, Color("2f6fb7") if not worn else Color("7d8a3a"))
			_disc(m, 7, 8, 1, Color("8f9498"))
			m.box(1, 6, 3, 1, 1, 1, Color("eeeeea"))
			return m.set_pivot(3.5, 0, 3.5)
		"bucket":
			var c := Color("e8c21e") if worn else Color("c8191e")
			_disc(m, 9, 0, 10, c)
			m.clear_box(2, 2, 2, 5, 8, 5)
			m.box(1, 2, 1, 7, 1, 7, Color("6f8a96"))  # a bit of grey water
			m.clear_box(2, 2, 2, 5, 1, 5)
			m.box(0, 10, 4, 9, 1, 1, Color("8f9498"))  # the handle
			return m.set_pivot(4.5, 0, 4.5)
		"helmet":
			var c := Color("1e1f22") if worn else (Color("1d3557") if new else Color("c8191e"))
			m.box(1, 0, 0, 7, 6, 10, c)
			m.box(0, 1, 1, 9, 4, 8, c)
			m.box(2, 6, 1, 5, 1, 8, c)
			m.clear_box(2, 0, 0, 5, 3, 3)  # the face
			m.box(1, 0, 5, 1, 2, 2, Color("eeeeea"))  # ear guards
			m.box(7, 0, 5, 1, 2, 2, Color("eeeeea"))
			return m.set_pivot(4.5, 0, 5)
		"skate":
			var boot := Color("1e1f22") if not worn else Color("4a3a2a")
			m.box(1, 2, 0, 5, 4, 14, boot)
			m.box(1, 6, 8, 5, 5, 6, boot)  # the ankle
			m.box(1, 1, 1, 5, 1, 12, Color("eeeeea"))  # holder
			m.box(3, 0, 0, 1, 1, 14, Color("d6dadc"))  # blade
			m.box(1, 5, 2, 5, 1, 6, Color("eeeeea"))  # laces
			return m.set_pivot(3.5, 0, 7)
		"spray_bottle":
			_disc(m, 4, 0, 8, Color("2f9adf"))
			m.box(1, 8, 1, 2, 2, 2, Color("eeeeea"))
			m.box(1, 10, 0, 2, 2, 4, Color("eeeeea"))  # the head
			m.box(1, 8, -1, 1, 2, 1, Color("eeeeea"))  # trigger
			return m.set_pivot(2, 0, 2)
		"first_aid_kit":
			m.box(0, 0, 0, 9, 6, 3, Color("eeeeea"))
			m.box(4, 1, -1, 1, 4, 1, Color("c8191e"))
			m.box(3, 2, -1, 3, 2, 1, Color("c8191e"))
			m.box(3, 6, 1, 3, 1, 1, Color("6e7378"))  # handle
			return m.set_pivot(4.5, 0, 1.5)
		"water_cooler":
			var o := Color("ee6a1a")
			_disc(m, 9, 0, 11, o)
			_disc(m, 9, 11, 1, Color("eeeeea"))
			m.box(3, 2, -1, 2, 1, 1, Color("eeeeea"))  # the tap
			m.box(0, 9, 4, 9, 1, 1, Color("eeeeea"))  # handle
			return m.set_pivot(4.5, 0, 4.5)
	push_error("LooseProps: unknown loose prop '%s'" % id)
	return null


## A round slab `n` voxels across (centred on n/2), `h` high from `y`.
static func _disc(m: VoxelModel, n: int, y: int, h: int, c: Color) -> void:
	_disc_at(m, 0, y, 0, n, h, c)


static func _disc_at(m: VoxelModel, x0: int, y: int, z0: int, n: int, h: int, c: Color) -> void:
	var r := n * 0.5
	for x in n:
		for z in n:
			var dx := x + 0.5 - r
			var dz := z + 0.5 - r
			if dx * dx + dz * dz <= r * r + 0.3:
				m.box(x0 + x, y, z0 + z, 1, h, 1, c)
