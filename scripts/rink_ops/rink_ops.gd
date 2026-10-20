class_name RinkOps
extends RefCounted
## The between-sessions chores that decide whether an event starts right
## (playtest #18 and #19, canvas "On-ice activities"):
##
## - The scoreboard: games want it in game mode (score, shots, penalties),
##   everything else wants a plain clock counting down the slot. A wrong
##   board annoys the customers. With game mode on a practice nobody sees the
##   slot run out, so they overstay and the next booking starts late.
## - The nets: each booking wants its own count on the ice, large and mini
##   (EventCatalog `nets`; minor hockey cross-ice wants the pads too). They
##   live in the storage along the wall by the Zamboni gates: 4 large, 8 mini.
##   Nice coaches skate them over from the gate themselves. For the others
##   someone walks them out in shoes (IceBalance).
## - The scorekeeper: every game needs one in the box. Early on a high
##   schooler volunteers. After the first week they want paying, or the owner
##   keeps score (Scorekeeping).
##
## With `auto` on (fast-forward, the office), the owner does the setup
## between sessions for 10 minutes of hours each, as Doris's floods
## run with auto_resurface. In the walk the player does it by hand, and
## whatever isn't done when the session starts costs satisfaction.
## RinkSim calls on_session_start(); this holds no reference to the sim.

const NETS_LARGE := 4
const NETS_MINI := 8
const SETUP_MIN := 10
const SCOREKEEPER_PAY := 15.0      # $ a game once the volunteer wants paying
const VOLUNTEER_DAYS := 7
const WRONG_BOARD := 4.0           # satisfaction lost to the wrong scoreboard mode
const OVERSTAY := 3.0              # and by the next booking when a practice overstays
const NETS_SHORT := 6.0            # hockey waiting for nets
const NO_SCOREKEEPER := 8.0
const SCOREKEEPER_NAME := "Tyler Boucher"

var auto := true
## "clock", "game" or "off" (the board is dark until someone turns it on).
var board := "off"
## The nets out on the ice now; the rest are in storage.
var nets_on := [0, 0]
## "volunteer", "paid", "owner" (keeps score) or "none".
var scorekeeper := "volunteer"
var volunteer_until := VOLUNTEER_DAYS
var asked_for_pay := false
## The next booking starts this many minutes late after an overstay.
var late_minutes := 0


## What a booking needs: {"board", "nets": [large, mini], "pads", "scorekeeper"}.
static func needs(s: Dictionary) -> Dictionary:
	var k := EventCatalog.kind(str(s.get("kind", EventCatalog.for_org(str(s.get("org", ""))))))
	return {"board": str(k.get("board", "clock")), "nets": (k.get("nets", [0, 0]) as Array).duplicate(),
		"pads": bool(k.get("pads", false)), "scorekeeper": bool(k.get("scorekeeper", false))}


## Whether the organiser skates the nets over from the gate themselves.
## Steady per organisation: some coaches are just nicer.
static func coach_helps(org: String) -> bool:
	return posmod(hash(org), 100) < 45


func nets_ready(s: Dictionary) -> bool:
	var n: Array = needs(s).nets
	return int(nets_on[0]) == int(n[0]) and int(nets_on[1]) == int(n[1])


## Puts nets on or takes them off (a person carried them). Clamped to what
## the rink owns.
func set_nets(large: int, mini: int) -> void:
	nets_on = [clampi(large, 0, NETS_LARGE), clampi(mini, 0, NETS_MINI)]


