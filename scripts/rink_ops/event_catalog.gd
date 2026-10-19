class_name EventCatalog
extends RefCounted
## Every kind of event the rink can put on its ice (playtest #42, canvas
## "On-ice activities"), with the criteria a slot has to meet and what the
## event needs from the staff. A booking with `kind` uses this row:
##
## - `hours`: the usual slot length. `rate` is $/h for rented ice; `per_head`
##   and `heads` for walk-in events, whose crowd also depends on the hour
##   and the season (expected_heads).
## - `windows`: when it can run, as [days, from_h, to_h], where days is
##   "weekday", "weekend" or "any" and hours may run past 24 (25.5 is 01:30).
## - `min_ice` / `min_rooms`: the ice reputation and facility score the
##   organisers want before they'll come.
## - Needs: `nets` [large, mini], `pads` (the black dividers for cross-ice
##   minor hockey), `board` ("game" or "clock", the scoreboard mode),
##   `scorekeeper`, `flood_before`, `ice` ("hard", "soft" for figure skating,
##   "snowed" for broomball), `rules` (LeagueRules.for_event).
## - `sell`: the owner can sell it one-off from the schedule; the rest come
##   only through contracts and bids.
##
## Weekday 08:00 to 16:00 is the hard part of a rink's week: hockey players
## are at work and kids are at school. It's the non-prime rate (PRIME_*),
## filled with noon shinny, parent-and-tot, school skating trips,
## stick-and-puck and, once the ice is good enough, pro practice.

const OPEN_H := 5.0      # the building opens for the 05:00 figure skaters
const CLOSE_H := 25.5    # and closes after the 01:30 broomball
const NON_PRIME := 0.65  # weekday daytime sells at this share of the rate

