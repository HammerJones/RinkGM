extends SceneTree
## Real sticks, stick racks and the pro shop (playtest #28, #34, #35, #36,
## #40):
##   - every stick variant builds a cheap shared mesh;
##   - sticks spawn asleep in every rack, at every age, with no stick
##     overlapping a rack's collider or another stick;
##   - woken, they settle and sleep again without leaving their racks;
##   - a walker pushed into a rack knocks a stick over (and `knocked` fires),
##     and the stick settles and sleeps;
##   - far from the camera resting sticks leave physics, and come back;
##   - the pro shop and its back room build, every dressing room and the
##     benches have real sticks on a walk, a match venue has none;
##   - the walk routes into the shop, the back room and a dressing room pass.
##   godot --headless --path . --script res://tools/tests/test_sticks_props.gd

const RACKS := ["stick_rack_wall", "stick_rack_shop", "stick_rack_aframe", "stick_barrel", "stick_rack_team"]
const SHRINK := 0.003  # contact slop allowed between a resting stick and a rack

var failures := 0
var _root: Node3D
var _venue: Venue


func _init() -> void:
	_run.call_deferred()


func _expect(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", what)
	else:
		print("  ok  ", what)


func _run() -> void:
	create_timer(240.0).timeout.connect(func():
		printerr("FAIL: test_sticks_props timed out")
		quit(1))
	_root = Node3D.new()
	root.add_child(_root)
	_check_meshes()
	await _check_racks()
	await _check_push()
	await _check_far()
	await _check_venue()
	print("\n%s (%d failure%s)" % ["FAILED" if failures else "OK", failures, "" if failures == 1 else "s"])
	quit(1 if failures else 0)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


# ---------------------------------------------------------------- meshes

func _check_meshes() -> void:
	var worst := 0
	var n := 0
	for model in StickProps.MODELS:
		for hand in [1, -1]:
			for junior in [false, true]:
				for tape in StickProps.TAPES:
					var v := StickProps.variant(model, hand, junior, tape)
					var m := StickProps.stick_mesh(v)
					if m == null or m.get_surface_count() == 0:
						_expect(false, "%s has a mesh" % StickProps.key(v))
						continue
					if StickProps.stick_mesh(v) != m:
						_expect(false, "%s mesh is cached" % StickProps.key(v))
					worst = maxi(worst, Venue._tris(m))
					n += 1
	_expect(worst <= 900, "%d stick variants, at most %d triangles each (budget 900)" % [n, worst])
	var v := StickProps.variant("warlock", 1, false, "black")
	_expect(StickProps.describe(v) == "Warlock HEX, left curve, senior, black tape", "describe(): %s" % StickProps.describe(v))
	var a := StickProps.stick_mesh(v).get_aabb()
	_expect(a.size.y > 1.6 and a.size.y < 1.85, "a senior stick is %.2f m tall in stick space" % a.size.y)


# ---------------------------------------------------------------- racks

## Every rack at every age, filled: asleep at spawn, no overlaps; then woken,
## they settle in place and sleep again.
func _check_racks() -> void:
	var all: Array[StickProp] = []
	var start := {}
	for age in 3:
		var room := Node3D.new()
		_root.add_child(room)
		var k := VenueKit.new(age, age)
		k.slab(Vector3(-10, -0.3, -10 - age * 30), Vector3(30, 0, 10 - age * 30), Color.GRAY)
		var sticks := {}
		for i in RACKS.size():
			var id: String = RACKS[i]
			var vs := []
			for j in StickProps.slots(id).size():
				vs.append(StickProps.pick(["honest", "kodiak", "warlock", "shorewood", "team"], i, j, 0.3))
			sticks[id] = StickProps.fill(k, id, Vector3(i * 5.0, 0, -age * 30.0), PI * 0.5 * i, vs, true)  # quarter turns: kit colliders are axis-aligned
		k.commit(room)
		await _frames(4)
		for id in sticks:
			var list: Array[StickProp] = sticks[id]
			var label := "%s/%s" % [id, Wear.NAMES[age]]
			var asleep := list.all(func(s: StickProp) -> bool: return s.sleeping)
			_expect(list.size() == StickProps.slots(id).size() and asleep, "%s: %d sticks spawn asleep" % [label, list.size()])
			var hits := _overlaps(list)
			_expect(hits.is_empty(), "%s: no stick overlaps the rack or another stick%s" % [label, "" if hits.is_empty() else " (%s)" % ", ".join(hits)])
			if age == Wear.WORN:
				for s in list:
					all.append(s)
					start[s] = s.global_transform
	# wake the worn set and let it settle
	for s in all:
		s.sleeping = false
	await _frames(120 * 3)
	var moved := {}
	var awake := {}
	for s in all:
		var id := _rack_of(s)
		var xf: Transform3D = start[s]
		var d := s.global_position.distance_to(xf.origin)
		moved[id] = maxf(float(moved.get(id, 0.0)), d)
		if not s.sleeping:
			awake[id] = int(awake.get(id, 0)) + 1
	for id in RACKS:
		var limit := 0.3 if id == "stick_barrel" else 0.12  # barrel sticks slump onto the rim
		_expect(float(moved.get(id, 0.0)) < limit and int(awake.get(id, 0)) == 0,
			"%s: woken sticks settle in place and sleep (moved at most %.3f m, %d still awake)" % [id, float(moved.get(id, 0.0)), int(awake.get(id, 0))])
	for c in _root.get_children():
		c.queue_free()
	await _frames(2)


func _rack_of(s: StickProp) -> String:
	# racks were laid out 5 m apart along x
	return RACKS[clampi(roundi(s.get_meta("rack_x", s.global_position.x) / 5.0), 0, RACKS.size() - 1)]


## Names of sticks whose (slightly shrunk) collision boxes intersect the
## venue's colliders or another stick.
func _overlaps(list: Array[StickProp]) -> Array:
	var out := []
	if list.is_empty():
		return out
	var space := list[0].get_world_3d().direct_space_state
	for s in list:
		s.set_meta("rack_x", s.global_position.x)
		for c in s.get_children():
			if not c is CollisionShape3D:
				continue
			var cs := c as CollisionShape3D
			var box := BoxShape3D.new()
			box.size = (cs.shape as BoxShape3D).size - Vector3.ONE * SHRINK * 2.0
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = box
			q.transform = cs.global_transform
			q.collision_mask = (1 << (VenueKit.VENUE_LAYER - 1)) | (1 << (StickProp.LAYER - 1))
			q.exclude = [s.get_rid()]
			var hits := space.intersect_shape(q, 4)
			for h in hits:
				var other: Object = h.collider
				out.append("%s at %s hits %s" % [s.describe(), s.global_position.snapped(Vector3.ONE * 0.01), other.get_class() if not other is StickProp else "a stick"])
	return out


# ---------------------------------------------------------------- push

## A walker runs into a full wall rack: sticks get knocked over, `knocked`
## names the walker, and they settle and sleep again.
func _check_push() -> void:
	var room := Node3D.new()
	_root.add_child(room)
	var k := VenueKit.new(5, Wear.WORN)
	k.slab(Vector3(-5, -0.3, -6), Vector3(5, 0, 2), Color.GRAY)
	k.block(Vector3(-5, 0, 0.195), Vector3(5, 2.5, 0.4), Color.GRAY)  # the wall behind the rack
	var vs := []
	for j in 14:
		vs.append(StickProps.pick(["honest", "kodiak", "team"], 9, j, 0.0))
	var list := StickProps.fill(k, "stick_rack_wall", Vector3.ZERO, 0.0, vs, true)
	k.commit(room)
	var knocked_by := []
	for s in list:
		s.knocked.connect(func(by: Node) -> void: knocked_by.append(by))
	var start := {}
	for s in list:
		start[s] = s.global_transform
	await _frames(4)
	var w := VenueWalker.new()
	room.add_child(w)
	w.global_position = Vector3(0.1, 0.05, -2.5)
	await _frames(6)
	w.running = true
	w.wish = Vector3(0, 0, 1)
	await _frames(120)
	w.wish = Vector3(0, 0, -1)
	await _frames(60)
	w.wish = Vector3.ZERO
	var over := 0
	for s in list:
		var xf: Transform3D = start[s]
		var tilt := rad_to_deg(xf.basis.y.angle_to(s.global_basis.y))
		if tilt > 20.0 or s.global_position.distance_to(xf.origin) > 0.15:
			over += 1
	_expect(over > 0, "a walker pushed into a wall rack knocks %d stick(s) over" % over)
	_expect(knocked_by.has(w), "knocked(by) names the walker (%d knock signal(s))" % knocked_by.size())
	var settled := false
	for i in 12:
		await _frames(60)
		if list.all(func(s: StickProp) -> bool: return s.sleeping):
			settled = true
			break
	var awake := list.filter(func(s: StickProp) -> bool: return not s.sleeping).size()
	for s in list:
		if not s.sleeping or s.global_position.y < -0.1:
			print("    awake/low stick at %s v %s" % [s.global_position.snapped(Vector3.ONE * 0.01), s.linear_velocity.snapped(Vector3.ONE * 0.01)])
	_expect(settled, "knocked sticks settle and sleep (%d still awake)" % awake)
	var floor_ok := list.all(func(s: StickProp) -> bool: return s.global_position.y > -0.1)
	_expect(floor_ok, "no stick fell through the floor")
	room.queue_free()
	await _frames(2)


# ---------------------------------------------------------------- far

## With a camera far away, a field's resting sticks leave physics; near,
## they come back asleep.
func _check_far() -> void:
	var room := Node3D.new()
	_root.add_child(room)
	var cam := Camera3D.new()
	room.add_child(cam)
	cam.current = true
	cam.position = Vector3(0, 1.6, -60)
	var k := VenueKit.new(6, Wear.WORN)
	k.slab(Vector3(-3, -0.3, -3), Vector3(3, 0, 3), Color.GRAY)
	var vs := []
	for j in 6:
		vs.append(StickProps.pick(["shorewood"], 3, j, 0.0))
	var list := StickProps.fill(k, "stick_barrel", Vector3.ZERO, 0.0, vs, true)
	k.commit(room)
	await create_timer(0.8).timeout
	var off := list.all(func(s: StickProp) -> bool: return s.process_mode == Node.PROCESS_MODE_DISABLED)
	_expect(off, "resting sticks 60 m from the camera are out of physics")
	cam.position = Vector3(0, 1.6, -3)
	await create_timer(0.8).timeout
	var on := list.all(func(s: StickProp) -> bool: return s.process_mode != Node.PROCESS_MODE_DISABLED and s.sleeping)
	_expect(on, "near the camera they are back, still asleep")
	var field := list[0].field
	_expect(field.counts() == Vector2i(6, 0) and field.find_child("Resting", false, false) != null, "the field draws its 6 resting sticks as one mesh")
	room.queue_free()
	await _frames(2)


# ---------------------------------------------------------------- venue

func _check_venue() -> void:
	var match_venue := Venue.instantiate_for(Career.exhibition(0))
	_root.add_child(match_venue)
	await process_frame
	_expect(_count_sticks(match_venue) == 0, "a match venue has no physics sticks (static copies only)")
	match_venue.queue_free()
	await process_frame
	_venue = Venue.instantiate_for(Career.exhibition(0), true)
	_root.add_child(_venue)
	for age in 3:
		_venue.set_all_ages(age)
		await process_frame
		var shop: VenueRoom = _venue.rooms["pro_shop"]
		var n := _count_sticks(shop)
		_expect(n >= 35, "%s pro shop has %d real sticks for sale" % [Wear.NAMES[age], n])
		_expect(_has_prop(shop, "skate_sharpener", age) and _has_prop(shop, "skate_rack_tags", age), "%s pro shop back room has the sharpener and the customer skate rack" % Wear.NAMES[age])
		var r := RecPlan.rect("pro_shop")
		_expect(r.size.x * r.size.y > 125.0, "the pro shop is %.1f x %.1f m" % [r.size.x, r.size.y])
	_expect(_venue.door("Back room") != null, "the back room has a door")
	var counts := []
	for id in ["locker_3", "locker_4", "locker_5", "locker_6", "locker_home", "locker_away", "benches"]:
		var c := _count_sticks(_venue.rooms[id])
		counts.append("%s %d" % [id, c])
		_expect(c >= 4, "%s has real sticks (%d)" % [id, c])
	var st := _venue.stats()
	print("  walk venue with sticks: ", st)
	_venue.set_all_ages(Wear.WORN)
	await process_frame
	for d in _venue.all_doors():
		d.open()
	await _frames(70)
	await _walk("hall to the pro shop", Vector3(-26.0, 0, -42.0), [Vector3(-26.0, 0, -37.5)], "pro_shop")
	await _walk("shop floor round the counter into the back room", Vector3(-26.0, 0, -38.0),
		[Vector3(-21.6, 0, -37.9), Vector3(-21.6, 0, -31.2), Vector3(-27.5, 0, -31.0), Vector3(-30.3, 0, -31.0), Vector3(-30.4, 0, -31.8)], "pro_shop")
	await _walk("front desk to the gym past the moved lobby wall", Vector3(-42.0, 0, -42.6), [Vector3(-27.0, 0, -42.3), Vector3(-25.0, 0, -42.3), Vector3(-25.0, 0, -47.5)], "gym")
	await _walk("hall to dressing room 5", Vector3(15.0, 0, -42.0), [Vector3(18.0, 0, -42.0), Vector3(18.0, 0, -38.5), Vector3(19.5, 0, -36.0)], "locker_5")


func _count_sticks(n: Node) -> int:
	return n.find_children("*", "StickProp", true, false).size()


func _has_prop(room: Node, id: String, age: int) -> bool:
	var mesh := Props.mesh(id, age)
	for c in room.find_children("*", "MultiMeshInstance3D", true, false):
		if (c as MultiMeshInstance3D).multimesh.mesh == mesh:
			return true
	return false


func _walk(what: String, start: Vector3, points: Array, room_id: String) -> Vector3:
	var w := VenueWalker.new()
	_venue.add_child(w)
	w.global_position = start + Vector3(0, 0.05, 0)
	for i in 10:
		await physics_frame
	for p in points:
		var stuck := 0
		var last: Vector3 = w.global_position
		for i in 120 * 12:
			var to: Vector3 = p - w.global_position
			to.y = 0.0
			if to.length() < 0.35:
				break
			w.wish = to.normalized()
			await physics_frame
			if i % 60 == 59:
				stuck = stuck + 1 if w.global_position.distance_to(last) < 0.2 else 0
				last = w.global_position
				if stuck >= 3:
					break
	w.wish = Vector3.ZERO
	for i in 20:
		await physics_frame
	var room := _venue.room_at(w.global_position + Vector3(0, 0.5, 0))
	var got := room.room_id if room else "-"
	var end: Vector3 = points.back()
	var flat := Vector2(w.global_position.x - end.x, w.global_position.z - end.z).length()
	_expect(got == room_id and flat < 0.6, "walk %s: ended in %s at %s" % [what, got, w.global_position.snapped(Vector3.ONE * 0.01)])
	var at := w.global_position
	w.queue_free()
	return at
