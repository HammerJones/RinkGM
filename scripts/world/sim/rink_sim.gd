class_name RinkSim
extends RefCounted
## The owner-operator rink: one building, its ice plant, its ice, Doris the
## resurfacer, the contracts that rent the ice and the books. Pure logic (no
## nodes), saved with to_dict()/from_dict(), advanced in in-game minutes.
##
## The player is the whole staff at first: every job costs hours from the
## owner's day (`hours_left`) and the mini games feed a `quality` into the job.
## What the player sees of the machines comes through SimInstrument, so better
## tools mean truer numbers. See docs/world/RINK_SIM.md (section 8, M1, lists
## the public surface).
##
## `create()` is the original sandbox rink (day 0 a Sunday in October).
## `create_m1()` is the vertical slice: Monday 1 September, Year 1, 05:00, with
## Gus's binder, the week's goals, the minor hockey bid and Doris refusing to
## start. advance() and advance_days() are the only ways the clock moves.

## A booking went on the ice (or was sent home: `rating` < 0). RinkLife
## listens, to decide who came and how they felt about it.
signal session_started(session: Dictionary, rating: float, wetness: float)
signal day_ended(day: int)

const STEP_MIN := 15
## The owner's day (docs 2.1): 14 hours, up to 4 more as overtime.
const OWNER_HOURS := 14.0
const OVERTIME_MAX := 4.0
## How well a staff member does a job handed to them (0..1); the owner brings their own skill.
const STAFF_QUALITY := 0.6
const WAKE_MIN := 5 * 60         # the owner's day starts at 05:00
const POWER_PRICE := 0.14       # $ per kWh
const DAILY_FIXED := 158.34     # the sum of FIXED_LINES, kept for old callers
## The month's fixed bills (docs 5.8) spread over its days.
const FIXED_LINES := {"insurance": 46.67, "property tax": 33.33, "water and sewer": 21.67,
	"natural gas": 45.0, "phone, internet, waste": 6.67, "water treatment": 5.0}
const FLOOD_GAS := 3.40         # gas and hot water per flood (docs 1.2)
const GLYCOL_PRICE := 4.0       # $ per litre of concentrate
const ROOMS := ["lobby", "home_dressing", "visitor_dressing", "washrooms", "stands", "pro_shop"]
const DAY_NAMES := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
const MONTH_NAMES := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const MONTH_DAYS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const RESURFACE_LEAD_MIN := 30  # Doris goes out this long before a booking, so the flood can freeze in
const INTERMISSION_MIN := 70    # the second intermission of a two-hour game slot
const MORNING_FLOOD_MIN := 5 * 60 + 50
const LIGHTS_WARM_MIN := 15.0   # metal halides take about 15 minutes to come up
const LIGHTS_KW := 32.0         # 48 old metal halides, all of it heat on the ice
const BASE_KW := 6.0            # exit lights, the office, the fridge
const RELEASE_FINE := 2500.0     # a reportable ammonia release
const HEAT_RECOVERY_PRICE := 0.06  # $ of gas saved per kWh of recovered heat
## The owner's own Beer League team: free while they learn, then dues like
## everyone else (Sean, 2026-10-17). Season fee from PROSHOP.md.
const LEAGUE_FREE_DAYS := 56
const LEAGUE_DUES := 120.0
const LEAGUE_GRACE_DAYS := 14
const GAME_HOURS := 3.0         # warm-up, the game, the beer

## M1 numbers (docs 0, 1.6, 5.2, open question 2).
const M1_START_CASH := 8000.0
const M1_ELECTRICITY_BILL := 11240.0
const CIA_WEEKLY_PAY := 60.0    # the town's transition fund pays the owner (not the rink)
const HARLOW_FALLS := {"name": "Harlow Falls", "price": 168.0, "slot_fit": 0.8, "ice": 62.0, "facility": 45.0, "distance": 0.4}
const BID_WEIGHTS := {"price": 0.4, "slot_fit": 0.3, "ice": 0.15, "facility": 0.1, "distance": 0.05}
const BID_BUDGET := Vector2(150.0, 185.0)  # $/h where the price score runs from 1 to 0
const BID_HOURS := 1.0

## Gus's binder: the notes taped to the plant room door, the dash and the desk.
const GUS_NOTES := [
	{"id": "welcome", "where": "front door", "text": "WELCOME. DON'T TOUCH BREAKER 14. GUS"},
	{"id": "oil_first", "where": "plant room door", "text": "Every morning. Oil first. Number 1 drinks."},
	{"id": "oil_half", "where": "compressor 1", "text": "Oil's in the blue drum. Hand pump. HALF the glass, not full."},
	{"id": "oil_hours", "where": "binder", "text": "Oil every 1,500 hours or when it goes dark, and number 1 goes dark in a thousand."},
	{"id": "screwdriver", "where": "binder", "text": "Push a screwdriver in at the blue line. If it goes in easy, the ice is soft. If it bounces, you've hit concrete and we have problems."},
	{"id": "plugs", "where": "Doris's dash", "text": "If Doris won't start it's the plugs. It's always the plugs. Unless it's the choke."},
	{"id": "plug_gap", "where": "drawer labelled DORIS", "text": "Gap them to 35 thou. Hand tight, then a quarter turn. Don't cross-thread her, the head's aluminium."},
	{"id": "blade", "where": "bay wall", "text": "Blade at a millimetre. Level end to end. Bolts from the centre out."},
	{"id": "thick", "where": "the electricity bill", "text": "Ice is too thick. Earl likes it thick. Earl doesn't pay the bill."},
	{"id": "snow_pit", "where": "bay", "text": "Melt pit heater's tired. Hose the pit down every day or Doris has nowhere to dump."},
	{"id": "mondays", "where": "binder", "text": "Take Mondays. I never did. Look at me."},
	{"id": "oversleep", "where": "binder", "text": "If you sleep through the alarm, the ice doesn't. Set two."},
]

var rng := RandomNumberGenerator.new()
var mode := "sandbox"     # "m1" for the vertical slice
var day := 0              # days since the start; create() day 0 is a Sunday in October
var minute := 6 * 60      # minutes since midnight
var start_weekday := 0    # weekday of day 0, 0 = Sunday (RinkContracts weekdays)
var start_doy := 287      # day of the year of day 0 (0 = 1 January): 15 October
var money := 2500.0
var hours_left := OWNER_HOURS + OVERTIME_MAX  # left in the owner's day, overtime included
var hours_worked := 0.0   # in the owner's day so far (05:00 to 05:00)
var fatigue := 0.0        # 0..100 (docs 2.1)
var overslept_day := -1   # fatigue 90+: the owner slept through this day's 05:00 block
var skill := {"driving": 0.55, "mechanic": 0.4}
var tools := {}       # reading -> instrument tier (SimInstrument.CATALOG)
var inventory := {}   # part id -> count on the shelf ("spark_plugs")
var rooms := {}       # room id -> Wear age, 0..2
var cleanliness := 0.55
var ice_rep := 40.0   # what customers think of the ice, 0..100
var rep_window_hours := 50.0  # booked hours the reputation remembers; smaller moves faster
var contracts := {}   # org id -> {"weeks_left", "satisfaction", optional "slots", "rate", "start_day"}
var events: Array = []  # [{"day", "minute", "text", "kind"}]
var ledger := {}      # category -> dollars this day (negative is spending)
var books: Array = [] # one entry per finished day: {"day", "revenue", "costs", "kwh", "ice", "ledger", "money_start", "money_end", "hours"}
var auto_resurface := false  # Doris goes out for every flood on the grid that has a crew
var morning_flood := true    # the first flood of the day at 05:50
var earl_hired := false      # Earl floods evenings and weekends once he's back (M2)
## The owner's own floods wait for the player to drive Doris (the
## doris_drive mini game) instead of happening by themselves: always when
## set, and while the owner is on site (the walk calls owner_on_site()).
## With a driver hired they stay automatic.
var owner_drives := false
var owner_here_until := -1      # absolute minute the walk last vouched for
var floods_waiting: Array = []  # [{"day", "minute", "for_org", "kind"}] owner floods not driven yet
var plate_closures: Array = []  # [{"day", "spot"}] the ice shut while a depth plate freezes in
var work_orders: Array = []   # [{"id", "args", "day", "minute", "by", "who", "hours"}] jobs handed to staff (WorkOrders)
var orders: Array = []    # [{"model", "arrives_day", "balance"}] compressors on the way
var delivered: Array = [] # models sitting in the parking lot, waiting to go in
var installs: Array = []  # [{"compressor", "model", "done_day", "quality"}]
var conversion := {}      # {"to", "done_day"} while the plant is being converted
var rental_until := -1    # last day of the rented chiller, -1 for none
var evacuated_day := -1   # a toxic release emptied the building this day
## Owner's Beer League dues: "free_until" day, "owed" dollars, "due_day", "benched".
var league := {"free_until": LEAGUE_FREE_DAYS, "owed": 0.0, "due_day": -1, "benched": false, "paid_through": -1}
var owner_game_weekday := 2  # the owner's BL-D game is the Tuesday vbl_d slot
var games: Array = []        # [{"day", "minute", "minutes"}] the owner's own games
## The owner's changes to the contracts' slots (Mechanics' RinkSchedule).
var schedule := RinkSchedule.new()
## Scoreboard, nets and scorekeeper between sessions (Mechanics' RinkOps).
var ops := RinkOps.new()
## What's on the ice now, for World's on-ice events: {"large": n, "mini": m}.
var nets_on_ice: Dictionary:
	get:
		return {"large": int(ops.nets_on[0]), "mini": int(ops.nets_on[1])}

## The building.
var lights_on := false
var lights_warm := 0.0    # 0 cold to 1 full brightness
var auto_lights := true   # sandbox: the lights follow 06:00 to 24:00 by themselves
var snow_pit := 0.0       # 0 empty to 1 full: Doris can't dump
var pit_melt_per_h := 0.25

## Records.
var log_book: Array = []  # [{"day", "minute", "who", "job", "readings": {name: SimInstrument dict}}]
var session_log: Array = []  # [{"day", "org", "start", "hours", "rating", "mid_rating", "cancelled"}]
var flood_log: Array = []    # [{"day", "minute", "crew", "for_org", "ok", "text"}]
var trips: Array = []        # [{"day", "minute", "compressor", "reason"}]
var bills: Array = []        # [{"id", "text", "amount", "due_day", "paid"}]
var goals: Array = []        # [{"id", "text", "done", "failed"}]
var bids: Array = []         # [{"org", "price", "rival", "rival_price", "decide_day", "state", "slots", "reason"}]
var binder: Array = []       # Gus's notes the owner has found
var weekly_reports: Array = []
var cancelled_sessions := 0
var lost_contracts := 0
var compressor_1_decision := ""  # "rebuild", "replace" or "nurse"
var trip_script := {}     # M1: {"compressor", "day", "minute", "done"} the night setback restart
var owner_pay_owed := 0.0 # the Community Ice Agreement's weekly pay, for Mechanics to move into the career's money
var cia_weekly_pay := 0.0

