# Millbrook and the valley: what's on the walls

A worldbuilding design for Sean. Owned by the World and asset design thread
(decor, readables and their art); Rink environment decides where each piece
sits in the `Venue`. The readables are data in `data/world/readables.json`
(40 entries, all excerpts written in full). Canon comes from `LORE.md`,
`TEAMS.md`, `PROSHOP.md`, `RINK_SIM.md`, `PATHS.md` and `docs/WORLD.md`; anything new is
listed in section 7 so the other docs can catch up.

Sean asked what hangs on the walls, what decorates the rink and what there is
to read, so that Millbrook feels like a fully defined place, and so the game
feels mostly relaxing. The idea in one line:

**Every object in the building is a small story about a person in the town,
and renovating the rink is the job of looking after those stories, not
replacing them.**

The tone is the rink's tone: warm, specific, a little silly, never stupid.
Nothing here is a menace. The worst thing in the building is a coffee machine.

---

## Contents

0. Rules of the decor (ages, keepsakes, room ids, the building's dates)
1. Millbrook Community Arena, room by room
2. The keepsakes
3. Literature and readables
4. The other rinks in the valley
5. Seasons and events
6. Prop list for the art team
7. Lore invented here
8. Open questions

---

## 0. Rules of the decor

### 0.1 Three ages, one story

Every decor piece follows `docs/ART.md`: worn (the 1970s original, faded,
grimy, notes taped on), repaired (the same thing kept going by volunteers, a
letter repainted in the wrong red) and renovated (new materials, club palette,
clean light). For decor the ages also tell a story about care:

| Age | What decor looks like | The feeling |
| --- | --- | --- |
| Worn | Frames crooked and yellowed, captions typed on index cards, banners sun-faded, tape everywhere, half the bulbs in the trophy case dead | A building that nobody has had time for, but everybody still loves |
| Repaired | Frames straightened and glass cleaned, a few new hand-lettered captions, the trophy case lit, notes replaced with laminated signs | Somebody is looking after it again |
| Renovated | Proper frames, museum labels in the RinkOS sign style, LED case lighting, banners restored and rehung, the town's history laid out as a walk | The town's living room, finished |

### 0.2 Keepsakes: renovation keeps, restores, never removes

`LORE.md` already says the legends' objects in the lobby are "reframed and
relit, never removed." This doc extends that to a short list of
**keepsakes** (section 2): objects the town considers part of the building.
A renovation project that touches a keepsake's room shows it in the project
screen with three choices:

| Choice | What happens | Town reaction |
| --- | --- | --- |
| Keep as is | The object stays, cleaned, exactly where it was | None, or a nice Clarion mention |
| Restore | Restored and relit; costs a little extra (usually $200 to $2,000) | Community reputation +1 to +3 when it's unveiled |
| Remove | Gone (stored in the hall closet, recoverable) | Community reputation -3 to -15, letters to the Clarion, a visit from someone who cares |

Nothing forces the player to keep anything, and nothing punishes them for
long: putting a removed keepsake back restores most of the lost reputation.
The point is that the town notices, the way a real town would.

### 0.3 Room ids

Two id sets exist: the `Venue` rooms in `RINK_SIM.md` 3.5 and the six
`ROOMS` in `scripts/world/sim/rink_sim.gd`. This doc (and `readables.json`)
uses the `Venue` ids, plus five new ones it proposes. Rink environment owns
the final list.

| Room in this doc | `Venue` id | `rink_sim.gd` room | Notes |
| --- | --- | --- | --- |
| Parking lot and exterior | new `parking_lot` | | Part of the W2 town scene; the outside of the rink |
| Lobby | `lobby` | `lobby` | Includes the trophy case, mural and front desk |
| Snack bar (the Hot Stove) | new `concession` | `lobby` | `RINK_SIM.md` puts concessions in the lobby; a sub-area id lets decor and the health inspector point at it |
| Skate rental and pro shop window | new `pro_shop` | `pro_shop` | The rink's rental counter; becomes Bev's lobby window at RENOVATED. Bev's main shop is across the lot (`bevs_shop`, `PROSHOP.md`) |
| Washrooms | `lobby` | `washrooms` | Facility weight counted with the lobby |
| Home dressing room | `locker_home` | `home_dressing` | The Lumber Kings' room |
| Visitors' dressing room | `locker_away` | `visitor_dressing` | The cold one |
| Ref room | new `ref_room` | | A former broom closet off the corridor |
| Benches, penalty boxes, timekeeper | `benches`, `penalty_boxes` | | |
| Stands | `stands_bench`, `stands_box` | `stands` | Wooden benches on the east side, 1974 box seats on the west |
| Rafters and banners | `lighting` (and `roof`) | | Banners hang from the trusses with the lamps |
| Office | `office` | | |
| Plant room | `plant_room` | | Already proposed in `RINK_SIM.md` |
| Resurfacer bay | `zamboni_bay` | | Doris's room |
| Upstairs hall | new `community_hall` | | Mezzanine Hall, above the lobby, a window on the south end |
| Bev's Edge & Tape | `bevs_shop` | | Across the parking lot; its walls are summarised here only |

### 0.4 The building's dates

Captions, photos and plaques all draw on one timeline so nothing contradicts.

| Year | What happened |
| --- | --- |
| 1952 | The Millbrook Lumber Kings are founded, playing on natural ice in the Mill Road Shed |
| 1956 | First Aldous Cup |
| 1973 | The Shed's roof sags under snow; the town votes to build a proper arena |
| 1974 | Millbrook Community Arena opens, Saturday 2 November. Mayor Harold Penner cuts the ribbon. Opening game: Kessler Millmen 5, Lumber Kings 3. Doris (Zambelli Model 525) and the Nordale plant are new |
| 1976 | The Millbrook High art class paints the lobby mural |
| 1977 | Gus Tremblay becomes arena manager. Ronnie Haverstock finds the dead spot behind the north net |
| 1979 | Lumber Kings win the Aldous Cup. Bev's Edge & Tape opens. Ronnie leaves for Granite City |
| 1983 | Earl Bratt becomes head icemaker. The Flood Crew beer league team is founded |
| 1984 | Moose Kowalczuk serves 17 minutes in the Millbrook penalty box during an exhibition and leaves a paperback behind |
| 1989 | The Millbrook Mallards are founded |
| 1991 | The roof starts dripping on the home blue line every March |
| 1994 | Ronnie brings the Puckworth Cup home for a day in August. Millbrook Midget AA win the valley title (Rick Saucier, 61 goals) |
| 2003 | A puck kills the HOME half of the scoreboard at the Lumber Kings' home opener |
| 2005 | 12 March: the Puckworth Cup sits on a folding table at centre ice for one night. About 400 people queue in the cold |
| 2019 | The last glycol test anybody wrote down |
| Last spring | Gus retires to Florida after 49 years; the town sells the arena for one dollar |

---

## 1. Millbrook Community Arena, room by room

The building is a 1974 municipal arena: concrete block painted institutional
mint and cream, harvest gold and burnt orange trim, wood panelling in the
lobby, brown quarry tile, steel trusses over the ice, sodium-yellow light in
the parking lot. At WORN it's tired but clean where it counts. People have
taped things to every surface for fifty years and almost every piece of tape
is holding up something that matters to someone.

### 1.1 Parking lot and exterior (`parking_lot`)

**Signs, exact wording**

| Sign | Where | Text |
| --- | --- | --- |
| The rink sign (`rink_sign`, hand-painted letters) | Above the front doors | WORN: `MILLBRO K COMMUN TY ARENA` (the O and the I fell off in different winters). REPAIRED: the missing letters repainted in a slightly wrong red. RENOVATED: `MILLBROOK COMMUNITY ARENA` in RinkOS sign letters, with the old wooden letters mounted inside the lobby |
| The marquee board | On posts at the lot entrance, changeable black letters | Day one: `PUBLIC SKATE SAT 1-3 / LUMBER KINGS FRI 8PM / THANK YOU GUS`. The player can set it (see 5.1 for event versions). It is always one letter short of what you want to say |
| Town welcome sign | Where Main Street meets the arena road | `WELCOME TO MILLBROOK / HOME OF RONNIE HAVERSTOCK / AND THE MILLBROOK BANK / DRIVE SLOW, KIDS SKATING` |
| Back door | The resurfacer bay's man door | `STAFF ONLY. THAT MEANS YOU, DYLAN.` (Dylan arrives in week 2; the sign was Gus's prophecy) |
| Snow pit fence | Behind the bay | `MOUNT DORIS: NO CLIMBING` (everyone climbs it) |
| Plug-in posts | Along the front row | `BLOCK HEATERS: STAFF AND REFEREES` with one post labelled `EARL` |

**Objects with history**

| Object | Story |
| --- | --- |
| The Double-Double cup in the snowbank | A Double-Double Donuts cup is frozen into the snowbank by the front doors every winter, as at every rink in the valley. Millbrook's is always in the same spot, left of the doors, and nobody admits to putting it there. Dylan eventually admits it's him, in year 2 |
| Mount Doris | The pile of snow Doris dumps out the back. By February it is taller than the bay door and kids hold King of the Hill on it during the Winter Carnival |
| The broken-stick barrel | By the back door (`PROSHOP.md`). Painted on the side in Gus's hand: `BROKEN STICKS ONLY. NOT BROKEN DREAMS. THOSE GO IN THE LEGION.` |
| The Warlock bench | Beside the front doors. Lorne Pettipiece built it from forty-one broken Warlock sticks (Bev: "Sturdier than they ever were as sticks"). Appears once the stick-barrel deal has run for a season |
| The Cup Tree | A blue spruce by the lot entrance, planted by Ronnie Haverstock in August 1994, the day the Puckworth Cup came home. It's about 9 m tall now and gets the Christmas lights |
| The frozen bicycle | A kid's bicycle has been frozen into the bike rack since November 2019. Its owner is now at university and has asked, in writing, for it to stay |

**Ages**

| Worn | Repaired | Renovated |
| --- | --- | --- |
| Potholes, one sodium lamp out, the marquee missing letters, the rink sign letters falling off | Lot graded, lamps working, the sign repainted, marquee letters replaced | LED lot lights, a canopy over the doors, a proper sign; keeps the Cup Tree, the marquee board (repainted in club navy), the Double-Double cup's snowbank, the frozen bicycle, and Mount Doris |

### 1.2 Lobby (`lobby`)

The first room the player walks into, at 05:00, in the dark. Wood panelling,
quarry tile, a long low ceiling with a water stain, the snack bar on the
right, the rental window on the left, the trophy case in the middle like a
piece of furniture in a living room. It smells of popcorn oil, wet wool and
rubber matting.

#### On the walls

