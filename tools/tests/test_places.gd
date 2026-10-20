extends SceneTree
## Headless check of Venue.places() for World's RinkPeople: every key is
## there in the building with the rec wing, and every place is standing room:
## a floor under it and nothing solid where a person would stand.
##
##   godot --headless --path . --script tools/tests/test_places.gd

const KEYS := ["canteen", "canteen_staff", "washroom", "glass", "pro_shop", "skate_rental", "bench", "entrance",
	"lobby", "office", "plant_room", "zamboni_bay", "dressing_room", "penalty_box"]

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _expect(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", what)
	else:
		print("  ok  ", what)


func _run() -> void:
	create_timer(120.0).timeout.connect(func():
		printerr("FAIL: test_places timed out")
		quit(1))
	var world := Node3D.new()
	root.add_child(world)
	world.add_child(Rink.new())
	var venue := Venue.instantiate_for(Career.exhibition(0), true)
	world.add_child(venue)
	for d in venue.all_doors():
		d.open()
	for i in 90:
		await physics_frame
	var space := world.get_world_3d().direct_space_state
	var places := venue.places()
	for key in KEYS:
		_expect(places.has(key) and places[key].size() > 0, "%s has places (%d)" % [key, places.get(key, []).size()])
	var body := PhysicsShapeQueryParameters3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.22
	shape.height = 1.2
	body.shape = shape
	body.collision_mask = VenueKit.VENUE_LAYER
	var bad := []
	var n := 0
	for key in places:
		for p in places[key]:
			n += 1
			var ray := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.0, 0), p + Vector3(0, -0.4, 0), VenueKit.VENUE_LAYER)
			var hit := space.intersect_ray(ray)
			body.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 0.95, 0))
			var blocked := space.intersect_shape(body, 1)
			if hit.is_empty() or absf(hit.position.y - p.y) > 0.3 or not blocked.is_empty():
				bad.append("%s %s%s" % [key, p, " (no floor)" if hit.is_empty() else (" (in %s)" % blocked[0].collider.get_parent().name if not blocked.is_empty() else " (floor at %.2f)" % hit.position.y)])
	_expect(bad.is_empty(), "all %d places are standing room %s" % [n, bad])
	var seats := 0
	for r in venue.get_children():
		if r is VenueRoom and r.has_method("seats"):
			seats += r.seats().size()
	_expect(seats > 1000, "the stands list their seats (%d)" % seats)
	print("\n%s (%d failure%s)" % ["FAILED" if failures else "OK", failures, "" if failures == 1 else "s"])
	quit(1 if failures else 0)