const KINDS := {
	"beer_league_game": {"name": "Beer league game", "use": "hockey", "hours": 1.25, "rate": 160.0,
		"windows": [["any", 20.5, 25.5]], "min_ice": 0.0, "min_rooms": 0.0,
		"nets": [2, 0], "board": "game", "scorekeeper": true, "flood_before": true, "ice": "hard", "rules": "beer_league_game", "sell": false},
	"senior_game": {"name": "Senior AAA game", "use": "hockey", "hours": 2.0, "rate": 210.0,
		"windows": [["any", 18.0, 23.0]], "min_ice": 72.0, "min_rooms": 55.0,
		"nets": [2, 0], "board": "game", "scorekeeper": true, "flood_before": true, "ice": "hard", "rules": "senior_game", "sell": false},
	"minor_practice": {"name": "Minor hockey practice (cross-ice)", "use": "hockey", "hours": 1.0, "rate": 175.0,
		"windows": [["weekday", 16.5, 20.5], ["weekend", 7.0, 18.0]], "min_ice": 50.0, "min_rooms": 25.0,
		"nets": [2, 6], "pads": true, "board": "clock", "flood_before": true, "ice": "hard", "sell": false},
	"minor_game": {"name": "Minor hockey game", "use": "hockey", "hours": 1.25, "rate": 175.0,
		"windows": [["weekend", 7.0, 19.0]], "min_ice": 50.0, "min_rooms": 25.0,
		"nets": [2, 0], "board": "game", "scorekeeper": true, "flood_before": true, "ice": "hard", "rules": "minor_game", "sell": false},
	"high_school_practice": {"name": "High school practice", "use": "hockey", "hours": 1.5, "rate": 165.0,
		"windows": [["weekday", 14.5, 18.0]], "min_ice": 55.0, "min_rooms": 35.0,
		"nets": [2, 0], "board": "clock", "flood_before": true, "ice": "hard", "sell": false},
	"figure_private": {"name": "Figure skating (private, early)", "use": "figure", "hours": 2.0, "rate": 170.0,
		"windows": [["any", 5.0, 8.0]], "min_ice": 55.0, "min_rooms": 30.0,
		"nets": [0, 0], "board": "clock", "flood_before": true, "ice": "soft", "sell": false},
	"figure_class": {"name": "Figure skating classes", "use": "figure", "hours": 1.0, "rate": 150.0,
		"windows": [["weekday", 16.0, 19.0], ["weekend", 9.0, 14.0]], "min_ice": 50.0, "min_rooms": 30.0,
		"nets": [0, 0], "board": "clock", "flood_before": true, "ice": "soft", "sell": false},
	"public_skate": {"name": "Public skate", "use": "public", "hours": 2.0, "rate": 0.0, "per_head": 6.0, "heads": 40,
		"windows": [["any", 9.0, 21.5]], "min_ice": 0.0, "min_rooms": 0.0,
		"nets": [0, 0], "board": "clock", "flood_before": true, "ice": "hard", "sell": true},
	"stick_and_puck": {"name": "Stick and puck", "use": "hockey", "hours": 1.0, "rate": 0.0, "per_head": 12.0, "heads": 14,
		"windows": [["any", 6.0, 22.0]], "min_ice": 20.0, "min_rooms": 0.0,
		"nets": [2, 0], "board": "clock", "flood_before": true, "ice": "hard", "sell": true},
	"noon_shinny": {"name": "Noon shinny (adults)", "use": "hockey", "hours": 1.25, "rate": 0.0, "per_head": 15.0, "heads": 16,
		"windows": [["weekday", 11.0, 14.0]], "min_ice": 25.0, "min_rooms": 0.0,
		"nets": [2, 0], "board": "clock", "flood_before": true, "ice": "hard", "sell": true},
	"parent_tot": {"name": "Parent and tot skate", "use": "public", "hours": 1.0, "rate": 0.0, "per_head": 5.0, "heads": 18,
		"windows": [["weekday", 9.0, 12.0]], "min_ice": 0.0, "min_rooms": 15.0,
		"nets": [0, 0], "board": "clock", "flood_before": true, "ice": "hard", "sell": true},
	"school_skate": {"name": "School skating trip", "use": "public", "hours": 1.5, "rate": 110.0,
		"windows": [["weekday", 9.0, 14.5]], "min_ice": 20.0, "min_rooms": 20.0,
		"nets": [0, 0], "board": "clock", "flood_before": true, "ice": "hard", "sell": true},
	"private_rental": {"name": "Private rental (party, office team)", "use": "public", "hours": 1.0, "rate": 200.0,
		"windows": [["weekend", 10.0, 21.0], ["weekday", 18.0, 22.0]], "min_ice": 30.0, "min_rooms": 30.0,
		"nets": [2, 0], "board": "clock", "flood_before": true, "ice": "hard", "sell": true},
	"learn_to_skate": {"name": "Adult learn-to-skate", "use": "public", "hours": 1.0, "rate": 140.0,
		"windows": [["weekday", 18.0, 21.0]], "min_ice": 35.0, "min_rooms": 0.0,
		"nets": [0, 0], "board": "clock", "flood_before": true, "ice": "hard", "sell": false},
	"broomball": {"name": "Broomball", "use": "public", "hours": 1.5, "rate": 130.0,
		"windows": [["any", 21.0, 25.5]], "min_ice": 30.0, "min_rooms": 0.0,
		"nets": [2, 0], "board": "game", "flood_before": false, "ice": "snowed", "sell": false},
	"pro_practice": {"name": "Pro team practice", "use": "hockey", "hours": 2.0, "rate": 320.0,
		"windows": [["weekday", 9.0, 13.0]], "min_ice": 85.0, "min_rooms": 75.0,
		"nets": [4, 0], "board": "clock", "flood_before": true, "ice": "hard", "sell": false},
	"tournament": {"name": "Tournament", "use": "hockey", "hours": 10.0, "rate": 190.0,
		"windows": [["weekend", 7.0, 22.0]], "min_ice": 70.0, "min_rooms": 60.0,
		"nets": [2, 0], "board": "game", "scorekeeper": true, "flood_before": true, "ice": "hard", "rules": "minor_game", "sell": false},
}

