extends Node
## Headless checks for real line changes: every dressed player has their own
## body; the ones on the bench stand behind the boards; on the fly a called
## skater skates to the bench's far gate and leaves, and the fresh one steps
## out of the centre-ice gate; at a stoppage the lines swap before the
## faceoff; all three forward lines and both defence pairs see the ice.
## Also: a puck over the glass is whistled dead, with the faceoff in the
## zone it was last played.
## Run: godot --headless --path . --fixed-fps 120 -- --test=lines

var game: Node
var _fails := 0
var _door_changes := 0
var _far_changes := 0
var _before := [[], []]


func _ready() -> void:
	game.autoplay = true
	game.events.line_change.connect(_on_change)
	await get_tree().physics_frame
	await _run()
	print("lines test: ", "FAILED %d" % _fails if _fails else "all passed")
	get_tree().quit(1 if _fails else 0)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: ", what)


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		for team in 2:
			_before[team] = game.team_skaters(team)


## Bodies that just came on during play stepped out of the bench door.
func _on_change(team: int, _on_ice: Array) -> void:
	if game.state != game.State.PLAY:
		return
	var door: Vector2 = game.bench_spot(team)
	for s in game.team_skaters(team):
		if not s in _before[team]:
			if Vector2(s.position.x, s.position.z).distance_to(door) < 1.0:
				_door_changes += 1
			else:
				_far_changes += 1


func _run() -> void:
	var n: int = game.settings.skaters_on_ice
	var dressed := {}  # the opening lines (an injury can bring a spare in late)
	for team in 2:
		for l in game.benches[team].f_lines + game.benches[team].d_pairs:
			for p in l:
				if p:
					dressed[p.id] = true
	for team in 2:
		_check(game.team_skaters(team).size() == n, "team %d starts with %d on the ice" % [team, n])
		_before[team] = game.team_skaters(team)
	# play a stretch: shifts run out and lines change on the fly
	await _wait(150.0)
	print("  door changes %d, elsewhere %d, bodies %d/%d" % [_door_changes, _far_changes, game.benches[0].bodies.size(), game.benches[1].bodies.size()])
	_check(_door_changes > 0, "on-the-fly changes come through the bench gate (%d)" % _door_changes)
	_check(_far_changes == 0, "nobody appears away from the door (%d)" % _far_changes)
	for team in 2:
		var b: Bench = game.benches[team]
		var on: Array = game.team_skaters(team)
		_check(on.size() == n, "team %d still has %d on the ice" % [team, n])
		_check(b.bodies.size() > n, "team %d has more bodies than slots (%d)" % [team, b.bodies.size()])
		var ids := {}
		for s in b.bodies.values():
			_check(not ids.has(s.player.id), "one body per player")
			ids[s.player.id] = true
			if not s in on:
				_check(s.position.z < -Rink.HALF_W, "bench players stand behind the boards (z %.1f)" % s.position.z)
				_check(not s.changing, "parked bodies aren't changing")
		for s in on:
			_check(s.position.z > -Rink.HALF_W, "on-ice bodies are on the ice")
	# every line got a shift
	var toi_ok := true
	for team in 2:
		var b: Bench = game.benches[team]
		for l in b.f_lines + b.d_pairs:
			for p in l:
				if p and dressed.has(p.id) and not b.hurt.has(p.id) and game.box.lines.get(p.id, {}).get("toi", 0.0) < 5.0:
					toi_ok = false
					print("  little ice time: team %d %s %s %.1f s (shift F %.0f s, D %.0f s)" % [team, p.position, p.short_name(), game.box.lines.get(p.id, {}).get("toi", 0.0), game.settings.shift_length("F"), game.settings.shift_length("D")])
	_check(toi_ok, "every line and pair got ice time (injuries aside)")
	# a stoppage swaps the called line before the faceoff. Wait for any
	# change in progress to finish first: a skater still out from a half-done
	# change can be the next line's player too and rightly stays on.
	var b0: Bench = game.benches[0]
	var settle := 0.0
	while settle < 30.0 and not _settled(b0):
		await _wait(0.1)
		settle += 0.1
	_check(_settled(b0), "line changes finish (%.1f s)" % settle)
	b0.f_time = 999.0
	b0.d_time = 999.0
	var was: Array = game.team_skaters(0).duplicate()
	game._whistle(Vector2.ZERO, "test")
	await _wait(2.0)
	var now: Array = game.team_skaters(0)
	var swapped := 0
	for s in now:
		if not s in was:
			swapped += 1
	_check(swapped == n, "a stoppage changes the tired line before the faceoff (%d new)" % swapped)
	for i in now.size():
		_check(now[i].player == b0.profile_for(i), "slot %d holds the bench's player" % i)

	# a puck over the glass is out of play
	await _wait(1.5)
	_check(game.state == game.State.PLAY, "play is back on after the faceoff")
	game._last_played = Vector2(10.0, 5.0)
	game.puck.controller = null
	game.puck.reset_at(Vector3(10.0, 3.0, Rink.HALF_W - 0.2))
	game.puck.vel = Vector3(0, 0, 4.0)
	await _wait(0.2)
	_check(game.state == game.State.STOPPAGE, "a puck over the glass is whistled dead")
	_check(game._pending_faceoff == Vector2(Rink.DOT_X, Rink.DOT_Z), "faceoff at the dot where it was last played (%s)" % str(game._pending_faceoff))


## Every slot holds the bench's player and nobody is heading off.
func _settled(b: Bench) -> bool:
	var on: Array = game.team_skaters(b.team)
	for i in on.size():
		if on[i].player != b.profile_for(i) or on[i].changing:
			return false
	return true