var plant: RefrigerationPlant
var ice: IceSlab
var doris: ResurfacerSim
var _kwh_today := 0.0
var _hours_today := 0.0
var _money_day_start := 0.0
var _session_key := ""
var _ratings_today: Array = []  # ice rating at the start of each session
var _cur_session := {}          # {"key", "mid", "use", "hours", "log"} until the mid sample
var _floods_done: Array = []    # flood minutes handled today
var _last_flood_abs := -100000  # absolute minute of the last flood
var _last_active_abs := -600    # absolute minute the owner last finished something
var _woke_day := 0
var _script: Array = []         # M1 story beats: [{"day", "minute", "text", "kind", "done"}]
var _recovered_kwh := 0.0
var _new_events: Array = []
var _collecting := false


static func create(seed_ := 1) -> RinkSim:
	var s := RinkSim.new()
	s.rng.seed = seed_
	s.plant = RefrigerationPlant.create_old()
	s.ice = IceSlab.new()
	s.doris = ResurfacerSim.create_doris()
	for k in SimInstrument.CATALOG:
		s.tools[k] = 0
	for r in ROOMS:
		s.rooms[r] = Wear.WORN
	s.contracts = {"vbl_d": {"weeks_left": 16, "satisfaction": 55.0},
		"public_skate": {"weeks_left": 52, "satisfaction": 55.0}}
	s._money_day_start = s.money
	return s


## The vertical slice (docs 8, M1): Monday 1 September, Year 1, 05:00.
static func create_m1(seed_ := 1) -> RinkSim:
	var s := RinkSim.create(seed_)
	s.mode = "m1"
	s.start_weekday = 1
	s.start_doy = 243  # 1 September
	s.minute = WAKE_MIN
	s.money = M1_START_CASH
	s._money_day_start = s.money
	s.ice = IceSlab.create_millbrook()
	s.ice_rep = 45.0
	s.rep_window_hours = 16.0  # the summer left little booked ice to remember
	s.auto_resurface = true
	s.auto_lights = false
	s.pit_melt_per_h = 0.012   # the melt pit heater is tired
	s.cia_weekly_pay = CIA_WEEKLY_PAY
	s.inventory = {"spark_plugs": 1}
	s.cleanliness = 0.5
	# Doris won't start: fouled plugs, and the choke stuck half closed
	s.doris.part("spark_plugs").condition = 0.0
	s.doris.choke_stuck = true
	# number 1 drinks: low in the glass, dark oil, a clogged filter
	var c1: Dictionary = s.plant.compressors[0]
	c1.oil = 0.3
	c1.oil_level = 0.3
	c1.drink = 0.001
	(c1.filter as SimPart).condition = 0.15
	s.contracts = {"vbl_d": {"weeks_left": 16, "satisfaction": 55.0},
		"public_skate": {"weeks_left": 52, "satisfaction": 55.0}}
	s.bills = [{"id": "hydro_aug", "amount": M1_ELECTRICITY_BILL, "due_day": 14, "paid": false,
		"text": "Millbrook Hydro, August: 70,000 kWh and a 150 kW demand charge. $11,240, due 15 September."}]
	s.bids = [{"org": "minor_hockey", "price": 0.0, "rival": HARLOW_FALLS.name, "rival_price": HARLOW_FALLS.price,
		"decide_day": 5, "state": "open", "slots": [[0, 8.0, 4.0]], "reason": ""}]
	s.goals = [
		{"id": "keep_bookings", "text": "Keep every booking this week.", "done": false, "failed": false},
		{"id": "ice_under_40", "text": "Get the ice under 40 mm.", "done": false, "failed": false},
		{"id": "compressor_1", "text": "Decide what to do about compressor 1.", "done": false, "failed": false},
		{"id": "minor_hockey_slot", "text": "Win back one Minor Hockey slot.", "done": false, "failed": false},
	]
	s.binder = GUS_NOTES.duplicate(true)
	s.trip_script = {"compressor": 0, "day": 2, "minute": 23 * 60 + 45, "done": false}
	s._woke_day = 0
	s._last_active_abs = -8 * 60
	s._script = [
		{"day": 0, "minute": 300, "kind": "story", "text": "05:00. The parking lot is dark. The keys are in an envelope under the mat: \"WELCOME. DON'T TOUCH BREAKER 14. GUS\""},
		{"day": 0, "minute": 300, "kind": "story", "text": "The plant room door is covered in notes. The top one: \"Every morning. Oil first. Number 1 drinks.\" The log book is open on the desk with a pencil on a string."},
		{"day": 0, "minute": 330, "kind": "story", "text": "The first flood of the day is due at 05:50. Gus's note on Doris's dash: \"If Doris won't start it's the plugs. It's always the plugs. Unless it's the choke.\""},
		{"day": 0, "minute": 345, "kind": "call", "text": "The office phone: Dale Huffman, Valley Beer League. \"So you're the new guy. We're on Tuesdays and Thursdays at ten, same as always. You're on the D roster, by the way. Free till you find your feet.\""},
		{"day": 0, "minute": 350, "kind": "bill", "text": "Last month's electricity bill is on the desk: $11,240. A note from Gus: \"Ice is too thick. Earl likes it thick. Earl doesn't pay the bill.\""},
		{"day": 0, "minute": 355, "kind": "goal", "text": "Four sticky notes on the corkboard: keep every booking; get the ice under 40 mm; decide what to do about compressor 1; win back one Minor Hockey slot."},
		{"day": 0, "minute": 375, "kind": "call", "text": "Donna Pettigrew, Millbrook Minor Hockey: \"Harlow Falls has our Sunday mornings. Give me ice I can put kids on, a reputation of 50, and a fair price, and I'll bring one slot home. Bids close Saturday night.\""},
		{"day": 1, "minute": 21 * 60, "kind": "story", "text": "Your own Beer League game is at 22:00, on your own ice. Flood at 21:30, and again at the second intermission. Someone has to."},
	]
	for b in s._script:
		b["done"] = false
	s._update_goals()
	return s


# ------------------------------------------------------------------ calendar

func weekday() -> int:
	return weekday_of(day)


func weekday_of(d: int) -> int:
	return posmod(d + start_weekday, 7)


## Monday-to-Sunday week number of day `d` (week 0 holds day 0).
func week_of(d: int) -> int:
	return floori(float(d + posmod(start_weekday - 1, 7)) / 7.0)


## The rink year: Year 1 from day 0.
func year() -> int:
	return 1 + day / 365


## {"month" 1..12, "dom" 1..31} of day `d`.
func date_of(d: int) -> Dictionary:
	var doy := posmod(start_doy + d, 365)
	var m := 0
	while doy >= int(MONTH_DAYS[m]):
		doy -= int(MONTH_DAYS[m])
		m += 1
	return {"month": m + 1, "dom": doy + 1}


## "Mon 1 Sep, Year 1".
func date_text(d := -1) -> String:
	var dd := day if d < 0 else d
	var dt := date_of(dd)
	return "%s %d %s, Year %d" % [DAY_NAMES[weekday_of(dd)], int(dt.dom), MONTH_NAMES[int(dt.month) - 1], 1 + dd / 365]


func clock_text() -> String:
	return "%s %02d:%02d" % [date_text(), minute / 60, minute % 60]


## "early" 05:00-07:00 (plant checks), "day" 07:00-17:00 (ice sessions),
## "evening" 17:00-01:00 (games and rentals), "late" 01:00-05:00 (planning).
func block() -> String:
	return block_at(minute)


static func block_at(m: int) -> String:
	var mm := posmod(m, 24 * 60)
	if mm >= 5 * 60 and mm < 7 * 60:
		return "early"
	if mm >= 7 * 60 and mm < 17 * 60:
		return "day"
	if mm >= 17 * 60 or mm < 60:
		return "evening"
	return "late"


## Minutes until the current block ends: advance(minutes_to_block_end()).
func minutes_to_block_end() -> int:
	var ends := [60, 5 * 60, 7 * 60, 17 * 60, 25 * 60]
	for e in ends:
		if int(e) > minute:
			return int(e) - minute
	return 25 * 60 - minute


## Minutes since the ice was last flooded, by anyone.
func minutes_since_flood() -> int:
	return _abs_minute() - _last_flood_abs


func _abs_minute() -> int:
	return day * 24 * 60 + minute


# ------------------------------------------------------------------ schedule

## The bookings on day `d`, by start time: [{"org", "use", "start", "hours"}],
## with the owner's schedule changes (RinkSchedule: one-off sales, moved and
## cancelled slots; those add "key", "kind" and "sale").
func sessions(d: int) -> Array:
	return schedule.bookings(self, d)


## The contracts' own weekly slots on day `d`, before any schedule changes.
func contract_sessions(d: int) -> Array:
	var wd := weekday_of(d)
	var out: Array = []
	for id in contracts:
		var c: Dictionary = contracts[id]
		if int(c.get("start_day", -99999)) > d:
			continue
		var o := RinkContracts.org(id)
		for s in c.get("slots", o.get("slots", [])):
			if int(s[0]) == wd:
				var e := {"org": id, "use": o.use, "start": float(s[1]), "hours": float(s[2])}
				if id == "vbl_d" and wd == owner_game_weekday:
					e["owner_plays"] = true
				out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.start) < float(b.start))
	return out


## The session on the ice at this minute, or {} if the ice is free.
func session_now() -> Dictionary:
	return session_at(minute)


## The session at minute `m` of today (past midnight wraps to tomorrow).
func session_at(m: int) -> Dictionary:
	var d := day + floori(float(m) / (24.0 * 60.0))
	var h := posmod(m, 24 * 60) / 60.0
	for s in sessions(d):
		if h >= float(s.start) and h < float(s.start) + float(s.hours):
			var out: Dictionary = s.duplicate()
			out.erase("owner_plays")
			return out
	return {}


## Who floods at minute `m` of day `d`: "you", "Earl", or "" when nobody can
## (the night block, an overslept morning, an owner out of hours).
func flood_crew(d: int, m: int) -> String:
	var b := block_at(m)
	if earl_hired and (b == "evening" or weekday_of(d) == 0 or weekday_of(d) == 6):
		return "Earl"
	if b == "late":
		return ""
	if d == day:
		if overslept_day == day and m < 7 * 60:
			return ""
		if m >= minute and hours_left < float(JOBS.resurface.hours) - 0.001:
			return ""
	return "you"


