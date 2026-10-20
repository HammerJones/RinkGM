class_name StaffRoster
extends RefCounted
## Who the rink employs beyond the named cast (W28, "people as characters").
## Townsfolk come out of the archetypes with one shared rink-staff schedule,
## so the town's half-dozen generated staff all clocked in at the zamboni bay
## at six and said the same things. Here each of them is hired into a
## position of their own: its place, shifts, title, work clothes and lines.
## The rink only has so many jobs; anyone left over works elsewhere.
##
## Lines are dealt, not shared: a position's own lines belong to its one
## holder, and every staff archetype's bark lines are split round the staff
## of that archetype, so no two people at the rink say the same thing.

## One person each, filled in this order. Shifts are schedule blocks
## (days 0 = Sunday). `prefers` is the archetype a position prefers.
const POSITIONS := [
	{"id": "ice_crew", "title": "Ice crew, weekday mornings", "place": "zamboni_bay", "outfit": "coveralls", "prefers": "rink_staff",
		"shifts": [[[1, 2, 3, 4, 5], 6.0, 12.0]],
		"lines": ["Edged the boards before you got here. You're welcome.", "Doors are sticking again. Third time this week.",
			"I can tell you who skated last night by the gouges.", "Earl wants the snow pit empty by nine. It won't be."]},
	{"id": "front_desk", "title": "Front desk", "place": "lobby", "outfit": "staff_polo", "prefers": "rink_staff",
		"shifts": [[[1, 2, 3, 4, 5], 8.0, 16.0]],
		"lines": ["Public skate's at noon. Helmets for the under-tens.", "Lost and found's in the box by my feet. Mostly mitts.",
			"If the phone rings one more time about the schedule, I'm laminating it.", "Sign in, please. Even if you're just watching."]},
	{"id": "snack_bar_am", "title": "Hot Stove, weekday mornings", "place": "canteen", "outfit": "canteen_apron", "prefers": "canteen_worker",
		"shifts": [[[1, 2, 3, 4, 5], 7.0, 13.0]],
		"lines": ["Coffee's on. First pot's for the ice crew.", "Muffins came in from the bakery at six. Blueberry's gone.",
			"Mornings are seniors and coffee. I like mornings.", "Lorraine does the fries. I do the coffee. That's the deal."]},
	{"id": "skate_rental", "title": "Skate rental and sharpening", "place": "skate_rental", "outfit": "shop_apron", "prefers": "rink_staff",
		"shifts": [[[0, 6], 10.0, 18.0], [[2, 4], 17.0, 21.0]],
		"lines": ["What size? Go up a half if you're in between.", "These were sharpened Tuesday. They're fine. Probably.",
			"Bring them back laced, please. I'm begging.", "Two pairs of nines left. Choose wisely."]},
	{"id": "custodian", "title": "Custodian", "place": "hall", "outfit": "work_jacket", "prefers": "rink_staff",
		"shifts": [[[1, 2, 3, 4, 5], 14.0, 22.0]],
		"lines": ["Mind the floor, I just mopped it. Again.", "Somebody keeps putting gum on the bleachers. I will find you.",
			"Washroom by the rec hall's out of towels. On my list.", "Every winter the salt eats this lobby alive."]},
	{"id": "coach", "title": "Learn-to-skate coach", "place": "bench", "outfit": "coach_tracksuit", "prefers": "rink_staff",
		"shifts": [[[6, 0], 8.0, 12.0], [[3], 17.0, 19.0]],
		"lines": ["Knees bent, arms out. Like you're carrying a pizza.", "Falling's part of it. Getting up's the lesson.",
			"My first coach skated in figure skates and a parka. Toughest woman I ever met.", "Six-year-olds are fearless until they aren't."]},
	{"id": "front_desk_weekend", "title": "Front desk, weekends", "place": "lobby", "outfit": "staff_polo", "prefers": "rink_staff",
		"shifts": [[[0, 6], 8.0, 16.0]],
		"lines": ["Weekends it's tournaments and birthday parties. Bring earplugs.", "Party room's booked till two. Cake's in the fridge.",
			"Visiting team? Dressing room four, past the bay.", "If you parked in the fire lane, now's your chance."]},
	{"id": "night_crew", "title": "Night ice crew", "place": "zamboni_bay", "outfit": "coveralls", "prefers": "rink_staff",
		"shifts": [[[1, 2, 3, 4, 5], 16.0, 23.0]],
		"lines": ["Beer league's in at nine. They'll want a fresh sheet and get what they get.", "Last flood's at eleven. Then I go home.",
			"Night ice is the best ice. Nobody's been on it.", "Doris runs better cold. So do I."]},
	{"id": "office_clerk", "title": "Office clerk, afternoons", "place": "office", "outfit": "cardigan", "prefers": "rink_staff",
		"shifts": [[[1, 2, 3, 4, 5], 13.0, 17.0]],
		"lines": ["Invoices in the left tray. Complaints in the bin. Kidding.", "Priya books them, I chase the money.",
			"The minor hockey cheque bounced again.", "Printer's jammed. The printer's always jammed."]},
	{"id": "ticket_booth", "title": "Ticket booth, game nights", "place": "entrance", "outfit": "staff_polo", "prefers": "canteen_worker",
		"shifts": [[[5, 6], 17.0, 22.0]],
		"lines": ["Adults five, kids two, seniors free if they cheer.", "Cash only. The card thing's been broken since summer.",
			"Hand stamps for re-entry. Don't lick it.", "Big crowd tonight. Visitors brought a bus."]},
	{"id": "maintenance", "title": "Building maintenance", "place": "plant_room", "outfit": "work_jacket", "prefers": "rink_staff",
		"shifts": [[[1, 2, 3, 4, 5], 10.0, 16.0]],
		"lines": ["Marguerite does the plant. I do everything that isn't the plant.", "That roof leak? Bucket's doing its best.",
			"Fixed the dryer in the dressing room. With a coat hanger.", "The boiler's older than me. Treat it nicely."]},
	{"id": "snack_bar_pm", "title": "Hot Stove, weekend afternoons", "place": "canteen", "outfit": "canteen_apron", "prefers": "canteen_worker",
		"shifts": [[[0, 6], 12.0, 19.0]],
		"lines": ["Tournament days we go through forty dozen hot dogs.", "Fries are two minutes. I'm not lying this time.",
			"Hot chocolate machine's got one setting: lava.", "Napkins are by the mustard. Take two, they're thin."]},
]

