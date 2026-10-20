class_name PlaceMap
extends Node3D
## Where people can walk in the venue and where the named places are
## (PEOPLE.md 7). The walkable floor is a navigation mesh baked from the
## venue's own colliders, so stairs, aisles and furniture are respected and
## a renovation that moves a wall just rebakes. Doors are baked open; people
## open and close the real ones as they pass (RinkPeople).
##
## The venue (Venue.places()) or its rooms can name spots as
## {"canteen": [Vector3...], ...} in venue space; anything still missing
## falls back to the guesses below, from the rooms' bounds and spawns.

signal ready_to_walk

const ICE_HALF := Vector2(30.0, 13.0)   # the ice sheet, x and z half sizes
const ICE_CORNER := 8.5

var venue: Node3D
var places := {}            # place name -> Array[Vector3] (venue space)
var seats: Array = []       # [[position, facing], ...] from the stands
var doors: Array = []       # VenueDoor
var baked := false
var _holds := {}            # person id -> [place, point index] (claim)
var _region: NavigationRegion3D


## Builds the places now and bakes the walk mesh in the background.
func build(v: Node3D) -> void:
	venue = v
	_collect_places()
	_bake()


func _rooms() -> Array:
	return venue.call("_room_nodes") if venue and venue.has_method("_room_nodes") else []


func _room(id: String) -> Node:
	for r in _rooms():
		if r.room_id == id:
			return r
	return null


func _collect_places() -> void:
	places.clear()
	seats.clear()
	doors = venue.all_doors() if venue and venue.has_method("all_doors") else []
	# the doors in the rink boards aren't for walking through: people don't
	# open them in passing and the walk mesh keeps them shut
	doors = doors.filter(func(d) -> bool: return not d is RinkDoor)
	if venue and venue.has_method("places"):
		# the venue names its own spots (checked for floor and standing room)
		var vp: Dictionary = venue.places()
		for k in vp:
			_add(k, vp[k])
	for r in _rooms():
		if r.has_method("seats"):
			seats.append_array(r.seats())
		if r.has_method("places"):
			var p: Dictionary = r.places()
			for k in p:
				_add(k, p[k])
	_fallbacks()


func _add(name_: String, pts) -> void:
	if not places.has(name_):
		places[name_] = []
	for p in (pts if pts is Array else [pts]):
		places[name_].append(p)


## Spots for places no room has named yet, from the current venue layout.
func _fallbacks() -> void:
	var lobby := _room("lobby")
	if lobby and not places.has("entrance"):
		var out: float = lobby.bounds.position.x + 0.8
		_add("entrance", [Vector3(out, 0, -2.0), Vector3(out, 0, 2.0)])
	if lobby and not places.has("lobby"):
		var b: AABB = lobby.bounds
		for i in 8:
			_add("lobby", Vector3(lerpf(b.position.x + 2.0, b.end.x - 2.0, (i % 4) / 3.0), 0, -4.0 + 8.0 * float(i / 4)))
	if not places.has("canteen"):
		# the snack bar counters face +Z at z -11.25; the line runs away from them
		for i in 10:
			_add("canteen", Vector3(-39.5, 0, -10.2 + i * 0.7))
	for pair in [["dressing_room", ["locker_home", "locker_away"]], ["bench", ["benches"]], ["penalty_box", ["penalty_boxes"]],
			["zamboni_bay", ["zamboni_bay"]], ["plant_room", ["plant_room"]], ["office", ["office"]]]:
		if places.has(pair[0]):
			continue
		for id in pair[1]:
			var r := _room(id)
			if r:
				_add(pair[0], r.spawn)
	if not places.has("washroom"):
		# the arena's washrooms are in the rec wing; without it, the lobby's far end
		var w := _room("rec_washrooms")
		_add("washroom", w.spawn if w else (lobby.bounds.end - Vector3(2.0, lobby.bounds.size.y, 2.0) if lobby else Vector3.ZERO))
	if not places.has("glass"):
		# standing room along the walkways in front of both stands
		for side in [-1.0, 1.0]:
			for i in 12:
				_add("glass", Vector3(-22.0 + i * 4.0, 0, side * (Venue.STAND_FRONT - 0.7)))
	if not places.has("pro_shop") and lobby:
		_add("pro_shop", lobby.spawn)
	if not places.has("stands"):
		for s in seats:
			_add("stands", s[0])
	var wings: bool = venue != null and venue.has_method("has_wings") and venue.has_wings()
	if not places.has("vending"):
		# in front of the lobby's two machines by the rink doors (and the rec lobby's)
		_add("vending", [Vector3(-35.6, 0, 11.45), Vector3(-35.6, 0, 12.45)])
		if wings:
			_add("vending", Vector3(-36.0, 0, -29.7))
	if not places.has("hall"):
		# somewhere to wander: the lobby, the walkways along the boards, the rec hall
		for p in places.get("lobby", []).slice(0, 4):
			_add("hall", p)
		var g: Array = places.get("glass", [])
		for i in range(0, g.size(), 3):
			_add("hall", g[i])
		if wings:
			for x in [-30.0, -18.0, -6.0, 6.0, 18.0]:
				_add("hall", Vector3(x, 0, -42.0))
	if wings and not places.has("parking"):
		# the stalls nearest the arena's front doors, both sides of the lane
		for z in [7.5, 10.5, 13.5, 16.5, 19.5, -7.5, -10.5, -13.5, -16.5, -19.5, 22.5, -22.5]:
			_add("parking", Vector3(-58.5, 0, z))
	if wings and not places.has("street"):
		# where people on foot come round the building from the road
		_add("street", [Vector3(-51.5, 0, 26.0), Vector3(-51.5, 0, -26.0), Vector3(-74.0, 0, 1.5)])