## The scheduled floods on day `d`: [{"minute", "crew", "for_org", "kind"}].
## A flood before every booking, the morning flood, and a second-intermission
## flood inside every two-hour game slot (the owner's Tuesday game included).
func floods(d: int) -> Array:
	var raw: Array = []
	for s in sessions(d):
		var m0 := int(round(float(s.start) * 60.0))
		if m0 - RESURFACE_LEAD_MIN >= 0:
			raw.append({"minute": m0 - RESURFACE_LEAD_MIN, "for_org": s.org, "kind": "before"})
		if s.use == "hockey" and float(s.hours) >= 2.0 and float(s.hours) <= 3.0:
			raw.append({"minute": m0 + INTERMISSION_MIN, "for_org": s.org, "kind": "intermission"})
		elif s.use == "hockey" and float(s.hours) > 3.0:
			for k in range(1, int(ceil(float(s.hours)))):
				raw.append({"minute": m0 + 60 * k, "for_org": s.org, "kind": "between"})  # a flood after every hour
	if morning_flood:
		var near := false
		for f in raw:
			if absi(int(f.minute) - MORNING_FLOOD_MIN) < 45:
				near = true
		if not near:
			raw.append({"minute": MORNING_FLOOD_MIN, "for_org": "", "kind": "morning"})
	raw.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.minute) < int(b.minute))
	var out: Array = []
	for f in raw:
		if not out.is_empty() and int(f.minute) - int(out[-1].minute) < 15:
			continue
		f["crew"] = flood_crew(d, int(f.minute))
		out.append(f)
	return out


## The weekly grid from day `from_day` (the current week's Monday by default):
## [{"day", "date", "sessions", "floods"}] for seven days.
func week_grid(from_day := -1) -> Array:
	var start := from_day
	if start < 0:
		start = day - posmod(weekday() - 1, 7)
	var out: Array = []
	for i in 7:
		var d := start + i
		out.append({"day": d, "date": date_text(d), "sessions": sessions(d), "floods": floods(d)})
	return out


## 0..100 from the rooms' renovation ages and how clean they are.
func facility_score() -> float:
	var t := 0.0
	for r in ROOMS:
		t += float(rooms.get(r, 0)) * 50.0
	return t / ROOMS.size() * (0.55 + 0.45 * cleanliness) + 12.0 * cleanliness


func offers() -> Array:
	return RinkContracts.offers(ice_rep, facility_score(), contracts.keys())


func sign(org_id: String) -> bool:
	for o in offers():
		if o.id == org_id:
			contracts[org_id] = {"weeks_left": int(o.weeks), "satisfaction": 60.0}
			_note("Signed %s." % o.name, "contract")
			return true
	return false


# ------------------------------------------------------------------ bids

## How an organisation scores an offer (docs 5.2): price, slot fit, ice,
## facility and distance, by its weights. 0..1.
static func bid_score(price: float, slot_fit: float, ice: float, facility: float, distance: float) -> float:
	var ps := clampf((BID_BUDGET.y - price) / (BID_BUDGET.y - BID_BUDGET.x), 0.0, 1.0)
	return BID_WEIGHTS.price * ps + BID_WEIGHTS.slot_fit * slot_fit + BID_WEIGHTS.ice * ice / 100.0 \
		+ BID_WEIGHTS.facility * facility / 100.0 + BID_WEIGHTS.distance * distance


## What a bid at `price` would score today against the rival:
## {"score", "rival_score", "ice_ok", "min_ice", "would_win"}.
func bid_preview(org: String, price: float) -> Dictionary:
	var o := RinkContracts.org(org)
	var b := _bid(org)
	var rival_price: float = b.get("rival_price", HARLOW_FALLS.price)
	var mine := bid_score(price, 1.0, ice_rep, facility_score(), 1.0)
	var rival := bid_score(rival_price, HARLOW_FALLS.slot_fit, HARLOW_FALLS.ice, HARLOW_FALLS.facility, HARLOW_FALLS.distance)
	var ok := ice_rep >= float(o.get("min_ice", 0.0))
	return {"score": mine, "rival_score": rival, "ice_ok": ok, "min_ice": float(o.get("min_ice", 0.0)), "would_win": ok and mine > rival}


func _bid(org: String) -> Dictionary:
	for b in bids:
		if b.org == org:
			return b
	return {}


## Prepares and sends a bid (1 owner hour). Can be revised until the decide
## day ends. Returns false if there is no open request or no time.
func submit_bid(org: String, price: float) -> bool:
	var b := _bid(org)
	if b.is_empty() or not str(b.state) in ["open", "submitted"] or day > int(b.decide_day) or price <= 0.0:
		return false
	_maybe_wake()
	if hours_left < BID_HOURS - 0.001:
		return false
	_charge_hours(BID_HOURS)
	b.price = price
	b.state = "submitted"
	_note("Sent %s a bid at $%.0f an hour." % [RinkContracts.org(org).name, price], "bid")
	return true


func _decide_bids() -> void:
	for b in bids:
		if int(b.decide_day) != day or not str(b.state) in ["open", "submitted"]:
			continue
		var o := RinkContracts.org(b.org)
		if b.state == "open":
			b.state = "lost"
			b.reason = "No bid from Millbrook."
		else:
			var p := bid_preview(b.org, float(b.price))
			if not p.ice_ok:
				b.state = "lost"
				b.reason = "The ice reputation is %.0f; they need %.0f." % [ice_rep, p.min_ice]
			elif p.would_win:
				b.state = "won"
				b.reason = "Millbrook scored %.2f to %s's %.2f." % [p.score, b.rival, p.rival_score]
				contracts[b.org] = {"weeks_left": int(o.get("weeks", 24)), "satisfaction": 60.0,
					"slots": (b.slots as Array).duplicate(true), "rate": float(b.price), "start_day": day + 1}
			else:
				b.state = "lost"
				b.reason = "%s scored %.2f to Millbrook's %.2f." % [b.rival, p.rival_score, p.score]
		var who: String = "Donna Pettigrew" if b.org == "minor_hockey" else str(o.get("name", b.org))
		if b.state == "won":
			_note("%s: \"You've got Sunday mornings. Don't make me regret it.\" (%s)" % [who, b.reason], "bid")
		else:
			_note("%s: \"We're staying with %s.\" (%s)" % [who, b.rival, b.reason], "bid")
	_update_goals()


# ------------------------------------------------------------------ time

## Advances the sim by `minutes`, in 15-minute steps. Returns the events
## noted on the way. With advance_days, the only way the clock moves.
func advance(minutes: int) -> Array:
	var outer := _collecting
	if not outer:
		_new_events = []
		_collecting = true
	var steps := maxi(1, minutes / STEP_MIN)
	for i in steps:
		_step()
	if outer:
		return []
	_collecting = false
	var out := _new_events
	_new_events = []
	return out


func advance_days(n: int) -> Array:
	return advance(n * 24 * 60)


func _step() -> void:
	var h := STEP_MIN / 60.0
	_maybe_wake()
	_run_script()
	if not trip_script.is_empty() and not bool(trip_script.done) and day == int(trip_script.day) and minute == int(trip_script.minute):
		_night_restart()
	var s := session_now()
	var key := "%d/%s/%s" % [day, s.get("org", ""), s.get("start", "")]
	if not s.is_empty() and key != _session_key:
		_session_key = key
		_start_session(s)
	_mid_sample()
	if auto_resurface:
		_auto_floods()
	_run_work_orders()
	var use: String = s.get("use", "hockey")
	var skaters := 0.0
	if not s.is_empty() and evacuated_day != day and not ice_closed(day):
		skaters = 20.0 if use == "hockey" else 30.0
	# the controller chases the target for whatever skates next, or idles warmer overnight
	var target: float = IceSlab.TARGET_TEMP.get(use, -5.0)
	if s.is_empty() and (minute < 5 * 60 or minute >= 23 * 60 + 30):
		target += 1.0
	var duty := clampf(0.5 + (ice.surface_temp - target) * 0.8, 0.0, 1.0)
	var was_tripped: Array = []
	for c in plant.compressors:
		was_tripped.append(bool(c.tripped))
	var cooling := plant.run(h, duty, rng)
	for i in plant.compressors.size():
		if bool(plant.compressors[i].tripped) and not bool(was_tripped[i]):
			_record_trip(i)
	_plant_consequences(h)
	var air := _air_temp()
	if auto_lights:
		lights_on = minute >= 6 * 60 and minute < 24 * 60
	if lights_on:
		lights_warm = minf(lights_warm + STEP_MIN / LIGHTS_WARM_MIN, 1.0)
	else:
		lights_warm = 0.0
	var lights := BASE_KW + LIGHTS_KW * lights_warm
	var load := 4.2 * (air - ice.surface_temp) + lights + skaters * 0.35 + 40.0
	ice.run(h, load, cooling, skaters * h)
	_kwh_today += (plant.last_power_kw + lights + 25.0) * h
	cleanliness = clampf(cleanliness - skaters * h * 0.0008, 0.0, 1.0)
	snow_pit = maxf(snow_pit - pit_melt_per_h * h, 0.0)
	_update_goals()
	minute += STEP_MIN
	if minute >= 24 * 60:
		_end_day()


func _maybe_wake() -> void:
	if minute >= WAKE_MIN and _woke_day != day:
		_wake()


## 05:00: the alarm. Sleep and days off take fatigue down, short nights put
## it up (docs 2.1), and the owner's hours start again.
func _wake() -> void:
	_woke_day = day
	var slept := clampf(float(_abs_minute() - _last_active_abs) / 60.0, 0.0, 9.0)
	if hours_worked <= 0.001:
		fatigue -= 40.0
	elif slept >= 6.0:
		fatigue -= 25.0
	else:
		fatigue += 10.0 * (6.0 - slept)
	fatigue = clampf(fatigue, 0.0, 100.0)
	hours_worked = 0.0
	hours_left = OWNER_HOURS + OVERTIME_MAX
	if fatigue >= 90.0:
		overslept_day = day
		hours_left -= 2.0
		fatigue = maxf(fatigue - 15.0, 0.0)
		_last_active_abs = _abs_minute() + 120
		_note("You slept through the alarm. It's 07:00. Gus's binder: \"If you sleep through the alarm, the ice doesn't. Set two.\"", "fatigue")


func _run_script() -> void:
	for b in _script:
		if not bool(b.done) and int(b.day) == day and int(b.minute) <= minute:
			b.done = true
			_note(str(b.text), str(b.kind))
	if mode == "m1" and day == 0 and minute == 6 * 60:
		var feel := "It is like skating on a parking lot." if ice.surface_temp < -4.5 else "Hmm. Softer than Harlow Falls. Good."
		_note("Hélène Arsenault of the figure club comes in for a look, feels the ice with a blade and frowns: \"%s\"" % feel, "story")


## M1: the night setback cycles the compressors; on the restart number 1's oil
## pump has to build pressure or the safety trips it.
func _night_restart() -> void:
	trip_script.done = true
	var i := int(trip_script.compressor)
	if plant.restart_check(i):
		_record_trip(i)


func _record_trip(i: int) -> void:
	var c: Dictionary = plant.compressors[i]
	var reason := str(c.get("trip_reason", ""))
	trips.append({"day": day, "minute": minute, "compressor": i, "reason": reason})
	_note("Compressor %d tripped%s at %02d:%02d. Nobody's here to hear it." % [i + 1, (" on " + reason) if reason != "" else "", minute / 60, minute % 60]
		if block() == "late" or block() == "evening" else "Compressor %d tripped%s." % [i + 1, (" on " + reason) if reason != "" else ""], "trip")


