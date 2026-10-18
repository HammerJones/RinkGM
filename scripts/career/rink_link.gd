class_name RinkLink
extends RefCounted
## Runs a career alongside the owner's rink (RINK_SIM.md 6.1): the RinkSim's
## clock owns the calendar and the Career follows it a day at a time.
##
## - Calendar: Career.follows_world is on; at each of the sim's midnights the
##   career passes a day, so `career.day == sim.day`.
## - Rest: a day counts as rest for the user only when the owner ended it
##   below UNRESTED_FATIGUE (RINK_SIM.md 2.1, 70 to 90: "the player's hockey
##   Progression.rest treats the days as unrested").
## - The user's game: Beer League D plays on the rink's own late ice, the
##   Tuesday 22:00 slot of the `vbl_d` contract. The clock stops there so the
##   hub can stage the match; play_round() records it and charges the owner.
## - League dues: Career.league_gate is RinkSim.owner_can_play.
## - Money: one balance, the sim's. The owner's dues and costs come out of it.
## - Save: the sim goes under the career save's `world.rink_sim` key.

const GAME_WEEKDAY := 2           # Tuesday
const GAME_MINUTE := 22 * 60      # the vbl_d late slot
const GAME_HOURS := 3.0           # warm-up, the game, the beer (RINK_SIM.md 2.1)
const UNRESTED_FATIGUE := 70.0

var career: Career
var sim: RinkSim


## Ties a fresh career to a fresh rink: the career's calendar jumps to the
## sim's and its first game lands on the first Tuesday.
static func start(c: Career, s: RinkSim) -> RinkLink:
	var link := RinkLink.new()
	link.career = c
	link.sim = s
	c.follows_world = true
	c.day = s.day
	c.game_day = link._next_game_day(s.day)
	link._wire()
	return link


## A new owner career: the user plays Beer League D and owns Millbrook.
static func new_owner(first: String, last: String, position: String, seed_: int = 0) -> RinkLink:
	var c := Career.new_career(first, last, position, seed_)
	c.save_path = Career.SLOTS.owner.path
	return start(c, RinkSim.create(seed_ if seed_ != 0 else randi()))


## The link for a loaded career that follows the world, or null.
static func resume(c: Career) -> RinkLink:
	if not c.follows_world or not c.world.has("rink_sim"):
		return null
	var link := RinkLink.new()
	link.career = c
	var saved: Variant = c.world.rink_sim
	link.sim = saved if saved is RinkSim else RinkSim.from_dict(saved)
	link._wire()
	return link


func _wire() -> void:
	career.league_gate = sim.owner_can_play
	career.world["rink_sim"] = sim  # saved live with the career


## Runs the rink up to `minutes` ahead, stopping early when the user's game is
## due. Returns true if it stopped for the game.
func advance(minutes: int) -> bool:
	var left := minutes
	while left > 0:
		if game_due():
			return true
		var step := mini(left, RinkSim.STEP_MIN)
		sim.advance(step)
		left -= step
		_follow()
	return game_due()


## Runs the rink until the user's next game (or the season break). Returns
## true if it stopped for a game, false if `max_days` ran out first.
func advance_to_game(max_days := 14) -> bool:
	return advance(max_days * 24 * 60)


## True when the current round is due and the rink's clock has reached the
## game's slot (a late game is also due on any later day).
func game_due() -> bool:
	if career.phase != Career.Phase.SEASON or not career.round_due():
		return false
	return sim.day > career.game_day or sim.minute >= GAME_MINUTE


## Records the round (the user's game played live when `user_result` is
## given), charges the owner the evening, and puts the next game on the
## Tuesday on or after the career's next game day.
func play_round(user_result: Dictionary = {}) -> Dictionary:
	var played_user: bool = not career.next_user_game().is_empty() and career.user().dressed()
	var summary := career.play_round(user_result)
	if played_user:
		sim.hours_left -= GAME_HOURS
	career.game_day = _next_game_day(maxi(career.game_day, sim.day + 1))
	return summary


## The first Tuesday on or after day `from`, by the sim's weekdays.
func _next_game_day(from: int) -> int:
	var wd := posmod(sim.weekday() + from - sim.day, 7)
	return from + posmod(GAME_WEEKDAY - wd, 7)


## Catches the career up with the sim's calendar, a day at a time.
func _follow() -> void:
	while career.day < sim.day:
		career.pass_day(fatigue() < UNRESTED_FATIGUE)


## The owner's fatigue, 0..100 (0 until the sim tracks it).
func fatigue() -> float:
	return float(sim.get("fatigue")) if "fatigue" in sim else 0.0

