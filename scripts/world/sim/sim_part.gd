class_name SimPart
extends RefCounted
## One replaceable physical part of the rink (a compressor's valve plates, the
## resurfacer blade, a pump bearing). Its true condition is hidden from the
## player, who only ever sees it through an instrument (SimInstrument).
##
## condition 1 is new, 0 is failed. Parts wear per operating hour, faster under
## stress (dirty oil, high head pressure, a dull blade on hard ice).

var id := ""
var name := ""
var condition := 1.0
var hours := 0.0         # operating hours since it was fitted
var life_hours := 5000.0  # hours to wear from new to failed under normal stress
var price := 0.0          # replacement part cost in dollars
var fail_below := 0.0     # condition where it stops working


static func make(id_: String, name_: String, life: float, price_: float, fail := 0.0, cond := 1.0) -> SimPart:
	var p := SimPart.new()
	p.id = id_
	p.name = name_
	p.life_hours = life
	p.price = price_
	p.fail_below = fail
	p.condition = cond
	return p


## Runs the part for `h` hours at `stress` (1 = normal wear).
func run(h: float, stress := 1.0) -> void:
	hours += h
	condition = maxf(condition - h * stress / life_hours, 0.0)


func failed() -> bool:
	return condition <= fail_below


## Fits a new part (`quality` < 1 for a poor install or a used part).
func replace(quality := 1.0) -> void:
	condition = clampf(quality, 0.0, 1.0)
	hours = 0.0


func to_dict() -> Dictionary:
	return {"condition": condition, "hours": hours}


func load_dict(d: Dictionary) -> void:
	condition = float(d.get("condition", condition))
	hours = float(d.get("hours", hours))