## Contract organisations (RinkContracts) -> the kind of event they put on.
const CONTRACT_KINDS := {
	"vbl_d": "beer_league_game", "vbl_a": "beer_league_game", "public_skate": "public_skate",
	"learn_to_skate": "learn_to_skate", "broomball": "broomball", "minor_hockey": "minor_practice",
	"figure_club": "figure_class", "high_school": "high_school_practice", "lumber_kings": "senior_game",
	"tournament": "tournament", "dukes_practice": "pro_practice",
}


static func kind(id: String) -> Dictionary:
	return KINDS.get(id, {})


static func for_org(org: String) -> String:
	return str(CONTRACT_KINDS.get(org, "private_rental"))


static func sellable() -> Array:
	var out: Array = []
	for id in KINDS:
		if bool(KINDS[id].get("sell", false)):
			out.append(id)
	return out


static func is_weekend(weekday: int) -> bool:
	return weekday == 0 or weekday == 6


## Prime time: weekday evenings, weekend days. Everything else is non-prime.
static func is_prime(weekday: int, hour: float) -> bool:
	if is_weekend(weekday):
		return hour >= 7.0 and hour < 22.0
	return hour >= 16.0


## Whether `kind_id` may run `hours` from `start` on a day with this weekday.
static func in_window(kind_id: String, weekday: int, start: float, hours: float) -> bool:
	for w in kind(kind_id).get("windows", []):
		var days: String = w[0]
		if days == "weekday" and is_weekend(weekday):
			continue
		if days == "weekend" and not is_weekend(weekday):
			continue
		if start >= float(w[1]) - 0.001 and start + hours <= float(w[2]) + 0.001:
			return true
	return false


## The ice rate for this kind at this time ($/h): non-prime hours sell cheaper.
static func rate(kind_id: String, weekday: int, start: float) -> float:
	var r := float(kind(kind_id).get("rate", 0.0))
	return r if is_prime(weekday, start) else r * NON_PRIME


## How many walk-ins come (`heads` scaled by the hour, the weekday and the
## season): a weekday-morning public skate is a handful, a winter Saturday
## afternoon is full, and the Christmas break fills every session.
static func expected_heads(kind_id: String, weekday: int, start: float, day_of_year: int) -> float:
	var base := float(kind(kind_id).get("heads", 0))
	if base <= 0.0:
		return 0.0
	var k := 1.0
	if is_weekend(weekday):
		k = 1.5 if start >= 12.0 and start < 17.0 else 1.0
	else:
		k = 0.35 if start < 15.0 else (0.8 if start < 18.0 else 0.9)
	if kind_id == "parent_tot" or kind_id == "noon_shinny":
		k = 1.0  # these are made for the daytime
	# winter is the season, and the Christmas break (Dec 20 to Jan 4) is the peak
	var doy := posmod(day_of_year, 365)
	if doy >= 353 or doy <= 3:
		k *= 2.2
	elif doy >= 305 or doy <= 75:
		k *= 1.2
	elif doy >= 152 and doy <= 243:
		k *= 0.5
	return base * k


## Why a slot fails a kind's criteria at this rink, or "" when it's fine.
static func criteria_problem(kind_id: String, weekday: int, start: float, hours: float, ice_rep: float, rooms: float) -> String:
	var k := kind(kind_id)
	if k.is_empty():
		return "No such event."
	if not in_window(kind_id, weekday, start, hours):
		return "%s don't run at that time." % k.name
	if ice_rep < float(k.get("min_ice", 0.0)):
		return "%s: the ice isn't good enough (reputation %.0f, need %.0f)." % [k.name, ice_rep, float(k.min_ice)]
	if rooms < float(k.get("min_rooms", 0.0)):
		return "%s: the rooms aren't good enough (facility %.0f, need %.0f)." % [k.name, rooms, float(k.min_rooms)]
	return ""
