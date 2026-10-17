extends SceneTree
## Headless venue check: builds the building in every renovation age, checks
## the room set, human-scale doors, crowd sizes per tier and the geometry
## budget, then walks a person through it (lobby -> rink walkway -> bench
## side -> home dressing room, up a grandstand aisle to the concourse, and up
## the lobby stairs to the manager's office). Exit code 1 on any failure.
##
##   godot --headless --path . --script tools/tests/test_venue.gd

const ROOMS := ["shell", "roof", "stands_bench", "stands_box", "benches", "penalty_boxes", "glass",
	"lobby", "office", "locker_home", "locker_away", "zamboni_bay", "lighting", "scoreboard"]
## Triangles the whole building may use, crowd and props included. A
## mid-range GPU (GTX 1060 class) draws several million per frame at 60 fps;
## 1.6M keeps the building well under that. The kit's arena seats are about
## 70% of it, so a low-detail seat is the first place to save.
const TRI_BUDGET := 1600000
## Meshes, MultiMeshes and sign labels. Forward+ handles thousands of draws
## per frame on that class of GPU; a couple of hundred static ones is little.
const DRAW_BUDGET := 260

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
	# a script error stops this coroutine; don't let CI hang on it
	create_timer(300.0).timeout.connect(func():
		printerr("FAIL: test_venue timed out")
		quit(1))
	_root = Node3D.new()
	root.add_child(_root)
	# low tier: worn, a handful of fans
	var low := _make(0)
	var low_fans := low.crowd.count()
	_expect(low.rink_name.ends_with("COMMUNITY RINK"), "beer-league rink is a community rink (%s)" % low.rink_name)
	for id in ROOMS:
		_expect(low.rooms.has(id), "room %s exists" % id)
	var ages := low.get_state().values()
	_expect(ages.count(VenueRoom.Age.WORN) >= ROOMS.size() - 5, "a beer-league rink is mostly worn (%s)" % [ages])
	low.queue_free()
	await process_frame
	var mid := _make(3)
	_expect(mid.crowd.count() > low_fans * 2, "senior crowd (%d) is well above beer league (%d)" % [mid.crowd.count(), low_fans])
	mid.queue_free()
	await process_frame
	# every age builds; worn stands lose planks, renovated get chairs
	_venue = _make(2)
	var seats := []
	for age in 3:
		var t0 := Time.get_ticks_msec()
		_venue.set_all_ages(age)
		var st := _venue.stats()
		var n := 0
		for id in ["stands_bench", "stands_box"]:
			n += _venue.rooms[id].seats().size()
		seats.append(n)
		print("  %-9s built in %d ms: %s, %d seats" % [VenueRoom.AGE_NAMES[age], Time.get_ticks_msec() - t0, st, n])
		_expect(st.triangles < TRI_BUDGET, "%s: %d triangles within budget %d" % [VenueRoom.AGE_NAMES[age], st.triangles, TRI_BUDGET])
		_expect(st.draws < DRAW_BUDGET, "%s: %d draws within %d" % [VenueRoom.AGE_NAMES[age], st.draws, DRAW_BUDGET])
		_expect(st.lights <= 12 and _no_shadows(_venue), "%s: %d lights, none casting shadows" % [VenueRoom.AGE_NAMES[age], st.lights])
	_expect(seats[0] < seats[1], "worn stands have missing planks (%d < %d seats)" % [seats[0], seats[1]])
	# human-scale doors (bench and box gates are half doors by design)
	for d in _venue.all_doors():
		var gate := d.height < 1.5
		_expect(d.width >= 0.9 and (gate or d.height >= 2.1), "door %s is %.2f x %.2f m" % [d.label, d.width, d.height])
	_venue.set_all_ages(VenueRoom.Age.WORN)
	for d in _venue.all_doors():
		d.open()
	await _frames(70)  # doors swing open
	await _walk_tests()
	print("\n%s (%d failure%s)" % ["FAILED" if failures else "OK", failures, "" if failures == 1 else "s"])
	quit(1 if failures else 0)


func _no_shadows(n: Node) -> bool:
	if n is Light3D and n.shadow_enabled:
		return false
	if n is GeometryInstance3D and n.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		return false
	for c in n.get_children():
		if not _no_shadows(c):
			return false
	return true


func _make(tier: int) -> Venue:
	var v := Venue.instantiate_for(Career.exhibition(tier))
	_root.add_child(v)
	return v


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _walk_tests() -> void:
	var lobby: Vector3 = _venue.rooms["lobby"].spawn
	await _walk("lobby to home dressing room", lobby, [
		Vector3(-36.0, 0, -8.5), Vector3(-32.0, 0, -8.5), Vector3(-29.0, 0, -15.9), Vector3(28.0, 0, -15.9),
		Vector3(32.5, 0, -12.0), Vector3(36.0, 0, -12.0), Vector3(38.0, 0, -10.0),
	], "locker_home")
	# up an aisle: walkway, aisle stair, ten rows of half steps, concourse
	var ax := -Venue.STAND_X + 0.6
	await _walk("bench-side aisle to the concourse", Vector3(ax, 0, -15.9), [Vector3(ax, 0, -27.0)], "stands_bench", Venue.STAND_Y0 + Venue.STAND_ROWS * Venue.ROW_RISE)
	await _walk("lobby stairs to the manager's office", Vector3(-36.0, 0, 12.6), [
		Vector3(-45.0, 0, 12.6), Vector3(-45.0, 0, 10.5), Vector3(-38.5, 0, 9.0), Vector3(-38.5, 0, -7.2), Vector3(-42.0, 0, -7.2),
	], "office", Venue.LOBBY_H + 0.3)
	await _walk("Zamboni bay from the rink walkway", Vector3(32.0, 0, 0.0), [Vector3(36.0, 0, 0.0), Vector3(37.0, 0, 3.0)], "zamboni_bay")


## Walks a VenueWalker from `start` through `points`; passes if it ends in
## room `room_id` (at height `floor_y`, give or take a step).
func _walk(what: String, start: Vector3, points: Array, room_id: String, floor_y := 0.0) -> void:
	var w := VenueWalker.new()
	_venue.add_child(w)
	w.global_position = start + Vector3(0, 0.05, 0)
	w.running = true
	await _frames(10)
	for p in points:
		var stuck := 0.0
		var last: Vector3 = w.global_position
		for i in 120 * 25:
			var to: Vector3 = p - w.global_position
			to.y = 0.0
			if to.length() < 0.35:
				break
			w.wish = to.normalized()
			await physics_frame
			if i % 60 == 59:
				stuck = stuck + 1.0 if w.global_position.distance_to(last) < 0.2 else 0.0
				last = w.global_position
				if stuck >= 3:
					break
	w.wish = Vector3.ZERO
	await _frames(30)
	var room := _venue.room_at(w.global_position + Vector3(0, 0.5, 0))
	var got := room.room_id if room else "-"
	_expect(got == room_id and absf(w.global_position.y - floor_y) < 0.4,
		"walk %s: ended in %s at %s" % [what, got, w.global_position.snapped(Vector3.ONE * 0.01)])
	w.queue_free()
