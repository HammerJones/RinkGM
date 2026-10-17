# RinkGM rink management: the RINK_SIM design

A game design for Sean, written for the developers who build it. Owned by the
World and asset design thread (sim core, mini games, art), with pieces handed
to Rink environment, Game mechanics, UI and Physics (see section 7).

Sean asked for a rink management loop in the style of today's simulation
games: the player owns and operates the Millbrook Community Arena, starts out
doing every job themselves (pro shop, ice, the plant, Doris, the books), and
grows into its general manager. The hands-on jobs are detailed mechanical mini
games with real parts to replace. The management side is just as deep. Ice
and facility quality decide which organisations will rent the ice, and the
tools for measuring and maintaining the rink get more accurate over time.

Touchstones: PowerWash Simulator and Car Mechanic Simulator for the hands-on
jobs (satisfying, physical, step by step, with a clean "before and after"),
Two Point Hospital, Planet Coaster and Football Manager for management (a
schedule to fill, people with opinions, a P&L that tells the truth). Tone:
lighthearted but not dumb. The machines are real, the numbers are real, and
the people are funny.

This doc maps onto the sim core already started in `scripts/world/sim/`
(`SimPart`, `SimInstrument`, `IceSlab`, `RefrigerationPlant`,
`ResurfacerSim`, `RinkContracts`) and the planned `RinkSim` that holds them.
Where a number here differs from a constant in that code, the doc says so and
suggests which to keep.

Units: the game shows metric first with imperial in brackets where rink people
use imperial (ice thickness in inches, pressures in psig, belt deflection in
inches). Money is dollars, as in `PROSHOP.md`.

## Contents

1. The loop: day, week, season, year, difficulty, the first hour
2. Owner-operator to GM: hours, staff, wages, the shift to managing
3. The systems: plant, ice, Doris, edger, building
4. Mechanical mini games (11 jobs)
5. General management
6. Connections: the hockey career, Physics and the region
7. Data shapes and ownership
8. Milestones

---

## 0. The premise

Millbrook Parks & Recreation can't afford the Community Arena any more. The
1974 plant eats $11,000 of electricity a month, the roof drips on the blue
line every March, and the Millbrook Minor Hockey Association moved half its
ice to Harlow Falls last spring. The town sells the arena to the player for
one dollar under the **Community Ice Agreement**:

| Clause | What it means in the game |
| --- | --- |
| Keep it a rink for 10 years | Selling or closing ends the career's rink side (a game-over screen for the rink, not the hockey) |
| At least 4 hours a week of public skating | A standing contract the player can't cancel without a town fine ($500 a missed week) |
| Minor hockey gets first refusal on prime ice at the community rate | Minor hockey can claim prime slots before anyone else bids, at a capped rate |
| Surplus is reinvested for the first two seasons | The owner's draw (paying yourself from the rink) is $0 until the start of season 3, so the player's personal money still follows the `PROSHOP.md` economy |

What the player inherits:

| Item | State |
| --- | --- |
| Cash in the rink account | $8,000 ("the reserve fund, what's left of it") |
| Line of credit at Frostbank | $25,000 at 8.5% |
| Every room in the `Venue` | `WORN` |
| Plant | Two 1974 Nordale RC-4 ammonia compressors (number 1 is "the grumpy one"), a rooftop evaporative condenser, a glycol loop |
| Doris | The 1974 Zambelli Model 525, gas, about 21,000 engine hours |
| Edger | A 1988 walk-behind edger that starts on the third pull |
| Tools | A screwdriver, a log book, an old dial thermometer, a socket set with three sockets missing |
| People | Nobody on the payroll. Earl Bratt (head icemaker since 1983) took his pension the day the town sold and is sulking at the Legion. Bev sharpens skates across the lot three afternoons a week |
| Gus's binder | The old arena manager, Gus Tremblay (1977 to last spring, now in Florida), left a binder of notes taped to the plant room door. Every note is a tutorial in fiction |

The player is still a beer league hockey player (the career in
`scripts/career/`). Owning the rink and playing hockey share one calendar and
one body.

---

## 1. The loop

### 1.1 Time in the sim

`RinkSim` advances in in-game minutes. A day is split into four blocks. The
sim runs freely inside a block at a chosen speed (pause, 1x, 4x, 16x, "to the
next event") and stops at each block boundary for decisions, like Football
Manager's continue button. Events (a compressor trip, an angry coach, a
delivery) can stop the clock inside a block.

| Block | Clock | What happens | What the player mostly does |
| --- | --- | --- | --- |
| Early morning (plant checks) | 05:00 to 07:00 | The plant comes out of night setback, the first flood of the day, early figure skating at 06:00 | Plant rounds (read every gauge, write the log), feel the ice, start Doris, decide setpoints for the day |
| Day (ice sessions) | 07:00 to 17:00 | Figure skating, school ice, seniors' skate, parent and tot, public skate, shinny, with resurfacing between sessions | Flood between sessions, run the counter and rentals, take deliveries, do jobs in dead time, phone calls |
| Evening (games and rentals) | 17:00 to 01:00 | Prime time: minor hockey 17:00 to 21:00, Senior games, beer league late ice 21:30 to 01:00 | Floods every hour, intermission floods at games, dressing rooms, concessions, playing your own game |
| Night (planning) | 01:00 to 05:00 | The plant runs on night setback (warmer ice, cheaper power), the building is empty | The office: the ice grid, bids, orders, the P&L, staff rosters; then sleep |

The night block is quick: the office screen opens, the player plans, and the
clock skips to 05:00 when they choose Sleep. Desk work done at night costs
sleep (see 2.2).

Rink time and the career share the calendar day `Career.day`. `RinkSim`
holds its own minute-of-day and the weekday (`(day + start_weekday) % 7`,
with 0 as Sunday, matching the weekday numbers in `RinkContracts.ORGS`).

### 1.2 A day in detail

A typical weekday in October, Year 1, before any staff:

