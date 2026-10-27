# The cast: who is in the rink

Sean, 2026-10-18: "I want everyone in the game to be a real character with
personality and dialogue options. Every person in the rink should be a real
NPC that moves and interacts with the world. Including everyone in the
stands."

`docs/world/PEOPLE.md` is the system and the data contract. This doc is the
readable companion to the data: who the 77 named people are, who they
love, who they can't stand, and what they come to watch. The game reads:

| File | What |
| --- | --- |
| `data/world/cast.json` | The named cast, one `Person` record each (PEOPLE.md section 3) |
| `data/world/archetypes.json` | The 24 archetypes townsfolk are generated from, plus valley `surnames` and `towns` |
| `data/world/events.json` | Every event kind, the contract-to-kind map, and 16 special events across the year |

Dialogue trees (`data/world/dialogue/<id>.json`) and quests
(`data/world/quests.json`, `docs/world/QUESTS.md`) are written separately.
Every cast member's `dialogue` is their own id and `quests` is empty, ready
for that pass. The quest pass was written at the same time as this one; the
cast uses its ids and folds in the people it needed (section 7), so every
person a quest names is in `cast.json`.

## 1. How to read the cast

- **Ids** are the canon first name (or the name everyone uses) and surname in
  ascii snake case: `bev_kowalchuk`, `helene_arsenault`, `gord_halvorsen`.
  `owner` is the player and never a cast id.
- **Interests** are per event kind, `watch` and `play` from 0 to 1. A kind
  that is missing is 0. Most people love one to three kinds and ignore the
  rest. In this doc "loves" means 0.7 or more. **Play means taking part**, so
  a coach, a referee, a timekeeper or an organiser "plays" the event they
  run: Hélène plays `figure_practice`, Marcel plays `beer_league`, Donna plays
  `tournament`.
- **Schedule** lists where a person is when they are not at an event: work,
  school, bed, a shift at the rink. Hours are floats, days are 0 = Sunday.
  Time not covered by a block is free time, when Attendance can pull them in.
  Staff shifts put them in a rink place (`zamboni_bay`, `canteen`,
  `pro_shop`, `office`, `plant_room`). Kids have `school` 8.5 to 15.5 on
  weekdays and a bedtime.
- **Rel** starts mostly between 0 and 30. Negative numbers are feuds and
  grudges (section 4). Everyone has a starting `owner` value; Earl starts at
  -10 because he is sulking, Hap at -10 because he is Hap.
- **Quests** may use `"self"` for the giver in favour templates; it is not a
  cast id.
- **Family** is a key beyond PEOPLE.md: a list of cast ids who are relatives,
  always reciprocal. Attendance uses it for "families come together" and for
  the kids' events fit (`needs_family_kid` in `events.json`). For named cast,
  a strong interest in a kids' event stands on its own: Donna and Bev do not
  need a child in the building to want to be there. The kid check is for
  generated townsfolk.
- **Look**: `height` scales an adult body (0.85 to 1.12); kids carry 1.0 and
  the body uses `age`. Colours are hex without `#`, and team colours match
  `TEAMS.md` (Lumber Kings `b22222` and black, Mallards green and gold, Dukes
  `4b2a7b` and `e3b23c`, Millmen `143d29` and cream).
- **Archetype** gives a cast member their barks and needs rates; their own
  dialogue tree overrides the barks when it has a line for the moment.

## 2. Everyone

