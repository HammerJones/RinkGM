class_name GameSettings
extends RefCounted
## How a game is played: always three periods, with an adjustable period
## length, overtime rules and line-change pacing. Saved with the career so the
## player's choice sticks.

const PERIOD_CHOICES := [2.0, 3.0, 5.0, 8.0, 12.0, 20.0]  # minutes

var periods := 3
var period_minutes := 5.0
## Regular season: one sudden-death OT period of this length, then a shootout.
var ot_minutes := 3.0
## Playoffs: full-length sudden-death OT periods until someone scores.
var playoff_ot_full_periods := true
var skaters_on_ice := 5  # 3 forwards + 2 defence
## Intermission length in real seconds (skippable later by the UI).
var intermission_seconds := 4.0


func period_length() -> float:
	return period_minutes * 60.0


func game_length() -> float:
	return period_length() * periods


## Target shift length in game seconds: about 45 s of a 20-minute period,
## scaled down for short periods but never so short the line can't do anything.
func shift_length(group: String) -> float:
	var s := clampf(period_length() * 0.0375, 22.0, 45.0)
	return s * (1.35 if group == "D" else 1.0)


func ot_length(playoffs: bool) -> float:
	return period_length() if playoffs and playoff_ot_full_periods else ot_minutes * 60.0


func to_dict() -> Dictionary:
	return {"periods": periods, "period_minutes": period_minutes, "ot_minutes": ot_minutes,
		"playoff_ot_full_periods": playoff_ot_full_periods, "skaters_on_ice": skaters_on_ice}


static func from_dict(d: Dictionary) -> GameSettings:
	var g := GameSettings.new()
	g.periods = int(d.get("periods", 3))
	g.period_minutes = float(d.get("period_minutes", 5.0))
	g.ot_minutes = float(d.get("ot_minutes", 3.0))
	g.playoff_ot_full_periods = d.get("playoff_ot_full_periods", true)
	g.skaters_on_ice = int(d.get("skaters_on_ice", 5))
	return g
