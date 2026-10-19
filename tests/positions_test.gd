extends Node
## Headless check that the AI plays its positions (TeamSystem): both teams
## play a stretch at Beer League D (level 0) and again at Senior AAA (level
## 3), and every quarter second each skater's distance from where their
## position belongs in the current phase is recorded. A structured side must
## stay clearly closer to its spots than a beer league one once a phase has
## settled, and closer overall and in the zones (at least three of offence,
## breakout, forecheck and D zone). Spots follow
## the play (TeamSystem.focus), not a puck flying faster than anyone can
## skate. The one skater whose job right now is the puck (the forechecker,
## the loose-puck chaser) isn't counted; extra chasers are. Prints a table
## by position and phase.
## Run: godot --headless --path . --fixed-fps 120 -- --test=positions [--heatmaps=dir] [--seconds=200]
## With --heatmaps, also writes an overhead sheet per tier to `dir`: one rink
## per phase (top row with the puck: offence, attack, breakout; bottom row
## without: forecheck, gap, D zone), attacking to the right with the puck on
## the right-hand side (bottom of the picture). Rings mark where the system
## puts each position with the puck at the black dot; around each, in the
## position's colour (C yellow, LW blue, RW green, LD purple, RD red), where
## its players actually were relative to their spot once the phase had
## settled (SETTLED seconds in). A
## structured side shows tight clouds on the rings, a beer league a smear.

const LEVELS := [0.0, 3.0]
const SAMPLE := 0.25
const CELL := 0.5      # m per heatmap cell
const SCALE := 4       # px per cell
const SPLAT := 3       # cells either side of a sample
const SETTLED := 1.5   # s in a phase before the heatmaps count it
## A typical puck spot per phase (attack frame, on the right-hand side), for
## drawing where the system puts each position on the heatmaps.
const SHOW_PUCK := {TeamSystem.Phase.OFFENCE: Vector2(21.0, 8.0), TeamSystem.Phase.ATTACK: Vector2(0.0, 5.0),
	TeamSystem.Phase.BREAKOUT: Vector2(-25.0, 6.0), TeamSystem.Phase.FORECHECK: Vector2(22.0, 8.0),
	TeamSystem.Phase.GAP: Vector2(0.0, 5.0), TeamSystem.Phase.DZONE: Vector2(-22.0, 9.0)}
const ROLE_COLOURS := {"C": Color(0.95, 0.75, 0.1), "LW": Color(0.2, 0.45, 0.95), "RW": Color(0.15, 0.7, 0.3), "LD": Color(0.6, 0.25, 0.8), "RD": Color(0.9, 0.2, 0.2)}
## Panel order on the sheet.
const SHEET := [TeamSystem.Phase.OFFENCE, TeamSystem.Phase.ATTACK, TeamSystem.Phase.BREAKOUT,
	TeamSystem.Phase.FORECHECK, TeamSystem.Phase.GAP, TeamSystem.Phase.DZONE]

var game: Node
var _fails := 0
var _seconds := 200.0
var _heat_dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seconds="):
			_seconds = a.trim_prefix("--seconds=").to_float()
		elif a.begins_with("--heatmaps="):
			_heat_dir = a.trim_prefix("--heatmaps=")
	game.autoplay = true
	seed(777)
	await get_tree().physics_frame
	var results := []
	for lv in LEVELS:
		results.append(await _play(lv))
	_report(results)
	print("positions test: ", "FAILED %d" % _fails if _fails else "all passed")
	get_tree().quit(1 if _fails else 0)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL: ", what)


