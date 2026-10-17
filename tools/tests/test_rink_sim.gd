extends SceneTree
## Rink management core: a looked-after rink keeps good ice and its customers,
## a neglected one loses both; saves round-trip; better tools read truer.
##   godot --headless --path . --script res://tools/tests/test_rink_sim.gd [-- --days=28]

var failures := 0


func _initialize() -> void:
	var days := 28
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.trim_prefix("--days="))
	var cared := _run(days, true)
	var neglected := _run(days, false)
	print("cared for: %s" % _summary(cared))
	print("neglected: %s" % _summary(neglected))
	if _avg_ice(cared) < 55.0:
		_fail("a looked-after rink should average 55+ ice, got %.0f" % _avg_ice(cared))
	if _avg_ice(neglected) > _avg_ice(cared) - 10.0:
		_fail("neglect should cost at least 10 ice points (%.0f vs %.0f)" % [_avg_ice(neglected), _avg_ice(cared)])
	if neglected.ice_rep >= cared.ice_rep:
		_fail("neglect should cost reputation")
	_check_save()
	_check_instruments()
	_check_offers()
	_check_thickness()
	_check_compressor_logistics()
	_check_refrigerants()
	_check_dues()
	if failures:
		printerr("test_rink_sim: %d failure(s)" % failures)
	else:
		print("test_rink_sim: ok")
	quit(1 if failures else 0)


## Runs `days` days. A caring owner resurfaces before every session, walks the
## plant each morning, keeps Doris fed and fixes what the readings show.
func _run(days: int, care: bool) -> RinkSim:
	var s := RinkSim.create(7)
	s.auto_resurface = care
	for d in days:
		if care:
			for o in s.offers():
				s.sign(o.id)
			s.job("plant_round")
			if s.doris.fuel < 0.3:
				s.job("refuel_doris")
			if s.doris.part("towel").condition < 0.3:
				s.job("towel_change")
			if s.doris.part("blade").condition < 0.25:
				s.job("blade_change", {"height_mm": 1.0})
			if s.doris.part("spark_plugs").condition < 0.2 or s.doris.engine_oil < 0.3:
				s.job("engine_tune")
			for i in s.plant.compressors.size():
				if s.plant.compressors[i].tripped:
					s.job("compressor_valve_job", {"compressor": i})
				elif float(s.plant.compressors[i].oil) < 0.35:
					s.job("compressor_oil_change", {"compressor": i})
			if s.plant.glycol_litres < RefrigerationPlant.LOOP_LITRES * 0.97:
				s.job("glycol_top_up", {"litres": RefrigerationPlant.LOOP_LITRES - s.plant.glycol_litres, "pct": 60.0})
			if d % 7 == 3:
				s.job("clean_building")
			if d == 2:
				s.job("descale_condenser")
		else:
			if s.doris.fuel < 0.3:
				s.job("refuel_doris")
		s.advance_days(1)
	return s


func _avg_ice(s: RinkSim) -> float:
	var t := 0.0
	var n := 0
	for b in s.books:
		if float(b.ice) >= 0.0:
			t += float(b.ice)
			n += 1
	return t / maxf(n, 1.0)


func _summary(s: RinkSim) -> String:
	var rev := 0.0
	var cost := 0.0
	var kwh := 0.0
	for b in s.books:
		rev += float(b.revenue)
		cost += float(b.costs)
		kwh += float(b.kwh)
	return "avg ice %.0f, rep %.0f, temp %.1f C, %.0f mm, revenue $%.0f, costs $%.0f, %.0f kWh/day, contracts %s, comp %s/%s" % [
		_avg_ice(s), s.ice_rep, s.ice.surface_temp, s.ice.thickness_mm, rev, cost, kwh / maxf(s.books.size(), 1.0),
		s.contracts.keys(), "tripped" if s.plant.compressors[0].tripped else "ok", "tripped" if s.plant.compressors[1].tripped else "ok"]


