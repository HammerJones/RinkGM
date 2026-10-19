# Side quests and favours

Sean, 2026-10-18: everyone in the rink is a real character, and what they like to watch or play is part of who they are. These are the stories they bring to the owner. They sit beside the path stories in `PATHS.md` and never replace a path beat: they are the small, warm things that happen on a Tuesday while the big story waits.

The data is `data/world/quests.json` (the format in `PEOPLE.md` section 8) and one dialogue tree per quest in `data/world/dialogue/quests/<quest id>.json`. The people are in `data/world/cast.json`.

## How they're built

- **Every quest is rooted in an event or a corner of the rink.** Each event kind in `PEOPLE.md` section 2 has at least two quests. Rink-life quests carry `"event": "rink_life"` and a `theme` (the canteen, the plant room, Doris, the pro shop, the trophy case, lost and found, Gus's binder, renovations).
- **Cozy by default.** Rewards are relationships, keepsakes that appear in the building, flags that open later stories, a little money or ice reputation. Nothing is grindy and almost nothing can fail. The few quests with a time limit fail softly, with a small relationship dip and a line in the day log.
- **Branches are flags.** A choice the owner makes in dialogue sets a flag; a `flag` goal step waits for it, and the `complete` node shows a different line for each branch. Keepsake choices (the Moosebrew clock, the mural's third leg, the Section C letter, the brass strip) follow the keepsake rule in `DECOR.md`: keep, restore, or remove, and the town notices.
- **Dialogue entry nodes.** Each quest tree has `offer`, `progress` and `complete`, reached as `quest:<id>:<node>` from the giver's hub, plus a `done` node for the giver's main tree to use afterwards. The offer always has an accept, a polite decline, a question, and usually a cheeky answer, each with a relationship effect. `progress` shows options gated by the `step` condition, so the giver talks about the step you're on. `complete` is shown once, right after the quest finishes (the quest's `reward` is already applied by then), and its options add the branch effects.
- **Other people's lines.** When a step is a talk with someone other than the giver, that person's line arrives through the step's `on_done` effects (a `note` in the day log, an item, a flag), so the quest works even before their own tree knows about it.
- **`prompt`** is the owner's line that opens the offer from the giver's hub (`Conversation` reads it).
- **Favours** are templates any generated townsperson of an archetype can give: one at a time per person, each template once a fortnight. They use `ask` and `thanks` lines (with `{name}`, `{known_as}` and the usual tokens) and `"self"` for the giver in effects. Their goals avoid `talk`, because a template can't know who it will be given by.

## All the quests

| Quest | Giver | Event kind | Length | Reward |
| --- | --- | --- | --- | --- |
| Minus Three and a Half | Hélène Arsenault | Figure practice | medium, 4 steps | Relationship with Hélène, the 1975 carnival pin (trophy case keepsake), unlocks Fifty Carnivals. |
| Test Day | Josée Thibodeau | Figure show | short, 3 steps | Relationship with Josée and Carol, her passed test sheet on the notice board, a flag for her story. |
| Fifty Carnivals | Hélène Arsenault | Figure show | long (chain, after Minus Three and a Half), 4 steps | Relationship with Hélène, the spring show becomes yearly, $200 door share, a little ice reputation, the banner's place. |
| The Coffee Bench | Carol Thibodeau | Figure practice | medium, 4 steps | Relationship with Carol and Lorraine, the early canteen flag, the bench thermos. |
| Since Opening Night | Irene Dubois | Public skate | medium, 4 steps | Relationship with Irene and Doreen, her 1974 ticket stub as a keepsake you place. |
| One Song, Lights Down | Devon Marsh | Public skate | long, 5 steps | Relationship with Devon and Dylan, an engagement flag, a guestbook line, a lead for a Mezzanine Hall wedding booking. |
| The Mitten Tree | Dylan Pruitt | Special event | medium, 4 steps | Relationship with Dylan, the mitten tree flag (seasonal decor), and a choice of topper. |
| Walter's First Lap | Walter Oduya | Learn to skate | medium, 4 steps | Relationship with Walter and Bev, Zuri's drawing of Doris for the corkboard, and an electrician friend. |
| Not Enough to Hold On To | Penny Marchetti | Learn to skate | medium, 4 steps | Relationship with Penny and Lorne, the skate aids on the ice, and an option to make small ones for the kids. |
| The Night Shift Hour | Hank Lavoie | Stick and puck | short, 3 steps | Relationship with Hank, a standing dawn stick and puck session, $40 in coffee fund coins. |
| Pylons and Patience | Kenny Szabo | Stick and puck | short, 4 steps | Relationship with Kenny, his signed pylon. |
| Sneakers on the Ice | Kev Szabo | Broomball | short, 3 steps | Relationship with Kev, a signed broom keepsake, boot mats flag. |
| The Carnival Final | Rhonda Pelkey | Broomball | long, 4 steps | Relationship with Rhonda and Kev, the Golden Boot keepsake, carnival broomball becomes yearly. |
| The AED and the Bake Sale | Donna Pettigrew | Minor hockey | medium, 4 steps | Relationship with Donna, the AED in the lobby, Donna's cake tin (to return full, maybe). |
| Saturday, Eight A.M. | Lisa Cormier | Minor hockey | medium, 4 steps | Relationship with Lisa and Donna, the warm novice room, the novice photo for the minor hockey wall. |
| The Toothbrush Incident | Dr Lyle Haverkamp | Beer league | long, 4 steps | Relationship with Dr Haverkamp and Sauce, a framed toothbrush for the visitors' room, maybe $180 out of pocket. |
| Bylaw Fourteen | Dale Huffman | Beer league | short, 3 steps | Relationship with Dale, the restored bylaw, maybe your own tab in the binder. |
| One Hook for Three Refs | Nell Haraldsen | Beer league | short, 4 steps | Relationship with Nell, a kinder line in the incident book, and the next quest in the ref room chain. |
| A Chair, a Mirror, a Heater | Nell Haraldsen | Beer league | long (chain, after One Hook for Three Refs), 5 steps | Relationship with Nell, a fully kitted ref room, a small ice reputation bump as the officials' reports turn kinder. |
| Seven Minutes Fast | Dwayne Kuzyk | Beer league | medium, 5 steps | Relationship with Dwayne (and Midge, depending), and a decision about the Moosebrew clock keepsake. |
| The Shed Bell | Old Pete Vachon | Senior hockey | medium, 4 steps | Relationship with Old Pete and Bev, the bell fixed, maybe a chance to ring it once. |
| The Rafters End | Stan Szymanski | Senior hockey | medium, 4 steps | Relationship with Stan and Lorne, a leaning stool at the rafters end rail. |
| Organ 2 | Doreen Vachon | Senior hockey | short, 4 steps | Relationship with Doreen, the Casio plugged in, and a standing music request. |
| Sixty Days Late | Coach Bernie Ostrowski | High school | medium, 4 steps | Relationship with Coach Ostrowski, a choice of bench paint, the shop class and the barrel, or $330 on time. |
| Section See | Desmond Faulk | High school | medium, 5 steps | Relationship with Mr Faulk, the pep band at games, and a choice about the Section C letter. |
| Games Every Seventy-Five Minutes | Bob Ferreira | Tournament | medium, 4 steps | Relationship with Bob, a $250 committee thank-you, the host crest pin (which a rink rat would love). |
| The Mallards Keep Time | Larry Piche | Tournament | medium, 4 steps | Relationship with Larry and Doreen, the Mallards as tournament timekeepers, a line in Larry's letter. |
| The Crest-Trading Table | Tommy Bellweather | Tournament | short (chain, after Games Every Seventy-Five Minutes), 4 steps | Relationship with Tommy, the 1988 Peewee B pin for the trophy case (or for him). |
| His Own Thermometer | Réjean Paquette | Pro practice | medium, 4 steps | Relationship with Réjean, a little ice reputation, the Dukes' trust flag, an unsigned practice puck. |
| Twelve Signatures | Tommy Bellweather | Pro practice | short, 3 steps | Relationship with Tommy and Réjean, a signed puck that goes to a kid. |
| Doris Day | Earl Bratt | Special event | long, 5 steps | Relationship with Earl and Lorraine, Doris Day every year, a ribbon for Doris's mirror, maybe one mark on Earl's tally wall. |
| Big Gord Won't Let You Walk | Big Gord Halvorsen | Special event | medium, 5 steps | Relationship with Big Gord (and Earl, depending on the nose), $100 in the Doris Retirement Fund jar. |
| One Green Balloon | Tyler Kowalchuk | Special event | medium, 5 steps | Relationship with Tyler, and a secret that is yours to keep or tell. |
| Harold Penner Night | June Penner | Special event | medium, 4 steps | Relationship with June and Ray, Harold's cushion on seat C-4-7, a yearly memorial night. |
| The Whetstone | Bev Kowalchuk | Rink life: the plant room | short, 2 steps | Relationship with Bev, five free sharpenings, her grandfather's whetstone home again. |
| Eight Dollars | Bev Kowalchuk | Rink life: the pro shop | short, 3 steps | Relationship with Bev, the dollar framed by her till, the chalkboard heart she denies. Costs $8. |
| Hit It Where the Dent Is | Lorraine Duffy | Rink life: the canteen | medium, 4 steps | Relationship with Lorraine and Terry, the coffee machine fixed (the flip sign), a Clarion front page. |
| Hot Choc Late | Lorraine Duffy | Rink life: the canteen | short (chain, after Hit It Where the Dent Is), 4 steps | Relationship with Lorraine, and the menu board's wording. |
| Forty-One Days | Marg Lindqvist | Rink life: the plant room | long, 5 steps | Relationship with Marg, a new record on the days-since sign, a little ice reputation. |
| The Ghost in the Binder | Dylan Pruitt | Rink life: Gus's binder | long, 5 steps | Relationship with Dylan and Earl, one of Earl's notes in Gus's capitals as a keepsake, and a secret you can keep. |
| Most Improved, 1991 | Gary Pruett | Learn to skate | medium, 4 steps | Relationship with Gary and Doreen, the 1991 trophy claimed at last (with Gary or in the trophy case). |
| Whose Leg Is It? | Agnes Mulroney | Rink life: renovations | medium, 5 steps | Relationship with Agnes, Dale and Bev, and the conservator's instructions for the mural keepsake. |
| The Last Brass Strip | Midge Kaminski | Rink life: renovations | long, 5 steps | Relationship with Midge and June, the final brass strip on the dedication plaque, a Clarion column. |

## The stories

### Figure practice

**Minus Three and a Half** (`helene_minus_three`, from Hélène Arsenault). Hélène Arsenault has coached the Millbrook Figure Skating Club for longer than the plant has been grumpy, and she can tell the ice temperature with one stroke. She asks for minus three and a half at the surface during her mornings, which means planning the day so hockey gets hard ice later. Hold a good figure rating for three mornings and edge the corners, and she gives you the sequinned pin from her first carnival costume, 1975. It is the closest thing to a compliment she owns.

**The Coffee Bench** (`carol_coffee_bench`, from Carol Thibodeau). Carol Thibodeau has driven Josée to six o'clock ice four mornings a week for eight years and has strong views on the heater buttons, which work on half the pillars and run on a ten minute timer. She asks for warm stands and early coffee. Fix the building up, talk Lorraine into opening the Hot Stove at a quarter to six, and the figure parents get their bench back. Carol gives you a spare thermos with a skate sticker on it, which is the highest honour a figure parent can give.

### Figure show

**Test Day** (`josee_test_day`, from Josée Thibodeau). Josée Thibodeau is fourteen, skates every morning before school and has been visualising her senior bronze test since August, mostly out loud. She asks the owner for a fresh flood and good ice on the day, then asks for advice on nerves. What you tell her (breathe, fall well, or pretend the evaluator is Earl) comes back in her story afterwards. She pins a photocopy of her passed test sheet on the lobby notice board, beside the black cat.

**Fifty Carnivals** (`helene_fifty_carnivals`, from Hélène Arsenault). The club's spring show is the fifty-first carnival since 1975, and Hélène wants it to look like the old ones: coloured gels on the lamps and the pale blue banner lowered to just above the ice. The gels are in a shoebox upstairs that Kessler is not allowed to borrow. Get the building safe enough to dress the lamps, give the show glass, and the show becomes a yearly event with a share of the door. At the end, you choose whether the banner stays low for the season.

### Public skate

**Since Opening Night** (`irene_opening_night`, from Irene Dubois). Irene Dubois is eighty-one and has skated counter-clockwise at the Millbrook Community Arena every week since the ribbon was cut in 1974, missing only two winters (a hip, then her late husband's hip). She would like one lap to the Skaters' Waltz on her anniversary. Doreen's Casio has been ready since 1979. Afterwards Irene gives you her opening night admission stub, fifty cents, and you decide where it lives: the trophy case's empty hook, the notice board, or Gus's binder.

**One Song, Lights Down** (`devon_one_song`, from Devon Marsh). Devon Marsh has carried a ring in his coat for three Saturdays. He met Ama at public skate when she fell on him by the rental window, and he wants to propose there during their song with the lights down. Doreen will play it (as a hymn, her price), Dylan will dim the lamps (not breaker 14), and the owner helps pick the spot: centre ice, the Millbrook bank where Ronnie's pucks stop, or beside Doris. Whatever you choose, the guestbook gets a new line.

### Learn to skate

**Walter's First Lap** (`walter_first_lap`, from Walter Oduya). Walter Oduya spent thirty-five years as an electrician at Kessler Pulp & Paper and never once stood on skates. His granddaughter Zuri is six and has started asking why Grandpa only watches. Get the rentals sharpened (Bev, on a Sunday, which she will deny), run three good adult lessons, and be there when he brings Zuri to public skate. He gives you her crayon drawing of Doris for the office corkboard, and offers to look at the space heater that trips breaker 9.

**Not Enough to Hold On To** (`penny_skate_aids`, from Penny Marchetti). Penny Marchetti teaches gym at Millbrook Elementary and the adult learn-to-skate on Monday nights, where eleven grown-ups share about four metres of boards. She asks for skate aids, the frames beginners push across the ice. The rink can't afford new ones, but the broken-stick barrel by the back door is full, and Lorne Pettipiece builds benches out of Warlocks. The seven orange chairs from the hall fill in for the first night.

**Most Improved, 1991** (`gary_most_improved`, from Gary Pruett). Gary Pruett of the Wobbly Pops learned to stop last February, does it in front of the bench at every opportunity, and now has a Valley Beer League award named after him, the Pruett, for most improved skater. He has become curious about the little MOST IMPROVED 1991 trophy nobody has ever claimed from the lost and found. The Clarion archive names Mrs D. Vachon, forty, who could not stand in January. Doreen left it there on purpose. She'd like Gary to have it, or the rink.

### Stick and puck

**The Night Shift Hour** (`hank_dawn_ice`, from Hank Lavoie). Hank Lavoie runs a paper machine on nights at Kessler Pulp & Paper and drives to Millbrook at five in the morning with his gear in the back, because the only thing that lets him sleep is an hour of shooting pucks at an empty net. He asks for a dawn stick and puck slot on fresh ice. Give him two and it becomes a standing session, and he pays for the first one in coins from the mill's coffee fund.

**Pylons and Patience** (`kenny_backhand`, from Kenny Szabo). Kenny Szabo is twenty-four, big-hearted and not quite good enough, and he knows it, and he's decided to do something about the part he can fix: his backhand. He needs stick and puck ice, the pylon bag (it's in Doris's MISC drawer, because of course it is) and a witness. At the end he gives you one orange pylon with KENNY'S, DO NOT BORROW on it in his dad's handwriting.

### Broomball

**Sneakers on the Ice** (`kev_sneakers`, from Kev Szabo). Kev Szabo runs the Harlow Falls Broomball Club, which plays in sneakers and walks straight in from the parking lot. The club is cheap, loud and forgives anything, and Kev would like to be a better guest. Clean the building, put the old boot mats back at the doors, and run two good nights. The club gives you a broom signed by every member, which Earl immediately hangs in the ref room, because it smells of brooms anyway.

**The Carnival Final** (`rhonda_carnival_final`, from Rhonda Pelkey). Rhonda Pelkey is the broomball club's goalie, a hydro dispatcher, and the keeper of the Golden Boot, a rubber boot spray-painted gold that has been the carnival broomball trophy since 2003. It has lived on her porch for three years because nobody beat her team. She asks for good carnival ice, and for the Boot to finally have a proper home. You decide where it goes: the trophy case, beside the pike, or back to Rhonda's porch.

### Minor hockey

**The AED and the Bake Sale** (`donna_bake_sale`, from Donna Pettigrew). Donna Pettigrew runs Millbrook Minor Hockey like an army with a bake sale, and this time the bake sale is the army. The association's requirement for ice is a first aid kit and an AED in the lobby, and the rink has neither. Donna will raise the money in one weekend of squares if the owner gives her the hall, two sessions of customers and a lobby that can take a cabinet. You get the empty cake tin back, which is a sign of deep trust.

**Saturday, Eight A.M.** (`lisa_warm_room`, from Lisa Cormier). Lisa Cormier is the team manager of the U7 novices, which means she does up forty-eight skates every Saturday at eight in the visitors' room, the cold one, where the only warm spot is a single floor tile by the drain. She asks for a warm room. Fix the visitors' hot water and get the building up a notch, and give the novices two good Saturdays. Their team photo goes up on the minor hockey wall, with one kid facing the wrong way.

### Beer league

**The Toothbrush Incident** (`haverkamp_toothbrush`, from Dr Lyle Haverkamp). The Toothbrush Incident is the valley's pettiest rivalry. In the Moose Knuckles' first comeback game Rick Saucier lost a front tooth to a Molars stick, Dr Lyle Haverkamp fixed it the next morning and sent a bill, and Sauce has refused to pay it, or accept a toothbrush in the handshake line, ever since. Hear both sides and settle it: pay the bill yourself, broker a mouthguard pact, or let the next game decide. Either way you get a toothbrush, framed, for the visitors' room wall.

**Bylaw Fourteen** (`dale_bylaw_fourteen`, from Dale Huffman). Dale Huffman has been commissioner of the Valley Beer League since the binder was a folder, and the binder is the league. Page fourteen, the bylaw on ties in the Last Call Cup final, has been missing since 2019, and the playoffs are coming. A note on Gus's 1998 calendar sends you to the glycol tab of the plant room binder, where Gus used it as a bookmark. Dale reads the bylaw aloud to you, all of it, and you choose how to react.

**One Hook for Three Refs** (`nell_one_hook`, from Nell Haraldsen). Nell Haraldsen referees the Valley Beer League four nights a week and the NSHA as a linesperson on Saturdays, and every night she hangs her coat on the floor. The ref room, a former broom closet with REFEREES painted over BROOMS, has one hook for three officials, and the incident book has been asking for a second in increasingly polite handwriting. Earl has hooks in Doris's MISC drawer. The officials remember who gave them a hook.

**A Chair, a Mirror, a Heater** (`nell_ref_room`, from Nell Haraldsen). The second half of Gus's ref room promise: a chair, a mirror and a heater. Lorne builds a chair out of Kodiak shafts, the building needs a proper circuit so the heater doesn't take breaker 9 with it, and the mirror is the owner's choice: a new one from Penner Hardware, or the cracked valley mirror from the men's washroom, the keepsake with the five towns marked in nail polish. Finish it and the officials write the kindest page the incident book has ever had.

**Seven Minutes Fast** (`dwayne_seven_minutes`, from Dwayne Kuzyk). Dwayne Kuzyk is the Ice Holes' social convenor, has never missed a postgame and has missed eleven games. He has discovered that the Moosebrew clock above the Hot Stove runs seven minutes fast, on purpose, since 1996, so that the Late Ice League gets on the ice on time, and that this has been making him early for the pitcher for years. He wants it fixed. The town, via Midge at the Clarion, wants it left alone. You can set it right, leave it, or give Dwayne a wristwatch from the lost and found set to the true time.

### Senior hockey

**The Shed Bell** (`pete_shed_bell`, from Old Pete Vachon). Old Pete Vachon has sharpened every Lumber King's skates since 1971, and after every home win he takes the brass bell from the Mill Road Shed out of the trophy case and rings it in the lobby. Lately it clunks. The clapper is hanging on a twist tie, which he denies. Bev machines a new pin on a coffee break and asks for the twist tie for her wall. After the next good home game, Pete may let you ring it.

**The Rafters End** (`stan_rafters_stool`, from Stan Szymanski). Stan Szymanski has stood at the same spot on the north end rail for every Lumber Kings home game since 1974; the rail is worn shiny under his elbows and the Duncannon Ledger once saw him cry. He will not sit down, because sitting is for the other end. He might lean. Lorne builds a tall leaning stool out of Shorewood shafts, and it appears at Stan's spot without a word. Stan says six words about it, which for Stan is a speech.

**Organ 2** (`doreen_organ_two`, from Doreen Vachon). Doreen Vachon, Old Pete's wife, runs the clock at Lumber Kings games and plays a Casio keyboard set to Organ 2: three songs and a slightly passive-aggressive dirge when the referee misses a call. The adapter died and the batteries die in the third period, so the dirge melts. Bev has a drawer of power adapters that are not hers. Plug it in and Doreen offers to play one request at the next game.

### High school

**Sixty Days Late** (`ostrowski_sixty_days`, from Coach Bernie Ostrowski). Coach Bernie Ostrowski has coached the Millbrook High Mallards since before the 2009 Valley High School Championship, which he mentions in every phone call about late payment. The school board pays sixty days late, always. This year he offers a trade: the shop class repaints the faded EAR IT on the home bench, or takes the broken-stick barrel for projects, in exchange for forgiving the late fee. Or you can insist on the money, politely.

**Section See** (`faulk_section_see`, from Desmond Faulk). Desmond Faulk teaches music at Millbrook High and leads a pep band of eleven teenagers and one very old sousaphone. They want to play Mallards home games from Section C, the section with no letter that the town calls Section See, because a pep band in Section See is a joke too good to waste. Fix the roped-off seats, decide whether to paint a C, leave the gap, or paint SEE, and give the band a home game.

### Tournament

**Games Every Seventy-Five Minutes** (`ferreira_seventy_five`, from Bob Ferreira). Bob Ferreira dispatched freight trains at Carrick Junction for thirty years and now chairs the Valley Peewee Tournament committee, which means he has a schedule board on an easel and opinions about every minute on it. Games every seventy-five minutes, a flood between each, and in eleven years the tournament has never finished on time. Edge before the weekend, flood eight times, keep the ice good, and the committee pays a thank-you on top of the contract and gives you this year's host pin.

**The Mallards Keep Time** (`larry_timekeepers`, from Larry Piche). Larry Piche plows snow, captains the Millbrook Mallards and has written to the Puckworth Cup trustees every March since 2005 in the same neat handwriting. This winter the Mallards have volunteered to keep time for the Valley Peewee Tournament, all eleven of them, with eleven matching pencils. Doreen trains them, the building warms the timekeeper's box, and the weekend runs. At the end Larry asks whether he can mention the rink in this year's letter.

**The Crest-Trading Table** (`tommy_crest_trade`, from Tommy Bellweather). Tommy Bellweather is eleven, lives at the rink, and runs the crest-trading table at tournaments with the seriousness of a bank. A girl from Port Ainsley has the 1988 Millbrook Peewee B pin, from the year of the felt pennant in the trophy case, and she'll only trade it for this year's host pin. Bring him the pin Bob gave you. Tommy makes the trade, then gives the 1988 pin to you, because it belongs to the rink.

### Pro practice

**His Own Thermometer** (`rejean_ir_gun`, from Réjean Paquette). Réjean Paquette has been the Duncannon Dukes' equipment manager for twenty-six years and trusts exactly one thermometer: the infrared gun in his jacket. When the Dukes rent Millbrook for practice he walks the ice before the players do and writes down what he finds. He asks for two practices at an 85 rating and a plant log that agrees with his gun. Earn it, and he tells the Dukes' front office the Millbrook ice is honest, which is the nicest thing a pro equipment manager can say.

**Twelve Signatures** (`tommy_twelve_signatures`, from Tommy Bellweather). Tommy Bellweather has a puck and a pen and a list of the Duncannon Dukes in order of how likely they are to sign. When the Dukes practise at Millbrook, he wants to stand at the glass. Réjean, who trusts no thermometer but likes children, gets the puck signed in the dressing room, twelve names, the goalies' smallest. You give it to Tommy, and choose how.

### Special event

**The Mitten Tree** (`dylan_mitten_tree`, from Dylan Pruitt). Dylan Pruitt is seventeen, wants to drive Doris more than he wants to graduate, and has decided this year's mitten tree will be the best in the valley. Sort the lost and found (nine mittens, fourteen socks, a retainer in a napkin), clean the lobby, and hold the Christmas skate with the fir up. The mittens go to the elementary school in January. At the end you choose which mitten goes on top.

**Doris Day** (`earl_doris_day`, from Earl Bratt). Earl Bratt has driven Doris, the 1974 Zambelli Model 525, more than nine thousand times and will not hear a word against her. He has never once asked for anything for himself. He asks for Doris Day: a tune-up, a fresh towel, a cake shaped like her snow tank, and a public skate where the town watches her flood. At the end he offers something he has never offered anyone: a mark on the tally wall.

**Big Gord Won't Let You Walk** (`gord_santa`, from Big Gord Halvorsen). Gordon 'Big Gord' Halvorsen, seventy-one, has sold trucks outside Kessler since 1977, stars in every advert, insists on every power play and has been Santa at Skate with Santa since nobody remembers. He arrives on Doris's snow tank shouting his slogan. He wants a full tank and a fresh sheet, and he wants the red nose on Doris, which Earl does not allow. You decide the nose.

**One Green Balloon** (`tyler_green_balloon`, from Tyler Kowalchuk). Tyler Kowalchuk, Bev's grand-nephew, works the shop till on weekends and has decided to solve Millbrook's smallest mystery: who ties a single green balloon to the 2005 Mallards photo every 12 March. Larry says not him, Bev says ask who's here first every day, and the resurfacer bay has a bag of green balloons with one missing. It's Earl. It's always been Earl. You can tell Tyler, who will tell the Clarion, or keep it.

**Harold Penner Night** (`june_memorial_game`, from June Penner). June Penner runs Penner Hardware on Main Street, whose board ad reads IF WE DON'T HAVE IT, HAROLD WILL ORDER IT, though Harold has been gone for twelve years. Her grandfather opened the arena in 1974 and shouted SKATE! from seat C-4-7 every game for thirty years. She asks for a memorial night. Ray brings the Lumber Kings in their 1974 socks, you polish the plaque, and at the end you choose who shouts the first SKATE!

### Rink life

**The Whetstone** (`bev_whetstone`, from Bev Kowalchuk). Bev Kowalchuk has run Bev's Edge & Tape since 1979 and sharpens every skate in town on Old Bertha, but she finishes every edge by hand on her grandfather's whetstone. Or she did, until Gus borrowed it in 1979 to touch up an ice scraper and never gave it back. It's on a nail behind the thermometer board in the plant room, with a note. Bring it home and Bev gives you five free sharpenings, and the story.

**Eight Dollars** (`bev_eight_dollars`, from Bev Kowalchuk). In the corner of Bev's chalkboard, under the hollows and her opinions of them, it says THE NEW ARENA OWNER OWES ME $8. Nobody knows what for, including the owner. Pay it, and then find the other thing she's been waiting for: the one-dollar bill the town sold the arena for, which is in the office cash box behind a combination that isn't the combination. It goes in the empty frame beside her first dollar from 1979. The $8 line on the chalkboard becomes a small drawn heart, which Bev denies.

**Hit It Where the Dent Is** (`lorraine_coffee_machine`, from Lorraine Duffy). Lorraine Duffy has run the Hot Stove canteen for twenty-two years, makes Earl's gravy, and knows the coffee machine works if you hit it where the dent is. Lately the dent has stopped working. The town considers the coffee machine the most important piece of equipment in the building. Terry Duffy of the Plungers, her nephew, can fix it between pager calls. When the flip sign turns to WORKING, the Clarion puts it on page one.

**Hot Choc Late** (`lorraine_hot_choc_late`, from Lorraine Duffy). Two letters fell off the Hot Stove's brown felt menu board years ago, so it reads HOT CHOC LATE. Nobody fixed it, because at public skate it is simply true. Bev has a tin of felt letters from her 1979 sign, with one O. Lorraine will not fix it, but she wants the letters in a drawer for the inspector and asks you whether to keep it or lean in with a new line.

**Forty-One Days** (`marg_forty_one_days`, from Marg Lindqvist). Marguerite Lindqvist ran the plant at Harlow Falls for thirty years and writes in your log in red pen when your entries are wrong. On No. 1's side of the plant room there is a flip-number sign, DAYS SINCE No. 1 TRIPPED, with the record painted under it in red: 41, from 1996. Marg wants a new record. It isn't a grind, it's a season: forty rounds, an oil change, a descale, and a log with no gaps. If No. 1 holds, she paints the new number herself.

**The Ghost in the Binder** (`dylan_binder_ghost`, from Dylan Pruitt). Dylan is sure Gus's binder is haunted: new sticky notes in Gus's capitals keep appearing on the plant room door, still wet, while Gus is in Florida sending postcards about alligators. Three morning rounds, a chewed marker behind the DORIS (DON'T) drawer, and one conversation later, it turns out Earl has been writing them. He watched Gus write for forty years, and it is easier than saying it himself. You choose what to tell Dylan.

**Whose Leg Is It?** (`agnes_three_legs`, from Agnes Mulroney). Agnes Mulroney taught art at Millbrook High for thirty-one years and is now the Valley Rocks Bonspiel draw master, and curlers notice everything. In 1976 her class painted Winter on the Mill Pond above the rental window, including a skater painted from both ends by two students who met in the middle, leaving three legs. The conservator from Wendover College asks in writing whether to correct it. Dale won't say which leg is his; Bev, eventually, will. Then you choose: keep all three, keep the leg and lose Gus's Florida stain, or keep everything.

**The Last Brass Strip** (`midge_last_brass_strip`, from Midge Kaminski). Midge Kaminski has written Off the Boards for the Millbrook Clarion for forty years, including the column that taught the town the word keepsake. Between the front doors, the 1974 dedication plaque lists five roof repairs and the words WE'RE TRYING, and under that, a gap Gus left for whoever fixes the roof properly. When the roof is truly renovated, June Penner engraves the last strip on her grandfather's machine. You choose what it says. Midge writes the column.

## Favour templates

| Favour | Archetype | What they ask | Goals | Reward |
| --- | --- | --- | --- | --- |
| Earlier Ice for Them | `hockey_parent` | They want Saturday's minor hockey practice to run on time so the family can make a tournament in Kessler. | Run a minor hockey session on decent ice, on time. | relationship +4, mood +0.05 |
| A Fresh Flood for Them's Kid | `figure_parent` | They's child has a figure test and needs a flood right before. | Flood right before the test.; Hold the test session on ice rated 65 or better. | relationship +5, mood +0.05 |
| Lights Down for Them | `date_night` | They would like the lights down for one slow song at public skate. | Run a public skate on good ice and dim the lamps for one song. | relationship +5, mood +0.06 |
| One Lap with Them | `learn_to_skate_adult` | They would like the owner to hold their hand for one lap at learn-to-skate. | Get your skates on and meet them on the ice.; Skate the lap during a learn-to-skate session. | relationship +6, mood +0.06 |
| Them Rides Doris | `rink_rat` | They want to ride along on one flood. | Do a flood with them riding along. | relationship +6, Earl Bratt +-1 |
| Them's Mitten | `retiree_regular` | They have lost a mitten, probably in the lost and found. | Check the lost and found crate at the rental window. | relationship +4, a day log line |
| The Wrong Bag | `beer_leaguer` | They took the wrong hockey bag home on Thursday. | Look in the dressing rooms for the right bag. | relationship +3 |
| A Clean Sheet for Them | `stick_and_puck_regular` | They would like a fresh sheet before stick and puck. | Flood before stick and puck.; Run the stick and puck session. | relationship +4, mood +0.04 |
| Salt the Lot | `broomballer` | They say the parking lot is icier than the rink. | Check the parking lot.; Clean up and salt the walkways. | relationship +4 |
| Heat for Section B | `superfan` | They say the heater over their seats is out for the Lumber Kings game. | Check the heater over their seats.; Run the next Lumber Kings home game. | relationship +4, mood +0.05 |
| A Spot at the Glass | `autograph_hunter` | They want to stand at the glass during pro practice. | Let them watch a Dukes practice from the glass. | relationship +5 |
| Coffee for the Coach in the Stands | `coffee_coach` | They won't leave the glass during the game and would like a coffee brought over. | Grab a coffee from the Hot Stove.; Bring it to the glass. | relationship +3, mood +0.03 |
| A Warm Seat for Them | `grandparent` | They want a seat near a working heater for a grandchild's game. | Find a seat under a working heater.; Run the minor hockey game. | relationship +4, mood +0.05 |
| Coffee at Shift Change | `shift_worker` | They come off a shift at the mill and wants the canteen open early. | Get a pot on at the Hot Stove early. | relationship +4, $4 |
| Something From This Century | `teen` | They would like public skate to play something newer than the Casio's repertoire. | Run a public skate with a request or two. | relationship +4, Doreen Vachon +1 |
| The East Circle | `figure_skater` | They say there's a rut where they land their jumps. | Flood the rut out.; Get figure ice rated 65 or better. | relationship +5, Hélène Arsenault +1 |
| The Lucky Glove | `minor_player` | They can't find their other glove, the lucky one with the hole. | Look for the glove in the dressing rooms. | relationship +4 |
| A Table for the 50/50 | `volunteer` | They need a table in the lobby to sell 50/50 tickets on game night. | Set up a table in the lobby.; Run the game night. | relationship +4, $20 |
| Water for the Officials | `official` | They would like water bottles for the officials before a game. | Grab some water from the Hot Stove.; Run the game. | relationship +4, Nell Haraldsen +1 |
| A Quiet Seat | `scout` | They would like a quiet seat away from the rafters end, and a line sheet. | Find a quiet seat in the stands.; Run the game they came to watch. | relationship +4, ice reputation +0.5 |

## People added for these quests

The quests use canon people where they can. These people were written for the quests and are now in `data/world/cast.json`, along with Terry Duffy and Lorne Pettipiece, who appear in steps but give no quest:

- **Josée Thibodeau** (`josee_thibodeau`): 14, figure skater in the Millbrook club, earnest and dramatic, testing senior bronze. Loves figure_show (play 0.9) and figure_practice (play 0.9); watches public_skate.
- **Carol Thibodeau** (`carol_thibodeau`): 44, figure parent, Josée's mother, eight years on the six a.m. coffee bench. Watches figure_practice (0.9) and figure_show (0.9).
- **Irene Dubois** (`irene_dubois`): 81, retiree regular, has skated every week since opening night in 1974 and skates her late husband Albert's laps too. Plays public_skate (0.9); watches senior_hockey and figure_show.
- **Devon Marsh** (`devon_marsh`): 29, date_night regular who met his fiancée Ama at public skate. Plays public_skate (0.8); watches beer_league a little.
- **Walter Oduya** (`walter_oduya`): 62, retired Kessler Pulp & Paper electrician learning to skate for his granddaughter Zuri (6). Plays learn_to_skate (0.9) and public_skate (0.6).
- **Penny Marchetti** (`penny_marchetti`): 31, gym teacher at Millbrook Elementary and the adult learn-to-skate instructor; cheerful, practical, writes very good cards. Plays learn_to_skate (as coach) and public_skate.
- **Hank Lavoie** (`hank_lavoie`): 47, shift_worker, runs a paper machine on nights at Kessler Pulp & Paper and shoots pucks at dawn to sleep. Plays stick_and_puck (0.9); watches senior_hockey.
- **Rhonda Pelkey** (`rhonda_pelkey`): 39, Harlow Falls Broomball Club goalie and hydro dispatcher, keeper of the Golden Boot. Plays broomball (0.95); watches special (the carnival).
- **Lisa Cormier** (`lisa_cormier`): 36, hockey_parent and U7 novice team manager, panic-bakes blueberry muffins. Watches minor_hockey (0.95); plays public_skate.
- **Nell Haraldsen** (`nell_haraldsen`): 35, official: Valley Beer League referee four nights a week, NSHA linesperson on Saturdays. Works beer_league and senior_hockey; watches figure_show on her nights off.
- **Desmond Faulk** (`desmond_faulk`): 48, music teacher at Millbrook High, leads the pep band and its 1971 sousaphone. Watches high_school (0.9) and senior_hockey.
- **Bob Ferreira** (`bob_ferreira`): 63, retired Carrick Junction freight dispatcher, chairs the Valley Peewee Tournament committee, loves a timetable. Watches tournament (0.95) and minor_hockey.
- **Tommy Bellweather** (`tommy_bellweather`): 11, rink_rat and autograph_hunter, runs the crest-trading table like a bank. Watches pro_practice (0.95), tournament (0.9) and senior_hockey; plays stick_and_puck and minor_hockey.
- **Réjean Paquette** (`rejean_paquette`): 58, Duncannon Dukes equipment manager for twenty-six years, trusts only his own infrared gun. Works pro_practice; watches senior_hockey with a professional frown.
- **Tyler Kowalchuk** (`tyler_kowalchuk`): 17, Bev's grand-nephew, works the shop till on weekends (canon, RINK_SIM 2.2), amateur detective with a notebook. Watches beer_league and senior_hockey; plays stick_and_puck.
- **June Penner** (`june_penner`): 48, runs Penner Hardware, granddaughter of the late Mayor Harold Penner who opened the arena in 1974. Watches senior_hockey (0.8) and special (0.9).
- **Lorraine Duffy** (`lorraine_duffy`): 63, canteen_worker, has run the Hot Stove for twenty-two years, makes Earl's gravy, Terry Duffy's aunt. Watches senior_hockey and public_skate from behind the counter.
