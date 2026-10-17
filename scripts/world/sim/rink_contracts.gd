class_name RinkContracts
extends RefCounted
## The organisations that rent ice, and what they need before they'll sign.
## Better ice and better rooms unlock better customers; poor ice loses them.
## `min_ice` is the rink's ice reputation (0..100) they need to bid,
## `min_rooms` the facility score. Times are hours of the day.

const ORGS := [
	{"id": "vbl_d", "name": "Valley Beer League (D and C)", "use": "hockey", "slots": [[2, 22.0, 2.0], [4, 22.0, 2.0]],
		"rate": 160.0, "min_ice": 0.0, "min_rooms": 0.0, "weeks": 16},
	{"id": "public_skate", "name": "Public skate", "use": "public", "slots": [[5, 13.0, 2.0], [6, 13.0, 2.0]],
		"rate": 0.0, "per_head": 6.0, "heads": 40, "min_ice": 0.0, "min_rooms": 0.0, "weeks": 52},
	{"id": "learn_to_skate", "name": "Adult learn-to-skate", "use": "public", "slots": [[1, 19.0, 1.0]],
		"rate": 140.0, "min_ice": 35.0, "min_rooms": 0.0, "weeks": 10},
	{"id": "broomball", "name": "Harlow Falls Broomball Club", "use": "public", "slots": [[3, 21.0, 1.5]],
		"rate": 130.0, "min_ice": 30.0, "min_rooms": 0.0, "weeks": 12},
	{"id": "minor_hockey", "name": "Millbrook Minor Hockey Association", "use": "hockey",
		"slots": [[1, 17.0, 3.0], [3, 17.0, 3.0], [5, 8.0, 4.0], [6, 8.0, 4.0]],
		"rate": 175.0, "min_ice": 50.0, "min_rooms": 25.0, "weeks": 24},
	{"id": "figure_club", "name": "Millbrook Figure Skating Club", "use": "figure", "slots": [[2, 6.0, 2.0], [4, 6.0, 2.0], [6, 12.0, 2.0]],
		"rate": 170.0, "min_ice": 55.0, "min_rooms": 30.0, "weeks": 24},
	{"id": "high_school", "name": "Millbrook High Mallards", "use": "hockey", "slots": [[2, 15.5, 1.5], [4, 15.5, 1.5]],
		"rate": 165.0, "min_ice": 55.0, "min_rooms": 35.0, "weeks": 14},
	{"id": "vbl_a", "name": "Valley Beer League A Division", "use": "hockey", "slots": [[3, 22.0, 2.0], [5, 22.0, 2.0]],
		"rate": 185.0, "min_ice": 60.0, "min_rooms": 35.0, "weeks": 16},
	{"id": "lumber_kings", "name": "Millbrook Lumber Kings (Senior AAA)", "use": "hockey",
		"slots": [[2, 19.0, 1.5], [4, 19.0, 1.5], [6, 19.0, 3.0]],
		"rate": 210.0, "min_ice": 72.0, "min_rooms": 55.0, "weeks": 20},
	{"id": "tournament", "name": "Valley Peewee Tournament (weekend)", "use": "hockey", "slots": [[6, 7.0, 12.0], [0, 7.0, 10.0]],
		"rate": 190.0, "min_ice": 70.0, "min_rooms": 60.0, "weeks": 1},
	{"id": "dukes_practice", "name": "Duncannon Dukes practice ice", "use": "hockey", "slots": [[1, 10.0, 2.0], [3, 10.0, 2.0]],
		"rate": 320.0, "min_ice": 85.0, "min_rooms": 75.0, "weeks": 12},
]


static func org(id: String) -> Dictionary:
	for o in ORGS:
		if o.id == id:
			return o
	return {}


## Who will bid on ice at a rink with this reputation.
static func offers(ice_rep: float, rooms: float, signed: Array) -> Array:
	var out: Array = []
	for o in ORGS:
		if o.id in signed:
			continue
		if ice_rep >= float(o.min_ice) and rooms >= float(o.min_rooms):
			out.append(o)
	return out


## Expected revenue per week of a contract.
static func weekly_revenue(o: Dictionary) -> float:
	var total := 0.0
	for s in o.slots:
		var hours: float = s[2]
		total += float(o.get("rate", 0.0)) * hours + float(o.get("per_head", 0.0)) * float(o.get("heads", 0))
	return total