| Time | Event | Owner hours |
| --- | --- | --- |
| 05:00 | Arrive, lights on (the breaker panel in the bay has a note: "NOT #14, EVER") | 0.1 |
| 05:10 | Plant rounds: compressors, oil, pressures, glycol, condenser, write the log | 0.5 |
| 05:40 | Ice check: screwdriver test at centre and both blue lines | 0.2 |
| 05:50 | First flood (Doris warm-up, flood, dump snow, refill hot water) | 0.35 |
| 06:00 to 08:00 | Figure skating club on the ice (if signed) | 0 (but you're there) |
| 08:00 | Flood | 0.35 |
| 08:15 to 15:00 | Dead time: a seniors' skate, a shinny group, maybe nothing. Jobs fit here | Jobs |
| 12:00 to 14:00 | Public skate: rentals counter, skate guard, music | 2.0 |
| 14:00 | Flood | 0.35 |
| 15:30 | High school practice | 0 |
| 17:00 to 21:00 | Minor hockey, four one-hour sessions, a flood after each | 1.4 |
| 21:00 | Dressing rooms (hose, squeegee, garbage, tape balls) | 0.5 |
| 21:30 to 23:30 | Beer league: two games, flood between | 0.35 |
| 23:30 | Last flood ("the night flood", deeper water to build the ice) | 0.4 |
| 00:00 | Office: tomorrow's grid, a parts order, an email from the figure club | 0.75 |

That is about 7.5 hours of fixed work plus the counter, cleaning and whatever
breaks. The owner's budget (2.1) is 14 hours, so there is room for one real
job a day, or a hockey game, or sleep. Not all three.

**Decisions that matter in a day:**

- Which sessions get a flood. A flood costs 21 minutes of owner time, $3.40
  of gas and hot water, and slot time on the grid. Skipping one saves time
  but the next group skates on chewed, snowy ice and the ice rating drops
  for that session.
- Setpoints. Colder ice (a lower brine supply temperature) is harder and
  faster, costs more power and is wrong for figure skating. Warming the ice
  for the figure club at 06:00 and pulling it back down for hockey at 17:00
  takes plant time.
- Which job to do in dead time, and whether to do it yourself, call a
  contractor or leave it.
- Whether to open the counter. Every hour the counter is open earns shop and
  rental money but costs an owner hour.

### 1.3 A week

| Day | Typical shape |
| --- | --- |
| Monday | Quietest day. Deliveries arrive, the weekly edging, the weekly glycol check, supplier calls. Adult learn to skate at 19:00 |
| Tuesday | Beer League D and C at 22:00 (the player's own game if they're in BL-D/C) |
| Wednesday | Broomball late; the mid-week contract calls and inspections tend to land here |
| Thursday | Beer league again; Bev's long afternoon at the sharpener |
| Friday | Evening rentals and Senior games; paperwork for the weekend |
| Saturday | Minor hockey from 07:00, figure skating at noon, public skate, a tournament weekend once a month in winter |
| Sunday | Minor hockey in the morning, the night flood, the weekly report. Bev is at church or the casino |

Weekly rhythms in the sim:

| Rhythm | When | What |
| --- | --- | --- |
| Weekly report | Sunday night | Ice rating by session, hours used, cash in and out, reputation change, contract warnings |
| Edging | Weekly (two to three times a week when busy) | Build-up along the boards. See mini game 4.10 |
| Plant log review | Weekly | Trends in the log book reveal slow problems (a creeping discharge pressure, falling glycol level) |
| Stock order | Weekly | Pro shop restock (supplier deals in `PROSHOP.md`), concessions, parts on the shelf |
| Stick barrel | Every two weeks | Lorne Pettipiece takes the barrel if there's a standing order (`PROSHOP.md`) |
| Payroll | Every two weeks once there is staff | Wages leave the account |

### 1.4 A season and a year

The rink year runs from ice-in in late August to ice-out in early June.

| Period | Dates | What it's about |
| --- | --- | --- |
| Ice-in | Mid August, about 10 days | Start the plant, chill the floor, build the base, paint lines and logos, build to full thickness. Mini game 4.11 |
| Pre-season | Late August to September | Hockey schools, tryouts, Senior AAA training camp, the GNHL rookie camp (late game). Warm, humid weather loads the plant and fogs the building |
| Main season | October to March | Every slot sells. Cold outside, so the condenser has an easy time but the roof, boiler and dehumidifier don't. Tournaments, playoffs, the curling bonspiel in March |
| Spring ice | April to May | Spring leagues, hockey schools, power skating. Ice allocation for next season happens now (bids, 5.2). Fog season: warm humid air meets cold ice |
| Ice-out | Early June, 3 days | Plant off, break and remove the ice (or let it melt into the floor drains), clean the slab |
| Summer shutdown | June to mid August | Plant overhaul, condenser descale, glycol test or flush, Doris's annual service, renovation projects, inspections, the Northern Rink Operators' trade show (tool upgrades), dry floor rentals (lacrosse, ball hockey, a wedding, the farmers' market) |

Summer is where the big jobs live, because the ice isn't depending on the
plant. It is a planning game: a list of projects, a budget, contractors to
book, and about ten weeks.

| Summer project | Typical length | Notes |
| --- | --- | --- |
| Compressor valve jobs on both machines | 2 days | Can be done in season on one machine at a time, but it's riskier |
| Condenser descale and fill repair | 2 days | Needs the plant off; only realistic in summer |
| Glycol flush and refill | 3 days | Every 5 to 10 years, or when the test says so |
| Header inspection and jumper replacement | 1 to 3 days | Easier with no ice on the floor |
| Pressure relief valve replacement | 1 day (contractor) | Required every 5 years by the ammonia inspector |
| Doris annual service | 2 days | Tires, hydraulics, a full tune-up |
| Room renovations | 1 to 8 weeks each | Rooms move WORN to REPAIRED to RENOVATED (5.8) |
| New refrigeration floor | 10 to 14 weeks | The biggest project in the game. Starts at ice-out, may delay ice-in |

### 1.5 How difficulty scales

The game gets harder in four ways, all from the world rather than from a
difficulty slider:

1. **The building ages.** Every part wears per hour. Fixing the obvious faults
   in Year 1 exposes the next layer: the 1974 floor reaches 50 years, the
   second compressor's bearings go, the roof membrane gives up.
2. **Customers get more demanding.** Better contracts have tighter
   requirements (a narrower ice temperature window, a laser-measured level,
   a minimum lux level, penalty clauses), and their own people measure the
   ice. A GNHL equipment manager brings his own infrared gun.
3. **The weather turns.** The weather model (outdoor temperature and humidity
   by day) loads the plant in September and May, freezes the condenser sump
   in January, fogs the arena in April, and brings an occasional heat wave or
   ice storm (power cut).
4. **The competition improves.** Harlow Falls replaces its R-22 plant in Year
   3, Port Ainsley opens a second pad, and Duncannon's Frostbank Centre
   undercuts on tournaments.

A difficulty setting on top tunes forgiveness, not the rules:

| Setting | Wear rate | Instrument error | Contract patience | Money |
| --- | --- | --- | --- | --- |
| Community | x0.7 | x0.75 | Organisations forgive two bad sessions | Grants easier |
| Operator (default) | x1.0 | x1.0 | One warning, then penalties | As written |
| Old Gus | x1.3 | x1.25, and nothing is logged automatically | No warnings | Insurance and loans dearer |

The game also has four stages the player moves through naturally. They are
not gated, but contract thresholds and the hours budget push this shape:

| Stage | Roughly | The player is | The fight is |
| --- | --- | --- | --- |
| Survive | Year 1 | Doing everything, badly at first | Keep every booking, stop the bleeding, win back minor hockey |
| Stabilise | Year 2 | Hiring the first help, learning the plant | Repair the worst rooms, get the ice into the 60s, sign the figure club and the Lumber Kings' new lease |
| Grow | Years 3 to 4 | Managing a small team, still doing the hard jobs | Tournaments, sponsors, a renovated lobby and dressing rooms, a digital controller |
| Prestige | Year 5 on | A GM who can still pull a valve plate | GNHL practice ice, a TV event, the new floor, beating Duncannon for the big contracts |

### 1.6 The first hour of play

The tutorial is in fiction: Gus's binder, a phone that rings, and Doris. No
pop-up teaches anything that a note in Gus's handwriting could teach instead.
The first day is Monday, the first week of September, Year 1. The ice is in
(Earl put it in before he quit; the lines are painted and the base is a bit
thick).

| Minute | Beat | What it teaches |
| --- | --- | --- |
| 0 | 05:00. Snow hasn't started yet but the parking lot is dark. The keys are in an envelope under the mat: "WELCOME. DON'T TOUCH BREAKER 14. GUS" | Walking, doors, the building at WORN |
| 2 | The plant room door is covered in notes. The top one: "Every morning. Oil first. Number 1 drinks." The log book is open on the desk with a pencil on a string | Plant rounds. The player reads the suction and discharge dial gauges, the oil sight glass on each compressor and the glycol thermometer, and writes them in the log. Each reading appears through its instrument (a dial that sticks, a sight glass that's "amber, probably") |
| 8 | Number 1's sight glass is low. A note: "Oil's in the blue drum. Hand pump. HALF the glass, not full." | A tiny job: top up oil (the first taste of mini game 4.2) |
| 12 | Out on the ice with a screwdriver. Gus's note: "Push a screwdriver in at the blue line. If it goes in easy, the ice is soft. If it bounces, you've hit concrete and we have problems." | The ice check. Text readings, not numbers ("about right", "soft") |
| 15 | The first flood of the day is due at 05:50. Doris won't start | The diagnose-repair loop |
| 16 | Doris cranks but won't fire. Gus's note on the dash: "If Doris won't start it's the plugs. It's always the plugs. Unless it's the choke." | Diagnosis. The player can test for spark (pull a lead, hold it near the block with insulated pliers, crank: a weak orange spark), check fuel (pump the throttle, smell at the carb), check the choke (stuck half closed) |
| 22 | Four spark plugs in a drawer labelled "DORIS". The player pulls the old plugs (black and wet: fouled), gaps the new ones to 0.035 in with a coin-type gauge, fits them hand-tight then a quarter turn, frees the choke with a spray of carb cleaner | Parts and procedure. Gapping and torque matter: a misgapped plug makes Doris run rough later |
| 28 | Doris coughs once out of the exhaust stack and starts. The first flood: drive the pattern (two laps around the boards, then the long overlapping passes), blade lever, water lever, don't hit the boards | Driving Doris, the core repeated skill |
| 35 | The figure club coach, Hélène Arsenault, arrives at 06:00 for a trial session, feels the ice with a blade and frowns: "It is like skating on a parking lot." | Ice use types: figure skaters want softer ice (-3 to -4 C surface). The player can warm it for next time |
| 45 | The phone in the office rings: the Valley Beer League commissioner, Dale Huffman, wants to know if "the new guy" is renewing the binder deal | The office, the ice grid and the first contract |
| 50 | Last month's electricity bill is on the desk: $11,240. A note from Gus: "Ice is too thick. Earl likes it thick. Earl doesn't pay the bill." | The economy, and the first strategic goal: get the ice from about 50 mm down to 32 mm by edging and shaving, which cuts the plant load |
| 55 | The week's goals appear as Gus-style sticky notes on the office corkboard: keep every booking; get the ice under 40 mm; decide what to do about compressor 1; win back one Minor Hockey slot | The goal system (a gentle objective list that can always be ignored) |
| 60 | At 22:00 the player has their own Beer League game, on their own ice, which they flooded at 21:40, and need to flood again at the second intermission. Someone has to | The core tension: one person, too many jobs |

By the end of the first week (the vertical slice, section 8), the player has
seen the plant trip once (number 1, on low oil pressure, Wednesday night),
done two mini games and fought for their first new contract.

---

## 2. Owner-operator to GM

### 2.1 The hours budget

| Number | Value | Note |
| --- | --- | --- |
| Work hours per day | 14.0 | The owner's normal day |
| Overtime | Up to 4.0 more (18 total) | Each overtime hour adds fatigue |
| Minimum sleep | 6 hours | Sleeping less adds fatigue fast |
| Days off | 1 a week recommended | A day off clears fatigue; Gus's note: "Take Mondays. I never did. Look at me" |
| Weekly budget | 98 hours at 14 a day | About what a real owner-operator works |

Every task costs owner hours when the owner does it:

| Task | Owner hours | Better tools or staff |
| --- | --- | --- |
| Plant rounds (read and log) | 0.5 | 0.25 with the digital controller; 0.1 with remote monitoring (glance at the phone) |
| Ice check (screwdriver, three spots) | 0.2 | 0.05 with the IR gun; 0 with fixed slab probes |
| Resurface (warm-up, flood, dump snow, refill hot water) | 0.35 | Doris takes 15 minutes on the ice (`ResurfacerSim.RESURFACE_HOURS` 0.25); dumping and refilling is the rest |
| Intermission flood at a game | 0.35, at a fixed time | |
| Edging the whole sheet | 1.5 | 1.0 with a newer edger |
| Dressing room clean after a session | 0.25 per room | Rink rat |
| Washrooms and lobby clean | 0.5 a day | Rink rat |
| Counter (shop, rentals, tickets) | 1 per hour open | Shop clerk, Bev |
| Public skate guard and music | 1 per hour | Rink rat |
| Snow pit melt and drain check | 0.25 a day | |
| Phone call or email with an organisation | 0.25 | Booking coordinator |
| Daily paperwork (cash count, deposit, log) | 0.5 | Booking software halves it |
| A bid (prepare and send) | 1.0 | |
| A meeting (sponsor, coach, banker) | 1.0 to 2.0 | Can't be delegated until the assistant manager |
| An inspection | 2.0 | |
| Mini games | 0.5 to 16 (see section 4) | Staff or contractors |
| Playing your own hockey game | 3.0 (warm-up, game, the beer) | |
| A road game for the career | 3.0 plus travel on the region map | |

**Fatigue** is 0 to 100. It rises with overtime (5 per hour), short sleep (10 per
missing hour) and the night shift (3 per hour of desk work after 01:00), and
falls 25 with a full night's sleep and 40 with a day off. Effects:

| Fatigue | Effect |
| --- | --- |
| 0 to 40 | None |
| 40 to 70 | Mini game tolerances shrink 20%; instrument readings taken by the owner get 25% more error ("you misread the gauge") |
| 70 to 90 | A chance per job of a mistake (a forgotten gasket, a dropped bolt); the player's hockey `Progression.rest` treats the days as unrested |
| 90+ | The owner oversleeps and misses the 05:00 block once; Gus's binder has a note for this too |

Fatigue is how the hours budget bites without a hard wall: the player can
always do one more job, and pays for it.

### 2.2 Staff

Every job the owner does can be handed to someone, at a wage and with that
person's skill. Staff do jobs at their skill (an automatic result, the same
quality math as the mini game), or the player can still do the job themselves.

| Role | Who (first hire) | Wage | Available | Does | Can't do |
| --- | --- | --- | --- | --- | --- |
| Rink rat | Dylan Pruitt, 17, Millbrook High, "wants to drive Doris more than he wants to graduate" | $15/h, up to 20 h a week (school), 40 in summer | Week 2 (he asks) | Dressing rooms, washrooms, lobby, snow pit, skate rental, public skate guard, edging after 5 supervised edges, floods after 20 supervised floods | Plant, Doris repairs, money |
| Zambelli driver | Earl Bratt, 66, head icemaker since 1983 | $22/h, evenings and weekends, up to 30 h a week | Month 2, once the ice rating has stayed over 45 for two weeks ("You didn't kill her. Fine.") | Floods at skill 0.92, edging, ice painting, small Doris jobs. Sees soft spots by eye (his ice readings carry half the owner's error) | Plant. Won't drive any machine except Doris ("I'll drive a Flatley when they bury me in one") |
| Plant operator | Marguerite "Marg" Lindqvist, retired from the Harlow Falls plant | $32/h, 20 h a week, plus on call | Reputation Fair, or after the first compressor trip | Plant rounds, oil service, glycol tests, valve jobs at skill 0.85, the ammonia log the inspector wants | Doris |
| Shop clerk | Tyler Kowalchuk, Bev's grand-nephew | $15/h, weekends | When the counter is open more than 12 h a week | The counter and rentals | Sharpening |
| Bev | Beverly Kowalchuk, `PROSHOP.md` | $20/h plus 5% of shop sales | Any time after the first month; she has to like you first (a few visits) | Runs the shop counter full time, sharpening, buying advice: she raises shop sales 25% and shows the true value of a supplier deal | She won't work Sundays |
| Booking coordinator | Priya Sandhu, part-time | $24/h, 20 h a week | Facility score 35 or 20 contracts | Phone calls, the ice grid's routine changes, invoices and late payers | Bids over $10,000 a season |
| Concessions attendant | Various | $15/h | When the snack bar is REPAIRED | Concessions | |
| Maintenance tech | Hired from the trades college in Kessler | $28/h | Reputation Good | Building jobs (lights, plumbing, boards and glass), the edger, Doris service at skill 0.8 | Ammonia jobs |
| Assistant manager | Promoted or hired | $1,250 a week | Reputation Good, three or more staff | Meetings, routine negotiations, rosters; frees the owner for the big decisions | Loans, renovations, the GNHL |

Payroll overhead (taxes and insurance) adds 12% to wages.

Staff have three hidden stats shown through the owner's judgement (and more
accurately with a staff review): **skill** per job type, **reliability**
(chance of a late arrival or a skipped step) and **morale** (drops with
overtime, bad equipment and being ignored; rises with raises, new tools and
a winning home team). Skill rises with practice and with training courses
(Ice Technician course $450, Refrigeration Operator Class B $1,200 and 40
hours, first aid $120).

**Contractors** cover what staff can't, at a price, any time:

| Contractor | Rate | Quality | Lead time |
| --- | --- | --- | --- |
| Valley Refrigeration Services (Kessler) | $135/h plus $200 call-out; $250/h nights and weekends | 0.95 | Same day for a trip, a week for a booked job |
| Zambelli field service | $120/h plus travel ($1.20/km from Port Lucerne) | 0.97 on Doris | 3 to 5 days |
| Maple Tire & Muffler | Tires, belts, filters at counter price; $95/h shop labour | 0.85 | Same day |
| Harlow Falls Electric | $110/h | 0.9 | 2 days |
| Northern Line Painting (ice lines and logos) | $3,500 a sheet, logos extra | 0.95 | Book a month ahead for August |

### 2.3 The shift from hands-on to managing

The game moves from hands-on to managing because the hours run out, not
because a menu says so.

| Stage | Owner's typical week | What pushes the change |
| --- | --- | --- |
| Year 1 | 95 hours: 60 hands-on, 20 counter and cleaning, 10 office, 5 hockey | The plant trips at night and nobody else knows how to reset it |
| Year 2 | 85 hours: 35 hands-on (the hard jobs), 25 office, 15 meetings, 10 hockey | Dylan and Earl take the floods and cleaning; Bev takes the shop |
| Years 3 to 4 | 75 hours: 15 hands-on (the jobs the owner enjoys or nobody else can do), 30 management, 15 projects, 15 hockey | Marg takes the plant; the Senior AAA career needs two practices a week (`LeagueTiers` `practices_per_week` 2) and road games in Kessler |
| Year 5 on | 65 hours: 5 to 10 hands-on, 35 management, 20 hockey and travel | Semi-Pro and Minor Pro mean games every 3 to 4 days and away trips. The rink must run without the owner |

The hockey career is the natural clock for this: the higher the player
climbs, the less they are at Millbrook, so a rink that still depends on the
owner's hands starts to fail while they're on a bus to Port Ainsley.

The hands-on game never goes away. Any job can still be done by the owner,
and doing it yourself is cheaper, sometimes better (owner skill can pass
staff skill), and the only way to do it with the newest tools before staff
are trained on them. Late game the mini games become a choice the player
makes because they're fun, like Car Mechanic Simulator's restorations.

**Owner skill.** The owner has a skill (0 to 1) per discipline, starting
low and rising with each job done:

| Discipline | Start | Rises with | Effect |
| --- | --- | --- | --- |
| Icemaking (floods, edging, painting) | 0.6 | Floods and ice jobs | Flood quality (the `skill` input to `ResurfacerSim.resurface`), painting accuracy |
| Refrigeration | 0.3 | Plant jobs and rounds | Mini game tolerance windows, the "ear" reading's error shrinks with plant hours |
| Mechanic (Doris, edger, pumps) | 0.4 | Machine jobs | Mini game tolerance and speed |
| Building | 0.3 | Building jobs | Same |
| Business | 0.3 | Bids, negotiations, P&L reviews | Better first offers, reading an organisation's true budget |

Experience is itself a measurement upgrade. After 200 plant hours the ear
can tell a valve tick from a bearing knock; after 500 floods the owner can
read ice softness from Doris's seat.

---

## 3. The systems

Every physical thing in the rink follows one pattern:

1. **Hidden true state.** A `SimPart` condition 0..1 (1 new, 0 failed) plus
   physical values (a pressure, a temperature, a litre count).
2. **Wear.** Per operating hour or per cycle (a start, a flood), multiplied by
   stress (dirty oil, high head pressure, hard ice).
3. **Failure modes.** Each part has one or more ways to fail. A failure mode
   starts giving **symptoms** well before it fails, through sound, sight,
   smell, feel and readings.
4. **Readings.** The player only sees the state through an instrument
   (`SimInstrument`), which adds error. Crude instruments give words, better
   ones give numbers with tighter error bands, the best add new readings.
5. **Sub-parts.** What the mini game replaces. `RefrigerationPlant` today
   rolls them into one `SimPart` per assembly (one "valves" part per
   compressor); the mini games act on the sub-parts listed here, and the
   assembly's condition is the weakest sub-part (or a weighted mix, noted per
   table).
6. **Neglect.** What happens if the symptom is ignored.

### 3.1 The refrigeration plant

Millbrook has an indirect ammonia plant: ammonia boils in a chiller and cools
glycol, and the glycol is pumped through pipes in the concrete floor under the
ice. The ammonia stays in the plant room. This is how most older community
rinks work.

```
 [Compressor 1] [Compressor 2]   (plant room, beside the resurfacer bay)
        \          /
     discharge header ---> [Evaporative condenser on the roof] ---> receiver
        ^                                                              |
     suction <--- [Chiller: ammonia boils in the shell] <--- expansion valve
                     |  glycol through the tubes
                     v
               [Glycol pump] ---> supply header ---> 128 floor circuits ---> return header ---> chiller
                     ^ expansion tank, strainer, makeup water
```

#### Plant numbers

| Thing | Value | Notes |
| --- | --- | --- |
| Refrigerant | Ammonia (R-717), about 340 kg charge | Smell threshold about 5 ppm; detector alarm at 25 ppm; evacuate at 150 ppm; 300 ppm is immediately dangerous |
| Compressors | 2 x Nordale RC-4, 4 cylinders, 75 hp (56 kW) motor, 1,150 rpm | About 175 kW (50 tons) of refrigeration each, new (`RefrigerationPlant.COMPRESSOR_KW`) |
| Typical load | 200 to 300 kW in season, 350+ during ice-in and warm weather | One compressor carries a cold January night; both run most of the day |
| Suction pressure | 18 to 24 psig (evaporating at about -15 to -12 C) | Lower means the plant is working hard or the chiller is starved; higher means it can't keep up |
| Discharge (head) pressure | 125 to 160 psig in winter, 160 to 185 psig in summer (condensing at about 25 to 35 C) | High pressure cutout at 210 psig; a minimum of about 110 psig is held in winter so the expansion valve feeds properly |
| Discharge temperature | 90 to 120 C at the compressor outlet | High temperature trip at 135 C; worn valves run hot |
| Net oil pressure | 30 to 45 psi above suction | Low oil pressure trip below 10 psi net after 60 seconds |
| Motor current | 80 to 95 A at full load (460 V) | Rising amps at the same load means the compressor is working harder (head pressure, scale) |
| Glycol | Inhibited ethylene glycol, 30 to 38% by volume, target 35% | 35% freezes at about -21 C (`RefrigerationPlant.GLYCOL_TARGET`) |
| Glycol loop volume | 9,000 L (`RefrigerationPlant.LOOP_LITRES`) | Floor pipe, headers, chiller tubes, expansion tank |
| Glycol supply temperature | -9 to -7 C for hockey, -6 to -5 C for figure skating | `supply_temp` in the code |
| Glycol return temperature | 1.5 to 2.5 C warmer than supply | A big difference means low flow (pump, strainer, air) |
| Glycol flow | About 45 L/s (710 US gpm) | 15 kW pump |
| Glycol pH | 8.0 to 10.0 | Below 7.5 the inhibitor is spent and steel pipe corrodes |
| Floor | 1974 concrete slab, 128 circuits (256 steel pipes, 25 mm, at 100 mm centres) | End of life around 45 to 50 years |
| Electricity | The plant is about 60% of the rink's power | 1974 plant: about 75 kW average in season including pumps and fans |

#### Components, failure modes and symptoms

**Compressor (one table per machine; sub-parts sum to the `SimPart`s in
`RefrigerationPlant.create_old()`).**

| Sub-part | Life | Price | Failure mode | Symptoms | Neglect causes |
| --- | --- | --- | --- | --- | --- |
| Suction valve rings (4) | 6,000 to 12,000 h | $28 each | Cracked or worn ring, weak spring | A light ticking at the cylinder head, lower capacity (longer run times), suction pressure higher than it should be, one head cooler than the others | Capacity loss, then a broken ring fragment in the cylinder |
| Discharge valve plates (4) | 6,000 to 12,000 h | $32 each | Leaking plate | Hot head (feel or IR gun), high discharge temperature, falling capacity | High temperature trip; oil cooks and goes black |
| Valve springs and head gaskets | With the valves | $10 per cylinder; $11 per gasket | Weak spring, blown gasket | Ammonia smell at the head, frost line | Leak, inspector fine |
| Piston rings (2 compression + 1 oil per piston) | 20,000 h | $130 per piston set ($520) | Wear | Oil carry-over (oil level drops faster), blow-by (crankcase pressure rises), lower capacity | Oil logged in the chiller, which insulates it and cuts capacity |
| Main and rod bearings | 30,000 h | $880 set | Wear, wiped bearing | Knocking that gets worse under load, falling oil pressure, metal in the oil (lab analysis) | Seized crankshaft: a $9,000 to $14,000 overhaul by contractor and the compressor out for 2 weeks |
| Shaft seal | 9,000 h (2 to 4 years) | $260 kit | Worn carbon face, hardened O-ring | Oil drips under the coupling (a few drops an hour is normal, a puddle is not), ammonia smell at the coupling | Oil loss, then low oil trip; an ammonia leak |
| Oil | 1,500 full-duty hours in this old machine; 4,000 with a good filter and clean system | $105 per 20 L pail (ISO 68 refrigeration oil), compressor holds 30 L | Breakdown, water and ammonia contamination, sludge | Sight glass amber to dark to black, oil pressure drift | Every other part wears 1 to 3 times faster (`stress` in the code: `1 + 2 x (1 - oil)`) |
| Oil filter | 1,000 h | $38 | Clogged | Oil pressure difference across the filter rises (needs gauges either side, upgrade) | Bypasses, dirty oil reaches bearings |
| Suction strainer screen | Clean each oil change | $60 if torn | Clogged | Suction pressure at the compressor lower than at the chiller | Starved, hot compressor |
| Capacity unloaders | 15,000 h | $95 per cylinder | Stuck loaded or unloaded | Compressor short cycles or won't unload at start (high starting amps, the lights dim) | Motor starter wear, trips |
| Motor | 60,000 h | Rewind $4,500 | Insulation breakdown, bearings | Hot motor, a hum, the breaker trips | Burned motor |
| Coupling insert | 8,000 h | $45 | Worn rubber | Clunk on start, black rubber dust under the guard | Misalignment, then the shaft seal wears faster |

Code note: `create_old()` starts compressor 1 at condition 0.55 and 2 at 0.7;
that is right for the story (1 is "the grumpy one").

**Chiller (shell and tube, flooded).**

| Sub-part | Life | Price | Failure mode | Symptoms | Neglect causes |
| --- | --- | --- | --- | --- | --- |
| Tubes | 40 years | Retube $30,000 | Freeze split (glycol too weak or flow stops while the compressor runs), corrosion | Ammonia in the glycol (a pH jump, the expansion tank smells), glycol in the ammonia | Catastrophe: weeks with no ice. The worst event in the game |
| Oil pot | Drain weekly | Free | Oil collects in the chiller (ammonia oil doesn't return on its own) | Capacity falls slowly, suction pressure drops | Oil-logged chiller, 10 to 30% capacity lost |
| Level control (float and expansion valve) | 20,000 h | $650 | Sticks | Suction pressure swings, frost on the suction line, liquid knocking at the compressor (slugging) | A slug breaks valve rings or a safety head |

**Evaporative condenser (rooftop, 1974 Boreal Aire, with a fill pack under
the coil).**

| Sub-part | Life | Price | Failure mode | Symptoms | Neglect causes |
| --- | --- | --- | --- | --- | --- |
| Fan belts (2 x B68, matched) | 3,000 h (1 to 2 years) | $24 each | Stretch, glazing, snap | Squeal at start, fan slower, head pressure up 10 to 20 psig; a snapped belt means the fan stops and head pressure climbs fast | High pressure trip in summer; the code drops capacity to 45% with the belt failed |
| Fan bearings | 20,000 h, grease every 3 months | $85 each | Dry, rumble | Rumble, warm housing | Seized fan |
| Spray pump (3 hp) | 25,000 h | $1,100 rebuilt; seal $90 | Seal leak, worn impeller | Dry patches on the coil, head pressure up | Scale bakes onto the dry coil |
| Spray nozzles (64) | Clog with scale | $6 each | Blocked | Uneven spray (seen from the roof hatch) | Scale |
| Coil and fill scale | Builds per running hour, faster with poor water treatment | Descale $400 of chemicals, fill pack $180 each (12 packs) | Scale layer | Head pressure and amps creep up over weeks, white crust visible | Everything in the plant works harder (`condenser_scale` in the code) |
| Basin, float valve, heater | Float $85, heater $320 | | Freezing in January, stuck float | Overflow or a dry basin; ice on the roof | A frozen basin stops the spray |
| Water treatment | Chemicals $90 a month | | Conductivity too high (scale) or bacteria (Legionella) | Conductivity above 2,500 uS/cm; slime | Scale; a health inspection fail and a forced shutdown |

**Glycol loop.**

| Sub-part | Life | Price | Failure mode | Symptoms | Neglect causes |
| --- | --- | --- | --- | --- | --- |
| Glycol concentration | Falls when the auto-fill tops up leaks with water | Concentrate $4.80/L | Diluted | Refractometer reading drops; on the old system there's no symptom at all until it's dangerous | Below 25% the chiller can freeze at night setback. The hidden killer |
| Inhibitor and pH | 2 to 3 years | Booster $450 a pail | Spent | pH below 8, glycol turns brown (rust) | Pipe and header corrosion, pinhole leaks |
| Pump bearings | 15,000 h (3 to 5 years) | $190 the pair | Wear | Growl, hot bearing housing (over 80 C is bad), vibration over 7 mm/s | Seized pump: no flow, the ice warms within hours |
| Pump mechanical seal | 12,000 h | $150 | Worn faces | Drips (a drop a minute is normal), crystals of dried glycol around the gland, a puddle | Glycol loss, air drawn in |
| Strainer | Clean every 3 months | Basket $140 | Clogged | Return temperature difference rises, pump amps drop | Low flow, warm spots |
| Air in the loop | After any drain or leak | | Air pockets | Gurgling in the header, a warm stripe in the ice | Warm stripes, pump cavitation |
| Expansion tank and makeup valve | | Valve $75 | Makeup valve passing | Tank level steady while glycol strength falls | Dilution (see concentration) |
| Headers and jumper hoses (256 hoses with clamps) | Hoses 15 to 25 years; header 50 | Hose $14, clamp $1.50, header weld $1,800 | Perished hose, rusted clamp, cracked weld | Expansion tank falling (litres a day), wet trench, sweet smell, a soft or pink spot near the end boards | Glycol loss, dilution, a soft end of the rink (`header` in the code leaks with age) |
| Floor pipes | 45 to 50 years | Cap a circuit $300; a new floor $650,000 | Corroded pinhole | Same as a header leak but nowhere in the trench | A dead circuit, then several: warm stripes, cancelled ice |
| Subfloor heating (frost heave protection) | | | Off or failed | Nothing for months, then the floor heaves and cracks | A heaved floor. Old Gus note: "If the heat loop pump stops, call me. Wherever I am." |

**Controls.** In 1974: pressure switches, a clock timer for night setback, a
thermostat bulb in the return glycol. Upgrades in 5.9.

| Part | Life | Price | Failure | Symptom |
| --- | --- | --- | --- | --- |
| Pressure switches (high, low, oil) | 20 years | $180 each | Drift | Trips at the wrong pressure, or doesn't trip at all (found by testing, or by an accident) |
| Setback timer | | $90 | Wrong time after a power cut | Plant warm when the 06:00 figure skaters arrive |
| Return glycol thermostat | | $140 | Drift | Ice slowly too warm or too cold |
| Ammonia detector (fixed) | Calibrate yearly | $2,400 new; calibration $250 | Drift | The inspector's test fails |
| Pressure relief valves | Replace every 5 years | $380 each, 4 of them | Age | None. The inspector checks the date |

#### Plant readings

| Reading | Unit | Starting instrument (error) | Upgrades (error, price) |
| --- | --- | --- | --- |
| Suction pressure | psig | Dial gauge on each compressor (+/- 5 psig, sticks; tap it) | Calibrated test gauge (+/- 1, $140); digital controller transducer (+/- 0.5, part of the controller) |
| Discharge pressure | psig | Dial gauge (+/- 5) | As above |
| Oil pressure | psi | Dial gauge (+/- 4) | As above |
| Oil quality | 0..1 | Sight glass: "clear, amber, dark, black" (`SimInstrument` `oil_quality` tier 0) | Oil lab analysis (+/- 0.03, $60 a sample, 5 days, also reports wear metals) |
| Compressor health | 0..1 | "It sounds rough" (`compressor_health` tier 0, error shrinks with owner plant hours) | Mechanic's stethoscope ($35, names the cylinder); vibration pen (+/- 0.08, $450); oil analysis (+/- 0.03) |
| Discharge temperature | C | Hand on the head pipe ("too hot to touch" above 60 C) | IR gun (+/- 0.5 C, $89); controller probe (+/- 0.3) |
| Motor amps | A | The dim of the lights when it starts | Clamp meter (+/- 1 A, $120); controller |
| Glycol supply and return | C | Old dial thermometer (`brine_temp` tier 0, +/- 1.5) | Digital controller (+/- 0.2, $3,800 in the code) |
| Glycol concentration | % | Nobody's checked (+/- 12) | Hydrometer (+/- 3, $35); refractometer (+/- 0.5, $180) |
| Glycol pH | pH | None | Test strips (+/- 0.5, $25 for 100); pH meter (+/- 0.05, $140) |
| Glycol level | L | Expansion tank sight glass ("about half") | A level stick and the log book (+/- 50 L); controller level sensor (+/- 10 L) with a daily trend |
| Condenser water conductivity | uS/cm | None | Conductivity meter (+/- 50, $160); automatic treatment controller (holds it) |
| Fan belt condition | 0..1 | Squeal, a look | Belt tension gauge ($30); the controller's fan amps |
| Ammonia in the air | ppm | The nose (5 ppm and up, "a whiff", "eyes watering", "get out") | Handheld detector (+/- 2, $650); fixed detection (required by inspection) |
| Leak location | | Sulphur stick (white smoke near ammonia, $15 a box) and phenolphthalein paper (turns pink) | Handheld detector; ultrasonic leak detector ($900) |

Readings are only taken when someone takes them. The log book is the
player's memory: a reading written down every morning gives a trend, and a
trend is how a creeping discharge pressure or a falling glycol level is
spotted early. If nobody logs for a few days the trend has a gap, and the
ammonia inspector asks why.

#### The compressor problem (Sean, 2026-10-17)

The plant is a logistics problem of its own. The new owner learns in the
first week that compressor 1 is near the end of its life, and the whole
first year hangs over that: rebuild it again, replace it like for like, or
use the replacement to change refrigerant. Code: `PlantCatalog`
(`scripts/world/sim/plant_catalog.gd`) and the "compressor problem" functions
on `RinkSim`.

**Compressor packages** (`PlantCatalog.COMPRESSORS`):

| Id | Package | kW | Efficiency | Price | Lead time | Out for | Contractor | Runs on | Parts last |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `nordale_rc4` | Nordale RC-4, 1974 reciprocating (what Millbrook has) | 175 | 0.85 | | | | | ammonia, R-22 | 1x |
| `nordale_rc6` | Nordale RC-6, new reciprocating; fits the old skid | 200 | 1.0 | $38,000 | 6 weeks | 4 days | $9,000 | ammonia, R-22, R-507A | 1.6x |
| `frostline_fs90` | Frostline FS-90 screw; efficient at part load, needs a new oil separator and starter | 260 | 1.08 | $92,000 | 12 weeks | 7 days | $18,000 | ammonia, R-507A | 2.5x |
| `kryomax_co2` | Kryomax CO2 transcritical rack; replaces compressors, chiller and receiver | 300 | 1.12 | $240,000 | 20 weeks | 21 days | $60,000 | CO2 | 2.5x |

**How a replacement goes:**

1. **Quote** (`quote_compressor`): the rep's price, deposit, lead time, install
   days and which refrigerants the machine takes.
2. **Order** (`order_compressor`): 30% deposit now. Freight is always late,
   so delivery is the lead time plus up to a day per week of lead.
3. **Delivery**: the balance is due when it lands on a flatbed in the parking
   lot (`delivered`). It waits there until the player books the install.
4. **Rental chiller** (`rent_chiller`, $1,200 delivery plus $650 a day, 180
   kW): keeps the ice in while a compressor is out. Without one, one old
   compressor carries the rink and the evening's ice suffers.
5. **Install** (`job("install_compressor")`): 4 owner hours to supervise; the
   contractor's crane, rigging, pipework, charging and testing take the
   compressor out for the install days. Best done in the summer shutdown.
6. **Commissioning**: the new parts start at 0.85 to 1.0 condition depending
   on the owner's supervision (`quality`).

**Refrigerants** (`PlantCatalog.REFRIGERANTS`): cost, safety and performance.

| Id | Refrigerant | Efficiency | Refill | Safety | The catch |
| --- | --- | --- | --- | --- | --- |
| `ammonia` | Ammonia (R-717), 340 kg | 1.15 (best) | $4/kg | Toxic: a seal that lets go empties the building, cancels the day, costs a $2,500 fine and reputation | $1,800 a year of inspection and an operator certificate |
| `r22` | R-22 (Freon), 900 kg | 1.0 | $95/kg, rising 60% a year; none to buy from Year 3 | Harmless to people | Phase-out: every leak gets dearer until the plant can't be refilled at all. Harlow Falls' story |
| `r507` | R-507A (HFC), 800 kg | 0.93 | $38/kg, rising 8% a year | Harmless to people | Costs the most power; a climate levy of $30 per kg leaked from Year 4 |
| `co2` | CO2 (R-744), 450 kg | 1.08 | $3/kg | Very high pressure, otherwise benign | Only the Kryomax rack runs it. Recovers half the plant's heat for flood water and the lobby (credited at $0.06 a kWh of gas) |

Converting (`job("convert_refrigerant")`) needs every compressor to support
the new refrigerant, costs the new charge plus $15,000 of contractor work,
and takes the whole plant down for ten days. Refrigerant leaks slowly from
worn shaft seals and old joints (`charge`); below about 85% charge the
chiller starves and capacity falls. `job("recharge_refrigerant")` tops it up
at that year's price.

The sensible paths: rebuild the RC-4s for a year or two while saving; an
RC-6 for compressor 1 in the first summer; a screw compressor once the
Lumber Kings sign; a CO2 conversion as the big late-game renovation (it
pays back in power, gas and inspections, and it is what the GNHL rinks
have). The drama path: Harlow Falls stays on R-22 too long and goes dark
for a month the winter its refills run out.

The plant room props for all of this (compressor packages, chiller,
receiver, pumps, header, pipe pieces, condenser, control panel, safety
station) are in `scripts/art/props.gd`; see `docs/ART.md`, "Plant room".

### 3.2 The ice slab

`IceSlab` today: one surface temperature, one thickness, smoothness,
cleanliness, paint. The design adds a coarse **grid** so ruts, soft spots,
edges and thickness can vary across the sheet: 20 cells along the rink by 8
across (each about 3.05 x 3.24 m), plus a ring of edge cells along the boards.
The sheet-wide values `IceSlab` already has stay as averages over the grid.

#### Ice numbers

| Thing | Target | Notes |
| --- | --- | --- |
| Surface temperature, hockey | -5 to -7 C (code target -5.5) | Hard, fast. Colder than -7 the ice gets brittle and chips |
| Surface temperature, figure skating | -3 to -4 C (code -3.5) | Softer, so jumps land and toe picks grip |
| Surface temperature, public skating | -4 to -5 C (code -4.5) | |
| Curling | -4 to -5 C, with pebble | Needs a level sheet within 3 mm |
| Thickness, hockey | 25 to 34 mm (1 to 1 3/8 in) | Hard, fast, dry. See "Thin ice or thick ice" below |
| Thickness, figure skating | 36 to 50 mm (1 1/2 to 2 in) | Holds deep edges without skidding |
| Paint layer | White base about 1 mm, 3 mm (1/8 in) from the concrete | Shaved through when the ice gets thin |
| Flood water | 55 to 60 C, about 450 L a flood (`ResurfacerSim.FLOOD_LITRES`) | Hot water drives out air and bonds to the old surface; 450 L over 1,586 m2 is about 0.3 mm |
| Shave per flood | 0.5 to 1 mm | Set by the blade (mini game 4.6) |
| Snow made per hour of hockey | About 0.6 m3 | Doris's snow tank holds about 2.5 m3 |
| Building air | 10 to 15 C, dew point below 0 C, relative humidity 40 to 50% | Above the ice-surface dew point, fog forms and the ceiling drips |
| Lighting | 500 lux worn (1970s metal halide), 1,000 lux renovated (LED), 1,500+ for TV | Old lamps put about 30 kW of heat on the ice |

#### Thin ice or thick ice (Sean, 2026-10-17)

| | Thin (25 to 32 mm) | Thick (40 mm and up) |
| --- | --- | --- |
| Plant power | Less: the pipes reach the surface (`IceSlab.insulation()`) | More: each extra 16 mm costs about 7% of the rink's kWh |
| Surface | Colder and harder for the same brine; fast | Softer; holds deep, sharp turns without skidding |
| Thermal mass | Little (`heat_capacity_mj()`): warms quickly when the plant trips or the lights are hot, melts faster | Lots: stays cold through a trip, melts slowly |
| After a flood | Dries fast (about 13 min at 32 mm) | Slow to freeze in (about 19 min at 48 mm, 31 at 60) (`dry_minutes()`) |
| Wear | Deep gouges reach the soft layer and the paint (`gouge` in `run()`) | Takes a beating |
| Who wants it | Hockey: bone dry the second their window starts | Figure skaters |

Wet ice is the friction: `wetness()` runs from 1 just after a flood to 0
when it has frozen in. Hockey loses up to 60% of its rating on wet ice,
public skating 30%, figure skating 20% (`IceSlab.WET_PENALTY`), and a group
that waits at the gate for the ice to dry loses satisfaction. Doris goes out
`RinkSim.RESURFACE_LEAD_MIN` (30 minutes) before a booking, so thin ice is
dry in time and thick ice only just. Back-to-back bookings with a quick
flood between them are where thick ice hurts, and where the figure club
and the hockey groups pull the owner in opposite directions.

Starting state for Millbrook: average thickness 48 mm (Earl likes it thick,
and the first goal, getting it down to 32 mm, pays off on the power bill), 12 mm
higher along the boards than at centre, a 6 mm low spot at the home blue
line where the roof drips in spring, surface around -4 C.

#### Hidden ice state

| Value | Range | Changes with |
| --- | --- | --- |
| `surface_temp` per cell | -14 to +2 C | Plant cooling, building heat, lights, skaters, flood water (the existing heat model) |
| `thickness_mm` per cell | 0 to 80 | Floods add, blades shave, edges build up, melt |
| `smoothness` per cell | 0..1 | Skater-hours carve it (more on soft ice), floods restore |
| `ruts` per cell | 0..1 | Deep cuts that one flood doesn't remove: corners, the creases, faceoff dots |
| `snow` per cell | 0..1 | Skating makes it; a flood clears it |
| `cleanliness` | 0..1 | Tape, puck marks, rust, mud from the lobby door |
| `paint` per cell | 0..1 | Fades as the white base and lines are shaved through |
| `edge_buildup_mm` per edge cell | 0 to 30 | Water runs to the boards and the blade can't reach; edger removes it |
| `level_mm` per cell | Deviation from a flat sheet | The floor's own heave plus uneven ice |
| `air_bubbles` | 0..1 | Cold or untreated flood water: cloudy, weak ice |
| `hardness` | Derived from temperature | |

#### Ice rating

`IceSlab.rating(use)` is the score organisations judge: 0 to 100, from
surface temperature against the use's target, smoothness, cleanliness,
thickness and paint. The design adds:

| Term | Weight | From |
| --- | --- | --- |
| Temperature against target for this use | 0.30 | Code |
| Smoothness, worst-quarter weighted (players notice the bad spots) | 0.25 | Code, plus grid |
| Snow at the start of the session | 0.10 | New: a skipped flood |
| Cleanliness | 0.10 | Code |
| Thickness | 0.10 | Code |
| Levelness and edge buildup | 0.08 | New |
| Paint | 0.07 | Code |

The rink's **ice reputation** (`ice_rep` in `RinkContracts.offers`) is the
average of `rating(use)` sampled at the start and the middle of every booked
session in the last 28 days, weighted by session hours. It uses the true
values: organisations skate on the real ice, not on the player's readings.

#### Ice readings

| Reading | Starting instrument | Upgrades |
| --- | --- | --- |
| Surface temperature | Screwdriver test (+/- 2.5 C, words: "rock hard, hard, about right, soft, slush") | IR gun (+/- 0.5, $89); slab temperature probes (+/- 0.15, $1,400, live readings at 6 points); overhead IR sensors with the controller (whole sheet) |
| Thickness | Drill and ruler (+/- 5 mm, 2 minutes a hole, only where you drill) | Ice thickness gauge (+/- 1.5, $220, 30 seconds a hole); laser level survey (+/- 0.5, $2,600, maps every cell in an hour); ultrasonic thickness scanner on Doris (late, +/- 1 mm, whole sheet every flood) |
| Levelness | Eye and a string line | Laser level ($1,200 basic, $2,600 with survey software) |
| Smoothness and ruts | Walk it and look ("chewed up at the dots") | Floodlight raking shot (a work light held low, free once Gus's note teaches it); the ice-mapping software with the laser |
| Snow | Look | |
| Air humidity | A wet finger and the fog | Wall hygrometer (+/- 5% RH, $40); dew point sensor with the controller |
| Lighting | "Dim at the far end" | Light meter (+/- 5%, $95) |

#### What neglect does to the ice

| Neglect | Result |
| --- | --- |
| Skip floods | Snow and ruts; the session's rating drops 10 to 25 points; minor hockey coaches complain on the second time |
| Ice too warm | Soft, slow, deep ruts; a 3 mm rut at a faceoff dot catches a skate; a figure club is happy, hockey isn't |
| Ice too cold | Brittle, chips, pucks bounce; the power bill rises |
| Ice too thick | Soft surface despite a cold floor; bills up 10 to 15% per extra inch |
| Ice too thin | Shaved through to the paint (white turns grey), then to the concrete: a hole, and the session is cancelled |
| Edges not cut | A lip at the boards that catches skates and kills pucks; the rink looks like a soup bowl from the stands |
| Dirty flood water or a torn towel | Streaks, water lines, cloudy ice |
| Fog (spring) | Water drips from the ceiling and freezes into bumps; the dehumidifier saves it |

### 3.3 Doris, the Zambelli Model 525

Doris is a 1974 gas Model 525 (`ResurfacerSim.create_doris()`): a 2.3 L
four-cylinder Hawthorne engine with points ignition and a carburettor, a
hydraulic conditioner, an 840 L water tank (flood and wash water), a 2.5 m3
snow tank and studded tires. A resurface takes about 15 minutes.

#### How a flood works (what the sim models)

1. The **blade** (77 in, 1.96 m) shaves 0.5 to 1 mm off the surface.
2. The **horizontal auger** pulls the shavings to the centre, the **vertical
   auger** lifts them into the snow tank.
3. The **wash water** bar sprays dirty ice ahead of the squeegee; the
   **squeegee** collects it to be vacuumed back.
4. The **flood water** spreader pipe lays hot water and the **towel** spreads
   it into a thin even film.
5. The driver's pattern decides coverage: overlaps, the corners, water on
   and off at the right moment.

#### Components

| Part (code id) | Life | Price | Failure mode | Symptoms | Neglect causes |
| --- | --- | --- | --- | --- | --- |
| Blade (`blade`) | 30 resurfacing hours, about 120 floods (code); half that on hard ice | $160 new, $45 resharpen | Dull, chipped, set at the wrong height | Snow ribbon thin or uneven, a "washboard" chatter, ridges left behind | Poor shave, ruts stay, ice gets thick |
| Spark plugs (`spark_plugs`) | 400 h | $28 a set | Fouled, worn gap | Hard starting, misfire (a stumble on acceleration) | Won't start (`fault()` "won't start") |
| Air filter (`air_filter`) | 250 h | $22 | Clogged | Black smoke, rich running, more CO | Poor power, CO in the arena |
| Points and condenser | 300 h | $32 | Pitted points, dwell drift | Misfire, timing drifts | Rough running, more CO |
| Distributor cap, rotor, plug wires | 1,000 h | $46, $55 | Cracked, tracking | Misfire in damp weather (every April) | Won't start in fog |
| Engine oil and filter | 120 h (code `engine_oil`) | $34 oil, $12 filter | Sludge | Dark dipstick, oil pressure light flickers at idle | Seized engine (`fault()` "seized"): a $6,500 rebuild |
| Carburettor | Adjust each tune-up; rebuild kit $65 | | Rich or lean | CO high, stalling, black smoke | Air quality inspection fail |
| Towel (`towel`) | 60 h | $85 | Frayed, stiff with old ice | Streaks and lines in the flood, water left in ridges | Lined, wavy ice |
| Squeegee (`squeegee`) | 180 h | $55 | Torn, worn | Dirty wash water left on the ice: grey streaks | Dirty, cloudy ice |
| Horizontal auger bearing (`auger_bearing`) | 900 h | $120 | Dry, worn | Grinding at the conditioner, snow spilling out the sides | Seized auger, flood abandoned mid-way |
| Vertical auger and flighting | 2,000 h | $380 | Worn flights | Snow tank fills slowly, snow left on the ice | |
| Hydraulic hose (`hydraulic_hose`) | 1,500 h | $95 | Burst | Wet hose, a slow conditioner lift, then a fountain of oil | `fault()` "hydraulic leak": oil on the ice, a stained patch to cut out |
| Hydraulic pump and fluid | 5,000 h; fluid 1,000 h | $900; $60 | Wear | Slow lift, whine | |
| Water tank and valves | | Valve $140 | Leaking valve | Drips trail on the ice in the bay | Bumps where she drips |
| Tires (`tires`) | 2,500 h | $640 a set | Studs worn | Sliding in the corners | A wall hit: board damage $400 |
| Fuel | A tank does about 22 floods | Gas $1.60/L, about 1.5 L a flood | Empty | Gauge, or the engine dies | `fault()` "out of gas", mid-flood if unlucky |
| Brakes | 3,000 h | $180 | Worn | Longer stopping | Boards |

#### Doris readings

| Reading | Starting | Upgrades |
| --- | --- | --- |
| Blade sharpness | Thumbnail test (words: "butter knife", "fair", "sharp") | Blade edge gauge ($75, +/- 0.05); edge inspection light |
| Blade height | Eye on the bay floor | Feeler gauges (+/- 0.05 mm, $18); dial blade-setting gauge ($180, +/- 0.02); laser blade jig ($650) |
| Engine health | Ear, smoke colour | Compression tester ($60, per cylinder); timing light and dwell meter ($110); exhaust gas analyser ($850, CO %) |
| Engine oil | Dipstick ("honey, tea, coffee, tar") | Oil lab sample ($40) |
| Flood quality | Look at the ice afterwards | Ice-mapping laser, the IR gun on fresh water (shows a warm stripe where the towel is dry) |
| CO and NO2 in the arena | Headaches, "feels stuffy" | Handheld CO meter ($180, +/- 3 ppm); fixed CO/NO2 monitor with the controller ($1,600) |

Indoor air is where Doris meets the inspector: a gas resurfacer and a gas
edger put carbon monoxide and nitrogen dioxide into the arena. Limits in the
game: CO 25 ppm one-hour average (fail above 30), NO2 0.3 ppm. A badly tuned
Doris on a cold night with the doors shut can reach 60 ppm. Ventilation (the
roof exhaust fan) helps, a tune-up helps more, a propane conversion ($3,800)
or a Flatley electric replacement ends the problem.

### 3.4 The edger

A 1988 walk-behind edger with a 5.5 hp engine and a 16 in cutting disc with
4 carbide blades.

| Part | Life | Price | Symptom |
| --- | --- | --- | --- |
| Carbide blades (set of 4) | 40 h | $95 | Chatter, a rough cut |
| Spark plug | 100 h | $6 | Hard starting ("third pull" becomes "ninth pull") |
| Pull cord | Whenever | $9 | Snapped |
| Drive belt | 200 h | $16 | Slipping |
| Engine oil | 25 h | $8 | Smoke |

Edging is needed when `edge_buildup_mm` passes 6 mm (weekly at Millbrook's
busy times).

### 3.5 The building

Each building system links to `Venue` room ids (shell, roof, stands_bench,
stands_box, benches, penalty_boxes, glass, lobby, office, locker_home,
locker_away, zamboni_bay, lighting, scoreboard). Rink environment would need
a `plant_room` room for the compressor room and the header trench; that is
the one room this design asks for.

| System | Room | Key parts and life | Failure symptoms | Neglect causes |
| --- | --- | --- | --- | --- |
| Dehumidifier (desiccant, 1990s) | shell | Wheel 10 years ($6,000), filters 3 months ($45), burner | Fog over the ice, ceiling drip, damp lobby | Drip bumps on the ice, rusting roof steel |
| Boiler (gas, heats dressing rooms, showers, flood water) | zamboni_bay | Burner service yearly ($350), circulator pump 10 years ($600), tank anodes 3 years ($80) | Lukewarm showers, flood water below 50 C | Cold showers (dressing room complaints), cloudy floods |
| Flood water heater | zamboni_bay | 380 L gas tank, elements, thermostat | Water under 55 C | Bubbly, weak ice |
| Lighting | lighting | 48 metal halide lamps, 10,000 h, $65 each, ballast $140; a lift rental $250 a day | Dim, flickering, a dark corner | Lux too low for contracts; one lamp dies every two weeks |
| Roof | roof | Membrane 25 years; patch $600; reroof $250,000 | Drips onto the ice in thaws (the home blue line) | Ice bumps, rot, ceiling tiles falling |
| Washrooms | lobby | Valves, flush kits $35, partitions | Running toilet (water bill), out of order signs | Health inspection points, reputation |
| Dressing rooms | locker_home, locker_away | Showers, benches, rubber floor, hooks | Mould, broken hooks, cold showers | Teams ask for the other room; contract minimums |
| Stands | stands_bench, stands_box | Seats (broken ones out of service), railings | Broken seats | Fewer usable seats; fire inspection fail on railings |
| Boards and glass | glass, benches, penalty_boxes | Board kickplate, glass panels $480 each, gate latches | Cracked glass, a dead board (the Millbrook bank stays unless the player fixes it on purpose, `LORE.md`) | Safety inspection fail, a contract walk-out |
| Scoreboard | scoreboard | Bulbs, the controller board | One side dead (`TEAMS.md`: "a scoreboard that only works on one side") | Embarrassment; Senior AAA needs both sides |
| Snow pit and floor drains | zamboni_bay | Melt pit heater, drain | Snow piles up in the bay | Doris can't dump; floods late |
| Concessions | lobby | Coffee machine, fryer, cooler | Broken coffee machine (the most urgent repair in the game, per the town) | Lost concessions, health points |
| Ventilation | shell | Exhaust fan and damper | Stuffy air, CO builds | Air quality fail |

**Facility score** (`min_rooms` in `RinkContracts`) is 0 to 100, from room
ages and condition:

| Room weight | Rooms |
| --- | --- |
| 3 | locker_home, locker_away, lobby (with washrooms) |
| 2 | stands_bench, stands_box, lighting, glass, shell (air and dehumidifier) |
| 1 | roof, benches, penalty_boxes, scoreboard, office, zamboni_bay |

| Age | Base points per room |
| --- | --- |
| WORN | 15 |
| REPAIRED | 55 |
| RENOVATED | 95 |

Each room's points move +/- 10 with cleanliness and with broken things inside
it. Millbrook starts around 18.

---

## 4. Mechanical mini games

### 4.1 How every mini game works

Each job is a hands-on scene in the real room (the plant room, the bay, the
roof, the ice) in first person, with the part on a bench or in place. It
borrows Car Mechanic Simulator's structure: look, diagnose, order, strip,
replace, rebuild, test. And PowerWash Simulator's satisfaction: grime comes
off, scale comes off, a clean part is visibly clean, and the before/after
reading is the reward.

**Phases.**

| Phase | What the player does | Costs |
| --- | --- | --- |
| Trigger | A symptom, a reading, a schedule (Gus's binder or the service plan), an inspection, or a failure | |
| Diagnose | Use senses and instruments on suspects. Each check costs minutes. The diagnosis board (a clipboard) lists suspects with the evidence for and against | Minutes per check; a wrong teardown costs hours and a gasket |
| Order | Pick parts from the supplier catalogue (shelf stock is instant) | Money; lead time; wrong parts are returned with a 20% restocking fee |
| Prepare | Safety first: lockout, isolation, PPE | Skipping a safety step is allowed, and sometimes punished (a fine, an injury, an ammonia release) |
| Procedure | Steps on the part: unbolt, remove, clean, measure, fit, torque, adjust | Minutes; tolerances |
| Test | Start it up, read the instruments, listen | |
| Result | A quality 0..1 per part fitted, passed to `SimPart.replace(quality)`, plus flags for hidden mistakes | |

**Interaction verbs.** Every mini game uses the same small set of verbs so
they feel like one game: grab and remove (bolts, parts), use tool on target
(wrench, scraper, gauge), measure (gauge reads with its error), adjust (turn
a screw while watching a reading), torque (hold the click: a torque wrench
fills a dial and clicks; old tools need feel), clean (PowerWash-style
brushing or spraying until the dirt mask clears), pour or pump (a level
rises in a sight glass), and inspect (a close-up with the work light).

**Quality math.** Each step that matters has a target and a tolerance.
Quality = the product of step scores, each from 0.7 to 1.0 (a step at the
edge of tolerance scores 0.85, out of tolerance scores 0.7 and sets a flag).
Skill widens tolerances (owner skill 0.3 gives the base window, 0.9 gives
1.6 times it). Better tools narrow the reading error, so the player can see
whether they're actually in tolerance.

**Hidden mistake flags** (applied to the sim, not shown until they bite):
`gasket_reused`, `bolt_undertorqued`, `bolt_overtorqued`, `dirt_in_system`,
`air_not_bled`, `misaligned`, `wrong_oil`, `not_locked_out`, `not_purged`,
`seal_face_touched`. Each adds wear or a delayed failure (a leak in 2 to 20
days, a bearing that lasts a third of its life).

**Doing it with staff or a contractor.** The same job can be auto-resolved
at the worker's skill: hours pass, money leaves, quality comes from the same
math with the worker's skill and random mistakes from their reliability.

### Mini game list

| # | Job | Where | Typical trigger | Owner hours | Parts cost |
| --- | --- | --- | --- | --- | --- |
| 4.2 | Compressor oil and filter service | Plant room | Dark oil, hours, low oil pressure | 2.5 | $250 |
| 4.3 | Compressor valve job | Plant room | Lost capacity, hot head, ticking | 6 to 8 | $480 a machine |
| 4.4 | Glycol concentration test, top-up and flush | Plant room | Monthly test, falling level, a leak repaired | 0.5 test, 3 top-up, 3 days flush | $25 to $15,000 |
| 4.5 | Glycol pump bearing and seal | Plant room | Growl, heat, drips | 6 | $340 |
| 4.6 | Condenser fan belt and descaling | Roof | Squeal, high head pressure, summer | 1 belt; 12 descale | $48; $1,500 |
| 4.7 | Resurfacer blade change and height setting | Resurfacer bay | Dull blade, chatter, ruts stay | 1 | $160 |
| 4.8 | Resurfacer engine tune-up | Resurfacer bay | Hard starting, CO, hours | 3 | $210 |
| 4.9 | Conditioner squeegee and towel | Resurfacer bay | Streaks, lines, dirty ice | 1.5 | $140 |
| 4.10 | Ice edging and leveling | Ice | Edge buildup, thickness survey | 1.5 to 6 | $0 to $95 |
| 4.11 | Painting lines and logos at ice-in | Ice | August, yearly | 4 days | $2,400 |
| 4.12 | Header leak hunt | Header trench | Falling glycol level, a soft end | 2 to 10 | $20 to $1,800 |

Smaller jobs use the same verbs without a full scene: replace a lamp from a
lift, fix a running toilet, swap a glass panel, change Doris's tires, drain
the chiller oil pot, grease the fan bearings, clean the glycol strainer,
sharpen skates on Old Bertha.

### 4.2 Compressor oil and filter service

**Trigger.** Gus's binder ("oil every 1,500 hours or when it goes dark, and
number 1 goes dark in a thousand"), the log book's run hours, the sight
glass reading dark or black, net oil pressure drifting below 25 psi, or an
oil lab report showing acid or water. Also the first real job of the
tutorial week.

**Diagnosis.**

| Suspect | Evidence for | Check (time) |
| --- | --- | --- |
| Oil worn out | Sight glass dark, smell burnt, hours since last change | Sight glass (1 min); draw a sample for the lab ($60, 5 days) |
| Low oil level (leak or carry-over) | Level below half glass | Sight glass; look under the shaft seal for drips (2 min) |
| Clogged filter | Oil pressure low but oil looks fine | Pressure either side of the filter (needs the test gauge kit, 5 min) |
| Failing oil pump or bearings | Oil pressure low with new oil; knocking | Stethoscope (3 min); lab metals |
| Oil-logged chiller | Capacity down, the oil level keeps dropping between changes | Chiller oil pot (drain it: 10 min) |

A wrong guess (changing oil when the bearings are the problem) costs the oil
and three hours, and the oil pressure stays low, which is itself a clue.

**Parts.**

| Part | Price |
| --- | --- |
| Refrigeration oil, ISO 68 naphthenic, 20 L pail (need 30 L) | $105 per pail |
| Oil filter cartridge, Nordale RC-4 | $38 |
| Filter housing O-ring | $4 |
| Suction strainer screen (if torn) | $60 |
| Crankcase drain plug washer | $2 |
| Waste oil disposal (hazardous, ammonia-contaminated) | $40 |

**Procedure.**

1. Read and log oil pressure, sight glass and run hours (the before reading).
2. Switch the compressor to manual and **pump it down**: slowly close the
   suction service valve while it runs, watching the suction gauge fall to
   2 psig. Don't pull a vacuum (air gets in). Stop the compressor.
3. Close the discharge service valve.
4. **Lock out** the motor starter: padlock, tag, try the start button.
5. Put on the full-face respirator with ammonia cartridges; the handheld
   detector on the bench if owned.
6. **Bleed** the last ammonia vapour from the crankcase through the purge
   valve and a hose into a bucket of water (ammonia dissolves in water).
   Bubbles stop when it's empty.
7. Open the drain valve and drain the oil into the waste drum. Look at it:
   colour, smell, glitter (metal), milkiness (water).
8. Remove the filter housing (4 bolts), pull the cartridge, check the
   housing for sludge, clean it (scrub verb).
9. Remove the suction strainer cover (6 bolts), pull the screen, clean it in
   solvent, inspect for tears (replace if torn).
10. Fit the new cartridge and O-ring (lubricated with clean oil; a dry
    O-ring flags `bolt_undertorqued` style seepage), refit covers, torque
    housing bolts to 25 ft-lb.
11. Close the drain. Pump in new oil with the hand pump to **half the sight
    glass** (the code's oil to 1.0). Overfilling causes oil carry-over and
    foaming (flag).
12. Remove the lockout, open the discharge valve, then crack the suction
    valve slowly (opening it fast can slug liquid into the cylinders: a
    knock and a cracked valve ring).
13. Start, watch the net oil pressure rise to 30 to 45 psi inside 30
    seconds. If it doesn't, stop (air in the pump: prime it).
14. Run 30 minutes, check the level (it drops as the filter fills; top up
    to half again), check for leaks with a sulphur stick or the detector.
15. Log it. Optional: drain the chiller oil pot (close isolation, wait 20
    minutes for the liquid ammonia to boil off, then open the drain a crack;
    a big hiss means it wasn't warm yet).

**Outcomes.**

| Quality factor | Target | Effect |
| --- | --- | --- |
| Level | Half glass +/- a quarter | Oil to 1.0; too high adds carry-over |
| Strainer clean | Dirt mask under 10% | Suction pressure drop gone |
| Filter fitted with lubricated O-ring | | No seep |
| Pump-down clean, no slugging at start | | Avoids valve damage |

Result: compressor `oil` to 1.0 and oil life 4,000 h with a new filter.
Other parts' stress drops back to 1. A skipped bleed (step 6) releases
ammonia: the detector alarms, 20 ppm in the plant room, a reportable
incident if over 150 ppm, and a fine if an inspector hears of it.

**Better tools.** Oil lab analysis turns guessing into a schedule and warns
of bearings 1,000 hours ahead. The digital controller logs net oil pressure
every minute and plots it. Filter pressure gauges show when the filter (not
the oil) needs changing. An oil transfer pump ($280) cuts the job by 30
minutes.

### 4.3 Compressor valve job

The signature plant job. Doing it well is the moment the player stops being
afraid of the plant room.

**Trigger.** Run times getting longer for the same ice; suction pressure
higher than normal while the ice is warm; one cylinder head hotter than the
others; a ticking at a head; the vibration pen or the ear says "rough"; the
discharge temperature over 125 C; or the scheduled 8,000-hour valve
inspection. In Year 1 compressor 1's valves are at 0.55 and fall to the trip
point (0.08) within about 2,000 run hours if nothing is done.

**Diagnosis.**

| Suspect | Evidence for | Check (time) |
| --- | --- | --- |
| Discharge valve leaking (one cylinder) | That head is hot | Hand or IR gun on each head (2 min); IR shows 15 to 25 C hotter |
| Suction valve broken | Ticking; low capacity; that cylinder's head is cooler | Stethoscope on each head (3 min) |
| Rings worn | Oil use up, crankcase pressure up, all cylinders weak | Pump-down test: shut the suction valve and see how far it pulls down (a healthy machine pulls to 0 psig in under a minute; weak valves or rings hold at 8 to 10 psig) (10 min) |
| Unloader stuck | Capacity low but steps between 50% and 100% | Watch the unloader indicator; the controller's amps |
| Condenser, not the compressor | Discharge pressure high on both machines | Discharge gauge, compare machines |
| Low ammonia charge | Receiver level low, bubbles in the liquid line sight glass | Receiver gauge glass (2 min) |

The pump-down test is the key teaching moment: a crude instrument (the
suction dial gauge) used cleverly gives a good answer.

**Parts (Nordale RC-4, per compressor).**

| Part | Qty | Price |
| --- | --- | --- |
| Suction valve ring | 4 | $28 each |
| Discharge valve plate | 4 | $32 each |
| Valve spring set (per cylinder) | 4 | $10 each |
| Cylinder head gasket | 4 | $11 each |
| Discharge valve cage gasket | 4 | $6 each |
| Safety head spring (inspect; replace if weak) | 4 | $18 each |
| Refrigeration oil top-up | 10 L | $55 |
| Total, full kit | | about $480 |

The code's `valves` SimPart price ($340) is the plates and springs alone;
gaskets and oil bring it to about $480.

Optional while it's open (if the cylinder walls show scoring or the pump-down
test failed badly): piston rings, $130 a piston, plus 3 more hours per
cylinder (pull the piston through the top, needs the rod cap off from the
crankcase side).

**Procedure.**

1. Shift the load to compressor 2 (in season this means one machine carries
   the ice; check the forecast and the schedule, and don't start this at
   16:00 on a Saturday).
2. Pump down, close service valves, lock out, PPE, bleed the crankcase (as
   4.2 steps 2 to 6). Bleed each head through its purge port.
3. Remove the water jacket hoses from each head (old Nordale heads are
   water-cooled), catching water in a pan.
4. Loosen the 8 head bolts per cylinder in the reverse cross pattern, a
   half turn each, then remove. The head is 22 kg: the grab verb has weight.
5. Lift out the safety head spring and the discharge valve cage assembly.
6. Inspect: the discharge plate (cracks, a step worn into the seat), the
   suction ring (broken pieces: check the cylinder for fragments with the
   work light), carbon on the seats, the cylinder wall (scored = rings job).
7. Clean the seats with a soft scraper and solvent (scrub until the dirt
   mask clears). Lap a marked seat on the lapping plate with fine compound
   (figure-eight strokes; too many strokes takes too much metal).
8. Fit new suction ring and springs in the cylinder top, new discharge
   plate and springs in the cage. Each plate must sit flat (a check: the
   plate rocks if a spring is seated wrong).
9. Measure the valve lift with feeler gauges: target 1.5 mm (+/- 0.15).
   Too little lift chokes flow; too much and the plate hammers and cracks.
10. Refit the cage and safety head spring (check spring free length against
    the card: 95 mm, replace if under 92).
11. New head gasket, dry. Seat the head, run all 8 bolts down finger-tight.
12. **Torque sequence**: cross pattern, three passes, 50, 100, then 150
    ft-lb (5/8 in grade 5 bolts). The torque verb shows the click; with the
    old bar and pipe, the player judges by a tension meter that has error.
13. Refit water jacket hoses, open the water valves, check for drips.
14. Evacuate air from the compressor with the vacuum pump (if owned) or by
    purging with a little ammonia through the purge valve to water (the old
    way: ammonia pushes the air out).
15. Leak test every joint: sulphur stick (white smoke) or the detector.
16. Remove lockout. Open discharge, crack suction slowly.
17. **Run-in**: start unloaded (the unloader holds 2 cylinders off), watch
    oil pressure, amps, listen with the stethoscope. After 10 minutes load
    to 100%. After 30 minutes, re-torque the heads warm to 150 ft-lb (the
    gasket settles).
18. Pump-down test again: it should now pull to 0 psig in under a minute.
19. Log it with the before and after readings.

**Outcomes.**

| Quality factor | Target | If missed |
| --- | --- | --- |
| Valve lift | 1.5 mm +/- 0.15 | Plates crack early (life x0.5) |
| Seats clean and lapped flat | Mask under 5% | Leaks from day one (quality 0.8) |
| Torque pattern and value | 150 ft-lb +/- 10%, cross pattern, three passes | Gasket leak in 2 to 20 days (`bolt_undertorqued`), a stripped thread (`bolt_overtorqued`, +2 hours with a thread insert) |
| New gaskets | | `gasket_reused`: ammonia seep, inspector fine |
| Fragments found | | A missed fragment scores the cylinder: rings life x0.3 |
| Re-torque after run-in | | Gasket life x0.6 |
| Slow suction opening | | A slug: knock, cracked ring, start again |

Result: `valves.replace(quality)`, capacity back (code `compressor_health`
rises with valve condition), discharge temperature down 15 to 25 C, power
per kW of cooling down. A good valve job on compressor 1 in Year 1 saves
about $600 a month in electricity.

**Better tools.** A digital torque wrench ($320) removes the error from step
12. A vacuum pump ($450) replaces purging, which cuts ammonia smell and
inspector risk. The vibration pen and the oil lab move the trigger from
"it broke" to "it's due". The digital controller compares cylinder head
temperatures continuously. A valve lift gauge ($60) beats feelers.

### 4.4 Glycol concentration test, top-up and flush

**Trigger.** Monthly test in Gus's binder (which nobody has done since 2019:
the true concentration at the start is 31%, `RefrigerationPlant.glycol_pct`
31.0, and it falls as the old header weeps and the makeup valve tops up with
water); a falling expansion tank; after any leak repair or drain; or the
ammonia inspector asking for the last test.

**The test (0.5 h).**

1. Draw a sample from the sample valve on the return line into a clean cup
   (run it a few seconds first: the first cup is the dead leg).
2. Look: clear green or pink is good; brown is rust (inhibitor spent); black
   flecks are scale; a smell of ammonia is very bad (chiller tube leak).
3. Measure:

| Instrument | Method | Reading |
| --- | --- | --- |
| None | Guess from the colour | +/- 12% |
| Hydrometer ($35) | Float it in a tall cylinder, read specific gravity, correct for temperature on the chart in Gus's binder | +/- 3% |
| Refractometer ($180) | A drop on the prism, look through it, read the freeze point scale (ethylene glycol scale) | +/- 0.5% |
| pH strips / meter | Dip | +/- 0.5 / +/- 0.05 |

| Concentration | Freeze point | Meaning |
| --- | --- | --- |
| 25% | -12 C | Danger: the chiller's ammonia boils at -14 C |
| 30% | -16 C | Minimum |
| 35% | -21 C | Target |
| 40% | -24 C | Thick: pumping costs more and heat transfer drops |

**Top-up (3 h).** The player works out how much concentrate to add. The
binder has the formula and the game shows the working on a notepad:

To raise the loop from c0 to ct, drain D litres of mix and add D litres of
concentrate: D = V x (ct - c0) / (100 - c0). For V = 9,000 L, c0 = 28%,
ct = 35%: D = 9,000 x 7 / 72 = 875 L, which is $4,200 of concentrate.

Steps: close the makeup water valve (and tag it: "NO WATER"), drain D litres
from the low-point drain into clean drums (the drained mix goes to the glycol
recycler at $0.40/L), pump
concentrate into the expansion tank with the drum pump, run the pump 2 hours
to mix, re-test. Bleed air at the high points of the header (each bleeder
spits, then runs clear). Check the pH; add inhibitor booster if under 8.

**Flush (summer, 3 days).** When the glycol is brown and the pH won't come
back, or after a chiller leak. Drain the whole loop (9,000 L to the
recycler), fill with water and cleaner, circulate 8 hours, drain, flush with
clean water until it runs clear (a PowerWash-style "clean" meter on the
sample cup), refill with premixed 35% (3,150 L concentrate, about $15,100,
plus inhibitor), bleed air for a day (the pump hammers until every pocket is
gone), test.

**Diagnosis traps.** A falling expansion tank level suggests a leak, but the
pump seal and the header (4.12) are separate jobs. A rising level with
falling concentration means the makeup valve is passing water: the hidden
dilution that ends in a frozen chiller.

**Parts.**

| Part | Price |
| --- | --- |
| Inhibited ethylene glycol concentrate | $4.80/L (208 L drum $998) |
| Inhibitor booster, 20 L | $450 |
| System cleaner, 20 L | $220 |
| Glycol recycling | $0.40/L |
| Makeup valve | $75 |
| pH strips | $25 |

**Outcomes.** Concentration hits the target within the instrument's error:
with a hydrometer the player may think they're at 35% and actually be at
32%. Air not bled (`air_not_bled`) leaves a warm stripe on the ice and
pump cavitation for a week. Leaving the makeup valve open undoes it all.

**Better tools.** Refractometer; a glycol level sensor with a daily trend
(the controller), which shows a leak as a slope; an automatic makeup unit
that adds premix instead of water ($1,900), which removes the dilution trap.

### 4.5 Glycol pump bearing and seal

**Trigger.** A growl from the pump, the bearing housing too hot to hold
(over 60 C by hand; the IR gun says 85 C), glycol drips under the seal
gland becoming a puddle, crystals of dried glycol around the shaft,
vibration pen over 7 mm/s, or a scheduled 5-year rebuild.

**Diagnosis.**

| Suspect | Evidence | Check |
| --- | --- | --- |
| Bearings | Growl that changes with speed, heat at the bearing housing, vibration at 1x and bearing frequencies | Hand or IR (1 min), stethoscope (2 min), vibration pen (3 min) |
| Seal | Drips at the gland, crystals | Look (1 min) |
| Coupling worn or misaligned | Black dust under the guard, vibration at 2x | Remove guard, look (5 min) |
| Cavitation (air or low suction pressure) | Gravel noise, flow low | Suction gauge, bleed air (10 min) |
| Motor bearing, not the pump | Heat on the motor end | IR on the motor (1 min) |

**Parts.**

| Part | Price |
| --- | --- |
| Pump-end bearing 6309-2Z | $48 |
| Drive-end bearing 6311-2Z | $64 |
| Bearing housing lip seals (2) | $12 each |
| Mechanical seal, type 21, 1.875 in | $150 |
| Casing gasket | $28 |
| Coupling insert (jaw spider) | $24 |
| Impeller nut lock washer | $4 |
| Total | about $340 |

The code splits this as `pump_bearing` ($190) and `pump_seal` ($150).

**Procedure.**

1. Plan: the pump stops the floor's cooling. Millbrook has one pump (a
   standby pump is a project in 5.9), so the job is done overnight on a
   night with no late ice, with the plant off, and the slab's thermal mass
   (the code's 250 MJ/K) buys about 5 hours before the ice warms 1 C.
   The clock is visible: a timer of "ice warming" while you work.
2. Lock out the pump motor.
3. Close the suction and discharge butterfly valves (8 in, big handles).
4. Open the casing drain into a clean drum (about 40 L, reusable).
5. Remove the coupling guard, mark the coupling halves, remove the spacer.
6. Unbolt the back pull-out assembly (8 bolts) and slide it out on the rails.
7. Hold the shaft, undo the impeller nut, pull the impeller with the puller.
8. Remove the old seal. **Measure** the seal's set length before you take
   it apart (mark the shaft): the new seal's spring must be compressed to its
   working length (32 mm for this seal). Wrong length means drips or a
   burned face.
9. Remove the bearing frame end cover, press the shaft out, pull the
   bearings with the bearing puller.
10. Check the shaft for wear under the seal and bearing seats (a micrometer
    if owned, else the fingernail test).
11. **Heat** the new bearings to 110 C on the induction heater ($600 tool)
    or in an oil bath on a hot plate, and slide them onto the shaft. Never a
    torch (flag: bearing life x0.3). Never hammer the outer race (flag).
12. New lip seals, reassemble the frame.
13. Fit the new mechanical seal: clean hands, no fingerprints on the seal
    faces (the verb is "wipe with a lint-free cloth"; touching the face sets
    `seal_face_touched`, drips from day one). Lubricate the elastomer with
    water or glycol, never oil.
14. Impeller on, new lock washer, nut torqued to 90 ft-lb. Check impeller
    clearance with feelers: 0.4 mm (+/- 0.1).
15. Slide the assembly back, new casing gasket, bolts in a cross pattern to
    60 ft-lb.
16. **Align** the pump and motor:

| Tool | Method | Achievable error |
| --- | --- | --- |
| Straightedge and feelers (start) | Lay the straightedge across the coupling halves top and side, shim the motor feet | +/- 0.5 mm |
| Dial indicator kit ($240) | Rim and face readings, shim maths on a card | +/- 0.05 mm |
| Laser shaft alignment ($2,800) | It tells you the shims | +/- 0.02 mm |

    Misalignment over 0.25 mm cuts bearing and seal life in half (`misaligned`).
17. Coupling insert in, guard on.
18. Open the valves, vent the casing at the top bleed screw until glycol
    runs clear, remove lockout.
19. Bump the motor to check rotation (wrong rotation after a motor rewire is
    a classic: flow is a third and the pump screams).
20. Start the pump, then the plant. Check: drips at the seal (a few in the
    first hour while the faces lap in, then none), bearing temperature after
    an hour (under 70 C), vibration under 2.8 mm/s.

**Outcomes.** Bearing and seal conditions set from the quality math;
alignment error multiplies their wear rate. Over the time budget, the ice
warms past -3 C and the 06:00 figure skaters get soft ice (fine) and the
07:00 minor hockey practice doesn't (complaint). Overrun badly and the first
session is cancelled.

**Better tools.** Dial indicator, then laser alignment; the induction
heater; the vibration pen to spot it a month early; a standby pump project
($14,000) which turns this into a daytime job with no ice clock.

### 4.6 Condenser fan belt and descaling

Two linked jobs on the roof: a quick belt change that can happen any week,
and the big descale that happens in summer.

**Trigger.** Belt: a squeal at fan start (07:00 when the plant loads up), a
fan that looks slow, head pressure 10 to 20 psig higher than last week in
the log, or a snapped belt and a high pressure trip. Descale: head pressure
and amps creeping up over weeks; the code's `condenser_scale` grows with
every running hour; white crust visible on the coil and fill; conductivity
too high.

**Diagnosis.**

| Suspect | Evidence | Check |
| --- | --- | --- |
| Belts slipping or glazed | Squeal, shiny belt sides, fan slow | Roof hatch, look and listen (5 min, cold in January); belt tension gauge |
| Scale on the coil | High head pressure on a mild day with the fan running fine | Look through the access door (5 min); log trend |
| Spray pump or nozzles | Dry patches on the coil | Look with the pump on (5 min) |
| Air (non-condensables) in the ammonia | High head pressure, receiver gauge higher than condensing temperature suggests | Compare the head pressure with the condensing pressure for the coil water temperature (10 min with a thermometer and the chart) |
| Frozen basin (winter) | No spray, ice on the casing | Look |

**Belt job (1 h, $48 to $130).**

1. Lock out the fan motor at the roof disconnect.
2. Remove the belt guard.
3. Loosen the motor base adjusting bolts, slide the motor in, roll off the
   old belts (never pry them over the sheave: flag).
4. Check the sheaves with a sheave groove gauge ($25): worn, dished grooves
   eat new belts (new sheaves $65 and $90).
5. Fit a **matched pair** of B68 belts (one new and one old, or two from
   different batches, wear unevenly).
6. Tension: push the belt mid-span. Target deflection is 1/64 in per inch of
   span: a 32 in span wants 1/2 in deflection at about 6 lb force. By thumb
   (start) the error is large; a belt tension gauge ($30) reads it.
7. Align the sheaves with a straightedge (or a laser sheave tool, $350).
8. Guard on, run, re-tension after 24 hours (new belts stretch).

**Descale (summer, 12 h over two days, about $1,500).**

1. Plant off (ice out), drain the basin, lock out fan and spray pump.
2. Scrape loose scale from the basin and fill faces; photograph the worst.
3. Remove damaged fill packs (12 in the unit; brittle 1974 PVC breaks) and
   replace ($180 each).
4. Clear the 64 spray nozzles (soak in acid, replace the cracked ones, $6).
5. Fill the basin with water and inhibited descaler (sulphamic acid, 4 x
   25 kg pails at $95), circulate with the spray pump. The PowerWash part:
   the coil goes from crusty white to grey steel as the timer runs; pH rises
   as the acid is used up, so add more until it stays low.
6. Drain, neutralise with soda ash to pH 7 before it goes to the drain
   (dumping acid is a town fine).
7. Rinse, refill, check the float valve and basin heater.
8. Set water treatment: bleed-off to hold 3 to 5 cycles of concentration
   (conductivity 1,500 to 2,500 uS/cm), biocide dosing, a Legionella
   sample to the lab ($85).

**Outcomes.** Belt: fan back to speed, head pressure drops in the log.
Descale: `condenser_scale` back near 0 (0.05 per untouched corner), head
pressure 15 to 25 psig lower in summer, compressor power down 8 to 12%,
fewer high pressure trips. Poor neutralising: fine. No biocide: the health
inspector fails the tower.

**Better tools.** Belt tension gauge, laser sheave alignment, a conductivity
meter, then an automatic water treatment controller ($2,200) that slows
scale to a third. A variable speed drive on the fan ($3,200) saves power
and ends the belt squeal at start.

### 4.7 Resurfacer blade change and height setting

**Trigger.** Snow ribbon thin or uneven (shown from the driver's seat on
every flood), ridges or "washboard" chatter left on the ice, ruts that don't
go away, a chipped blade (a puck in the conditioner), or the blade's hours
(30 resurfacing hours, half on hard ice).

**Diagnosis.**

| Suspect | Evidence | Check |
| --- | --- | --- |
| Dull blade | Thin snow, a polished look on the ice instead of a cut | Thumbnail test on the edge (1 min); edge gauge |
| Blade set too high | Even thin snow across the whole width | Look at the setting (2 min) |
| Blade not level (one end deeper) | A wedge of snow, a ridge every pass at one side | Feelers at both ends |
| Chipped blade | A line on the ice every pass at the same place | Look along the edge with the light |
| Conditioner, not the blade | Snow left on the ice although the cut is good | Augers (4.9) |

**Parts.** Ice blade 77 in, $160 new; resharpening the old one at the
blade shop in Kessler $45 (3 days; keep a spare); 7 blade bolts and lock
washers $14; cut-resistant gloves $25 (required).

**Procedure.**

1. Park Doris in the bay on the level pad, conditioner down, engine off, key
   out and in your pocket (lockout for Doris).
2. Gloves on. A blade is a 2 m razor: handling it without gloves is
   possible and sometimes bleeds (a first aid stop, 0.5 h, and a story).
3. Raise the conditioner slightly and set it on the blade-change stands
   (two wooden blocks Gus made, labelled "DORIS'S SHOES").
4. Fit the blade guard to the new blade.
5. Loosen the 7 blade bolts with the long ratchet, from the ends to the
   centre. Slide the old blade out (a heavy, slow grab; dropping it chips
   the edge).
6. Clean the blade holder: ice, rust and old snow out of the slot (scrub).
7. Slide in the new blade, bolts finger-tight.
8. **Set the height.** Three adjusting screws (left, centre, right) set how
   far the edge sits below the runners. The target cut is 1.0 mm (the code's
   `blade_height_mm`, 0.8 to 1.2 shaves cleanly), level within 0.1 mm end to
   end, with a slight crown of 0.05 mm at centre so the middle doesn't skip
   on a dished sheet.
   The player turns each screw (1/6 turn = 0.1 mm) and measures with feelers
   under a straightedge laid across the runners. Every measurement carries
   the gauge's error; the dial setting gauge shows the reading live.
9. Torque the blade bolts from the centre out to 35 ft-lb.
10. Remove the guard, lower the conditioner.
11. **Test pass.** One slow lap at the edge of the sheet with the blade
    down and no water. The snow ribbon in the auger should be even, about a
    finger thick, the full width. Adjust if it isn't (another 10 minutes).
12. Log the change (blade hours to 0, which side is the spare).

**Outcomes.**

| Factor | Target | If missed |
| --- | --- | --- |
| Height | 1.0 mm +/- 0.2 | Too shallow: ruts stay, the ice thickens; too deep: shaves through the paint in weeks, uses more water to rebuild |
| Level | Within 0.1 mm | A ridge on every pass, ice dishes over the season |
| Bolt torque | 35 ft-lb, centre out | A loose blade chatters (washboard) |

`ResurfacerSim` already turns `blade.condition` and `blade_height_mm` into
cut quality; level becomes a new `blade_level_mm`.

**Better tools.** Feeler gauges, then the dial setting gauge, then the laser
blade jig. An in-house blade sharpener ($4,800, renovated zamboni_bay)
makes sharpening a bench job and saves the trip. A spare blade on the shelf
is the cheapest upgrade in the game.

### 4.8 Resurfacer engine tune-up

**Trigger.** Hard starting (the first-hour tutorial uses a slice of this),
a stumble or misfire, black smoke, the CO meter or a headache complaint,
the health inspector's air quality test, or 300 engine hours.

**Diagnosis.**

| Suspect | Evidence | Check |
| --- | --- | --- |
| Fouled or worn plugs | Hard start, misfire | Pull a plug: black and wet (rich), white (lean), tan (good), gap (1 min each) |
| Points pitted, dwell off | Misfire at speed, timing wanders | Look at the points (5 min); dwell meter |
| Timing | Pinging, poor power | Timing light (5 min) |
| Rich carburettor | Black smoke, high CO | Exhaust gas analyser, or the smell |
| Weak cylinder | One plug always fouls | Compression test: 150 psi good, under 110 or 20% below the others is a valve or ring problem (beyond a tune-up: a contractor rebuild) |
| Damp cap and wires | Misfire in April fog | Spray water mist at night and look for sparks tracking |
| Fuel filter | Dies under load | Look at the filter bowl |

**Parts.**

| Part | Price |
| --- | --- |
| Spark plugs, set of 4 | $28 |
| Points and condenser | $32 |
| Distributor cap and rotor | $46 |
| Plug wire set | $55 |
| Air filter | $22 |
| Fuel filter | $9 |
| PCV valve | $8 |
| Engine oil 4.5 L and filter | $46 |
| Total, full tune-up | about $210 (a plugs-only fix is $28) |

**Procedure.**

1. Engine cold, key out, battery negative off.
2. Compression test first (if the tester is owned): plugs out, throttle
   wide, crank 5 times per cylinder, write the numbers.
3. Plugs: gap new plugs to 0.035 in (+/- 0.002 with a wire gauge; a coin
   gauge at the start has +/- 0.005), thread by hand (cross-threading an
   old aluminium head is an expensive flag: a thread repair, 2 h), torque to
   15 ft-lb.
4. Distributor: cap off, rotor off, points out. New points, set the gap to
   0.016 in with feelers on the cam high point, new condenser, a dab of cam
   grease. New rotor and cap, wires one at a time in the firing order 1-3-4-2
   (swapping two wires: a dramatic backfire and a flag).
5. Air filter, fuel filter, PCV valve.
6. Oil and filter change (drain, filter, refill to the dipstick's full mark).
7. Battery on, start. Warm up 10 minutes.
8. Dwell: 30 degrees (+/- 2) with the dwell meter; without it, the points
   gap is the only setting.
9. Timing: 6 degrees before top dead centre at idle, vacuum advance
   disconnected, with the timing light on the crank pulley marks. Without
   one: "turn the distributor until it idles fastest, then back a hair",
   which is how Gus did it (+/- 4 degrees).
10. Idle speed to 650 rpm with the throttle stop screw.
11. Idle mixture: turn the mixture screw for the highest smooth idle; with
    the exhaust gas analyser, for CO under 1.5% at idle.
12. Test: start cold three times, a flood, the CO meter at the bench during
    the flood with the bay door shut.

**Outcomes.** Spark plug and air filter `SimPart`s to new, the engine term in
the flood quality back up, and a new **CO emission factor** (0.5 to 2.0) that
the air model uses. A bad mixture setting doubles CO. The tune-up is the
most direct link between a mini game and an inspection result.

**Better tools.** Wire gap gauge, compression tester, timing light and dwell
meter, exhaust gas analyser, the fixed CO/NO2 monitor. A propane conversion
($3,800) drops CO by 70%; an electronic ignition kit ($240) removes points
from future tune-ups. Late game, Doris can be restored (a renovation
project for her, $18,000, the club colours) or retired for a Flatley.

### 4.9 Conditioner squeegee and towel replacement

**Trigger.** Grey streaks (dirty wash water left behind: squeegee), lines
and ridges in the fresh flood (towel frayed or folded), water left in a
"railroad track", snow spilling out the conditioner sides (auger), a dry
stripe (blocked spreader holes), or hours.

**Diagnosis.**

| Suspect | Evidence | Check |
| --- | --- | --- |
| Squeegee worn or torn | Grey streaks, wash water left on the ice | Look at the rubber edge (2 min) |
| Towel frayed, stiff or folded | Fine lines, uneven water film | Look and feel the towel (1 min) |
| Spreader pipe holes blocked | Dry stripes | Run the flood water in the bay (3 min) |
| Wash water nozzles blocked | Dirty patches | Run wash water in the bay |
| Augers worn | Snow left behind | Look at the flights (5 min) |
| Driver | Overlap gaps in the pattern | The replay of the last flood (the ice-mapping software) |

**Parts.** Squeegee rubber 77 in, $55; towel (heavy woven cotton, 2 m), $85;
towel bar clamps $12; spreader pipe end caps $8.

**Procedure.**

1. Doris in the bay, conditioner raised on the stands, key out.
2. Remove the squeegee clamp strip (14 bolts, rusty: penetrating oil, wait
   two minutes, or snap one: a flag and 20 minutes drilling it out).
3. Remove the old rubber, clean the channel (scrub).
4. Fit the new rubber, trim it square with the knife against a straightedge
   (a crooked cut leaves a streak).
5. Refit the clamp strip, bolts snug from the centre out.
6. Set squeegee height: the rubber edge just touches the bay floor with the
   conditioner's weight on it, even across (a feeler or a strip of paper
   pulled under it: same drag at each end).
7. Clear the spreader pipe holes with a drill bit (each hole on a strip,
   click each), flush.
8. Unclip the old towel, fit the new one to the towel bar so it lies flat,
   with the full width touching, no folds, the trailing edge even. The
   game shows the towel's contact as a stripe pattern when the water is run
   in the bay.
9. Run the flood water in the bay for 10 seconds: watch the film behind the
   towel.
10. Log it. Hang the old towel on Gus's hook ("Old towels clean the bay").

**Outcomes.** `towel` and `squeegee` to new at the job's quality; the
condition term in `ResurfacerSim.resurface` back up. A folded towel or a
crooked squeegee leaves a line on every flood until it's fixed.

**Better tools.** A towel rack that dries towels between floods (renovated
bay) doubles towel life. The IR gun on a fresh flood shows dry stripes as
warm or cold lines instantly.

### 4.10 Ice edging and leveling

**Trigger.** Edge buildup over 6 mm (feels like a lip at the boards, pucks
die along the wall), a thickness survey showing high spots, the weekly
schedule, or a curling bonspiel booking that needs the sheet within 3 mm.

**The survey (diagnosis).** The player builds a thickness map:

| Tool | Method | Time | Coverage | Error |
| --- | --- | --- | --- | --- |
| Drill and ruler (start) | Drill a hole, push a ruler in until it hits concrete, plug with slush | 2 min a hole | Only where you drill (the player picks points on the grid) | +/- 5 mm |
| Ice thickness gauge | A drill with a depth probe | 30 s a hole | Same | +/- 1.5 mm |
| Laser level survey | A rotating laser on a tripod at centre, a receiver on a rod, walk the grid | 1 h | Every cell | +/- 0.5 mm |
| Ultrasonic scanner on Doris (late) | Automatic every flood | 0 | Every cell | +/- 1 mm |

The map shows as a contour overlay on the ice (a coloured grid in the
office and on the ice). Holes drilled must be filled with slush and water,
and a missed hole is a skate-catcher.

**Edging (1.5 h).**

1. Start the edger (third pull, or ninth with an old plug).
2. Set cut depth on the edger's wheel (1 to 6 mm per pass).
3. Walk the boards, the disc against the kickplate. The player steers with
   a cursor that must hug the board line; drifting out leaves a ridge, too
   close scrapes the boards (marks the paint and wears blades).
4. Corners: short overlapping passes.
5. Around the nets' pegs and the bench gates: by hand with an ice scraper.
6. Sweep the snow into the path of the next flood; Doris picks it up.

**Leveling (over several nights).** With the map, the player plans:

| Problem | Fix |
| --- | --- |
| Edge buildup | Edger passes until the edge cells are within 3 mm of the neighbours |
| High spots in the middle | Set Doris's blade deeper (1.5 mm) and make extra dry shave passes over the marked cells (a route drawn on the map) |
| Low spots | Hand-flood with the hose and spreader (thin coats, 0.5 mm each, let freeze between) |
| General thickness too high | Shave the whole sheet a little deeper each night for a week |

**Outcomes.** A new thickness map, average thickness and standard
deviation. The Year 1 goal (48 to 32 mm) cuts the plant's load
(`IceSlab.run`'s insulation term) and the bill by about 12% a month.
Over-shaving exposes paint (grey patches, paint term falls) and in the worst
case concrete (a cancelled session and a costly rebuild of that patch).

**Better tools.** Ice gauge, laser level, the ice-mapping software, a newer
edger with a dust-free electric motor ($6,500), a laser-guided edger
(late). Doris's ultrasonic scanner turns this into routine maintenance.

### 4.11 Painting lines and logos at ice-in

The yearly August set piece. It takes four in-game days, mostly time-lapsed,
with the hands-on parts played.

**Trigger.** Ice-in (the summer plan's last week), or a mid-season rebuild
after a disaster (a melted floor).

**Phases and procedure.**

| Day | Step | Details |
| --- | --- | --- |
| 1 | Prepare the floor | Clean the concrete (PowerWash-style), check the floor temperature probes, close the bay doors, dehumidifier on |
| 1 | Pull down the floor | Plant on, glycol at -9 C; the slab goes from 15 C to -5 C in about 24 to 36 h (the plant clock) |
| 2 | Mist coats | Hand hose with a fine nozzle, or a spray boom on a cart: 15 to 20 mist passes, each frozen before the next, to 3 mm (1/8 in). Too much water at once puddles and makes soft ice (a cloudy patch) |
| 2 | White base | Mix white ice paint (powder plus water, about 300 L for the sheet), spray two coats with the boom in overlapping passes, each pass 6 m wide. Gaps show as grey stripes; overspray on the boards costs a scrub later |
| 2 | Seal | Two mist coats over the white so the colour doesn't lift |
| 3 | Lay out | String and tape from the centre: centre red line 12 in (30 cm) wide across the rink, blue lines 12 in wide 25 ft (7.62 m) either side of centre, goal lines 2 in (5 cm) 11 ft (3.35 m) from the end boards, faceoff circles of 15 ft (4.57 m) radius at the four end-zone dots (20 ft / 6.1 m out from the goal line, 22 ft / 6.71 m off centre), the centre circle, the neutral zone dots 5 ft (1.5 m) inside the blue lines, the goal creases (6 ft / 1.83 m radius), the referee crease. These are `Rink.gd`'s own constants (`BLUE_X` 7.62, `GOAL_X` from 3.35, `CIRCLE_R` 4.57, `DOT_X`, `DOT_Z` 6.71, `CREASE_R` 1.83), so the painted lines and the physics agree |
| 3 | Paint lines | Lines with a wheeled line painter along the strings, circles with a circle scribe on a pin at the dot. The player walks the painter along the string; wobble shows. Dots and the crease fill by brush |
| 3 | Logos | Sponsor and club logos: printed mesh logos laid wet and flooded in, or painted through stencils. Placement is part of sponsor deals (centre ice, the neutral zone, behind the nets). A logo laid on a wet patch wrinkles |
| 3 | Seal | Mist coats until the lines are under 3 mm of clear ice |
| 4 | Build | Floods with the hose then with Doris, 12 to 20 of them, to 32 mm. Each flood thin |
| 4 | Inspect | The hockey association's inspector checks line positions (tolerance +/- 2 in / 5 cm) |

**Parts and costs.**

| Item | Price |
| --- | --- |
| White ice paint, enough for one sheet | $1,400 |
| Red and blue line paint | $250 |
| Line painter wheel (one-time tool) | $180 |
| String, tape, circle scribe, brushes | $60 |
| Printed mesh logos | $150 to $600 each (the sponsor usually pays) |
| Water and plant power for ice-in | About $2,400 of electricity |
| Contractor alternative (Northern Line Painting) | $3,500 a sheet plus logos |

**Diagnosis-style choices.** Painting on ice that's too warm bleeds the
colour (fuzzy lines); too cold and the paint freezes in lumps. The IR gun
tells the player when the surface is at -4 to -5 C, the right window. With
the screwdriver they guess.

**Outcomes.** A paint quality (whiteness, line straightness, position
error), the `paint` value starting the season near 1.0, line positions that
pass or fail the inspection (a fail means a re-paint of that line: an ice
cut, paint, re-seal), and sponsor satisfaction with their logo. A beautiful
centre-ice logo raises facility perception for the whole season.

**Better tools.** IR gun for timing, a spray boom with a pump cart ($1,800),
chalk line, a laser line layout tool ($1,400) that projects lines onto the
ice, then a painting robot (late, Polarix "Lineo", $40,000, which once
painted a faceoff circle around a stationary rink rat). A renovated floor
with fixed temperature probes makes pull-down predictable.

### 4.12 Header leak hunt

**Trigger.** The expansion tank level falling in the log (the code's
`header` SimPart leaks `(1 - condition) x 0.6` litres an hour, about 7 L a
day at Millbrook's starting 0.5, and the makeup valve hides it by adding
water), a sweet smell in the header trench, a wet trench, a soft spot or a
pink tint in the ice near the end boards, or the glycol test showing
concentration falling with the level steady (makeup water hiding a leak).

**Diagnosis.** This is a detective game. The leak could be anywhere in the
loop, and every place costs time to check.

| Suspect | Evidence | Check (time) |
| --- | --- | --- |
| Pump seal | Drips at the pump | Look (1 min). The classic wrong first guess |
| Expansion tank, fittings, drains in the plant room | Wet floor, crystals | Walk the plant room with a torch (10 min) |
| Chiller tube (into the ammonia side) | Glycol level falls, ammonia receiver oddly rises, ammonia smell in the glycol sample | Sample test (10 min); this one is serious |
| Header trench jumpers and clamps | Wet trench, puddles, perished hoses | Lift trench plates (12 plates, 15 min each); inspect each jumper with the light |
| Header weld | A seep along a weld, rust stains | Same, plus a mirror |
| Floor pipe under the concrete | No wetness anywhere, but a soft or pink spot in the ice, a warm stripe | IR gun along the stripe (10 min), thermal camera (2 min for the whole sheet), circuit isolation and pressure test (below) |

Tools that narrow it:

| Tool | What it does | Price |
| --- | --- | --- |
| Log book trend | Leak rate in litres a day (needs daily readings) | Free |
| Thermal camera | Shows a warm or cold stripe over a leaking circuit | $900 |
| Fluorescent dye and UV lamp | Dye in the loop; leaks glow in the trench | $85 |
| Circuit isolation | Clamp a circuit's jumpers, pressurise it with a hand pump to 50 psi, watch a gauge for 30 minutes | Hand pump and gauge $140; 40 minutes a circuit |
| Mechanic's stethoscope | Hiss at a pinhole | $35 |
| Level sensor with the controller | A precise leak rate and when it started | With the controller |

The game generates the leak location from the header's age and a random
roll: mostly a jumper hose (70%), a clamp (15%), a weld (10%), a floor pipe
(5%). A Year 1 Millbrook leak is always a jumper, for fairness.

**Parts.**

| Part | Price |
| --- | --- |
| Jumper hose, 1 in EPDM, cut to length | $14 |
| Stainless hose clamps | $1.50 each |
| Header weld repair (contractor welder; glycol drained from that section) | $1,800 |
| Circuit cap kit (abandon a floor circuit) | $300 |
| Glycol to replace what was lost | $4.80/L concentrate |

**Procedure (a jumper).**

1. Find it (above).
2. Lift the trench plates over it.
3. Close the circuit's header valves if fitted (Millbrook's 1974 header has
   none: clamp the jumper hoses on both sides with hose pinch clamps).
4. Catch the glycol in a tray; cut the old hose off.
5. Clean the nipples with a wire brush (scrub).
6. Fit the new hose, two clamps each end, torque the clamps (overtightening
   cuts the hose).
7. Remove the pinch clamps, bleed air at the circuit's high point.
8. Watch for an hour. Replace the plates.
9. Top up with concentrate (not water) and test the mix (4.4).
10. Log it. Gus's note: "If you find one, there's three. Do them all while
    you're down there." True: the neighbours of a failed jumper are usually
    close behind. The player can replace the whole row at $14 a hose.

**A floor pipe.** No good fix in season. Options: cap the circuit (the
neighbours compensate; up to 4 capped circuits is invisible, more shows as
warm stripes); live with the leak and top up concentrate (costly and
dilution-prone); or plan the new floor (5.8). This is the long-term story:
Millbrook's floor is 50 years old, and every capped circuit pushes the new
floor project closer.

**Outcomes.** Leak rate to zero (or reduced), `header` condition improved
for a jumper row replacement, glycol saved. Not finding the leak means
continued dilution, which ends (if the makeup valve is open and nobody tests
the glycol) with a frozen chiller, the worst event in the game: no ice for
three weeks, every contract's cancellation penalties, a $30,000 retube.

**Better tools.** Daily logging, dye, the thermal camera, the controller's
level trend, header isolation valves (a $12,000 summer project that makes
every future hunt quick), the automatic premix makeup unit.

---

## 5. General management

The office on the lobby mezzanine (`Venue` room `office`) is the
management hub: a desk, a phone, a corkboard, the binder, and later a PC.
Its screens are RinkOS panels (`assets/ui/STYLE.md`). At WORN it's a
clipboard and a wall calendar; RENOVATED adds the booking software and a
plant controller screen.

### 5.1 The ice grid

The heart of management. A weekly grid of the sheet's time, 7 days by
15-minute cells from 05:00 to 01:00 (80 cells a day).

**Slot classes.**

| Class | When | Demand | Rate card (Year 1) |
| --- | --- | --- | --- |
| Prime | Weekdays 16:00 to 22:00; weekends 07:00 to 21:00 | Everyone wants it | $195/h |
| Shoulder | Weekdays 06:00 to 08:00 and 22:00 to 23:30; weekend evenings after 21:00 | Figure skaters (mornings), beer leagues (late) | $150/h |
| Dead time | Weekdays 08:00 to 16:00; anything after 23:30 | Schools, seniors, shinny, parent and tot, broomball, cheap late ice | $95/h |
| Summer dry floor | June to mid August | Ball hockey, lacrosse, events | $60/h |

**What goes on the grid.**

| Block type | Who | Notes |
| --- | --- | --- |
| Contract slot | Signed organisations (5.2) | Fixed weekly; moving one needs the organisation's agreement |
| Programme | The rink's own: public skate, adult learn to skate, shinny, parent and tot, stick and puck | Revenue per head; the player sets times and prices |
| Casual rental | One-off bookings from the phone queue (a birthday party, a company game) | Fills gaps at the rate card |
| Flood | Auto-inserted after each session (15 minutes), removable | A session with no flood before it starts on used ice |
| Maintenance | Edging, a job that needs the ice empty | Blocks the ice |
| Setpoint change | The ice use per block (hockey, figure, public, curling) | The plant ramps to the next use's target; the grid shows a ramp bar where the ice will be off-target |
| Event | Tournaments, the bonspiel, TV | Multi-day blocks with their own schedule |

**Grid rules and decisions.**

- Every session needs a flood before it to start clean; skipping saves 15
  minutes and costs ice rating (3.2).
- Dressing rooms are a constraint: every hockey session needs two, and back
  to back games with no flood gap need four (Millbrook has two until the
  dressing room expansion project). The grid flags conflicts.
- Temperature changes take time: about 1 to 2 hours for 2 C with both
  compressors (the slab's 250 MJ/K and the plant's capacity). Putting the
  figure club at 06:00, right after the night setback has let the ice warm,
  is free; putting them at 16:00 between minor hockey sessions costs plant
  power and leaves hockey on soft ice.
- Night setback: from the last flood to 04:00, the plant can run warmer
  (-4 C surface), which saves about 8% of the plant's power. A late
  booking cancels it.
- Electricity demand charges: the utility bills the month's highest
  15-minute power peak at $14/kW. Starting both compressors together at
  16:45 for prime time sets the peak. Staggering starts or pre-cooling at
  15:00 on cheap dead time saves real money. The digital controller does
  this automatically.
- Owner and staff time: the grid shows who floods each gap. An unstaffed
  gap is red.

### 5.2 Contracts and bidding

**The allocation season.** Most ice is sold once a year. In March and April
organisations send a request for ice (an RFP) for the next season. Rinks in
the region (6.3) bid. Organisations score bids and sign. Through the
season, smaller one-off requests come in (tournaments, hockey schools,
film shoots, a wedding on dry floor).

**A request** lists what the organisation wants:

| Field | Example (Millbrook Minor Hockey) |
| --- | --- |
| Hours a week and slot pattern | 14 h: Mon and Wed 17:00 to 20:00, Sat and Sun 08:00 to 12:00 |
| Season | 24 weeks, October to March |
| Ice use | Hockey |
| Minimum ice rating | 50 |
| Minimum facility score | 25, with both dressing rooms usable |
| Extras | Storage room for gear, a first aid kit and AED, the rink's logo on the jersey (they'll ask for a discount for it) |
| Budget (hidden) | $160 to $185/h |
| Weights | Price 40%, slot fit 30%, ice 15%, facility 10%, distance 5% |

**A bid** is what the player offers:

| Field | Player choice |
| --- | --- |
| Rate | Per hour, any number (the organisation's hidden budget decides) |
| Slots offered | The ones asked for, or alternatives (a worse slot at a lower rate) |
| Term | 1 or 2 seasons; a longer term wants a discount and gives stability |
| Escalator | 0 to 5% a year |
| Extras | Free storage, a dressing room held for them, their banner, a sharpening deal with Bev, a free hour for a fundraiser |
| Guarantees | A minimum ice rating clause (raises the score, risks penalties) |

**Scoring.** Each competing bid gets a score from the organisation's weights,
its relationship with each rink (0 to 100) and the rinks' reputations. The
best score signs. The player sees the result and, with a good relationship,
the reason ("Harlow Falls was $12 cheaper and has four dressing rooms").

**Contract terms in play.**

| Term | Rule |
| --- | --- |
| Rink cancels a slot | Refund plus a penalty of 50% of the slot's value; relationship -5 (-10 with under 48 hours' notice) |
| Organisation cancels | Over 7 days' notice: free. Under 48 hours: they pay 100% |
| Make-good | The rink can offer a replacement slot instead of the penalty (they accept if the slot is close in time) |
| Ice clause | If the true ice rating is under the contract minimum for 3 sessions in 4 weeks, they can walk with 2 weeks' notice |
| Payment | Monthly, net 30. Some pay late (the beer league pays in cash from a coffee can, always on time; the high school pays 60 days late, always) |
| Renewal | At the end of the term, the organisation re-scores the rink against the competition; a good relationship is worth about 10% of price |

**Relationships.** Each organisation has a contact person and a
relationship meter. It rises with good ice, flexibility (moving a slot when
asked), small favours (a free hour for a fundraiser), and the player showing
up (a meeting, an hour). It falls with cancelled ice, bad sessions, price
rises and being ignored.

### 5.3 Organisations

Ids match `RinkContracts.ORGS` where they already exist; new ones are marked
new. `min_ice` is the ice reputation needed to bid, `min_rooms` the facility
score.

| Id | Organisation | Contact | Use | Hours/week | Rate | min_ice | min_rooms | Other requirements | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `vbl_d` | Valley Beer League (D and C) | Dale Huffman, commissioner ("the binder") | Hockey | 4 (code), more as the league grows | $160 | 0 | 0 | | At Millbrook at the start. The player's own league |
| `public_skate` | Public skate (the rink's programme) | | Public | 4 | $6 a head, 40 heads | 0 | 0 | Community Ice Agreement minimum | Can't be cancelled |
| `broomball` | Harlow Falls Broomball Club | Kev Szabo | Public | 1.5 | $130 | 30 | 0 | | Broomball shoes chew the ice less than skates, but the club is loud |
| `learn_to_skate` | Adult learn-to-skate | Run by the rink, later a coach | Public | 1 | $140 | 35 | 0 | Rental skates sharp | A good on-ramp to community reputation |
| new `haverstock_oldtimers` | Haverstock Old-timers' Invitational (one weekend in January) | Ronnie Haverstock, via his daughter | Hockey | 18 over a weekend | $2,500 flat plus concessions | 50 | 30 | A beer garden licence | Ronnie still plays Thursdays (`TEAMS.md`) |
| `minor_hockey` | Millbrook Minor Hockey Association | Donna Pettigrew, president | Hockey | 14 | $175 | 50 | 25 | Both dressing rooms usable, a first aid kit and AED | Community Ice Agreement: first refusal on prime ice, rate capped at $175 |
| `figure_club` | Millbrook Figure Skating Club | Hélène Arsenault, coach | Figure | 6 | $170 | 55 | 30 | Surface -3 to -4 C during their slots, clean smooth ice, a sound system | Hard to please, loyal once happy |
| `high_school` | Millbrook High Mallards | Coach Bernie Ostrowski | Hockey | 3 | $165 | 55 | 35 | | Fills dead time; pays 60 days late |
| `vbl_a` | Valley Beer League A Division | Dale Huffman | Hockey | 4 | $185 | 60 | 35 | Two dressing rooms REPAIRED | Moving it from Harlow Falls is a direct fight with them |
| new `hockey_school` | Moose Kowalczuk's Summer Hockey School | Moose's agent | Hockey | 30 a week for 4 weeks (August, after ice-in) or spring ice | $190 | 60 | 40 | Ice in by August 10 | Moose knows. Draws kids from the whole valley |
| new `curling_bonspiel` | Valley Rocks Bonspiel (one March weekend) | Agnes Mulroney, draw master | Curling | 36 over a weekend | $6,000 flat | 65 | 30 | Sheet level within 3 mm (needs the laser level survey), pebble, house circles painted (a mid-season paint job), -4 to -5 C | Curlers notice everything |
| `tournament` | Valley Peewee Tournament (one weekend a month in winter) | Organising committee | Hockey | 22 over a weekend | $190 | 70 | 60 | Four dressing rooms (or two with a tight grid), concessions open, 400 usable seats | Big concessions weekend |
| `lumber_kings` | Millbrook Lumber Kings, Senior AAA (NSHA) | Ray Duchesne, board chair; Old Pete Vachon, equipment manager | Hockey | 6 | $210 | 72 | 55 | Home dressing room REPAIRED, both scoreboard sides working, 600 usable seats, a beer licence for games | At the start they play out the last season of an old lease at $180/h, on probation: if the ice reputation isn't 60 by January they announce a move to Harlow Falls next season |
| `dukes_practice` | Duncannon Dukes practice ice (Minor League Pro) | The Dukes' GM (the red phone is not for you) | Hockey | 4 | $320 | 85 | 75 | Ice temperature logged by a controller, dressing rooms RENOVATED | When their arena hosts concerts |
| new `gnhl_camp` | Kingsport Monarchs rookie camp and road practice (one week in September) | Monarchs' director of operations | Hockey | 3 a day for 7 days | $450 | 88 | 80 | Controller logs and a certificate (an inspector's ice report), dressing rooms RENOVATED, 1,000 lux, a gym or a room that can be one | Their equipment manager measures the ice with his own IR gun. The biggest reputation boost in the game |
| new `tv_event` | TeleNorth Saturday Night Hockey Hometown Weekend | A producer named Kyle | Hockey | One weekend | $40,000 plus sponsor upside | 90 | 85 | Lighting RENOVATED (1,500 lux), 1,000 usable seats, power for the broadcast trucks (a 400 A service upgrade), both scoreboards, parking | Once a year at most, and only one valley rink gets it |

**Organisation profiles.** Each organisation also has a personality that
changes how it scores bids and how forgiving it is:

| Organisation | Cares most about | Forgives | Never forgives |
| --- | --- | --- | --- |
| Beer leagues | Late ice that's cheap, a place to drink after | Bad ice, mostly | Losing their binder |
| Minor hockey | Price, Saturday mornings, safety | One bad session | Cancelled games with no notice; a kid hurt by a rut |
| Figure club | Ice temperature and smoothness, early morning | Price rises | Hockey ice at their session; a rut at a jump landing |
| High school | Dead time, cheap | Late payment (theirs) | |
| Broomball | Cheap late ice | Anything | |
| Senior AAA | Ice, dressing room, crowd, beer | | A bad home playoff game |
| Tournaments | Dressing rooms, the schedule running on time, concessions | | Falling behind schedule |
| Curlers | Level, pebble, temperature | | A 4 mm dip under a house |
| GNHL | Everything measured | | Anything at all |
| TV | Light, power, schedule | | Dead air |

### 5.4 Reputation

Reputation has six dimensions, each 0 to 100, plus an overall stars rating
that matches the tiers in `PROSHOP.md`.

| Dimension | From | Used by |
| --- | --- | --- |
| Ice (`ice_rep`) | Rolling 28-day average of true session ice ratings | Contracts' `min_ice`, every bid score |
| Facility (`min_rooms`) | Facility score (3.5): room ages, cleanliness, broken things | Contracts' `min_rooms`, attendance, sponsors |
| Reliability | Sessions delivered on time as booked; cancellations, late floods, a game held up | Bid scores, renewals |
| Community | Public skate hours, minor hockey, learn to skate, free fundraiser hours, the high school shop class taking sticks (`PROSHOP.md`) | The town, grants, the Community Ice Agreement |
| Hockey | Home clubs' results, tournaments and events hosted, the player's own fame in the career | Sponsors, attendance, the GNHL |
| Business | Bills paid on time, loans in good standing, inspections passed | Loans and interest rates, supplier terms |

| Overall | Score (weighted mean: ice 30%, facility 20%, reliability 15%, community 10%, hockey 15%, business 10%) | Unlocks |
| --- | --- | --- |
| Any | 0 to 29 | Consignment suppliers (Honest, Shorewood, Gripley's) |
| Fair | 30 to 49 | CMC, Kodiak and Warlock entry lines; Marg will talk to you; first sponsors above local level |
| Good | 50 to 69 | Kodiak and Warlock pro, Ironside; regional tournaments; the maintenance tech |
| Great | 70 to 84 | Grafton; GNHL interest; naming rights offers |
| Famous | 85+ | Custom orders; the TV event; the trade show invites you to speak |

Millbrook starts around 22 (Any), with ice about 45, facility 18,
reliability 60 (Gus never cancelled), community 55, hockey 15, business 40.

### 5.5 Sponsors and vendor deals

**Sponsors** pay for space in the building. Sponsor names come from the
`LORE.md` canon; the tier rule (local sponsors in beer league rinks,
Moosebrew, Brokenbone and Double-Double from Senior AAA up) decides who
calls.

| Asset | Count | Worn price a season | Renovated price a season | Notes |
| --- | --- | --- | --- | --- |
| Board ad panel | 24 | $400 | $1,400 | The old 1970s ads (Maple Tire, Moosebrew, Big Gord with more hair, Grizzly Gas) are on expired deals: re-sign or replace |
| Centre-ice logo | 1 | $2,500 | $12,000 | Painted at ice-in (4.11); the sponsor wants it perfect |
| Neutral zone logos | 2 | $800 | $3,500 | |
| Zambelli wrap (Doris's tank sides) | 1 | $1,500 | $3,000 | Earl objects ("She's not a billboard"); relationship hit with Earl |
| Scoreboard | 1 | $1,000 | $5,000 (video board) | |
| Lobby and concession signage | 6 | $200 | $800 | |
| Naming rights | 1 | | $25,000 to $60,000 a year | Great reputation. Renaming the Community Arena costs Community reputation (-15) unless the name keeps "Millbrook" |
| Intermission promotions | Per game | $50 | $300 | The Hearthstone Hot Seat, the Puckhead pizza toss |

Sponsors renew if the rink's attendance and Hockey reputation hold. They
can also be part of supplier deals (co-marketing in `PROSHOP.md`).

**Vendor deals.**

| Vendor | What | Deal shape |
| --- | --- | --- |
| Pro shop brands | Stock for Bev's shop | As `PROSHOP.md` "How the shop grows": reputation thresholds, minimum orders, margin, exclusivity, co-marketing, length |
| Double-Double Donuts | Coffee and donuts for the snack bar | From Fair: their machine and cups, 45% margin, their sign in the lobby |
| Puckhead Pizza | Pizza on game nights | Delivered in under two periods; 20% to the rink; Gino delivers in his goalie mask |
| Moosebrew Lager | Beer garden at Senior games and tournaments | Needs a liquor licence ($600 a year, a health inspection) |
| Grizzly Gas & Go | Doris's fuel and propane | 5% fuel discount for a board ad |
| Hearthstone Furnaces | The boiler | A discounted replacement boiler for the warming room sponsorship |
| Valley Refrigeration Supply | Plant parts | A service contract ($400 a month) gives 10% off parts and priority call-outs |
| Lorne Pettipiece | The broken-stick barrel | As `PROSHOP.md`: $3 a wooden shaft, $1 a composite, standing order every two weeks |

### 5.6 Pricing

The player sets prices; demand responds.

| Price | Start | Range | Who reacts |
| --- | --- | --- | --- |
| Prime ice per hour | $195 | $120 to $350 | Each organisation's hidden budget; casual rentals drop 3% per $5 above the regional average |
| Shoulder ice | $150 | $90 to $250 | |
| Dead time | $95 | $50 to $180 | |
| Public skate adult / child / family | $6 / $4 / $15 | | Attendance by price, weather (cold Saturdays fill it), ice and facility |
| Skate rental | $5 | | Rental skates need sharpening (Bev, $8 a pair cost) |
| Sharpening | $8 (Bev's price) | | `PROSHOP.md` |
| Concessions | Coffee $2, hot chocolate $2.50, fries $4, pizza slice $4.50 | | Spend per head: $2.50 at public skate, $4 at a game, $7 at a tournament |
| Beer at Senior games | $6 a pint ($2 cost) | | Licence needed |

Regional averages are visible in the office (the rate sheet the valley rinks
all secretly share). Raising rates mid-contract isn't allowed; at renewal it
costs relationship.

### 5.7 Events and tournaments

Events are planned projects with a checklist and a run-of-show, played in
the evening and day blocks at higher speed.

**Planning (from 8 weeks ahead).**

| Task | Lead time | Notes |
| --- | --- | --- |
| Accept the booking and the deposit | 8 weeks | 25% deposit |
| Build the schedule | 4 weeks | Games every 75 minutes with a flood, or every 60 with no flood (cheaper ice, worse ice) |
| Staff the weekend | 2 weeks | Extra floods, dressing rooms, concessions, the timekeeper |
| Order concessions stock | 1 week | Running out of fries is a reliability hit |
| Ice preparation | 2 days | Edge, level, a deep night flood |
| Signage and sponsors | 1 week | Tournament sponsor banners |
| Referees' room | | The office, if nothing else |

**Running it.** The schedule runs live. Each game can run long (overtime,
an injury); a late flood pushes every later game; falling 30 minutes behind
costs reliability and relationship. Concessions sales spike between games.
Ice wears fast: 20 hours of hockey in a day with 10-minute floods tests the
plant and the blade.

| Event | Revenue (typical) | Costs | Reputation |
| --- | --- | --- | --- |
| Valley Peewee Tournament | Ice $4,200, concessions $3,000 net | Staff $900, stock, extra power | Hockey +3, Community +2 |
| Haverstock Old-timers' | $2,500 flat, beer garden $1,800 net | Licence, staff | Community +4 |
| Valley Rocks Bonspiel | $6,000 flat, bar $2,000 | House circles painted and removed after ($600, an ice cut) | Ice +2 if it goes well |
| Hockey school (4 weeks) | $22,800 | Ice-in early (power) | Hockey +3 |
| GNHL rookie camp | $9,450 plus a big reputation boost | Everything must be perfect | Hockey +10, Ice +5 |
| TV event | $40,000 plus sponsor upside | Lighting and power upgrades first | Hockey +15, sponsors' offers double |
| Dry floor in summer | Farmers' market $400 a Saturday, a wedding $2,500, ball hockey $60/h | Cleaning | Community |

### 5.8 Finance and renovation projects

**The monthly P&L** (an office screen, also printed on the corkboard).

Example: October, Year 1, before minor hockey comes back.

| Revenue | $ | Costs | $ |
| --- | --- | --- | --- |
| Ice: Lumber Kings (old lease, 6 h/wk at $180) | 4,640 | Electricity (70,000 kWh at $0.13, plus a 150 kW demand charge at $14) | 11,200 |
| Ice: casual rentals (8 h/wk) | 5,160 | Natural gas (boiler, flood water) | 1,700 |
| Ice: Valley Beer League | 2,750 | Gasoline (Doris, edger) | 600 |
| Public skate | 2,060 | Water and sewer | 650 |
| Ice: broomball, learn to skate | 1,440 | Insurance | 1,400 |
| Concessions (net) | 1,600 | Property tax | 1,000 |
| Pro shop margin (Bev's shop) | 900 | Parts and supplies | 900 |
| Skate rental | 400 | Water treatment, glycol tests | 150 |
| Board ads | 350 | Phone, internet, waste | 200 |
| Stick barrel | 40 | Wages | 0 |
| | | Loan interest | 70 |
| **Total** | **19,340** | **Total** | **17,870** |
| | | **Net** | **+1,470** |

A good month, until compressor 1 trips. Winning minor hockey back adds about
$10,500 a month; a Doris engine rebuild costs $6,500.

**What a year looks like** at Millbrook as it grows (rough targets for
balancing):

| Year | Revenue | Costs | Net | What changed |
| --- | --- | --- | --- | --- |
| 1 | $190,000 | $195,000 | -$5,000 | Survive; a few repairs; the line of credit |
| 2 | $280,000 | $250,000 | +$30,000 | Minor hockey, figure club, staff, two rooms REPAIRED |
| 3 | $370,000 | $310,000 | +$60,000 | Lumber Kings' new lease, tournaments, the controller, the owner's draw starts |
| 5 | $520,000 | $410,000 | +$110,000 | Renovated rooms, the GNHL camp, a new floor on a loan |

**Cash and timing.** Cash is separate from profit: organisations pay net
30, suppliers want payment on delivery until Business reputation is Fair,
the electricity bill lands on the 15th. Running out of cash means the line
of credit, then missed payments (Business reputation falls), then the bank
calls.

**Owner's draw.** The owner can pay themselves from the rink (the transfer
lands in the career's `money`). The Community Ice Agreement blocks it for the
first two seasons; after that it's capped by the bank while a loan is
outstanding (25% of the last quarter's profit).

**Loans and grants.**

| Source | Amount | Rate | Term | Conditions |
| --- | --- | --- | --- | --- |
| Frostbank line of credit | $25,000 (more with Business reputation) | 8.5% | Open | Start |
| Frostbank term loan | Up to 3x last year's net plus 50% of a project | 7.5% (6.5% at Business 70+) | 5 to 10 years | Monthly payments; covenant: no missed payments |
| Town of Millbrook capital loan | Up to $150,000 | 2% | 10 years | Community reputation 50+; keeps minor hockey's rate cap for the term |
| Community Rink Revitalisation Fund (province) | 50% of an energy project, up to $150,000 | Grant | | An energy audit ($1,500), a 3-month application, the project must save 20% of plant energy |
| Equipment financing (Zambelli, Flatley dealers) | A machine's price | 6.9% | 5 years | The machine is the collateral |
| Sponsor prepayment | One season of naming rights | | | Great reputation |

**Renovation projects.** Each `Venue` room moves WORN to REPAIRED to
RENOVATED through a project with a cost, a duration, a season (some need the
ice out) and an effect. `Venue.set_room_age(room_id, age)` is called when a
project finishes.

| Room | To REPAIRED | To RENOVATED | Effects |
| --- | --- | --- | --- |
| locker_home | $15,000, 2 weeks, any time (the visitors' room doubles up) | $85,000, 6 weeks, summer | Facility +, contract requirements, player morale for home clubs |
| locker_away | $15,000, 2 weeks | $85,000, 6 weeks | Same |
| lobby | $18,000, 3 weeks (open with a tarp) | $120,000, 8 weeks, summer | Facility (weight 3), concessions spend +30%, Bev's lobby window (`PROSHOP.md`) |
| office | $3,000, 1 week | $25,000, 2 weeks | Unlocks the PC tier of the office tools |
| stands_bench, stands_box | $25,000 each, 3 weeks | $300,000 each, 10 weeks, summer | Usable seats 60% to 85% to 100%, attendance |
| lighting | $12,000 (replace dead lamps and ballasts), 1 week | $95,000 (LED, 1,000 lux; 1,500 lux TV package $140,000), 2 weeks | Lux; LED cuts 30 kW of heat on the ice and about $1,800 a month of power |
| glass | $20,000, 1 week | $110,000 (seamless acrylic), 3 weeks, summer | Safety inspection, Senior and pro requirements |
| benches, penalty_boxes | $6,000 each | $30,000 each | Small facility |
| roof | $40,000 (patch and recoat), 2 weeks, dry weather | $250,000 (new membrane and insulation), 6 weeks, summer | Ends the March drip; a low-emissivity ceiling ($45,000 add-on) cuts radiant heat on the ice by 20% |
| shell | $30,000 (seal, paint, dehumidifier service) | $180,000 (new dehumidifier, ventilation, insulation) | Fog, air quality |
| zamboni_bay | $8,000 (drain, snow pit heater) | $45,000 (towel rack, blade sharpener room, a level pad, wash bay) | Doris jobs faster, towel life x2 |
| scoreboard | $5,000 (fix the dead side) | $60,000 (video board) | Sponsors, Senior requirement |
| new `plant_room` | $10,000 (ventilation, ammonia detection, eyewash) | $40,000 (the room done properly: detection, emergency exhaust, a control room window) | Ammonia inspection |

**Plant and machine projects** (not rooms, but the same project system):

| Project | Cost | Duration | Effect |
| --- | --- | --- | --- |
| Compressor overhaul by contractor | $12,000 each | 2 weeks | All compressor parts to 0.95 |
| New high-efficiency compressor | $65,000 each | 3 weeks, summer | 20% more efficient, a digital unloader |
| Digital plant controller | $28,000 | 1 week | Instrument tier (5.9), automatic setback and demand control, alarms |
| Remote monitoring | $4,000 plus $60 a month | 1 day | Alarms on the phone; the night trip no longer waits until 05:00 |
| Variable speed drives (pump, condenser fan) | $9,000 | 3 days | Pump and fan power down 40% |
| Standby glycol pump | $14,000 | 1 week | No ice clock on pump jobs |
| Header isolation valves | $12,000 | 2 weeks, summer | Leak hunts become quick |
| Heat recovery (compressor heat warms the flood water, the subfloor and the lobby) | $55,000 | 3 weeks, summer | Gas bill down 60% |
| Automatic water treatment | $2,200 | 1 day | Condenser scale x0.3 |
| New refrigeration floor (and a new header) | $650,000 | 12 weeks from ice-out | Every floor and header part new, isolation valves, slab probes, a level floor; the Revitalisation grant and a town loan usually pay for half |
| Doris restoration | $18,000 | 4 weeks | Doris in club colours, all parts 0.95 (`LORE.md`) |
| Propane conversion | $3,800 | 1 week | CO down 70% |
| Flatley electric resurfacer | $145,000 | | No CO, cheaper running; Earl won't drive it |
| Polarix Glide | $260,000 | | Drives itself; refuses to move around mascots; late game |

### 5.9 The measurement and tool upgrade tree

Sean: "As time goes on the maintenance and measurement methods become more
accurate." Three things make that true:

1. **Instruments** narrow error and add readings (`SimInstrument.CATALOG`
   tiers).
2. **Methods** change how a job is done (a torque wrench instead of feel, a
   laser instead of a string, a controller instead of a log book).
3. **Experience**: owner and staff skill shrink the error of the senses
   (2.3).

Tools come from the Harlow Falls hardware store, Valley Refrigeration
Supply, the Zambelli catalogue, and the Northern Rink Operators' trade show
(every May, in Duncannon: new tools and machines unlock there, and the
Zambelli and Flatley booths are as far apart as the hall allows).

| Tier | Ice | Plant | Machines | Building | Office |
| --- | --- | --- | --- | --- | --- |
| T0 Start (Gus's kit) | Screwdriver test (+/- 2.5 C); drill and ruler (+/- 5 mm); eye and string | Dial gauges (+/- 5 psig); sight glass words; "it sounds rough"; dial thermometer (+/- 1.5 C); the nose; sulphur sticks; the log book | Thumbnail blade test; coin plug gauge; feel for torque; Gus's timing method | Wet finger for humidity; "dim at the far end" | The binder, a wall calendar, a cash box |
| T1 Hardware store ($20 to $250, any reputation) | IR gun ($89, +/- 0.5 C); ice thickness gauge ($220, +/- 1.5 mm) | Hydrometer ($35, +/- 3%); test gauge set ($140, +/- 1 psig); clamp meter ($120); stethoscope ($35); pH strips ($25) | Feeler gauges ($18); wire plug gauge ($8); torque wrench ($140, +/- 4%); belt tension gauge ($30); sheave gauge ($25) | Hygrometer ($40); light meter ($95); handheld CO meter ($180) | A spreadsheet on an old laptop: booking errors halved |
| T2 Trade suppliers ($150 to $1,000, Fair) | Laser level, basic ($1,200) | Refractometer ($180, +/- 0.5%); pH meter ($140); vibration pen ($450); oil lab analysis ($60 a sample); conductivity meter ($160); handheld ammonia detector ($650); dial indicator alignment ($240) | Dial blade setting gauge ($180); compression tester ($60); timing light and dwell meter ($110); digital torque wrench ($320); vacuum pump ($450); induction bearing heater ($600) | Thermal camera ($900); ultrasonic leak detector ($900) | Booking software ($40 a month): the online calendar, invoices, fewer phone calls |
| T3 Trade show ($1,000 to $5,000, Good) | Laser level survey with mapping software ($2,600, +/- 0.5 mm, every cell); slab temperature probes ($1,400, +/- 0.15 C) | Digital controller (part of the $28,000 project: +/- 0.2 C, +/- 0.5 psig, logs everything); laser shaft alignment ($2,800) | Laser blade jig ($650); exhaust gas analyser ($850); in-house blade sharpener ($4,800) | Fixed CO/NO2 monitor ($1,600); dew point control with the dehumidifier | Accounting and payroll software; the P&L by department |
| T4 Late game (Great) | Ultrasonic thickness scanner on the resurfacer (+/- 1 mm, every flood); overhead IR sensors (the whole sheet live) | Remote monitoring with predictive alerts ("valve plates on 1 are trending to failure in about 600 hours") | Polarix mapping on any machine; painting robot | Building management system | Data on every organisation's history; bid predictions |

**What each upgrade changes in play.**

| Upgrade | Before | After |
| --- | --- | --- |
| IR gun | "About right" from a screwdriver, can't hit the figure club's -3 to -4 window on purpose | A number to 0.5 C: setpoints become a plan |
| Refractometer | A hydrometer reading of 33% that might be 30% | 34.6% +/- 0.5: no surprise freeze-ups |
| Vibration pen | The pump growls when it's nearly dead | 4.5 mm/s and rising: replace it in a quiet week |
| Oil lab | Change oil when it's black | Know the bearings are wearing before they knock |
| Digital controller | A log written at 05:10 with the gauges' errors | Every minute logged, alarms, automatic setback and demand control; plant rounds 0.25 h |
| Remote monitoring | A Wednesday night trip is found at 05:00 with the ice at -2 C | The phone rings at 01:40; the player (or Marg) resets it from bed or drives in |
| Laser level | Leveling by guesswork | A contour map; curling unlocks |
| Thermal camera | A leak hunt of 10 hours | 2 minutes to find the warm stripe |

### 5.10 Inspections

| Inspection | Who | When | Checks | Fail means |
| --- | --- | --- | --- | --- |
| Health | District health inspector | Twice a year, one unannounced; after complaints | Washrooms, concessions (fridge temperatures, handwashing), dressing room mould, air quality during a flood (CO under 25 ppm average, NO2 under 0.3), condenser water (Legionella sample) | A fine ($500 to $2,000), a re-inspection, closing the snack bar or the building until fixed |
| Fire | Millbrook fire department | Yearly | Exits clear (the corner clutter at WORN), extinguishers, emergency lights, occupancy (usable seats), alarms | Occupancy capped, fines, events blocked |
| Ammonia and pressure vessels | Provincial boiler and pressure vessel inspector | Yearly, plus the 5-year relief valve date | Machine room ventilation and detection (25 ppm alarm, 150 ppm emergency exhaust), the emergency stop outside the door, relief valve dates, operator certification (someone with a Refrigeration Operator certificate on staff or on contract), the log book with daily entries, eyewash station, PPE | A plant shutdown order: the worst fail in the game. Gaps in the log are a warning |
| Insurance | Brokenbone Mutual's surveyor | Yearly | Boards and glass, ice condition, first aid, the AED, the snow pit fence, slip hazards | Premium up 20 to 50%; a pass with no notes gives 10% off |
| Electrical | Harlow Falls Electric | Every 5 years, and for the TV power upgrade | The 1974 panel (breaker 14) | Repairs ordered |
| Hockey association sanction | The valley's hockey association | Before the season | Line positions (4.11), glass height, gates, first aid, dressing rooms | Sanctioned games can't be played at the rink until fixed |

Each inspection is a short in-person scene (the inspector walks, the player
follows), then a report with points. Better instruments and logs are
evidence: a controller printout satisfies the ammonia inspector in a minute;
a log with gaps doesn't.

### 5.11 Staff management

Beyond hiring (2.2):

| Screen or action | What it does |
| --- | --- |
| Roster | Assign staff to grid blocks (floods, the counter, the plant) by week; the grid turns red where nobody is assigned |
| Job queue | Jobs (mini games) waiting: assign to a person, a contractor or "I'll do it" |
| Training | Courses that raise skill and unlock jobs (Refrigeration Operator Class B lets the owner or Marg sign the ammonia log) |
| Reviews | Every 3 months: reveals the person's true skill and morale more accurately, sets raises |
| Rules | Standing orders: "flood after every session", "never skip the 06:00 check", "call me if the plant trips" |

Personalities: Earl argues with any change to Doris; Dylan is fast and
sloppy and gets good; Marg writes in the log in red pen when the player's
entries are wrong; Bev tells the truth about supplier deals and charges for
it.

---

## 6. Connections

### 6.1 The hockey career

The player still plays in the valley leagues (`Career`, `LeagueTiers`). The
career and the rink share `Career.day`.

| Career state | Rink effect |
| --- | --- |
| Beer League D or C | The player's games are at Millbrook, late ice (`vbl_d` slots). Someone has to flood before, at intermission and after; with no staff, the owner floods in full gear, which costs a warm-up and is a running gag |
| A home game | The grid marks it; the owner can't do other work for 3 hours |
| A road game | Travel on the region map costs the evening (`docs/WORLD.md`): the rink needs a driver and the plant needs someone on call |
| Beer League A | Games in Harlow Falls: the competitor's rink, which the player can look at (their ice, their dressing rooms) |
| Senior AAA | If the Lumber Kings sign a new lease, the player's own team plays at the player's rink in front of the player's crowd. Profit as a player starts here (`PROSHOP.md`), and the rink's beer garden is open |
| Semi-Pro, Minor Pro | Games every 3 to 4 days, practices most days, road trips: the rink must run on staff |
| League dues | The owner plays free while learning (the first 8 weeks). Then Dale Huffman, the Valley Beer League commissioner, calls: owner or not, everybody pays their dues, because the $120 season fee (`PROSHOP.md`) buys the refs, the scorekeeper, the pucks and the jerseys. Two weeks' grace, then "no dues, no game" (`RinkSim.league`, `pay_dues()`, `owner_can_play()`; Mechanics reads `owner_can_play()` before the owner's game) |
| Fatigue | Owner fatigue feeds `Progression.rest` (an overworked owner plays tired); a day off restores both |
| Fame | The player's career fame raises the rink's Hockey reputation; a famous local player unlocks Doris's retirement fund raffle (`PROSHOP.md`) |

The career's offseason today jumps `day += 120`. With the rink sim, the
offseason is the summer shutdown and is played (projects, ice-in), so the
jump should move to "the next ice-in" or be replaced by playing the days.
That is a Game mechanics decision (open question 1).

### 6.2 The Physics hook: ice quality on the puck

The rink's ice affects how the game plays. At the start of a match at
Millbrook (and at any rink, from that rink's state), the sim hands the match
an `IceSurface` summary. Physics decides how to use it; these are proposed
inputs with suggested ranges:

| Field | Range | From | Suggested effect |
| --- | --- | --- | --- |
| `puck_friction_mult` | 0.85 to 1.35 | Surface temperature (warmer is slower), snow, smoothness | Puck slide friction |
| `skate_glide_mult` | 0.9 to 1.05 | Temperature, snow | Skater glide and top speed |
| `edge_grip_mult` | 0.9 to 1.1 | Temperature (soft ice grips, too soft gives way), ruts | Turn and stop sharpness |
| `bounce_noise` | 0 to 1 | Ruts, chips, smoothness, hardness (brittle cold ice) | Random puck hops and rolling pucks |
| `snow_rate` | 0.5 to 2 | Hardness, temperature | How fast snow builds during a period, raising friction until the intermission flood |
| `edge_lip_mm` | 0 to 30 | Edge buildup | Pucks along the boards die or pop up |
| `soft_spots` | List of rink positions and strength | Grid cells with warm or thin ice | Local friction and rut patches |
| `dead_board` | The Millbrook bank (`LORE.md`) | The board segment behind the net | Already lore: the puck dies there. Kept unless the player renovates it away |

Between periods, the intermission flood (or a skipped one) resets snow and
smoothness. Away rinks have their own fixed ice profiles (Kessler's barn "like
a gravel road", per Bev).

### 6.3 The region: competitors

The other rinks in `docs/WORLD.md` and `TEAMS.md` bid for the same
contracts. Each competitor is a simple AI rink: an ice rating, a facility
score, rates, a few personality rules, and scripted upgrades.

| Rink | Starts at | Personality | Story beats |
| --- | --- | --- | --- |
| Harlow Falls Municipal Twin Pad | Ice 64, facility 55, rates $185 to $210 | Tidy, municipal, slow to change; two pads so it can offer more slots; Brendan Quinn's laminated five-year plan | Has Millbrook's minor hockey hours at the start. Its R-22 plant faces the refrigerant phase-out in Year 3: a summer closure and a chance to win contracts |
| Kessler Memorial Arena (the Barn) | Ice 52, facility 40 | Natural feel, brine plant, standing room, loud; cheap; the mill's money | Competes for beer leagues and old-timers, never for figure skating |
| Port Ainsley Lakeside Arena | Ice 62, facility 50 | Lake town, the pond rink in deep winter | Opens a second pad in Year 4 |
| Duncannon Frostbank Centre | Ice 88, facility 92 | The benchmark: expensive, booked by pro hockey and concerts, rarely available | Undercuts on tournaments in Year 2 to fill dead weekends; the GNHL's first call until Millbrook earns it |
| Duncannon Memorial Gardens | Ice 48, facility 30 | The 1949 rink, run-down like Millbrook | Could close (its contracts go to auction) or be renovated by a rival owner |

Competitors also affect away games for the player (their ice profiles go to
Physics the same way) and provide things to learn from: visiting Harlow Falls
for a Beer League A game lets the player look at their plant room (a free
idea, and a tool sometimes: "their IR gun is the $89 one").

---

## 7. Data shapes and ownership

Shapes follow the existing sim core: pure-logic `RefCounted` classes with
`to_dict()` / `load_dict()` (or `from_dict()` on `RinkSim`).

### 7.1 Components

`SimPart` grows a few fields; existing fields keep their meaning.

```gdscript
# SimPart (existing: id, name, condition, hours, life_hours, price, fail_below)
var system := ""            # "plant", "ice", "resurfacer", "edger", "building"
var location := ""          # Venue room id or node path for the 3D scene ("plant_room/compressor_1/head_3")
var cycles := 0             # starts, floods
var life_cycles := 0        # 0 = wears by hours only
var supplier := ""          # "valley_refrigeration", "zambelli", "maple_tire", "hardware"
var lead_days := 0
var flags := []             # hidden mistake flags from the last install ("bolt_undertorqued")
var install_quality := 1.0
```

Failure modes and symptoms are data, not code, in
`scripts/world/sim/parts.json` (World and asset design):

```json
{
  "compressor.valves.discharge_plate": {
    "name": "Discharge valve plate", "price": 32, "qty": 4, "life_hours": 9000,
    "assembly": "compressor.valves",
    "failure_modes": [
      {"id": "leaking", "below": 0.45,
       "symptoms": ["head_hot", "discharge_temp_high", "capacity_low"],
       "effect": {"capacity_mult": 0.85, "discharge_temp_add": 15}},
      {"id": "cracked", "below": 0.1,
       "symptoms": ["knock_light", "trip_high_temp"],
       "effect": {"trip": true}}
    ]
  }
}
```

```json
"symptoms": {
  "head_hot": {"sense": "touch", "text": "Head 3 is too hot to keep your hand on.",
               "reading": "head_temp", "where": "plant_room/compressor_1/head_3"},
  "squeal_start": {"sense": "sound", "text": "A squeal from the roof when the fan kicks in.",
                   "audio": "belt_squeal", "when": "fan_start"}
}
```

### 7.2 Instruments and readings

Readings are the things that can be measured; instruments are the ways to
measure them. `SimInstrument.CATALOG` already holds tiers per reading with
`sigma`, `price` and `bands`. Proposed additions per tier:

```json
{"id": "ir_gun", "name": "Infrared thermometer", "sigma": 0.5, "price": 89,
 "bias": 0.0, "minutes": 0.5, "where": "anywhere",
 "unlock": {"reputation": 0, "source": "hardware"},
 "adds_readings": ["head_temp", "bearing_temp"],
 "fatigue_sensitive": true}
```

| Field | Meaning |
| --- | --- |
| `sigma` | 1-sigma error (existing) |
| `bias` | A fixed offset for an uncalibrated tool (the old dial thermometer reads 1 C warm); calibration removes it |
| `minutes` | Time cost per reading |
| `where` | Where the player must be (a room id) |
| `unlock` | Reputation, a source (shop, trade show), a course |
| `adds_readings` | New readings this tool makes possible |
| `skill_scaled` | For senses: sigma shrinks with owner skill (the ear) |
| `fatigue_sensitive` | Fatigue adds error |

Every reading taken goes to the **log book** with the day, minute, who,
instrument and value, so trends and inspectors can use it.

### 7.3 Contracts

`RinkContracts.ORGS` entries today: `id, name, use, slots, rate, per_head,
heads, min_ice, min_rooms, weeks`. Proposed additions:

```json
{
  "id": "minor_hockey", "name": "Millbrook Minor Hockey Association",
  "contact": "Donna Pettigrew", "use": "hockey",
  "slots": [[1, 17.0, 3.0], [3, 17.0, 3.0], [6, 8.0, 4.0], [0, 8.0, 4.0]],
  "rate": 175.0, "min_ice": 50.0, "min_rooms": 25.0, "weeks": 24,
  "requires": {"rooms": {"locker_home": "WORN", "locker_away": "WORN"},
               "dressing_rooms": 2, "seats": 0, "aed": true,
               "temp_window": null, "cert": null},
  "budget": [160.0, 185.0],
  "weights": {"price": 0.4, "slot_fit": 0.3, "ice": 0.15, "facility": 0.1, "distance": 0.05},
  "personality": "minor_hockey",
  "rfp_month": 3, "season_start_month": 10
}
```

Weekdays count from 0 = Sunday, as in the code. Minor hockey's weekend
sessions are `[6, 8.0, 4.0]` and `[0, 8.0, 4.0]` (Saturday and Sunday).

A signed contract in the save:

```json
{"org": "minor_hockey", "rate": 172.0, "slots": [[1, 17.0, 3.0]], "start_day": 30,
 "end_day": 198, "escalator": 0.02, "extras": ["storage"], "ice_clause": 50.0,
 "strikes": 0, "relationship": 58, "paid_through_day": 60, "owed": 2150.0}
```

### 7.4 The save

`RinkSim.to_dict()` holds the whole rink. Game mechanics owns the career
save format, so this goes under the `world` key that `docs/WORLD.md` already
proposes, as `world.rink_sim` (agreed with Mechanics first).

```json
"world": {
  "rink_sim": {
    "version": 1,
    "rink_id": "millbrook_community_arena",
    "minute": 340, "start_weekday": 1,
    "rng_state": "...",
    "cash": 8000.0,
    "loans": [{"id": "frostbank_loc", "balance": 0.0, "limit": 25000.0, "rate": 0.085}],
    "plant": {"compressors": [], "condenser_scale": 0.15, "glycol_pct": 31.0, "...": "RefrigerationPlant.to_dict()"},
    "ice": {"surface_temp": -4.0, "thickness_mm": 48.0, "grid": [], "...": "IceSlab.to_dict()"},
    "resurfacer": {"parts": {}, "...": "ResurfacerSim.to_dict()"},
    "edger": {"parts": {}},
    "building": {"rooms": {"lobby": 0, "locker_home": 0}, "systems": {}},
    "instruments": ["screwdriver", "drill_ruler", "dial", "ear", "sight_glass"],
    "skills": {"ice": 0.6, "refrigeration": 0.3, "mechanic": 0.4, "building": 0.3, "business": 0.3},
    "fatigue": 12.0,
    "staff": [{"id": "dylan", "role": "rink_rat", "wage": 15.0, "skill": {"floods": 0.4}, "morale": 70, "reliability": 0.8}],
    "contracts": [],
    "requests": [],
    "grid": {"week_start_day": 0, "blocks": []},
    "reputation": {"ice": 45.0, "facility": 18.0, "reliability": 60.0, "community": 55.0, "hockey": 15.0, "business": 40.0},
    "relationships": {"minor_hockey": 35, "figure_club": 20},
    "sponsors": [],
    "ledger": [{"day": 3, "cat": "electricity", "amount": -11200.0}],
    "log_book": [{"day": 0, "minute": 310, "who": "owner", "reading": "suction_psig_1", "instrument": "dial", "value": 22.0}],
    "jobs": [],
    "projects": [],
    "inspections": [],
    "inventory": {"spark_plugs": 4, "blade": 0},
    "orders": [],
    "goals": ["keep_bookings", "ice_under_40", "compressor_1", "minor_hockey_slot"]
  }
}
```

`Venue.get_state()` returns `{room_id: age}`; the rink sim's
`building.rooms` is the source of truth and calls `Venue.apply_state()` when
the building scene loads.

`RinkSim` API sketch (pure logic, no nodes):

```gdscript
class_name RinkSim
extends RefCounted

enum Block { EARLY, DAY, EVENING, NIGHT }
const OWNER_HOURS_PER_DAY := 14.0
const OVERTIME_MAX := 4.0

static func create_millbrook(seed: int) -> RinkSim
func advance(minutes: int) -> Array          # returns events (trip, call, delivery, inspection)
func advance_to_block_end() -> Array
func block() -> Block
func read(reading: String, who := "owner") -> Dictionary   # through the best owned instrument, logs it
func start_job(job_id: String, worker := "owner") -> Dictionary  # time and parts reserved
func finish_job(job_id: String, result: Dictionary) -> void      # quality and flags from the mini game
func book(block: Dictionary) -> bool
func bid(request_id: String, offer: Dictionary) -> void
func month_pnl(month: int) -> Dictionary
func ice_surface() -> Dictionary               # the Physics hook (6.2)
func to_dict() -> Dictionary
static func from_dict(d: Dictionary) -> RinkSim
```

A mini game scene receives the job and the parts' true state, plays out,
and returns `{quality, hours, parts_used, flags, injuries, readings}` to
`finish_job`. The scene never writes the sim directly.

### 7.5 Ownership

| Piece | Owner |
| --- | --- |
| `scripts/world/sim/` (`RinkSim`, `SimPart`, `SimInstrument`, `IceSlab`, `RefrigerationPlant`, `ResurfacerSim`, `RinkContracts`), `parts.json`, organisations and competitors data, the economy numbers | World and asset design (sim core) |
| Mini game scenes and their logic (`scenes/world/jobs/`), part and tool models, the plant room, Doris's opened-up parts, the edger, the trade show | World and asset design (mini games, art) |
| Voxel art for parts, tools, the plant, symptoms (steam, frost, drips, scale) | World and asset design |
| The building rooms, the new `plant_room` and header trench, placing machines and job spots in rooms, walking around the rink, doors, room ages via `Venue.set_room_age` | Rink environment |
| `Career.day`, travel time, the career save's `world` key, `money` and the owner's draw, fatigue into `Progression.rest`, the offseason change | Game mechanics |
| Management screens: the ice grid, bids, the P&L, staff, the log book, the instrument readouts, the region map's rink layer | UI (to `assets/ui/STYLE.md`) |
| Mini game input (grab, turn, torque hold, steer the edger and Doris) | Controls, with World and asset design |
| The `IceSurface` hook: puck friction, bounce, snow, edge lip, soft spots | Physics |
| This doc, milestones and the open questions | Project manager with World and asset design |

---

## 8. Milestones

### M1: the vertical slice (one week at Millbrook)

One playable week, Monday to Sunday, first week of September, Year 1.

| In | Detail |
| --- | --- |
| `RinkSim` | Minute clock, four blocks, hours budget and fatigue, the event list, `to_dict`/`from_dict`, saved under `world.rink_sim` |
| Plant | Two compressors with valves, rings, bearings, seal, oil (existing `RefrigerationPlant`), the condenser with scale and fan belt, the glycol loop with pump, concentration and a weeping header. Compressor 1 trips on low oil pressure on Wednesday night if its oil isn't serviced |
| Ice | `IceSlab` with the 20 x 8 grid for thickness and smoothness, the three use targets, ratings per session, the 48 mm starting thickness |
| Doris | `ResurfacerSim` with the "won't start" tutorial and driving the flood pattern (a top-down flood view is fine for M1) |
| Instruments | T0 for everything, plus two buyable upgrades: the IR gun and the refractometer |
| Two mini games | 4.2 Compressor oil and filter service and 4.7 Resurfacer blade change and height setting, in full (the "won't start" plug change as the tutorial slice of 4.8) |
| Three contracts | `vbl_d` (signed), `public_skate` (signed), `minor_hockey` (a bid that can be won during the week if the ice reputation reaches 50) |
| Grid | The weekly grid with sessions, auto-floods and who floods them |
| Economy | The week's P&L with real line items; the electricity bill on the desk |
| Gus's binder | The first-hour notes and the week's four goals |
| The player's game | The Tuesday BL-D game at Millbrook, with floods around it. Free while the owner learns |
| UI | Office screens in RinkOS style: grid, log book, P&L, the job queue |

| Out of M1 | Why |
| --- | --- |
| Staff | Week 2 at the earliest in the story |
| Renovations, loans | Need months |
| Building systems beyond lights and the snow pit | Later |
| The region's competitors | Bids are scored against a fixed Harlow Falls offer in M1 |
| The Physics hook | M3 |

Done when: a tester plays the week start to finish, both mini games change
the sim (a good oil service prevents the Wednesday trip; a bad blade height
shows on the ice), the minor hockey bid can be won or lost, and the P&L adds
up.

### Later milestones

| Milestone | Adds |
| --- | --- |
| M2: A month | Staff (Dylan, Earl, Bev), mini games 4.3 valve job, 4.4 glycol, 4.9 squeegee and towel, 4.10 edging and leveling; the figure club and its temperature window; the first inspection (health); the monthly P&L and the line of credit |
| M3: The season | All 11 mini games except ice-in painting; the full contract list to Senior AAA; the bidding season in spring; reputation dimensions; sponsors and vendor deals tied to `PROSHOP.md`; the Physics `IceSurface` hook; the Lumber Kings probation story |
| M4: The year | Summer shutdown and projects, renovations through `Venue.set_room_age`, loans and grants, ice-out and ice-in with mini game 4.11, the trade show and the T2/T3 tool tiers, all inspections |
| M5: The region | Competitor rinks bidding, Harlow Falls' plant phase-out, tournaments and events with run-of-show, the career's offseason played instead of skipped |
| M6: Prestige | The digital controller and remote monitoring, the new floor project, the GNHL camp, the TV event, Doris's restoration or a Flatley or a Polarix, naming rights |
| M7: Other rinks | Owning or managing a second rink (Duncannon Memorial Gardens), a staff hierarchy, the owner as a pure GM |

### Open questions

1. **The offseason.** The career's `start_next_season()` adds 120 days. With
   the rink sim, should the summer be played day by day (projects, ice-in) or
   time-skipped with a summary? Suggestion: played, with "skip to the next
   event" making it fast. Game mechanics.
2. **Rink-rat shifts.** `PROSHOP.md` has the player earning $30 rink-rat
   shifts at Millbrook. If the player owns Millbrook from day one, those
   shifts become the owner's own work. Suggestion: keep the $30 shifts as
   pay from the town's transition fund for the first season (the Community
   Ice Agreement pays the owner $60 a week while the draw is blocked), so the
   `PROSHOP.md` early economy is unchanged. Sean and Game mechanics.
3. **Starting thickness.** Decided (Sean, 2026-10-17): 48 mm, with the
   thin-versus-thick trade-offs in 3.2.
4. **The plant room.** Rink environment to add a `plant_room` room and the
   header trench to `Venue`.
5. **First person or diorama for mini games.** First person in the real room
   matches the walkable venue; a bench diorama is cheaper for M1. Suggestion:
   first person for the plant room jobs, a raised workbench view for Doris's
   blade and squeegee.
6. **Ammonia or freon.** Decided (Sean, 2026-10-17): ammonia at Millbrook,
   R-22 at Harlow Falls, and the owner can convert later. See "The
   compressor problem" in 3.1.
7. **Physics.** Which `IceSurface` fields the puck and skater can take, and
   whether soft spots are worth a per-position lookup.
