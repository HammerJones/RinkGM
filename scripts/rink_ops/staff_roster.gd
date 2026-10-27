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

## What each position says when something's going on (W29): the first and
## last hour of a shift, a fresh sheet just laid, a hockey game tonight, a
## machine down. Dealt with the position, so these too have one speaker.
const WHEN := {
	"ice_crew": {
		"start": ["Six o'clock. The ice doesn't care that I'm tired.", "Coffee first. Then the doors. Then the coffee again."],
		"end": ["Noon. Night crew can have her.", "Logging my floods and going home to sleep sideways."],
		"resurfaced": ["Fresh sheet. Nobody touch it for five minutes.", "Look at that. Glass. Somebody take a picture."],
		"game_tonight": ["Game tonight, so I'm leaving them a thin flood at four.", "Night crew's got the game. I'm just making sure they've got ice to give."],
		"broken": ["She's down. I told them about that hose in August.", "Can't flood with a dead machine. Shovels it is, I guess."]},
	"front_desk": {
		"start": ["Morning. Phones are already ringing.", "Unlocking the till. Don't talk to me until it balances."],
		"end": ["Four o'clock. The weekend kid can take the phone.", "Last call for the lost and found. Then it's mine."],
		"resurfaced": ["They just flooded, so public skate's a few minutes late. Sorry.", "Ice is fresh if anyone asks. People always ask."],
		"game_tonight": ["Game tonight. I've had nine calls about parking.", "Visitors' bus parks out back tonight. Not in the fire lane."],
		"broken": ["If you're here to ask about the machine, join the queue.", "I'm telling people it's 'maintenance'. Sounds better."]},
	"snack_bar_am": {
		"start": ["Fryer's warming. Coffee's not. Give me two minutes.", "First pot's brewing. Smell that? That's hope."],
		"end": ["Wiping down. The afternoon crowd gets what's left.", "Last coffee's on the house. Don't tell Lorraine."],
		"resurfaced": ["Flood's done, so here comes the rush. Watch.", "Ice crew gets a free coffee after a flood. House rule."],
		"game_tonight": ["Game tonight. I'm prepping forty hot dogs before I go.", "Big night. I'll leave the night shift the good buns."],
		"broken": ["Machine's down? Then I'm selling a lot of coffee to worried people.", "Everyone's waiting on the mechanic. Mechanics drink coffee too."]},
	"skate_rental": {
		"start": ["Wheel's warming up. First sharpen's ten minutes.", "Counting pairs. Somebody walked off with a size eight again."],
		"end": ["Last rentals back by six, laced, please.", "Closing the window. Sharpening tomorrow."],
		"resurfaced": ["Fresh ice. Perfect time to find out your edges are bad.", "They just flooded. Ten minutes and you're out there."],
		"game_tonight": ["Game tonight. Every player in town wants a sharpen by five.", "I've done twelve pairs of goalie skates today. My wrists hurt."],
		"broken": ["Ice is closed till they fix it. Rentals are free to look at.", "Nobody's renting skates for ice they can't use."]},
	"custodian": {
		"start": ["Two o'clock. The morning left me a mess.", "Mop's wet, bucket's full. Let's see what they did to the washrooms."],
		"end": ["Lights in the hall go off at ten. That means you.", "Last round. Then I lock up and drive home with the window down."],
		"resurfaced": ["Fresh ice means wet boots means my floor. Every time.", "Snow pit's full again after that flood. Not my department. Still my mess."],
		"game_tonight": ["Game tonight. Popcorn everywhere by ten. I can already see it.", "Putting out the extra bins for the crowd tonight."],
		"broken": ["Something's broken? Not my mop. Everything else, ask Earl.", "Machine's down, so nobody's tracking slush in at least."]},
	"coach": {
		"start": ["Morning, skaters. Helmets on before skates on.", "Pylons out. Little ones first, big ones help."],
		"end": ["Good work today. Same time next week.", "Gloves off the ice, please. I find them for weeks."],
		"resurfaced": ["Fresh ice. Don't fall on it before I do.", "Clean sheet. Today we do our crossovers properly."],
		"game_tonight": ["There's a game tonight. Go watch how the big ones stop.", "Watch the game tonight and count the crossovers."],
		"broken": ["No ice? Then it's dryland. Grab a pylon.", "Lesson's off till they fix the machine. Stretch anyway."]},
	"front_desk_weekend": {
		"start": ["Weekend. Birthday parties at ten, eleven and noon.", "Putting the tournament draw up on the board."],
		"end": ["Four o'clock. Somebody else's birthday party now.", "I'm going home to a quiet room and no cake."],
		"resurfaced": ["Flood's done, the tournament's back on time. Barely.", "Fresh ice. Tell the coaches, they'll stop asking me."],
		"game_tonight": ["Game tonight after the tournament. Long day for the ice.", "We've got a game tonight too. Pray for the night crew."],
		"broken": ["The tournament's behind and the machine's down. Lovely.", "I'm telling the coaches it's a 'short delay'. It's not."]},
	"night_crew": {
		"start": ["Four o'clock. Doris and me, all night.", "Checking her oil before the evening rush."],
		"end": ["Last flood's down. Lights out, I'm gone.", "Logging the night. Day crew can deal with the doors."],
		"resurfaced": ["That's the one before the game. Nicest ice all day.", "Laid it thin. Let it set. Don't let the beer league near it yet."],
		"game_tonight": ["Game tonight. I'll do a flood between periods if they let me.", "Two floods tonight with the game. I'll earn my sandwich."],
		"broken": ["She's down and there's a game tonight. Great.", "No machine, no flood. I'll scrape by hand if I have to."]},
	"office_clerk": {
		"start": ["One o'clock. The invoices have been breeding.", "Kettle on, inbox open. Let's see who owes what."],
		"end": ["Five. Whatever's in the tray is tomorrow's.", "Posting the bills on my way out."],
		"resurfaced": ["Every flood costs gas and water. I see it in the bills.", "Another flood. I'll put it on the log."],
		"game_tonight": ["Game tonight. Gate money better beat the hydro bill.", "Printed the game sheets. Somebody tell the scorekeeper."],
		"broken": ["A repair bill. Wonderful. Which budget line is 'hope'?", "I'm already writing the cheque for the mechanic. Again."]},
	"ticket_booth": {
		"start": ["Booth's open. Float's counted. Hand stamps are inked.", "Cash box, roll of tickets, a coffee. Ready."],
		"end": ["Booth's closing. Late arrivals pay at the door.", "Counted twice. We're up eight dollars. Don't ask me how."],
		"resurfaced": ["Fresh ice for the game. People notice, you know.", "They flooded just now, so we're starting on time for once."],
		"game_tonight": ["Big crowd tonight. Visitors brought a bus.", "Game night. Best night of the week, if you ask me."],
		"broken": ["If the game's off, I'm doing refunds. I hate refunds.", "Machine's down? Then I'm selling tickets on faith."]},
	"maintenance": {
		"start": ["Ten o'clock. Work orders on the clipboard, all urgent.", "Rounds first. The boiler, the roof, the door that sticks."],
		"end": ["Four. If it's still dripping, the bucket's on duty.", "Signing off. Call me if it's actually on fire."],
		"resurfaced": ["Floods put a lot of hot water through that heater. I'll check it.", "Fresh ice. Means the hot water tank's empty for an hour."],
		"game_tonight": ["Game tonight. Testing the horn. Sorry, everyone.", "Checking the scoreboard bulbs before the game."],
		"broken": ["Down again. I'll get my tools.", "Something's broken. That's what they pay me for, I suppose."]},
	"snack_bar_pm": {
		"start": ["Afternoon shift. Hot dog roller's on.", "Refilling the ketchup. It's always the ketchup."],
		"end": ["Fryer's off at seven. I mean it this time.", "Counting the float. Somebody paid in quarters again."],
		"resurfaced": ["Flood's done, so the parents come for coffee. Every time.", "Fresh ice, fresh fries. That's the deal."],
		"game_tonight": ["Game tonight. I'm leaving forty dozen hot dogs for the night crew.", "Busy night coming. Restocking the gum."],
		"broken": ["Machine's down and everyone's hungry while they wait.", "Nothing sells fries like a delay."]},
}

