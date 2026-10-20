extends SceneTree
## Headless check of the venue's side of a puck leaving play (VenuePhysics):
## glass heights, fan colliders, and a stand-in puck integrator that does
## what Hockey physics is to do: Rink.confine below the glass, and once
## `clears_glass`, gravity plus `contact`/`bounce` against the building. A low
## shot bounces off the boards, one into the glass stays in, one that clears
## the side glass lands in the stands (stopped by fans or seats, never
## through a wall), and one over the bench boards lands on the bench.
##
##   godot --headless --path . --script tools/tests/test_puck_out.gd

const DT := 1.0 / 240.0
const R := 0.04  # puck half-width

var failures := 0
var _venue: Venue
var _space: PhysicsDirectSpaceState3D


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
		printerr("FAIL: test_puck_out timed out")
		quit(1))
	var world := Node3D.new()
	root.add_child(world)
	_venue = Venue.instantiate_for(Career.exhibition(4))
	world.add_child(_venue)
	_venue.set_attendance(1.0)
	_space = world.get_world_3d().direct_space_state
	for i in 3:
		await physics_frame
	var fans := _venue.crowd.get_node_or_null("FanColliders")
	_expect(fans != null and fans.get_child_count() > 0, "a full house has fan colliders (%d boxes for %d fans)" % [fans.get_child_count() if fans else 0, _venue.crowd.count()])
	_expect(is_equal_approx(VenuePhysics.glass_top(Vector2(-7, -Rink.HALF_W)), VenuePhysics.board_top()), "no glass over the player benches")
	_expect(VenuePhysics.glass_top(Vector2(20, Rink.HALF_W)) > 2.2 and VenuePhysics.glass_top(Vector2(Rink.HALF_L, 0)) > 3.4, "side glass about 2.3 m, end glass about 3.5 m")

	var r := await _shot(Vector3(15, 0, 0), Vector3(0, 0, 20))
	_expect(not r.out and absf(r.pos.z) < Rink.HALF_W, "a shot along the ice bounces off the side boards (%s)" % r.pos)
	r = await _shot(Vector3(15, 0, 8), Vector3(0, 4.0, 14))
	_expect(not r.out and absf(r.pos.z) < Rink.HALF_W, "a shot into the side glass stays in (%s)" % r.pos)
	r = await _shot(Vector3(15, 0.5, 6), Vector3(0, 9.0, 14))
	_expect(r.out, "a puck over the box-side glass leaves play")
	var front := Venue.STAND_FRONT
	_expect(r.pos.z > Rink.HALF_W and r.pos.z < Venue.HALF_Z and r.pos.y >= Venue.STAND_Y0 - 0.05, "it lands in the stands, not through them (%s, stands from z %.1f)" % [r.pos, front])
	_venue.set_attendance(0.0)
	await physics_frame
	await physics_frame
	var empty := await _shot(Vector3(15, 0.5, 6), Vector3(0, 9.0, 14))
	_expect(empty.out and empty.pos.z > Rink.HALF_W and empty.pos.z < Venue.HALF_Z, "in an empty house it lands among the seats (%s)" % empty.pos)
	r = await _shot(Vector3(-7, 0.3, -9), Vector3(0, 4.5, -9))
	_expect(r.out and r.pos.z < -Rink.HALF_W and r.pos.z > -Rink.HALF_W - 3.5 and r.pos.y < 1.5, "a puck over the bench boards lands on the bench (%s)" % r.pos)
	print("\n%s (%d failure%s)" % ["FAILED" if failures else "OK", failures, "" if failures == 1 else "s"])
	quit(1 if failures else 0)


## Fires a puck and runs it for four seconds.
func _shot(from: Vector3, v: Vector3) -> Dictionary:
	var pos := from
	var vel := v
	var out := false
	for i in 240 * 4:
		vel.y -= 9.8 * DT
		if out:
			var c := VenuePhysics.contact(_space, pos, vel, R, DT)
			if c.is_empty():
				pos += vel * DT
			else:
				pos = c.point
				vel = VenuePhysics.bounce(vel, c)
		else:
			pos += vel * DT
			if pos.y < 0.0:
				pos.y = 0.0
				vel.y = 0.0
			if VenuePhysics.clears_glass(pos, R):
				out = true
				continue
			var r := Rink.confine(pos, R)
			if r[1] != Vector2.ZERO:
				pos = r[0]
				var n := Vector3(r[1].x, 0, r[1].y)
				vel -= n * maxf(vel.dot(n), 0.0) * 1.6
		if pos.y < 0.0:
			pos.y = 0.0
			vel = Vector3(vel.x * 0.9, 0.0, vel.z * 0.9)
		if i % 8 == 7:
			await physics_frame
	return {"out": out, "pos": pos.snapped(Vector3.ONE * 0.01)}
