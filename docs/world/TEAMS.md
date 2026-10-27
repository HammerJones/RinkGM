# RinkGM clubs and leagues

This is the hockey world of the valley, every club on the ladder from Beer League D to Minor League Pro. The machine-readable version is `teams.json` next to this file, and it holds everything below, so the Mechanics thread can load it directly.

The tone follows the world lore: the clubs are funny because they are true. Every beer league in the north has a team of dentists, a team of guys who were good in 1994, and a team that only shows up for the postgame. Higher up the ladder the jokes move from the players to the owners, mascots and marketing departments, and the hockey gets serious.

Everything here is built to sit on top of the GNHL lore in `LORE.md` and `canon.json`: the sponsors use their canon names, slogans and colours, the Millbrook Mallards are the beer league team who asked for the Puckworth Cup in 2005, the Duncannon Dukes are Kingsport's affiliate with the red rotary phone, and Ronnie Haverstock still plays the Thursday old-timers' game (which is not a league, so he appears as a cameo, not a club). Nearly every beer leaguer in the valley wears Honest Hockey gear.

## The ladder at a glance

| Tier | League | Short | Clubs | Divisions | Trophy |
| --- | --- | --- | --- | --- | --- |
| Beer League D | Valley Beer League, D Division (the Late Ice League) | VBL-D | 7 | Early Ice, Late Ice | The Last Call Cup |
| Beer League C | Valley Beer League, C Division (the Scorekeepers) | VBL-C | 7 | Tuesday, Thursday | The Moosebrew Mug |
| Beer League A | Valley Beer League, A Division (the Grudge League) | VBL-A | 8 | Pad 1, Pad 2 | The Frostbank Valley Championship (the Gord) |
| Senior AAA | Northern Senior Hockey Association (Senior) | NSHA | 8 | Mill Division, Lake Division | The Aldous Cup |
| Semi-Pro | Interlake Hockey League (the Gas Money League) | ILHL | 9 | Lakeshore Division, Rail Division | The Pembrook Trophy (the Gas Can) |
| Minor League Pro | Continental Hockey Association (the Minors) | CHA | 9 | Timber Division, Iron Division | The Callahan Shield |