| Piece | Where | What it is | Caption, exact wording |
| --- | --- | --- | --- |
| Dedication plaque | Between the front doors | Cast bronze, 1974, with a brass strip added later | See `dedication_plaque` in `readables.json`. The last line on the brass strip is `WE'RE TRYING`, and there's a strip-sized gap below it for whoever fixes the roof properly |
| The Mallards and the Cup | Facing the doors, the biggest frame in the room | A colour photo, 2005: eleven men in green Mallards jerseys around the Puckworth Cup on a folding table at centre ice | `The Millbrook Mallards with the Puckworth Cup. Millbrook Community Arena, 12 March 2005. We asked.` Beside it, framed, the original letter, and below it on a chain, Larry Piche's binder of follow-ups (`mallards_letters`) |
| The Wall of Lumber Kings | The long west wall, two rows | A team photo for every season since 1952, black and white to colour | See "The team photo wall" below |
| The Beer League Champions Board | Above the front desk | A plywood board painted with every Valley Beer League champion since 1977, in four hands of lettering | Header: `VALLEY BEER LEAGUE CHAMPIONS (WE KEPT SCORE)`. The D Division column switches to masking tape in 2011, like the Last Call Cup |
| The mural, *Winter on the Mill Pond* | Above the rental window, 9 m long | Painted 1976 by the Millbrook High art class (see below) | A small painted label in the corner: `Millbrook High Art 1976. Mrs. A. Mulroney and class.` |
| Minor hockey photo wall | By the washroom corridor | Millbrook Minor Hockey team photos, every age group, in mismatched frames | Typical: `Millbrook Peewee B 1988. Back row, third from left: a very young Rick Saucier, already talking.` |
| The GNHL banner | Above the snack bar | See 1.3 | |
| Notice board | By the front desk | Cork, 1.2 m, every thumbtack in town | `notice_board` |
| Payphone | Corridor wall | A 1970s rotary payphone, beige, with a hand-written card | `OUT OF ORDER SINCE 1998. STILL TAKES YOUR QUARTER.` |
| Rules of the Rink | By the doors to the ice | Enamel sign, 1974 | `RULES OF THE RINK. 1. Skate counter-clockwise. 2. No horseplay. 3. No snowballs. 4. Helmets for children under 12. 5. Respect the ice, it was made for you. MILLBROOK PARKS & RECREATION.` Someone has added, in marker: `6. Be nice to Earl.` |

#### The team photo wall

Fifty-odd Lumber Kings photos in two rows. The ones the town talks about:

| Year | Caption | The story |
| --- | --- | --- |
| 1952 | `The first Lumber Kings, Mill Road Shed. They lost 9-1 and threw a party anyway.` | Natural ice, wool sweaters, a dog in the front row |
| 1956 | `Aldous Cup Champions. The Shed's roof held, just.` | The first Cup |
| 1974 | `Opening night at the Community Arena. Kessler 5, Lumber Kings 3. We were nervous.` | The new rink, still smelling of paint |
| 1979 | `ALDOUS CUP CHAMPIONS 1979` (larger frame, gold mat) | In the far left doorway, out of focus, a young man in a Millbrook Dairy uniform is carrying crates of milk for the party. It's Ronnie Haverstock, the week before Granite City signed him. Nobody noticed until 1994 |
| 1987 | `Lumber Kings 1987.` | Every player has the same moustache. A note on the frame: `Not a team rule. Just happened.` |
| 1999 | `Lumber Kings 1999.` | Hung upside down since 2006, when Gus dropped it reframing. The players voted to keep it that way |
| 2003 | `Home opener 2003. The night the scoreboard died.` | The whole team pointing up at the dark HOME half |
| 2005 | `The Lost Winter. No photo. We were all at the Mallards' thing.` | A blank frame with that caption typed on an index card |
| Last season | `Lumber Kings. The last season under Gus.` | Gus in the front row in his parka, the only time he ever sat for one |

#### The trophy case, item by item

A 2.4 m oak and glass case on a mint-green steel base, standing in the
middle of the lobby. At WORN, two of the four bulbs work and the glass has
fifty years of children's forehead prints. Its right-hand third is a small
display freezer, running off breaker 14.

