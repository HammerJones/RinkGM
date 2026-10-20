extends SceneTree
## The bulb scoreboard: digits light the right bulbs, the period maps to a
## digit, clock mode blanks the scores, a worn board has dead bulbs, and the
## whole board is one draw.
##
##   godot --headless --path . --script tools/tests/test_bulb_board.gd

var fails := 0


func _init() -> void:
	_run.call_deferred()


func _expect(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		printerr("FAIL: ", what)
	else:
		print("  ok  ", what)


func _board(age: int) -> BulbBoard:
	var k := VenueKit.new(1, age)
	var b := BulbBoard.make(age, 7)
	var xf := Transform3D(Basis.IDENTITY, Vector3(0, 8, 0))
	b.add_face(k, xf, Vector2(6.0, 2.0), false)
	var holder := Node3D.new()
	root.add_child(holder)
	k.add(b)
	k.commit(holder)
	return b


func _run() -> void:
	var b := _board(VenueRoom.Age.RENOVATED)
	# 4 score digits and the period (20 bulbs each), 4 clock digits (27), colon
	_expect(b.bulb_count() == 5 * 20 + 4 * 27 + 2, "wall face has %d bulbs" % b.bulb_count())
	var mmis := b.find_children("*", "MultiMeshInstance3D", true, false)
	_expect(mmis.size() == 1 and mmis[0].multimesh.use_colors, "one coloured MultiMesh for all bulbs")
	# 8 = 7 segments; "1" lights a full column of 7 (n=2) bulbs
	b.show_score({"home": 8, "away": 1, "period": "1ST", "clock": "00:00"})
	var n_00 := b.lit_count()
	b.show_score({"home": 88, "away": 1, "period": "1ST", "clock": "00:00"})
	_expect(b.lit_count() - n_00 == 20, "a second 8 lights 20 more bulbs (%d)" % (b.lit_count() - n_00))
	_expect(BulbBoard.period_glyph("2ND") == "2" and BulbBoard.period_glyph("OT") == "4", "period digits")
	b.show_time(19, 5)
	b.mode = "clock"
	var clock_lit := b.lit_count()
	b.show_score({"home": 88, "away": 88, "period": "3RD", "clock": "00:00"})
	_expect(b.lit_count() == clock_lit, "clock mode ignores score updates")
	b.mode = "game"
	_expect(b.lit_count() > clock_lit, "game mode shows the score again")
	var worn := _board(VenueRoom.Age.WORN)
	worn.show_score({"home": 88, "away": 88, "period": "8", "clock": "88:88"})
	var dead := worn.bulb_count() - worn.lit_count()
	_expect(dead > 0 and dead < worn.bulb_count() / 10, "worn board has a few dead bulbs (%d)" % dead)
	print("bulb board test: ", "all passed" if fails == 0 else "%d failed" % fails)
	quit(1 if fails > 0 else 0)