| Name | Id | Role | Age | Hook | Favourite events |
| --- | --- | --- | --- | --- | --- |
| Earl Bratt | `earl_bratt` | Staff, Head icemaker (since 1983) and Doris's driver | 66 | Head icemaker since 1983; sulking at the Legion until the ice stays over 45 | beer league (plays), stick and puck (watches), Senior (watches) |
| Dylan Pruitt | `dylan_pruitt` | Staff, Rink rat | 17 | Wants to drive Doris more than he wants to graduate | Dukes practice (watches), stick and puck (plays), specials (watches) |
| Marguerite Lindqvist | `marguerite_lindqvist` | Staff, Plant operator (retired from the Harlow Falls plant) | 66 | Plant operator with a red pen: 'Fine is not a number' | figure show (watches) |
| Beverly Kowalchuk | `bev_kowalchuk` | Staff, Owner, Bev's Edge & Tape (since 1979) | 67 | Sharpens every skate in town on Old Bertha; opinions free | figure show (watches), figure practice (watches), Senior (watches) |
| Tyler Kowalchuk | `tyler_kowalchuk` | Staff, Shop clerk on weekends | 17 | Bev's grand-nephew on the weekend till; amateur detective | Senior (watches), beer league (watches), stick and puck (plays) |
| Priya Sandhu | `priya_sandhu` | Staff, Booking coordinator, part-time | 38 | Booking coordinator who speaks in time slots | tournament (watches), specials (watches), public skate (plays) |
| Lorraine Duffy | `lorraine_duffy` | Staff, Runs the Hot Stove snack bar (twenty-two years) | 63 | Twenty-two years at the Hot Stove; makes Earl's gravy | broomball (watches), Senior (watches), public skate (watches) |
| Josie Bautista | `josie_bautista` | Staff, Hot Stove counter after school | 16 | Canteen counter and Mallards defence; deadpan | high school (plays), learn to skate (watches), stick and puck (plays) |
| André Clarke | `andre_clarke` | Staff, Maintenance tech (hired from the Kessler trades college) | 29 | Maintenance tech who talks to machines like patients | Senior (watches), stick and puck (plays) |
| Gus Tremblay | `gus_tremblay` | Visitor, Retired arena manager (1977 to last spring) | 75 | The old manager, in Florida; the binder and the postcards. On the owner's first morning he is still in the building before his four o'clock flight and offers the walkthrough (`data/world/tutorial.json`) | Senior (watches), specials (watches), beer league (watches) |
| Ronnie "The Milkman" Haverstock | `ronnie_haverstock` | Regular, Retired GNHL centre (1979 to 1996) | 69 | The Milkman: Millbrook's GNHL legend, still plays Thursdays | stick and puck (watches), specials (plays), Senior (watches) |
| Tracy Haverstock | `tracy_haverstock` | Regular, Manager, Millbrook Dairy shop | 42 | Ronnie's daughter; runs the Old-timers' Invitational | specials (plays), broomball (watches), public skate (plays) |
| Pete Vachon | `old_pete_vachon` | Regular, Lumber Kings equipment manager and club historian (since 1971) | 75 | Lumber Kings equipment manager since 1971; the Valley Book | Senior (watches), specials (watches), stick and puck (watches) |
| Doreen Vachon | `doreen_vachon` | Regular, Timekeeper (the Casio, Organ 2) | 73 | Timekeeper with a Casio on Organ 2 and a dirge for bad calls | Senior (plays), specials (plays), beer league (plays) |
| Stan Szymanski | `stan_szymanski` | Regular, Retired mill millwright | 84 | The rafters end rail, every Kings game since 1974 | Senior (watches), specials (watches) |
| Midge Kaminski | `midge_kaminski` | Regular, Columnist, Off the Boards, The Millbrook Clarion | 64 | Clarion columnist; leave the clock alone | specials (watches), high school (watches), figure show (watches) |
| Agnes Mulroney | `agnes_mulroney` | Regular, Retired art teacher (31 years) | 77 | Art teacher behind the 1976 mural; bonspiel draw master | figure show (watches), specials (plays), public skate (watches) |
| Bud Mulroney | `bud_mulroney` | Regular, Retired rural mail carrier | 79 | Sells the 50/50; Rascal was his dog | Senior (watches), public skate (watches), specials (plays) |
| June Penner | `june_penner` | Regular, Owner, Penner Hardware ('If we don't have it, Harold will order it') | 48 | Harold's granddaughter; seat C-4-7 and the shout | specials (watches), Senior (watches), high school (watches) |
| Dale Huffman | `dale_huffman` | Regular, Commissioner, Valley Beer League (keeper of the binder) | 66 | Beer league commissioner; the binder; wants your dues | beer league (watches), specials (watches), Senior (watches) |
| Donna Pettigrew | `donna_pettigrew` | Regular, President, Millbrook Minor Hockey Association | 56 | Minor hockey president; an army with a bake sale | minor hockey (watches), tournament (plays), specials (watches) |
| Ray Duchesne | `ray_duchesne` | Regular, Board chair, Millbrook Lumber Kings (volunteer) | 66 | Lumber Kings board chair; the January probation deadline | Senior (watches), specials (watches), minor hockey (watches) |
| Hélène Arsenault | `helene_arsenault` | Regular, Head coach, Millbrook Figure Skating Club | 61 | Figure club coach; 06:00 is sacred; 'Again.' | figure practice (plays), figure show (plays), learn to skate (watches) |
| Kev Szabo | `kev_szabo` | Regular, President, Harlow Falls Broomball Club | 58 | Broomball club president; the loudest laugh in the valley | broomball (plays), specials (watches) |
| Bernie Szabo | `bernie_szabo` | Regular, Play-by-play, CKVL 1340 Valley Radio (since 1985) | 63 | CKVL play-by-play; says Kessler three ways | Senior (watches), specials (plays), beer league (watches) |
| Kenny Szabo | `kenny_szabo` | Regular, Grinder winger | 24 | Big-hearted grinder; the Player path linemate | beer league (plays), stick and puck (plays), Senior (plays) |
| Bernie Ostrowski | `bernie_ostrowski` | Regular, Coach, Millbrook High Mallards | 57 | Mallards high school coach; 2009; pays late | high school (plays), Senior (watches) |
| Stan Kubiak | `stan_kubiak` | Regular, Head coach, Millbrook Lumber Kings | 58 | Lumber Kings coach, tired and decent; hands over the whistle | Senior (plays), stick and puck (watches) |
| Gary Pruett | `gary_pruett` | Regular, Manager, Valley Foods | 43 | Learned to stop last February; stops in front of the bench | beer league (plays), minor hockey (watches), tournament (watches) |
| Dr. Lyle Haverkamp | `lyle_haverkamp` | Regular, Dentist, Haverkamp Family Dentistry | 52 | Dentist who lectures on mouthguards and never wears one | beer league (plays), Senior (watches) |
| Rick "Sauce" Saucier | `rick_saucier` | Regular, Sells farm equipment | 49 | 61 goals in 1994; yells from the glass | minor hockey (watches), tournament (watches), beer league (plays) |
| Dwayne Kuzyk | `dwayne_kuzyk` | Regular, Bartender, Hat Trick Tavern | 38 | Ice Holes social convenor; never missed a postgame | broomball (plays), beer league (plays), specials (watches) |
| Morley Gilchrist III | `morley_gilchrist` | Regular, Funeral director | 47 | Funeral director and the steadiest goalie in the valley | beer league (plays), figure show (watches) |
| Colin Nolan | `colin_nolan` | Regular, Branch manager, Frostbank Millbrook | 45 | Bank manager coach with a laminated line-change spreadsheet | beer league (plays) |
| Gino Russo Jr. | `gino_russo` | Regular, Night manager, Puckhead Pizza | 29 | Pizza night manager in a pepperoni goalie mask | beer league (plays), specials (watches) |
| Larry Piche | `larry_piche` | Regular, Town snowplough driver | 61 | Wrote to the Cup trustees in 2005; follows up every March | beer league (plays), specials (watches), high school (watches) |
| Tyler Brandt | `tyler_brandt` | Regular, Sells phones at the Harlow Falls mall | 26 | Half a season of Junior B in 2017; tells you about it | beer league (plays), Senior (plays), stick and puck (plays) |
| Gordon "Big Gord" Halvorsen | `gordon_halvorsen` | Regular, Owner, Big Gord's Trucks (since 1977) | 71 | Big Gord: trucks, billboards, every power play, and Santa | beer league (plays), specials (plays), Senior (watches) |
| Shauna Reid | `shauna_reid` | Regular, Night nurse | 34 | Night nurse, fastest skater in C, crullers for the refs | beer league (plays), stick and puck (plays) |
| Marion Fischer | `marion_fischer` | Regular, Head librarian, Kessler Public Library | 55 | Librarian; polite off the ice, dirty on it; shhh | beer league (plays) |
| Owen Pruett | `owen_pruett` | Family, Grade 5 | 10 | Gary's son; passed his dad in a fortnight | minor hockey (plays), tournament (plays), public skate (plays) |
| Mason "Little Sauce" Saucier | `mason_saucier` | Family, Grade 7 | 12 | Little Sauce: talented, tired of 1994 | minor hockey (plays), tournament (plays), stick and puck (plays) |
| Maddie Pruitt | `maddie_pruitt` | Family, Grade 4 | 9 | Holds the chair at learn-to-skate; the Coach path's star | learn to skate (plays), public skate (plays), figure show (watches) |
| Carla Pruitt | `carla_pruitt` | Customer, Shift supervisor, Millbrook Dairy plant | 44 | Dylan and Maddie's mum; Honest Hockey to the bone | learn to skate (watches), high school (watches), minor hockey (watches) |
| Tommy Bellweather | `tommy_bellweather` | Family, Grade 6 | 11 | Rink rat who runs the crest-trading table like a bank | Dukes practice (watches), tournament (watches), stick and puck (plays) |
| Marisol Bautista | `marisol_bautista` | Customer, Personal support worker | 42 | Learning to skate at 42 so her kids aren't the only ones | learn to skate (plays), public skate (plays), high school (watches) |
| Colette Beaulieu | `colette_beaulieu` | Regular, Assistant coach, Millbrook Figure Skating Club | 26 | Figure assistant coach; kids' learn-to-skate; 'Knees soft' | learn to skate (plays), figure practice (plays), figure show (plays) |
| Josée Thibodeau | `josee_thibodeau` | Family, Grade 9 | 14 | The club's best jumper, testing Senior Bronze; operatic falls | figure practice (plays), figure show (plays), public skate (watches) |
| Carol Thibodeau | `carol_thibodeau` | Customer, Pharmacist, Millbrook Drugs | 44 | Eight years on the 6 am coffee bench; a decimal point | figure show (watches), figure practice (watches) |
| Lily Marchetti | `lily_marchetti` | Family, Grade 3 | 8 | Eight, sequins, falls a lot and loves it | figure show (plays), figure practice (plays), public skate (plays) |
| Paolo Marchetti | `paolo_marchetti` | Customer, Shoe repair (and skate-boot stretching, which annoys Bev) | 39 | Films every practice from three angles; Bev hates his boot stretching | figure practice (watches), figure show (watches), specials (watches) |
| Noah Delisle | `noah_delisle` | Customer, Grade 11 | 16 | Figure skater and Mallards winger; will have to choose | figure practice (plays), figure show (plays), high school (plays) |
| Yvette Lacombe | `yvette_lacombe` | Visitor, Figure skating judge and test evaluator | 68 | Test day judge from Sainte-Odile with her own blanket | figure show (plays), figure practice (watches) |
| Irene Dubois | `irene_dubois` | Regular, Retired switchboard operator | 81 | Every week since opening night 1974; skates Albert's laps too | public skate (plays), figure show (watches), figure practice (watches) |
| Jess Whitehorse | `jess_whitehorse` | Customer, Veterinary technician, part-time | 31 | Mum at Friday public skate with a toddler who loves Doris | public skate (plays), learn to skate (watches), specials (watches) |
| Birdie Whitehorse | `birdie_whitehorse` | Family, Toddler | 3 | Three; falls every four seconds; 'DOWIS!' | public skate (plays), specials (watches), learn to skate (plays) |
| Hank Lavoie | `hank_lavoie` | Regular, Paper machine tender, nights, Kessler Pulp & Paper | 47 | Off nights at the paper mill at five; pucks till he's sleepy | stick and puck (plays), broomball (watches), Senior (watches) |
| Marcel Thibodeau | `marcel_thibodeau` | Regular, Referee, Valley Beer League and NSHA (thirty seasons) | 56 | Veteran ref; would like a second coat hook; 'Noted' | beer league (plays), Senior (plays), minor hockey (plays) |
| Nell Haraldsen | `nell_haraldsen` | Regular, Referee, Valley Beer League (four nights a week) | 35 | Ref four nights a week; wants a second coat hook | beer league (plays), Senior (plays), Dukes practice (watches) |
| Brody Sauvé | `brody_sauve` | Regular, Grade 10 | 15 | Fifteen-year-old minor hockey ref, right about the rules | minor hockey (plays), tournament (plays), high school (watches) |
| Moose Kowalczuk | `moose_kowalczuk` | Visitor, Host, Moose on the Loose (Saturday Night Hockey) | 72 | PIM king turned TV darling; the penalty box library | minor hockey (plays), specials (plays), Senior (watches) |
| Barry "Suitcase" Pomeroy | `barry_pomeroy` | Visitor, Retired GNHL defenceman | 61 | Suitcase: nine clubs, seven Dukes stints, always welcome | specials (plays), Dukes practice (plays) |
| Donnie Delorme | `donnie_delorme` | Visitor, Baker (the better twin) | 56 | The better twin; bakes; says nothing | beer league (watches), stick and puck (plays) |
| Hap Doyle | `hap_doyle` | Visitor, Head coach, Kessler Millmen (since 1988) | 71 | Kessler's coach; smiled once in 1996; 'We'll see' | Senior (plays), stick and puck (watches) |
| Annette Rourke | `annette_rourke` | Visitor, Head coach, Duncannon Dukes (CHA) | 45 | Dukes coach; chews ice; 'the same every night' | Dukes practice (plays), Senior (watches) |
| Merv Tolliver | `merv_tolliver` | Visitor, Columnist, The Last Word, The Duncannon Daily Ledger | 60 | Ledger columnist who hates everything, in stars | Senior (watches), specials (watches) |
| Cody Lindqvist | `cody_lindqvist` | Regular, Brewmaster, Sin Bin Brewpub | 36 | Brewer and rules lawyer; Marg's son | beer league (plays), specials (watches) |
| Penny Marchetti | `penny_marchetti` | Regular, Gym teacher, Millbrook Elementary | 31 | Gym teacher and adult learn-to-skate instructor; Paolo's sister | learn to skate (plays), public skate (plays), figure show (watches) |
| Walter Oduya | `walter_oduya` | Customer, Retired electrician, Kessler Pulp & Paper | 62 | Retired electrician learning to skate for his granddaughter | learn to skate (plays), public skate (plays) |
| Devon Marsh | `devon_marsh` | Customer, Line cook, the Slapshot Saloon | 29 | Met Ama at public skate; planning to propose there | public skate (plays), specials (plays) |
| Rhonda Pelkey | `rhonda_pelkey` | Regular, Hydro dispatcher | 39 | Broomball goalie; keeper of the Golden Boot | broomball (plays), specials (plays) |
| Lisa Cormier | `lisa_cormier` | Customer, Dental hygienist | 36 | U7 novice manager; panic-bakes blueberry muffins | minor hockey (watches), public skate (plays), learn to skate (watches) |
| Desmond Faulk | `desmond_faulk` | Regular, Music teacher, Millbrook High | 48 | Pep band leader with a 1971 sousaphone; Section See | high school (watches), Senior (watches), specials (watches) |
| Bob Ferreira | `bob_ferreira` | Regular, Retired freight dispatcher (Carrick Junction) | 63 | Tournament chair who wants it to run on time, once | tournament (watches), minor hockey (watches), specials (watches) |
| Réjean Paquette | `rejean_paquette` | Visitor, Equipment manager, Duncannon Dukes (twenty-six years) | 58 | Dukes equipment manager; trusts only his IR gun | Dukes practice (plays), Senior (watches) |
| Terry Duffy | `terry_duffy` | Regular, Plumber, Duffy Bros. Plumbing & Heating | 44 | Plungers centre; his pager goes off on breakaways | beer league (plays), Senior (watches) |
| Lorne Pettipiece | `lorne_pettipiece` | Visitor, Woodworker, Pettipiece Woodworks | 70 | Woodworker who builds benches from broken sticks | Senior (watches), specials (watches) |

## 3. The circles

### 3.1 The rink staff

The people on the payroll, or about to be. Nobody is on it on day one
(`RINK_SIM.md` 2.2); each arrives on their own condition.

- **Earl Bratt** drives Doris and nobody else drives Doris, until Dylan has
  twenty supervised floods and Kenny takes her out on the night the call
  comes. He floods before figure ice on Tuesday and Thursday at 05:00, the
  late beer league ice and the weekend. He plays D for the Flood Crew.
- **Dylan Pruitt** asks for a job in week two. He does everything except the
  plant and the money, fast and sloppy, then good.
- **Marg Lindqvist** (`marguerite_lindqvist`) runs the plant once the rink is Fair or the grumpy
  compressor trips. Rounds at 05:00, red pen, matched belts.
- **Bev Kowalchuk** sharpens across the lot and joins the payroll once she
  likes you, never on Sundays. **Tyler Kowalchuk** works her till on
  weekends once the counter is open more than twelve hours.
- **Priya Sandhu** takes the phone when the rink has twenty contracts.
- **Lorraine Duffy** has run the Hot Stove for twenty-two years; **Josie
  Bautista** works the counter after school. **André Clarke** is the
  maintenance tech hired from Kessler when the reputation is Good.
- **Gus Tremblay** is not staff any more, but his binder is, and his
  postcards arrive monthly. If the rink reaches Great he visits.

### 3.2 The regulars and the town

The people who are in the building most weeks whether anything is booked or
not, and who carry the town's memory.

- **Ronnie Haverstock** plays the Thursday old-timers' game and passes off
  the dead spot. His daughter **Tracy** books the Old-timers' Invitational.
- **Old Pete and Doreen Vachon**: equipment and history; the clock and the
  Casio. Married for fifty years and still bickering about the 15 card.
- **Stan Szymanski** at the rafters end, **June Penner** in her
  grandfather's seat C-4-7, **Bud Mulroney** with the 50/50 roll and **Ray Duchesne** with his programme
  column are the Lumber Kings' crowd in four people.
- **Midge Kaminski** writes the Clarion's column and is the town's voice on
  keepsakes. **Agnes Mulroney** taught the art class that painted the mural
  and runs the bonspiel draw.
- **Irene Dubois** has skated every week since opening night in 1974 and
  skates her late husband Albert's laps as well as her own.
- **Desmond Faulk** leads the Millbrook High pep band from Section See;
  **Lorne Pettipiece** builds benches from Bev's broken sticks.

### 3.3 The figure club

The club rents Tuesday and Thursday 06:00 and Saturday noon, needs the
surface at -3 to -4 C and never forgives hockey ice at its session.

- **Hélène Arsenault**, head coach. **Colette Beaulieu**, her former skater,
  assistant coach and the kids' learn-to-skate group.
- **Josée Thibodeau**, 14, the best jumper, testing her Senior Bronze, and
  her mother **Carol**, a pharmacist with a thermos; her dad is **Marcel**,
  the referee, who watches tests from the lobby. **Lily Marchetti**, 8,
  sequins and falls, her father **Paolo**, three camera angles, and her aunt
  **Penny**. **Noah Delisle**, 16, the only boy in the club and the fastest
  skater on the Mallards.
- **Madame Yvette Lacombe** drives from Sainte-Odile to judge test day.
- In the stands: Agnes, Midge, Doreen, Bev (she was the girl doing the sit
  spin in the mural), Irene (who comes early for the end of practice) and
  Marisol.

### 3.4 Minor hockey and the families

- **Donna Pettigrew** runs Millbrook Minor Hockey and is the rink's most
  important customer.
- The Pruitts: **Carla**, Dorothy Pruitt's granddaughter, and her kids
  **Dylan** and **Maddie**. The Pruetts (no relation, and tired of saying
  so): **Gary** and **Owen**. The Saucier problem: **Rick** and his son
  **Mason** ("Little Sauce"). The Bautistas: **Marisol** and **Josie**.
- **Lisa Cormier** manages the U7 novices and their thirty mittens. **Bob
  Ferreira** chairs the Valley Peewee Tournament. **Tommy Bellweather**, 11,
  runs the crest-trading table and wants twelve Dukes signatures.
- **Brody Sauvé**, 15, refs the games for $25 and the experience.

### 3.5 The beer league

Valley Beer League D and C both play at Millbrook (`TEAMS.md`), so a
generous slice of the cast is beer league. The named ones are each team's
notable: **Gary Pruett** (Wobbly Pops), **Dr. Lyle Haverkamp** (Molars),
**Rick Saucier** (Moose Knuckles), **Dwayne Kuzyk** (Ice Holes), **Morley
Gilchrist III** (Pallbearers), **Earl** (Flood Crew), **Colin Nolan**
(Frozen Assets), **Gino Russo Jr.** (Puckheads), **Cody Lindqvist** (Sin Bin
Brewers), **Big Gord** (`gordon_halvorsen`, Haulers), **Terry Duffy**
(Plungers), **Larry Piche** (Mallards), **Tyler
Brandt** (Cold Ones), **Shauna Reid** (Night Owls), **Marion Fischer**
(Overdues), plus **Kenny Szabo**. **Dale Huffman** keeps the binder and
watches from the stands at 21:30.

### 3.6 Public skate, learn-to-skate, stick and puck, broomball

- Public skate: **Irene**, **Jess Whitehorse** and her toddler **Birdie**
  on quiet Fridays, and **Devon Marsh**, who met his Ama on a Saturday and
  plans to propose there.
- Monday adult learn-to-skate, taught by **Penny Marchetti**: **Walter
  Oduya**, 62, learning for his granddaughter Zuri, and **Marisol
  Bautista**, racing, silently, to let go of the boards first. Colette
  takes the kids' group, where Maddie holds the chair and Birdie falls every
  four seconds.
- Stick and puck: **Hank Lavoie** at dawn off nights, **Kenny**, **Tommy**,
  **Tyler**, **Little Sauce** alone, and sometimes **Donnie Delorme** doing
  something nobody can explain.
- Wednesday broomball: **Kev Szabo**, **Rhonda Pelkey** in goal with the
  Golden Boot on her porch, **Dwayne** and sometimes Kenny. Lorraine, Hank
  and Tracy watch.

### 3.7 League, officials and the media

**Marcel Thibodeau** (referee, thirty seasons), **Nell Haraldsen** (referee
four nights a week, NSHA linesperson, after a second coat hook), **Brody**
(minor hockey ref). **Bernie Szabo**
calls the Kings on CKVL; **Merv Tolliver** reviews the rink in stars for the
Ledger. **Coach Bernie Ostrowski** has the Mallards, **Stan Kubiak** the
Lumber Kings.

### 3.8 Visitors

They come to Millbrook for something specific, then leave.

- **Moose Kowalczuk** for his summer hockey school (`RINK_SIM.md` 5.3) and
  any retirement ceremony he can cry at.
- **Barry "Suitcase" Pomeroy** with the Dukes and for the Old-timers'.
- **Coach Annette Rourke** and **Réjean Paquette**, the Dukes' equipment
  manager with his own infrared gun, when the Dukes rent practice ice
  (`dukes_practice`, ice 85 or better).
- **Hap Doyle** with the Kessler Millmen.
- **Donnie Delorme** from his Harlow Falls bakery, to the back row.
- **Gus**, if the rink earns it.

## 4. Relationships worth knowing

**Feuds and grudges**

- **Rick Saucier and Dr. Haverkamp** (-40 both ways): the Toothbrush
  Incident. The bill is unpaid; the Molars bring it to every game.
- **Rick and Donna** (-25): he coaches from the glass, she runs the
  association that has to deal with it. **Rick and Brody** (-20 and -30):
  Brody is fifteen and right.
- **Midge and Merv** (-30 both ways): the warm columnist and the acid one.
  They agree about the ice and never about anything else.
- **Carol Thibodeau and Paolo Marchetti** (-10 both ways): the filming spot on the
  glass. **Paolo and Bev** (-5): boot stretching.
- **Tyler Brandt and Tyler Kowalchuk** (-15 both ways): the name.
- **Rhonda and Earl** (-10): when the flood happens before broomball.
- **June Penner and Big Gord** (-20 and -10): billboards.
- **Doreen and Marcel** (-5 both ways): the dirge.
- **Cody and Marcel** (-15): Rule 6.2.
- **Stan Szymanski and Merv** (-20): the Ledger saw him cry.

**In love**

- **Devon and Ama**: he is going to propose at public skate, during their
  song, with the lights down (Ama is not in the cast; she is the reason).
- **Old Pete and Doreen**, fifty years. **Agnes and Bud**, longer.
- **Dylan and Josie**: he has a crush (50); she laughs at his jokes (35).
  Nothing more is written; it is for the dialogue writers.

**Who owes whom**

- Rick owes Dr. Haverkamp for a front tooth.
- The Mallards' high school team owes the rink, always, sixty days late.
- Every beer leaguer owes Dale their $120.
- The refs owe Shauna for the crullers, which the incident book records.
- Kenny feels he owes Ronnie for every piece of advice; Ronnie thinks
  advice is free.

**Mentors and heroes**

Tommy worships Dylan, who worships Earl, who misses Gus. Josie wants to be
Shauna. Little Sauce listens to Ronnie and not to his dad. Colette still
skates for Hélène, who still skates for Madame Lacombe. Marg reads her son
Cody's penalty sheet in red pen.

## 5. Events

Thirteen kinds (PEOPLE.md section 2) live in `events.json` with a base
`pull`, a `spectator_cap` (the share of seats the kind can fill), a
participant range, participant ages and `needs_family_kid`. The `contracts`
map gives every `RinkContracts.ORGS` id its kind (`figure_club` is
`figure_practice`, `lumber_kings` is `senior_hockey`, `dukes_practice` is
`pro_practice`); `contracts_proposed` covers the new organisations in
`RINK_SIM.md` 5.3. Every kind has at least three named people who love
playing it and three who love watching it.

The year's special events, each with a host from the cast, a blurb and what
makes it go well or badly:

| Special | When | Kind | Host |
| --- | --- | --- | --- |
| Lumber Kings Home Opener | second Friday of October | `senior_hockey` | Ray |
| Halloween Public Skate | day 304 | `public_skate` | Dylan |
| Doris Day | day 306 | `special` | Earl |
| Valley Peewee Tournament | third weekend of November (and one weekend a month in winter) | `tournament` | Bob |
| Skate with Santa | second Saturday of December | `public_skate` | Big Gord |
| The Snowflake Showcase | third Saturday of December | `figure_show` | Colette |
| Haverstock Old-timers' Invitational | third weekend of January | `special` | Ronnie |
| Hockey Day in Millbrook | last Saturday of January | `special` | Donna |
| Millbrook Winter Carnival | first weekend of February | `special` | Midge |
| The Broomball Beer Cup (Carnival Final) | first Saturday of February (Carnival night) | `broomball` | Rhonda |
| Valentine's Couples Skate | day 45 | `public_skate` | Doreen |
| Harold Penner Night | first Saturday of March | `special` | June |
| Figure Club Test Day | second Sunday of March | `figure_show` | Hélène |
| Learn-to-Skate Graduation | last Monday of March | `learn_to_skate` | Penny |
| The Spring Carnival (the ice show) | second Saturday of April | `figure_show` | Hélène |
| Doris's Retirement Fund Skate-a-thon | last Saturday of April | `public_skate` | Dylan |

A special's `draws` lists the kinds whose fans it pulls besides its own
(Hockey Day in Millbrook draws minor hockey, high school, beer league and
Senior fans). The Spring Carnival is the club's fifty-first carnival (the
quest `helene_fifty_carnivals` dresses its lamps with Gus's gels); the
February Winter Carnival is the town fair, with a figure exhibition under
the gels and the broomball final for the Golden Boot. Two more canon dates were left out to keep the list at 16 and
could be added later: the New Year's Eve skate to 00:30 with Auld Lang Syne
on the Casio, and the Mallards' anniversary on 12 March with its single
green balloon.

## 6. The archetypes

Generated townsfolk come from 24 archetypes (PEOPLE.md section 5). Each sets
trait ranges, interests, a schedule, a look, needs rates per hour, a family
shape, about twenty first names for its age, and barks in every situation
from bad ice to a long canteen line. Weights are each archetype's share of a
town's population and sum to 0.99; staff, officials, shopkeepers, canteen
workers and scouts are deliberately rare, since the cast covers them.

| Archetype | Weight | Ages | Loves |
| --- | --- | --- | --- |
| `hockey_parent` | 0.1 | 30 to 55 | tournament, minor hockey, learn to skate |
| `figure_parent` | 0.04 | 32 to 55 | figure show, figure practice, learn to skate |
| `rink_rat` | 0.03 | 10 to 17 | stick and puck, Dukes practice, Senior |
| `beer_leaguer` | 0.1 | 24 to 60 | beer league, stick and puck, Senior |
| `retiree_regular` | 0.07 | 62 to 90 | Senior, specials, public skate |
| `date_night` | 0.05 | 18 to 40 | public skate, specials, Senior |
| `figure_skater` | 0.04 | 6 to 20 | figure practice, figure show, public skate |
| `minor_player` | 0.09 | 5 to 17 | minor hockey, tournament, public skate |
| `teen` | 0.07 | 13 to 19 | high school, public skate, Senior |
| `learn_to_skate_adult` | 0.03 | 25 to 70 | learn to skate, public skate, figure show |
| `stick_and_puck_regular` | 0.03 | 16 to 60 | stick and puck, beer league, Dukes practice |
| `broomballer` | 0.03 | 20 to 60 | broomball, specials, beer league |
| `superfan` | 0.06 | 30 to 85 | Senior, specials, Dukes practice |
| `autograph_hunter` | 0.02 | 8 to 45 | Dukes practice, Senior, specials |
| `coffee_coach` | 0.03 | 30 to 60 | minor hockey, tournament, high school |
| `grandparent` | 0.07 | 58 to 90 | minor hockey, figure show, learn to skate |
| `scout` | 0.005 | 35 to 70 | Senior, Dukes practice, tournament |
| `shift_worker` | 0.06 | 22 to 62 | stick and puck, beer league, Senior |
| `shopkeeper` | 0.005 | 30 to 75 | Senior, specials, figure show |
| `canteen_worker` | 0.01 | 15 to 70 | specials, tournament, broomball |
| `volunteer` | 0.02 | 40 to 85 | specials, minor hockey, tournament |
| `official` | 0.01 | 15 to 65 | beer league, Senior, minor hockey |
| `coach` | 0.015 | 22 to 75 | minor hockey, Senior, high school |
| `rink_staff` | 0.005 | 16 to 70 | beer league, Senior, stick and puck |

What makes each one fun in the stands:

- **hockey_parent**: lives on the glass with a coffee, loses track of which
  motel they're in on tournament weekends, says "SKATE" and then apologises.
- **figure_parent**: up since 4:40, asks about the surface temperature like
  a prescription, knows every song in the program and hates that.
- **rink_rat**: knows where the 41 lost pucks are, asks for a job, asks to
  drive Doris, asks for an autograph on their arm.
- **beer_leaguer**: blames the ice, the knee and the binder, in that order;
  the pitcher is pre-ordered.
- **retiree_regular**: was here for the 1974 opener and is still angry about
  the score; gets cold first and leaves happy if there was hot chocolate.
- **date_night**: falls, laughs, shares a Haverstock; the slow song is the
  peak of their week.
- **figure_skater**: counts the program under their breath and takes ruts
  at the takeoff personally.
- **minor_player**: has been dressed for an hour, wants a freezie and fries,
  and loves Doris.
- **teen**: here to be seen, rates the ice "mid", secretly having fun.
- **learn_to_skate_adult**: helmet, elbow pads, gallows humour, triumph at
  two seconds without the boards.
- **stick_and_puck_regular**: wants silence and an empty net; "Ping."
- **broomballer**: loud on purpose, shorts in a fridge, hates a late flood.
- **superfan**: cowbell, chant, "BEAT THE MILL"; writes a letter if the
  fries run out.
- **autograph_hunter**: Sharpie in every pocket, devastated by back doors.
- **coffee_coach**: coaches from the glass, played Midget AA, has emailed the
  association. The stands' chaos engine.
- **grandparent**: lemon squares, a knitted toque per game, cheers the wrong
  red jersey.
- **scout**: "Hmm." Drives four hours for one shift; leaves at the whistle.
- **shift_worker**: comes at 10 am on a Tuesday, says "Yup", goes to bed.
- **shopkeeper**: Main Street in a seat; mentions their board ad.
- **canteen_worker**: "Whatcha having, hon?" The best barometer of the
  crowd's mood.
- **volunteer**: clipboard is law; 50/50 for the kids; on the doors since
  1983.
- **official**: one coat hook, three officials, noted; hears everything,
  officially nothing.
- **coach**: practice plan laminated, wants the ice the same, loses it over
  a late flood.
- **rink_staff**: the snow pit is full, the belt is squealing, nobody touch
  breaker 14.

## 7. Canon notes

**Reconciled**

- Bev is 67 (`PROSHOP.md`, and the 1976 mural where she is 17). The PEOPLE.md
  example record says 58; the cast uses 67. The example's hair value
  `grey_bun` is not in the look enum, so she has `bun` with grey hair.
- `RinkContracts.ORGS` does not carry an event kind yet, though PEOPLE.md
  section 2 says it will; until it does, `events.json` `contracts` is the
  map.
- Gary Pruett (Wobbly Pops, the Pruett award) and the Pruitts (Dylan,
  Maddie, Dorothy of Honest Hockey) are different families with similar
  names. The cast keeps them apart and makes it a running joke.
- Ages derived from canon dates: Ronnie 69 (drove the milk truck until 22,
  left in 1979), Old Pete 75 (since 1971), Stan Szymanski 84 (the rail since
  1974), Dale Huffman 66 (a student painter on the 1976 mural), Agnes 77
  (taught thirty-one years, supervised the mural), Rick Saucier 49 (Midget
  AA in 1994), Tyler Brandt 26 (Junior B in 2017), Gus 75 (manager from 1977
  for forty-nine years), Moose 72, Suitcase 61, Donnie Delorme 56.
- Old Pete's first name is written Pete; canon never gives a longer one.
  Little Sauce had no first name in canon; he is Mason here.
- Hélène is from Sainte-Odile, which fits her French and the judge's town;
  canon only says she coaches the club.

**Merged with the quest pass**

`docs/world/QUESTS.md` was written alongside this cast and named its own
people. Where the two passes invented the same person, the cast takes the
quest's id and folds the details together; where the quest named a canon
person differently, the cast takes the quest's id:

| Cast id | Notes |
| --- | --- |
| `gordon_halvorsen`, `marguerite_lindqvist` | Canon Big Gord and Marg, under their full first names |
| `lorraine_duffy` | The Hot Stove cook (this pass had her as Lorraine Bouchard); 63, twenty-two years, Terry Duffy's aunt |
| `irene_dubois` | The opening-night public skater (this pass had a widower, Arnie MacPhail; Irene replaces him) |
| `josee_thibodeau`, `carol_thibodeau` | The figure skater and her 6 am mother (this pass had Sophie and Grace Tran); Marcel the ref becomes Josée's dad |
| `hank_lavoie` | The dawn stick-and-puck shift worker (this pass had Len Bouchard) |
| `tommy_bellweather` | The rink rat and autograph hunter (this pass had Jojo Bautista) |
| `nell_haraldsen` | The referee who wants a second hook (this pass had a linesperson, Kim Nakashima) |
| `june_penner` | Harold Penner's granddaughter in C-4-7 (this pass had his son Russ) |
| `tyler_kowalchuk` | Now 17 and an amateur detective, as the quests have him |
| `penny_marchetti`, `walter_oduya`, `devon_marsh`, `rhonda_pelkey`, `lisa_cormier`, `desmond_faulk`, `bob_ferreira`, `rejean_paquette` | The quest pass's new people, given full records. Penny is made Paolo's sister |
| `terry_duffy`, `lorne_pettipiece` | Canon (`TEAMS.md`, `PROSHOP.md`), needed as quest talk targets |

To avoid two Desmonds and two Paquettes, this pass's maintenance tech is
**André Clarke** and its teen ref is **Brody Sauvé**. Dropped as duplicates:
Imran Qureshi and Hannah Boychuk (Devon covers date night), Gerald Fong
(Walter covers the adult beginner), Tina Moreau (Rhonda covers broomball),
Jonah Littlechild (Réjean and Suitcase cover the Dukes).

**New characters for Sean to approve**

Invented in this pass, rooted in canon roles that had no name yet, or added
so every event kind has its lovers:

| Id | Who | Why |
| --- | --- | --- |
| `tracy_haverstock` | Ronnie's daughter, runs the Old-timers' | `RINK_SIM.md` 5.3: "Ronnie Haverstock, via his daughter" |
| `josie_bautista`, `marisol_bautista` | A canteen teen and Mallard, and her mother, an adult learner | Canteen, high school and learn-to-skate cover |
| `andre_clarke` | Maintenance tech | `RINK_SIM.md` 2.2 "hired from the trades college in Kessler" |
| `bud_mulroney` | Agnes's husband, the 50/50 seller | The Mulroneys' dog Rascal (`DECOR.md`); the 50/50 drum |
| `mason_saucier` | Little Sauce's first name | `PATHS.md` 4.3 |
| `owen_pruett` | Gary Pruett's son | The Wobbly Pops "learned the same winter their kids did" |
| `carla_pruitt` | Dylan and Maddie's mother, Dorothy's granddaughter | `PATHS.md` 4.3 family line |
| `colette_beaulieu` | Figure assistant coach, kids' learn-to-skate | Figure and learn-to-skate cover |
| `lily_marchetti`, `paolo_marchetti`, `noah_delisle` | Figure skaters and a parent | Figure club cover |
| `yvette_lacombe` | Figure test judge | Test day |
| `jess_whitehorse`, `birdie_whitehorse` | Mum and toddler at public skate | Public skate and the kid who falls a lot |
| `marcel_thibodeau`, `brody_sauve` | Veteran referee, minor hockey ref | The ref room and the incident book |

**Proposed links**: Marg Lindqvist is Cody Lindqvist's mother (both canon,
unlinked until now); Big Gord is Santa at Skate with Santa (canon) and
Donna is Lorne Pettigrew's sister (`PATHS.md` 7.2, not in the cast data
because Lorne is not in the cast). Evan Lindqvist of the Wendover Scholars
could be Marg's nephew, unwritten.

**New special events**: Doris Day on 2 November (the arena's and Doris's
shared birthday; the quest `earl_doris_day` marks it), Hockey Day in
Millbrook, the Broomball Beer Cup as the name of the Carnival final (the
trophy is the quests' Golden Boot), Harold Penner Night (the quests'
`june_memorial_game`), figure test day, learn-to-skate graduation, the
Spring Carnival in April and Doris's Retirement Fund Skate-a-thon. The
Snowflake Showcase, Skate with Santa, the Winter Carnival, the Halloween
skate, the home opener, the Old-timers' and the Peewee tournament are canon.