| Shelf | Item | Label (at REPAIRED or later) | Story |
| --- | --- | --- | --- |
| Top | Ronnie's Shorewood | `Shorewood Classic 5030, Gripley's tape. Used by R. Haverstock, Tuesday Beer League, 1979, on the night the scout came.` | The stick he scored five goals with on Millbrook's crooked ice. The tape has never been changed |
| Top | Doris's original keys | `Keys to the 1974 Zambelli Model 525, as delivered. Fob shaped like a Z.` | Gus kept the originals in the case and used the spare for forty-nine years. Earl says Doris knows |
| Top | The 1979 game puck | `Aldous Cup winning goal, Game 6, April 1979.` | Black rubber, the old NSHA logo nearly worn off from being held |
| Middle | The frozen Double-Double cup | `Double-Double Donuts cup, recovered from the queue line, 12 March 2005. Do not unplug.` | In the freezer section, still in a block of the ice off the sidewalk where people waited three hours to see the Cup. Breaker 14 runs this freezer. That's the whole secret |
| Middle | The Millbrook Dairy milk bottle | `The bottle that stood beside the Puckworth Cup on the dairy counter, August 1994.` | Glass, with the dairy's cow logo. Somebody has left a dollar in it every year since |
| Middle | The 1979 programme | `Official Programme, Aldous Cup Final, Game 6. 25 cents.` | Readable (`program_1979_final`) |
| Middle | The Shed door handle | `Door handle from the Mill Road Shed, 1952 to 1974.` | Cast iron, worn bright where a generation of hands pulled it |
| Middle | The Last Call Cup | `The Last Call Cup, Valley Beer League D Division (when it's here).` | A dented pewter stein bolted to a puck, names on masking tape since 2011. It lives in the case when the champions aren't using it at the Wobbly Pop |
| Middle | The Moosebrew Mug | `The Moosebrew Mug, C Division.` | Two litres, etched moose, slightly sticky. A note on the shelf: `PLEASE RETURN CLEAN. YOU KNOW WHO YOU ARE.` |
| Bottom | The pike | `Pike, Esox lucius, thrown 14 February 1981, Lakers vs Lumber Kings.` | Port Ainsley fans threw a frozen pike after the first goal. Gus had it mounted. It looks surprised |
| Bottom | The Shed bell | `Bell from the Mill Road Shed. Rung for every home win since 1952.` | Brass, the size of a mixing bowl. Old Pete takes it out of the case after every Lumber Kings home win and rings it in the lobby. It goes back the same night |
| Bottom | The 1988 pennant | `Millbrook Peewee B, Valley Champions 1988.` | Felt, faded green |
| Bottom | The figure skate | `First carnival, Millbrook Figure Skating Club, 1975.` | One small white skate, sequins on the lace |
| Bottom | The empty hook | `Reserved.` | A hook with nothing on it. Gus said it was for "the next thing worth keeping." The player can put something here (a puck from their own first goal, a championship) |

#### The mural: *Winter on the Mill Pond* (1976)

Painted by the Millbrook High art class under Mrs. Agnes Mulroney, who
taught art for thirty-one years and is now the Valley Rocks Bonspiel draw
master (`RINK_SIM.md`). It shows the town skating on the frozen mill pond on
a winter afternoon, and every figure is somebody.

| Detail | Who or what |
| --- | --- |
| The girl in the red toque, doing a sit spin | Bev Kowalchuk, aged 17, painted by Bev Kowalchuk, aged 17. She denies it. She's the only figure with properly sharpened skates |
| The three-legged skater | Two students painted the same skater from opposite ends and met in the middle. One of them was Dale Huffman, now commissioner of the Valley Beer League. He has never said which leg was his |
| The dairy truck on the far bank | The Millbrook Dairy truck that Ronnie Haverstock would drive two years later |
| The skaters in buffalo plaid | The 1976 Lumber Kings, playing shinny |
| The dog chasing a puck | Rascal, the Mulroneys' dog, who chased every puck in Millbrook for fourteen years and is remembered on seat A-9-3 |
| The mill and the church steeple | Both still standing on Main Street |
| The water stain in the sky | From the 1991 roof leak. It is shaped exactly like Florida. The town calls it Gus's Florida, and Gus moved there |

| Worn | Repaired | Renovated |
| --- | --- | --- |
| Faded, the stain spreading, a corner scuffed by hockey bags | Cleaned, the corner protected by a rail | Restored by a conservator from Wendover College ($4,000). The restorer asks, in writing, whether to correct the third leg and remove the stain. Keeping both is the town's choice; "fixing" either is a keepsake removal |

#### Lobby ages

| | Worn | Repaired | Renovated |
| --- | --- | --- | --- |
| Look | Tile cracked, panelling scuffed, frames crooked, index-card captions, trophy case half lit | Tile patched, frames straightened, hand-lettered captions, case fully lit, tarp on one wall during work | New floor, warm LED light, the photos laid out as a walk from 1952 to now with RinkOS labels, the trophy case restored on a new base, Bev's sharpening window |
| Keeps | Every photo, the plaque, the payphone, the Rules of the Rink sign | Same | Same, plus the old wooden sign letters mounted over the doors inside |
| Restores | | The trophy case bulbs, the Champions Board | The mural, the trophy case, the 1979 photo (re-matted in gold) |
| Replaces | | Notice board cork | The front desk, benches, flooring, ceiling |
| Fight to keep | | | The upside-down 1999 photo, the payphone (now a photo spot: lift it and Moose's voice says "Moose knows. Call your mother."), the blank 2005 frame |

### 1.3 The snack bar: the Hot Stove (`concession`)

Named for the hot stove league, where hockey people argue all summer. A
counter, a fryer, a cooler, a popcorn machine, and the coffee machine that
the town considers the most important piece of equipment in the building.

**On the walls**

| Piece | What it is |
| --- | --- |
| The GNHL banner | A Moosebrew banner from 1981, 4 m wide: `MOOSEBREW LAGER, OFFICIAL BEER OF THE GRAND NORTHERN HOCKEY LEAGUE`, with the eight club logos of 1981 (Kingsport, Bramford, Ste-Colette, Northgate, Marrow Bay, Fairhaven, Granite City, Redstone). The Sunvale, Lake Ostrander and Silverton logos have been added since as stickers. The Loons sticker is upside down. This is the "faded banner above the snack bar" in `LORE.md` |
| The Moosebrew clock | Round, with a moose whose antlers are crossed sticks. Runs seven minutes fast, on purpose, since 1996, so the Late Ice League gets on the ice on time |
| The menu board | Brown felt with push-in white letters. See below |
| The flip sign | On the coffee machine, a hinged card: `COFFEE MACHINE IS: WORKING / NOT WORKING`. At WORN it is on NOT WORKING. Fixing the machine flips it, and the Clarion notices |
| Puckhead Pizza sign | `PIZZA BY THE SLICE. DELIVERED IN UNDER TWO PERIODS.` (once the Puckhead deal is signed) |
| The tip jar | A pickle jar labelled `DORIS RETIREMENT FUND`, holding about $31 in coins at the start. Earl says she's not retiring. It feeds the `PROSHOP.md` raffle |
| Health permit | Framed, district health office, renewed after each inspection. At WORN the latest date is one week ago, which is lucky |

**The menu board, exact text at WORN**

```
THE HOT STOVE
COFFEE ............ 2.00
HOT CHOCOLATE ..... 2.50
TEA ............... 2.00
FRIES ............. 4.00
  W/ GRAVY ........ 5.00 (EARL'S GRAVY)
HOT DOG ........... 3.50
POPCORN ........... 2.00
CHIPS ............. 1.50
BAR ............... 1.75
PIZZA SLICE ....... 4.50 (WHEN GINO'S HERE)
THE HAVERSTOCK .... 3.00 (HOT CHOC + 14 MARSHMALLOWS)
NO FRIES DURING THE ANTHEM. THE FRYER IS LOUD.
```

Two letters are missing, so it reads `HOT CHOC LATE`. Nobody fixes this,
because it's true at public skate.

| Worn | Repaired | Renovated |
| --- | --- | --- |
| Grease-dark tile, the felt menu with missing letters, the dented coffee machine | New fryer and cooler, the coffee machine fixed (or a Double-Double machine with their sign), menu letters replaced | A proper canteen with a pass-through to the hall, a printed menu board in club colours. Keeps: the GNHL banner (cleaned, framed behind acrylic), the clock (and whether it stays seven minutes fast is a keepsake choice), The Haverstock on the menu, the felt board moved to the hall as a relic |

### 1.4 Skate rental and the pro shop window (`pro_shop`)

The rink's own counter, under the mural: rental skates, the lost and found,
a till for public skate admissions.

| Piece | Story |
| --- | --- |
| The skate cubbies | Plywood pigeonholes, sizes painted in harvest gold from junior 8 to adult 13. Size 9 has a sticker: `BEV SAYS SHARPEN ME` |
| The Wall of Shame | Polaroids of people who returned rental skates late, with dates. The oldest is from 1981. One is Big Gord, who returned his three days late and sold the rink a truck while he was there |
| Lost and found bin | A wooden crate stencilled `LOST`, with a clipboard inventory (`lost_and_found`). Mittens over a month old go to the mitten tree at Christmas |
| The counter bell | A brass desk bell with `RING FOR GUS` on a strip of tape. At REPAIRED the tape says the player's name, in Dylan's handwriting |
| Rental price card | `SKATES $5. HELMETS FREE. PLEASE GIVE THEM BACK.` |

At RENOVATED this becomes **Bev's at the Rink** (`PROSHOP.md`): a sharpening
window with a small Old Bertha's cousin, a stick rack, and the Wall of Shame
moved to the side wall, intact.

### 1.5 Washrooms (part of `lobby`)

Harvest-gold tile, brown stall partitions, a hand dryer installed in 1987
that is louder than the goal horn.

| Piece | Text or story |
| --- | --- |
| Hand dryer sign | `WARNING: HAND DRYER. CHILDREN MAY CRY. ADULTS MAY TOO.` |
| The mirror in the men's | Cracked in 1992 by a celebrating Lumber King. The crack runs exactly like the valley road, and somebody has marked the five towns on it in nail polish: Millbrook, Harlow Falls, Kessler, Port Ainsley, Duncannon. Kids use it to explain the region map |
| Stall graffiti | `KESSLER SUCKS`, corrected underneath to `KESSLER SUCKS (RESPECTFULLY)`, then `MILLBROOK SUCKS`, corrected to `MILLBROOK SUCKS LESS SINCE THE NEW OWNER` (this line appears once the ice rating passes 60) |
| Out of order signs | Laminated, dated in marker, reused for years: `OUT OF ORDER 3/11` with three older dates crossed out |
| Handwashing poster | District Health Office, 1999: a cartoon beaver washing its paws for twenty seconds. At RENOVATED the beaver is kept, framed |

| Worn | Repaired | Renovated |
| --- | --- | --- |
| A running toilet (you can hear it from the lobby), one stall out of order, a dryer that shrieks | Flush kits fitted, partitions repainted, the signs come down | New fixtures, a family washroom, quiet dryers. The cracked valley mirror is a keepsake: kept in the men's, or moved to the lobby with a label (`The Valley Road, 1992. Not to scale.`) |

### 1.6 Home dressing room (`locker_home`)

The Lumber Kings' room, shared with whoever has the home side of a beer
league game. Wooden benches round three walls, hooks above, a rubber floor,
a skate-sharpening closet in the corner that belongs to Old Pete Vachon.

**On the walls**

| Piece | Text or story |
| --- | --- |
| The stencil over the door | `LEAVE IT BETTER THAN YOU FOUND IT`, painted by Gus in 1977 in Lumber Kings red. Unofficial addition below: `OR AT LEAST LEAVE` |
| Captains' board | A varnished board with every Lumber Kings captain since 1952 in gold leaf. The 1974 to 1977 entries are in a different gold because the first painter moved to Kessler |
| The 1979 ceiling tile | Every member of the 1979 team signed the ceiling tile above the door. `1979 ALDOUS CUP, WE ALL SIGNED, DON'T PAINT IT, GUS.` Gus didn't |
| Stall 14 | The stall Ronnie never used (he was beer league), now given each season to the Lumber King the room votes most likely to make the show. A small brass plate: `14` |
| The win tally | Pencil marks on the sharpening closet door: Lumber Kings wins over Kessler on the outside, losses on the inside, "where you don't see them on the way out." The inside is longer |
| Two Masks | A signed copy of Walter Brzezinski's goalie book on a shelf above the goalies' stall (`two_masks`): `To the Millbrook goalies. One for you and one for me. W.B.` |

**Objects with history**

| Object | Story |
| --- | --- |
| The tape ball | A ball of used Gripley's tape that every winning team in the room has added a strip to since 1983. It's about 60 cm across now and sits on a stool in the corner like a pet. Its official name is The Gripley. Earl started it after the Flood Crew's first win |
| The Gripley's bucket | A bucket of half-used tape rolls, as in every dressing room in the valley |
| Old Pete's drawer | The skate sharpener's drawer in the closet, where Old Pete keeps the 1979 Cup photo (`TEAMS.md`) and a jar of every Lumber King's last pair of laces |
| The radiator | Cast iron, painted six colours over the years, the only warm thing in the room at WORN. Players hang wet gloves on it, and the smell is part of the room's history whether anybody likes it or not |

| | Worn | Repaired | Renovated |
| --- | --- | --- | --- |
| Look | Benches split and taped, hooks missing, a cold shower, mould in the shower corner, a single bulb flickering | New bench slats (one unpainted), hooks replaced, the shower hot, mould gone | Lumber Kings red and buffalo plaid accents, wood stalls with nameplates, a skate-drying rack, a proper sharpening room, a whiteboard |
| Keeps | Everything | Same | The stencil, the captains' board, the 1979 tile (cut out and framed in the new ceiling), stall 14, the tally door (kept as the door of the new sharpening room) |
| Fight to keep | | | The tape ball. Renovation crews always want to throw it out. The room will not play well until it is back |

### 1.7 Visitors' dressing room (`locker_away`)

The same room as the home side, built the same year, and somehow always
three degrees colder. The boiler's return pipe runs under one floor tile by
the drain, which is the only warm spot.

| Piece | Text or story |
| --- | --- |
| Visitors' sign | On the door, enamel: `VISITORS. WELCOME TO MILLBROOK. PLEASE LEAVE THE ROOM AS YOU FOUND IT (THAT IS, COLD).` The last two words are a later addition |
| The graffiti wall | Fifty years of visiting teams (`graffiti_visitor`): Kessler 1979, the pike drawing, the Toothbrush Incident |
| Shower sign | `THE VISITORS' SHOWER IS ON THE LEFT. IT IS ALSO ON THE RIGHT. NEITHER IS HOT.` |
| The warm tile | An arrow in marker: `STAND HERE, IT'S WARMER.` |
| Hap Doyle's notebook | Left on the bench after the first Kessler visit at Senior AAA (`hap_doyle_plans`). Returning it is a small quest |

| Worn | Repaired | Renovated |
| --- | --- | --- |
| Cold, the drain slow, one bench section missing (`ART.md`'s missing seat slat) | Hot water, the drain cleared, the bench rebuilt | Matches the home room in neutral grey and navy. Keeps the graffiti wall behind a clear acrylic sheet with a sign: `VISITORS' HISTORY. ADD YOURS BELOW THE LINE.` A fresh panel below lets new teams keep writing |

### 1.8 Ref room (`ref_room`)

A former broom closet off the corridor between the dressing rooms. The word
`REFEREES` is painted over the word `BROOMS`, and the old letters show
through in the right light.

| Piece | Text or story |
| --- | --- |
| The rulebook | GNHL rules, current edition, with a coffee ring on Rule 6.2 (`gnhl_rulebook`) |
| The incident book | `ref_incident_book`: a running record that tells the player what the officials think of the ice |
| The whistle jar | A pickle jar of spare whistles, all with tooth marks |
| The cruller box | A Double-Double box, usually with two crullers from the Night Owls' Shauna Reid |
| The one hook | There is exactly one coat hook for three officials. The incident book asks for a second hook, then a chair, then a mirror, then a heater, in that order. Each is cheap and the refs remember who gave it to them |
| The sign on the inside of the door | Gus's: `WE CAN'T HEAR YOU.` Someone's addition: `WE CAN, ACTUALLY.` |

At RENOVATED the ref room becomes a proper officials' room off the new
corridor. The `BROOMS` door is kept as its door.

### 1.9 Benches, penalty boxes and the timekeeper's box (`benches`, `penalty_boxes`)

| Piece | Story |
| --- | --- |
| `EARN IT` | Painted inside the home bench boards in 1974, faded to `EAR  IT` at WORN. Repainted correctly at REPAIRED, then repainted wrong again by a volunteer at REPAIRED's second coat (`ART.md`: the wrong red) |
| The bench gate penny | A 1974 penny wedged in the home bench gate latch to stop it rattling. Replacing the latch is fine; throwing away the penny is not |
| The penalty box library | A shelf of paperbacks in the home penalty box since Moose Kowalczuk left a mystery novel there in 1984 (`moose_memoir`). Moose's note is taped inside the shelf: `The butler didn't do it. Be good.` The rule, on a card: `TAKE ONE FOR YOUR TWO MINUTES. BRING IT BACK NEXT TIME YOU'RE BAD.` Books include a Dickens with a puck mark through it, a fishing guide, and three copies of *Moose Knows* |
| Timekeeper's box | Between the penalty boxes. Doreen Vachon (Old Pete's wife) runs the clock and plays a Casio keyboard set to "Organ 2": three songs and a slightly passive-aggressive version of the Kingsport dirge when the ref misses a call. The goal horn is an air horn off a Kessler Pulp & Paper log truck, "acquired in 1979" |
| The HOME flip chart | Because the HOME half of the scoreboard is dead (1.10), Doreen hangs a flip chart of big painted numbers 0 to 15 off the timekeeper's box. She has never needed the 15 |

Renovated: new benches and boxes with seamless glass (`RINK_SIM.md` 5.8).
Keeps: the library (on a proper shelf with a reading light), the penny, the
air horn (wired to the new scoreboard's goal button), the flip chart (hung
in the hall).

### 1.10 The stands (`stands_bench`, `stands_box`)

Two sides. The east side (`stands_bench`) is eight rows of wooden benches on
steel frames, painted harvest gold, with radiant heaters over them. The west
side (`stands_box`) is ten rows of 1974 moulded seats in alternating rows of
harvest gold and burnt orange. The north end is a standing rail, the
"rafters end," where the loudest people stand.

**Signs and boards**

| Piece | Text |
| --- | --- |
| Heater buttons | On each pillar: `PUSH FOR HEAT (10 MIN). PUSH AGAIN, NOTHING HAPPENS, IT'S A TIMER.` |
| Section letters | Painted on the end of each row in cream: A to F on the west side. Section C is missing its letter and everybody calls it Section See |
| The scoreboard | A 6.5 x 3 m Maple Tire & Muffler wall board (`ART.md`): `MILLBROOK` across the top, `MAPLE TIRE & MUFFLER: WE FIX WHAT WINTER BREAKS` along the bottom. The HOME half has been dark since a puck hit it at the 2003 home opener. Fixing it ($5,000) is one of the most satisfying jobs in the game |
| The glass at the north end | Two panels have been "temporary" since 1979: scratched polycarbonate held at the top by Gripley's tape. The 1979 programme asked fans not to lean on them |

**Seat plaques** (small brass plates on seat backs, west side)

| Seat | Plaque |
| --- | --- |
| C-4-7 | `Harold Penner sat here and shouted "SKATE!" for thirty years.` |
| B-1-1 | `Reserved for Gus. He never sat down.` |
| E-6-14 | `For Ronnie's mum, who watched every Tuesday.` |
| A-9-3 | `In memory of Rascal, a good dog, who was not allowed in.` |
| F-2-12 | `Donated by the Ice Holes. This is not a joke. Okay it's a bit of a joke.` |

**The board ads (24 panels at WORN)**

The old ads on the dasher boards (`RINK_SIM.md` 5.5: expired deals, re-sign
or replace). Each is a painted plywood panel faded to pastel.

| Panel | Sponsor | Text | Painted |
| --- | --- | --- | --- |
| 1 | Maple Tire & Muffler | `WE FIX WHAT WINTER BREAKS` | 1976 |
| 2 | Moosebrew Lager | `BREWED COLD. SERVED COLDER.` | 1974 |
| 3 | Big Gord's Trucks | `BIG GORD WON'T LET YOU WALK`, with a 1978 Big Gord with a lot more hair | 1978 |
| 4 | Grizzly Gas & Go | `FILL UP BETWEEN PERIODS` | 1980 |
| 5 | Millbrook Dairy | `MILK: WHAT RONNIE DRANK` | 1980 |
| 6 | Penner Hardware | `IF WE DON'T HAVE IT, HAROLD WILL ORDER IT` | 1974 |
| 7 | Bev's Edge & Tape | `SKATES SHARPENED / OPINIONS FREE` | 1979 |
| 8 | Millbrook Legion, Branch 112 | `FISH FRY FRIDAYS. LEST WE FORGET.` | 1981 |
| 9 | Hearthstone Furnaces | `WARM HOMES. COLD ICE.` | 1985 |
| 10 | Duffy Bros. Plumbing & Heating | `NUMBER ONE IN THE NUMBER TWO BUSINESS` | 2004 |
| 11 | Gilchrist & Sons Funeral Home | `WE'LL BE THE LAST TO LET YOU DOWN` | 2012 |
| 12 | Haverkamp Family Dentistry | `WEAR A MOUTHGUARD. WE MEAN IT.` | 2015 |
| 13 | The Wobbly Pop Tap & Grill | `WINGS, PINTS, AND THE GAME ON` | 2019 |
| 14 | Hat Trick Tavern | `PITCHERS AT 10:45` | 2008 |
| 15 to 24 | (blank) | Painted over in cream, one with `YOUR AD HERE. CALL GUS.` | Various |

**Objects with history**

| Object | Story |
| --- | --- |
| The Millbrook bank | Board panel N7, behind the north net, a stick length left of the post. The dead spot (`LORE.md`). Someone painted a small white milk bottle on the kickplate there years ago. Nobody knows who; Ronnie says it wasn't him (`haverstock_memoir`). The milk bottle is a keepsake, and so is the dead board itself |
| The goal judges' cages | Two wire-mesh booths behind each end, with a red light on a pole. The north one has a sticker: `LIGHT IS ON A TIMER. PHANTOM GOALS NOT OUR PROBLEM.` |
| The rafters end rail | A steel rail worn shiny by forty years of elbows. An old man, Stan Szymanski, stands at the same spot every Lumber Kings game and has since 1974. He's the man the Ledger saw crying (`ledger_last_word`) |

| | Worn | Repaired | Renovated |
| --- | --- | --- | --- |
| Look | Broken seats roped off, chipped paint, heaters that work on half the pillars, faded board ads | Seats fixed (some in a slightly different orange), railings repainted, heaters working, new ads in the old paint style | New seats in navy, red and white, glass railings, a centre-hung scoreboard (`ART.md`), new ad panels |
| Keeps | Everything | Same | The seat plaques (moved to the new seats, same seat numbers), one row of original harvest-gold seats at the top of section A as a "heritage row," Walt's spot on the rafters rail, the milk bottle on N7 |
| Fight to keep | | | The heritage row (people pay more for it, which surprises the business plan), and the dead board: fixing it is possible and the town will be upset (`LORE.md`) |

### 1.11 The rafters (`lighting`, `roof`)

Steel trusses, 48 metal halide lamps (`RINK_SIM.md` 3.5), and everything the
town has ever wanted to hang above the ice.

**Banners, left to right from the south end**

| Banner | Look | Story |
| --- | --- | --- |
| `14 HAVERSTOCK. MILLBROOK'S OWN. 1979.` | Hand-sewn felt in Millbrook Dairy green and white, with his milk-uniform photo framed beside it on the end wall | The retired number (`LORE.md`). The hook has been replaced three times: 1994, 2005 and 2017. The third hook is a Kessler Pulp & Paper log chain, which Kessler has noticed |
| `LUMBER KINGS: ALDOUS CUP 1956` | Red felt, black lettering, moth holes | The Shed era |
| `LUMBER KINGS: ALDOUS CUP 1979` | The newest-looking old banner, because Gus took it down every summer to keep it out of the sun | |
| `NSHA MILL DIVISION CHAMPIONS: 1956, 1966, 1979, 1988, 2001` | One banner, years added in different felt | 2001 is in a slightly wrong red |
| `MILLBROOK MIDGET AA, VALLEY CHAMPIONS 1994` | Green | Rick Saucier's 61 goals. The Moose Knuckles touch their sticks to it from the bench, which is why it has tape marks |
| `MILLBROOK HIGH MALLARDS, VALLEY HIGH SCHOOL CHAMPIONS 2009` | Mallard green and gold | Coach Bernie Ostrowski's only title, mentioned in every phone call about late payment |
| `2004-05: SEASON NOT PLAYED. MILLBROOK ASKED.` | Home-made, sewn by Larry Piche's mother on a bedsheet, in Mallards green | The town's favourite banner. It copies the Puckworth Cup engraving |
| `MILLBROOK FIGURE SKATING CLUB, 50 CARNIVALS, 1975 TO 2025` | Pale blue satin | Hélène Arsenault had it made. It is the only banner that's ironed |
| Sponsor banners from the 1970s | Maple Tire, Moosebrew, Big Gord's earliest (with hair), Grizzly Gas, faded to pastels (`LORE.md` 6) | Replaced as sponsors re-sign; the originals go to the hall |

**Objects with history**

| Object | Story |
| --- | --- |
| The Rafter Puck | A puck has sat on top of truss 6 since a deflection in 1987. Earl says it's Ronnie's from the 1979 final, which is impossible, and Earl knows it. The lighting renovation crew finds it, and it goes in the trophy case, or back up on the truss, the player's call |
| The mitten | A single red mitten hangs from truss 3, thrown in 1999 when a Lumber King scored a hat trick and someone did the Fairhaven thing, badly |
| Linesman | A pigeon who lives in the rafters, named by Earl for "never being where he should." He has a nest above the south lamps. At RENOVATED he gets a bird box on the outside wall, which he ignores |

| Worn | Repaired | Renovated |
| --- | --- | --- |
| Dim (500 lux), one lamp dead every two weeks, banners faded and crooked, rust on the steel | Lamps and ballasts replaced, banners straightened | LED at 1,000 lux, the steel painted, banners cleaned and lit by their own small spotlights; the Haverstock banner gets a proper rigging point. Keeps every banner. The 1970s sponsor banners can go to the hall (no reaction) or stay (a small Community bonus) |

### 1.12 The office (`office`)

Gus's office for forty-nine years. A mint-green steel desk, a window onto
the ice that fogs over, a corkboard, a filing cabinet that only opens if you
lift the drawer as you pull.

| Piece | Story |
| --- | --- |
| The 1998 calendar | A Grizzly Gas & Go calendar for 1998, still on the wall, open at whatever month it is. Gus kept it because the days come round again (1998's dates fall on the same weekdays as 2009, 2015 and 2026), and because it has a nice picture of a truck. The envelope under the mat is written on one of its pages |
| The corkboard | The week's goals as Gus-style sticky notes (`RINK_SIM.md` 1.6), the P&L when it prints, the postcards from Florida (`gus_postcards`) |
| The ice grid | A whiteboard with coloured magnets for each organisation's slots. At WORN the Minor Hockey magnets are in a margarine tub labelled `HARLOW FALLS (FOR NOW)` |
| The rate sheet | A photocopy of the valley rinks' prime ice rates that every manager secretly shares, with Harlow Falls' rate circled and `!!!` beside it |
| The phone | A beige rotary desk phone. When it rings, it's a contract, a complaint or Gus. The player can't tell which until they answer, which is the fun of it. A thumbtack holds a card: `DUKES DON'T CALL HERE. THE RED PHONE IS IN DUNCANNON.` |
| Gus and Doris, 1977 | A framed photo of a young Gus with a three-year-old Doris, both very clean |
| The cash box | Grey steel, with a combination written on the bottom in Gus's hand, which is not the combination |
| The bookshelf | The trade journal (`nro_journal_*`), Szabo's Almanac, Teague's book, the Flatley brochure in the drawer, a Zambelli parts catalogue from 1988 |
| The radio | Tuned to CKVL 1340, Bernie Szabo's voice at game time |

| Worn | Repaired | Renovated |
| --- | --- | --- |
| Paper everywhere, a dead fluorescent tube, a space heater that trips breaker 9, the fogged window | Cleared, painted, a laptop with the spreadsheet (T1 office tier) | A glass-fronted office with a clear view of the ice, the booking software screen, a proper chair. Keeps the 1998 calendar, the photo of Gus and Doris, the rotary phone (still the main line, now with a light), the corkboard |

### 1.13 Plant room (`plant_room`)

The room `RINK_SIM.md` asks Rink environment to build: two Nordale RC-4s, the
chiller, the receiver, the glycol pumps (`ART.md` plant props). The decor is
how it becomes Gus's room.

| Piece | Story |
| --- | --- |
| The door of notes | Gus's sticky notes, index cards and torn binder pages, layered on the plant room door, with the binder taped to it (`gus_binder`). Top note: `Every morning. Oil first. Number 1 drinks.` |
| Number 1's chalk | On No. 1's belt guard, in chalk: `No. 1 (DRINKS)`. On No. 2's: `No. 2 (FINE)` |
| Nameplates | Riveted brass on each compressor: `NORDALE REFRIGERATION MACHINERY CO. MODEL RC-4. SERIAL 7403-118` (No. 1) and `7403-119` (No. 2) |
| Days since sign | A flip-number sign: `DAYS SINCE No. 1 TRIPPED: [ 3 ]`. The record, painted below in red: `41 (1996)` |
| The log book | Open on a steel desk, the pencil on a string (`marg_red_pen` once Marg arrives) |
| The chair | A glycol drum with a cushion on it, the cushion embroidered `GUS` by somebody's aunt |
| The radio | A transistor radio on the shelf, tuned to CKVL, held together with Gripley's |
| The ear defenders | On a nail, with a note: `WEAR THESE. I DIDN'T. WHAT?` |
| The thermometer collection | Eleven dial thermometers on a board, every one that Gus ever replaced, with dates. One reads -4 permanently and is labelled `HONEST ONE` |
| The ammonia pamphlet | `pamphlet_ammonia`, on the inside of the door, with Gus's note: `He asks for the log. Have the log.` |

| Worn | Repaired | Renovated |
| --- | --- | --- |
| Machinery-green enamel, frost on the suction lines, oil stains, the door of notes | Fresh paint, yellow guards, the eyewash and detector fitted, notes moved into the binder | Navy and charcoal, a control room window, screens. Keeps the door of notes (the old door rehung on the control room wall as a noticeboard), the thermometer board, the days-since sign (fight to keep it next to the digital controller, which also counts the days and is less fun) |

### 1.14 Resurfacer bay (`zamboni_bay`)

Doris's room. Concrete, a floor drain, the snow pit door, the hot water tank,
the edger in the corner, and the smell of warm oil and wet wool (`LORE.md`).

| Piece | Story |
| --- | --- |
| `DORIS` | Painted over the bay door in cream and blue, the same colours as her tank, in letters a metre high, by Earl in 1984 |
| Earl's tally wall | Tally marks in black marker on the block wall beside the bay door, in groups of five, one for every flood Earl has driven since 1983: 9,412 at the start. When Earl comes back, he adds to it. Nobody else may |
| DORIS'S SHOES | The two wooden blade-change blocks Gus made (`RINK_SIM.md` 4.7), labelled in marker |
| Gus's towel hook | A hook by the drain: `OLD TOWELS CLEAN THE BAY.` |
| The parts drawers | A steel cabinet, every drawer labelled `DORIS`, one labelled `DORIS (MISC)`, one `DORIS (DON'T)` (it holds the old points and condenser) |
| The hot water tank sign | `55 OR DON'T BOTHER.` |
| The dealer poster | A 1974 Zambelli poster of a Model 525 on gleaming ice: `THE ZAMBELLI BRAND ICE RESURFACER. ACCEPT NO SUBSTITUTES.` |
| The Flatley poster | A Flatley F-9 poster from 1971, used as a dartboard. The darts are all near the battery |
| The radio | On a shelf by the door, CKVL; Doris "likes it" (`earl_notebook`) |
| Frank Zambelli | A small framed photo of Frank Zambelli with a battery candle in front of it, placed by Earl. Not a joke. A little bit a joke |

| Worn | Repaired | Renovated |
| --- | --- | --- |
| Snow piled in the pit, a slow drain, oil stains, a dim bulb | The drain and pit heater fixed, the floor painted | A wash bay, a level pad, a towel rack and a blade sharpener room (`RINK_SIM.md` 5.8). Keeps the `DORIS` lettering (repainted in her restoration colours if she's restored), Earl's tally wall (the new wall is built around it and the patch is left unpainted with a small light), Doris's shoes, the Zambelli poster. The Flatley poster stays even if the rink buys a Flatley, which is funny |

### 1.15 Upstairs: Mezzanine Hall (`community_hall`)

A proposal for Rink environment: a wood-panelled room above the lobby with a
long window over the south end of the ice. It's where the town happens when
there's no hockey: Legion fish fries, Rotary breakfasts, birthday parties on
paper tablecloths, the Lumber Kings' booster club, Doreen Vachon's Tuesday
piano lessons, the Valley Beer League's annual general meeting (held in the
hall, minutes kept in the binder, over in eleven minutes). It also gives
the player a place to read, and a dry-floor venue for summer events.

| Piece | Story |
| --- | --- |
| THE TABLE | A plain steel folding table, stencilled `THE TABLE`, with a brass plate: `The Puckworth Cup stood here, centre ice, 12 March 2005.` Still used for bingo. The Mallards eat their end-of-season dinner off it |
| The piano | An upright said to be the Hotel Lindell's piano, bought at auction in 1978. It is not. The Lindell's piano is still in the Lindell. Nobody in Millbrook will hear this |
| The 1979 victory dinner | A long panoramic photo of the hall in 1979, everyone in plaid, the Aldous Cup on the head table, the milk crates stacked by the door |
| The bookshelf | The town's hockey library: *Grand and Northern*, *Off the Dead Spot*, the VMHA coach manual, *The Little Zambelli Brand Ice Resurfacer That Could* in the kids' corner on a rug |
| Bonspiel trophies | The Valley Rocks Bonspiel trophies once curling comes (`RINK_SIM.md` 5.3), and a pair of curling brooms crossed on the wall |
| The 50/50 drum | The booster club's wire drum for 50/50 tickets, with a sign: `THE DUKES' 50/50 PAID FOR A HOUSE. OURS PAID FOR A FRIDGE.` |
| The bar | Two Moosebrew taps, dry until the liquor licence. At WORN a hand-written sign: `TAPS ARE DECORATIVE UNTIL FURTHER NOTICE.` |
| Stacking chairs | 120 of them, mint green, stamped `MILLBROOK P&R 1974`. Seven are orange and nobody knows why |

| Worn | Repaired | Renovated |
| --- | --- | --- |
| Panelling dark, the window fogged, carpet tiles curling, a smell of old coffee | Carpet replaced, the window cleared, a working kitchen | A proper function room for rentals (weddings, `RINK_SIM.md` 5.7 dry floor events), the hall's own small canteen pass-through. Keeps THE TABLE, the piano, the photos, the orange chairs |

### 1.16 Bev's Edge & Tape (`bevs_shop`), the walls only

`PROSHOP.md` has the shop. For decor: the photo wall above the counter holds
Millbrook team photos from 1971 on, with Bev in most of them, including the
1979 Lumber Kings photo with Bev at the end of the back row holding a
sharpening stone like a trophy. Her chalkboard of hollows (`bev_chalkboard`)
hangs over Old Bertha. A framed one-dollar bill sits by the till: the first
dollar she took in 1979, and beside it a newer frame waiting, she says, for
"the dollar the arena sold for. I'd like it as a souvenir." If the player
gives her the dollar (the bill from the sale, in the office cash box), Bev's
relationship jumps and the frame is filled.

---

## 2. The keepsakes

The town's list. Each is a prop (section 6) with the keep, restore or remove
choice (0.2) at renovation.

| Keepsake | Room | Restore cost | Removal reaction |
| --- | --- | --- | --- |
| The Mallards and the Cup photo, the letter and the follow-ups binder | lobby | $400 (reframe, light) | -15 Community, a visit from Larry Piche, who is very polite about it, which is worse |
| Ronnie's number 14 banner and the milk-uniform photo | rafters | $600 (new rigging) | -15 Community, and Ronnie stops coming to Thursday old-timers for a month |
| The trophy case and its contents (including the freezer on breaker 14) | lobby | $2,000 (restore the case) | -10 Community; unplugging the freezer is a separate -5 and a Clarion column |
| The mural, three legs and Gus's Florida | lobby | $4,000 (conservator) | -8 for painting over the leg, -3 for removing the stain, -12 for painting over the mural |
| The Millbrook bank (board N7) and the milk bottle | stands | $0 | -10 Community, and Earl won't speak to the player for two weeks |
| The Moosebrew clock, seven minutes fast | concession | $80 | -3 for setting it right, which the Late Ice League also feels on the schedule |
| The tape ball | locker_home | $0 | Lumber Kings morale down until it's back |
| Earl's tally wall | zamboni_bay | $150 (light and frame) | Earl quits for a week |
| The penalty box library | penalty_boxes | $120 (shelf and lamp) | -3; a letter from Moose's agent |
| The dedication plaque | lobby | $200 (polish) | Not removable. Renovating the roof adds the final brass strip |
| The 1979 ceiling tile | locker_home | $250 (cut out and frame) | -5 |
| THE TABLE | community_hall | $0 | -5; the Mallards hold their dinner at the Legion out of protest |
| The days-since sign | plant_room | $0 | None from the town. Marg is quietly sad |
| The Cup Tree | parking_lot | $0 | Not removable (the town owns that strip of land, it turns out) |

---

## 3. Literature and readables

### 3.1 How reading works

Readables are objects the player can pick up or look at closely (a binder, a
programme in the trophy case, the graffiti on a wall). They open in a reading
view: the text, a picture of the object, and a short line of what the player
noticed. They are always optional and never timed, which keeps them part of
the relaxing side of the game: you can sit in the penalty box at 23:30 after
the last flood and read Moose's memoir with the lamps humming.

Each readable has `hooks` that the game can act on:

| Hook type | What it does | Example |
| --- | --- | --- |
| Tutorial in fiction | Teaches a job the way `RINK_SIM.md` 1.6 asks: no pop-up that a note could replace | Gus's binder, the Zambelli manual |
| Mini game hint | A procedure detail or a number the mini game uses (blade height, plug gap, oil level) | Manual excerpts, Marg's log |
| Tool tip | Points to a measurement upgrade and what it changes | The trade journal on the IR gun and refractometer |
| Lore | GNHL and valley history for loading screens and broadcast trivia | *Grand and Northern*, the guestbook |
| Story thread | A small arc that pays off later | Gus's postcards, Larry's follow-ups, the ref room requests |
| Path unlock | Opens or strengthens a career path | The coaching manuals for a Coach path, the scouting guide for the GM side |

`unlock` is `null` for readables present at the start; otherwise it says
when the readable appears. `location` uses the room ids in 0.3.

### 3.2 The 40 readables

Full excerpts are in `data/world/readables.json`. Grouped by what they do:

**The rink teaches you (start of the game)**

| Id | Title | Found | Does |
| --- | --- | --- | --- |
| `gus_envelope` | The Envelope Under the Mat | lobby | The first object in the game; points to the binder |
| `gus_binder` | The Binder | plant_room | Plant rounds, oil, glycol, the people. The breaker 14 mystery |
| `zambelli_525_manual` | Zambelli Model 525 Operator's and Service Manual | zamboni_bay | Flood pattern, blade height, plug gap |
| `nordale_manual` | Nordale RC-4 manual | plant_room | Oil grade, valve job symptoms; Gus and Marg argue in the margins |
| `pamphlet_ammonia` | That Smell | plant_room | The ammonia inspection checklist in fiction |
| `vbl_bylaws` | The Binder (Valley Beer League) | lobby | Dues, the grace period, the league contract |
| `notice_board` | The Lobby Corkboard | lobby | Live board for contracts, events and town life |
| `lost_and_found` | Lost and Found inventory | pro_shop | Daily flavour, items to return |
| `dedication_plaque` | The Dedication Plaque | lobby | The opening date; the roof strip reward |

**The rink teaches you (later)**

| Id | Title | Found | Unlock | Does |
| --- | --- | --- | --- | --- |
| `gus_postcards` | Postcards from Florida | office | Monthly from month 2 | Seasonal reminders; breaker 14 solved |
| `earl_notebook` | Earl's Notebook | zamboni_bay | Earl hired | Soft spots, protecting the bank, hot floods |
| `marg_red_pen` | The Plant Log, Annotated in Red | plant_room | Marg hired | Good logging; belt diagnosis; refractometer |
| `nro_journal_spring` | The Northern Rink Operator, Spring | office | Start | IR gun, temperature targets, thickness |
| `nro_journal_autumn` | The Northern Rink Operator, Autumn | office | November, Year 1 | Glycol maths and instruments |
| `pamphlet_flatley` | Flatley brochure | office | Start, newer edition after an air quality warning | The electric replacement and Earl's veto |
| `bev_chalkboard` | Bev's Chalkboard | bevs_shop | Start | Hollows and their tradeoffs |
| `ref_incident_book` | Referees' Incident Report Book | ref_room | Start | Refs report the ice; the hook-chair-mirror-heater chain |

**Hockey reading**

| Id | Title | Found | Does |
| --- | --- | --- | --- |
| `blue_line_magazine` | The Blue Line | lobby | GNHL news, a short-shift tip; new issue monthly |
| `gnhl_rulebook` | Official Rules of the GNHL | ref_room | Real rules for the Coach path; the Sokolov Rules |
| `program_1979_final` | Aldous Cup Final programme, 1979 | lobby (trophy case) | Lore and the "temporary" glass |
| `program_lumber_kings` | Lumber Kings Gameday | stands_box | The Lumber Kings contract; programme ads to sell |
| `grand_and_northern` | Grand and Northern | community_hall | GNHL history; Millbrook in the Cup's travels |
| `moose_memoir` | Moose Knows | penalty_boxes | The penalty box library's origin |
| `haverstock_memoir` | Off the Dead Spot | community_hall | How to use the Millbrook bank |
| `teague_book` | I'll Do My Best | office | Cash vs profit, net 30, backup goalies |
| `little_zambelli` | The Little Zambelli Brand Ice Resurfacer That Could | community_hall | Kids' book; the flood pattern, sneakily |

**Coaching and the GM side**

| Id | Title | Found | Unlock | Does |
| --- | --- | --- | --- | --- |
| `two_masks` | Two Masks: Goaltending for Young People | locker_home | Start | Goalie coaching: angles, square, recovery |
| `vmha_coach_manual` | VMHA Coach Level 1 Manual | community_hall | Start | Practice plans, line changes, reading style tags |
| `hap_doyle_plans` | Practice Plans (DO NOT REMOVE FROM KESSLER) | locker_away | First Millmen visit | The trap, battle drills; a return quest |
| `valley_almanac` | Szabo's Valley Hockey Almanac | office | Start, new edition each season | Scouting every club's style; the region's rinks |
| `cha_scouting_guide` | Reading a Player: CHA Scouting Field Guide | office | Semi-Pro | What scouts look for; ice affects how players are judged |

**The town talks**

| Id | Title | Found | Unlock | Does |
| --- | --- | --- | --- | --- |
| `clarion_sale` | Off the Boards: Town Sells Arena for a Dollar | lobby | Start | The premise, from the town |
| `clarion_keepsakes` | Off the Boards: Leave the Clock Alone | lobby | First room RENOVATED | Introduces keepsakes |
| `ledger_last_word` | The Last Word: A Night in Millbrook | community_hall | Senior AAA | Harsh, fair reviews that track the renovation |
| `pamphlet_learn_to_skate` | Learn to Skate at Millbrook! | lobby | Start | Public programmes |
| `pamphlet_brokenbone` | Moose Knows: Your Head | lobby | Start | Helmets; the insurance survey |
| `guestbook` | The Lobby Guestbook | lobby | Start | Decades of visitors; the player signs it |
| `mallards_letters` | The Letter, and Twenty-One Follow-ups | lobby | Start | The town's heart; a reply arrives late game |
| `graffiti_home` | Home Dressing Room Graffiti | locker_home | Start | Room history; the Kessler tally |
| `graffiti_visitor` | Visitors' Dressing Room Graffiti | locker_away | Start | The cold room; the warm tile |

### 3.3 Story threads that run through the readables

| Thread | Pieces | Payoff |
| --- | --- | --- |
| Breaker 14 | The envelope, the binder ("Do not ask"), postcard 4 | The trophy case freezer and the frozen Double-Double cup. The electrical inspector flags the circuit; the fix is a dedicated circuit, and the freezer stays |
| Gus in Florida | Monthly postcards | If the rink reaches Great, Gus visits for the home opener, signs the guestbook, and sits in seat B-1-1 for the first time |
| The Mallards' letter | The framed letter, the binder of follow-ups, each March | The Year 5 reply in `PATHS.md` (`w_trustees_reply`): a polite card inviting the Mallards to carry the Cup onto the ice at the Kingsport home opener. The card is framed beside the 2005 letter, and the follow-ups binder gets one last page in Larry's handwriting: `They wrote back.` |
| Hap Doyle's notebook | Left in the visitors' room | Return it and Hap nods. Keep it and the Kessler ice bookings get harder for a season |
| The ref room | The incident book's requests | Each small purchase earns a line of thanks in the book; all four make refs more forgiving of a late flood |
| The three-legged skater | The mural, the restorer's letter, Dale Huffman | Ask Dale and he finally says which leg was his (the middle one) |
| The Rafter Puck | Earl's claim, the lighting renovation | The puck comes down, Earl admits he made it up, and asks for it to go back up anyway |

---

## 4. The other rinks in the valley

Each town's rink should be recognisable in one look, as `WORLD.md` asks. The
decor is how.

**Harlow Falls Municipal Twin Pad (1990s, tidy, plain).** Everything is
laminated. The lobby has a donor wall of engraved bricks, a rules sign with
fourteen rules, and floor arrows to Pad 1 and Pad 2 in two shades of blue.
The Huskies' five-year plan is framed on the wall like a mission statement,
and the Harlow Falls Minor Hockey "Pathway to Excellence" poster shows a
flowchart from Tiny Tykes to the GNHL. Two warm touches: a small bronze plaque to
Dorothy Pruitt, founder of Honest Hockey Co. (`It's fine. She'd want you to
know it's fine.`), and a framed Squalls jersey in the Pad 2 corridor reading
`EMERGENCY MO TEAGUE PLAYED HERE (WEDNESDAYS)`. The Pad 2 gate has a newer
hinge than Pad 1, because of Dale "Transformer" Hughes.

**Kessler Memorial Arena, the Barn (wooden trusses, loud).** Dark wood,
standing room on three sides and a brass band loft over the visitors' bench.
Eleven Aldous Cup banners hang from the trusses, and the newest is from
1998, which the Millmen do not mention. The mill whistle blows for every
Millmen goal, and the smell of Kessler Pulp & Paper drifts in when the wind
is wrong. In the hallway hangs the only photo of Hap Doyle smiling (1996),
under a card: `HE DENIES IT.` The broadcast booth has three pronunciations of
"Kessler" taped above Bernie Szabo's microphone. Rolls of paper towel are
stacked by the door for Port Ainsley games.

**Port Ainsley Lakeside Arena (a lake town).** Nautical: fishing nets and
buoys on the lobby ceiling, a chalkboard by the door with the lake's ice
thickness for anglers (`BAY: 14 IN. POINT: 9 IN. NARROWS: STAY OFF.`), and a
statue of Sturgie, the Sturgeon's seven-foot mascot, whose eyes follow you.
A pair of rubber waders is mounted in the trophy case: the ones the man wore
in 1962 to fish the Aldous Cup out of the lake. A framed Puckhead Pizza box
honours the 1983 goalie who founded it. The Pond Classic photo wall shows
every February game on the frozen lake, and Big Nils Olsen's ice hut is
parked in the lot all winter.

**Frostbank Centre, Duncannon (modern, 5,000 seats, the benchmark).** Glass,
steel and a TeleNorth video board the size of a barn. The concourse has a
"Road to Kingsport" wall of every Duke who got the call, with a red rotary
phone icon beside each name. Barry "Suitcase" Pomeroy's seven stints are on
the wall behind Lorne Pettigrew's desk, with a luggage tag for each. A framed
50/50 cheque (`$212,450: WON BY A NURSE FROM ASHCOMBE, WHO BOUGHT A HOUSE`) and
a case of Big Gord bobbleheads, one per year. Everything is clean and
impressive and, as Merv Tolliver writes, has never once made anybody cry. It
shows the player what RENOVATED can look like at scale, and what it can
lose.

**Duncannon Memorial Gardens (1949, the Foundry, half empty).** The run-down
counterpart. `SAVE THE GARDENS` lawn signs are stacked in the lobby, and the
council vote tallies are pinned to the board, with Marc Leclerc's three
filibusters circled. The best detail is on the north wall: pale rectangles in
the paint where the Dukes' banners hung until 2009. The Foundry have never
painted over them. A hand-lettered sign under the gaps says `THEY KNOW WHERE
WE ARE.`

**Beyond the valley.** Road-exit rinks get one line each on their loading
card: the Rail Barons' locomotive shed with a train horn, Ellery's Pit with
soot on the rafters, Wexford's section 104 with water bowls, St. Brendan's
Abbey with an organ that plays hymns at faceoffs, the Belle Rive lazy river
behind section 12.

---

## 5. Seasons and events

Decor changes with the calendar, so the building feels lived in all year.
All seasonal pieces are props from section 6, placed by event, and most are
put up by the player or staff as a small, cosy job (a "decorate" action: 0.5
hours, a little Community reputation, no fail state).

### 5.1 The home opener (October, Lumber Kings)

- Buffalo-plaid bunting along the rafters end rail and the front desk.
- Marquee: `HOME OPENER FRI 8PM / LUMBER KINGS VS KESSLER / BEAT THE MILL`.
- A plaid scarf tied on Doris's mirror (Earl allows this one).
- The ceremonial puck drop, by Ronnie Haverstock if he's been asked. He
  always is. He always says yes.
- Old Pete takes the Shed bell out of the case early and polishes it in the
  lobby where people can see.
- The Clarion's preview pinned to the notice board.

### 5.2 Christmas (December)

- **Skate with Santa.** Santa arrives on Doris, every year, the second
  Saturday of December. Santa is Big Gord, who shouts "Ho ho ho, Big Gord
  won't let you walk!" from the snow tank. Earl drives.
- **The mitten tree.** A real fir in the lobby, hung with every unclaimed
  mitten from the lost and found and the ones people bring. They go to
  Millbrook Elementary in January. This is Millbrook's quiet version of the
  Fairhaven mitten throw.
- **Doris's antlers.** Felt antlers on her headlamps. Earl allows the antlers
  but not the red nose. (If the player adds the nose, Earl takes it off
  before every flood and puts it back after.)
- Paper snowflakes from Millbrook Elementary taped to the glass, one per
  child, names on the back.
- The Snowflake Showcase (`PATHS.md`): the learn-to-skate and figure club
  show, with paper snowflakes hung from the rafters on fishing line.
- The Cup Tree lit outside, white lights only, by tradition.
- The Legion's turkey raffle table in the lobby; the Hot Stove sells
  "Christmas Hot Choc Late" with candy cane.
- New Year's Eve public skate to 00:30 with Doreen's Casio playing Auld Lang
  Syne in organ mode.

### 5.3 Tournament weekends (Valley Peewee Tournament)

- Team welcome signs on every dressing room door, hand-painted by the host
  parents (`WELCOME KESSLER ATOM A, GOOD LUCK, PLEASE BE NICE`).
- A schedule board on an easel in the lobby, games every 75 minutes, which
  the player updates live as the day runs late.
- Hockey bags lining the corridor like a sandbag wall.
- A crest-trading table where kids swap team pins.
- The 50/50 drum from the hall, a raffle table, the tournament sponsor
  banner over the snack bar.
- Tournament chili at the Hot Stove (the Legion's recipe).
- An MVP ballot box made from a shoebox.

### 5.4 Playoff runs

- The **Beard-o-meter**: a corkboard in the lobby with a weekly photo of
  every Lumber King's playoff beard (`LORE.md` tradition). The equipment
  manager has an eyeliner moustache, out of solidarity.
- `LUMBER KINGS: WE BELIEVE` banners in Main Street shop windows, including
  Bev's (hers says `WE BELIEVE, SHARPEN FIRST`).
- Brooms by the door, for when a series is swept.
- The Shed bell rings after every home playoff win, in the lobby, by Old
  Pete, until he's hoarse.
- A Clarion special edition pinned to the board, and the marquee counting
  down: `4 WINS TO THE ALDOUS CUP`.

### 5.5 The town fair: Millbrook Winter Carnival (first weekend of February)

- An ice sculpture contest in the parking lot (the Flood Crew carves a Doris
  every year; the Molars carve a molar).
- King of Mount Doris for the kids.
- The broomball tournament on Saturday night.
- The figure club's carnival show with coloured gels on the lamps, and the
  50 Carnivals banner lowered to just above the ice.
- Lanterns strung across the lot, a hot chocolate stand outside.

### 5.6 The rest of the year

- **Haverstock Old-timers' (January):** old team photos brought down from
  the wall and set on easels round the hall; the 1994 Cup photo in the
  middle.
- **Valley Rocks Bonspiel (March):** house circles painted in the ice, curling
  brooms on the hall wall, Agnes Mulroney's draw board.
- **The Mallards' anniversary (12 March):** a single green balloon tied to
  the 2005 photo, every year, put there by nobody in particular.
- **Millbrook Dairy Days (July, dry floor):** the summer farmers' market,
  hay bales, bunting in dairy green and white, the Millbrook Dairy truck
  parked inside on the floor.
- **Halloween public skate:** pumpkins on the boards, Doris in a sheet as a
  ghost (Earl: "Fine. Once.").

---

## 6. Prop list for the art team

Sizes are width x depth x height in metres (`ART.md` conventions: real-world
sizes, pivot on the floor centred, wall props pivoted at the bottom centre
of the backplate, hanging props at the ceiling mount). Props use the 0.065 m
voxel unless noted. Every prop has the three ages; "keepsake" props should
keep their identity at RENOVATED (the same object, cleaned and lit).

### P1: the lobby slice and the first hour

| Id | What | Size (m) | Room | Notes |
| --- | --- | --- | --- | --- |
| `trophy_case` | Oak and glass case on a mint steel base, right third a display freezer with a hum and a frost line | 2.4 x 0.5 x 2.0 | lobby | Keepsake. Worn: two of four bulbs lit, smudged glass. Contents as separate small props below |
| `case_shorewood_stick` | Ronnie's taped Shorewood, on brackets | 1.6 x 0.1 x 0.1 | lobby | Use `Models.shaft()` and `blade()` |
| `case_doris_keys` | Ring of keys on a Z fob | 0.08 x 0.02 x 0.12 | lobby | |
| `case_frozen_cup` | Double-Double cup in a block of ice | 0.15 x 0.15 x 0.2 | lobby | Inside the freezer section |
| `case_milk_bottle` | Millbrook Dairy glass bottle with a dollar in it | 0.09 x 0.09 x 0.25 | lobby | |
| `case_shed_bell` | Brass bell on a wooden yoke | 0.3 x 0.25 x 0.35 | lobby | Also a hand prop for Old Pete |
| `case_pike` | Mounted pike, surprised | 0.9 x 0.12 x 0.3 | lobby | |
| `last_call_cup` | Pewter stein bolted to a puck, masking tape names | 0.14 x 0.14 x 0.22 | lobby | `TEAMS.md` trophy |
| `moosebrew_mug` | Two-litre etched glass mug | 0.16 x 0.12 x 0.24 | lobby | `TEAMS.md` trophy |
| `photo_frame_team` | Team photo frame, 0.9 x 0.65, mat colour per age | 0.9 x 0.04 x 0.65 | lobby | One mesh, picture as a texture or `RinkOS.sign_3d()`; 50 copies |
| `photo_frame_small` | Small frame | 0.3 x 0.03 x 0.4 | many | |
| `mallards_cup_photo` | The big framed 2005 photo with the letter frame and chained binder | 1.6 x 0.08 x 1.2 | lobby | Keepsake |
| `dedication_plaque` | Bronze plaque with the brass strip and the gap | 0.6 x 0.04 x 0.5 | lobby | Keepsake; a `roof_strip` part appears when the roof is renovated |
| `notice_board` | Cork board with layered paper and thumbtacks | 1.2 x 0.05 x 0.9 | lobby | Pins are a small kit (`pin_note`, `pin_card`, `pin_poster`) |
| `mural_mill_pond` | The 1976 mural as a wall panel | 9.0 x 0.03 x 2.4 | lobby | Merged mesh; the three-legged skater and the Florida stain are separate decals so they can be "fixed" |
| `moosebrew_clock` | Round clock, moose with crossed-stick antlers, hands animated | 0.45 x 0.08 x 0.45 | concession | Keepsake; runs 7 minutes fast |
| `gnhl_banner_1981` | Moosebrew GNHL banner with eight logos and three stickers | 4.0 x 0.02 x 1.0 | concession | Hanging |
| `coffee_machine` | Dented 1980s coffee machine with the flip sign | 0.45 x 0.5 x 0.75 | concession | Worn: dent, NOT WORKING |
| `menu_board_felt` | Felt letter board with missing letters | 2.0 x 0.05 x 0.9 | concession | Text via letter voxels so letters can be missing |
| `payphone` | Beige rotary payphone with the card | 0.3 x 0.25 x 0.6 | lobby | Wall prop at 1.2 m |
| `guestbook_lectern` | Wooden lectern with an open book and a pen on a chain | 0.5 x 0.4 x 1.1 | lobby | |
| `pamphlet_rack` | Wire rack, four pockets | 0.4 x 0.15 x 0.9 | lobby | |
| `gus_binder` | Fat three-ring binder with tabs and notes | 0.3 x 0.08 x 0.32 | plant_room | Hand prop |
| `door_notes` | Layered sticky notes and index cards on a door leaf | 0.9 x 0.02 x 2.1 | plant_room | Overlay on `door_leaf` |
| `log_book_desk` | Open log book with a pencil on a string, on a small steel desk | 0.9 x 0.6 x 0.75 | plant_room | |
| `envelope_mat` | Doormat with the envelope under the corner | 0.9 x 0.6 x 0.02 | parking_lot | First interactable |
| `marquee_sign` | Changeable letter board on two posts | 3.0 x 0.4 x 2.8 | parking_lot | Letters as a kit; always one letter short |

### P2: the rest of Millbrook

| Id | What | Size (m) | Room | Notes |
| --- | --- | --- | --- | --- |
| `champions_board` | Painted plywood board with names, masking tape after 2011 | 2.4 x 0.03 x 1.2 | lobby | |
| `rules_sign` | Enamel Rules of the Rink sign with the marker addition | 0.6 x 0.02 x 0.8 | lobby | |
| `skate_cubbies` | Plywood pigeonholes with painted sizes and rental skates | 2.4 x 0.4 x 1.8 | pro_shop | Skates as a repeated mini prop |
| `wall_of_shame` | Board of Polaroids | 1.0 x 0.02 x 0.7 | pro_shop | |
| `lost_bin` | Wooden crate stencilled LOST, with a clipboard | 0.8 x 0.5 x 0.6 | pro_shop | |
| `counter_bell` | Brass desk bell with tape label | 0.09 x 0.09 x 0.07 | pro_shop | |
| `tip_jar` | Pickle jar, DORIS RETIREMENT FUND | 0.12 x 0.12 x 0.2 | concession | |
| `hand_dryer` | 1987 wall hand dryer | 0.3 x 0.2 x 0.3 | washrooms | Loud |
| `valley_mirror` | Cracked mirror with the five towns marked | 0.9 x 0.03 x 0.6 | washrooms | Keepsake |
| `out_of_order_sign` | Laminated sign with crossed-out dates | 0.22 x 0.01 x 0.3 | washrooms | Reusable anywhere |
| `tape_ball` | Giant tape ball on a stool | 0.6 x 0.6 x 1.05 | locker_home | Keepsake. Grows a little each home win |
| `tape_bucket` | Bucket of half-used Gripley's rolls | 0.3 x 0.3 x 0.35 | locker_home, locker_away | |
| `captains_board` | Varnished board with gold names | 1.2 x 0.04 x 1.8 | locker_home | |
| `signed_ceiling_tile` | 0.6 m ceiling tile covered in signatures | 0.6 x 0.02 x 0.6 | locker_home | Keepsake; frame variant for RENOVATED |
| `stall_plate_14` | Brass plate on a stall | 0.1 x 0.01 x 0.08 | locker_home | |
| `radiator_cast` | Cast-iron radiator with six paint layers | 1.0 x 0.2 x 0.7 | locker_home | |
| `graffiti_wall` | Painted block wall section with layered writing | 3.0 x 0.02 x 2.0 | locker_away | Decal set; the acrylic cover and the fresh panel at RENOVATED |
| `ref_door_brooms` | Door with REFEREES over BROOMS | 0.9 x 0.05 x 2.1 | ref_room | Variant of `door_leaf` |
| `whistle_jar` | Pickle jar of whistles | 0.12 x 0.12 x 0.18 | ref_room | |
| `cruller_box` | Double-Double box, two crullers | 0.3 x 0.2 x 0.1 | ref_room | |
| `coat_hook` | Single wall hook | 0.05 x 0.08 x 0.1 | many | |
| `penalty_library` | Small bookshelf with paperbacks and Moose's note | 0.9 x 0.25 x 0.6 | penalty_boxes | Keepsake |
| `casio_keyboard` | Keyboard on a stand | 0.95 x 0.35 x 0.8 | penalty_boxes | |
| `flip_score_chart` | Hanging flip chart of painted numbers 0 to 15 | 0.6 x 0.05 x 0.9 | penalty_boxes | |
| `log_truck_horn` | Chrome air horn on a bracket | 0.5 x 0.15 x 0.2 | penalty_boxes | |
| `radiant_heater` | Ceiling radiant heater with a pillar button | 1.2 x 0.3 x 0.2 | stands_bench | Hanging |
| `seat_plaque` | Small brass plate for a seat back | 0.1 x 0.01 x 0.04 | stands_box | Fits `arena_seat` |
| `board_ad_panel` | A painted dasher-board ad panel (24 sponsors as textures) | 2.44 x 0.02 x 0.9 | stands | Placed by Rink environment on the boards |
| `milk_bottle_mark` | The painted milk bottle on board N7 | 0.08 x 0.005 x 0.16 | stands | Keepsake decal |
| `goal_judge_cage` | Wire mesh booth with a red light on a pole | 1.0 x 1.0 x 2.2 | stands | |
| `championship_banner` | Felt banner, text via `RinkOS.sign_3d()` | 1.5 x 0.02 x 2.4 | lighting | One mesh, many texts |
| `retired_number_banner` | The Haverstock 14 banner with its log-chain hook | 1.5 x 0.02 x 2.6 | lighting | Keepsake |
| `sponsor_banner_70s` | Faded 1970s sponsor banner | 3.0 x 0.02 x 1.0 | lighting | |
| `rafter_puck` | A puck sitting on a truss flange | 0.08 x 0.08 x 0.03 | lighting | Tiny; findable |
| `rafter_mitten` | A red mitten hanging from a truss | 0.12 x 0.04 x 0.25 | lighting | |
| `pigeon_linesman` | Linesman the pigeon, idle and peck poses | 0.3 x 0.15 x 0.25 | lighting | Optional animation |
| `office_desk` | Mint-green steel desk with drawers | 1.5 x 0.75 x 0.75 | office | |
| `rotary_phone` | Beige desk phone | 0.22 x 0.2 x 0.12 | office | |
| `calendar_1998` | Grizzly Gas calendar with a truck | 0.35 x 0.01 x 0.6 | office | Keepsake |
| `ice_grid_board` | Whiteboard with coloured magnets | 1.8 x 0.05 x 1.2 | office | Magnets as a kit, one colour per organisation |
| `cash_box` | Grey steel cash box | 0.3 x 0.22 x 0.1 | office | |
| `filing_cabinet` | Four-drawer steel cabinet | 0.47 x 0.62 x 1.32 | office | |
| `transistor_radio` | Taped transistor radio | 0.25 x 0.08 x 0.15 | plant_room, zamboni_bay, office | |
| `drum_chair` | Glycol drum with a GUS cushion | 0.58 x 0.58 x 0.95 | plant_room | |
| `days_since_sign` | Flip-number sign with the record | 0.6 x 0.03 x 0.4 | plant_room | Keepsake |
| `thermometer_board` | Board of eleven dial thermometers | 0.9 x 0.05 x 0.6 | plant_room | |
| `ear_defenders_nail` | Ear defenders on a nail with a note | 0.2 x 0.12 x 0.25 | plant_room | |
| `doris_lettering` | DORIS in metre-high letters | 3.2 x 0.02 x 1.0 | zamboni_bay | Above the bay door |
| `tally_wall` | Earl's tally marks as a wall decal (9,412, extendable) | 3.0 x 0.01 x 2.0 | zamboni_bay | Keepsake |
| `doris_shoes` | Pair of wooden blade-change blocks | 0.3 x 0.2 x 0.25 each | zamboni_bay | |
| `towel_hook` | Hook with an old towel | 0.1 x 0.1 x 0.6 | zamboni_bay | |
| `parts_cabinet_doris` | Steel drawer cabinet, drawers labelled DORIS | 0.9 x 0.45 x 1.2 | zamboni_bay | |
| `poster_zambelli_1974` | Dealer poster | 0.6 x 0.01 x 0.9 | zamboni_bay | |
| `poster_flatley_dartboard` | Flatley poster with darts | 0.6 x 0.05 x 0.9 | zamboni_bay | |
| `double_double_snowbank` | Cup frozen into a snow lump | 0.4 x 0.4 x 0.3 | parking_lot | |
| `warlock_bench` | Bench of 41 broken sticks | 1.6 x 0.6 x 0.9 | parking_lot | Appears after a season of the stick deal |
| `block_heater_post` | Plug-in post | 0.15 x 0.15 x 1.0 | parking_lot | Repeated; one labelled EARL |
| `town_welcome_sign` | Painted wooden town sign on posts | 2.4 x 0.2 x 1.8 | parking_lot | Building voxels (0.25 m) for the posts |
| `frozen_bicycle` | Kid's bike frozen into a rack | 1.2 x 0.5 x 0.8 | parking_lot | Keepsake (minor) |

### P3: the hall, seasons and the rest

| Id | What | Size (m) | Room | Notes |
| --- | --- | --- | --- | --- |
| `the_table` | Steel folding table with a brass plate | 1.8 x 0.75 x 0.74 | community_hall | Keepsake |
| `upright_piano` | Upright piano | 1.5 x 0.6 x 1.25 | community_hall | |
| `stacking_chair` | Mint (and seven orange) stacking chairs | 0.45 x 0.5 x 0.8 | community_hall | MultiMesh |
| `bookshelf_hall` | Tall bookshelf with the hockey library and a kids' rug | 0.9 x 0.3 x 1.8 | community_hall | |
| `fifty_fifty_drum` | Wire raffle drum on a stand | 0.5 x 0.4 x 0.6 | community_hall | |
| `tap_tower` | Two Moosebrew taps with the sign | 0.3 x 0.2 x 0.5 | community_hall | |
| `bingo_board` | Lit bingo number board | 1.2 x 0.1 x 0.9 | community_hall | |
| `curling_brooms` | Two crossed brooms on a wall mount | 1.4 x 0.1 x 1.4 | community_hall | |
| `panorama_1979` | Long panoramic photo frame | 2.0 x 0.03 x 0.4 | community_hall | |
| `plaid_bunting` | Buffalo-plaid bunting, one 2 m swag | 2.0 x 0.02 x 0.4 | many | Seasonal: home opener, playoffs |
| `mitten_tree` | Fir tree hung with mittens | 1.2 x 1.2 x 2.0 | lobby | Seasonal: Christmas |
| `doris_antlers` | Felt antlers for Doris's headlamps (and the nose, separately) | 0.6 x 0.2 x 0.5 | zamboni_bay | Attach to `resurfacer` |
| `paper_snowflake` | Paper snowflake taped to glass | 0.25 x 0.005 x 0.25 | stands | Seasonal; dozens, varied |
| `team_door_sign` | Hand-painted welcome sign for a dressing room door | 0.6 x 0.01 x 0.45 | locker_home, locker_away | Seasonal: tournaments |
| `schedule_easel` | Easel with the tournament schedule board | 0.7 x 0.6 x 1.7 | lobby | |
| `crest_table` | Folding table with pin trays | 1.8 x 0.75 x 0.74 | lobby | Reuses `the_table` mesh |
| `beard_o_meter` | Cork board of beard photos | 1.2 x 0.05 x 0.9 | lobby | Seasonal: playoffs; reuses `notice_board` |
| `sweep_broom` | A broom leaning on the wall | 0.3 x 0.1 x 1.4 | lobby | Seasonal |
| `ice_sculpture` | Carved ice block (Doris, a molar) | 1.0 x 1.0 x 1.5 | parking_lot | Seasonal: Winter Carnival; glass material |
| `lantern_string` | String of lanterns, one 4 m span | 4.0 x 0.2 x 0.4 | parking_lot | Seasonal |
| `pumpkin` | Pumpkin on the boards | 0.3 x 0.3 x 0.25 | stands | Seasonal: Halloween |
| `cup_tree` | The blue spruce, with a lights variant | 4.0 x 4.0 x 9.0 | parking_lot | Building scale (0.25 m voxels) |
| `wood_sign_letters` | The old rink sign letters mounted indoors | 6.0 x 0.1 x 0.6 | lobby | RENOVATED only |

---

## 7. Lore invented here

New canon this doc adds, for the owners of the other docs to accept, rename
or push back on:

| Fact | Touches |
| --- | --- |
| The arena opened Saturday 2 November 1974, ribbon cut by Mayor Harold Penner; the opening game was Kessler 5, Lumber Kings 3 | `LORE.md`, `TEAMS.md`, `RINK_SIM.md` |
| Before 1974 the Lumber Kings played on natural ice in the Mill Road Shed | `TEAMS.md` |
| The Lumber Kings' Aldous Cups are 1956 and 1979 (canon only said the last was 1979); Mill Division titles 1956, 1966, 1979, 1988, 2001 | `TEAMS.md`, `teams.json` |
| The 2005 Cup night was 12 March 2005; the Mallards' letter was dated 14 January 2005; Larry Piche has sent 21 follow-ups | `LORE.md`, `TEAMS.md` |
| Breaker 14 runs the trophy case freezer holding a Double-Double cup frozen in ice from the 2005 queue line (this is what "DON'T TOUCH BREAKER 14" means, and why the electrical inspector cares) | `RINK_SIM.md` 1.6 and 5.10 |
| The Shorewood stick in the trophy case is Ronnie's, from the night the scout watched in 1979 | `LORE.md` 6 |
| Ronnie found the dead spot in 1977; it's board panel N7, a stick length left of the north post; someone painted a milk bottle on it. He planted the Cup Tree in August 1994 | `LORE.md` |
| Ronnie appears, unnoticed, in the doorway of the 1979 Lumber Kings Cup photo, delivering milk | `LORE.md` |
| The lobby mural (1976) was painted by Agnes Mulroney's art class; Agnes is now the bonspiel draw master; Bev painted herself into it; Dale Huffman painted one leg of the three-legged skater | `RINK_SIM.md` 5.3, `PROSHOP.md` |
| The faded GNHL banner above the snack bar is a 1981 Moosebrew banner with the eight clubs of 1981 | `LORE.md` |
| Moose Kowalczuk served 17 minutes in the Millbrook penalty box at a 1984 exhibition and left a paperback, which started the penalty box library | `LORE.md` |
| Doreen Vachon (Old Pete's wife) runs the clock, plays a Casio, and teaches piano in the hall | `TEAMS.md` |
| The HOME half of the scoreboard died at the 2003 Lumber Kings home opener | `RINK_SIM.md` 3.5 |
| Earl's tally wall: 9,412 floods since 1983 (`LORE.md` says "nine thousand times") | `LORE.md`, `RINK_SIM.md` |
| Earl believes Doris likes CKVL; Earl painted `DORIS` over the bay door in 1984 | `RINK_SIM.md` |
| Gus kept a 1998 Grizzly Gas calendar because its days line up again; he retires to Florida and writes postcards; the guestbook has his goodbye after 49 years | `RINK_SIM.md` |
| The Mezzanine Hall (`community_hall`) above the lobby, with THE TABLE, the not-the-Lindell piano and the hockey library | Rink environment (new room) |
| New room ids proposed: `parking_lot`, `concession`, `pro_shop`, `ref_room`, `community_hall` (plus `bevs_shop` for the shop across the lot) | Rink environment, `rink_sim.gd` |
| New characters: Mayor Harold Penner (late), Midge Kaminski (Clarion columnist), Stan Szymanski (rafters end regular), Prof. Alistair Quenneville (historian), Walt Flatley Jr. (Flatley sales), Linesman the pigeon, Rascal the Mulroneys' dog | `TEAMS.md`, `LORE.md` |
| Penner Hardware is a Millbrook sponsor; the Penners are the Mayor's family | `TEAMS.md` sponsors |
| A puck killed the Lumber Kings' 2003 scoreboard, the pike thrown on 14 February 1981 is mounted in the trophy case, and the Kessler log-truck air horn is the goal horn | |
| The Northern Rink Operators' Association publishes *The Northern Rink Operator*; *The Blue Line* is the GNHL magazine; Clarion Books published Ronnie's memoir (1997); Kessler Public Library Press published the 1982 school play as a picture book | `LORE.md` |
| Kessler's Barn has eleven Aldous Cup banners, the newest from 1998; the mill whistle blows for Millmen goals | `TEAMS.md` |
| Duncannon Memorial Gardens still shows pale rectangles where the Dukes' banners hung until 2009 | `TEAMS.md` |
| The Frostbank Centre's record 50/50 was $212,450 | `TEAMS.md` ("paid for a house") |

One small canon note found while reading: Bev's flat-hollow line in
`PROSHOP.md` ("You'll glide like a Zamboni going downhill") uses the real
trade mark; in this world it should be "like a Zambelli going downhill,"
which Zambelli's lawyers would also object to, so it's funnier.

---

## 8. Open questions

1. Is the Mezzanine Hall wanted? It gives the town a living room and the
   readables a home, but it's a new room for Rink environment. Without it,
   the hall's pieces can move to the lobby and the office.
2. Keepsake reactions: are the Community reputation numbers in section 2
   the right size next to `RINK_SIM.md` 5.4 (naming rights without
   "Millbrook" is -15)? They're pitched so that removing one big keepsake
   hurts like a bad rename.
3. Should the player be able to add their own keepsakes (the empty hook in
   the trophy case, the guestbook signature, a photo of their first team
   on the wall)? The doc assumes yes; it's cheap and it's the kind of thing
   that makes a place feel like yours.
4. Readables UI: a simple reading view is assumed (UI thread). Does the
   pixel terminal style (`assets/ui/STYLE.md`) suit handwritten notes, or
   should handwriting get its own font?
5. Seasonal decorating as a "decorate" action (0.5 h, small Community gain):
   does Mechanics want it on the calendar like other jobs, or as free
   flavour?