func _check_save() -> void:
	var a := RinkSim.create(3)
	a.auto_resurface = true
	a.advance_days(2)
	a.advance(5 * 60)
	var b := RinkSim.from_dict(JSON.parse_string(JSON.stringify(a.to_dict(), "", true, true)))  # full precision, or the replay drifts
	b.auto_resurface = true
	a.advance_days(2)
	b.advance_days(2)
	# JSON keeps ~15 digits, so the two drift in the last place; compare what matters
	var ka := a.contracts.keys()
	var kb := b.contracts.keys()
	ka.sort()
	kb.sort()
	if a.day != b.day or a.minute != b.minute or ka != kb \
			or absf(a.money - b.money) > 1.0 or absf(a.ice.surface_temp - b.ice.surface_temp) > 0.05 \
			or absf(a.ice.smoothness - b.ice.smoothness) > 0.01 or absf(a.ice_rep - b.ice_rep) > 0.1:
		_fail("a loaded save should play on like the original: %s %s %d/%d %d/%d $%.2f vs $%.2f, %.2f C vs %.2f C, rep %.2f vs %.2f" % [a.contracts.keys(), b.contracts.keys(), a.day, b.day, a.minute, b.minute,
			a.money, b.money, a.ice.surface_temp, b.ice.surface_temp, a.ice_rep, b.ice_rep])


func _check_instruments() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var err := [0.0, 0.0]
	for i in 200:
		err[0] += absf(float(SimInstrument.read("ice_temp", 0, -5.0, rng).value) + 5.0)
		err[1] += absf(float(SimInstrument.read("ice_temp", 1, -5.0, rng).value) + 5.0)
	if err[1] >= err[0] * 0.5:
		_fail("the infrared gun should read much truer than the screwdriver (%.2f vs %.2f)" % [err[1] / 200.0, err[0] / 200.0])
	var s := RinkSim.create(1)
	s.money = 1000.0
	if not s.buy_tool("ice_temp", 1) or s.tools.ice_temp != 1:
		_fail("buying the infrared thermometer")


func _check_offers() -> void:
	var s := RinkSim.create(1)
	var low := s.offers().size()
	s.ice_rep = 90.0
	for r in RinkSim.ROOMS:
		s.rooms[r] = Wear.RENOVATED
	s.cleanliness = 1.0
	var ids: Array = []
	for o in s.offers():
		ids.append(o.id)
	if not "dukes_practice" in ids or ids.size() <= low:
		_fail("great ice and renovated rooms should bring the Dukes, got %s" % ids)
	if not s.sign("dukes_practice") or not s.contracts.has("dukes_practice"):
		_fail("signing the Dukes")


## Thin ice is cheap, hard and dry but fragile; thick ice holds its cold and its
## edges but stays wet longer after a flood.
func _check_thickness() -> void:
	var thin := IceSlab.new()
	var thick := IceSlab.new()
	thin.thickness_mm = 30.0
	thick.thickness_mm = 48.0
	for s in [thin, thick]:
		s.surface_temp = -5.5
		s.smoothness = 0.9
	if thick.dry_minutes(450.0) <= thin.dry_minutes(450.0) + 3.0:
		_fail("a flood on thick ice should take longer to dry (%.0f vs %.0f min)" % [thick.dry_minutes(450.0), thin.dry_minutes(450.0)])
	if thin.rating("hockey") <= thick.rating("hockey") or thick.rating("figure") <= thin.rating("figure"):
		_fail("hockey should prefer thin ice and figure thick")
	# lights off and the plant down for an hour: the thick sheet holds its cold
	var a := thin.surface_temp
	thin.run(1.0, 120.0, 0.0, 0.0)
	thick.run(1.0, 120.0, 0.0, 0.0)
	if thick.surface_temp - a >= thin.surface_temp - a:
		_fail("thick ice should warm more slowly")
	var t2 := IceSlab.new()
	t2.thickness_mm = 20.0
	var t3 := IceSlab.new()
	t3.thickness_mm = 40.0
	t2.run(1.0, 0.0, 0.0, 20.0)
	t3.run(1.0, 0.0, 0.0, 20.0)
	if t2.smoothness >= t3.smoothness:
		_fail("thin ice should gouge faster")
	# a fresh flood: hockey minds the wet, the figure club barely does
	var f := IceSlab.new()
	f.thickness_mm = 40.0
	f.surface_temp = -5.0
	var before_h := f.rating("hockey")
	var before_f := f.rating("figure")
	f.resurface(1.0, 0.0, 450.0)
	if f.rating("hockey") / before_h >= f.rating("figure") / before_f:
		_fail("wet ice should cost hockey more than figure skating")