The three beer leagues are divisions of one organisation, the Valley Adult Recreational Hockey League, which everyone calls the Valley Beer League. It is run out of a binder at the Millbrook Community Arena front desk. D and C play at Millbrook (late ice, shared rink, so every game is a home game for somebody's sponsor); A plays at the Harlow Falls twin pad. From Senior up, clubs have their own rinks and away games really are away.

Club counts match `league_tiers.gd` exactly (7, 7, 8, 8, 9, 9; 48 clubs). Three expansion clubs are included (the Puckheads for D; the Cold Ones and Kessler Overdues for C), marked `expansion` in the data, in case those leagues go to eight teams so nobody has a bye week. Semi-Pro and Minor League Pro have nine clubs, so they also have a bye each round; a tenth club each would need a new name later.

## Trophies

- **The Last Call Cup** (Valley Beer League, D Division). A dented pewter beer stein bolted to a hockey puck. The engraving plate ran out in 2011, so winners now write their names on masking tape.
- **The Moosebrew Mug** (Valley Beer League, C Division). A two-litre glass mug etched with a moose. Filled once by the winners, emptied quickly, returned sticky.
- **The Frostbank Valley Championship (the Gord)** (Valley Beer League, A Division). Officially the Frostbank Valley Championship. Everyone calls it the Gord, after the bronze bust of Big Gord Halvorsen he donated in 1998 without being asked.
- **The Aldous Cup** (Northern Senior Hockey Association). A real silver cup from 1922, donated by Kessler mill owner Thaddeus Aldous. It has been dropped through the ice of Port Ainsley lake once (1962) and recovered by a man in waders.
- **The Pembrook Trophy (the Gas Can)** (Interlake Hockey League). The original 1979 trophy was a chrome jerry can on a walnut base, because the founder ran a gas station. The new one is nicer. Nobody calls it anything but the Gas Can.
- **The Callahan Shield** (Continental Hockey Association). A heavy oak shield with a silver maple leaf for every champion since 1951. Two trainers carry it; it does not get skated around.
- Above all of them sits the Puckworth Cup of the Grand Northern Hockey League (see the GNHL canon).

## Playing styles

Each club has one style tag the on-ice AI can express. A style is a small nudge on top of the tier's `ai` block in `league_tiers.gd`, never bigger than the gap between two tiers, so a Senior trap team is still better organised than a beer league one.

| Style | What it looks like | TierAI nudge |
| --- | --- | --- |
| `swarm` | Everyone chases the puck. Beer league classic. | discipline -0.10, anticipation -0.05, dash_use +0.10 |
| `run_and_gun` | Fly the zone, trade chances, forget defence. | dash_use +0.15, shot_selection -0.05, discipline -0.10, decide_max -0.05 |
| `physical` | Finish every check, lift every stick. | aggression +0.15, discipline -0.05 |
| `trap` | Clog the neutral zone, sit on leads. | discipline +0.12, anticipation +0.08, dash_use -0.10, aggression -0.05 |
| `possession` | Keep the puck, make the extra pass, wait for a lane. | vision +0.12, shot_selection +0.10, decide_min +0.05 |
| `dump_and_chase` | Chip it deep, go get it, grind the corners. | vision -0.08, aggression +0.08, dash_use +0.08 |
| `shoot_everything` | Any angle, any distance, right now. | shot_selection -0.15, decide_max -0.10 |
| `goalie_dependent` | A great goalie behind a so-so team. | goalie_reaction -0.12, goalie_positioning +0.12, discipline -0.05 |

`goalie_reaction` is a multiplier where lower is faster, so a negative nudge makes the goalie quicker.

## Beer League D: Valley Beer League, D Division

Beginner beer league. Late ice at the Millbrook Community Arena, mismatched socks, and a scoreboard that only works on one side. Nobody is good and everybody is having a nice time, except during the Toothbrush Incident games.

Divisions: Early Ice, Late Ice. Named for the 9:30 pm and 11:15 pm ice slots. Purely for the standings page.

| Club | Short | Town | Home rink | Colours | Founded | Sponsor or owner | Style |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Wobbly Pops | WOB | Millbrook | Millbrook Community Arena | `#d98a1c` `#2b2b2b` `#f2e6c8` | 2019 | The Wobbly Pop Tap & Grill, Millbrook Main Street | `swarm` |
| Millbrook Molars | MOL | Millbrook | Millbrook Community Arena | `#f4f4f4` `#3fa7d6` `#e8452c` | 2015 | Haverkamp Family Dentistry | `possession` |
| Moose Knuckles | MKN | Millbrook | Millbrook Community Arena | `#7a4a26` `#f2d16b` | 2024 | Millbrook Legion Hall, Branch 112 | `run_and_gun` |
| Ice Holes | ICE | Millbrook | Millbrook Community Arena | `#a4161a` `#f2f2f2` `#1b1b1b` | 2008 | Hat Trick Tavern | `shoot_everything` |
| Pallbearers | PAL | Harlow Falls | Millbrook Community Arena | `#1b1b1b` `#7b3fa0` `#c0c0c0` | 2012 | Gilchrist & Sons Funeral Home ("We'll be the last to let you down") | `goalie_dependent` |
| Flood Crew | FLD | Millbrook | Millbrook Community Arena | `#3c8d4e` `#f2f2e9` | 1983 | Millbrook Parks & Recreation (owner of the rink) | `dump_and_chase` |
| Frozen Assets | FRA | Millbrook | Millbrook Community Arena | `#7fb3d5` `#0b2545` `#b0b7bf` | 2017 | Frostbank, Millbrook branch ("Banking With a Cool Head") | `trap` |
| Puckheads (expansion) | PZA | Millbrook | Millbrook Community Arena | `#c1272d` `#f7c548` `#8b5a2b` | 2026 | Puckhead Pizza, Millbrook ("Delivered in Under Two Periods") | `swarm` |

- **Wobbly Pops.** Dads who learned to skate the same winter their kids did, and refuse to be outdone by a nine-year-old. Notable: Gary Pruett (captain, centre). Learned to stop last February and now does it at every opportunity, preferably in front of the bench.
- **Millbrook Molars.** Four dentists, a hygienist and two patients who could not say no. They hand out toothbrushes in the handshake line. Notable: Dr. Lyle Haverkamp (owner, defence). Lectures everyone about mouthguards and has never once worn one. Style: They pass constantly because nobody wants to get hit in the hands.
- **Moose Knuckles.** The 1994 Millbrook Midget AA team, back together for one more run. They were very good in 1994. Notable: Rick 'Sauce' Saucier (right wing). Scored 61 goals in 1994 and has told 61 stories about it since. Gassed by the second period.
- **Ice Holes.** They play for the postgame. The pitcher is pre-ordered for 10:45 and the hockey is in the way. Notable: Dwayne Kuzyk (left wing, social convenor). Has never missed a postgame and has missed eleven games. Style: Every shot is one step closer to the bar.
- **Pallbearers.** Quiet, punctual, unfailingly polite. They arrive in the second hearse. Notable: Morley Gilchrist III (goalie). The steadiest hands in the valley, which he says comes with the job. Nobody asks which part.
- **Flood Crew.** The rink staff, on their own ice after hours. They know every soft spot and every dead board. Notable: Earl Bratt (head icemaker since 1983, defence). Drives Doris, the 1974 Zambelli, and will not hear a word against her. Uses the Millbrook bank, the dead spot behind the net that Ronnie Haverstock made famous, better than anyone alive except Ronnie.
- **Frozen Assets.** Tellers, a loans officer and the branch manager. They protect a one-goal lead like an overdraft. Notable: Colin Nolan (branch manager, coach). Changes lines with a laminated spreadsheet and charges a late fee for missed shifts.
- **Puckheads.** Brand new: the delivery drivers from the Millbrook Puckhead, who signed up on a dare. Half of them borrowed their skates. Notable: Gino Russo Jr. (goalie, night manager). Plays in a mask painted like a pepperoni puck. Has delivered to the rink between periods, which the league has asked him to stop.

## Beer League C: Valley Beer League, C Division

Intermediate beer league, still at Millbrook. People keep score here, and some of them keep grudges. Sponsors come from all over the valley, which is how a Kessler truck dealer and a Port Ainsley muffler shop ended up fighting a billboard war on Millbrook ice.

Divisions: Tuesday, Thursday. Named for the nights the teams usually play.

| Club | Short | Town | Home rink | Colours | Founded | Sponsor or owner | Style |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Sin Bin Brewers | SBB | Harlow Falls | Millbrook Community Arena | `#7a3e1d` `#f0e0c0` | 2016 | Sin Bin Brewpub, Harlow Falls | `physical` |
| Big Gord's Haulers | BGH | Kessler | Millbrook Community Arena | `#c0c4c8` `#d7261e` `#1b1b1b` | 1991 | Big Gord's Trucks ("Big Gord Won't Let You Walk") | `dump_and_chase` |
| Plungers | PLU | Millbrook | Millbrook Community Arena | `#d7263d` `#2b6cb0` `#ffffff` | 2004 | Duffy Bros. Plumbing & Heating ("Number one in the number two business") | `trap` |
| Millbrook Mallards | MAL | Millbrook | Millbrook Community Arena | `#2e7d4f` `#ffffff` `#c9a227` | 1989 | Millbrook Dairy (Ronnie Haverstock's old employer) | `possession` |
| Cold Ones (expansion) | CLD | Millbrook | Millbrook Community Arena | `#1f4d2b` `#e0a526` `#ffffff` | 2021 | Moosebrew Lager | `shoot_everything` |
| Brokenbone Adjusters | ADJ | Harlow Falls | Millbrook Community Arena | `#1c4e80` `#f2f2f2` `#6c4f8c` | 2010 | Brokenbone Mutual Insurance ("We've Seen Your Slapshot") | `possession` |
| Night Owls | OWL | Harlow Falls | Millbrook Community Arena | `#f28db2` `#6f3b1f` `#fff4e0` | 2013 | Double-Double Donuts, Harlow Falls (open 24 hours) | `run_and_gun` |
| Maple Tire Retreads | RTR | Port Ainsley | Millbrook Community Arena | `#222222` `#ffffff` `#b22222` | 1996 | Maple Tire & Muffler, Port Ainsley branch ("We Fix What Winter Breaks") | `goalie_dependent` |
| Kessler Overdues (expansion) | OVD | Kessler | Millbrook Community Arena | `#6a1b2a` `#e8dcc0` | 2026 | Friends of the Kessler Public Library | `physical` |

- **Sin Bin Brewers.** Craft beer people. Every beer on the tap list is named after a penalty, and they have earned all of them. Notable: Cody Lindqvist (brewmaster, defence). Leads the division in penalty minutes, almost all of them for explaining the rulebook to referees.
- **Big Gord's Haulers.** Big Gord owns the team, picks the lines and plays defence. The roster is whoever is on the lot that week. Notable: Gordon 'Big Gord' Halvorsen (owner, defence, age 71). Has sold trucks from the same lot outside Kessler since 1977 and stars in every advert, shouting from a truck bed. Insists on being on the ice for every power play, and shouts from there too.
- **Plungers.** Hot-and-cold split jerseys, like the taps. The best-organised team in C, until someone gets an emergency call mid-game. Notable: Terry Duffy (centre). Still carries a pager. It goes off about once a game, usually on a breakaway. Style: They know a thing or two about clogs.
- **Millbrook Mallards.** The most famous beer league team in hockey. During the 2005 lockout they wrote to the Puckworth Cup trustees asking to be considered, and the Cup came to Millbrook for a night. The photo hangs in the lobby; the players have aged, the handwriting has not. Notable: Larry Piche (snowplough driver, captain). Wrote the 2005 letter in his neat handwriting and has sent the trustees a polite follow-up every March since. Has never received a reply and considers this encouraging. Style: Twenty years together. They know where everyone will be, which helps, because nobody can get there quickly.
- **Cold Ones.** Twentysomethings who are sure they are one call away from Senior. They warm up with music on a speaker. Notable: Tyler Brandt (captain, right wing). Played half a season of Junior B in 2017 and brings it up in every handshake line. Style: Every rush ends with a slapshot from the blue line, because Tyler saw it on TV.
- **Brokenbone Adjusters.** Insurance adjusters who know exactly what every injury costs and play accordingly. They file incident reports on hits. Notable: Doug Peterson (claims manager, defence). Has denied two of his own teammates' claims, citing pre-existing conditions (being in the beer league). Style: Risk-averse. Never makes a pass that is not fully covered.
- **Night Owls.** Overnight bakers, two night nurses and a hospital porter. At 11:15 pm they are wide awake and everyone else is not. Notable: Shauna Reid (night nurse, centre). The fastest skater in the division. Plays every shift like it is a code blue and brings day-old crullers for the refs.
- **Maple Tire Retreads.** Nobody under 45. Every knee has been rebuilt at least once, and the goalie is the reason they still win. Notable: Wally Dumont (goalie, age 58). Played two games of Senior for Kessler in 1989. Has stopped everything since and still has the Kessler socks.
- **Kessler Overdues.** Librarians. Polite off the ice and the dirtiest team in the valley on it. Shhh. Notable: Marion Fischer (head librarian, defence). Has never issued a fine she did not collect, on or off the ice.

## Beer League A: Valley Beer League, A Division

The top beer division, played on both sheets at Harlow Falls Municipal. Ex-college players, ex-junior players, and grudges that predate some of the players. This is the first time you play somewhere other than home. Emergency Mo Teague played here on Wednesdays before he won the Puckworth Cup, so every A Division goalie quietly believes he is next.

Divisions: Pad 1, Pad 2. Named for the two sheets at Harlow Falls Municipal.

| Club | Short | Town | Home rink | Colours | Founded | Sponsor or owner | Style |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Slapshot Saloon | SLS | Harlow Falls | Harlow Falls Municipal Twin Pad | `#4a2c1a` `#f5deb3` `#8b0000` | 2002 | Slapshot Saloon, Harlow Falls | `possession` |
| Hydro Linemen | HYD | Harlow Falls | Harlow Falls Municipal Twin Pad | `#ffd23f` `#174a7c` | 1979 | Harlow Falls Hydro, Local 6 social committee | `physical` |
| Rink Rage Bombers | RRB | Harlow Falls | Harlow Falls Municipal Twin Pad | `#a4e000` `#0d0d0d` `#1e90ff` | 2020 | Rink Rage energy drink ("Taste the Penalty") | `run_and_gun` |
| Splinter Group | SPL | Harlow Falls | Harlow Falls Municipal Twin Pad | `#4b2e83` `#e5c75e` | 2017 | Lou's Second Pint, directly across the street from the Slapshot Saloon | `shoot_everything` |
| Backcrackers | BCK | Harlow Falls | Harlow Falls Municipal Twin Pad | `#0e6b6b` `#f2f2f2` | 2011 | Kerr Family Chiropractic | `trap` |
| Smoke Eaters | SMK | Kessler | Harlow Falls Municipal Twin Pad | `#c8102e` `#f2f2f2` `#1b1b1b` | 1988 | Kessler Volunteer Fire Department; jersey sponsor Hearthstone Furnaces ("Warm Homes. Cold Ice.") | `dump_and_chase` |
| Walleyes | WAL | Port Ainsley | Harlow Falls Municipal Twin Pad | `#5a7d2a` `#f2c75c` | 2009 | Lakeside Bait & Tackle, Port Ainsley | `goalie_dependent` |
| Rusty Blades | RUS | Harlow Falls | Harlow Falls Municipal Twin Pad | `#a6542b` `#2b2b2b` `#d9d9d9` | 1999 | The Rusty Blade Pub, Harlow Falls | `possession` |

- **Slapshot Saloon.** The best bar team in the valley. They recruit ex-college players with the promise of free wings for life. Notable: Brett Kowalski (centre). Played four years of small-college hockey and mentions it before, during and after every game.
- **Hydro Linemen.** Power linemen who climb poles in January blizzards. A bodycheck is a nice break for them. Notable: Dale 'Transformer' Hughes (defence). Six foot five, kind to animals, has knocked two opponents through the old Pad 2 gate.
- **Rink Rage Bombers.** The sponsorship is a cooler of a drink nobody over thirty should touch. They are very, very fast for exactly forty minutes. Notable: Jordan 'Jolt' Pelletier (left wing). Has had a can between every period since 2021. Has not, as far as anyone knows, slept.
- **Splinter Group.** Formed when half the Slapshot Saloon roster quit over who paid for a pitcher. They have been angry for eight years. Notable: Mike Barrett (captain, right wing). Is still owed $14.50 and keeps the receipt in his helmet.
- **Backcrackers.** Run by a chiropractor whose business plan is to fix opponents' backs after the game, for a fee. Notable: Dr. Shane Kerr (defence). Adjusts his own neck on the bench between shifts. The sound carries.
- **Smoke Eaters.** Volunteer firefighters. Famous for the postgame chili, and for leaving mid-period when the pagers go off. Notable: Captain Doug Ellis (fire chief, centre). Once took a faceoff in full turnout gear after a call. Won it.
- **Walleyes.** Ice fishermen and lake guides. The bus smells of minnows and the goalie is unbeatable on a good day. Notable: Anton Ruutu (goalie, owns the bait shop). Came from Finland for one exchange semester in 2009 and never left. Says the valley reminds him of home, but with worse coffee.
- **Rusty Blades.** The dynasty. Five straight A Division titles, a roster of ex-junior players and a trophy case in the pub's washroom hallway. Notable: Dale Fraser (playing coach). Still wears his 1992 Junior C ring under his glove. Treats the A Division like the Olympics.

## Senior AAA: Northern Senior Hockey Association

Proper town clubs with boards of directors, history books and rinks that smell like eighty winters. The NSHA is where the valley's towns settle their arguments. Five clubs are on the valley road; three (Tollbridge, Sainte-Odile, Carver's Gap) sit just beyond it.

Divisions: Mill Division, Lake Division. Valley-road towns against the lakeside and up-the-pass towns.

| Club | Short | Town | Home rink | Colours | Founded | Sponsor or owner | Style |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Kessler Millmen | KES | Kessler | Kessler Memorial Arena (the Barn) | `#143d29` `#f0e6d0` `#c0c0c0` | 1921 | Community-owned; jersey sponsor Kessler Pulp & Paper | `physical` |
| Millbrook Lumber Kings | MLK | Millbrook | Millbrook Community Arena | `#b22222` `#1b1b1b` `#f2f2f2` | 1952 | Volunteer board; jersey sponsor Grizzly Gas & Go | `dump_and_chase` |
| Harlow Falls Huskies | HFH | Harlow Falls | Harlow Falls Municipal Twin Pad | `#7a8288` `#ffffff` `#1b2a4a` | 1964 | Frostbank | `possession` |
| Port Ainsley Lakers | PAK | Port Ainsley | Port Ainsley Lakeside Arena | `#1c5fa8` `#ffffff` | 1930 | Port Ainsley Marina & Boat Storage | `run_and_gun` |
| Duncannon Foundry | DFO | Duncannon | Duncannon Memorial Gardens | `#8c3b1a` `#1b1b1b` | 1946 | Duncannon Iron Works retirees' association | `trap` |
| Tollbridge Coal Kings | TCK | Tollbridge | Tollbridge Coliseum | `#1b1b1b` `#e0a526` | 1934 | Tollbridge Rail & Coal | `physical` |
| Sainte-Odile Castors | STO | Sainte-Odile | Arena Sainte-Odile | `#0e6b6b` `#f2f2f2` `#c8a24a` | 1928 | Caisse populaire de Sainte-Odile | `possession` |
| Carver's Gap Ravens | CGR | Carver's Gap | The Gap Rink | `#4b2e83` `#e5c75e` | 1959 | Gap Pass Ski Hill | `goalie_dependent` |

- **Kessler Millmen.** The oldest club in the north and the loudest building. Eleven Aldous Cups, wooden trusses, standing room, and the smell of the mill when the wind is wrong. Notable: Hap Doyle (head coach since 1988). Seventy-one years old. Has been photographed smiling once, in 1996, and denies it.
- **Millbrook Lumber Kings.** Your home town's senior club, in buffalo-plaid jerseys. Last Aldous Cup in 1979. Crowds rise and fall with the state of the Community Arena. Notable: Old Pete Vachon (equipment manager and club historian). Has sharpened every Lumber King's skates since 1971 and keeps the 1979 Cup photo in the skate sharpener's drawer. Hook: When the user renovates Millbrook Community Arena, the Lumber Kings' attendance and morale can rise with it.
- **Harlow Falls Huskies.** Tidy, well-run and slightly smug. The best minor hockey system in the valley feeds them, and they will tell you so in their newsletter. Notable: Brendan Quinn (general manager). Wears a tie behind the bench. Has a five-year plan, laminated.
- **Port Ainsley Lakers.** Fishing-town club. Every February they play one home game outdoors on the frozen lake, and the fans throw a frozen pike after the first goal. Notable: Big Nils Olsen (captain, defence). Six foot six ice fisherman. Hauls his own ice hut to the Pond Classic and sells coffee out of it at intermission.
- **Duncannon Foundry.** The city's original team, in the 1949 downtown Gardens the council keeps trying to demolish. The pro Dukes shared the building until 2009, then left for the Frostbank Centre, and the Foundry have not forgiven them. Notable: Marc Leclerc (goalie and city councillor). Has filibustered the Gardens demolition vote three times. Plays the same way.
- **Tollbridge Coal Kings.** A rail junction town past the east end of the valley. The Coliseum seats 1,100 and they have sold it out for every playoff game since 1971. Notable: Wade 'The Toll' Tkachuk (enforcer, left wing). Collects the toll from anyone who crosses the crease. Works as a crossing guard on weekdays and is lovely with children.
- **Sainte-Odile Castors.** A French-speaking lake village with the most skilled team in Senior. They pass the puck like it belongs to them and sing on the bench. Notable: Father Marc Gagnon (head coach and parish priest). Blesses the sticks before every game. Has received three bench minors for language, which he says were in Latin.
- **Carver's Gap Ravens.** Up the mountain pass, two hours by bus when the road is open. The rink is a Quonset hut and visiting teams swear the air is thinner. Notable: Petr Novak (goalie, age 39). Came for a ski instructor job in 2004. Still the best goalie in Senior, and the only reason the Ravens make the playoffs.

## Semi-Pro: Interlake Hockey League

City clubs with mascots, owners with opinions, and pay that covers gas and a meal. Port Ainsley is the valley's member; the rest are lake, port and rail cities beyond the valley, reached by the Gas Can Express.

Divisions: Lakeshore Division, Rail Division. Lake and port towns against the inland rail and mining cities.

| Club | Short | Town | Home rink | Colours | Founded | Sponsor or owner | Mascot | Style |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Port Ainsley Sturgeon | PAS | Port Ainsley | Port Ainsley Lakeside Arena | `#00205b` `#a2aaad` | 1979 | Owned by Marlene Fisk, Fisk Marine & Outboard | Sturgie, a seven-foot fish with unsettling eyes | `trap` |
| Carrick Junction Rail Barons | CJR | Carrick Junction | Union Yard Arena | `#e04e39` `#1b1b1b` `#f2f2f2` | 1979 | Founding member; owned by the Carrick Junction Railway Heritage Society | Conductor Cal, who blows a train whistle after every goal and most icings | `dump_and_chase` |
| Ellery Smelters | ELS | Ellery | Ellery Civic Centre (the Pit) | `#8b0000` `#a5acaf` | 1990 | Ellery Nickel Refinery | Slag, a soot-covered furnace worker in a hard hat | `physical` |
| Cold Harbour Stingrays | CHS | Cold Harbour | Cold Harbour Waterfront Arena | `#00718f` `#f3c300` | 2003 | Owned by the Cold Harbour Aquarium | Ray Charge, a stingray in a lifeguard whistle | `run_and_gun` |
| Wexford Ice Dogs | WID | Wexford | Kibble King Pet Foods Arena | `#1c1c1c` `#9bd0ff` | 2008 | Owned by Kibble King Pet Foods | Biscuit, a husky in a goalie mask | `shoot_everything` |
| Wendover Scholars | WEN | Wendover | Wendover College Arena (the Pond) | `#1d4f2b` `#f2c75c` | 1994 | Operated with Wendover College | Professor Puck, an owl in a mortarboard | `possession` |
| Fort Kinnear Timberwolves | FKT | Fort Kinnear | Fort Kinnear Forestry Arena (the Kennel) | `#6d6f73` `#f2f2f2` `#1b1b1b` | 1992 | Kinnear Forest Products | Lobo, a grey wolf with a lumberjack's axe (foam) | `goalie_dependent` |
| Snowden Blizzard | SNB | Snowden | Snowden Dome | `#6caddf` `#ffffff` | 2001 | Owned by the City of Snowden tourism board | Flurry, a snowman with a hockey stick for an arm | `run_and_gun` |
| Galloway Outlaws | GAL | Galloway | Honest Abe's Auto Plaza Arena | `#3d2817` `#d4a017` `#f2e6c8` | 2011 | Owned by 'Honest' Abe Larsen, Honest Abe's Auto Plaza | Sheriff Deals, a cowboy with a foam megaphone | `physical` |

- **Port Ainsley Sturgeon.** The lake's own pro-ish team, sharing the Lakeside Arena with the senior Lakers and playing a careful, grinding game in front of 2,200 people in toques. Their 1983 goalie delivered pizzas between games and founded Puckhead Pizza. Notable: Coach Dmitri Volkov (head coach). Former minor pro defenceman who settled here for the fishing. Preaches structure in a voice that never goes above a murmur.
- **Carrick Junction Rail Barons.** A railway city that founded the league. Their rink is a converted locomotive shed, and the goal horn is an actual train horn. Notable: Kyle Sullivan (captain, centre). Drives a freight train four days a week. Has never been late to a game, which he credits to timetables.
- **Ellery Smelters.** A mining and smelting city that likes its hockey the way it likes its work: hot, heavy and loud. The Pit is the most hostile building in the league. Notable: Derek 'Anvil' Morrow (defence). Leads the league in hits and has never apologised for one. Runs a very popular knitting circle in the off-season.
- **Cold Harbour Stingrays.** A port city named by people who were honest about the weather, with a team named after a warm-water fish by a marketing committee. Notable: Felix Dubois (right wing). League scoring leader two years running. Signs autographs at the aquarium's touch tank on Sundays.
- **Wexford Ice Dogs.** Owned by a dog-food company, so every promotion night is a dog night. Dogs welcome in section 104. Section 104 is never quiet. Notable: Riley Campbell (centre). Shoots from anywhere because the owner pays a bonus per shot on goal. The owner has not reconsidered.
- **Wendover Scholars.** A college town team stocked with grad students and former varsity players. Smart, patient and slightly insufferable. Notable: Evan Lindqvist (defence, PhD candidate). Writing a thesis on the physics of the wrist shot. Corrects the play-by-play announcer on his own time.
- **Fort Kinnear Timberwolves.** Forestry town at the end of the rail line. The skaters are honest and slow; the goalie is a local legend. Notable: Jean-Paul 'Le Mur' Roy (goalie, age 36). Turned down two minor pro contracts to stay near his trapline. The Kennel chants 'MUR' after every save.
- **Snowden Blizzard.** The snowiest city in the north, according to a sign at the city limit. Their arena is a dome that leaks snowmelt onto the visitors' bench. Notable: Sasha Ivanov (left wing). Fastest skater in the league. Once beat the team bus home on cross-country skis.
- **Galloway Outlaws.** Owned by a used-car dealer who appears on the video board between every period. They play like they have something to sell. Notable: Honest Abe Larsen (owner). Has traded players for cars, twice. One of the cars was better.

## Minor League Pro: Continental Hockey Association

Real professionals one phone call from the GNHL. Every club is a development affiliate of a GNHL parent. The Duncannon Dukes, the Kingsport Monarchs' affiliate, are the valley's own, and their Frostbank Centre is the benchmark for what a renovated rink looks like. Parent clubs come from the GNHL canon in `canon.json`; Bramford and Redstone are the two GNHL clubs without a CHA affiliate (they can be said to run theirs out west).

Divisions: Timber Division, Iron Division. Northern and forestry cities against the steel and port cities.

| Club | Short | Town | Home rink | Colours | Founded | Sponsor or owner | Mascot | Style | GNHL parent |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Duncannon Dukes | DUN | Duncannon | Frostbank Centre | `#4b2a7b` `#e3b23c` `#f4f1e8` | 1972 | Owned by Frostbank Sports & Entertainment | His Grace, a moose in a velvet cape and a small crown (the big crown is Kingsport's) | `possession` | Kingsport Monarchs (`kgm`) |
| Halverton Northmen | HAL | Halverton | Halverton Coliseum | `#0038a8` `#ffffff` `#c8102e` | 1951 | Owned by the Halverton Sports Commission | Big Olaf, a bearded giant with a foam axe | `trap` | Fairhaven Squalls (`fhs`) |
| Ravensport Breakers | RAV | Ravensport | Harbourfront Centre | `#f2f2f2` `#006d75` `#ff6a13` | 1977 | Owned by the Ravensport Port Authority | Bosun, a seagull in a sou'wester | `run_and_gun` | Marrow Bay Gulls (`mbg`) |
| Marchmont Voyageurs | MAR | Marchmont | Marchmont Portage Arena | `#2e6b3a` `#e8d5a8` `#7a1f1f` | 1956 | Owned by a fan co-operative of 4,000 shareholders | Pierre le Pagayeur, a voyageur with a canoe paddle | `dump_and_chase` | Ste-Colette Coureurs (`scc`) |
| Tamarack Kodiaks | TAM | Tamarack | Tamarack Credit Union Place | `#4f2c1d` `#f4a900` | 1983 | Owned by Tamarack Credit Union | Cubby, a bear who has been in the same suit since 1983 | `physical` | Northgate Foresters (`ngf`) |
| Ashcombe Elk | ASH | Ashcombe | Ashcombe Antler Arena | `#041e42` `#b9975b` | 1962 | Owned by the Ashcombe Hunting & Angling Club | Bugle, an elk whose antlers do not fit through the tunnel | `goalie_dependent` | Granite City Stonecutters (`gcs`) |
| Fenwick Firebirds | FEN | Fenwick | Fenwick Rink Rage Arena | `#f74902` `#1b1b1b` | 1999 | Owned by Rink Rage Beverage Co. since 2011 | Phoenix Phil, who is set on (fake) fire during introductions | `shoot_everything` | Silverton Specters (`sil`) |
| St. Brendan Friars | SBF | St. Brendan | The Abbey | `#1b1b1b` `#ffffff` `#c8102e` | 1938 | Owned by the St. Brendan Abbey Brewery | Brother Puck, a monk in a helmet | `trap` | Lake Ostrander Loons (`ost`) |
| Belle Rive Riptide | BRR | Belle Rive | Belle Rive Splash Centre | `#2ec4b6` `#5b2a86` | 1996 | Owned by the Belle Rive Waterpark Group | Splash, a wave with sunglasses | `run_and_gun` | Sunvale Scorpions (`sun`) |

- **Duncannon Dukes.** The valley's top club and the Kingsport Monarchs' affiliate: one step below monarchs, which is where Kingsport thinks everyone belongs. 5,000 seats since the 2009 move out of the old Gardens, a TeleNorth video board, and a 50/50 draw that once paid for a house. Every renovation you plan is measured against this building. Notable: Lorne Pettigrew (general manager). Keeper of the red rotary phone on his desk, which rings only when Kingsport wants a player. Nobody else in Duncannon is allowed to touch it. Barry 'Suitcase' Pomeroy's seven stints here are on the wall behind it.
- **Halverton Northmen.** A founding member with seven Callahan Shields and a building full of banners. They expect to win and get grumpy when they do not. Notable: Coach Bruce Walsh (head coach). Coached in the GNHL for eleven games in 2014. It ended badly. He would like to go back.
- **Ravensport Breakers.** A big port city that comes alive for hockey. The waterfront arena shakes when the ships blow their horns. Notable: Connor Murphy (defence). Twenty-year-old prospect with the hardest shot in the league. The GNHL scouts sit in row F.
- **Marchmont Voyageurs.** The fan-owned club. Shareholder meetings are louder than the games, and the games are very loud. Notable: Nick Savard (left wing, fan-voted captain). Elected captain by 4,000 shareholders after a campaign that included lawn signs.
- **Tamarack Kodiaks.** A northern forestry city that builds big, heavy, slow-to-anger teams, like their parent club in Northgate. Kodiak, the skate maker, has sent a cease-and-desist letter every year since 1983; the club replies with season tickets. Notable: Josh Kerr (right wing, enforcer). Six foot four, a lumber grader by trade. Reads to schoolchildren every Tuesday and fights someone every Saturday.
- **Ashcombe Elk.** A quiet, rich town that plays a quiet, careful game. Their goalie steals games they have no business winning. Notable: Mats Holmstrom (goalie). Thirty-four, Swedish, studies opposing shooters on a tablet between periods. Says very little and stops a lot.
- **Fenwick Firebirds.** The energy drink's flagship team. Pyrotechnics, a DJ, and a playing style best described as caffeinated. Notable: Jake Brodeur (centre). Has the league's best hands and worst haircut, both paid for by the sponsor.
- **St. Brendan Friars.** Born from a monastery's brewery team. The arena is called the Abbey, the organ plays hymns at faceoffs, and the system is pure discipline. The monks also pray, nightly, for their cursed parent club in Lake Ostrander. Notable: Brother Anselm (assistant coach, actual monk). Runs the penalty kill. Has taken a vow of silence that he breaks only to yell at linesmen.
- **Belle Rive Riptide.** A 1996 expansion team, signed up three years after its desert parent club in Sunvale, that has never changed its teal-and-purple jerseys, and never will. Their arena has a lazy river behind section 12. Notable: Ilya Petrov (right wing). Former GNHL first-round pick on his third comeback. Absurdly talented on the nights he is interested.

## Rivalries

| Rivalry | Clubs | Tiers | Since |
| --- | --- | --- | --- |
| The Mill and the Lake | Kessler Millmen vs Port Ainsley Lakers | Senior AAA | 1931 |
| The $14.50 Feud | Slapshot Saloon vs Splinter Group | Beer League A | 2017 |
| The Gardens Grudge | Duncannon Foundry vs Duncannon Dukes | Senior AAA, Minor League Pro | 2009 |
| The Valley Cup | Port Ainsley Sturgeon vs Duncannon Dukes | Semi-Pro, Minor League Pro | 2010 |
| The Billboard War | Big Gord's Haulers vs Maple Tire Retreads | Beer League C | 1996 |
| The Toothbrush Incident | Millbrook Molars vs Moose Knuckles | Beer League D | 2024 |

**The Mill and the Lake.** The oldest feud in the north. In the 1962 final at the Pond Classic a Kessler defenceman fell through soft ice by the boards, the Aldous Cup went in after him, and Port Ainsley won the replay. Kessler says the Lakers cut the ice. Port Ainsley fans have thrown a frozen pike onto the ice after the first goal of every meeting since, and Kessler fans throw back a roll of paper towel.

**The $14.50 Feud.** Two bars across the street from each other. Half the Saloon's roster walked out over an unpaid pitcher and founded the Splinter Group at Lou's Second Pint. The $14.50 has never been repaid; the receipt is in Mike Barrett's helmet. Both bars run a drink special on game night named after the other team's captain.

**The Gardens Grudge.** When the Frostbank Centre opened, the Dukes walked out of the Memorial Gardens they had shared with the Foundry since 1972, and took the Saturday nights, half the crowd and the city's attention with them. The Foundry were left alone in a half-empty 1949 barn the council keeps trying to knock down. They never play each other, so the rivalry runs through council meetings, letters to the Duncannon Daily Ledger and a charity alumni game every March that the Foundry treats as a cup final.

**The Valley Cup.** A September preseason exhibition between the two biggest clubs in the valley. The Dukes treat it as a practice. The Sturgeon treat it as their Puckworth Cup final, and have won it three times, which the Port Ainsley paper has never stopped printing.

**The Billboard War.** Big Gord's Trucks and Maple Tire & Muffler have fought over the same valley billboards for thirty years. The bosses settle it on the ice twice a season, and the loser has to run the winner's ad on their own sign for a month.

**The Toothbrush Incident.** In the Moose Knuckles' first comeback game, Rick Saucier lost a front tooth to a Molars stick. Dr. Haverkamp fixed it the next morning and sent the bill. Saucier has not paid it, the Molars bring it to every game, and the Moose Knuckles now refuse the toothbrushes in the handshake line.

Two of these cross tiers, which matters for the career: the Gardens Grudge means a Duncannon Foundry player who makes the Dukes has some explaining to do at the Foundry's bar, and the Valley Cup gives a Semi-Pro season one game against a Minor League Pro club.

## How promotion feels

Moving up should feel like the valley noticing you. Each step has a scout, a way of getting to away games, and a headline in a local paper.

| Step | Who notices | How you get there | The headline |
| --- | --- | --- | --- |
| Beer League D to Beer League C | Nobody. The C Division captain who saw you at late ice asks if you are free Thursdays. | Your own car. The heater works if you hit the dash. | Clarion, page 7: 'Local Skater Moves Up to C; Mother Says She Always Knew' |
| Beer League C to Beer League A | The Rusty Blades' playing coach, watching from behind the glass with a coffee and a notebook. | Carpool to Harlow Falls, the first real away rink. | Harlow Falls Herald: 'Millbrook Newcomer Heads to A Division, Grudges Await' |
| Beer League A to Senior AAA | Hap Doyle's nephew, in a Millmen jacket, who never takes notes and never needs to. A letter arrives on Kessler letterhead. | The rented yellow school bus, which has a Senior team on it and smells like it. | Kessler Courier: 'Beer Leaguer Invited to Millmen Camp; Doyle: "We'll See"' |
| Senior AAA to Semi-Pro | A man in an ILHL windbreaker with a clipboard and a stopwatch, who drives four hours to see one shift. | A coach bus nicknamed the Gas Can Express. You get gas money and a meal per diem of $11. | Port Ainsley Lakesider: 'Senior Standout Signs Semi-Pro Deal (Gas Money Included)' |
| Semi-Pro to Minor League Pro | A CHA scout with a laminated lanyard and a GNHL parent club logo on his tablet. In the valley it might be Ronnie Haverstock himself, who hands you the Dukes' phone number after the Thursday old-timers' game. | Charter coach with wifi that never works, hotel rooms with a roommate. | Duncannon Daily Ledger, front of sports: 'From Late Ice to the Dukes: Valley's Own Gets the Call' |
| Minor League Pro to GNHL | The phone call. In Duncannon it is the red rotary phone on Lorne Pettigrew's desk, ringing for Kingsport at 6:40 am. | A plane. Your first one with a team logo on the tail. | Every paper in the valley, front page: 'One of Ours in the Show' |

**The papers.**

- *The Millbrook Clarion* (Millbrook). Weekly, eight pages, beer league scores printed next to the church bake sale.
- *The Harlow Falls Herald* (Harlow Falls). Twice weekly. Very proud of its A Division standings box.
- *The Kessler Courier* (Kessler). Has covered the Millmen since 1921 and has never once been neutral.
- *The Port Ainsley Lakesider* (Port Ainsley). Fishing reports, ice thickness, and the Sturgeon.
- *The Duncannon Daily Ledger* (Duncannon). The valley's only daily, with a real sports section and a columnist who hates everything.

**The radio.** CKVL 1340 Valley Radio. Carries Lumber Kings and Millmen games. Play-by-play by Bernie Szabo, who has called every Kessler home game since 1985 and still pronounces it three different ways.

**Going back down.** Getting cut at a tryout or released is handled kindly by the world: your old team welcomes you back, the Clarion runs 'Back Where He Belongs', and the postgame pitcher is on the house.

These lines fit the existing `_news()` feed in `career.gd`: signing, tryout invitations and scoring titles can pick the paper of the town the club plays in.

## Towns and rinks beyond the valley

The five valley towns host every Beer League club and five of the eight Senior clubs. Everything else is in towns and cities beyond the valley road. These are new names for the World thread to accept or rename; they can start as road exits on the region map (a destination with a travel time and a rink, no walkable scene).

| Rink | Town | On the valley map |
| --- | --- | --- |
| Millbrook Community Arena (`millbrook_community_arena`) | Millbrook | yes |
| Harlow Falls Municipal Twin Pad (`harlow_falls_municipal`) | Harlow Falls | yes |
| Kessler Memorial Arena (the Barn) (`kessler_barn`) | Kessler | yes |
| Port Ainsley Lakeside Arena (`port_ainsley_lakeside`) | Port Ainsley | yes |
| Frostbank Centre (`duncannon_frostbank_centre`) | Duncannon | yes |
| Duncannon Memorial Gardens (`duncannon_memorial_gardens`) | Duncannon | yes |
| Tollbridge Coliseum (`tollbridge_coliseum`) | Tollbridge | no, beyond the valley |
| Arena Sainte-Odile (`sainte_odile_arena`) | Sainte-Odile | no, beyond the valley |
| The Gap Rink (`carvers_gap_rink`) | Carver's Gap | no, beyond the valley |
| Union Yard Arena (`carrick_union_yard`) | Carrick Junction | no, beyond the valley |
| Ellery Civic Centre (the Pit) (`ellery_smelter_pit`) | Ellery | no, beyond the valley |
| Cold Harbour Waterfront Arena (`cold_harbour_arena`) | Cold Harbour | no, beyond the valley |
| Kibble King Pet Foods Arena (`wexford_kibble_king`) | Wexford | no, beyond the valley |
| Wendover College Arena (the Pond) (`wendover_pond`) | Wendover | no, beyond the valley |
| Fort Kinnear Forestry Arena (the Kennel) (`fort_kinnear_kennel`) | Fort Kinnear | no, beyond the valley |
| Snowden Dome (`snowden_dome`) | Snowden | no, beyond the valley |
| Honest Abe's Auto Plaza Arena (`galloway_arena`) | Galloway | no, beyond the valley |
| Halverton Coliseum (`halverton_arena`) | Halverton | no, beyond the valley |
| Harbourfront Centre (`ravensport_arena`) | Ravensport | no, beyond the valley |
| Marchmont Portage Arena (`marchmont_arena`) | Marchmont | no, beyond the valley |
| Tamarack Credit Union Place (`tamarack_arena`) | Tamarack | no, beyond the valley |
| Ashcombe Antler Arena (`ashcombe_arena`) | Ashcombe | no, beyond the valley |
| Fenwick Rink Rage Arena (`fenwick_arena`) | Fenwick | no, beyond the valley |
| The Abbey (`st_brendan_arena`) | St. Brendan | no, beyond the valley |
| Belle Rive Splash Centre (`belle_rive_arena`) | Belle Rive | no, beyond the valley |

Duncannon gets a second rink, the 1949 Memorial Gardens, for the senior Foundry. It is the run-down counterpart to the Frostbank Centre and could reuse the Kessler barn kit.

## For the Mechanics thread

`names.gd` keeps its API. The suggestion is to load club data from a JSON file instead of the hard-coded `CLUBS` array:

1. Copy `teams.json` into the repo, for example `res://data/teams.json`, so it ships with the game.
2. In `Names`, load it once (a static cache) and keep `Names.clubs(tier)` returning the same shape it does today, `[name, primary, secondary]` per club, built from the first N non-expansion clubs of that tier in file order. Nothing that calls it breaks.
3. Add `Names.club_data(tier) -> Array[Dictionary]` for the full records, and use it in `career.gd` where the league is built (around the `Names.clubs(t)` loop) to set the new fields.
4. `Team` gains `key` (the string id, such as `nsha_kessler_millmen`), `town`, `home_rink`, `style`, and an optional third colour `tertiary`. `team.short` comes from the file instead of `name.left(3)` (which would give MIL for both the Millbrook Molars and the Millbrook Mallards, and POR for every Port Ainsley club). `to_dict` and `from_dict` should default the new fields so old saves still load.
5. Style on ice: `game.gd` already has `team_ai[team]` per side. A small `TierAI.with_style(tag)` that adds the style's `ai_delta` (clamped to 0..1, `decide_min` and `decide_max` kept positive) lets each club play its way: `team_ai[i] = TierAI.for_tier(tier).with_style(team.style)`.
6. Fixtures can read the home club's `home_rink` to know where a game is played, which is what `docs/WORLD.md` already asks for. Rink ids here are proposals for `region.gd`.
7. Divisions are cosmetic for now (a standings page grouping); playoffs can stay a single table.
8. Rivalry games are a possible later hook: the `rivalries` list names the clubs, so a fixture between them could get a crowd boost, an extra news line, or more aggression.
9. If `teams.json` is missing or broken, fall back to the current hard-coded lists so the game never boots without clubs.

## Open questions

- GNHL parents are linked by team id from `canon.json` (for example `kgm` for the Kingsport Monarchs). The parent pairings other than Duncannon and Kingsport are mine, chosen by theme (port to port, forestry to forestry, teal 1990s expansion to teal 1990s expansion); the GNHL writer may want to confirm them.
- The nineteen new towns beyond the valley (and the Gardens in Duncannon) need the World thread's blessing.
- Beer leagues are partly coed in the lore (Shauna Reid, Marion Fischer). The name pools in `names.gd` are all men's first names; worth a word with Mechanics if generated players should match.
