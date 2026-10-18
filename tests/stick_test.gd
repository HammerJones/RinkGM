extends Node
## Headless checks for stick wear and breaking (StickWear): wear and the
## break odds, losing the puck with a broken stick, getting a new one at the
## bench door or a faceoff.
## Run: godot --headless --path . --fixed-fps 120 -- --test=sticks

var game: Node
var _fails := 0


func _ready() -> void:
	seed(4242)
	await get_tree().physics_frame
	await _run()
	print("sticks test: ", "FAILED %d" % _fails if _fails else "all passed")
	get_tree().quit(1 if _fails else 0)


func _run() -> void:
	var s: Skater = game.skaters[1]  # an AI skater on the human's team

	# --- wear and the odds
	s.stick_health = 1.0
	StickWear.stress(s, 1.0, &"test")
	if s.stick_broken:
		StickWear.fresh(s)
	else:
		_check(is_equal_approx(s.stick_health, 1.0 - StickWear.WEAR), "a slapshot's load wears the stick")
	var fresh := _break_rate(s, 1.0, 1.0)
	var worn := _break_rate(s, 0.15, 1.0)
	var tough := _break_rate(s, 1.0, 3.0)
	print("break odds per 5 slapshots' load: new %.3f, worn %.3f, durable %.3f" % [fresh, worn, tough])
	_check(worn > fresh * 3.0, "a worn stick breaks far more easily")
	_check(tough < fresh, "a more durable stick breaks less")

	# --- a broken stick loses the puck and can't touch it
	await _settle()
	var at := Vector2(-4.0, 8.0)  # clear of every faceoff spot, so no teammate is standing there
	s.place(at, Vector3(1, 0, 0))
	game.puck.reset_at(Vector3(at.x + 0.8, 0, at.y))
	game.puck.frozen = false
	game.puck.controller = s
	await _wait(0.2)
	_check(s.has_puck(), "carrying before the break")
	var broke := [0]
	game.stick_broken.connect(func(_who, _id, _c): broke[0] += 1)
	StickWear.snap(s, &"test")
	await _wait(0.1)
	_check(broke[0] == 1, "the break is reported")
	_check(not s.has_puck(), "a broken stick loses the puck")
	_check(not s.blade_down(), "a broken stick can't touch the puck")

	# --- the AI goes to its bench door for a new one
	var replaced := [0]
	game.stick_replaced.connect(func(_who): replaced[0] += 1)
	var door: Vector2 = game.bench_spot(s.team)
	game.puck.reset_at(Vector3(-door.x, 0, 6.0))
	game.puck.controller = null
	var t := 0.0
	while s.stick_broken and t < 10.0 and game.state == game.State.PLAY:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	print("new stick from the bench after %.1f s (state %d)" % [t, game.state])
	_check(not s.stick_broken and replaced[0] == 1, "the bench hands over a new stick")
	_check(Vector2(s.position.x, s.position.z).distance_to(door) < StickWear.BENCH_REACH + 0.5 or game.state != game.State.PLAY,
		"it was handed over at the bench door")

	# --- or at the next faceoff
	StickWear.snap(s, &"test")
	game._start_faceoff(Vector2.ZERO)
	_check(not s.stick_broken, "a faceoff comes with a new stick")


func _break_rate(s: Skater, health: float, durability: float) -> float:
	var n := 4000
	var broke := 0
	s.stick_durability = durability
	for i in n:
		s.stick_broken = false
		s.stick_health = health
		if StickWear.stress(s, 5.0, &"test"):
			broke += 1
	s.stick_durability = 1.0
	StickWear.fresh(s)
	return float(broke) / n


func _settle() -> void:
	while game.state != game.State.PLAY:
		await get_tree().physics_frame


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		_fails += 1