## Work-point reservation (W28): `who` takes a free point of `place`, one
## person per point, giving up any point they held before. Vector3.INF when
## every point is taken: they find something else to do rather than stack.
func claim(place: String, who: String) -> Vector3:
	var held: Array = _holds.get(who, [])
	if not held.is_empty() and held[0] == place:
		return point(place, held[1])
	release(who)
	var pts: Array = places.get(place, [])
	var taken := {}
	for h: Array in _holds.values():
		if h[0] == place:
			taken[h[1]] = true
	for i in pts.size():
		if not taken.has(i):
			_holds[who] = [place, i]
			return pts[i]
	return Vector3.INF


func release(who: String) -> void:
	_holds.erase(who)


## A point for `place`, picked by `i` (so people spread out), or Vector3.INF.
func point(place: String, i := 0) -> Vector3:
	if place == "ice":
		return ice_point(i)
	var pts: Array = places.get(place, [])
	return pts[posmod(i, pts.size())] if not pts.is_empty() else Vector3.INF


## Somewhere on the ice, inside the rounded corners.
func ice_point(i: int) -> Vector3:
	var h := hash(i * 7919 + 13)
	var x := ((h & 0xffff) / 65535.0 * 2.0 - 1.0) * (ICE_HALF.x - 1.5)
	var z := (((h >> 16) & 0xffff) / 65535.0 * 2.0 - 1.0) * (ICE_HALF.y - 1.5)
	var cx := absf(x) - (ICE_HALF.x - ICE_CORNER)
	var cz := absf(z) - (ICE_HALF.y - ICE_CORNER)
	if cx > 0.0 and cz > 0.0 and Vector2(cx, cz).length() > ICE_CORNER - 1.5:
		var v := Vector2(cx, cz).normalized() * (ICE_CORNER - 1.5)
		x = signf(x) * (ICE_HALF.x - ICE_CORNER + v.x)
		z = signf(z) * (ICE_HALF.y - ICE_CORNER + v.y)
	return Vector3(x, 0, z)


static func on_ice(p: Vector3) -> bool:
	return absf(p.x) < ICE_HALF.x and absf(p.z) < ICE_HALF.y and p.y < 0.5


## A walking path in venue space. Straight line until the bake is done.
func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if not baked or not is_inside_tree():
		return PackedVector3Array([from, to])
	var map := get_world_3d().navigation_map
	var xf := venue.global_transform if venue else Transform3D.IDENTITY
	var p := NavigationServer3D.map_get_path(map, xf * from, xf * to, true)
	if p.is_empty():
		return PackedVector3Array([from, to])
	var inv := xf.affine_inverse()
	for i in p.size():
		p[i] = inv * p[i]
	return p


# ------------------------------------------------------------------- baking

func _bake() -> void:
	if venue == null:
		return
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1 << (VenueKit.VENUE_LAYER - 1)
	nm.cell_size = 0.25
	nm.cell_height = 0.1
	nm.agent_radius = 0.25
	nm.agent_height = 1.7
	nm.agent_max_climb = 0.3
	nm.agent_max_slope = 40.0
	nm.filter_baking_aabb = AABB(Vector3(-Venue.HALF_X - 30.0, -0.5, -Venue.HALF_Z - 40.0), Vector3(Venue.HALF_X * 2 + 60.0, 9.0, Venue.HALF_Z * 2 + 80.0))
	var src := NavigationMeshSourceGeometryData3D.new()
	# bake through doorways: the leaves' colliders are switched off for the parse
	var saved := []
	for d in doors:
		for b in d.find_children("*", "CollisionObject3D", true, false):
			saved.append([b, b.collision_layer])
			b.collision_layer = 0
	NavigationServer3D.parse_source_geometry_data(nm, src, venue)
	for s in saved:
		s[0].collision_layer = s[1]
	_region = NavigationRegion3D.new()
	_region.name = "WalkMesh"
	add_child(_region)
	var map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, nm.cell_size)
	NavigationServer3D.map_set_cell_height(map, nm.cell_height)
	NavigationServer3D.bake_from_source_geometry_data_async(nm, src, _baked.bind(nm))


func _baked(nm: NavigationMesh) -> void:
	if not is_instance_valid(_region):
		return
	_region.navigation_mesh = nm
	baked = true
	ready_to_walk.emit()