func _auto_floods() -> void:
	for f in floods(day):
		var m := int(f.minute)
		if m < minute or m >= minute + STEP_MIN or m in _floods_done:
			continue
		_floods_done.append(m)
		var entry := {"day": day, "minute": m, "crew": f.crew, "for_org": f.for_org, "kind": f.kind, "ok": false, "text": ""}
		if ice_closed(day):
			entry.ok = true
			entry.text = "The ice is closed: a depth plate is freezing in."
		elif _abs_minute() - _last_flood_abs < 30:
			entry.ok = true
			entry.text = "Already flooded."
		elif str(f.crew) == "":
			entry.text = "Nobody to flood."
			if f.for_org != "":
				_note("Nobody flooded before %s." % RinkContracts.org(f.for_org).get("name", f.for_org), "flood")
		elif owner_waits() and str(f.crew) == "you":
			entry.text = "Waiting for you to drive Doris."
			entry["waiting"] = true
			floods_waiting.append({"day": day, "minute": m, "for_org": f.for_org, "kind": f.kind})
			if floods_waiting.size() > 20:
				floods_waiting = floods_waiting.slice(floods_waiting.size() - 20)
			_note("%02d:%02d: the flood%s is due. Doris is in the bay." % [m / 60, m % 60,
				(" before %s" % RinkContracts.org(f.for_org).get("name", f.for_org)) if f.for_org != "" else ""], "flood")
		else:
			var r := job("resurface")
			entry.ok = bool(r.ok)
			entry.text = str(r.text)
			if r.ok:
				entry["smooth_after"] = ice.felt_smoothness()
			if not r.ok:
				_note("The %02d:%02d flood didn't happen: %s" % [m / 60, m % 60, r.text], "flood")
			elif f.kind == "intermission" and f.get("for_org", "") == "vbl_d" and weekday() == owner_game_weekday and mode == "m1":
				_note("Second intermission: you flood your own game in full gear, skates and all. The bench chirps you the whole way round.", "story")
		flood_log.append(entry)
		if flood_log.size() > 300:
			flood_log = flood_log.slice(flood_log.size() - 300)


## Staff do the jobs handed to them on the calendar (WorkOrders) when their
## time comes; each order keeps how it went. Orders older than a week drop off.
func _run_work_orders() -> void:
	for o: Dictionary in work_orders:
		if o.has("ok") or int(o.day) != day or int(o.minute) >= minute + STEP_MIN or int(o.minute) < minute:
			continue
		var args: Dictionary = o.get("args", {}).duplicate()
		args["by"] = str(o.by)
		var r := job(str(o.id), args)
		o["ok"] = bool(r.ok)
		o["text"] = str(r.text)
		if not r.ok:
			_note("%s couldn't do the %s: %s" % [o.by, str(o.id).replace("_", " "), r.text], "job")
	work_orders = work_orders.filter(func(o: Dictionary) -> bool: return int(o.day) >= day - 7)


func _start_session(s: Dictionary) -> void:
	# a one-off sale (RinkSchedule) has no contract: its rate and crowd ride on the booking
	var sale := bool(s.get("sale", false))
	var o: Dictionary = {"name": s.get("name", "a one-off booking"), "rate": s.get("rate", 0.0)} if sale else RinkContracts.org(s.org)
	if sale and float(s.get("per_head", 0.0)) > 0.0:
		o["per_head"] = float(s.per_head)
		o["heads"] = float(s.heads)
	var c: Dictionary = contracts[s.org] if contracts.has(s.org) else {"satisfaction": 60.0}
	var entry := {"day": day, "org": s.org, "start": s.start, "hours": s.hours, "rating": -1.0, "mid_rating": -1.0, "cancelled": false}
	session_log.append(entry)
	if session_log.size() > 300:
		session_log = session_log.slice(session_log.size() - 300)
	if evacuated_day == day:
		entry.cancelled = true
		cancelled_sessions += 1
		_cur_session = {}
		book("refunds", -50.0)
		c.satisfaction = maxf(float(c.satisfaction) - 10.0, 0.0)
		_note("%s sent home: the building is closed after the ammonia release." % o.name, "session")
		session_started.emit(s, -1.0, 0.0)
		return
	if ice_closed(day):
		entry.cancelled = true
		cancelled_sessions += 1
		_cur_session = {}
		c.satisfaction = maxf(float(c.satisfaction) - 3.0, 0.0)
		_note("%s booked elsewhere today: the ice is closed while a depth plate freezes in." % o.name, "session")
		session_started.emit(s, -1.0, 0.0)
		return
	if not lights_on:
		lights_on = true
		c.satisfaction = maxf(float(c.satisfaction) - 4.0, 0.0)
		_note("%s found the building dark and flipped the breakers themselves. The lamps take fifteen minutes to come up." % o.name, "session")
	var rating := ice.rating(s.use)
	entry.rating = rating
	_ratings_today.append(rating)
	var wet := ice.wetness()
	if wet > 0.25:
		# the flood hasn't frozen in: hockey stands at the gate and glares
		var grumble := 8.0 * wet * float(IceSlab.WET_PENALTY.get(s.use, 0.3)) / 0.6
		c.satisfaction = maxf(float(c.satisfaction) - grumble, 0.0)
		_note("%s waited at the gate for the ice to dry." % o.name, "session")
	if rating < 25.0:
		entry.cancelled = true
		cancelled_sessions += 1
		_cur_session = {}
		c.satisfaction = maxf(float(c.satisfaction) - 15.0, 0.0)
		ice_rep = maxf(ice_rep - 4.0, 0.0)
		book("refunds", -50.0)
		_note("Cancelled %s: the ice is unplayable (%.0f)." % [o.name, rating], "session")
		session_started.emit(s, -1.0, wet)
		return
	c.satisfaction = lerpf(float(c.satisfaction), rating, 0.2)
	_session_ops(s, c)
	_rep_sample(rating, float(s.hours) * 0.5)
	_cur_session = {"key": _session_key, "mid": minute + int(float(s.hours) * 30.0), "use": s.use, "hours": float(s.hours), "log": session_log.size() - 1}
	var rate := float(c.get("rate", o.get("rate", 0.0)))
	if rate > 0.0:
		book("ice rental", rate * float(s.hours))
	if o.has("per_head"):
		var heads := float(o.heads) * clampf(rating / 70.0, 0.3, 1.3)
		book("public skate", float(o.per_head) * heads)
		book("skate rental", heads * 0.25 * 5.0)
		book("concessions (net)", heads * 2.5 * 0.5)
	elif s.use == "hockey":
		book("concessions (net)", 20.0 * 4.0 * 0.5)
	session_started.emit(s, rating, wet)


## The board, the nets and the scorekeeper as the session starts (RinkOps).
func _session_ops(s: Dictionary, c: Dictionary) -> void:
	var r := ops.on_session_start(s, day)
	c.satisfaction = maxf(float(c.satisfaction) - float(r.satisfaction), 0.0)
	if float(r.hours) > 0.0:
		_charge_hours(float(r.hours))
	if float(r.cost) > 0.0:
		book("scorekeeper", -float(r.cost))
	for t in r.notes:
		_note(t, "session")


## The middle-of-session sample for the ice reputation (docs 3.2).
func _mid_sample() -> void:
	if _cur_session.is_empty() or minute < int(_cur_session.mid):
		return
	var r := ice.rating(str(_cur_session.use))
	var i := int(_cur_session.log)
	if i >= 0 and i < session_log.size():
		session_log[i].mid_rating = r
	_rep_sample(r, float(_cur_session.hours) * 0.5)
	_cur_session = {}


## The reputation is a rolling average of true session ratings, weighted by
## hours: a sample of `hours` moves it hours / rep_window_hours of the way.
func _rep_sample(rating: float, hours: float) -> void:
	ice_rep = lerpf(ice_rep, rating, clampf(hours / rep_window_hours, 0.0, 1.0))


## Leaks, releases and recovered heat from the last plant step.
func _plant_consequences(h: float) -> void:
	_recovered_kwh += plant.last_recovered_kw * h
	if plant.last_leak_kg > 0.0 and year() >= 4:
		var tax: float = PlantCatalog.refrigerant(plant.refrigerant).gwp_tax
		if tax > 0.0:
			book("refrigerant levy", -plant.last_leak_kg * tax)
	if plant.last_release and evacuated_day != day:
		evacuated_day = day
		ice_rep = maxf(ice_rep - 6.0, 0.0)
		book("fines", -RELEASE_FINE)
		_note("Ammonia release at the compressor seal. Everyone out; the fire department and the inspector are on their way.", "alarm")


func _end_day() -> void:
	_plates_frozen(day)
	book("electricity", -_kwh_today * POWER_PRICE)
	if _recovered_kwh > 0.0:
		book("heat recovered", _recovered_kwh * HEAT_RECOVERY_PRICE)
		_recovered_kwh = 0.0
	_daily_logistics()
	for k in FIXED_LINES:
		book(k, -float(FIXED_LINES[k]))
	_decide_bids()
	for b in bills:
		if not bool(b.paid) and int(b.due_day) == day:
			_note("Overdue: %s" % b.text, "bill")
	var rev := 0.0
	var cost := 0.0
	for k in ledger:
		if ledger[k] > 0:
			rev += ledger[k]
		else:
			cost -= ledger[k]
	var avg := -1.0
	if not _ratings_today.is_empty():
		avg = 0.0
		for r in _ratings_today:
			avg += r
		avg /= _ratings_today.size()
	books.append({"day": day, "revenue": rev, "costs": cost, "kwh": _kwh_today, "ice": avg,
		"ledger": ledger.duplicate(), "money_start": _money_day_start, "money_end": money, "hours": _hours_today})
	ledger = {}
	_ratings_today = []
	_kwh_today = 0.0
	_hours_today = 0.0
	_floods_done = []
	day_ended.emit(day)
	minute = 0
	day += 1
	_money_day_start = money
	if posmod(day, 365) == 300:
		book("inspection", -float(PlantCatalog.refrigerant(plant.refrigerant).inspection))
		_note("The yearly %s inspection." % PlantCatalog.refrigerant(plant.refrigerant).name)
	if weekday() == 1:
		_end_week()


## Deliveries, installs finishing, the rental chiller's bill, league dues.
func _daily_logistics() -> void:
	for o in orders.duplicate():
		if day >= int(o.arrives_day):
			orders.erase(o)
			delivered.append(o.model)
			book("equipment", -float(o.balance))
			_note("The %s is on a flatbed in the parking lot. Balance paid: $%.0f." % [PlantCatalog.compressor(o.model).name, o.balance], "delivery")
	for i in installs.duplicate():
		if day >= int(i.done_day):
			installs.erase(i)
			plant.install_compressor(int(i.compressor), str(i.model), float(i.quality))
			_note("Compressor %d is running again: a %s." % [int(i.compressor) + 1, PlantCatalog.compressor(i.model).name])
	if not conversion.is_empty() and day >= int(conversion.done_day):
		plant.refrigerant = str(conversion.to)
		plant.charge = 1.0
		for c in plant.compressors:
			c.out = false
		_note("The plant is back up on %s." % PlantCatalog.refrigerant(conversion.to).name)
		conversion = {}
	if rental_until >= 0:
		book("chiller rental", -PlantCatalog.RENTAL_CHILLER_DAY)
		if day >= rental_until:
			rental_until = -1
			plant.rental_kw = 0.0
			_note("The rental chiller went back on its trailer.")
	_league_dues()


