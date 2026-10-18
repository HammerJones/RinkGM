extends SceneTree
## The rink office's view of the sim: the grid, fuzzy readings, the week's
## P&L, the job queue and Gus's goals.


func _init() -> void:
	var fails := 0
	var sim := OfficeData.demo_sim(3, 14 * 60)
	fails += _check(sim.weekday() == 3 and sim.minute == 14 * 60, "demo sim lands on Wednesday 14:00")

	# Grid: 7 days of 80 cells, Monday first; Tuesday's beer league is booked
	# at 22:00, Doris floods at 21:30, and at the intermission the owner
	# floods in full gear (RINK_SIM 7.5: nobody else is on staff in M1).
	var week := OfficeData.grid_week(sim)
	fails += _check(week.size() == 7 and week[0].name == "Mon" and week[0].cells.size() == 80, "grid is 7 x 80, Monday first")
	var tue: Array = week[1].cells
	var c22 := OfficeData._cell(22.0)
	fails += _check(tue[c22].kind == "session" and tue[c22].booking.org == "vbl_d", "Tuesday 22:00 is the beer league")
	fails += _check(tue[c22 - 2].kind == "flood" and tue[c22 - 2].crew == "you", "you flood at 21:30")
	fails += _check(tue[c22 + 4].kind == "flood" and tue[c22 + 4].crew == "you", "the owner floods the 23:00 intermission in gear")
	fails += _check(OfficeData.slot_class(2, 17.0) == "prime" and OfficeData.slot_class(2, 10.0) == "dead"
		and OfficeData.slot_class(6, 22.0) == "shoulder", "slot classes")
	fails += _check(OfficeData.grid_summary(sim).unstaffed == 0, "no unstaffed floods in the first week")

	# Readings: words with the starting tools, numbers once a tool is bought.
	fails += _eq(OfficeData.reading_text("oil_quality", {"value": 0.7, "text": "amber", "sigma": 0.25, "instrument": "Sight glass"}).text, "amber, probably")
	fails += _eq(OfficeData.reading_text("compressor_health", {"value": 0.7, "text": "fine, probably", "sigma": 0.2, "instrument": "It sounds rough"}).text, "fine, probably")
	fails += _eq(OfficeData.reading_text("ice_thickness", {"value": 48.0, "text": "48.0", "sigma": 5.0, "instrument": "Drill and ruler"}).text, "way too thick?")
	fails += _eq(OfficeData.reading_text("ice_temp", {"value": -4.62, "text": "-4.6", "sigma": 0.5, "instrument": "Infrared thermometer"}).text, "-4.6 C +/-0.5")
	fails += _check(OfficeData.log_book(sim).size() == 3, "a plant round each morning, Monday to Wednesday")
	for e in OfficeData.log_book(sim):
		for k in e.readings:
			if OfficeData.reading_kind(k) == "status":
				continue  # the panel lights say running or tripped, plainly
			var shown := OfficeData.reading_text(OfficeData.reading_kind(k), e.readings[k])
			fails += _check(not shown.text.is_valid_float() and shown.fuzzy, "starting tools never show a bare number (%s)" % k)

	# P&L: Monday and Tuesday are on the books, with electricity in the costs.
	var pl := OfficeData.week_pl(sim)
	fails += _check(pl.days == 2 and pl.total_out > 0.0, "two finished days in the week's P&L")
	var cats: Array = pl.costs.map(func(c): return c[0])
	fails += _check("electricity" in cats and "insurance" in cats, "electricity and the fixed bills are line items")
	fails += _check(OfficeData.power_bill(sim).last == OfficeData.FIRST_POWER_BILL and OfficeData.power_bill(sim).pace > 0.0, "power bill and pace")

	# Jobs: queue two, run one; the hours come off the owner's day.
	var h := sim.hours_left
	OfficeData.job_queue(sim).append({"id": "compressor_oil_change", "args": {"compressor": 0}})
	OfficeData.job_queue(sim).append({"id": "edge_ice", "args": {}})
	fails += _check(is_equal_approx(OfficeData.queue_hours(sim), 4.0), "queued hours")
	var r := OfficeData.run_next(sim)
	fails += _check(r.ok and is_equal_approx(sim.hours_left, h - 2.5) and OfficeData.job_queue(sim).size() == 1, "running the oil change")

	# Goals: Gus's four notes, kept by the sim; number 1 waits for a decision.
	var goals := OfficeData.goals(sim)
	fails += _check(goals.size() == 4, "four goals")
	fails += _check(goals[2].id == "compressor_1" and not goals[2].done, "compressor 1 is undecided after an oil change")
	fails += _check(not goals[3].done, "minor hockey is not signed")

	# Clock and blocks.
	fails += _check(OfficeData.block_of(5 * 60 + 30) == 0 and OfficeData.block_of(12 * 60) == 1
		and OfficeData.block_of(23 * 60) == 2 and OfficeData.block_of(30) == 2 and OfficeData.block_of(3 * 60) == 3, "blocks")
	fails += _check(OfficeData.minutes_to_next_block(5 * 60) == 120 and OfficeData.minutes_to_next_block(14 * 60) == 180
		and OfficeData.minutes_to_next_block(23 * 60) == 120 and OfficeData.minutes_to_next_block(3 * 60) == 120, "next block")
	if fails == 0:
		print("office data test: all passed")
	quit(1 if fails > 0 else 0)


func _check(ok: bool, what: String) -> int:
	if ok:
		return 0
	push_error("failed: " + what)
	return 1


func _eq(got: String, want: String) -> int:
	if got == want:
		return 0
	push_error("expected '%s', got '%s'" % [want, got])
	return 1