## Called by RinkSim as booking `s` starts on day `day`. Returns
## {"satisfaction": loss, "hours": owner hours spent, "cost": $, "notes": [text]}.
func on_session_start(s: Dictionary, day: int) -> Dictionary:
	var out := {"satisfaction": 0.0, "hours": 0.0, "cost": 0.0, "notes": []}
	var need := needs(s)
	var name := str(s.get("name", RinkContracts.org(str(s.get("org", ""))).get("name", "The booking")))
	if late_minutes > 0:
		out.satisfaction += OVERSTAY
		out.notes.append("%s started %d minutes late: the last group overstayed." % [name, late_minutes])
		late_minutes = 0
	if auto:
		var chores := 0
		if board != need.board:
			board = need.board
			chores += 1
		if not nets_ready(s) and not coach_helps(str(s.get("org", ""))):
			chores += 1
		nets_on = need.nets.duplicate()
		out.hours = chores * SETUP_MIN / 60.0
	else:
		if board != need.board:
			out.satisfaction += WRONG_BOARD
			if need.board == "game":
				out.notes.append("%s played without the score on the board." % name)
			else:
				out.notes.append("%s couldn't see their time on the board and overstayed." % name)
				late_minutes = 10
		if not nets_ready(s):
			if coach_helps(str(s.get("org", ""))):
				nets_on = need.nets.duplicate()
				out.notes.append("%s's coach skated the nets over from the gate." % name)
			else:
				out.satisfaction += NETS_SHORT
				out.notes.append("%s stood around waiting for nets (%d large, %d mini wanted)." % [name, need.nets[0], need.nets[1]])
				nets_on = need.nets.duplicate()  # they went and got them in the end
	if need.scorekeeper:
		_scorekeeper_for_game(day, name, out, float(s.get("hours", 0.0)))
	return out


func _scorekeeper_for_game(day: int, name: String, out: Dictionary, s_hours: float) -> void:
	if scorekeeper == "volunteer" and day >= volunteer_until:
		asked_for_pay = true
		if auto:  # fast-forwarding, the owner says yes rather than lose the kid mid-week
			scorekeeper = "paid"
			out.notes.append("%s wants $%.0f a game to keep keeping score. You said yes; keep score yourself from the office to save it." % [SCOREKEEPER_NAME, SCOREKEEPER_PAY])
		else:
			scorekeeper = "none"
			out.notes.append("%s won't keep score for free any more: $%.0f a game to stay on." % [SCOREKEEPER_NAME, SCOREKEEPER_PAY])
	match scorekeeper:
		"paid":
			out.cost += SCOREKEEPER_PAY
		"owner":
			if auto:  # fast-forwarding, the owner sits in the box for the game
				out.hours += float(s_hours)
		"none":
			out.satisfaction += NO_SCOREKEEPER
			out.notes.append("Nobody kept score for %s." % name)


## Hires the scorekeeper back at SCOREKEEPER_PAY a game.
func pay_scorekeeper() -> void:
	scorekeeper = "paid"


## The owner keeps score from now on (the Scorekeeping mini game).
func keep_score_yourself() -> void:
	scorekeeper = "owner"


## The owner kept the sheet for the game on the ice now (Scorekeeping,
## `quality` 0..1): a clean sheet pleases the league, a messy one costs like
## having nobody in the box. Returns what happened, or "" with no game on.
func sheet_kept(sim: RinkSim, quality: float) -> String:
	var now := sim.minute / 60.0
	for s in sim.sessions(sim.day):
		if not needs(s).scorekeeper or now < float(s.start) or now >= float(s.start) + float(s.hours):
			continue
		var c: Dictionary = sim.contracts.get(s.org, {})
		var delta := 2.0 if quality >= 0.8 else -NO_SCOREKEEPER * (1.0 - quality)
		if not c.is_empty():
			c.satisfaction = clampf(float(c.satisfaction) + delta, 0.0, 100.0)
		var name := RinkSchedule._name(s)
		return "%s: a clean sheet, the league's happy." % name if quality >= 0.8 else "%s: the league has questions about your sheet." % name
	return ""


func to_dict() -> Dictionary:
	return {"auto": auto, "board": board, "nets_on": nets_on.duplicate(), "scorekeeper": scorekeeper,
		"volunteer_until": volunteer_until, "asked_for_pay": asked_for_pay, "late_minutes": late_minutes}


static func from_dict(d: Dictionary) -> RinkOps:
	var o := RinkOps.new()
	o.auto = bool(d.get("auto", true))
	o.board = str(d.get("board", "off"))
	var n: Array = d.get("nets_on", [0, 0])
	o.nets_on = [int(n[0]), int(n[1])]
	o.scorekeeper = str(d.get("scorekeeper", "volunteer"))
	o.volunteer_until = int(d.get("volunteer_until", VOLUNTEER_DAYS))
	o.asked_for_pay = bool(d.get("asked_for_pay", false))
	o.late_minutes = int(d.get("late_minutes", 0))
	return o