## How a staff member keeps time, dealt by id: [name, earliest, latest]
## minutes after the shift starts (negative is early). Each day lands
## somewhere in the range, so the late ones aren't late the same way twice.
const PUNCTUALITY := [
	["early", -15, -5],
	["on time", 0, 3],
	["runs late", 0, 20],
	["late a lot", 10, 40],
]

## A shift this long gets a break in the middle (hours), taken in the hall.
const BREAK_AFTER := 5.0
const BREAK_PLACE := "hall"

## How often a staff member says a situational line instead of an idle one.
const SITUATION_CHANCE := 0.6

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
		var from := float(s[1])
		var to := float(s[2])
		var h := posmod(hash(p.id), 5)
		if to - from >= BREAK_AFTER:
			# lunch in the middle, give or take half an hour by habit
			var at := snappedf((from + to) * 0.5 + float(h - 2) * 0.25, 0.25)
			var rest := 0.5 if to - from >= 7.0 else 0.25
			p.schedule.append({"days": s[0].duplicate(), "from": from, "to": at, "place": pos.place, "doing": "work"})
			p.schedule.append({"days": s[0].duplicate(), "from": at, "to": at + rest, "place": BREAK_PLACE, "doing": "work", "break": true})
			p.schedule.append({"days": s[0].duplicate(), "from": at + rest, "to": to, "place": pos.place, "doing": "work"})
		else:
			p.schedule.append({"days": s[0].duplicate(), "from": from, "to": to, "place": pos.place, "doing": "work"})
	p.job = "%s, Millbrook Arena" % pos.title
	p.work = {}  # `work` is a day job away from the rink; theirs is here (on_shift)
	p.look["outfit"] = pos.outfit
	p.lines = {"idle": (pos.lines as Array).duplicate()}
	for k: String in WHEN.get(pos.id, {}):
		p.lines[k] = (WHEN[pos.id][k] as Array).duplicate()
	var punct: Array = PUNCTUALITY[posmod(hash(p.id + "/clock"), PUNCTUALITY.size())]
	p.habits = {"position": pos.id, "title": pos.title, "punctuality": punct[0], "late": [punct[1], punct[2]]}


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