func _league_dues() -> void:
	if day == int(league.free_until) and int(league.paid_through) < day:
		league.owed = LEAGUE_DUES
		league.due_day = day + LEAGUE_GRACE_DAYS
		_note("Dale Huffman, Valley Beer League: \"Love what you've done with the place. But owner or not, everybody pays their dues: $%.0f gets the refs, the scorekeeper, the pucks and the jerseys. By the %s.\"" % [LEAGUE_DUES, "end of next week"], "call")
	elif float(league.owed) > 0.0 and day >= int(league.due_day) and not league.benched:
		league.benched = true
		_note("Dale Huffman: \"No dues, no game. Your sweater's in my trunk when you're ready.\"", "call")


## Pays the owner's Beer League dues. Returns false if nothing is owed.
func pay_dues() -> bool:
	if float(league.owed) <= 0.0:
		return false
	book("league dues", -float(league.owed))
	league.owed = 0.0
	league.benched = false
	league.paid_through = day + 365
	_note("Dues paid. Dale hands back the sweater.")
	return true


## Can the owner play their own Beer League game today?
func owner_can_play() -> bool:
	return not bool(league.benched)


## The owner played their own game: 3 owner hours (warm-up, the game, the
## beer), recorded, and tiring. False if Dale has the sweater.
func owner_played_game(minutes: int) -> bool:
	if not owner_can_play():
		return false
	_maybe_wake()
	_charge_hours(GAME_HOURS)
	fatigue = clampf(fatigue + 6.0, 0.0, 100.0)
	_last_active_abs = maxi(_last_active_abs, _abs_minute() + 60)
	games.append({"day": day, "minute": minute, "minutes": minutes})
	_note("You played %d minutes of Beer League hockey on your own ice." % minutes, "game")
	return true


## The owner spent `minutes` working out (the weight room, a pickup game):
## owner hours, plus `effort` fatigue on top of any overtime.
func owner_trained(minutes: int, effort: float) -> void:
	_maybe_wake()
	_charge_hours(minutes / 60.0)
	fatigue = clampf(fatigue + effort, 0.0, 100.0)


func _end_week() -> void:
	var w := week_of(day - 1)
	for id in contracts.keys():
		var c: Dictionary = contracts[id]
		c.weeks_left = int(c.weeks_left) - 1
		var o := RinkContracts.org(id)
		if float(c.satisfaction) < 35.0:
			contracts.erase(id)
			lost_contracts += 1
			_note("%s took their ice elsewhere." % o.name, "contract")
		elif int(c.weeks_left) <= 0:
			if ice_rep >= float(o.min_ice) and float(c.satisfaction) >= 50.0:
				c.weeks_left = int(o.weeks)
				_note("%s renewed." % o.name, "contract")
			else:
				contracts.erase(id)
				lost_contracts += 1
				_note("%s didn't renew." % o.name, "contract")
	if cia_weekly_pay > 0.0:
		owner_pay_owed += cia_weekly_pay
		_note("The town's transition fund pays you $%.0f for the week (the Community Ice Agreement)." % cia_weekly_pay, "money")
	var pnl := week_pnl(w)
	var t := 0.0
	var n := 0
	var hrs := 0.0
	for b in books:
		if week_of(int(b.day)) == w:
			hrs += float(b.get("hours", 0.0))
			if float(b.ice) >= 0.0:
				t += float(b.ice)
				n += 1
	weekly_reports.append({"week": w, "pnl": pnl, "ice": t / maxf(n, 1.0), "ice_rep": ice_rep, "hours": hrs, "cancelled": cancelled_sessions})
	if w == 0:
		_finish_week_goals()
	_note("The weekly report: revenue $%.0f, costs $%.0f, net $%.0f; ice reputation %.0f." % [pnl.total_revenue, pnl.total_costs, pnl.net, ice_rep], "report")


## Takes the Community Ice Agreement pay owed to the owner (for the career's money).
func take_owner_pay() -> float:
	var p := owner_pay_owed
	owner_pay_owed = 0.0
	return p


## Air temperature in the bowl: an old building with no dehumidifier.
func _air_temp() -> float:
	var season := cos(TAU * posmod(start_doy + day - 7, 365) / 365.0)  # coldest in early January
	return 9.0 - 4.0 * season


# ------------------------------------------------------------------ the compressor problem

## What a compressor package costs and how long it takes. See PlantCatalog.
func quote_compressor(model: String) -> Dictionary:
	var m := PlantCatalog.compressor(model)
	return {"model": model, "name": m.name, "price": m.price, "deposit": float(m.price) * 0.3,
		"contractor": m.contractor, "lead_weeks": m.lead_weeks, "install_days": m.install_days,
		"refrigerants": m.refrigerants, "pitch": m.pitch}


## Orders a compressor: 30% deposit now, the balance on delivery.
func order_compressor(model: String) -> bool:
	var q := quote_compressor(model)
	if float(q.price) <= 0.0 or money < float(q.deposit):
		return false
	book("equipment", -float(q.deposit))
	var lead := int(q.lead_weeks) * 7 + rng.randi_range(0, int(q.lead_weeks))  # freight is always late
	orders.append({"model": model, "arrives_day": day + lead, "balance": float(q.price) - float(q.deposit)})
	_note("Ordered a %s. The rep says %d weeks." % [q.name, q.lead_weeks], "order")
	if compressor_1_decision == "":
		decide_compressor_1("replace")
	return true


## The week's goal: "rebuild" (a valve job), "replace" (order a new one) or
## "nurse" (keep it going on oil and attention). False for anything else.
func decide_compressor_1(choice: String) -> bool:
	if not choice in ["rebuild", "replace", "nurse"]:
		return false
	compressor_1_decision = choice
	_note("Compressor 1: you've decided to %s it." % choice, "decision")
	_update_goals()
	return true


## Brings in a portable chiller for `days` (delivery plus a day rate).
func rent_chiller(days: int) -> void:
	if rental_until < 0:
		book("chiller rental", -PlantCatalog.RENTAL_CHILLER_DELIVERY)
	rental_until = maxi(rental_until, day + days)
	plant.rental_kw = PlantCatalog.RENTAL_CHILLER_KW
	_note("A rental chiller is humming in the parking lot until day %d." % rental_until)


## Year-dependent refill price per kg for the current refrigerant, -1 if banned.
func refill_price() -> float:
	return PlantCatalog.refill_price(plant.refrigerant, year())


# ------------------------------------------------------------------ the building

## The breakers by the bay door (not 14). The old metal halides take about a
## quarter of an hour to come up, cost power and put heat on the ice.
func set_lights(on: bool) -> void:
	if on == lights_on:
		return
	lights_on = on
	auto_lights = false
	if not on:
		lights_warm = 0.0
	_note("Lights %s." % ("on: the metal halides hum and start to glow" if on else "off"), "building")


# ------------------------------------------------------------------ money

## Books `dollars` (negative is spending) to a P&L line and the cash.
func book(category: String, dollars: float) -> void:
	ledger[category] = float(ledger.get(category, 0.0)) + dollars
	money += dollars


func _book(category: String, dollars: float) -> void:
	book(category, dollars)


## Pays a bill on the desk. False if it's paid already, unknown, or the cash
## isn't there.
func pay_bill(id: String) -> bool:
	for b in bills:
		if b.id == id:
			if bool(b.paid) or money < float(b.amount):
				return false
			book("electricity (last month)" if str(id).begins_with("hydro") else "bills", -float(b.amount))
			b.paid = true
			_note("Paid: %s" % b.text, "bill")
			return true
	return false


## The P&L for Monday-to-Sunday week `w` (the current week when -1):
## {"week", "from_day", "to_day", "revenue": {line: $}, "costs": {line: $},
## "total_revenue", "total_costs", "net", "money_start", "money_end"}.
## The lines add up to money_end - money_start.
func week_pnl(w := -1) -> Dictionary:
	var wk := week_of(day) if w < 0 else w
	var lines := {}
	var first := -1
	var last := -1
	var m0 := money
	var m1 := money
	var have := false
	for b in books:
		if week_of(int(b.day)) != wk:
			continue
		if not have:
			m0 = float(b.get("money_start", 0.0))
			have = true
		m1 = float(b.get("money_end", 0.0))
		first = int(b.day) if first < 0 else first
		last = int(b.day)
		for k in b.ledger:
			lines[k] = float(lines.get(k, 0.0)) + float(b.ledger[k])
	if week_of(day) == wk:
		if not have:
			m0 = _money_day_start
			first = day
		m1 = money
		last = day
		for k in ledger:
			lines[k] = float(lines.get(k, 0.0)) + float(ledger[k])
	var rev := {}
	var cost := {}
	var tr := 0.0
	var tc := 0.0
	for k in lines:
		var v: float = lines[k]
		if v >= 0.0:
			rev[k] = v
			tr += v
		else:
			cost[k] = -v
			tc -= v
	return {"week": wk, "from_day": first, "to_day": last, "revenue": rev, "costs": cost,
		"total_revenue": tr, "total_costs": tc, "net": tr - tc, "money_start": m0, "money_end": m1}


# ------------------------------------------------------------------ hours and fatigue

## Charges `h` owner hours: overtime past 14 hours and desk work in the night
## block add fatigue (docs 2.1).
func _charge_hours(h: float) -> void:
	var before := hours_worked
	hours_worked += h
	_hours_today += h
	hours_left = maxf(hours_left - h, 0.0)
	var ot := maxf(hours_worked - OWNER_HOURS, 0.0) - maxf(before - OWNER_HOURS, 0.0)
	fatigue += 5.0 * ot
	if block() == "late":
		fatigue += 3.0 * h
	fatigue = clampf(fatigue, 0.0, 100.0)
	_last_active_abs = maxi(_last_active_abs, _abs_minute() + int(h * 60.0))


## Hours left before overtime starts.
func normal_hours_left() -> float:
	return maxf(OWNER_HOURS - hours_worked, 0.0)


## Instruments read by a tired owner carry more error.
func _sigma_mult() -> float:
	return 1.25 if fatigue >= 40.0 else 1.0


## The quality the owner brings to a job: the mini game's, or their skill,
## less for a tired owner (tolerances shrink at 40, mistakes from 70).
func _job_quality(args: Dictionary) -> float:
	var q: float = float(args.get("quality", clampf(skill.mechanic + 0.3, 0.0, 1.0)))
	if fatigue >= 40.0:
		q *= 0.92
	if fatigue >= 70.0 and rng.randf() < 0.25:
		q *= 0.75
		_note("Tired hands: a bolt rolls under the bench and you finish without it.", "fatigue")
	return clampf(q, 0.0, 1.0)


