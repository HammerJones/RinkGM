extends SceneTree
## RINK-OS text helpers: rules, meters, stat lines and captions.


func _init() -> void:
	var fails := 0
	fails += _eq(RinkOS.rule("scoreboard", 20), "// SCOREBOARD ------")
	fails += _eq(RinkOS.rule("", 8), "// -----")
	fails += _eq(RinkOS.meter(0.64), "[######----]")
	fails += _eq(RinkOS.meter(1.5, 4), "[####]")
	fails += _eq(RinkOS.meter(-1.0, 4), "[----]")
	fails += _eq(RinkOS.dots("Speed", "64"), "SPEED........ 64")
	fails += _eq(RinkOS.key("Shot accuracy"), "SHOT_ACCURACY")
	fails += _eq(RinkOS.caption("Next game"), "[ NEXT GAME ]")
	fails += _eq(RinkOS.clock(295.2), "04:56")
	fails += _eq(RinkOS.clock(-3.0), "00:00")
	if fails == 0:
		print("rinkos text test: all passed")
	quit(1 if fails > 0 else 0)


func _eq(got: String, want: String) -> int:
	if got == want:
		return 0
	push_error("expected '%s', got '%s'" % [want, got])
	return 1