## Minutes `p` turns up after (negative: before) their shift on day `day`:
## somewhere in their punctuality range, the same all day.
static func late_minutes(p: Person, day: int) -> int:
	var r: Array = p.habits.get("late", [0, 0])
	var lo := int(r[0])
	var hi := int(r[1])
	return lo + posmod(hash("%s/%d" % [p.id, day]), hi - lo + 1)


## Whether `p` should be at the rink at `hour`: on shift, and past the time
## their habit brings them in. `here` is whether they already are; lateness
## moves arriving, never leaving, and an early bird is wanted before the
## shift starts.
static func due(p: Person, wd: int, hour: float, day: int, here: bool) -> bool:
	var late := late_minutes(p, day) / 60.0
	if late < 0.0:
		return p.on_shift(wd, hour) or p.on_shift(wd, hour - late)
	return p.on_shift(wd, hour) and (here or p.on_shift(wd, hour - late))


## The whole shift `p` is on at `hour`, breaks included, as [from, to];
## empty when they're off.
static func shift_span(p: Person, wd: int, hour: float) -> Array:
	if not p.on_shift(wd, hour):
		return []
	var from := hour
	var to := hour
	var grew := true
	while grew:
		grew = false
		for e: Dictionary in p.schedule:
			if str(e.get("doing", "")) != "work" or not wd in e.get("days", []):
				continue
			var f := float(e.from)
			var t := float(e.to)
			if f < from and t >= from:
				from = f
				grew = true
			if t > to and f <= to:
				to = t
				grew = true
	return [from, to]


## What's going on for `p` right now, most pressing first: "broken" (Doris
## won't go or a compressor's out), "resurfaced" (a flood in the last 20
## minutes), "game_tonight" (hockey on the ice after five), "start" or "end"
## (the first or last hour of their shift), or "".
static func situation(sim: RinkSim, p: Person) -> String:
	if sim == null:
		return ""
	if sim.doris and sim.doris.fault() != "":
		return "broken"
	if sim.plant:
		for i in sim.plant.compressors.size():
			if sim.plant.compressor_health(i) <= 0.0:
				return "broken"
	if sim.minutes_since_flood() < 20:
		return "resurfaced"
	var hour := sim.minute / 60.0
	for s: Dictionary in sim.sessions(sim.day):
		if str(s.get("use", "")) == "hockey" and float(s.start) >= 17.0 and float(s.start) > hour:
			return "game_tonight"
	var span := shift_span(p, sim.weekday(), hour)
	if span.is_empty():
		return ""
	if hour - float(span[0]) < 1.0:
		return "start"
	if float(span[1]) - hour <= 1.0:
		return "end"
	return ""


## The topic `p` should speak to when asked for `topic`: an idle staff member
## with a line for what's going on talks about that instead, most times.
static func topic_now(w: StoryWorld, p: Person, topic: String) -> String:
	if topic != "idle" or p.lines.is_empty() or w.sim == null:
		return topic
	var now := situation(w.sim, p)
	if now == "" or not p.lines.has(now) or w.rng.randf() >= SITUATION_CHANCE:
		return topic
	return now


