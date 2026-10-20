# RinkGM paths: Player, Coach, GM

A game design for Sean, written for the developers who build it. Owned by the
World and asset design thread (story, characters, beat data), with the
systems handed to Game mechanics, Physics, Controls, UI and Rink environment
(section 8).

Sean, 2026-10-18: "I also want multiple paths the owner can go down: Coach,
Player, GM. Each one has its own unique storyline and character arcs. I don't
want the game to feel like a chore though. I want it to be a mostly relaxing
experience and only chaotic if maintenance is neglected, the schedule isn't
set, customers are treated poorly." Inspirations: Slapshot Rebound and Puck
for physics controls where the player's own dexterity is the skill, Tape to
Tape for the RPG layer, and the NHL games for the feeling of a real, living
league.

This doc sits on top of `LORE.md` (the GNHL, the legends, the brands),
`TEAMS.md` and `teams.json` (every club on the ladder), `PROSHOP.md` (Bev,
money, gear) and `RINK_SIM.md` (the rink loop, hours, staff, contracts). It
reuses their people and places and tries not to contradict them. Where it
proposes a change to one of them, it says so (section 8.4).

The short version:

- The owner always owns Millbrook Community Arena. A **path** is the owner's
  hockey ambition on top of that: play it, coach it, or run it.
- Year 1 is a soft intro where the owner tries all three. At the Legion
  Christmas party they choose one **main path**. The other two stay open as
  smaller **side roles**.
- The game is **cozy by default, chaos you earned**. A well-run rink runs
  itself. Chaos comes only from neglected maintenance, an unset schedule or
  customers treated poorly. It always warns first, it arrives one problem at
  a time, and it never ends a save.
- The hockey is **hands first**. On the ice, outcomes come from the player's
  stick, timing and skating. Ratings shape what the body can do; they never
  roll dice on whether a shot goes in.