## Plays `_seconds` of game time with both sides at `level`; returns
## {dist: {role: {phase: [sum, n]}}, heat: {role: [ours, theirs]}}.
func _play(level: float) -> Dictionary:
	game.team_ai = [TierAI.for_level(level), TierAI.for_level(level)]
	game.restart()
	await get_tree().physics_frame
	var dist := {}
	var set_up := [0.0, 0]  # [sum, n] once the phase has settled
	var heat := {}
	var cols := int(Rink.LENGTH / CELL) + 1
	var rows := int(Rink.WIDTH / CELL) + 1
	for r in TeamSystem.ROLES:
		dist[r] = {}
		heat[r] = []
		for ph in TeamSystem.PHASE_NAMES.size():
			var grid := PackedFloat32Array()
			grid.resize(cols * rows)
			heat[r].append(grid)
	var t := 0.0
	var next := 0.0
	var holder := -1  # the team that last had the puck under control
	var team_ph := [-1, -1]
	var settled := [0.0, 0.0]  # s each team has been in its current phase
	while t < _seconds:
		await get_tree().physics_frame
		if game.state == game.State.OVER:
			game.restart()
		if game.state != game.State.PLAY:
			continue
		t += 1.0 / Engine.physics_ticks_per_second
		if t < next:
			continue
		next = t + SAMPLE
		var puck: Puck = game.puck
		if puck.controller:
			holder = puck.controller.team
		for team in 2:
			var tp := TeamSystem.phase(team, holder, TeamSystem.to_frame(game, team, Vector2(puck.position.x, puck.position.z)).x)
			settled[team] = settled[team] + SAMPLE if tp == team_ph[team] else 0.0
			team_ph[team] = tp
		for s: Skater in game.skaters:
			if s.changing or s == puck.controller or s.ai_on_puck:
				continue
			var role := TeamSystem.role_of(s, game)
			var ph := TeamSystem.phase(s.team, holder, TeamSystem.to_frame(game, s.team, Vector2(puck.position.x, puck.position.z)).x)
			var p := TeamSystem.focus(game, s.team)
			var ss := TeamSystem.strong_side(s.team, p)
			var want := TeamSystem.spot(role, ph, p, TeamSystem.role_of(puck.controller, game) if puck.controller and puck.controller.team == s.team else "", ss)
			var at := TeamSystem.to_frame(game, s.team, Vector2(s.position.x, s.position.z))
			var acc: Array = dist[role].get(ph, [0.0, 0])
			acc[0] += at.distance_to(want)
			acc[1] += 1
			dist[role][ph] = acc
			if settled[s.team] >= SETTLED:
				set_up[0] += at.distance_to(want)
				set_up[1] += 1
			# the heatmaps show the set-up once a phase has settled (not the
			# skate there), each sample as how far off its spot it was, laid
			# around the formation for a typical puck (mirrored so the puck's
			# side is always the right-hand side, the bottom of the picture)
			if settled[s.team] < SETTLED:
				continue
			var shown := TeamSystem.spot(role, ph, SHOW_PUCK[ph], "", 1.0) + (at - want) * Vector2(1.0, ss)
			var cx := int((shown.x + Rink.HALF_L) / CELL)
			var cy := int((shown.y + Rink.HALF_W) / CELL)
			var grid: PackedFloat32Array = heat[role][ph]
			for dy in range(-SPLAT, SPLAT + 1):
				for dx in range(-SPLAT, SPLAT + 1):
					var x := cx + dx
					var y := cy + dy
					if x >= 0 and x < cols and y >= 0 and y < rows:
						grid[y * cols + x] += exp(-0.5 * (dx * dx + dy * dy) / 2.0)
			heat[role][ph] = grid
	if _heat_dir != "":
		_save_heat(heat, cols, rows, "%s/positions_level%d.png" % [_heat_dir, int(level)])
	return {"level": level, "dist": dist, "set_up": set_up}


func _mean(acc: Array) -> float:
	return acc[0] / maxf(acc[1], 1.0)