# ------------------------------------------------------------------ jobs

## Hours, parts cost and the P&L line each job charges.
const JOBS := {
	"resurface": {"hours": 0.35, "cost": FLOOD_GAS, "cat": "natural gas"},
	"plant_round": {"hours": 0.5, "cost": 0.0},
	"ice_check": {"hours": 0.2, "cost": 0.0},
	"reset_compressor": {"hours": 0.25, "cost": 0.0},
	"compressor_oil_change": {"hours": 2.5, "cost": 250.0, "cat": "plant parts"},
	"compressor_oil_top_up": {"hours": 0.25, "cost": 25.0, "cat": "plant parts"},
	"compressor_valve_job": {"hours": 6.0, "cost": 340.0, "cat": "plant parts"},
	"descale_condenser": {"hours": 4.0, "cost": 120.0, "cat": "plant parts"},
	"replace_fan_belt": {"hours": 0.75, "cost": 45.0, "cat": "plant parts"},
	"glycol_top_up": {"hours": 1.0, "cost": 0.0, "cat": "glycol"},
	"pump_bearing": {"hours": 4.0, "cost": 190.0, "cat": "plant parts"},
	"blade_change": {"hours": 1.0, "cost": 160.0, "cat": "Doris parts"},
	"doris_plugs": {"hours": 0.4, "cost": 28.0, "cat": "Doris parts"},
	# World: through her service hatch, in place (DorisCarb, DorisOil)
	"doris_carb": {"hours": 0.75, "cost": 9.0, "cat": "Doris parts"},
	"doris_oil_change": {"hours": 0.5, "cost": 46.0, "cat": "Doris parts"},
	"engine_tune": {"hours": 1.5, "cost": 70.0, "cat": "Doris parts"},
	"towel_change": {"hours": 0.5, "cost": 85.0, "cat": "Doris parts"},
	"shave_ice": {"hours": 0.5, "cost": 2.0, "cat": "gasoline"},
	"edge_ice": {"hours": 1.5, "cost": 2.0, "cat": "gasoline"},
	"dump_snow": {"hours": 0.25, "cost": 0.0},
	"clean_building": {"hours": 2.0, "cost": 15.0, "cat": "parts and supplies"},
	"refuel_doris": {"hours": 0.25, "cost": 45.0, "cat": "gasoline"},
	"install_compressor": {"hours": 4.0, "cost": 0.0, "cat": "equipment"},  # the contractor does the rest
	"convert_refrigerant": {"hours": 6.0, "cost": 0.0, "cat": "equipment"},
	"recharge_refrigerant": {"hours": 1.0, "cost": 0.0, "cat": "refrigerant"},
	# the ice jobs (docs/world/ICE.md)
	"install_plate": {"hours": 2.0, "cost": 65.0, "cat": "parts and supplies"},
	"ice_depth": {"hours": 0.3, "cost": 0.0},
	"ice_survey": {"hours": 0.6, "cost": 0.0},
	"hose_flood": {"hours": 0.4, "cost": 0.0, "cat": "natural gas"},
	"chip_ice": {"hours": 1.0, "cost": 0.0},
}


## Does a job, instantly. `args`: "quality" 0..1 from the mini game (default
## from the owner's skill) plus per-job settings (docs 8, M1, API). Returns
## {"ok": bool, "text": String, ...}. A job that goes ahead always charges its
## hours and parts; one that can't (no hours, Doris won't start) charges nothing.
func job(id: String, args := {}) -> Dictionary:
	var spec: Dictionary = JOBS.get(id, {})
	if spec.is_empty():
		return {"ok": false, "text": "No such job."}
	_maybe_wake()
	var hours: float = spec.hours
	if id == "ice_check" and int(tools.get("ice_temp", 0)) >= 1:
		hours = 0.05  # the IR gun
	var by := str(args.get("by", ""))  # a staff member's name: their time, not the owner's
	if by == "" and hours > hours_left + 0.001:
		return {"ok": false, "text": "Not enough hours left today."}
	var q := _job_quality(args) if by == "" else clampf(float(args.get("quality", STAFF_QUALITY)), 0.0, 1.0)
	var cost: float = spec.cost
	var extra_hours := 0.0
	var out := {"ok": true, "text": ""}
	var text := ""
	match id:
		"resurface":
			if snow_pit >= 1.0:
				return {"ok": false, "text": "The snow pit is full: Doris has nowhere to dump."}
			if args.get("ice_state") is IceSlab:
				# driven (the doris_drive mini game or its autopilot)
				var dr := _driven_resurface(args)
				cost = float(dr.cost)
				extra_hours = float(dr.hours) - hours
				text = str(dr.text)
				out.merge(dr.out, true)
			else:
				var pat := PackedFloat64Array(args.get("pattern", []))
				var snow_before := ice.snow
				var r := doris.resurface(ice, skill.driving, pat)
				if r < 0.0:
					return {"ok": false, "text": "Doris %s." % doris.fault()}
				snow_pit = minf(snow_pit + 0.1 + 0.15 * snow_before, 1.0)
				_last_flood_abs = _abs_minute()
				skill.driving = minf(skill.driving + 0.002, 1.0)
				text = "Resurfaced (%.0f%%)." % (r * 100.0)
				out["quality"] = r
		"plant_round":
			var rd := readings()
			_log("plant_round", rd)
			text = "Plant round, written in the log."
			out["readings"] = rd
		"ice_check":
			var rd := _ice_readings()
			_log("ice_check", rd)
			text = "Ice check: %s at centre, %s." % [rd.temp_centre.text, rd.smoothness.text]
			out["readings"] = rd
		"reset_compressor":
			var i: int = int(args.get("compressor", 0))
			plant.compressors[i].tripped = false
			plant.compressors[i].trip_reason = ""
			plant.run(0.0, 0.0, rng)
			text = "Compressor %d %s." % [i + 1, "back on" if not plant.compressors[i].tripped else "trips again"]
		"compressor_oil_change":
			var i: int = int(args.get("compressor", 0))
			var c: Dictionary = plant.compressors[i]
			c.oil = 0.75 + 0.25 * q
			c.oil_level = clampf(float(args.get("oil_level", 0.5)), 0.0, 1.0)
			var filter_ok := bool(args.get("filter_ok", true))
			(c.filter as SimPart).replace(1.0 if filter_ok else 0.2)
			c.drain_leak = 0.0 if bool(args.get("drain_plug_torque_ok", true)) else 0.006
			var psi := plant.net_oil_psi(i)
			out["oil_psi"] = SimInstrument.read("oil_psi", int(tools.get("oil_psi", 0)), psi, rng, _sigma_mult())
			text = "Fresh oil in compressor %d; the gauge comes up to %s psi." % [i + 1, out.oil_psi.text]
		"compressor_oil_top_up":
			var i: int = int(args.get("compressor", 0))
			plant.compressors[i].oil_level = clampf(float(args.get("oil_level", 0.5)), 0.0, 1.0)
			text = "Topped up compressor %d from the blue drum." % (i + 1)
		"compressor_valve_job":
			var i: int = int(args.get("compressor", 0))
			var c: Dictionary = plant.compressors[i]
			c.valves.replace(0.7 + 0.3 * q)
			c.tripped = false
			c.trip_reason = ""
			if i == 0 and compressor_1_decision == "":
				compressor_1_decision = "rebuild"
			text = "New valve plates."
		"descale_condenser":
			plant.condenser_scale *= 0.4 - 0.3 * q
			text = "Condenser descaled."
		"replace_fan_belt":
			plant.condenser_fan_belt.replace(0.8 + 0.2 * q)
			text = "New fan belt."
		"glycol_top_up":
			var litres: float = float(args.get("litres", 200.0))
			var pct: float = float(args.get("pct", 50.0))
			cost = litres * pct / 100.0 * GLYCOL_PRICE
			text = "Glycol now %.0f%%." % plant.top_up(litres, pct)
		"pump_bearing":
			plant.pump_bearing.replace(0.75 + 0.25 * q)
			text = "New pump bearing."
		"blade_change":
			doris.part("blade").replace(0.85 + 0.15 * q)
			doris.blade_height_mm = float(args.get("height_mm", 1.0 + rng.randfn(0.0, 0.3 * (1.0 - q))))
			doris.blade_level_mm = float(args.get("level_mm", 0.0))
			doris.blade_bolts_ok = bool(args.get("bolts_ok", true))
			text = "New blade, set at %.1f mm." % doris.blade_height_mm
		"doris_plugs":
			if int(inventory.get("spark_plugs", 0)) > 0:
				inventory.spark_plugs = int(inventory.spark_plugs) - 1
				cost = 0.0
			var plugs := doris.part("spark_plugs")
			plugs.replace(0.55 + 0.45 * q)
			if not bool(args.get("torque_ok", true)):
				plugs.condition *= 0.7  # a loose plug: she'll run rough
			if bool(args.get("cross_threaded", false)):
				extra_hours += 2.0
				cost += 45.0  # a thread repair insert in the old aluminium head
				plugs.condition *= 0.8
			if bool(args.get("choke_freed", true)):
				doris.choke_stuck = false
			if doris.fault() == "":
				text = "Doris coughs once out of the exhaust stack and starts."
			else:
				text = "New plugs in, but she cranks and won't fire. Unless it's the choke."
			if bool(args.get("cross_threaded", false)):
				text += " One plug cross-threaded: two hours with a thread repair kit."
		"doris_carb":
			# the jets and the float bowl cleaned, a new bowl gasket
			var clean := clampf(float(args.get("jets_clean", 1.0)) * 0.6 + float(args.get("bowl_clean", 1.0)) * 0.4, 0.0, 1.0)
			doris.carb = clampf((0.6 + 0.4 * q) * (0.5 + 0.5 * clean), 0.0, 1.0)
			if bool(args.get("choke_freed", true)):
				doris.choke_stuck = false
			text = "Carburettor cleaned"
			if not bool(args.get("gasket_ok", true)):
				extra_hours += 0.25
				text += "; the old bowl gasket weeps gas, so you do it twice"
			text += "." if doris.fault() == "" else ", but she still won't fire."
		"doris_oil_change":
			# drained, a new filter, refilled to the dipstick (0.5 ADD .. 1 FULL)
			var lv := clampf(float(args.get("oil_level", 0.9)), 0.0, 1.5)
			var fresh := 0.8 + 0.2 * q
			if lv < 0.5:
				fresh *= 0.5 + lv  # short of the ADD mark: it cooks what's there
			if not bool(args.get("filter_ok", true)):
				fresh *= 0.85
			if not bool(args.get("drain_plug_torque_ok", true)):
				fresh *= 0.8  # it weeps from the drain plug
			doris.engine_oil = clampf(fresh, 0.0, 1.0)
			text = "Fresh oil and a new filter in Doris"
			if lv > 1.1:
				text += "; over the FULL line, she'll smoke a little"
			elif lv < 0.5:
				text += "; she's under the ADD mark"
			text += "."
		"engine_tune":
			doris.part("spark_plugs").replace()
			doris.part("air_filter").replace()
			doris.engine_oil = 1.0
			doris.carb = 1.0
			doris.choke_stuck = false
			text = "Doris tuned up."
		"towel_change":
			doris.part("towel").replace()
			text = "New towel."
		"shave_ice":
			if snow_pit >= 1.0:
				return {"ok": false, "text": "The snow pit is full: Doris has nowhere to dump."}
			var mm := doris.dry_cut(ice, skill.driving)
			if mm < 0.0:
				return {"ok": false, "text": "Doris %s." % doris.fault()}
			snow_pit = minf(snow_pit + 0.25, 1.0)
			text = "A dry cut with the blade down: about %.1f mm off." % mm
		"edge_ice":
			if args.get("ice_state") is IceSlab:
				ice.adopt(args.ice_state)
				snow_pit = minf(snow_pit + 0.05, 1.0)
				text = "Edged the boards; the lip is down to %.0f mm." % maxf(ice.edge_lip_mm(), 0.0)
				out["quality"] = q
			else:
				ice.edge_cut(6.0, q)
				snow_pit = minf(snow_pit + 0.05, 1.0)
				text = "Edged the boards; the lip is down to %.0f mm." % maxf(ice.edge_lip_mm(), 0.0)
		"install_plate":
			var spot := str(args.get("spot", ""))
			if not IceSlab.PLATE_SPOTS.has(spot) or spot in ice.plates or plate_pending(spot):
				return {"ok": false, "text": "There's already a plate there." if spot in ice.plates or plate_pending(spot) else "Put a plate where?"}
			var on_day := int(args.get("day", day + 1))
			if on_day < day:
				return {"ok": false, "text": "That day's gone."}
			plate_closures.append({"day": on_day, "spot": spot})
			text = "Plate ordered for %s. The ice closes on %s while it freezes in." % [spot.replace("_", " "), date_text(on_day)]
			out["closed_day"] = on_day
			out["sessions_lost"] = sessions(on_day).size()
		"ice_depth":
			# the measuring scene's own caliper readings when it has them
			var given: Variant = args.get("readings", null)
			var rd: Dictionary = given if given is Dictionary and not (given as Dictionary).is_empty() else depth_readings(str(args.get("spot", "")))
			_log("ice_depth", rd)
			out["readings"] = rd
			var parts := PackedStringArray()
			for k: String in rd:
				parts.append("%s %s" % [k.replace("_", " "), rd[k].text])
			text = "Depth at the plates: %s." % ", ".join(parts)
		"ice_survey":
			var pts: Array = args.get("points", [])
			var given_s: Variant = args.get("readings", null)
			var rd: Dictionary = given_s if given_s is Dictionary and not (given_s as Dictionary).is_empty() else survey_readings(pts)
			_log("ice_survey", rd)
			out["readings"] = rd
			text = "Surveyed %d spots off the laser." % rd.size()
		"hose_flood":
			if args.get("ice_state") is IceSlab:
				ice.adopt(args.ice_state)
			var litres := float(args.get("litres", 0.0))
			cost = ResurfacerSim.heat_cost(litres, float(args.get("temp_c", doris.flood_temp_c)))
			text = "Hose-flooded the low spots: %.0f L." % litres
			out["quality"] = q
		"chip_ice":
			var cut := 0.0
			if args.get("ice_state") is IceSlab:
				ice.adopt(args.ice_state)
			else:
				cut = ice.chip_boards(q)
			snow_pit = minf(snow_pit + 0.04, 1.0)
			text = "Chipped the ridge off along the boards; the lip is down to %.0f mm." % maxf(ice.edge_lip_mm(), 0.0)
			out["chipped_mm"] = cut
		"dump_snow":
			snow_pit = 0.0
			text = "Hosed the snow pit down to the drain."
		"clean_building":
			cleanliness = minf(cleanliness + 0.35 * q, 1.0)
			text = "Building cleaned."
		"refuel_doris":
			doris.fuel = 1.0
			text = "Doris refuelled."
		"install_compressor":
			var i: int = int(args.get("compressor", 0))
			var model: String = str(args.get("model", ""))
			if not model in delivered:
				return {"ok": false, "text": "Nothing like that in the parking lot."}
			if not plant.refrigerant in PlantCatalog.compressor(model).refrigerants:
				return {"ok": false, "text": "That machine can't run on %s." % PlantCatalog.refrigerant(plant.refrigerant).name}
			delivered.erase(model)
			var m := PlantCatalog.compressor(model)
			cost = float(m.contractor)
			plant.compressors[i].out = true
			installs.append({"compressor": i, "model": model, "done_day": day + int(m.install_days), "quality": 0.85 + 0.15 * q})
			text = "The crane is here. Compressor %d is out for %d days." % [i + 1, m.install_days]
		"convert_refrigerant":
			var to: String = str(args.get("to", ""))
			if not PlantCatalog.REFRIGERANTS.has(to) or to == plant.refrigerant:
				return {"ok": false, "text": "Convert to what?"}
			if not plant.can_run(to):
				return {"ok": false, "text": "The compressors can't run on %s." % PlantCatalog.refrigerant(to).name}
			var r := PlantCatalog.refrigerant(to)
			var price := PlantCatalog.refill_price(to, year())
			if price < 0.0:
				return {"ok": false, "text": "You can't buy %s any more." % r.name}
			cost = float(r.charge_kg) * price + 15000.0
			for c in plant.compressors:
				c.out = true
			conversion = {"to": to, "done_day": day + 10}
			text = "The contractor is recovering the old charge. The plant is down for ten days."
		"recharge_refrigerant":
			var price := refill_price()
			if price < 0.0:
				return {"ok": false, "text": "Nobody sells %s any more." % PlantCatalog.refrigerant(plant.refrigerant).name}
			var kg := (1.0 - plant.charge) * float(PlantCatalog.refrigerant(plant.refrigerant).charge_kg)
			cost = kg * price
			plant.charge = 1.0
			text = "Topped up %.0f kg of %s." % [kg, PlantCatalog.refrigerant(plant.refrigerant).name]
	if by == "":
		_charge_hours(hours + extra_hours)
		if id != "resurface":
			skill.mechanic = minf(skill.mechanic + 0.004, 1.0)
	else:
		text = "%s: %s" % [by, text]
	if cost > 0.0:
		book(str(spec.get("cat", "parts and supplies")), -cost)
	out.text = text
	out["hours"] = hours + extra_hours
	out["cost"] = cost
	_note(text, "job")
	_update_goals()
	return out


