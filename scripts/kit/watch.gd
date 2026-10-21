class_name Watch
extends RefCounted
## The owner's wristwatch (playtest #13): Q raises it to read the time, and
## it keeps countdown timers and a daily alarm on the rink's own clock, so a
## timer set in the walk runs on in the office and through fast-forwarded
## work. Better watches come from the pro shop later: more timers, an alarm,
## a backlight for the dark plant room.
##
## Times are absolute sim minutes (day * 1440 + minute of the day).

const DAY_MIN := 24 * 60

## Each model: name, shop price, how many timers it holds, whether it has a
## daily alarm, a stopwatch and a backlight (readable with the lights off).
const MODELS := {
	"gas_station": {"name": "Gas-station digital", "price": 12.0, "timers": 1, "alarm": false, "stopwatch": true, "backlight": false},
	"sport": {"name": "Sport digital", "price": 45.0, "timers": 2, "alarm": true, "stopwatch": true, "backlight": true},
	"dive": {"name": "Steel dive watch", "price": 180.0, "timers": 3, "alarm": true, "stopwatch": true, "backlight": true},
}
const STARTER := "gas_station"

var model := STARTER
## [{"label", "end"}] counting down to absolute minute `end`.
var timers: Array = []
## Minute of the day the alarm rings, or -1 for off.
var alarm := -1
var _alarm_rang_day := -1
## Absolute minute the stopwatch started, or -1.
var stopwatch_start := -1


func spec() -> Dictionary:
	return MODELS.get(model, MODELS[STARTER])


static func abs_minute(sim: RinkSim) -> int:
	return sim.day * DAY_MIN + sim.minute


## Starts a countdown of `minutes`. False when every timer slot is running.
func set_timer(minutes: int, label: String, now: int) -> bool:
	if timers.size() >= int(spec().timers) or minutes <= 0:
		return false
	timers.append({"label": label, "end": now + minutes})
	return true


func clear_timer(i: int) -> void:
	if i >= 0 and i < timers.size():
		timers.remove_at(i)


## Sets the daily alarm (minute of the day, -1 off). False on a watch without one.
func set_alarm(minute_of_day: int) -> bool:
	if not bool(spec().alarm) and minute_of_day >= 0:
		return false
	alarm = posmod(minute_of_day, DAY_MIN) if minute_of_day >= 0 else -1
	return true


func toggle_stopwatch(now: int) -> void:
	stopwatch_start = now if stopwatch_start < 0 else -1


## Advances to absolute minute `now`; returns what went off as
## [{"kind": "timer"|"alarm", "label"}].
func tick(now: int) -> Array:
	var out: Array = []
	for t in timers.duplicate():
		if now >= int(t.end):
			out.append({"kind": "timer", "label": t.label})
			timers.erase(t)
	if alarm >= 0:
		var d := floori(float(now) / DAY_MIN)
		if posmod(now, DAY_MIN) >= alarm and _alarm_rang_day != d:
			_alarm_rang_day = d
			out.append({"kind": "alarm", "label": "Alarm"})
	return out


## What the face shows at `now`: {"time", "day", "timers": [{"label", "left"}],
## "alarm", "stopwatch", "lit"}. `dark` is true where the player stands in
## the dark: only a backlit watch reads then.
func read(now: int, weekday: int, dark := false) -> Dictionary:
	var m := posmod(now, DAY_MIN)
	var out := {
		"time": "%02d:%02d" % [m / 60, m % 60],
		"day": RinkSim.DAY_NAMES[posmod(weekday, 7)].to_upper(),
		"timers": [],
		"alarm": "%02d:%02d" % [alarm / 60, alarm % 60] if alarm >= 0 else "",
		"stopwatch": "",
		"lit": not dark or bool(spec().backlight),
	}
	for t in timers:
		out.timers.append({"label": t.label, "left": maxi(0, int(t.end) - now)})
	if stopwatch_start >= 0:
		var s := now - stopwatch_start
		out.stopwatch = "%d:%02d" % [s / 60, s % 60]
	return out


## Swaps to a better model, keeping the running timers that still fit.
func upgrade(model_id: String) -> bool:
	if not MODELS.has(model_id) or model_id == model:
		return false
	model = model_id
	while timers.size() > int(spec().timers):
		timers.pop_back()
	if not bool(spec().alarm):
		alarm = -1
	return true


static func minutes_text(left: int) -> String:
	return "%d:%02d" % [left / 60, left % 60] if left >= 60 else "%d min" % left


func to_dict() -> Dictionary:
	return {"model": model, "timers": timers.duplicate(true), "alarm": alarm,
		"alarm_rang_day": _alarm_rang_day, "stopwatch_start": stopwatch_start}


static func from_dict(d: Dictionary) -> Watch:
	var w := Watch.new()
	w.model = str(d.get("model", STARTER))
	w.timers = (d.get("timers", []) as Array).duplicate(true)
	w.alarm = int(d.get("alarm", -1))
	w._alarm_rang_day = int(d.get("alarm_rang_day", -1))
	w.stopwatch_start = int(d.get("stopwatch_start", -1))
	return w