func _report(results: Array) -> void:
	print("  average distance from the position's spot (m), level 0 -> level 3")
	var head := "  %-4s" % ""
	for ph in TeamSystem.PHASE_NAMES:
		head += " %15s" % ph
	print(head + "      all")
	var all := [[0.0, 0], [0.0, 0]]
	var by_phase := {}  # phase -> [[sum, n] level 0, [sum, n] level 3]
	for role in TeamSystem.ROLES:
		var line := "  %-4s" % role
		for ph in TeamSystem.PHASE_NAMES.size():
			var a: Array = results[0].dist[role].get(ph, [0.0, 0])
			var b: Array = results[1].dist[role].get(ph, [0.0, 0])
			var bp: Array = by_phase.get(ph, [[0.0, 0], [0.0, 0]])
			for k in 2:
				var acc: Array = [a, b][k]
				all[k][0] += acc[0]
				all[k][1] += acc[1]
				bp[k][0] += acc[0]
				bp[k][1] += acc[1]
			by_phase[ph] = bp
			if a[1] < 4 or b[1] < 4:
				line += " %15s" % "-"
				continue
			line += " %6.1f -> %5.1f" % [_mean(a), _mean(b)]
		print(line)
	var line := "  %-4s" % "all"
	for ph in TeamSystem.PHASE_NAMES.size():
		var bp: Array = by_phase.get(ph, [[0.0, 0], [0.0, 0]])
		line += " %6.1f -> %5.1f" % [_mean(bp[0]), _mean(bp[1])]
	print(line + "   %.1f -> %.1f" % [_mean(all[0]), _mean(all[1])])
	print("  once a phase has settled (%.1f s in): %.1f -> %.1f m" % [SETTLED, _mean(results[0].set_up), _mean(results[1].set_up)])
	# the clear margin is in the set-up once a phase has settled; overall
	# (counting the skate to the new spots) it's smaller and noisier
	_check(_mean(results[1].set_up) < _mean(results[0].set_up) * 0.85, "a structured side holds its positions once set up (%.1f vs %.1f m)" % [_mean(results[1].set_up), _mean(results[0].set_up)])
	_check(_mean(all[1]) < _mean(all[0]), "a structured side keeps its positions overall (%.1f vs %.1f m)" % [_mean(all[1]), _mean(all[0])])
	# in the zones, where the system is clearest (in the neutral zone the
	# spots sit near the puck anyway, so chasing it doesn't show)
	var zones := [TeamSystem.Phase.OFFENCE, TeamSystem.Phase.BREAKOUT, TeamSystem.Phase.FORECHECK, TeamSystem.Phase.DZONE]
	var tighter := []
	for ph in zones:
		var bp: Array = by_phase.get(ph, [[0.0, 0], [0.0, 0]])
		if _mean(bp[1]) < _mean(bp[0]):
			tighter.append(TeamSystem.PHASE_NAMES[ph])
	_check(tighter.size() >= zones.size() - 1, "tighter in the zones (only %s)" % [tighter])


## One sheet: a rink per phase, each position's density in its colour.
func _save_heat(heat: Dictionary, cols: int, rows: int, path: String) -> void:
	var w := cols * SCALE
	var h := rows * SCALE
	var gap := 8
	var img := Image.create((w + gap) * 3, (h + gap) * 2, false, Image.FORMAT_RGB8)
	img.fill(Color(0.12, 0.12, 0.14))
	for pi in SHEET.size():
		var ph: int = SHEET[pi]
		var ox := (pi % 3) * (w + gap)
		var oy := (pi / 3) * (h + gap)
		var tops := {}
		for role in TeamSystem.ROLES:
			var top := 0.0
			for v in heat[role][ph]:
				top = maxf(top, v)
			tops[role] = top
		for cy in rows:
			for cx in cols:
				var col := _ice(Vector2(cx * CELL - Rink.HALF_L, cy * CELL - Rink.HALF_W))
				for role in TeamSystem.ROLES:
					if tops[role] <= 0.0:
						continue
					var a := sqrt(heat[role][ph][cy * cols + cx] / tops[role])
					if a > 0.08:
						col = col.lerp(ROLE_COLOURS[role], clampf(a, 0.0, 1.0) * 0.85)
				img.fill_rect(Rect2i(ox + cx * SCALE, oy + cy * SCALE, SCALE, SCALE), col)
		var pk: Vector2 = SHOW_PUCK[ph]
		_dot(img, ox, oy, pk, 0.0, 0.5, Color.BLACK)
		for role in TeamSystem.ROLES:
			var f := TeamSystem.spot(role, ph, pk, "", 1.0)
			_dot(img, ox, oy, f, 0.9, 1.3, Color.BLACK)
			_dot(img, ox, oy, f, 0.0, 0.9, ROLE_COLOURS[role])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("  heatmaps: ", path)


## A filled ring (inner radius `r0`, outer `r1`, metres) at rink point `f`.
func _dot(img: Image, ox: int, oy: int, f: Vector2, r0: float, r1: float, col: Color) -> void:
	var px_per_m := SCALE / CELL
	var c := Vector2(ox + (f.x + Rink.HALF_L) * px_per_m, oy + (f.y + Rink.HALF_W) * px_per_m)
	var r := int(ceil(r1 * px_per_m))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var d := Vector2(dx, dy).length() / px_per_m
			var x := int(c.x) + dx
			var y := int(c.y) + dy
			if d >= r0 and d <= r1 and x >= ox and y >= oy and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, col)


func _ice(p: Vector2) -> Color:
	if Rink.sdf(p) > 0.0:
		return Color(0.12, 0.12, 0.14)
	var ax := absf(p.x)
	if absf(ax - Rink.BLUE_X) < 0.3:
		return Color(0.35, 0.45, 0.85)
	if absf(ax - Rink.GOAL_X) < 0.15 or ax < 0.2:
		return Color(0.85, 0.35, 0.35)
	return Color(0.9, 0.92, 0.95)

