class_name BoxScore
extends RefCounted
## Counts a live game the same way QuickSim does (goals, assists, shots on
## goal, hits, plus/minus, ice time, goalie lines), so a game played in the
## engine feeds the career exactly like a simulated one.

var lines := {}  # player id -> stat line
var shots_on := [0, 0]
var injuries: Array = []  # [{"pid", "injury"}]


func line(p: PlayerProfile) -> Dictionary:
	if not lines.has(p.id):
		lines[p.id] = QuickSim.blank_line()
	return lines[p.id]


func add_toi(players: Array, dt: float) -> void:
	for p in players:
		if p:
			line(p).toi += dt


func shot_on_goal(shooter: PlayerProfile, team: int) -> void:
	shots_on[team] += 1
	if shooter:
		line(shooter).shots += 1


func goal(scorer: PlayerProfile, assists: Array, plus: Array, minus: Array) -> void:
	if scorer:
		line(scorer).g += 1
	for a in assists:
		line(a).a += 1
	for p in plus:
		if p:
			line(p).pm += 1
	for p in minus:
		if p:
			line(p).pm -= 1


func hit(p: PlayerProfile) -> void:
	if p:
		line(p).hits += 1


## Final result in QuickSim's format. `goals` = [home, away] including any
## shootout winner; `goalies` = [home goalie, away goalie] profiles.
func to_result(home_id: int, away_id: int, goals: Array, ot: bool, so: bool, playoff: bool, goalies: Array, glen: float) -> Dictionary:
	var res := QuickSim.new_result(home_id, away_id, playoff)
	res.hg = goals[0]
	res.ag = goals[1]
	res.ot = ot
	res.so = so
	res.live = true
	for side in 2:
		var g: PlayerProfile = goalies[side]
		if g == null:
			continue
		var l := line(g)
		l.toi = glen
		l.sa = shots_on[1 - side]
		l.ga = goals[1 - side] - (1 if so and goals[1 - side] > goals[side] else 0)
		var won: bool = goals[side] > goals[1 - side]
		if won:
			l.w = 1
		elif ot or so:
			l.otl = 1
		else:
			l.l = 1
		if l.ga == 0:
			l.so = 1
	res.box = lines
	res.injuries = injuries
	return res