- The rink is **one plan a day**. Each morning the owner sets the day's ice
  curve (Nucleares, but daily), hands jobs to people by their skills
  (RimWorld), fixes real parts with real tools when they want to (My Summer
  Car, lighter) and works the ledger in big seasonal beats (the "spreadsheet
  simulator" of Europa Universalis and Automation). Every one of these has a
  calm default, so ignoring the depth is always allowed (1.8).

## Contents

0. Existing systems the paths build on
1. Pillars and pace: cozy by default, chaos you earned (1.8: inspirations
   and the daily loop)
2. How paths work
3. The Player path: "The Skates"
4. The Coach path: "The Whistle"
5. The GM path: "The Binder"
6. The living league
7. The shared cast
8. Ownership, hooks and data shapes
9. Open questions for Sean

---

## 0. Existing systems the paths build on

Nothing here starts from zero. These are the hooks already in the code or in
the agreed docs, and what each path does with them.

| Existing piece | Where | Used by the paths for |
| --- | --- | --- |
| `Career.day`, the shared calendar | `scripts/career/career.gd`, `RINK_SIM.md` 1.1 | Every beat's trigger and window; all three paths and the rink share one clock |
| `Career.news` and `_news()` | `career.gd` | The news ticker and the papers (section 6). Already prints signings, tryouts, scoring titles |
| `compute_invitations()`, `scouting_score()`, `try_out()` | `career.gd` | Player path promotion; the GM path's scouting is the same maths seen from the other desk |
| `_check_release()` | `career.gd` | The gentle demotion ("Back Where He Belongs", `TEAMS.md`). The model for every soft setback |
| `LeagueTiers.TIERS`: `practices_per_week`, `days_between_games`, `tryout_cut`, `ai` | `league_tiers.gd` | Hours per path (practices are hours), the pacing of each act, how organised each tier plays |
| `TierAI` and the club `style` nudges | `tier_ai.gd`, `TEAMS.md` "Playing styles" | Coach path systems and tactics become one more nudge on top of tier and style |
| `Bench`: lines, pairs, shift clocks, energy | `scripts/game/bench.gd` | Coach path line deployment and in-game bench calls |
| `QuickSim.simulate()` | `quick_sim.gd` | Simming every other game in every tier so the league breathes; the "sim to next key moment" option |
| `Progression.practice_xp(p, quality)` and `training_focus` | `progression.gd`, `player_profile.gd` | Coach path practice plans (a drill is a focus plus a quality) and player development |
| `Progression.age_one_year()` (decline past 29, faster past 33) | `progression.gd` | The Player path's age arc; veterans retiring league-wide |
| `Injury` severities and games out | `injury.gd` | The Player path's injury arc; injury reports in the news |
| `MoveUnlocks` and the move catalog ids | `move_unlocks.gd`, `scripts/core/moves.gd` | Signature moves taught by story characters (the Millbrook bank) |
| `PlayerProfile.history`, `career_stats` | `player_profile.gd` | The records book, career retrospectives, the hall of fame |
| `Career.league_gate` and `RinkSim.owner_can_play()` | `career.gd`, `rink_sim.gd` | Dale's dues gate; the same hook gates a coach's bench or a GM's vote when the rink is in crisis (never as a punishment, as a reminder) |
| Owner hours budget (98 a week), fatigue, staff, standing orders | `RINK_SIM.md` 2.1, 2.2, 5.11 | Each path spends hours differently; standing orders are the auto-delegation tool |
| Time blocks and speeds (pause, 1x, 4x, 16x, to the next event) | `RINK_SIM.md` 1.1 | The pacing tools (1.4) |
| Difficulty settings: Community, Operator, Old Gus | `RINK_SIM.md` 1.5 | How hard chaos pushes (1.3) |
| `RinkContracts.ORGS`: `lumber_kings`, `minor_hockey`, `learn_to_skate`, `hockey_school` | `rink_sim.gd`, `RINK_SIM.md` 5.3 | Coach and GM storylines live inside contracts the rink already sells |
| Reputation dimensions (ice, facility, reliability, community, hockey, business) | `RINK_SIM.md` 5.4 | Each path feeds one or two of them more than the others |
| `teams.json`: clubs, styles, rivalries, promotion steps, papers, radio | `data/world/teams.json`, `TEAMS.md` | Every opponent, rival, headline and bus ride |
| `lore.json`: GNHL clubs, legends, sponsors | `data/world/lore.json`, `LORE.md` | The GNHL backdrop, cameos, awards, broadcast trivia |
| `DevMenu` | `scripts/dev/dev_menu.gd` | A Paths tab: set path, jump to act, fire a beat (8.3) |

One gap matters for two of the three paths: `Career` assumes the user is a
dressed skater (`user_id`, `lineup_for()` always dresses the user). The Coach
and GM paths need a career whose user is not on the ice. Section 8 asks Game
mechanics for a `role` on the career and a `next_managed_game()` beside
`next_user_game()`.

---

## 1. Pillars and pace: cozy by default, chaos you earned

### 1.1 The five pillars

| Pillar | What it means in practice | The test |
| --- | --- | --- |
| **Cozy by default** | A rink with its work covered is pleasant to be in. Doris hums, the radio plays CKVL, Bev says something rude and kind, the puck makes a nice sound. Most days have nothing urgent in them | A tester who keeps the grid filled and the standing orders set can play a whole week at 4x with no red on the corkboard |
| **Chaos you earned** | Trouble comes from three sources only: neglected maintenance, an unset schedule, customers treated poorly. Random bad luck exists (a heat wave, a power cut) but is rare, warned and small | Every crisis can be traced, in one sentence on its card, to something the player did or did not do |
| **Warnings first, never a spiral** | Problems announce themselves in fiction before they cost anything. One crisis at a time. A setback has a ceiling and a way back | No save can be lost by failure. The worst month costs about one month's profit and ten points of one reputation |
| **Hands first** | On the ice, the player's dexterity decides outcomes. Ratings change the shape of what the body can do, never whether a shot "succeeds" | A great pair of hands at rating 30 can lead Beer League D in scoring; a rating 70 skater with clumsy hands cannot carry Semi-Pro |
| **The valley goes on without you** | Other teams, players, coaches and towns have their own seasons and stories. The news is about them as much as you | In any week, at least half the news ticker is about someone else |
| **One plan a day, depth on request** | The rink's systems (the plant curve, the jobs, the staff grid, the ledger) each have a calm default: Gus's preset curve, "do the usual", starter work priorities, Priya's suggested bids. The player engages as deeply as they like, when they like (1.8) | A tester who never opens the curve planner, the priority grid or a mini game still has a rink that works, just less well and less cheaply |

### 1.2 What a calm day looks like

The cozy baseline is concrete. A calm Tuesday in November, Year 2, with
Dylan and Earl on staff and standing orders set:

| Time | What the player sees | What the player does |
| --- | --- | --- |
| 05:00 | Snow on the lot, the sodium light, Gus's binder on the desk. Earl's truck is already there | Plant rounds, if they feel like it (Marg's not hired yet). 4 minutes of reading dials with a coffee |
| 06:00 | Hélène's figure club on warm, smooth ice. She nods. That's a compliment | Nothing. Watch, or skip to the next event |
| 10:00 | A phone call: the Kessler Overdues want an extra Saturday slot | Say yes, say no, or let Priya handle it (once hired) |
| 12:00 | Public skate. Music. A dad falls over, laughs | Run the counter, or let Dylan |
| 15:00 | Free time | One of: a mini game (the edger's belt is squeaking), a path activity (practice plan, scouting tape, stick-and-puck ice for yourself), or a nap |
| 19:00 | The path's evening: a game, a practice, a board meeting | The main event of the day |
| 23:30 | Earl does the night flood. The radio plays the late scores | Read the Clarion, sleep |

On a day like this the only decisions are the ones the player wants to make.
That is the target for 70% of days once Year 1 is over.

### 1.3 Where chaos comes from

Three **pressure** values, 0 to 100, are derived each day from state the
rink sim already tracks. They are not new resources to manage; they are a
reading of the player's neglect.

| Pressure | Rises with | Falls with | Signals in fiction |
| --- | --- | --- | --- |
| **Maintenance** | Parts under their symptom threshold with no job queued (`SimPart.condition`), skipped rounds, overdue services (oil, blade, glycol test), gaps in the log book | Jobs done, rounds logged, services on time, a contractor visit | Doris coughs twice, the plant room smells sweet, Earl mutters, Gus's note falls off the door, frost on the header trench |
| **Schedule** | Red (unstaffed) cells on the ice grid in the next 7 days, sessions with no flood, double-booked dressing rooms, a team practice with no ice booked, a game night with no one on Doris | Grid filled for the week, staff rostered, standing orders set | Dale calls asking "is Tuesday still on?", a coach waits in the lobby with a pylon bag, the dressing room door has two teams' tape on it |
| **Customers** | Relationship meters falling (`RINK_SIM.md` 5.2), unanswered calls older than 2 days, bad sessions for a contract, a price rise without notice, a cancelled slot | Good sessions, returned calls, small favours, showing up | A pointed email, a parent at the counter, Hélène's frown, the Clarion's letters page |

The player's main path adds its own fourth flavour of pressure, but only
through the same three sources: a Player who is never at the rink raises
Schedule pressure, a Coach who books his own team into minor hockey's slot
raises Customer pressure, a GM who undercharges his own team for ice is a
Customer problem with every other tenant (5.6, "Two Hats").

### 1.4 How it escalates: the four rungs

Every pressure source climbs the same ladder. Each rung has a minimum dwell
time before the next one can fire.

| Rung | Pressure | Dwell before next rung | What happens | Cost |
| --- | --- | --- | --- | --- |
| 1. **Whisper** | 30 | 2 days | A sensory symptom and a line from a character. Gus's binder gains a sticky note on the right page | None |
| 2. **Warning** | 50 | 3 days | A red card on the office corkboard with the cause and three ways out. A phone call or a visit | None yet. The card says what it will cost if ignored |
| 3. **Trouble** | 70 | 5 days | One bad thing, sized and capped: a session on bad ice, a relationship hit of 5 to 10, a $300 to $1,500 bill, a late game start | Small and named in advance |
| 4. **Set piece** | 85, and nothing else active | Then a 7-day grace for that source | A short playable scene: the plant trips at 01:40, the parents' meeting, the Lumber Kings board calls you to the Legion. It ends with a choice and a recovery | Capped (below) |

The rules that keep it gentle:

1. **Warnings first, always.** No cost can land without a Whisper and a
   Warning before it. The Old Gus difficulty is the only exception, and it
   says so on the tin ("No warnings. Gus never had any.").
2. **One fire at a time.** Only one Set piece can be active. Others wait on
   the corkboard, frozen at Trouble, until it resolves. Two Point Hospital's
   cascading emergencies are exactly what we are not making.
3. **Every card has at least three outs:** do it yourself (hours), pay
   someone (money: staff or contractor), or call in a favour (relationship).
   A fourth, "let it ride", always exists and states its known cost.
4. **Caps.** A single Set piece costs at most the larger of $2,500 or one
   month of the rink's average net, and at most 10 points off one
   reputation dimension. A contract can walk, but only after a Warning that
   named it.
5. **Grace.** After a Set piece, that source cannot fire another for 7 days,
   and its pressure drops by 30 on resolution, whatever the choice.
6. **The valley rallies.** If two pressures sit above 70 for 14 days, or the
   rink's cash goes under $1,000, catch-up help arrives (1.6). This is
   automatic and unashamed.
7. **No save ends early.** The rink cannot be lost by failure. Hockey
   setbacks are soft too: a cut player goes back down a tier, a fired coach
   lands on a smaller bench, a GM's board can take the trades away for one
   season. Nothing ends the story except the player choosing to sell the
   rink (which the Community Ice Agreement makes a deliberate act).

Rule 7 changes one line of `RINK_SIM.md` 5.8: "running out of cash means the
line of credit, then missed payments, then the bank calls". Proposed: the
bank calls, and then the Frostbank manager, Wendell Moss (new), sits in the
office and restructures: the owner's draw is frozen, the line of credit is
capped, a repayment plan starts, and the town's transition fund covers the
electricity bill for two months. It is a bad week, not an ending.

### 1.5 Pacing tools

| Tool | What it does | Where it comes from |
| --- | --- | --- |
| **Time controls** | Pause, 1x, 4x, 16x, and "to the next event". The clock stops at block boundaries and for anything that needs the player | `RINK_SIM.md` 1.1 |
| **Skip to next event, with a preview** | Before skipping, a short list shows what will happen and who will do it: "06:00 figure club (Earl floods). 10:00 delivery (Dylan signs). 19:00 your game." Anything with no one assigned is in red, and the skip offers to assign it | New, UI and Game mechanics |
| **"Do the usual"** | Before staff exist, routine owner jobs (rounds, floods, dressing rooms) can auto-resolve at 85% of the owner's skill and their normal hours. The player plays them only when they want to | New, World (sim) |
| **Mastered mini games** | After three runs of a mini game at quality 0.8 or better, it can auto-resolve at the owner's best quality minus 0.05. The hands-on version stays available, like Car Mechanic Simulator's quick repair | New, World (sim) |
| **Standing orders** | "Flood after every session", "call me if the plant trips", "accept any casual rental over $150". The auto-delegation layer once staff exist | `RINK_SIM.md` 5.11 |
| **Match modes** | Play the whole game; play my shifts (Player) or key moments (Coach, GM); sim with a highlights reel. Period length is already a setting (2 to 20 minutes) | `GameSettings.PERIOD_CHOICES`, `QuickSim` |
| **Act skips** | Between acts, a "the season goes by" montage can sim weeks of routine at a chosen standing-order policy, stopping only for beats and Set pieces | New, Game mechanics |
| **No fail states** | 1.4 rule 7 | |
| **Catch-up help** | 1.6 | |
| **Comfort settings** | Game speed, aim assist strength, stick auto-centre, colour-blind palettes, `Tuning.blend` (Sim to Arcade). These change comfort, never the rules of the sim | `Tuning.blend` exists; the rest is Controls and UI |

### 1.6 Catch-up help: the valley rallies

When the player is behind, the town helps, in character. Each fires at most
once a season, in this order of preference:

| Help | Fires when | What it does |
| --- | --- | --- |
| **Gus phones from Florida** | Maintenance pressure 70+ for a week | Gus talks the owner through the worst job over the phone: that mini game's tolerances widen 30% for one run, and he names the next part that will fail. "Number 1 drinks. I told you that." |
| **Mallards volunteer night** | Schedule pressure 70+ for a week | Larry Piche and the Millbrook Mallards cover a week of floods, dressing rooms and the counter for free. Their quality is 0.7 and they leave the coffee pot on |
| **Earl comes in early** | Any two pressures 60+ and Earl is hired | Earl takes the 05:00 block for a week, unpaid. He will mention it for a year |
| **Bev's word** | Customer pressure 70+ for a week | Bev phones the offended party. Relationship +10 with one organisation. "I told her you're an idiot but you're our idiot." |
| **The transition fund** | Rink cash under $1,000 | The Community Ice Agreement pays $3,000 once, from the town's transition fund. The Clarion prints it kindly |
| **Ronnie's Thursday** | Player path: 6 games with no points, or a tryout cut | A one-on-one session on Thursday old-timers' ice. A practice drill where the player's hands improve, plus a double practice XP day. Never a stat gift |
| **Old Pete's drawer** | Coach or GM path: 5 straight losses | Old Pete Vachon opens the skate sharpener's drawer and shows the 1979 Cup photo, then tells the team a story. Team morale reset to neutral |

### 1.7 What we take from each inspiration, and what we leave

| Inspiration | What we take | What we deliberately don't |
| --- | --- | --- |
| **Slapshot Rebound** | The stick is a physical object on the right stick: the ~220 degree arc, lift, tilt, dash and stop, with the puck as a real body. Skill is in the hands: there is no "shoot" button that decides the outcome. Readable, fast, satisfying contact | Its pure competitive online focus and lack of progression. Its 3v3 arcade format as the end state (we go to 5-on-5 with lines). Its empty-arena presentation |
| **Puck** | Momentum skating and weight: turning hard costs speed, a check is two bodies colliding, not an animation. The mouse as a stick, so keyboard and mouse players get the same dexterity game. Emergent goals that nobody scripted | Its hardcore lack of onboarding. We teach with Gus's notes, Ronnie's drills and Comfort settings, so a new player can enjoy Beer League D while their hands catch up |
| **Tape to Tape** | An RPG layer that changes how you play, not just how big your numbers are: perks with personality (our Habits, 3.4), a cast with jokes, a map you travel, upgrades between games, and a warm cartoon tone | Roguelite resets and permadeath. Run-based structure. Upgrades so large they replace skill (all our gear and Habits together are capped, `PROSHOP.md` 8 points per key) |
| **NHL series** (Be a Pro, Franchise, GM modes) | The living league: standings, stat leaders, injury reports, trade rumours, awards nights, a draft, a deadline, records falling, broadcast presentation (Bernie Szabo on CKVL, Saturday Night Hockey), the career arc from call-up to veteran | Card packs and microtransactions. Ratings that decide outcomes over skill. Menus for the sake of menus (contract screens with twenty sliders). Scouting as a chore of clicking reports |
| **Nucleares** | Slowly, safely building up the plant ahead of the day's load and tapering it back down at night; anticipating fluctuations (a full house, a warm April day) instead of reacting to them | Its hourly, hands-on, second-by-second control and its catastrophic failures. Ours is one plan a day (1.8.1) |
| **My Summer Car** | Repairing real objects: carry the part, move it into place, take the tool off the pegboard, turn the bolt, start the machine and hear it run | Lost bolts, unlabelled wiring, hours of trial and error, a mistake you can't find. Ours snaps into ghost outlines and always shows mistakes at the test step (1.8.2) |
| **RimWorld** | Delegating by skill: a work-priorities grid of people against job types, jobs flowing to whoever is best and free, staff quirks that make stories | Mental breaks, needs bars, spirals where one bad event cascades. Our staff have moods, not breakdowns (1.8.3) |
| **Europa Universalis, Automation** | The "spreadsheet simulator": bids, rates, sponsors, advertising, community and seasonal events, a ledger that tells the truth and levers with visible results | Dozens of stacked hidden modifiers and decisions every day. Our spreadsheet comes in seasonal beats, with defaults filled in and a "why" on every number (1.8.4) |
| **Cozy sims** (Stardew Valley, PowerWash Simulator, Two Point Hospital) | Stardew: seasons and festivals, people with heart levels and small stories, no fail state, "tomorrow is another day". PowerWash: the clean before-and-after of a job done. Two Point: satire with a straight face, staff with quirks | Stardew's energy bar that ends the day by force (our fatigue is a cost, not a wall). Two Point's escalating crisis waves and timed objectives that fail you |

The one-line version for anyone new on the team: **Slapshot's hands, Tape to
Tape's heart, the NHL's world, Stardew's pace.** And for the rink: **a
Nucleares morning, My Summer Car hands, a RimWorld roster and a Europa
Universalis ledger, all of them set to gentle.**

### 1.8 Inspirations and the daily loop

Sean, 2026-10-18, on the rink side: Nucleares for "setting a proper flow and
anticipating temperature fluctuations... slowly, safely building up
reactivity and production before safely tapering it back down at night. If
Nucleares is an hourly workflow, I want a daily work flow." My Summer Car for
"actually repairing physical items by moving them into place and using tools
on them... not as in depth or hands on/difficult." RimWorld for "delegating
and scheduling tasks based on people's skill set and what needs to be done."
Europa Universalis and Automation for the "spreadsheet simulator" of
"securing contracts/sales, advertising, participating in community events,
coordinating seasonal and special events at the rink."

Each one maps onto a system `RINK_SIM.md` already designs, and each sits
under the relaxing-by-default pillar: a calm default that works if ignored,
depth for the player who wants it, and neglect that shows up only through the
three pressures in 1.3 (never as a new way to fail).

#### 1.8.1 Nucleares: the day curve

**What exists.** `RinkSim._step()` already runs a duty controller: it takes
the target surface temperature for whatever skates next
(`IceSlab.TARGET_TEMP`: hockey -5.5 C, figure -3.5 C, public -4.5 C), adds
1 C when the building idles overnight (the night setback), and sets the
plant's duty from the error (`duty = 0.5 + (surface - target) * 0.8`,
clamped 0 to 1). `RINK_SIM.md` 5.1 adds the physics that make planning
matter: about 1 to 2 hours to move 2 C with both compressors, night setback
saving about 8% of plant power, and a demand charge of $14 per kW on the
month's highest 15-minute peak, which punishes starting both compressors at
16:45 and rewards pre-cooling on cheap dead time at 15:00.

**What we add: one plan a day, made at 05:00.** The plant screen in the
office shows the **day curve**: the grid's bookings drawn as a stepped line
of target temperatures across the day, and the plant's predicted surface
temperature as a second line. The player shapes the plan with a few handles:

| Handle | What it does | Default |
| --- | --- | --- |
| Ramp points (up to 4 a day) | "Start pulling down at 15:00 for 17:00 minor hockey." The controller chases the ramp instead of the step | Gus's preset curve for that weekday |
| Ramp rate | How fast to move. Above about 1.5 C an hour, compressor wear rises (a stress multiplier on `SimPart` wear) | 1.0 C an hour ("slowly, safely") |
| Compressor staging | Number 1, number 2, or both, and in which order they start | Both, staggered 20 minutes (avoids the demand peak) |
| Night setback | When the taper starts after the last flood, and how warm to idle | After the night flood, +1 C (`rink_sim.gd` today) |
| Load forecast | Read-only: the day's expected extra heat | Always shown |

**Anticipating loads.** The forecast card lists what will push the ice warm,
so the player builds ahead of it instead of reacting:

| Load | Source in the sim | What a good plan does |
| --- | --- | --- |
| A full house | Attendance at a Senior game or a tournament (people, lights, the doors opening) | Pre-cool 0.5 C an hour before puck drop; the second compressor on before the crowd, not after |
| A warm spring day | The weather model (`RINK_SIM.md` 1.5): outdoor temperature and humidity load the condenser and fog the building in April and May | Start the ramp earlier, run the dehumidifier, accept a slightly softer target for public skate |
| Back-to-back floods | Each flood lays down warm water (`IceSlab.resurface`) that must freeze before the next session (`RESURFACE_LEAD_MIN` 30) | Leave freeze time in the grid; don't flood heavy before a figure session |
| A use change | Figure at 06:00, hockey at 17:00 | Put the warm use right after the night setback, when it costs nothing (`RINK_SIM.md` 5.1) |
| A heat wave or a power cut | Rare weather events, always forecast two days ahead | A deep pre-cool the night before; a rented chiller (`rent_chiller()`) if it's bad |

**The rhythm.** Build up slowly in the early block, hold through the day,
peak for prime time, taper after the night flood, log it. The satisfaction is
the Nucleares one: watching the actual line settle on the planned one, and
the bill coming in lower than last month.

**What we keep lighter.** No valves to turn second by second, no
minute-by-minute babysitting: once the plan is set, the controller follows it
and the player only glances at it. Mistakes are small and visible: ice 1 C off
target dips that session's rating a few points (a Customers pressure input),
an overshoot is a line on the power bill, a demand peak is a line on the
monthly P&L. Nothing melts down. The default (Gus's preset curve, applied
automatically on Community difficulty) gives okay ice at a slightly higher
bill, so a player who never opens the screen is fine. Later the digital
controller ($28,000, `RINK_SIM.md` 5.8) proposes the curve itself and the
player just approves it, which is the late-game reward for having learned it.

#### 1.8.2 My Summer Car: hands on parts

**What exists.** The mini games in `RINK_SIM.md` section 4 already share one
set of verbs (grab and remove, use tool on target, measure, adjust, torque,
clean, pour, inspect), the look, diagnose, order, strip, replace, test
structure, and hidden mistake flags (`gasket_reused`, `bolt_undertorqued`
and so on). The reference job is Doris's spark plugs in the first hour
(`RINK_SIM.md` 1.6).

**What we take.** Parts are physical objects. The new blade arrives in a
Zambelli box at the front desk; you carry it to the bay, take the socket
wrench off the pegboard, back off the six blade bolts, lift the old blade out
(it's heavy and the camera feels it), move the new one into place, start each
bolt by hand, torque them in order, set the height with the gauge, and drive
Doris onto the ice to see the result. The good feeling is cause and effect
you did with your hands.

**What we keep lighter.**

| My Summer Car | RinkGM |
| --- | --- |
| Bolts roll away and get lost | A magnetic parts tray: everything you remove goes in it and stays there |
| You find the right spot by trial and error | Ghost outlines show where a part goes when you pick it up; a wrong part refuses to seat with a clear clunk |
| Dozens of fasteners and wiring | At most about 12 fasteners per job; no wiring diagrams |
| Mistakes hide until something breaks | Mistakes are flagged, but the test step always shows a symptom you can catch (a reading off, a noise, a drip): warnings first |
| No help | Gus's clipboard lists the steps; Gus's phone call (1.6) widens tolerances when you're stuck |
| You must do it every time | After three good runs it can be auto-resolved (1.5, mastered mini games), or handed to staff |

#### 1.8.3 RimWorld: the work-priorities grid

**What exists.** Staff with a skill per job type, reliability and morale
(`RINK_SIM.md` 2.2), the roster, job queue, training, reviews and standing
orders (5.11), contractors for what staff can't do, and personalities (Earl
argues with any change to Doris, Dylan is fast and sloppy and gets good, Marg
writes in red pen, Bev won't work Sundays).

**What we add: the priorities grid.** One screen: people as rows, job types
as columns, each cell a priority from 1 (do this first) to 4 (only if nothing
else), or blank (never). Skill shows as pips in each cell. Cells a person
can't do are greyed with their reason (Earl in the Plant column: "I'll drive a
Flatley when they bury me in one"; Dylan in Plant until he's 18 and trained).

The columns: Floods, Edging, Plant rounds, Plant jobs, Doris jobs,
Building, Counter, Cleaning, Bookings, Events.

Jobs from the queue go to the free person with the highest priority for that
column, ties broken by skill. The **owner is a row too**, so the player
decides what they personally keep (many keep Plant jobs because the mini
games are fun). The path's hockey hours are fixed blocks in the owner's row:
on a Player path road trip the row is greyed for the evening, which is
exactly when the grid shows whether the rink runs without you.

**What we keep lighter.** No needs bars, no mental breaks, no cascades.
Morale nudges reliability by a few percent and shows in a line of dialogue.
A new hire arrives with sensible starter priorities, so the grid is optional
until the player wants to tune it. Staff never quit without two Warnings
first (a Schedule pressure input), and an unhappy person tells you why.

#### 1.8.4 Europa Universalis and Automation: the spreadsheet simulator

**What exists.** The ice grid (5.1), contracts and bidding with RFPs,
hidden budgets and scoring weights (5.2), organisations with personalities
(5.3), reputation (5.4), sponsors and vendor deals (5.5), pricing against
the regional rate sheet (5.6), events and tournaments with lead times and a
run-of-show (5.7), the monthly P&L, loans, grants and projects (5.8).

**What we add.**

| Lever | What it is | Where it plugs in |
| --- | --- | --- |
| **Advertising** (new) | Small paid pushes: a Clarion ad ($60 a week), a CKVL 1340 spot read by Bernie Szabo ($150 a week), posters at Grizzly Gas and Maple Tire ($25), flyers home with the school ($40). Each lifts demand for one programme or event (public skate heads, learn-to-skate sign-ups, tournament teams, Senior attendance) for a few weeks, with diminishing returns | Programme revenue (5.1), event revenue (5.7), the Hockey and Community reputations |
| **Community events** | Free fundraiser hours, the Snowflake Showcase, the Mallards' Cup photo night, a food bank skate, the Haverstock Old-timers'. They cost ice and hours and pay in Community reputation and relationships | `RINK_SIM.md` 5.4 Community, 5.7 events |
| **The year planner** | One screen for the season at a glance: ice-in, the allocation season in March and April, the monthly Peewee tournaments, the Haverstock Old-timers' in January, the bonspiel in March, summer dry floor, inspections, the trade show. Every event shows its lead-time tasks counting down | 5.7 planning table, 1.4 the year |
| **Forecasts with a "why"** | Every number the player sets shows the expected result and the reason: "At $205/h minor hockey scores you 71 against Harlow Falls' 74. Price is 40% of their score." Automation's market demographics, applied to organisations' weights | 5.2 scoring |

**What we keep lighter.** The spreadsheet arrives in **beats**, not every
day: the allocation season, a tournament's planning weeks, a sponsor's
renewal, the monthly P&L. Each decision is one screen with at most about six
numbers, and defaults are filled in (by Gus's notes in Year 1, by Priya the
booking coordinator once hired, who suggests a rate for every bid). Modifiers
don't stack dozens deep: every effect on a number is listed under it.

#### 1.8.5 The daily loop, all together

| Block | Rink work (and its touchstone) | Hockey path work |
| --- | --- | --- |
| Early (05:00 to 07:00) | Plant rounds and the **day curve** (Nucleares): check the forecast, approve or tweak the plan. 2 to 5 minutes of play | |
| Day (07:00 to 17:00) | The **priorities grid** routes the jobs (RimWorld); the owner picks one **hands-on job** if they feel like it (My Summer Car); phone calls and the counter | Stick-and-puck ice, practice plans, scouting calls |
| Evening (17:00 to 01:00) | The curve peaks for prime time; floods; the event run-of-show on tournament weekends | The path's main event: a game, a practice, a board meeting |
| Night (01:00 to 05:00) | The taper (night setback). The office: the **ledger** in its beats (EU and Automation): bids in allocation season, the month's P&L, a sponsor call | Line cards, the binder, the news |

| Cadence | What the player sets | Calm default if they don't |
| --- | --- | --- |
| Daily | The day curve | Gus's preset curve |
| Weekly | The ice grid, the roster and priorities, the stock order | Last week's grid repeats; starter priorities; Bev orders |
| Monthly | Pricing, advertising, sponsor follow-ups | Prices hold; no ads |
| Seasonal | Bids, events, projects, the year planner | Priya's suggested bids (once hired); Gus's notes before that |

The relaxing-by-default pillar stays on top of all four: each touchstone's
default keeps the rink working, its depth saves money and earns reputation,
and neglecting it feeds only the three pressures in 1.3 (bad sessions are
Customers, missing hands are Schedule, unserviced parts are Maintenance),
with every warning and cap that comes with them.

---

## 2. How paths work

### 2.1 The owner always owns the rink

The rink sim in `RINK_SIM.md` runs for every player on every path. The path
is the owner's hockey ambition: what they do in the evening block, what they
care about on the bus, which people's stories they are inside.

| Path | Fantasy | Where the owner spends hockey hours | What success looks like |
| --- | --- | --- | --- |
| **Player** ("The Skates") | The late bloomer from the late ice, like Ronnie Haverstock before you | On the ice and on the road | The red phone rings for you |
| **Coach** ("The Whistle") | The person who made a town's kids, and then its senior team, better | Behind the bench and at practice, mostly at your own rink | The Aldous Cup lifted at the Barn, and a kid you taught to stop playing in front of scouts |
| **GM** ("The Binder") | The builder: the roster, the deals, the franchise, the room full of people with opinions | At the desk, on the phone, in the stands with a notebook | A professional team playing in Millbrook, in your renovated rink |

### 2.2 Choosing: try all three, then commit

**Recommendation: one main path chosen in Year 1, after a soft intro where
the owner tries all three. The other two remain as side roles at a smaller
scale.**

The soft intro runs from the first day (Monday, first week of September,
Year 1) to the Legion Christmas party (20 December, Year 1, about day 105).

| Week | Taster | Path | What it shows |
| --- | --- | --- | --- |
| 1 (Tuesday 22:00) | The first Flood Crew game on your own ice, which you flooded at 21:40 and flood again at intermission in full gear (`RINK_SIM.md` 1.6, minute 60) | Player | Hands first: one game, one stick, the dead board behind the net |
| 2 (Saturday 11:00) | Kids' learn-to-skate. Nobody signed up to teach it. Eleven kids, one is holding a chair. That's Maddie Pruitt | Coach | Teaching is a real-time game; you skate the drill to show it |
| 3 (Monday) | Dale Huffman drops off "the binder". The Flood Crew has nine skaters and no goalie for Tuesday | GM | A roster is a puzzle made of people. You find a goalie at public skate |
| 4 to 14 | All three continue at taster scale: one BL-D game a week, Saturday learn-to-skate, the binder's small asks | All | Each has a little arc that resolves by mid December |
| 15 (mid Dec) | Three finales: the Flood Crew's game against the Molars; the Snowflake Showcase where the learn-to-skate kids skate for their parents; the Lumber Kings' board meeting on their January probation deadline (`RINK_SIM.md` 5.3) | All | The player has felt each one's best moment |
| Dec 20 | **The Legion Christmas party.** Ronnie, Donna Pettigrew and Ray Duchesne each ask, separately, over terrible punch | Choice | The choice |

At the party, the choice is a conversation, not a menu: you take a drink to
one of three tables. Each person makes their pitch in two lines:

- **Ronnie Haverstock** (Player): "I was twenty-two and driving milk. You've
  got hands. Thursday nights, my ice. Let's see how far up the road you go."
- **Donna Pettigrew** (Coach): "The U13s need a coach by January and the
  last one moved to Harlow Falls with half our ice. You were good with the
  little ones. Don't make me ask twice. I'll ask twice."
- **Ray Duchesne** (GM): "The Kings need somebody who can read a budget and
  a defenceman. Old Pete says you're both. Old Pete has never said that
  about anybody."

"I'll think about it" is allowed. All three tasters continue until ice-out
in June, when Earl says "Pick one. You look like a man carrying three
pucks."

### 2.3 Why one main path, with side roles

| Option | For | Against |
| --- | --- | --- |
| Fully free, all three at full scale | Maximum freedom | The hours budget (98 a week) cannot hold three careers and a rink. The story becomes three half-stories. It feels like a chore, which is the one thing Sean asked us to avoid |
| One path forever, chosen at the start | Cleanest | The player chooses blind, before they know what they like. Locks out the late-game "retire and coach" arc that real hockey people live |
| **One main path chosen after a taster, side roles for the others, switch at an offseason** (recommended) | The player chooses informed. A clear story with a clear cast. The side roles keep variety and the valley stays connected. The hours budget works | One more system (side roles) to build |

**Side roles** are each path at a fixed small scale. They are always
available, cost few hours, and never reach the main path's set pieces.

| Side role | What it includes | Its ceiling |
| --- | --- | --- |
| Player | Your Beer League team, Thursday old-timers' shinny, stick-and-puck ice | Beer League A. No tryout invites above it |
| Coach | Saturday learn-to-skate and one minor hockey team as an assistant | The Valley Peewee Tournament as an assistant |
| GM | The Flood Crew's roster and Dale's binder; a seat (one vote) on the Lumber Kings board | Voting on the lease; no trades, no signings |

**Switching.** Once per offseason, at the ice-out barbecue in June, the
player can change their main path. The new path starts at its Act 2 if its
side role was active for at least a season, otherwise at Act 1 with a
short catch-up montage. The old path becomes a side role, and its characters
keep their state. Late in a Player career (age 33+, or after the GNHL call),
retiring into the Coach or GM path is a designed epilogue, not a switch: the
beat "The Last Lace" (3.6) offers it.

### 2.4 What each path changes

**In the daily loop.**

| | Player | Coach | GM |
| --- | --- | --- | --- |
| The evening block | Games and practices (yours) | Practices you run and games you coach | Board meetings, scouting trips, games from the stands |
| The day block | Stick-and-puck ice, the gym (a renovated room), Bev for edges | Practice plans, video, phone calls with parents and players | The phone, the desk, contract talks, the jobs board |
| The night block | Sleep (fatigue matters most here: owner fatigue feeds `Progression.rest`) | Line cards and tomorrow's drills | The binder, trade calls, the news |
| Travel | Most: road games along the valley, then beyond on the Gas Can Express | Some: road games, home practices | Flexible: scouting trips on the region map |
| Where dexterity lives | Every shift | Drill demos, bench timing, the whiteboard (4.3) | Your Beer League side role and stick-and-puck; your eye for a player in the stands (5.3) |

**In the rink sim.** Hockey hours per week, from the owner's 98 (the rest of
the budget is the rink):

| Act | Player | Coach | GM |
| --- | --- | --- | --- |
| 1 | 4 (BL-D game, Thursday shinny) | 4 (learn-to-skate, the Flood Crew bench) | 3 (the binder) |
| 2 | 6 to 8 (BL-C, BL-A: a practice, Harlow Falls trips) | 9 (U13: two practices, a game, the parents) | 8 (Kings board, the lease, recruiting) |
| 3 | 14 (Senior AAA: two practices, games every 5 days, the bus) | 14 (Kings assistant) | 12 (Kings GM: scouting, the jobs board) |
| 4 | 24 (Semi-Pro: three practices, games every 4 days) | 20 (Kings head coach) | 18 (the ILHL expansion bid) |
| 5 | 34 (Minor League Pro: four practices, games every 3 days) | 26 (Sturgeon or Kings in the ILHL) | 22 (first ILHL season) |
| 6 | Away most weeks (GNHL stint) | | |

**Staff needs** follow from where the owner is:

| Path | First hire pressure | Why |
| --- | --- | --- |
| Player | A plant operator (Marg) by Senior AAA, an assistant manager by Semi-Pro | The owner is on a bus to Port Ainsley when number 1 trips. `RINK_SIM.md` 2.3 already assumes this shape |
| Coach | A Zambelli driver (Earl) early, a booking coordinator (Priya) by Act 3 | The owner is at the rink but on the bench, not on Doris, at exactly the hours floods happen. And their teams' ice is the rink's prime ice |
| GM | A booking coordinator early, the assistant manager late | The owner's day is all phone and desk already. The rink and the team compete for the same calls |

**In progression.** Each path has its own progression on top of the owner's
rink skills (`RINK_SIM.md` 2.3):

| Path | Progresses | Through |
| --- | --- | --- |
| Player | `Skills` ratings, moves, Habits, tier, fame | Games, practice, beats (section 3) |
| Coach | Coach skills (Teaching, Tactics, Bench, Rapport), a playbook of systems, coach reputation, bench level | Practices run, games coached, players developed (section 4) |
| GM | GM reputation, a scouting network (accuracy like `RINK_SIM.md` 5.9 instruments), budget, franchise value, board trust | Deals, drafts, results, attendance (section 5) |

Every path also feeds the rink's reputation, one dimension more than the
others: Player feeds **Hockey** (fame), Coach feeds **Community** (minor
hockey, learn-to-skate) and Hockey, GM feeds **Business** and Hockey.

### 2.5 How long each path runs

Roughly one act per season, with acts 1 and 2 shorter. A path's main story
ends around Year 6 or 7, matching the rink sim's Prestige stage (Year 5 on).
After the last act the path keeps going as a sandbox with the living league
and recurring yearly beats (awards, the Valley Cup, Larry's March letter).

---

## 3. The Player path: "The Skates"

### 3.1 The premise

You are the new owner of a tired rink and a Beer League D winger (or
centre, or defence) with good hands and no reputation. Ronnie Haverstock
went from the milk truck to the GNHL. Nobody has done it since. Everyone in
the valley quietly thinks about it.

### 3.2 Dexterity first: how skill works

The rule is **hands decide, stats shape**.

| What the player's hands do | What ratings do (through `PhysicsProfile`) | What ratings never do |
| --- | --- | --- |
| Aim every shot with the stick's position and the follow-through | Set shot speed, release time, how much the puck wobbles off a bad release (`shot_power`, `shot_release`, `shot_accuracy`) | Decide whether a shot "hits". There is no hit roll; the goalie is a physical body with its own AI |
| Place passes on the tape with stick angle and weight | Set pass speed and how forgiving the receiver's trap is (`pass_quality`) | Auto-complete a pass |
| Perform dekes and moves by gesture (`MoveUnlocks` gates which gestures register) | Set blade speed across the arc and how well the puck stays on (`stick_handling`) | Perform a move the hands didn't trace |
| Skate: edges, crossovers, stops, the dash | Top speed (15 to 25 mph, `ARCHITECTURE.md`), acceleration, turn grip (`speed`, `agility`) | Steer for you |
| Time a hit, a stick lift, a poke | Hit power, balance, injury risk (`hitting`, `toughness`) | Win a board battle you lost with your body position |

Balancing targets for Physics (to agree, 8.4):

- A human with good hands at a rating average of 30 should be able to lead
  Beer League D (AI average 28, `LeagueTiers`) in scoring. That is the fun of
  Act 1: your hands are ahead of your body.
- The same human at rating 30 in Senior AAA (AI average 56) should be able
  to score occasionally but be outmuscled and outskated. Stats matter more
  the higher you go, because the AI is organised (`TierAI`) and fast.
- From the GM's side, a human's production counts more than their rating:
  propose `scouting_score()` weights production 1.5x for the user, so great
  hands earn the invite even when the ratings lag.

**Practising your hands is a real thing in the game.** Stick-and-puck ice
at 06:00 or in dead time (the rink's own programme, `RINK_SIM.md` 5.1) has
short drills: pylons, the shooting gallery, the Millbrook bank. They give
practice XP (`Progression.practice_xp`) and, more importantly, they are where
the player gets better with their own thumbs. Ronnie's Thursday lessons are
the same drills with a mentor.

### 3.3 The RPG layer: ratings, moves, Habits, gear

Four layers, each capped so the hands stay in charge:

| Layer | What it is | Cap | Built on |
| --- | --- | --- | --- |
| Ratings | The nine skater keys, 1 to 100 | Potential per key (80 to 96 for the user) and age | `Skills`, `Progression` |
| Moves | Shots and dekes you can perform | The tree in `MoveUnlocks` plus story moves | `MoveUnlocks`, Controls' catalog |
| **Habits** (new) | Perks with personality, earned by beats and play patterns | 3 equipped ("written on the tape"), each worth at most +3 to a key or a situational effect | New, Game mechanics |
| Gear | Bev's shop | 8 points per key across all gear | `PROSHOP.md` |

**Habits** are the Tape to Tape part: small, situational, funny, and
earned by doing, never bought. Examples:

| Habit | Earned by | Effect |
| --- | --- | --- |
| Late Ice Legs | Play 10 games starting after 21:00 | Stamina recovers 15% faster in games after 21:00 |
| The Millbrook Bank | Ronnie's Act 2 lesson (beat `p2_ronnie_bank`) | Unlocks the `millbrook_bank` chip pass: a soft chip off the end boards that dies at a dead board or an edge lip (`IceSurface.dead_board`, `edge_lip_mm`) |
| Barn Ears | Win a game at the Kessler Barn | The crowd's noise no longer shakes your aim reticle on the road |
| Gas Money Sleeper | 10 road trips on the Gas Can Express | Travel fatigue halved |
| Bev's Edge | Get your skates done before 20 straight games | +2 `agility` while edges are fresh |
| Haverkamp's Lecture | Wear a mouthguard for a whole season (the Molars notice) | One step down on any face injury |
| Suitcase | Be traded, released or called up three times | No morale loss on a team change; +2 `pass_quality` for 5 games with new linemates |
| The Wrong Twin | Score in a game you were listed as day-to-day | Injury modifiers on `speed` halved for one game a season |

### 3.4 Characters

| Character | Who | Arc on this path |
| --- | --- | --- |
| **Ronnie "The Milkman" Haverstock** | Millbrook's own GNHL legend, 1979 to 1996; plays the Thursday old-timers' game (`LORE.md`) | **Mentor.** Starts as a polite legend who calls you "the new owner". Becomes the man who teaches you the Millbrook bank, then the one who hands you the Dukes' phone number (`TEAMS.md` promotion table). His own wound: he went late and always wondered what he'd have been at 19. He wants you to go, and he is afraid you'll go and not come back |
| **Kenny Szabo** (new) | 24, a big-hearted grinder winger, son of CKVL's Bernie Szabo (`TEAMS.md`), nephew of broomball's Kev Szabo. Not quite good enough, knows it | **Linemate and friend.** Carpools with you to Harlow Falls in your car with the heater you hit. Makes Beer League A with you. Is cut at Senior AAA camp the year you make it (Act 3). Signs with the Lumber Kings anyway as a depth player and becomes their captain, so he plays at your rink while you're away. In Act 5 he is the one driving Doris the night you get the call |
| **Tyler Brandt** | Cold Ones captain, BL-C, half a season of Junior B in 2017 (`TEAMS.md`) | **Rival.** Sure he is one call from Senior, and gets it first: he makes the Kessler Millmen a year ahead of you. Struggles there, gets released down to BL-A, and you meet him again as an opponent who has stopped talking about 2017. In Act 4 he is your Semi-Pro linemate for a season, humbler and genuinely useful. The arc lands in a handshake line |
| **Earl Bratt** | Head icemaker since 1983, Flood Crew defenceman (`TEAMS.md`, `RINK_SIM.md`) | **Your first D partner.** Sulking at the Legion in September, so the Flood Crew is short a defenceman. When Earl comes back to drive Doris (Month 2), he comes back to the Flood Crew too, and plays the dead board better than anyone but Ronnie |
| **Hap Doyle** | Kessler Millmen head coach since 1988, 71, smiled once in 1996 (`TEAMS.md`) | **The coach who doubts you.** "Beer Leaguer Invited to Millmen Camp; Doyle: 'We'll see.'" If you sign in Kessler, he benches you for the first three games and plays you on the fourth line. If you sign with the Lumber Kings instead, he says "We'll see" to the Courier every time you play Kessler. Either way his arc ends with the second smile in recorded history |
| **Dmitri Volkov** | Port Ainsley Sturgeon head coach, murmurs (`TEAMS.md`) | **The coach who believes in structure, and then in you.** Teaches you to play without the puck. Gives you the Valley Cup's last minute |
| **Coach Annette Rourke** (new) | Duncannon Dukes head coach, ex-CHA defencewoman, chews ice from a cup | The pro bench: fair, cold, fast. "I don't need you to be good. I need you to be the same every night." The Metronome speech, in valley form |
| **Lorne Pettigrew** | Dukes GM, keeper of the red rotary phone (`TEAMS.md`) | The gatekeeper. Brother of Donna Pettigrew (proposed, 7.2) |
| **Derek "Anvil" Morrow** | Ellery Smelters defenceman, leads the ILHL in hits, runs a knitting circle (`TEAMS.md`) | **The injury.** The hit that puts you out is his, clean and hard. Two weeks later a scarf arrives in Sturgeon colours with a card: "Nothing personal. Wash on cold." |
| **Barry "Suitcase" Pomeroy** | The most beloved journeyman in hockey (`LORE.md`) | **The age arc.** Visits the Haverstock Old-timers' Invitational the year you turn 30 |
| **Bev** | Bev's Edge & Tape (`PROSHOP.md`) | The voice of truth about your edges and your ego. Her line on every promotion is already written (`PROSHOP.md` "Bev's lines") |

### 3.5 The story in acts

| Act | Name | Tier and year (best case) | The question it asks |
| --- | --- | --- | --- |
| 1 | Late Ice | BL-D, Year 1 | Can you play hockey and run a rink at the same time? |
| 2 | The Carpool | BL-C and BL-A, Years 2 to 3 | Are you actually good, or just good at late ice? |
| 3 | The Barn | Senior AAA, Year 3 or 4 | Kessler or home? |
| 4 | Gas Money | Semi-Pro, Years 4 to 5 | What does it cost to keep going? |
| 5 | The Red Phone | Minor League Pro, Years 5 to 6 | The rink or the call? |
| 6 | The Show | GNHL stint, Year 6 or 7 | What do you bring home? |

**Act 1: Late Ice (Beer League D, Year 1).** You join the Flood Crew, the
rink staff's own team (`TEAMS.md`), because you are now the rink staff. The
sponsor line "Millbrook Parks & Recreation" is out of date; the first beat
is buying the jerseys yourself ($240, and Bev sews the new crest). The Flood
Crew is short a defenceman because Earl is sulking at the Legion. Your games
are on your own ice, so you flood before, at the second intermission in
full gear, and after. The rival this year is small and funny: Gary Pruett of
the Wobbly Pops, who learned to stop last February and stops in front of
you on purpose. Earl comes back in Month 2 (`RINK_SIM.md` 2.2) and with him
the dead board. The act ends at the Last Call Cup playoffs: win or lose, the
Night Owls' captain Shauna Reid sees you at late ice and asks if you are
free Thursdays (the BL-C invite, `TEAMS.md`).

**Act 2: The Carpool (Beer League C and A, Years 2 to 3).** Kenny Szabo
needs a ride to Harlow Falls, and your car's heater works if you hit the
dash. The carpool is a recurring scene on the region map: a two-minute drive
with Kenny talking, CKVL on the radio, his dad calling a Lumber Kings game.
In C, Tyler Brandt and the Cold Ones are the loud rivals. Ronnie's Thursday
lessons start (beat `p2_ronnie_bank`): he teaches the Millbrook bank on the
dead board, then tells you to find the dead spots in other rinks too. In A
Division, Dale Fraser of the Rusty Blades, five straight titles, treats every
game like the Olympics and is the first real wall. Tyler makes the Millmen
before you. The act ends with the letter on Kessler letterhead, or a second
season in A if you didn't earn it (the world is kind about it).

**Act 3: The Barn (Senior AAA, Year 3 or 4).** The act opens with a choice
the rink sim has been building towards: two invitations, one from the
Kessler Millmen (eleven Aldous Cups, Hap Doyle, the loudest building in the
north) and one from your own Millbrook Lumber Kings (last Cup 1979, your
tenants, on probation if your ice is bad). Kenny tries out for the Millmen
with you and is cut. If you sign in Kessler, you ride the rented yellow
school bus, play fourth line for Hap, and play the Lumber Kings in your own
building as the visitor, which the Clarion prints with a photo of you
flooding at intermission anyway. If you sign with the Kings, your games fill
your own stands, the beer garden opens (`RINK_SIM.md` 6.1), and Hap says
"We'll see." The act ends with the Aldous Cup final, very likely Kessler
against Millbrook, and whichever side you chose, Kenny is on the other.

**Act 4: Gas Money (Semi-Pro, Years 4 to 5).** The man in the ILHL
windbreaker drives four hours to see one shift. The Port Ainsley Sturgeon
sign you; $150 a game and an $11 per diem (`PROSHOP.md`). The Gas Can
Express takes you beyond the valley: Carrick Junction's train horn, Ellery's
Pit, the Wexford dog section. You are away from the rink two or three nights
a week, so the rink's staff and standing orders are now the story's
co-stars: the weekly report on the bus is how you hear about Doris. Tyler
Brandt is your linemate for a season. The injury beat lands here if it
hasn't already: Anvil Morrow's hit, a Moderate or Major injury, and a rehab
spent running the rink full time. That rehab is a quiet, good stretch of
the game: you find out whether your rink runs without you, and you get to
mind it properly for once. The scarf arrives. The act ends at the Valley
Cup: the Sturgeon against the Duncannon Dukes, the preseason exhibition the
Dukes treat as practice and the Sturgeon treat as a Cup final.

**Act 5: The Red Phone (Minor League Pro, Years 5 to 6).** After the
Thursday old-timers' game Ronnie hands you a phone number on the back of a
Grizzly Gas receipt. The Duncannon Dukes sign you: a charter coach with
wifi that never works, a roommate, Coach Rourke. Games every three days.
The act's spine is the call-up meter (8.2): points, plus-minus and
consistency push it, injuries pause it. Then the morning: 06:40, Lorne
Pettigrew's red phone rings for Kingsport. It rings on the same day as
something your rink cannot easily do without you (the TV event weekend, the
Lumber Kings' home playoff game, or the GNHL rookie camp at Millbrook, from
`RINK_SIM.md` 5.3). This is the moment Sean asked for: **the rink or the
call-up**.

- **Go.** Kenny drives Doris that night, Earl runs the plant room with Marg,
  the Mallards work the counter. The rink sim plays the weekend on standing
  orders while you are on a plane, and you get the weekly report in a hotel
  in Kingsport. If the rink is well staffed it goes fine and the Clarion
  calls it "the night the town ran the rink". If it isn't, the valley
  rallies (1.6) and it is merely rough.
- **Stay.** Lorne says "It'll ring again. Probably." It does, later that
  season, if your form holds (the meter drops 30%, it does not reset).
  Staying is not punished, only delayed. The town never forgets that you
  stayed, and Community reputation rises 10.

**Act 6: The Show (GNHL, Year 6 or 7).** Your first plane with a team logo
on the tail. The Kingsport Monarchs: Mrs Eunice Tolland on the organ, a
dressing room that smells of money, Theo Lindgren-Baptiste across the ice
eating the same breakfast. The GNHL stint is a short playable window (a
recommendation, open question 3): about 10 games, ending with a choice to
stay up (sandbox seasons in the GNHL, rink on full staff) or come home. The
last beat is the same either way: the summer day with something to bring
home. If you won a Cup, the Puckworth Cup comes to Millbrook (it has been
before, in 1994 and 2005, `LORE.md`). If you didn't, you bring your first
GNHL puck, and Ronnie hangs it beside his milk uniform photo.

### 3.6 Set pieces

| Id | Moment | Act | What makes it special |
| --- | --- | --- | --- |
| `p1_flood_in_gear` | Second intermission, your own game: you drive Doris in full gear, helmet on | 1 | The whole game in one image; a running gag until staff take over |
| `p1_jerseys` | Bev sews the Flood Crew's new crest | 1 | You are the sponsor now |
| `p1_earl_returns` | Earl walks into the Flood Crew dressing room with his old stick and says nothing | 1 | Tied to the rink sim's Month 2 hire |
| `p2_ronnie_bank` | Thursday old-timers' ice, 22:30. Ronnie shows you the dead board | 2 | Teaches the `millbrook_bank` move and Habit |
| `p2_carpool` | The drive to Harlow Falls with Kenny, CKVL on, heater thumped | 2 | A recurring two-minute scene on the region map |
| `p3_two_letters` | Two envelopes on the office desk: Kessler letterhead and a Lumber Kings note in Old Pete's pencil | 3 | The Senior choice |
| `p3_kenny_cut` | The Millmen camp's cut list, pinned in the Barn's hallway | 3 | Your name is on it. His isn't |
| `p3_visitor_at_home` | (Kessler) You play at Millbrook in the visitors' room you renovated | 3 | Your own crowd boos you a little, lovingly |
| `p3_aldous_final` | Game 3 at the Barn, Bernie Szabo on CKVL saying "Kessler" three ways | 3 | Kenny on the other side |
| `p4_anvil_scarf` | The parcel at the rink front desk | 4 | The injury arc's warmest beat |
| `p4_rehab_month` | A month at your own rink, full time, unhurt by the clock | 4 | Cozy as a reward, not a punishment |
| `p4_valley_cup` | Sturgeon vs Dukes, the last minute, Volkov taps your shoulder | 4 | The first time you play the Dukes |
| `p5_receipt` | Ronnie's phone number on a Grizzly Gas receipt | 5 | The promotion table's best line, played |
| `p5_red_phone` | 06:40. The rotary phone rings in Lorne's office and Lorne points at you | 5 | The rink or the call |
| `p6_tail_logo` | The plane | 6 | |
| `p6_bring_it_home` | The summer day: the Cup on the dairy counter, or your puck beside Ronnie's photo | 6 | The ending |
| `p_age_suitcase` | Suitcase Pomeroy at the old-timers' bar the year you turn 30: "Keep a bag by the door. Not because you'll leave. Because you'll want to know you could." | Any | The age arc |
| `p_last_lace` | Age 33+ or after the GNHL: the offer to retire into the Coach or GM path | Any | The epilogue switch |

### 3.7 The age and injury arcs, as systems

Both arcs come from existing code, not scripts.

- **Age.** `Progression.age_one_year()` already declines physical skills past
  29 and faster past 33. The path adds beats on top: `p_age_suitcase` at 30,
  a Courier column calling you "veteran" at 31, and `p_last_lace` at 33.
  Recommended starting age: 21 (open question 1), so a fast climb reaches the
  GNHL at about 27 with peak years still ahead, and a slow climb meets the
  age arc honestly.
- **Injury.** The first Moderate or Major injury from Senior AAA up fires the
  injury beat set (the rehab month, the get-well card from whoever hit you).
  If no serious injury happens by the end of Act 4, the scarf still arrives
  after a big Anvil hit you shook off: "Nothing personal. Glad you got up."
  Injuries are never scripted into the player's body; only the story around
  them is.

---

## 4. The Coach path: "The Whistle"

### 4.1 The premise

The kids' learn-to-skate needed somebody. Then the U13s did. Then the
Lumber Kings' coach walked out at the second intermission and Ray Duchesne
handed you the clipboard. You did not mean to become a coach; nobody in a
town like Millbrook ever does.

### 4.2 Mechanics

The Coach path is a management game with real-time moments, played mostly
at your own rink.

**Practice plans.** A practice is a block on the ice grid (your own
contract's ice, so the rink sim knows about it). The plan is a 60-minute
strip of drills, dragged in like cards.

| Drill | Minutes | Trains (focus for `Progression.practice_xp`) | Needs |
| --- | --- | --- | --- |
| Edges and crossovers | 10 | `speed`, `agility` | Clean ice (ice rating matters, see below) |
| Tape to tape | 10 | `pass_quality` | |
| Shooting gallery | 10 | `shot_accuracy`, `shot_release` | Pucks (a bucket, `PROSHOP.md`) |
| One-timer line | 10 | `shot_power`, `shot_release` | The `one_timer` move for the shooter |
| Battle drill (corners) | 8 | `hitting`, `toughness` | Raises injury chance slightly |
| Breakout reps | 12 | Team: the breakout system's familiarity | A system installed |
| Forecheck reps | 12 | Team: the forecheck system's familiarity | A system installed |
| Power play and penalty kill units | 15 | Team: special teams familiarity | Lines set |
| Goalie shots | 10 | Goalie keys | A goalie coach or you |
| Fun game (sharks and minnows, 3-on-3 shinny) | 10 | Morale, a little of everything | Kids love it. So do Senior players, secretly |

Practice `quality` (the input `practice_xp` already takes) comes from:

| Factor | Effect |
| --- | --- |
| The ice | The session's true ice rating (`IceSlab.rating("hockey")`) scales quality 0.7 to 1.1. **A coach who neglects the rink coaches worse.** This is the Coach path's link to cozy-versus-chaos |
| Your demo | Each new drill, you can skate it yourself first (a 20 to 40 second dexterity challenge: weave the pylons, hit the pass). A clean demo adds up to +0.15 quality for that drill. Skippable, at +0 |
| Plan shape | Too many drills of one type: diminishing returns. A fun game at the end: +morale |
| Coach skill | Teaching (below) |

**Systems and tactics.** A small playbook. Each system is a nudge on the
team's `TierAI` (the same mechanism as club `style` in `TEAMS.md`), scaled by
the team's familiarity with it (0 to 1, from practice reps and games).

| Category | Options | Example nudge at full familiarity |
| --- | --- | --- |
| Forecheck | 1-2-2 (safe), 2-1-2 (aggressive), 1-3-1 trap | 2-1-2: aggression +0.08, dash_use +0.06, discipline -0.04 |
| Breakout | Up the wall, reverse, stretch pass | Stretch: vision +0.06, decide_max -0.04, more icings |
| D-zone | Zone, man-on-man, box-plus-one on the PK | Zone: discipline +0.08, anticipation +0.04 |
| Power play | Umbrella, 1-3-1, overload | 1-3-1: vision +0.08 on the PP unit |
| Identity | One word on the dressing room whiteboard: "Skate", "Grind", "Patience", "Chaos" | A small morale bonus when results match the word |

Rule (to match `TEAMS.md`): a coach's nudge is never bigger than the gap
between two tiers. A brilliant coach makes a Senior team look Semi-Pro on its
best night; it doesn't make a beer league team look Senior.

**Line deployment.** Built on `Bench`: three forward lines and two pairs,
plus PP and PK units, plus matchups ("line 3 against their top line at
home"). The coach sets lines between games; in the game, line changes use
`Bench`'s shift clocks with the coach's overrides.

**Player development.** Each player has a `training_focus`
(`PlayerProfile`). The coach assigns it, holds one-on-one talks (Rapport),
and decides ice time. Development is visible: a weekly line on the coach's
corkboard, "Little Sauce: backhand up 2 this month."

**In-game bench management. Decision:** the Coach path is **bench-first**,
with a **playing-coach** option in the beer leagues.

| Tier | The coach | What the player controls |
| --- | --- | --- |
| Beer leagues (BL-D bench in Act 1, any BL as a side role) | Playing coach, like Dale Fraser of the Rusty Blades | Your own skater, live (the full dexterity game), plus quick bench calls from a radial menu at stoppages: change lines, timeout, pull the goalie |
| Minor hockey, Senior AAA, Semi-Pro | Behind the bench | The bench view: watch the game at 1x, 2x or 4x, call changes on the fly, set matchups, call a timeout and draw a play |

Where dexterity lives for a bench coach:

| Moment | The skill |
| --- | --- |
| **Changes on the fly** | Timing. Call the change when the puck crosses the far blue line and the change is clean; call it late and you get caught with tired legs or too many men. A rhythm skill, read off the ice, not a menu |
| **The whiteboard** | In a timeout (30 seconds of real time), you draw the play with the stick or mouse: a route, a screen, a pass. The AI runs it on the next faceoff in the same way it runs everything, through `Skater.Controls`. A clean, simple drawing works best; a scribble confuses the fourth line |
| **Drill demos** | 4.2 above |
| **Your own skates** | The coach can still play Thursday shinny and stick-and-puck as a side role |

The match modes for a coach: full game on the bench; **key moments**
(QuickSim runs the game and stops for decisions: a penalty, a late lead,
the third period of a one-goal game, a timeout chance); or sim with
highlights.

**Coach skills** (0 to 1, rising with use, like the owner's rink skills):

| Skill | Rises with | Effect |
| --- | --- | --- |
| Teaching | Practices run, drills demoed | Practice quality, how fast familiarity grows |
| Tactics | Systems installed and used in games | Size of the system nudges, unlocks new playbook options |
| Bench | Games coached, good changes | Fewer bad changes when you let the bench run itself; better key-moment reads |
| Rapport | One-on-ones, keeping promises about ice time | Morale, how players respond to role changes, the parents |

### 4.3 Characters

| Character | Who | Arc on this path |
| --- | --- | --- |
| **Maddie Pruitt** (new) | 9 in Year 1, Dylan Pruitt's little sister, great-granddaughter of Dorothy Pruitt who founded Honest Hockey (`LORE.md`). Holds a chair at learn-to-skate. Will not let go of the chair | **The struggling kid who becomes a star.** Week 2 she can't stand. By Christmas she lets go of the chair at the Snowflake Showcase. In Year 2 she is the slowest skater on the U11s and the only one who listens. In Year 3 she scores the winner at the Valley Peewee Tournament on Millbrook ice. Her last beat (Year 6) is a letter from a Wendover College program, and she asks you to write her reference. You write it in Gus's binder first, then type it |
| **"Little Sauce" Saucier** (new) | 12, Rick "Sauce" Saucier's son (Moose Knuckles, 61 goals in 1994, `TEAMS.md`). Talented, tired of hearing about 1994 | **The kid with a loud parent.** He is better than Maddie and has more pressure. His arc is about whether he still likes hockey. The answer depends on Rapport, ice time and how you handle his dad |
| **Rick "Sauce" Saucier** | Moose Knuckles right wing, hockey dad, gassed by the second period | **The parents.** Yells from the glass. Wants Little Sauce on the power play and the first line and in the paper. His arc: in a parents' meeting he realises he is doing to his son what 1994 did to him. Or doesn't, and transfers the boy to Harlow Falls (a soft loss, never a disaster) |
| **Donna Pettigrew** | Millbrook Minor Hockey president (`RINK_SIM.md` 5.3) | **The boss and the conscience.** She runs minor hockey like an army with a bake sale. She is also your rink's most important customer, so every coaching decision has a rink side |
| **Colin Nolan** | Frozen Assets coach, laminated line-change spreadsheet, late fees for missed shifts (`TEAMS.md`) | **The first rival coach.** A beer league bench battle where the spreadsheet is the enemy. He becomes a friend and lends you the spreadsheet template. It's very good |
| **Ray Duchesne** | Lumber Kings board chair (`RINK_SIM.md` 5.3) | Hires you, defends you, needs you to win before the January probation deadline |
| **Stan Kubiak** (new) | The Lumber Kings' head coach at the start, 58, tired, a decent man out of ideas | Walks out at the second intermission of a 6-1 loss to Tollbridge in Year 2 and hands you his whistle. Comes back in Act 4 as a scout who wants to help |
| **Ilya Petrov** | Belle Rive Riptide right wing, former GNHL first-round pick on his third comeback, "absurdly talented on the nights he is interested" (`TEAMS.md`) | **The former pro with a past.** Released by Belle Rive, he signs with the Lumber Kings for his fourth comeback, in Senior AAA, to everyone's astonishment. He is the best player in the league and the hardest to coach. His arc is about why he stopped caring (a GNHL coach told him at 20 that he was "a highlight, not a hockey player"). It resolves when he chooses to backcheck in the Aldous Cup final |
| **Donnie Delorme** | The better twin from the Wrong Twin scandal, now runs a bakery (`LORE.md`) | **Your assistant coach, reluctantly.** Better at hockey than anyone in the valley ever was and has no interest in being seen. Runs the power play from the end of the bench in a flour-dusted jacket. He will never go behind a bench at a level with TV cameras, and you learn not to ask |
| **Hap Doyle** | Kessler Millmen head coach | **The rival coach.** Eleven Aldous Cups in his building, a system older than you. He respects you exactly once, in the handshake line after the Act 4 final, whichever way it went |
| **Father Marc Gagnon** | Sainte-Odile Castors coach, parish priest, bench minors "in Latin" (`TEAMS.md`) | The friendly rival: the most skilled team in Senior, singing on the bench. The opponent you learn tactics from |
| **Dmitri Volkov** | Port Ainsley Sturgeon head coach | **The successor offer.** In Act 5 he wants to retire to his ice hut and recommends you to Marlene Fisk |
| **Hélène Arsenault** | Figure club coach (`RINK_SIM.md`) | The other coach in the building. She teaches your kids edges in a guest session and is better at it than you. Professional respect, warmly given, eventually |

### 4.4 The story in acts

| Act | Name | Year | The question |
| --- | --- | --- | --- |
| 1 | The Chair | Year 1 | Can you teach? |
| 2 | The Sawdust | Years 1 to 2 | Can you handle the parents? |
| 3 | The Clipboard | Year 2 | Can you take over a senior team mid-season? |
| 4 | The Aldous Cup | Years 3 to 4 | Can you win with a star who doesn't care and an assistant who won't be seen? |
| 5 | The Gas Can | Years 5 to 6 | Do you leave your own bench for a bigger one? |

**Act 1: The Chair (Year 1).** Saturday 11:00 learn-to-skate and the Flood
Crew bench (as playing coach). Eleven kids, one chair, Maddie. The act is
small on purpose: two short sessions a week where the coach skates drills,
and the satisfaction is watching kids go from falling to gliding. Colin
Nolan's spreadsheet beats you twice. The act ends at the Snowflake Showcase
in December, when Maddie lets go of the chair, and Donna Pettigrew, watching
from the stands with a coffee, asks you to take the U13s.

**Act 2: The Sawdust (Years 1 to 2).** The Millbrook U13 C team, nicknamed
the Sawdust (new; they are the bottom of the Lumber Kings' pyramid). The
last coach left with half of minor hockey's ice for Harlow Falls
(`RINK_SIM.md` 0), so winning back that ice and winning games are the same
story. Practice plans arrive, and the ice rating on your grid now changes how
good your practices are. Sauce yells from the glass. Little Sauce is the best
player and the unhappiest. The parents' meeting in the lobby is the act's set
piece. The act ends at the minor hockey year-end banquet, where Ray Duchesne
introduces himself.

**Act 3: The Clipboard (Year 2).** You join the Lumber Kings as an assistant
in October. The Kings are on probation as tenants (`RINK_SIM.md` 5.3: ice
reputation 60 by January or they announce a move to Harlow Falls), so the
rink and the bench are one problem: good ice and a winning team keep them.
In November, at the second intermission of a 6-1 loss to the Tollbridge Coal
Kings, Stan Kubiak hands you his whistle and walks out to his truck. You are
the head coach for the third period. The Kings are a `dump_and_chase` club
(`TEAMS.md`) with old legs; you install a system over the winter and find out
whether you can. Donnie Delorme comes to a game to sell crullers and stays to
fix the power play. The act ends at the January deadline: if the ice and the
team held, Ray announces a new lease in the lobby. If not, they announce a
move to Harlow Falls "next season", and the act's last beat is the chance to
change their mind by spring (always reachable).

**Act 4: The Aldous Cup (Years 3 to 4).** Ilya Petrov, released by Belle
Rive, phones the rink to ask if the ice is any good. The Kings sign him. He
scores a highlight goal a night and loses you two games a week. Hap Doyle's
Millmen are the wall. The act is about a team becoming a team: Petrov's
past, Donnie's refusal to be seen, the old guys' legs, the kids from the
Sawdust now old enough to skate in practice with the Kings (Maddie skates the
pylons at Kings practice and Petrov notices). The act ends in the Aldous Cup
final. Win it and the 1922 cup comes to Millbrook for the first time since
1979; Old Pete takes the photo out of the drawer and frames it. Lose it and
Hap Doyle smiles at you in the handshake line, which is somehow worse and
better.

**Act 5: The Gas Can (Years 5 to 6).** Two offers: Dmitri Volkov wants to
retire to his ice hut and recommends you to Marlene Fisk as the Port Ainsley
Sturgeon's head coach (Semi-Pro, ILHL); or the Lumber Kings follow the GM
path's expansion story into the ILHL and you stay with them (if the GM side
role pushed it, or if Sean wants the paths to cross, open question 6). Either
way you coach a Semi-Pro team: 16 games, owners with opinions, the Gas Can
Express, mascots. The Valley Cup against the Dukes is the act's big game.
The path's epilogue: Bruce Walsh of the Halverton Northmen, who coached 11
GNHL games in 2014 and would like to go back, calls about a CHA assistant
job. You can take it (a sandbox future) or stay home. Either way, Maddie
asks for that reference.

### 4.5 Set pieces

| Id | Moment | Act |
| --- | --- | --- |
| `c1_the_chair` | Maddie and the chair, first session | 1 |
| `c1_snowflake` | The Snowflake Showcase: parents with phones, Maddie lets go | 1 |
| `c2_parents_meeting` | The lobby, 19:30, folding chairs. Sauce stands up. A dialogue scene where Rapport and what you say decide whether Little Sauce stays | 2 |
| `c2_six_am` | The U13s get the 06:00 slot after the figure club, on ice warmed for Hélène. Do you change the setpoint (plant time and money) or coach on soft ice? | 2 |
| `c3_whistle` | Stan Kubiak's whistle on the bench at the second intermission | 3 |
| `c3_january` | Ray in the lobby with a lease, or a moving announcement | 3 |
| `c4_petrov_call` | Ilya Petrov on the office phone: "Is the ice any good?" | 4 |
| `c4_whiteboard` | Game 7, Aldous Cup final, a timeout with 1:12 left. You draw the play | 4 |
| `c4_old_petes_frame` | The 1979 photo comes out of the drawer | 4 |
| `c5_ice_hut` | Volkov's ice hut on Port Ainsley lake. He pours coffee from a thermos and offers you his job | 5 |
| `c5_valley_cup` | Sturgeon vs Dukes from the bench | 5 |
| `c_reference` | Maddie's reference letter | Year 6 |

---

## 5. The GM path: "The Binder"

### 5.1 The premise

Dale Huffman's binder runs the Valley Beer League. Ray Duchesne's binder
runs the Lumber Kings. You are the kind of person people hand binders to.
The GM path starts with the Flood Crew's roster and ends, if it goes well,
with a professional team playing in Millbrook, in a rink you renovated for
it.

### 5.2 Franchise choice

**Recommendation: the Lumber Kings, taken up the ladder.** The GM path
builds the Millbrook Lumber Kings from a volunteer Senior AAA club into the
**tenth club of the Interlake Hockey League** (Semi-Pro). `TEAMS.md` already
notes the ILHL has nine clubs and "a tenth club would need a new name
later": this path is that tenth club. It uses the existing team, its
history (last Aldous Cup 1979, Old Pete, the plaid), its lease with your rink
(`RINK_SIM.md` 5.3) and the "rise with the rink" hook `TEAMS.md` gives them.
A brand-new franchise is the alternative (open question 6).

### 5.3 Mechanics

**The jobs board (Senior AAA).** Senior hockey is amateur. You can't pay
players much (Senior pays $40 a game, `PROSHOP.md`), so you recruit by
finding them jobs in the valley. The jobs board is a corkboard in the Kings'
office with real employers: Big Gord's lot ("he'll want you at the bobblehead
night"), Maple Tire, Kessler Pulp & Paper, Harlow Falls Hydro (the Linemen
play there, awkward), Duffy Bros. Plumbing, your own rink (a job at the rink
is a conflict of interest, 5.6). Each employer has slots, hours and a
temperament. A player's decision weighs the job, the team's chances, the
town and his girlfriend in Port Ainsley.

**Scouting.** The scouting network works like the rink's instruments
(`RINK_SIM.md` 5.9): a player's true ratings are hidden and every source
reads them with an error band.

| Source | Error (rating points) | Cost | Unlocked |
| --- | --- | --- | --- |
| Your own eye, from the stands | +/- 12, and +/- 6 if you watch three games | Hours and travel | Start |
| Your own skates (shinny, stick-and-puck with him) | +/- 5 on puck skills, can't read hitting | An hour on the ice, dexterity | Start. The GM's dexterity moment: play with a prospect and feel his passes |
| Old Pete's notebook | +/- 8, local players only, and he knows character | Free | Start |
| A part-time scout (Stan Kubiak, after the Coach path's Act 3, or a new hire) | +/- 6, one region | $150 a week | GM reputation Fair |
| Video service | +/- 5, any player whose games are filmed (Senior and up) | $60 a month | Act 3 |
| Combine data (ILHL) | +/- 3 on skating and shot, nothing on hockey sense | The combine fee | Act 4 |

Scouting a player is watching him, not clicking a report: on a scouting trip
the GM sits in the stands of a real simmed-then-shown game (a highlights
reel of that player's shifts), and notes go into the binder. The estimate
narrows as you watch more.

**Trades.** Senior AAA trades are favours between towns; Semi-Pro trades are
deals. Each rival GM has a personality (5.4) that sets what they value and how
they negotiate. Rules kept simple: players, picks, cash (Semi-Pro), and
"future considerations" (which in Galloway means a car).

**Contracts and the budget.**

| Tier | Contract | The cap |
| --- | --- | --- |
| Senior AAA | A per-game fee ($40 standard, up to $100 for stars), a job, gas money | The club's budget (board-approved), about $28,000 a season: ice rent, bus, gear, fees, the banquet |
| Semi-Pro | One or two seasons, per-game pay ($150 standard, $400 for stars), per diem $11 | The ILHL's salary cap of $95,000 a team per season (new number), plus a floor of $60,000 |

The money is real and connects to the rink: ticket sales, the beer garden,
sponsors and the 50/50 draw go to the team; ice rent goes to the rink. The
GM sees both P&Ls side by side, which is where the conflict of interest
lives.

**Drafting juniors.** Two pipelines:

| Pipeline | When | Who |
| --- | --- | --- |
| **NSHA territorial list** (Senior AAA) | Every spring | Each club may protect 6 local players aged 18 to 21 from its town's minor hockey and high school (Millbrook High Mallards, Coach Bernie Ostrowski). The Sawdust kids from the Coach path grow into this list |
| **ILHL draft** (Semi-Pro) | June, at the Union Yard Arena in Carrick Junction (where the league was founded, 1979) | Three rounds from the Northern Junior Hockey League (new: a junior league beyond the valley, used only as a draft pool) and released college players. Order by reverse standings; the expansion club picks first in its first year |

**Board trust.** The Lumber Kings' volunteer board (Ray Duchesne, Old Pete,
three others) has a trust meter. It rises with wins, attendance, a balanced
budget and keeping promises; it falls with losing streaks, overspending and
the Clarion's letters page. Low trust brings Warnings and then the Set piece
"The Legion meeting". The worst case: Ray takes trades and signings back for
one season and you stay on as GM with a co-signer. You can never be fired
from a franchise you own (and by Act 4, you do).

### 5.4 The living GMs: rivals with personalities

| GM or owner | Club | Tier | Personality | How they trade |
| --- | --- | --- | --- | --- |
| **Brendan Quinn** | Harlow Falls Huskies | Senior AAA | A tie behind the bench, a laminated five-year plan, smug (`TEAMS.md`) | Only trades for players who fit year 3 of the plan. Will tell you which year you're in |
| **Hap Doyle** (coach and de facto GM) | Kessler Millmen | Senior AAA | Doesn't trade. Has never traded | Once a decade, for a goalie. This is that decade |
| **Father Marc Gagnon** | Sainte-Odile Castors | Senior AAA | Gentle, skilled, unexpectedly ruthless | Trades only French-speaking players to clubs where they'll be happy, and checks |
| **The Tollbridge Rail & Coal board** | Tollbridge Coal Kings | Senior AAA | Old men in a boardroom over the station | Wants toughness. Trades skill for a good enforcer every time |
| **Marlene Fisk** | Port Ainsley Sturgeon | Semi-Pro | Outboard motor dealer, careful with money, the valley's other owner (`TEAMS.md`) | Fair, slow, values defence. Your natural ally and your direct competitor for the valley's crowd |
| **"Honest" Abe Larsen** | Galloway Outlaws | Semi-Pro | Used-car dealer on the video board every period; has traded players for cars twice (`TEAMS.md`) | Offers a car in every deal. One of the cars is always better than the player |
| **Kibble King Pet Foods** (marketing VP Trish Bello, new) | Wexford Ice Dogs | Semi-Pro | Pays a bonus per shot on goal | Overvalues shooters, undervalues defencemen. The easiest mark in the league, and the most cheerful |
| **The Railway Heritage Society** | Carrick Junction Rail Barons | Semi-Pro | The league's founders; minutes are taken | Trades only at meetings, which are monthly |
| **Lorne Pettigrew** | Duncannon Dukes | Minor League Pro | Keeper of the red phone | Not a trade partner. An affiliation partner (Act 5) |

### 5.5 The story in acts

| Act | Name | Year | The question |
| --- | --- | --- | --- |
| 1 | The Binder | Year 1 | Can you build a roster out of the people who walk in the door? |
| 2 | The Board | Year 2 | Can you run a club you also rent ice to? |
| 3 | The Jobs Board | Years 2 to 3 | Can you build a winner in a league with no money? |
| 4 | The Tenth Club | Years 4 to 5 | Can Millbrook be a pro town? |
| 5 | The Red Phone, the Other End | Years 5 to 6 | What do you owe the valley? |

**Act 1: The Binder (Year 1).** Dale drops off the Valley Beer League binder
and asks you, as the rink, to keep the Flood Crew alive. Nine skaters, no
goalie, Tuesday. Recruiting is local and charming: the public skate dad who
played goal at Wendover College, the high school shop teacher, Gino Russo Jr.'s
cousin. The rink's customers are your talent pool, which is the first taste
of how the rink and the team feed each other. In November Dale asks you to
take over the D Division schedule as convenor. The act ends at the Lumber
Kings' board meeting on probation, where you say one sensible thing about
the budget and Ray writes your name on a napkin.

**Act 2: The Board (Year 2).** You join the Kings' board, and by spring
you're its GM, because Ray is tired and Old Pete says so. The first decision
is the lease: the Kings rent 6 hours a week of your prime ice. You are both
sides of the table (5.6). The act's other thread is minor hockey: Donna
Pettigrew's first refusal on prime ice (`RINK_SIM.md` 0) means the Kings'
Saturday 19:00 game slot is hers if she wants it, and she knows you want it.
The act ends with a negotiated peace (the Kings get Saturdays in exchange for
a Kings player coaching the Sawdust) or a public spat in the Clarion that
costs both of you.

**Act 3: The Jobs Board (Years 2 to 3).** Building a Senior winner with the
jobs board, Old Pete's notebook and the territorial list. Brendan Quinn of
Harlow Falls is the rival GM: tidier, richer, smug, and annoyingly good. You
make your first trade with him and he shows you which year of his plan it
was. The big signing is a goalie, because in Senior a goalie is a team
(Petr Novak of Carver's Gap is 39 and the best in the league; can you lure
him down the pass?). The act ends at the Aldous Cup playoffs and, either
way, Marlene Fisk asks you to lunch.

**Act 4: The Tenth Club (Years 4 to 5).** Marlene tells you the ILHL is
thinking about a tenth club so nobody has a bye week, and that Port Ainsley
would rather it was Millbrook than somewhere that might steal her crowd
(she is wrong about that and knows it). The expansion bid is a checklist
that runs through the rink sim, which is exactly why it is satisfying:

| ILHL requirement | Rink sim link |
| --- | --- |
| 1,200 usable seats | Stands renovated (`RINK_SIM.md` 5.8: stands_bench and stands_box) |
| Home dressing room RENOVATED, a visitors' room REPAIRED | `locker_home`, `locker_away` |
| 1,000 lux lighting | The LED lighting project |
| A video board or both scoreboard sides | `scoreboard` |
| Ice reputation 75 for the last season | The whole rink game |
| A $150,000 franchise fee | A Frostbank term loan, sponsors, a fan share drive (like the Marchmont co-op, `TEAMS.md`) |
| A name, colours and a mascot | A town vote (below) |

The **name vote** is a set piece: the Clarion runs a ballot. Options:
keep the Millbrook Lumber Kings (the plaid, the 1979 photo), the Millbrook
Mallards (the 2005 letter; Larry Piche writes in), or the Millbrook Dorises
(write-in, Earl organised it, it wins the popular vote and the board
overrules it, and Earl never forgives anyone). The mascot is chosen too:
Timber, a beaver in a plaid jacket, or Doris herself in foam, if the vote
went Earl's way. The act ends with the first ILHL home opener at Millbrook:
Sturgie the sturgeon visits, Bernie Szabo calls it, the stands are full,
and the Kessler Overdues' librarians are in section 4 shushing people.

**Act 5: The Red Phone, the Other End (Years 5 to 6).** Lorne Pettigrew
calls you, on an ordinary phone, to propose a loan agreement: Dukes prospects
on loan to Millbrook for development, your best player available to the Dukes
when injuries hit. It is good for your club's quality and bad for your
team's stability, and the question of the act is what a small club owes the
big one, and what it owes its own town. The last set piece is your best
player getting the call to Duncannon, the way you once dreamed someone from
Millbrook would. You drive him to the Frostbank Centre yourself. If the
Player path's side role is active, that player can be you (and the GM path
ends with you driving yourself, which the Clarion finds very funny).

### 5.6 Conflicts of interest: "Two Hats"

The owner is the landlord, the sponsor, the employer and the GM. Each
decision where one hat helps the other at someone else's expense moves a
**Two Hats** meter (league integrity and the town's trust, 0 to 100,
starting 70).

| Decision | Helps | Costs | Two Hats |
| --- | --- | --- | --- |
| Kings' ice rent below $180/h (the regional rate band, `RINK_SIM.md` 5.6) | The team's budget | The rink's P&L, and every other tenant notices | -5 per $10 under, a Warning from the NSHA commissioner (Dot Ferland, new) under $160 |
| Kings' ice rent above $230/h | The rink | The team's budget and the board's trust | -3 per $10 over, Ray complains |
| A player's job at your own rink | Easy recruiting | Looks like a salary under the table | -4 each beyond two |
| The Kings in minor hockey's Saturday prime slot | Gate revenue | Minor hockey's first refusal (the Community Ice Agreement) | -10 and Donna's relationship -15, unless she agrees |
| The same sponsor for the rink's boards and the jerseys | A bigger deal | Fine, actually | 0. It's what everyone does |
| Kings practice ice in dead time at the dead-time rate | Cheap ice for the team | Fine | +2. That's what dead time is for |

Low Two Hats (under 40) brings the Clarion column, then an NSHA (or ILHL)
review: a Set piece at the Legion where you explain yourself. Nothing worse
than a fine and a forced rate change ever happens. It is a cozy game; the
point is that the player feels the hats, not that they are punished for
wearing them.

### 5.7 Characters

| Character | Who | Arc on this path |
| --- | --- | --- |
| **Dale Huffman** | Valley Beer League commissioner, the binder (`RINK_SIM.md`) | Hands you the binder and slowly, gratefully, retires into the stands. His last beat is a VBL "Commissioner Emeritus" mug, which he uses for coffee at every game |
| **Ray Duchesne** | Lumber Kings board chair | The mentor GM: a volunteer who kept the club alive for twenty years on bake sales. His arc is learning to let go of the club, to you |
| **Old Pete Vachon** | Equipment manager since 1971, keeps the 1979 photo in the sharpener drawer (`TEAMS.md`) | The club's memory and your best scout for character. His notebook is the first scouting instrument. His last beat is the expansion opener: he sharpens the skates of the first pro team in Millbrook's history and says "same as 1971" |
| **Brendan Quinn** | Huskies GM | The rival GM, from smug to respectful. In Act 4 he votes against the expansion at the NSHA, then sends you a laminated card on opening night: "Year 1." |
| **Marlene Fisk** | Sturgeon owner | Ally and competitor. Her arc is the valley's two pro clubs learning to share a crowd (the Valley Cup becomes a three-way weekend if Sean likes it) |
| **Honest Abe Larsen** | Galloway Outlaws owner | The comic rival. Every trade call includes a car. In Act 5 he offers you a convertible for your best defenceman in January |
| **Petr Novak** | Carver's Gap Ravens goalie, 39 (`TEAMS.md`) | The goalie you try to lure down the pass. If you get him, his last season is a gift; if not, he beats you in the playoffs and sends a Gap Pass ski ticket |
| **Larry Piche** | Mallards captain, writes to the Cup trustees every March (`TEAMS.md`) | Writes in for the Mallards in the name vote; the town's sentiment in one man |
| **Lorne Pettigrew** | Dukes GM | The other end of the red phone |
| **Dot Ferland** (new) | NSHA commissioner, a retired school principal from Sainte-Odile with a whistle she never uses | The integrity check. Fair, dry, impossible to charm |

---

## 6. The living league

### 6.1 What makes it breathe

The valley has six leagues and the GNHL above them, and they all play every
week whether you watch or not.

| System | Cadence | What it shows | Built on |
| --- | --- | --- | --- |
| **Every tier simmed** | Every round | All six valley leagues play their full seasons with standings, playoffs and champions, not just the user's tier | `Season`, `QuickSim`, `_ensure_league` (proposed: sim every tier, 8.1) |
| **The GNHL backdrop** | Weekly | A light table sim of the 11 GNHL clubs: standings, a weekly scores digest, stat leaders (Theo Lindgren-Baptiste near the top, always), the Cup final | New, small; teams from `lore.json` |
| **News ticker** | Daily | 3 to 6 lines a day across the valley, at most half about you | `Career.news` |
| **The papers** | Weekly | Each town's paper prints its own headlines in its own voice: the Clarion's bake sale beside the BL-D scores, the Herald's A Division box, the Courier never neutral about Kessler, the Lakesider's ice thickness report, the Ledger's real sports section | `TEAMS.md` "The papers" |
| **Merv Tolliver's column** (new name) | Weekly, Duncannon Daily Ledger | "The columnist who hates everything" (`TEAMS.md`). Hates you specifically once a season, which is how you know you've arrived | |
| **CKVL 1340 Valley Radio** | Game nights | Bernie Szabo's play-by-play on the car radio and the rink's PA; late scores at 23:30 | `TEAMS.md` |
| **Saturday Night Hockey** | Saturday nights | GNHL broadcast on the lobby TV; *Moose on the Loose* intermission trivia (`LORE.md` 6) | |
| **Trade rumours** | Weekly in season, daily at the deadline | "Sources: Galloway shopping a defenceman (and a 2019 Buick)." Some true, some not; the GM path's scouting can confirm | New |
| **Injury reports** | After each round | Valley and GNHL injuries with games out | `Injury` |
| **Rivalry games** | When they fall | The six `TEAMS.md` rivalries get a crowd boost, a pre-game paper line and a post-game anecdote (the pike and the paper towel) | `teams.json` `rivalries` |
| **Awards night** | Each June | The Valley Hockey Banquet at the Kessler Legion: every tier's awards (6.3) | New |
| **Records book** | Always | "The Valley Book", kept in pencil by Old Pete: single season and career records for every valley league, set by anyone | `PlayerProfile.history`, `career_stats` |
| **Retirements and legends** | Each offseason | AI veterans retire (`_offseason_team` already retires at 40 or washes out); named characters retire with a news story and a farewell | `career.gd` |
| **Hall of Honour** | Each summer | The GNHL inducts a legend; the trivia lines become a ceremony on Saturday Night Hockey | `LORE.md` |

### 6.2 Storylines that progress without you

Each named character with an arc has a small state machine that advances each
season on its own conditions. You can be part of their story or watch it in
the paper.

| Storyline | What happens on its own |
| --- | --- |
| **Larry Piche's March letter** | Every March, the Clarion prints that Larry has written to the Puckworth Cup trustees again. In Year 5, a reply arrives (a beat for any path, `w_trustees_reply`): a polite card and an invitation for the Mallards to carry the Cup onto the ice at the Kingsport home opener. The whole valley watches on Saturday Night Hockey |
| **Tyler Brandt** | Makes Senior, gets released, rebuilds. If you aren't on the Player path, he goes further than anyone expected and becomes the valley's own Semi-Pro story, and the papers ask "the next Haverstock?" |
| **The Rusty Blades' streak** | Five straight A Division titles at the start. The streak ends in Year 2 or 3 to whoever beats them; if no one does, it reaches eight and Dale Fraser retires at the peak |
| **Big Gord's last power play** | Big Gord, 71, insists on every power play. In Year 3 he announces his retirement at the Billboard War game. The bobblehead night in Duncannon becomes a tribute |
| **Wally Dumont, 58** | The Maple Tire Retreads goalie. Each season a chance he retires; when he does, the Retreads collapse in the standings and the paper prints his 1989 Senior photo |
| **Hap Doyle's last season** | Year 4 or 5. His farewell game at the Barn is a set piece for any path (it's in the paper if you weren't there). He smiles a second time |
| **The Loons' curse** | Lake Ostrander has 0 Cups (`LORE.md`). In one season between Year 3 and Year 6, they are suddenly good, and the GNHL digest follows a run that ends, cruelly, in the Final. Or doesn't, once per save, rarely |
| **Theo Lindgren-Baptiste** | Chases Teddy Varga's assists record over the years; breaks it on a weeknight and describes it as "a nice moment" |
| **The Silverton Specters** | Remain unbearable |
| **Harlow Falls' R-22 plant** | Year 3 closure (`RINK_SIM.md` 6.3) moves contracts and teams; the papers cover it |
| **The Duncannon Gardens** | The council keeps trying to demolish the 1949 Gardens; Marc Leclerc keeps filibustering. A vote every year; it passes or fails in the Ledger |
| **Ilya Petrov's comebacks** | Off the Coach path, he still has comebacks, somewhere, every second season |
| **Maddie Pruitt** | Off the Coach path, she still learns to skate (more slowly), and appears on minor hockey scoresheets in the Clarion. She is somebody's success story either way |

### 6.3 Awards

| League | Award | For |
| --- | --- | --- |
| Valley Beer League (all divisions) | The Haverstock (new) | Season MVP across the three divisions, chosen by the captains. Ronnie presents it and is embarrassed |
| Valley Beer League | The Pruett (new) | Most improved skater; named for Gary Pruett, who learned to stop |
| Valley Beer League | The Gilchrist Steady Hands (new) | Best goalie. Morley Gilchrist III presents it, quietly |
| NSHA | The Aldous Medal (new) | Senior AAA MVP |
| NSHA | The Doyle (new, from Year 5) | Coach of the year, named after Hap's retirement |
| ILHL | The Fisk Outboard (new) | Semi-Pro MVP, a real outboard motor |
| CHA | The Callahan Medal (new) | Minor League Pro MVP |
| GNHL | The Harrowgate | Sportsmanship (`LORE.md`); winners must look embarrassed |
| GNHL | The Frostbank Cool Head Award | Calmest goalie (`LORE.md`) |

---

## 7. The shared cast

### 7.1 Everyone, through three lenses

The same people appear on every path, in different roles. This keeps the
valley one place and makes switching paths feel like seeing your town from
another chair.

| Character | Player path sees | Coach path sees | GM path sees |
| --- | --- | --- | --- |
| Ronnie Haverstock | Mentor; the phone number | A guest coach who runs a Thursday clinic for the Sawdust | A board ally and the face of the expansion campaign |
| Earl Bratt | Your D partner on the Flood Crew | The man who floods before your practices, with opinions about your drills | The man who organises the Dorises write-in |
| Bev | Your edges and your ego | Sharpens a team's skates for free before the Peewee final, once | Your landlord's tenant and a jobs-board employer; tells you the truth about every supplier deal |
| Gus Tremblay (in Florida) | Notes in the binder | Notes in the binder; a postcard after a title | Notes in the binder, including one about the 1979 Kings' budget |
| Dale Huffman | The commissioner who wants your dues | The man who schedules your beer league bench | The man who hands you the binder |
| Donna Pettigrew | The president of minor hockey, a customer | Your boss | Your landlord's most important tenant and the Two Hats test |
| Ray Duchesne | The Kings' chair who invites you, in Act 3 | The man who hires you | The man you replace |
| Old Pete Vachon | Sharpens your skates the night before the Aldous final | The drawer and the photo | The notebook |
| Kenny Szabo | Linemate and friend | A Lumber Kings depth winger you coach, who'd run through a wall for you | A cheap, loyal depth signing who becomes captain |
| Tyler Brandt | Rival | A player you coach for one season and humble, gently | A free agent who overrates himself, then signs for less and is worth it |
| Hap Doyle | The coach who doubts you | The rival coach | The GM who never trades |
| Maddie Pruitt | A kid at public skate who asks for your autograph in Year 4 | The star of your story | A territorial-list name in Year 6, in Old Pete's pencil |
| Little Sauce and Sauce | Sauce is a beer league opponent who tells 61 stories | The kid and the parent | A prospect, and his father calling you about his ice time |
| Ilya Petrov | A Riptide opponent who plays one brilliant shift against you | The former pro with a past | A signing that could make or break a season |
| Donnie Delorme | Sells you crullers at the Harlow Falls bakery and says nothing about hockey | Your assistant coach | Refuses your contract offer by baking a cake with "NO" on it |
| Marlene Fisk | Your Semi-Pro owner | Offers you the Sturgeon bench | Ally and rival owner |
| Lorne Pettigrew | The red phone | Not much: a nod at the Valley Cup | Your affiliation partner |
| Hélène Arsenault | Watches you skate and calls your edges "agricultural" | The other coach in the building | A tenant whose 06:00 slot is sacred |
| Larry Piche and the Mallards | Opponents in BL-C; your volunteers when you're away | The volunteers who run the Peewee tournament's timekeeping | The name-vote write-in |
| Moose Kowalczuk | Interviews you on Saturday Night Hockey after your first GNHL goal | His summer hockey school is a coaching clinic you can teach at | His hockey school is a rink contract (`RINK_SIM.md` 5.3) and a sponsor |
| Anvil Morrow | The hit and the scarf | A defenceman you game-plan around | A trade target who knits in the dressing room |

### 7.2 New characters this doc proposes

For the World thread's approval (and Sean's). Each is small and rooted in
existing canon.

| Name | Who | Rooted in |
| --- | --- | --- |
| Kenny Szabo | Player path linemate, 24 | Bernie Szabo (CKVL) and Kev Szabo (broomball) in `TEAMS.md`, `RINK_SIM.md` |
| Maddie Pruitt | Coach path star, 9 in Year 1 | Dylan Pruitt (rink rat) and Dorothy Pruitt (Honest Hockey founder) |
| "Little Sauce" Saucier | Coach path kid, 12 | Rick "Sauce" Saucier (Moose Knuckles) |
| Stan Kubiak | The Lumber Kings' outgoing coach | New |
| Coach Annette Rourke | Duncannon Dukes head coach | New; the Dukes have no named coach yet |
| Dot Ferland | NSHA commissioner | New |
| Trish Bello | Wexford Ice Dogs owner's marketing VP | Kibble King Pet Foods (`TEAMS.md`) |
| Wendell Moss | The Frostbank branch manager who restructures instead of foreclosing | Frostbank (`LORE.md`), the Frozen Assets (whose branch manager is Colin Nolan, so Wendell is regional, from Duncannon) |
| Merv Tolliver | The Duncannon Daily Ledger columnist who hates everything | `TEAMS.md` (unnamed) |
| The Sawdust | Millbrook U13 C team nickname | Minor hockey (`RINK_SIM.md`) |
| The Northern Junior Hockey League | Junior league used as the ILHL draft pool | New, off-map |
| Donna and Lorne Pettigrew as siblings | A family link | Two existing Pettigrews |

---

## 8. Ownership, hooks and data shapes

### 8.1 Who builds what

| Piece | Owner | Notes |
| --- | --- | --- |
| Path state, side roles, the switch, path progression (coach skills, GM reputation, board trust, Two Hats), the beat runner (`StoryDirector`), chaos pressures and the escalation ladder's timing, catch-up help triggers, the call-up meter, Habits, simming every tier each round, the GNHL table sim, the ILHL tenth club and the draft | **Game mechanics** | Pure logic, testable with `tools/tests/`. Needs a career `role` so the user need not be a dressed skater (`next_managed_game()`), and every tier simulated each round |
| Hands-first balance (the 30-rated-hands target in 3.2), coach systems as `TierAI` nudges (with style, capped by the tier gap), the whiteboard play executed through `Skater.Controls`, the `millbrook_bank` chip pass, bench line overrides in game | **Physics** | `TierAI.with_style()` from `TEAMS.md` generalises to `with_nudges([style, system])` |
| Bench radial menu (beer league playing coach), changes-on-the-fly timing input, whiteboard drawing with stick or mouse, drill demo inputs, the `millbrook_bank` gesture in the move catalog, Comfort settings | **Controls** | `millbrook_bank` is a new catalog id |
| The Legion choice scene, path hub screens (Player: tier ladder and Habits; Coach: practice planner, lines, playbook; GM: binder, jobs board, scouting, trades, budget, Two Hats), the corkboard warnings with their three outs, the skip preview, newspapers and ticker, awards night, the records book | **UI** | All in RinkOS (`assets/ui/STYLE.md`); the corkboard and binder are diegetic where possible |
| The rooms the stories need: the Lumber Kings' office (a corner of the `office` or a new room off the lobby), the coach's room, the whiteboard prop, the trophy case and banners that change with titles, the expansion's renovated stands, Legion Hall Branch 112 on Main Street | **Rink environment** | Room ages via `Venue.set_room_age` |
| The rink-side touchstones (1.8): the day curve (ramp points, ramp-rate wear, staging, load forecast) on top of the `RinkSim` duty controller; the work-priorities grid's job routing; mastered and "do the usual" auto-resolve; the magnetic tray and ghost outlines in the mini games; advertising levers and forecasts with a "why" | **World and asset design (sim core and mini games)** | UI builds the day curve, priorities grid and year planner screens |
| This doc, beat data (`data/world/beats.json`), character data and voxel characters, news and paper text templates, award and record names, the Legion, the Kings' office interior art | **World and asset design** | |

### 8.2 Data shapes

**Path state** in the career save (Mechanics owns the format; proposed under
a `paths` key beside `world`):

```json
"paths": {
  "version": 1,
  "main": "player",
  "chosen_day": 105,
  "side": {"coach": {"active": true, "scale": "side"}, "gm": {"active": true, "scale": "side"}},
  "act": {"player": 3, "coach": 1, "gm": 1},
  "beats": {
    "p3_two_letters": {"state": "done", "day": 1210, "choice": "lumber_kings"},
    "p3_kenny_cut": {"state": "done", "day": 1236}
  },
  "flags": {"senior_club": "nsha_millbrook_lumber_kings", "stayed_for_rink": false},
  "rel": {"ronnie": 64, "kenny": 81, "tyler": 22, "hap_doyle": 15},
  "player": {"habits": ["late_ice_legs", "millbrook_bank"], "habits_equipped": ["millbrook_bank"], "callup_meter": 0.0},
  "coach": {"skills": {"teaching": 0.2, "tactics": 0.1, "bench": 0.1, "rapport": 0.3}, "playbook": ["fc_122"], "familiarity": {}},
  "gm": {"rep": 30, "board_trust": 60, "two_hats": 70, "scouts": [], "notes": {}},
  "chaos": {
    "pressure": {"maintenance": 22, "schedule": 8, "customers": 15},
    "rung": {"maintenance": 0, "schedule": 0, "customers": 0},
    "active_set_piece": "",
    "grace_until": {"maintenance": 0, "schedule": 0, "customers": 0},
    "help_used": {"gus_phone": 0, "mallards_night": 0}
  }
}
```

**A beat** in `data/world/beats.json`:

```json
{
  "id": "p5_red_phone",
  "path": "player",
  "act": 5,
  "trigger": {"event": "day_start", "block": "early"},
  "conditions": [
    {"tier_gte": 5},
    {"callup_meter_gte": 1.0},
    {"beat_done": "p5_receipt"},
    {"not_injured": true}
  ],
  "clash": {"pick_one": ["rink_event_this_week", "home_playoff_lumber_kings", "gnhl_camp_at_rink"]},
  "window_days": [0, 90],
  "priority": 95,
  "scene": "red_phone",
  "choices": [
    {"id": "go", "effects": [{"flag": "stayed_for_rink", "value": false}, {"next": "p6_tail_logo"}, {"rink_mode": "standing_orders", "days": 4}]},
    {"id": "stay", "effects": [{"flag": "stayed_for_rink", "value": true}, {"callup_meter_mul": 0.7}, {"rep": {"community": 10}}]}
  ],
  "fallback": {"after_days": 90, "beat": "p5_red_phone_again"}
}
```

Beat fields, in short:

| Field | Meaning |
| --- | --- |
| `id` | Prefix by path: `p` Player, `c` Coach, `g` GM, `w` world (any path), `x` chaos Set pieces |
| `trigger.event` | `day_start`, `block_start`, `game_end`, `season_end`, `offseason`, `injury`, `tier_change`, `rink_event` (from `RinkSim.advance()` events), `news` |
| `conditions` | All must hold. Small vocabulary: tier, act, flags, relationships, stats, reputation, rink state, pressures, beats done |
| `window_days` | How long after first eligible it may fire; then `fallback` |
| `priority` | Higher wins when several are eligible on one day. At most one story beat and one Set piece per day |
| `scene` | The scene id (dialogue, a match setup, a short playable moment) |
| `choices` and `effects` | Flags, relationship deltas, reputation, money, contracts, Habits, moves, next beats |
| `fallback` | What happens if it never fired: always something gentler, never nothing |

**A chaos Set piece** is a beat with `"path": "any"`, a `pressure` condition
and the cap fields:

```json
{"id": "x_plant_trip_night", "source": "maintenance", "conditions": [{"pressure_gte": {"maintenance": 85}}, {"no_active_set_piece": true}],
 "outs": ["drive_in", "call_valley_refrigeration", "call_marg", "let_it_ride"], "cap": {"money": 2500, "rep_points": 10}}
```

### 8.3 Dev menu

A Paths tab in `DevMenu` (Project manager), through Mechanics' public
functions: set main path, set act, list eligible beats, fire a beat, set a
pressure, trigger catch-up help, fill the call-up meter.

### 8.4 Proposed changes to other docs and code

| Where | Change | Who decides |
| --- | --- | --- |
| `RINK_SIM.md` 5.8 | "The bank calls" becomes Wendell Moss's restructuring (1.4 rule 7). The rink cannot be lost by failure | Sean, World (sim) |
| `RINK_SIM.md` 1.5 | Old Gus difficulty keeps its "no warnings" rule but not the ability to end a save | Sean |
| `career.gd` | A career `role` (player, coach, gm); `next_managed_game()`; all tiers simmed each round; user production weighted 1.5x in `scouting_score()` | Game mechanics |
| `league_tiers.gd` | A seventh tier, the GNHL, for the Player path's Act 6 (open question 3) | Game mechanics, Sean |
| `teams.json` | The ILHL tenth club (Millbrook, expansion), the Sawdust, award names, the Northern Junior Hockey League as a draft pool | World |
| `scripts/core/moves.gd` | `millbrook_bank` move id | Controls |
| `TierAI` | `with_nudges()` taking style and system deltas | Physics |
| `TEAMS.md` | Kenny Szabo, Coach Rourke, Dot Ferland, Merv Tolliver named | World |

---

## 9. Open questions for Sean

1. **How old is the owner at the start?** The code starts the user at 19
   (`Career.new_career`). Recommended: **21**, home after a year at Wendover
   College. Old enough to be handed a rink for a dollar without it being
   strange, young enough that a fast Player path reaches the GNHL at about
   27, before the decline in `Progression` bites, and a slow one meets the
   age arc honestly.

2. **When does the path choice land?** Recommended: **the Legion Christmas
   party, 20 December of Year 1** (about day 105), after three months of
   tasters, with "I'll think about it" allowed until ice-out in June. The
   alternative, choosing at the start, means choosing blind.

3. **Is the GNHL playable?** Recommended: **yes, for the Player path only,
   as a capstone.** A seventh tier in `LeagueTiers` with the 11 GNHL clubs;
   the user plays a stint of about 10 games after the call, then may stay up
   in sandbox seasons where the user plays a 20-game slice and the rest is
   simmed. The Coach and GM paths top out at Semi-Pro (with a CHA epilogue
   offer for the coach) and see the GNHL as the living backdrop.

4. **How does a coach play the games?** Recommended: **bench-first, with a
   playing-coach option in the beer leagues.** The coach's dexterity shows up
   in drill demos, changes on the fly and the timeout whiteboard. Direct
   control of a skater from Senior AAA up would make the Coach path a second
   Player path.

5. **Can paths switch?** Recommended: **once per offseason, at the ice-out
   barbecue**, starting the new path at Act 2 if its side role was active for
   a season. Plus the designed epilogue (`p_last_lace`) for a retiring
   player.

6. **The GM path's franchise: the Lumber Kings or a new club?** Recommended:
   **the Lumber Kings, taken up to become the ILHL's tenth club.** It uses the
   existing team, its 1979 photo and its lease with the rink, and fills the
   tenth ILHL slot `TEAMS.md` left open. A follow-up: should the Coach path's
   Act 5 be allowed to coach that expansion club when the GM side role built
   it? Recommended yes, as a bonus ending for players who kept the side role
   going.

7. **Can the rink ever be lost?** Recommended: **never by failure**, only by
   the player choosing to sell. The bank restructures instead of
   foreclosing (Wendell Moss), and the town helps. This changes one line in
   `RINK_SIM.md` 5.8.

8. **How much do ratings matter against hands?** Recommended: **"hands
   decide, stats shape"**, with the concrete Physics target that good hands
   at rating 30 can lead Beer League D in scoring but can't carry Senior AAA,
   and user production weighted 1.5x in scouting so great hands earn
   promotions even when ratings lag. Sean should play this early (M1 of the
   controls work) and tell us if it feels right.
