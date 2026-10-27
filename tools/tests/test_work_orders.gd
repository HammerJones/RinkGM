extends SceneTree
## Jobs handed to staff on the RINK-OS calendar (WorkOrders): who can take
## which job and when, and the sim doing it on their time, not the owner's.
##
##   godot --headless --path . --script tools/tests/test_work_orders.gd

var failures := 0


func _init() -> void:
	var cast := Cast.load_region(1)
	var by := {}
	for p: Person in cast.people.values():
		if p.role == "staff":
			by[p.name] = p
	var andre: Person = by["André Clarke"]      # maintenance tech, Mon-Fri 7:00-15:30
	var priya: Person = by["Priya Sandhu"]      # booking coordinator
	var earl: Person = by["Earl Bratt"]         # head icemaker
	_expect("plant" in WorkOrders.trades_of(andre), "the maintenance tech works on the plant (%s)" % [WorkOrders.trades_of(andre)])
	_expect("ice" in WorkOrders.trades_of(earl), "the head icemaker works on the ice (%s)" % [WorkOrders.trades_of(earl)])
	_expect(WorkOrders.trades_of(priya).is_empty(), "the booking coordinator takes no jobs")

	var sim := OfficeData.demo_sim(3, 9 * 60)   # Wednesday 09:00
	var d := sim.day
	_expect(WorkOrders.why_not(sim, priya, "plant_round", d, 10 * 60) != "", "not their line of work: refused")
	_expect(WorkOrders.why_not(sim, andre, "plant_round", d, 6 * 60) != "", "before their shift: refused")
	_expect(WorkOrders.why_not(sim, andre, "plant_round", d, 8 * 60) != "", "already gone by: refused")
	_expect(WorkOrders.why_not(sim, andre, "compressor_valve_job", d, 10 * 60) != "", "a 6 h job that runs past their shift: refused")
	_expect(WorkOrders.why_not(sim, andre, "plant_round", d + 4, 10 * 60) != "", "on their day off: refused")

	var hours := sim.hours_left
	var cash := sim.money
	var r := WorkOrders.assign(sim, andre, "compressor_oil_change", d, 10 * 60, {"compressor": 0})
	_expect(r.ok, "handed the oil change to André at 10:00 (%s)" % r.text)
	_expect(WorkOrders.why_not(sim, andre, "plant_round", d, 11 * 60) != "", "and he can't take a second job at the same time")
	var r2 := WorkOrders.assign(sim, andre, "replace_fan_belt", d, 13 * 60)
	_expect(r2.ok, "a later job the same day is fine (%s)" % r2.text)
	WorkOrders.cancel(sim, WorkOrders.on_day(sim, d)[1])
	_expect(WorkOrders.on_day(sim, d).size() == 1, "an order can be taken back before it runs")

	sim.advance(2 * 60)  # to 11:00
	var o: Dictionary = WorkOrders.on_day(sim, d)[0]
	_expect(o.get("ok", false), "the order ran at 10:00 (%s)" % o.get("text", "not run"))
	_expect(str(o.get("text", "")).begins_with("André:"), "in André's name (%s)" % o.get("text", ""))
	_expect(absf(sim.hours_left - hours) < 0.001, "without spending the owner's hours (%.2f -> %.2f)" % [hours, sim.hours_left])
	_expect(sim.money < cash - 200.0, "the parts still come out of the till (%.0f -> %.0f)" % [cash, sim.money])
	_expect(not WorkOrders.cancel(sim, o), "a done order can't be taken back")

	var copy := RinkSim.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())))
	_expect(copy.work_orders.size() == sim.work_orders.size(), "orders survive a save")
	print("work orders test: ", "FAILED %d" % failures if failures else "all passed")
	quit(1 if failures else 0)


func _expect(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1
