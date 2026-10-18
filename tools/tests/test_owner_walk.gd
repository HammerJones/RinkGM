extends SceneTree
## Headless check of the venue walk inside an owner career (RinkLink): the
## walk runs on the career's rink without resetting its clock, its flags (the
## keys) are saved with the career, and walking time moves the career's
## calendar and stops for the Tuesday 22:00 game.
##
##   godot --headless --path . --script tools/tests/test_owner_walk.gd

const PATH := "user://test_owner_walk.json"

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
	var world := Node3D.new()
	root.add_child(world)
	world.add_child(Rink.new())
	var venue := Venue.instantiate_for(Career.exhibition(0), true)
	world.add_child(venue)
	var link := RinkLink.new_owner("Walk", "Test", "C", 5)
	var c := link.career
	var start := [link.sim.day, link.sim.minute]
	var story := WalkStory.start(venue, null, link)
	_expect(story.sim == link.sim, "the walk runs on the career's rink")
	_expect([link.sim.day, link.sim.minute] == start, "starting the walk leaves the rink's clock alone (%s)" % story.clock_text())
	_expect(story.clock_text() == "MON 05:00" and story.first_hour(), "a new owner starts the first hour at 05:00 Monday")

	# the keys stay found across a save
	story.flags["keys"] = true
	c.save_path = PATH
	_expect(c.save() == OK, "the career saves")
	var c2 := Career.load_from(PATH)
	var link2 := RinkLink.resume(c2)
	var story2 := WalkStory.start(venue, null, link2)
	_expect(not story2.first_hour() and story2.flags.has("keys"), "the walk remembers the keys after a load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

	# walking time is the career's time, up to the Tuesday game
	var steps := 0
	while not story.game_due and steps < 2000:
		story.tick(600.0)
		steps += 1
	_expect(story.game_due, "walking runs into the owner's game")
	_expect(link.sim.weekday() == RinkLink.GAME_WEEKDAY and link.sim.minute >= RinkLink.GAME_MINUTE, "it's Tuesday night (%s)" % story.clock_text())
	_expect(c.day == link.sim.day and link.game_due(), "the career followed the walk's clock to its game")

	print("owner walk: %s (%d failure%s)" % ["FAILED" if failures else "OK", failures, "" if failures == 1 else "s"])
	quit(1 if failures else 0)