## `p`'s week for the staff screen: one row per day (0 = Sunday) of
## {"day", "shifts": [[from, to]], "breaks": [[from, to]], "off"}.
static func week(p: Person) -> Array:
	var out: Array = []
	for wd in 7:
		var shifts: Array = []
		var breaks: Array = []
		for e: Dictionary in p.schedule:
			if str(e.get("doing", "")) != "work" or not wd in e.get("days", []):
				continue
			if e.get("break", false):
				breaks.append([float(e.from), float(e.to)])
			var mid := (float(e.from) + float(e.to)) * 0.5
			var span := shift_span(p, wd, mid)
			if not span in shifts:
				shifts.append(span)
		shifts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		out.append({"day": wd, "shifts": shifts, "breaks": breaks, "off": shifts.is_empty()})
	return out


## "6:00", "13:30": an hour of the day as a clock.
static func clock(h: float) -> String:
	return "%d:%02d" % [int(h), roundi(fmod(h, 1.0) * 60.0)]


## `p`'s week in a line for the staff screen: days with the same hours
## grouped, then breaks, days off and how they keep time, e.g.
## "Mon-Fri 6:00-12:00 (break 9:00-9:15) | off Sun, Sat | early".
static func week_text(p: Person) -> String:
	var groups: Array = []  # [[days], hours text, breaks text]
	var off: Array = []
	for row: Dictionary in week(p):
		if row.off:
			off.append(RinkSim.DAY_NAMES[row.day])
			continue
		var hours := ", ".join(row.shifts.map(func(s: Array) -> String: return "%s-%s" % [clock(s[0]), clock(s[1])]))
		var rests := ", ".join(row.breaks.map(func(s: Array) -> String: return "%s-%s" % [clock(s[0]), clock(s[1])]))
		if not groups.is_empty() and groups[-1][1] == hours and groups[-1][2] == rests and groups[-1][0][-1] == row.day - 1:
			groups[-1][0].append(row.day)
		else:
			groups.append([[row.day], hours, rests])
	var parts: Array = []
	for g: Array in groups:
		var days: Array = g[0]
		var span: String = RinkSim.DAY_NAMES[days[0]] if days.size() == 1 else "%s-%s" % [RinkSim.DAY_NAMES[days[0]], RinkSim.DAY_NAMES[days[-1]]]
		parts.append("%s %s%s" % [span, g[1], " (break %s)" % g[2] if g[2] != "" else ""])
	var out := "; ".join(parts)
	if not off.is_empty():
		out += " | off " + ", ".join(off)
	if p.habits.has("punctuality"):
		out += " | " + str(p.habits.punctuality)
	return out


## Positions whose work includes keeping the building clean.
const CLEANING := ["custodian", "ice_crew", "night_crew"]
## Snack bar staff clean up in the last hour of their shift.
const CLOSING_CLEAN := ["snack_bar_am", "snack_bar_pm"]
const CLEANING_WORDS := ["janitor", "custodian", "attendant", "icemaker"]


## Everyone on the clock at `hour` of weekday `wd`, named cast included:
## [{"id", "place", "position" ("" for the named cast), "on_break"}].
static func staff_on(cast: Cast, wd: int, hour: float) -> Array:
	var out: Array = []
	for p: Person in cast.people.values():
		if not p.on_shift(wd, hour):
			continue
		var e := p.entry_at(wd, hour)
		out.append({"id": p.id, "place": str(e.get("place", "")), "position": str(p.habits.get("position", "")),
			"on_break": bool(e.get("break", false))})
	return out


## How many people on the clock are cleaning up right now (RinkMess): the
## custodian and the ice crews, snack bar staff closing up, and named staff
## whose job is the building's upkeep. Nobody cleans on their break.
static func cleaners_on(cast: Cast, wd: int, hour: float) -> int:
	var n := 0
	for s: Dictionary in staff_on(cast, wd, hour):
		if s.on_break:
			continue
		var p: Person = cast.people[s.id]
		if s.position in CLEANING:
			n += 1
		elif s.position in CLOSING_CLEAN:
			var span := shift_span(p, wd, hour)
			if float(span[1]) - hour <= 1.0:
				n += 1
		elif s.position == "" and CLEANING_WORDS.any(func(w: String) -> bool: return w in p.job.to_lower()):
			n += 1
	return n