## The archetypes the rink's generated staff come from.
const STAFF_ARCHETYPES := ["rink_staff", "canteen_worker"]


## Hires the cast's generated staff into POSITIONS (each person's schedule,
## job, place and outfit become the position's) and deals out everyone's
## lines. Returns {position id: person id}.
static func hire(cast: Cast) -> Dictionary:
	var pool: Array = cast.people.values().filter(func(p: Person) -> bool:
		return p.generated and p.role == "staff" and p.archetype in STAFF_ARCHETYPES)
	pool.sort_custom(func(a: Person, b: Person) -> bool: return a.id < b.id)
	var out := {}
	for pos: Dictionary in POSITIONS:
		if pool.is_empty():
			break
		var who: Person = pool[0]
		for p: Person in pool:
			if p.archetype == pos.prefers:
				who = p
				break
		pool.erase(who)
		_take(who, pos)
		out[pos.id] = who.id
	for p: Person in pool:
		_let_go(p)
	deal_lines(cast)
	return out


## `p` takes the position: their rink work blocks become its shifts.
static func _take(p: Person, pos: Dictionary) -> void:
	p.schedule = p.schedule.filter(func(e) -> bool: return str(e.get("doing", "")) != "work")
	for s: Array in pos.shifts:
		p.schedule.append({"days": s[0].duplicate(), "from": float(s[1]), "to": float(s[2]), "place": pos.place, "doing": "work"})
	p.job = "%s, Millbrook Arena" % pos.title
	p.work = {}  # `work` is a day job away from the rink; theirs is here (on_shift)
	p.look["outfit"] = pos.outfit
	p.lines = {"idle": (pos.lines as Array).duplicate()}


## No position left: they work somewhere else in town and come as anyone.
static func _let_go(p: Person) -> void:
	p.schedule = p.schedule.filter(func(e) -> bool: return str(e.get("doing", "")) != "work")
	p.role = "regular"
	p.job = "Works in town"
	p.work = {}


## Splits each staff archetype's bark lines round the staff of that
## archetype (named cast included), so each line has one speaker. A topic
## with fewer lines than people leaves the rest to their own dialogue.
static func deal_lines(cast: Cast) -> void:
	for arch_id: String in STAFF_ARCHETYPES:
		var barks: Dictionary = cast.archetype(arch_id).get("barks", {})
		var staff: Array = cast.people.values().filter(func(p: Person) -> bool:
			return p.role == "staff" and p.archetype == arch_id)
		staff.sort_custom(func(a: Person, b: Person) -> bool: return a.id < b.id)
		if staff.is_empty():
			continue
		for topic: String in barks:
			if not barks[topic] is Array:
				continue
			var lines: Array = barks[topic]
			for i in lines.size():
				var p: Person = staff[i % staff.size()]
				if not p.lines.has(topic):
					p.lines[topic] = []
				p.lines[topic].append(lines[i])