## The walk: the owner is in the building for the next `minutes`, so their
## floods wait to be driven.
func owner_on_site(minutes := 30) -> void:
	owner_here_until = _abs_minute() + minutes


func owner_waits() -> bool:
	return not earl_hired and (owner_drives or _abs_minute() <= owner_here_until)


## The ice is closed on day `d` while a depth plate freezes in.
func ice_closed(d: int) -> bool:
	for c in plate_closures:
		if int(c.day) == d:
			return true
	return false


func plate_pending(spot: String) -> bool:
	for c in plate_closures:
		if str(c.spot) == spot:
			return true
	return false


## The day a closure ends: its plates are in.
func _plates_frozen(d: int) -> void:
	var keep: Array = []
	for c in plate_closures:
		if int(c.day) <= d:
			if not str(c.spot) in ice.plates:
				ice.plates.append(str(c.spot))
				_note("The depth plate at %s has frozen in." % str(c.spot).replace("_", " "), "job")
		else:
			keep.append(c)
	plate_closures = keep


## The owner flood waiting to be driven (the latest in the last two hours),
## or {}.
func flood_waiting() -> Dictionary:
	var now := _abs_minute()
	for i in range(floods_waiting.size() - 1, -1, -1):
		var f: Dictionary = floods_waiting[i]
		var at := int(f.day) * 24 * 60 + int(f.minute)
		if now - at <= 120 and at > _last_flood_abs:
			return f
	return {}


## A driven resurface (the doris_drive mini game or its autopilot): the
## worked ice comes back as `ice_state` with what the run measured.
func _driven_resurface(args: Dictionary) -> Dictionary:
	ice.adopt(args.ice_state)
	var q := clampf(float(args.get("quality", 0.5)), 0.0, 1.0)
	doris.flood_l = clampf(float(args.get("flood_l_left", 0.0)), 0.0, ResurfacerSim.FLOOD_TANK_L)
	doris.wash_l = clampf(float(args.get("wash_l_left", 0.0)), 0.0, ResurfacerSim.WASH_TANK_L)
	doris.cuts_driven += 1
	doris.fuel = maxf(doris.fuel - float(args.get("fuel_used", 0.045)), 0.0)
	for id in doris.parts:
		(doris.parts[id] as SimPart).run(ResurfacerSim.RESURFACE_HOURS, 1.0 + (0.5 if bool(args.get("jam", false)) and id == "auger_bearing" else 0.0))
	doris.engine_oil = maxf(doris.engine_oil - ResurfacerSim.RESURFACE_HOURS / 120.0, 0.0)
	doris.carb = maxf(doris.carb - ResurfacerSim.RESURFACE_HOURS / ResurfacerSim.CARB_LIFE_H, 0.0)
	# the pit takes what was dumped (a full Doris load is about 0.25 of it)
	var dumped := float(args.get("dumped_m3", 0.0))
	snow_pit = minf(snow_pit + dumped / ResurfacerSim.SNOW_TANK_M3 * 0.25, 1.0)
	_last_flood_abs = _abs_minute()
	floods_waiting = []
	skill.driving = minf(skill.driving + 0.004, 1.0)
	var mins := float(args.get("minutes", 15.0))
	var kind := str(args.get("kind", "normal"))
	var what: String = {"normal": "Resurfaced", "dry": "Dry cut", "flood": "Flooded", "none": "Drove round"}.get(kind, "Resurfaced")
	var text := "%s (%.0f%%): %+.1f mm, %d%% covered." % [what, q * 100.0, float(args.get("thickness_change_mm", 0.0)), roundi(float(args.get("coverage", 0.0)) * 100.0)]
	if bool(args.get("jam", false)):
		text += " The augers jammed."
	if int(args.get("board_hits", 0)) > 0:
		text += " Doris kissed the boards."
	return {"cost": float(args.get("gas_cost", FLOOD_GAS)), "hours": maxf(mins / 60.0, 0.1), "text": text, "out": {"quality": q}}


## What the drill or the calipers read at the plates (`spot`, or all of them).
func depth_readings(spot := "") -> Dictionary:
	var out := {}
	var tier := int(tools.get("ice_thickness", 0))
	for id in ice.plates:
		if spot != "" and id != spot:
			continue
		out[id] = SimInstrument.read("ice_thickness", tier, ice.plate_depth_mm(str(id)), rng, _sigma_mult())
	return out