func _check_compressor_logistics() -> void:
	var s := RinkSim.create(4)
	s.money = 100000.0
	if not s.order_compressor("nordale_rc6"):
		_fail("ordering an RC-6")
		return
	s.advance_days(7 * 7 + 1)
	if not "nordale_rc6" in s.delivered:
		_fail("the RC-6 should have arrived in about six weeks, orders %s" % [s.orders])
		return
	var cap_before := s.plant.capacity_kw()
	var r := s.job("install_compressor", {"compressor": 0, "model": "nordale_rc6"})
	if not r.ok or s.plant.compressor_health(0) != 0.0:
		_fail("installing takes compressor 1 out: %s" % r.text)
	s.rent_chiller(5)
	if s.plant.capacity_kw() <= cap_before * 0.6:
		_fail("the rental chiller should keep most of the capacity")
	s.advance_days(6)
	if s.plant.compressors[0].model != "nordale_rc6" or s.plant.compressor_health(0) < 0.8:
		_fail("compressor 1 should be a healthy RC-6 now")
	if s.plant.rental_kw != 0.0:
		_fail("the rental should have gone home")


func _check_refrigerants() -> void:
	if PlantCatalog.refill_price("r22", 2) <= PlantCatalog.refill_price("r22", 1) or PlantCatalog.refill_price("r22", 3) >= 0.0:
		_fail("R-22 should get dearer, then be unobtainable")
	var s := RinkSim.create(2)
	s.money = 100000.0
	if s.job("convert_refrigerant", {"to": "co2"}).ok:
		_fail("old Nordales can't run on CO2")
	var p := RefrigerationPlant.create_old()
	var amm := p.efficiency()
	p.refrigerant = "r22"
	if p.efficiency() >= amm:
		_fail("ammonia should be the more efficient refrigerant")
	# a CO2 plant pays some of its bill back in heat
	var c := RinkSim.create(3)
	for i in c.plant.compressors.size():
		c.plant.install_compressor(i, "kryomax_co2")
	c.plant.refrigerant = "co2"
	c.advance_days(2)
	if float(c.books[0].ledger.get("heat recovered", 0.0)) <= 0.0:
		_fail("CO2 should recover heat")
	# a failed seal on ammonia empties the building
	var a := RinkSim.create(9)
	a.plant.compressors[0].seal.condition = 0.0
	a.advance_days(30)
	if a.evacuated_day < 0:
		_fail("a failed seal on ammonia should cause a release within a month")


func _check_dues() -> void:
	var s := RinkSim.create(5)
	s.advance_days(RinkSim.LEAGUE_FREE_DAYS)
	if float(s.league.owed) > 0.0:
		_fail("the owner plays free while they learn")
	s.advance_days(2)
	if float(s.league.owed) != RinkSim.LEAGUE_DUES:
		_fail("Dale should ask for dues")
	s.advance_days(RinkSim.LEAGUE_GRACE_DAYS)
	if s.owner_can_play():
		_fail("no dues, no game")
	if not s.pay_dues() or not s.owner_can_play():
		_fail("paying the dues should get the sweater back")


func _fail(msg: String) -> void:
	printerr(msg)
	failures += 1
