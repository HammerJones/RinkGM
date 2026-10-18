class_name Shootout
extends RefCounted
## The shootout, played on the ice: one shooter at a time takes the puck from
## centre ice against the other team's goalie, everyone else on the bench.
## Team 0 (the user's side) shoots first, then they alternate.
## Three rounds, stopping early once one side can't catch up, then sudden
## death a round at a time. An attempt ends with a goal, a save, a miss past
## the goal line, the puck carried back past centre, dying loose or jammed
## at the goal line, or the shooter running out of time. Game hosts it
## (Game._shootout) and reports goals and saves to it.

const ROUNDS := 3
const MAX_ROUNDS := 20       # then the side with more goals, or a coin toss
const READY_TIME := 1.2      # puck frozen at centre while the shooter gets set
const ATTEMPT_TIME := 12.0
const RESULT_TIME := 1.8
const DEAD_PUCK := 1.0       # seconds loose and still before the attempt is over
const BACK_X := -4.0         # the puck carried this far back past centre ends it
const CRASH_TIME := 1.5      # seconds jammed at the goal line before it's over

enum Phase { READY, LIVE, RESULT, DONE }

var game: Node
var made := [0, 0]
var taken := [0, 0]
var order := [[], []]  # per team: shooters, best first
var team := 0          # shooting now
var shooter: Skater
var phase := Phase.READY
var _timer := 0.0
var _touched := false
var _dead := 0.0


func _init(g: Node) -> void:
	game = g
	for t in 2:
		order[t] = shooters(g.benches[t])


## A bench's shootout order: healthy skaters, the best hands first.
static func shooters(b: Bench) -> Array:
	var out: Array = []
	for l in b.f_lines + b.d_pairs:
		for p in l:
			if p and not b.hurt.has(p.id) and not out.has(p):
				out.append(p)
	out.sort_custom(func(a, c): return _hands(a) > _hands(c))
	return out


static func _hands(p: PlayerProfile) -> float:
	return p.skills.n("shot_accuracy") + p.skills.n("stick_handling") + 0.5 * p.skills.n("shot_power")


func start() -> void:
	_next()


func update(dt: float) -> void:
	_timer -= dt
	match phase:
		Phase.READY:
			if _timer <= 0.0:
				game.puck.frozen = false
				phase = Phase.LIVE
				_timer = ATTEMPT_TIME
		Phase.LIVE:
			_watch(dt)
		Phase.RESULT:
			if _timer <= 0.0:
				_next()


func on_goal(side: int) -> void:
	if phase == Phase.LIVE and side == game.attack_side(team):
		_result(true)


func on_save() -> void:
	if phase == Phase.LIVE:
		_result(false)


func on_puck_out() -> void:
	if phase == Phase.LIVE:
		_result(false)


func winner() -> int:
	if made[0] != made[1]:
		return 0 if made[0] > made[1] else 1
	return 0 if randf() < 0.5 else 1


func is_done() -> bool:
	return phase == Phase.DONE


func _watch(dt: float) -> void:
	var puck: Puck = game.puck
	var att: int = game.attack_side(team)
	if puck.controller == shooter:
		_touched = true
	var x: float = puck.position.x * att
	if _timer <= 0.0 or (x > Rink.GOAL_X + 0.3 and puck.in_net_side == 0):
		_result(false)  # out of time, or wide past the goal line
		return
	if _touched and x < BACK_X:
		_result(false)  # took it back past centre
		return
	# loose and dead, or jammed into the goalie at the goal line
	var jammed: bool = (Rink.GOAL_X - shooter.position.x * att) < 1.0
	if _touched and (jammed or (puck.controller == null and puck.horizontal_speed() < 0.4)):
		_dead += dt
		if _dead > (CRASH_TIME if jammed else DEAD_PUCK):
			_result(false)
	else:
		_dead = 0.0


func _result(scored: bool) -> void:
	taken[team] += 1
	if scored:
		made[team] += 1
	phase = Phase.RESULT
	_timer = RESULT_TIME
	game.puck.controller = null
	game.puck.frozen = true
	var name: String = shooter.player.short_name() if shooter.player else "Shooter"
	game.hud.show_message("%s\nSHOOTOUT %d - %d" % ["GOAL! " + name if scored else "NO GOAL", made[0], made[1]], RESULT_TIME)


func _next() -> void:
	if _decided():
		phase = Phase.DONE
		game.shootout_over(winner())
		return
	team = 0 if taken[0] == taken[1] else 1
	var list: Array = order[team]
	shooter = game.benches[team].body(list[taken[team] % list.size()])
	game.shootout_shooter(shooter)
	_touched = false
	_dead = 0.0
	phase = Phase.READY
	_timer = READY_TIME


## True once the shootout has a winner: one side can't catch up in the first
## three rounds, or a sudden-death round ends uneven (or the cap is hit).
func _decided() -> bool:
	if taken[0] < ROUNDS or taken[1] < ROUNDS:
		var left := [maxi(ROUNDS - taken[0], 0), maxi(ROUNDS - taken[1], 0)]
		return made[0] > made[1] + left[1] or made[1] > made[0] + left[0]
	if taken[0] != taken[1]:
		return false
	return made[0] != made[1] or taken[0] >= MAX_ROUNDS
