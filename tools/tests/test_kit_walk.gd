extends SceneTree
## Headless check of the owner's kit in the venue walk (KitHud): the watch
## comes up and takes a timer, the bag opens and holds the walk, the nets come
## off the rack by the gate, stepping on the ice in shoes halves the pace and
## starts the balance game, a net goes down on the ice and the sim counts it,
## a fall drops what's carried, Gus's crampons end the wobble, the gym's
## ball dribbles at the owner's side and drops through the hoop when the shot
## is right, and the weight room's machines are there to train on.
##
##   godot --headless --path . --script tools/tests/test_kit_walk.gd

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _expect(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL: ", what)
	else:
		print("  ok  ", what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _key(walk: Node, k: Key, shift := false) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.shift_pressed = shift
	e.pressed = true
	walk._unhandled_input(e)


func _run() -> void:
	create_timer(120.0).timeout.connect(func():
		printerr("FAIL: test_kit_walk timed out")
		quit(1))
	var walk: Node = load("res://scenes/venue/venue_walk.tscn").instantiate()
	root.add_child(walk)
	await _frames(3)
	var kit: KitHud = walk.kit
	var ops: RinkOps = walk.story.sim.ops
	_expect(kit != null and kit.spots.size() == 3, "the net racks and the crampons can are by the gate")

	_key(walk, KEY_Q)
	_key(walk, KEY_T)
	_expect(kit.watch_up and kit.kit.watch.timers.size() == 1, "Q raises the watch and T starts a timer")
	_key(walk, KEY_T)
	_expect(kit.kit.watch.timers.size() == 1, "the gas-station watch holds one")
	_key(walk, KEY_Q)
	_key(walk, KEY_TAB)
	_expect(kit.bag_open and walk._busy(), "Tab opens the bag and the owner stands still")
	_key(walk, KEY_TAB)
	_expect(not kit.bag_open, "Tab closes it")

	# the big nets, off the rack inside the bay door
	walk.walker.global_position = Vector3(35.6, 0.05, -3.4)
	await _frames(2)
	walk._act({"carry": "large"})
	_expect(kit.kit.carrying == "large" and kit.kit.in_storage("large", ops) == 3, "a big net comes off the rack")

	# onto the ice in shoes
	walk.walker.global_position = Vector3(20.0, 0.05, 0.0)
	await _frames(3)
	_expect(kit.balancing and is_equal_approx(walk.walker.speed_scale, IceBalance.SPEED_SCALE), "on the ice in shoes: half pace and the wobble")
	_expect(kit.hands_hint() == "[E] SET THE NET DOWN", "the prompt says set the net down")
	walk._use()
	_expect(kit.kit.carrying == "" and int(ops.nets_on[0]) == 1 and kit.kit.nets_out.size() == 1, "the net is down and the sim counts it")
	walk._use()
	_expect(kit.kit.carrying == "large" and int(ops.nets_on[0]) == 0, "and lifts again")

	# a fall drops it and leaves the owner on the ice for a moment
	kit._fall()
	_expect(kit.kit.carrying == "" and int(ops.nets_on[0]) == 1 and kit.down_t > 0.0, "a fall drops the net on the ice")
	await _frames(2)
	_expect(walk.walker.speed_scale == 0.0, "the owner is down")

	# Gus's crampons
	walk.story.flags["crampons"] = true
	await _frames(2)
	_expect(kit.kit.has_crampons(), "the crampons go in the bag")
	kit.down_t = 0.0
	await _frames(2)
	_expect(not kit.balancing and walk.walker.speed_scale == 1.0, "with crampons on the ice is just floor")

	walk.walker.global_position = Vector3(-42.0, 0.05, -7.0)
	await _frames(2)
	_expect(not kit.balancing, "off the ice, no wobble")
	await _pickup(walk)
	await _training(walk)
	print("kit walk: %s (%d failure%s)" % ["FAILED" if failures else "OK", failures, "" if failures == 1 else "s"])
	quit(1 if failures else 0)


func _pickup(walk: Node) -> void:
	var cart: VenueSpot = walk.venue.spot("pickup_basketball")
	_expect(cart != null and (cart.data.hoops as Array).size() == 2, "the gym's ball cart knows both hoops")
	if cart == null:
		return
	var kit: KitHud = walk.kit
	var hoop: Dictionary = cart.data.hoops[1]
	var rim := Vector3(float(hoop.rim[0]), float(hoop.rim[1]), float(hoop.rim[2]))
	# the free-throw line, facing the hoop
	walk.walker.global_position = Vector3(rim.x - 4.2, 0.05, rim.z)
	walk._yaw = -PI * 0.5
	walk._pitch = atan2(rim.y - VenueWalker.EYE, 4.2)  # looking at the rim
	await _frames(3)
	walk._act({"pickup": cart.data})
	var g := kit.pickup
	_expect(g != null, "the ball cart starts a pickup game")
	# dribbling in place: the ball keeps coming back to the hand
	var far := 0.0
	for i in 240:
		await physics_frame
		far = maxf(far, g.ball.global_position.distance_to(g._hand()))
	_expect(far < 1.2, "the ball dribbles at the owner's side (strays %.2f m)" % far)
	# find the power that drops it in from the line, as a player would
	var made_at := -1.0
	for step in range(30, 46):
		var before := g.makes
		g.hold()
		g.charge = step * 0.02
		g.release()
		for i in 200:
			await physics_frame
			if g._flying == 0.0:
				break
		if g.makes > before:
			made_at = step * 0.02
			break
	_expect(made_at > 0.0, "a free throw at %.0f%% power goes in" % (made_at * 100.0))
	_expect(g.shots > g.makes, "and the short ones don't count (%d of %d)" % [g.makes, g.shots])


func _training(walk: Node) -> void:
	for id in ["train_squat_rack", "train_bench", "train_dumbbells", "train_treadmill", "train_bike"]:
		_expect(walk.venue.spot(id) != null, "the weight room has %s" % id)
	_expect(walk.kit.act({"train": "squat_rack"}).contains("CAREER"), "outside a career a set is just exercise")