## Survey rod readings at rink points `pts` ([Vector2] or [[x, y]]): the
## laser's mark on the rod, mm (SimInstrument "ice_level").
func survey_readings(pts: Array) -> Dictionary:
	var out := {}
	var tier := int(tools.get("ice_level", 0))
	var k := 0
	for p in pts:
		var v := Vector2.ZERO
		if p is Vector2:
			v = p
		elif p is Array and (p as Array).size() >= 2:
			v = Vector2(float(p[0]), float(p[1]))
		out["p%d" % k] = SimInstrument.read("ice_level", tier, ice.rod_reading_mm(v), rng, _sigma_mult())
		out["p%d" % k]["at"] = [v.x, v.y]
		k += 1
	return out


func _log(job_id: String, rd: Dictionary) -> void:
	log_book.append({"day": day, "minute": minute, "who": "owner", "job": job_id, "readings": rd})
	if log_book.size() > 500:
		log_book = log_book.slice(log_book.size() - 500)


## What the owner can see on a plant round, through the current tools. Every
## value is a SimInstrument reading: {"value", "text", "sigma", "instrument"}.
func readings() -> Dictionary:
	var sm := _sigma_mult()
	var out := {}
	out["ice_temp"] = SimInstrument.read("ice_temp", int(tools.ice_temp), ice.surface_temp, rng, sm)
	out["ice_thickness"] = SimInstrument.read("ice_thickness", int(tools.ice_thickness), ice.thickness_mm, rng, sm)
	out["glycol_pct"] = SimInstrument.read("glycol_pct", int(tools.glycol_pct), plant.glycol_pct, rng, sm)
	out["glycol_level"] = SimInstrument.read("glycol_level", int(tools.get("glycol_level", 0)), plant.glycol_litres, rng, sm)
	out["brine_temp"] = SimInstrument.read("brine_temp", int(tools.brine_temp), plant.supply_temp, rng, sm)
	out["suction_psig"] = SimInstrument.read("suction_psig", int(tools.get("suction_psig", 0)), plant.suction_psig(), rng, sm)
	out["discharge_psig"] = SimInstrument.read("discharge_psig", int(tools.get("discharge_psig", 0)), plant.discharge_psig(), rng, sm)
	for i in plant.compressors.size():
		var c: Dictionary = plant.compressors[i]
		var n := i + 1
		out["compressor_%d" % n] = SimInstrument.read("compressor_health", int(tools.compressor_health), plant.compressor_health(i), rng, sm)
		out["oil_%d" % n] = SimInstrument.read("oil_quality", int(tools.oil_quality), float(c.oil), rng, sm)
		out["oil_level_%d" % n] = SimInstrument.read("oil_level", int(tools.get("oil_level", 0)), float(c.oil_level), rng, sm)
		var running := not bool(c.tripped) and not bool(c.get("out", false))
		out["oil_psi_%d" % n] = SimInstrument.read("oil_psi", int(tools.get("oil_psi", 0)), plant.net_oil_psi(i) if running else 0.0, rng, sm)
		var status := "running"
		if bool(c.get("out", false)):
			status = "out"
		elif bool(c.tripped):
			status = "tripped" + ((": " + str(c.trip_reason)) if str(c.trip_reason) != "" else "")
		out["status_%d" % n] = {"value": 1.0 if running else 0.0, "text": status, "sigma": 0.0, "instrument": "The panel lights"}
	return out


## The ice check: the screwdriver (or the IR gun) at centre and both blue
## lines, the drill at centre, and a walk.
func _ice_readings() -> Dictionary:
	var sm := _sigma_mult()
	var out := {}
	var spots := {"temp_centre": Vector2i(10, 4), "temp_home_blue": Vector2i(7, 4), "temp_away_blue": Vector2i(13, 4)}
	for k in spots:
		var p: Vector2i = spots[k]
		var cl := ice.cell(p.x, p.y)
		var t := ice.surface_temp - (float(cl.thickness_mm) - ice.thickness_mm) * 0.03  # thin spots read colder
		out[k] = SimInstrument.read("ice_temp", int(tools.ice_temp), t, rng, sm)
	out["thickness_centre"] = SimInstrument.read("ice_thickness", int(tools.ice_thickness), float(ice.cell(10, 4).thickness_mm), rng, sm)
	out["smoothness"] = SimInstrument.read("smoothness", int(tools.get("smoothness", 0)), ice.felt_smoothness(), rng, sm)
	return out


func buy_tool(reading: String, tier: int) -> bool:
	var t: Array = SimInstrument.tiers(reading)
	if tier <= int(tools.get(reading, 0)) or tier >= t.size() or money < float(t[tier].price):
		return false
	book("tools", -float(t[tier].price))
	tools[reading] = tier
	if reading == "ice_level" and str(t[tier].id) == "level_sense":
		# the new machine: it reads the lidar map and sets blade and water itself
		doris.auto_level = true
		doris.model = "Zambelli 750 Level-Sense"
		for id in doris.parts:
			(doris.parts[id] as SimPart).replace()
	_note("Bought a %s." % t[tier].name, "purchase")
	return true


## Buys an instrument by its id ("ir_gun", "refractometer").
func buy_instrument(id: String) -> bool:
	var f := SimInstrument.find(id)
	if f.is_empty():
		return false
	return buy_tool(str(f.reading), int(f.tier))


func _note(text: String, kind := "note") -> void:
	if text == "":
		return
	var e := {"day": day, "minute": minute, "text": text, "kind": kind}
	events.append(e)
	if _collecting:
		_new_events.append(e)
	if events.size() > 400:
		events = events.slice(events.size() - 400)


# ------------------------------------------------------------------ goals

func _goal(id: String) -> Dictionary:
	for g in goals:
		if g.id == id:
			return g
	return {}


func _set_goal(id: String, done: bool, failed := false) -> void:
	var g := _goal(id)
	if g.is_empty():
		return
	if done and not bool(g.done):
		g.done = true
		_note("Goal done: %s" % g.text, "goal")
	if failed and not bool(g.failed):
		g.failed = true
		_note("Goal missed: %s" % g.text, "goal")


func _update_goals() -> void:
	if goals.is_empty():
		return
	if ice.thickness_mm < 40.0:
		_set_goal("ice_under_40", true)
	if compressor_1_decision != "":
		_set_goal("compressor_1", true)
	var b := _bid("minor_hockey")
	if not b.is_empty():
		if b.state == "won":
			_set_goal("minor_hockey_slot", true)
		elif b.state == "lost":
			_set_goal("minor_hockey_slot", false, true)
	if cancelled_sessions > 0 or lost_contracts > 0:
		_set_goal("keep_bookings", false, true)


## Sunday night of the first week: the bookings goal is kept if nothing was
## cancelled or lost; the ice goal is missed if it's still 40 mm or more.
func _finish_week_goals() -> void:
	_update_goals()
	var kb := _goal("keep_bookings")
	if not kb.is_empty() and not bool(kb.failed):
		_set_goal("keep_bookings", true)
	var ig := _goal("ice_under_40")
	if not ig.is_empty() and not bool(ig.done):
		_set_goal("ice_under_40", false, true)
	var cg := _goal("compressor_1")
	if not cg.is_empty() and not bool(cg.done):
		_set_goal("compressor_1", false, true)


# ------------------------------------------------------------------ save

## Plain members saved by name (to_dict) and restored with their types.
const SAVE_VARS := ["mode", "day", "minute", "start_weekday", "start_doy", "money", "hours_left", "hours_worked",
	"fatigue", "overslept_day", "inventory", "cleanliness", "ice_rep", "rep_window_hours", "contracts", "events",
	"ledger", "books", "auto_resurface", "morning_flood", "earl_hired", "orders", "delivered", "installs",
	"conversion", "rental_until", "evacuated_day", "owner_game_weekday", "games", "lights_on", "lights_warm",
	"auto_lights", "snow_pit", "pit_melt_per_h", "log_book", "session_log", "flood_log", "trips", "bills", "goals",
	"bids", "binder", "weekly_reports", "cancelled_sessions", "lost_contracts", "compressor_1_decision",
	"trip_script", "owner_pay_owed", "cia_weekly_pay", "owner_drives", "owner_here_until", "floods_waiting", "plate_closures",
	"work_orders", "_kwh_today", "_hours_today", "_money_day_start", "_session_key", "_ratings_today", "_cur_session",
	"_floods_done", "_last_flood_abs", "_last_active_abs", "_woke_day", "_script", "_recovered_kwh"]
## Old save keys that map onto renamed members.
const SAVE_ALIASES := {"kwh_today": "_kwh_today", "session_key": "_session_key", "ratings_today": "_ratings_today",
	"recovered_kwh": "_recovered_kwh"}


func to_dict() -> Dictionary:
	var d := {"version": 2, "skill": skill.duplicate(), "tools": tools.duplicate(), "rooms": rooms.duplicate(),
		"league": league.duplicate(), "rng_seed": str(rng.seed), "rng_state": str(rng.state),
		"plant": plant.to_dict(), "ice": ice.to_dict(), "doris": doris.to_dict(), "schedule": schedule.to_dict(), "ops": ops.to_dict()}
	for k in SAVE_VARS:
		var v: Variant = get(k)
		if v is Array or v is Dictionary:
			d[k] = v.duplicate(true)
		else:
			d[k] = v
	return d


static func from_dict(d: Dictionary) -> RinkSim:
	var s := RinkSim.create()
	for k in ["skill", "tools", "rooms", "league"]:
		var v: Dictionary = d.get(k, {})
		var into: Dictionary = s.get(k)
		for kk in v:
			into[kk] = v[kk]
	for alias in SAVE_ALIASES:
		if d.has(alias) and not d.has(SAVE_ALIASES[alias]):
			d[SAVE_ALIASES[alias]] = d[alias]
	for k in SAVE_VARS:
		if not d.has(k):
			continue
		var cur: Variant = s.get(k)
		var v: Variant = d[k]
		match typeof(cur):
			TYPE_INT:
				s.set(k, int(v))
			TYPE_FLOAT:
				s.set(k, float(v))
			TYPE_BOOL:
				s.set(k, bool(v))
			TYPE_STRING:
				s.set(k, str(v))
			TYPE_ARRAY:
				s.set(k, (v as Array).duplicate(true))
			TYPE_DICTIONARY:
				s.set(k, (v as Dictionary).duplicate(true))
	# JSON brings ints back as floats; the flood minutes are compared with `in`
	var fd: Array = []
	for m in s._floods_done:
		fd.append(int(m))
	s._floods_done = fd
	s.rng.seed = int(d.get("rng_seed", "1"))
	s.rng.state = int(d.get("rng_state", "0"))
	s.plant.load_dict(d.get("plant", {}))
	s.ice.load_dict(d.get("ice", {}))
	s.doris.load_dict(d.get("doris", {}))
	s.schedule = RinkSchedule.from_dict(d.get("schedule", {}))
	s.ops = RinkOps.from_dict(d.get("ops", {}))
	if not d.has("_money_day_start"):
		s._money_day_start = s.money
	return s
