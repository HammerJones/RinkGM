# Bev's Edge & Tape: the Millbrook pro shop

A design for Sean. Owned by the World and asset design thread (the shop, its
art and its item data). The numbers here match `catalog.json` in this folder,
which is the file the game would load.

The short version: gear is a set of small, honest tradeoffs. Every sharpening,
curve, lie, flex and pad choice moves a few rating points from one skill to
another. Better brands add a point or two on top, and they cost real money in
a career that starts out paid in gas money. No piece of gear replaces skill:
all gear together can move any one rating by at most 8 points.

## 1. The shop

### Name, place and owner

**Bev's Edge & Tape** sits on Millbrook's main street, across the parking lot
from Millbrook Community Arena. The hand-painted sign over the door says
`SKATES SHARPENED / OPINIONS FREE`.

**Beverly "Bev" Kowalchuk**, 67, has run the place since 1979. She sharpens
every skate in town on **Old Bertha**, a floor-standing sharpener whose maker
went out of business in 1983, so Bev machines her own spare parts. She
remembers every hollow she has ever ground and most of the goals scored on
them. She is blunt, warm, funny, and right about skates more often than is
comfortable. She is closed on Sundays: "Bev is at church or the casino in
Kessler. She won't say which."

Supporting cast, for later: Bev's grand-nephew Tyler works the till on
weekends once the shop grows, and a shop cat named Toe Drag sleeps on the
skate wall.

### Look and layout

A voxel interior about 8 m wide and 12 m deep, built from the 0.25 m building
kit with props in the 0.065 m props kit. Warm and cluttered: wood panelling,
a pegboard wall, a radiator that clanks, a fogged front window with the
arena's lights across the lot.

| Area | Where | What's there |
| --- | --- | --- |
| Front door | Front centre | Bell on a spring, a rubber mat, a hand-written "SKATE GUARDS ON" sign |
| Counter | Front right | Old cash register, a jar of pucks, the coffee pot ($1), tape display tower beside it |
| Stick rack | Left wall | Composite sticks racked by brand (Honest, Kodiak, Warlock), a barrel of Shorewood wood sticks, a "USED" bucket |
| Skate wall | Right wall | Boxes stacked to the ceiling, display skates on pegs, Grafton in a glass case at stage 3 |
| Try-on bench | Middle right | A long bench on a rubber mat, a foot measuring board |
| Glove and pads bins | Middle | Wire bins of gloves, shins, elbows and shoulder pads, with a sign: "SMELL BEFORE YOU BUY. TRUST ME." |
| Sharpening station | Back centre | Old Bertha behind a half wall, a spark shield, a chalkboard listing hollows and Bev's opinions of them |
| Stick bench | Back left | A vice, a hacksaw, a heat gun, a steam box for wood sticks, a bin of plugs |
| Goalie corner | Back right | Goalie pads on a rail, masks on a shelf (grows at stage 2) |
| Photo wall | Above the counter | Framed Millbrook team photos from 1971 on, Bev in most of them |
| Shooting lane | Side room, stage 2 | A tarp, a net, a radar gun, so the player can try a stick and see the numbers |

### Renovation look

The shop follows the same worn, repaired and renovated ages as the rink.

| Age | Look |
| --- | --- |
| Worn | One flickering fluorescent tube, a water stain on the ceiling tiles, half-empty racks, one glove bin |
| Repaired | New lights, a second stick rack, fresh paint on the counter, the back room opens up |
| Renovated | The shooting lane, a proper goalie wall, a glass Grafton case, a small "Bev's at the Rink" window in the arena lobby for sharpening on game night |

### How the shop grows

The stock grows in five stages. The shop's stage is the higher of what your
tier unlocks and what Millbrook's rink renovation unlocks, so a player who
fixes up the home rink gets better gear even before climbing the ladder.

| Stage | Name | Unlocked by tier | Or by rink age | What it adds |
| --- | --- | --- | --- | --- |
| 0 | Old Bertha | Beer League D | Worn | Honest Hockey, Shorewood, CMC basics, the used rack. Hollows 3/8", 1/2", 5/8". Steam curve and lie jobs on wood sticks. Cuts, plugs and tape. |
| 1 | The New Wheel | Beer League C | Repaired | Hollows 5/16" and 3/4". Heat-gun curve jobs on composites. Kodiak and Warlock entry sticks, CMC mid gear, vintage goalie pads. |
| 2 | The Back Room | Beer League A | Renovated | 1" hollow, the profiling jig, lie jobs on composites, the full goalie wall, Kodiak and Warlock pro sticks, the shooting lane. |
| 3 | Authorised Dealer | Senior AAA | | Elite sticks, Grafton Blades fittings by appointment, the dual-radius Kessler Special profile. |
| 4 | Custom Orders | Semi-Pro | | Grafton Atelier. Custom-order sticks built to your curve, lie and flex with no fee, delivered 7 calendar days later. |

Sharpening is only at Bev's, so a road trip to Kessler means getting your
edges done before you leave. Once the rink is renovated, Bev's lobby window
lets you sharpen at the arena on home game nights.

## 2. Money

### Currency and starting cash

Dollars, shown as `$`. You start with $80 ("the jar on your dresser, mostly
loonies, one button") and a garage-sale kit: hand-me-down skates, Uncle Ray's
wooden stick, and pads with someone else's name inside the helmet.

### Earning it

Beer league players pay to play, the way real ones do. Until Senior AAA, money
comes from rink-rat shifts at Millbrook Community Arena and small bonuses from
the team sponsor. That also ties the shop to the rink story: the shifts are
the same rink you're renovating.

| Tier | Season fee | Pay per game | Win bonus | Champion bonus | Player of the game | Gas per away game |
| --- | --- | --- | --- | --- | --- | --- |
| Beer League D | $120 | $0 | $10 (Millbrook Tavern) | $50 | Free sharpening coupon | $5 |
| Beer League C | $150 | $0 | $15 (Millbrook Tavern) | $75 | Free sharpening coupon | $5 |
| Beer League A | $180 | $0 | $20 (Harlow Falls Auto Body) | $100 | $20 | $8 |
| Senior AAA | $0 | $40 | $25 | $250 | $25 | club pays |
| Semi-Pro | $0 | $150 | $40 | $600 | $50 | club pays |
| Minor League Pro | $0 | $500 | $75 | $1,500 | $100 | club pays |

| Side job | Pay | Limit | Cost |
| --- | --- | --- | --- |
| Rink-rat shift (flood the ice, run the rental window) | $30 at BL-D, $35 at BL-C, $40 from BL-A | 2 a week | One calendar day |
| Ref a kids' game (from BL-A) | $25 | 1 a week | One calendar day |

A rough Beer League D season: 12 weeks of two shifts is $720, about six wins
add $60, minus the $120 fee and a few dollars of gas, so about $650. That buys
a weekly sharpening ($96 a season), a mid stick and one good piece of gear. By
Minor League Pro a season pays $8,000 or more, and gear is a small tweak you
can afford freely, which is right for that stage.

### Prices at a glance

| Thing | Price |
| --- | --- |
| Tape roll | $4 to $7 |
| Sharpening | $8 |
| Curve job | $10 wood, $20 composite |
| Lie job | $10 wood, $25 composite |
| Cut / plug | $5 / $6 wood, $12 composite |
| Profile | $35 ($60 for the Kessler Special) |
| Sticks | $29 to $319 |
| Skates | $99 to $1,099 |
| Pads, gloves, helmets | $29 to $229 |
| Goalie gear | $59 to $649 |

Bev buys gear back at a quarter of what you paid ("and a lecture"). The used
rack sells at half price; used items break 50% more often and protect 5
points less.

## 3. Services

All numbers are rating points added to `Skills.modifiers`. Positive is better
for that skill.

### Skate sharpening (radius of hollow)

A deeper hollow (smaller number) bites harder into the ice: tighter turns,
more agility, but more drag and less glide. A flatter hollow (bigger number)
glides faster and turns wider. Bev's standard 1/2" is the neutral baseline.

| Hollow | Agility | Speed | Full-strength games | Fade games | Stage |
| --- | --- | --- | --- | --- | --- |
| 5/16" ("the can opener") | +5 | -5 | 3 | 2 | 1 |
| 3/8" | +3 | -3 | 4 | 2 | 0 |
| 1/2" (standard) | 0 | 0 | 5 | 3 | 0 |
| 5/8" | -2 | +2 | 6 | 3 | 0 |
| 3/4" | -3 | +3 | 6 | 3 | 1 |
| 1" ("the butter knife") | -5 | +5 | 7 | 3 | 2 |

Every sharpening costs $8. A fresh edge gives the full effect for the listed
number of games, then fades evenly to nothing over the fade games while a
**dull edge** penalty of -2 agility and -1 speed fades in. A practice counts
as half a game. So even the standard hollow is worth keeping fresh, and the
deep hollows need sharpening more often, which is how real edges behave.
Skate guards ($12) add one full-strength game to every sharpening.

**Goalies** use the same hollows with different effects: a deep bite gives an
explosive push for reflex saves, a flat one gives smoother lateral slides to
stay square to the shooter.

| Hollow | Reflexes | Positioning |
| --- | --- | --- |
| 5/16" | +3 | -3 |
| 3/8" | +2 | -2 |
| 1/2" | 0 | 0 |
| 5/8" | -1 | +1 |
| 3/4" | -2 | +2 |
| 1" | -3 | +3 |

### Skate profile (rocker)

The curve of the blade along its length. Profiling lasts until you change
skates or re-profile. A shorter radius means less blade on the ice: nimbler,
but less stable through contact (toughness also covers staying up after a hit).

| Profile | Agility | Speed | Toughness | Price | Stage |
| --- | --- | --- | --- | --- | --- |
| 9 ft Pivot | +2 | -1 | -1 | $35 | 2 |
| 11 ft Stock | 0 | 0 | 0 | $35 | 0 |
| 13 ft Glide | -2 | +1 | +1 | $35 | 2 |
| Kessler Special (9/13 dual) | +1 | +1 | -1 | $60 | 3 |

### Stick curve depth

More curve cups the puck for more power and lift, but it sprays shots and
makes the backhand worse (shown as passing, since that's where backhands live
in the current skill set).

| Depth | Shot power | Shot accuracy | Passing |
| --- | --- | --- | --- |
| Flat (6 mm) | -3 | +3 | +1 |
| Mild (9 mm) | -1 | +1 | 0 |
| Mid (12 mm) | 0 | 0 | 0 |
| Deep (15 mm) | +2 | -1 | -1 |
| Banana (19 mm, legal limit) | +4 | -3 | -2 |

### Stick curve position

Where the curve sits on the blade. A toe curve gets the puck off fast for
quick snapshots and toe drags; a heel curve loads up for slapshots.

| Position | Shot release | Shot power |
| --- | --- | --- |
| Toe | +2 | -2 |
| Mid | 0 | 0 |
| Heel | -2 | +2 |

One curve job changes depth, position or both: $10 on wood (Bev steams it),
$20 on a composite (heat gun, from stage 1). Wood can go anywhere. A composite
can only move two depth steps from its factory curve, and every heat job adds
0.5% to its chance of breaking each game. Bev: "Composites remember what they
were."

### Stick lie

The angle between shaft and blade. A higher lie stands the stick up and keeps
the blade near your skates, for tight handling. A lower lie lays it flat and
puts the blade out in front, for poke checks and stick lifts.

| Lie | Stick handling | Reach (proposed hook) | Stick-lift strength (proposed hook) | Interim stand-in |
| --- | --- | --- | --- | --- |
| 4 (flat) | -3 | +6 cm | x1.08 | +4 hitting |
| 5 | -1 | +3 cm | x1.04 | +2 hitting |
| 5.5 (stock) | 0 | 0 | x1.00 | 0 |
| 6 | +1 | -3 cm | x0.96 | -2 hitting |
| 7 (upright) | +3 | -6 cm | x0.92 | -4 hitting |

A lie job is $10 on wood, $25 on a composite (stage 2, one step from stock).

**How "defensive ability" maps.** There is no defence rating, and today
`PhysicsProfile` sets stick-lift strength from half stick handling and half
hitting. So the honest design is a small new physics input: stick reach and a
stick-lift multiplier that come from the stick, not from ratings. That's the
Physics thread's call. Until it exists, the defensive side is stood in by
`hitting`, which is the only defence lever the physics has without touching
stick handling. With lie 4, stick handling -3 and hitting +4 still nets a
slightly stronger stick lift and firmer checks, so the tradeoff points the
right way.

### Stick flex and cutting

Flex is how many pounds it takes to bend the shaft an inch, so a bigger
number is stiffer. Stiff sticks fire harder slapshots for players strong
enough to load them, but take longer to release and spray wrist shots. Too
whippy and the puck flutters. What matters is the flex compared with the
player's own strength.

Each player has an **ideal flex** of `50 + 0.5 x shot power` (trained value),
rounded to 5 for display. A Beer League D player with 28 power wants about
65; a minor pro with 74 power wants about 85. The effect comes from how many
steps of 10 the stick is off that ideal, blended smoothly between rows.

| Steps from ideal | Shot power | Shot release | Shot accuracy |
| --- | --- | --- | --- |
| 3 too whippy | -3 | +2 | -2 |
| 2 too whippy | -2 | +2 | -1 |
| 1 too whippy | -1 | +1 | 0 |
| Just right | 0 | 0 | 0 |
| 1 too stiff | +2 | -1 | -1 |
| 2 too stiff | +3 | -2 | -2 |
| 3 too stiff | +2 | -3 | -4 |

Power peaks at two steps too stiff. Past that you can't bend it at all, so
it's all downside. Because ideal flex rises with power, a stick that is too
stiff for you now can become the right stick as you train.

Sticks come in a choice of flexes at purchase (55 to 105, depending on the
stick). After that, Bev changes flex the real-world way:

| Job | Price | Flex | Length and reach | Limit |
| --- | --- | --- | --- | --- |
| Cut 1" off the top | $5 (free on the day you buy) | +4 per inch | -2.5 cm per inch | 4" |
| Plug 1" into the top | $6 wood, $12 composite | -4 per inch | +2.5 cm per inch | 2" |

Length changes reach, which belongs to the same proposed Physics hook as lie.

### Tape

| Style | Stick handling | Shot release |
| --- | --- | --- |
| Heel to toe, thick | +1 | -1 |
| Toe half only | -1 | +1 |
| Bare blade | 0 | 0 |

A tape job lasts 4 games. A roll ($4 Honest, 3 jobs; $7 Kodiak waxed, 5 jobs)
or $4 for Bev to do it. Colours are cosmetic: black, white, Millbrook green,
hockey pink, and glow tape at stage 3 for the Port Ainsley pond.

### A worked example: Uncle Ray's stick

The starter stick is a joke with a lesson in it. It's 85 flex with a banana
heel curve. For a beginner with 28 shot power, 85 is two steps too stiff, so
together with the curve and the stick's own -1 release it comes to about +8
shot power (at the cap), -5 release, -5 accuracy and -2 passing. Big shots that
miss the net. Bev's first visit fixes it for $16: steam it to a mid curve and
mid position ($10) and plug 2" into it ($6) to bring it down to 77 flex. That
leaves about +2 power, -2 release, -1 accuracy. Or she sells you a $29
Lumberjack in 65 flex and tells you to give Ray's stick back to Ray.

## 4. The catalogue

64 items: 15 sticks (13 skater, 2 goalie), 9 skates (7 skater, 2 goalie),
37 helmets, gloves, pads and goalie pieces, and 3 tape and accessory items.
That count includes the 9 garage-sale starters you begin with. Prices are in dollars; "Stage" is when it shows up in the shop.

**Protection** is a number per body part from the injury model's list (knee,
ankle, groin, shoulder, wrist, hand, ribs, back, concussion). It's the chance
that an injury rolled on that part drops one severity step, so a day-to-day
knock becomes nothing and a moderate one becomes minor. Protection from
everything you wear adds up per part, capped at 60%. Starter gear sits at
about 15%, so cheap upgrades help a bit and heavy pads help a lot, at the
cost of speed and agility.

### Skater sticks

Break is the chance per game that the stick breaks. A broken stick is gone,
and you finish the game with the team's bucket stick (an Honest Standard).

| Stick | Brand | Price | Stage | Material | Flexes | Stock curve | Mods | Break |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Uncle Ray's Shorewood (starter) | Shorewood | free | 0 | Wood | 85 | Banana, heel, lie 5.5 | Release -1 | 0.8% |
| Lumberjack | Shorewood | $29 | 0 | Wood | 65, 75, 85 | Mild, mid | Release -2, handling +1, passing +1 | 0.6% |
| Lakehouse | Shorewood | $49 | 0 | Wood, fibreglass wrap | 65 to 95 | Mid, mid | Release -1, handling +1, passing +1 | 0.8% |
| 1952 | Shorewood | $79 | 1 | Wood | 75, 85, 95 | Mild, mid, lie 6 | Handling +2, passing +2, release -2, power -1 | 0.8% |
| HC Standard | Honest | $45 | 0 | Composite | 55 to 95 | Mid, mid | Power +1, handling -1 | 1.5% |
| HC Plus | Honest | $79 | 0 | Composite | 55 to 95 | Mid, mid | Power +1, release +1, handling -1 | 2.0% |
| HC "Pretty Good, Actually" | Honest | $119 | 1 | Composite | 65 to 95 | Mid, mid | Power +1, release +1, accuracy +1, handling -2 | 2.0% |
| Trapper | Kodiak | $99 | 1 | Composite, mid kick | 65 to 105 | Mid, heel | Power +2, release -1 | 2.5% |
| Grizzly Classic | Kodiak | $179 | 2 | Composite, mid kick | 75 to 105 | Deep, mid, lie 5 | Power +3, accuracy +1, release -2 | 2.5% |
| Heritage Pro 1924 | Kodiak | $299 | 3 | Composite | 75 to 105 | Mid, heel | Power +3, accuracy +2, release -1, handling -1 | 2.0% |
| HEX | Warlock | $119 | 1 | Composite, low kick | 55 to 95 | Deep, toe | Release +3, power -1, accuracy -1 | 3.5% |
| COVEN PRO | Warlock | $199 | 2 | Composite, low kick | 65 to 95 | Deep, toe, lie 6 | Release +3, handling +1, power -2 | 4.0% |
| NECRO-X ULTRALIGHT | Warlock | $319 | 3 | Composite, low kick | 65 to 95 | Banana, toe, lie 6 | Release +4, handling +2, power -2, accuracy -1 | 5.0% |

The brands have personalities in numbers, not just words. Shorewood is soft
hands and slow release but nearly unbreakable. Honest is heavy and plain.
Kodiak is the power stick. Warlock is the quick-release stick that dies young.
The best stick of each brand nets about +3 over a neutral stick, and pays for
it in price and, for composites, in broken sticks.

### Goalie sticks

| Stick | Brand | Price | Stage | Mods | Break |
| --- | --- | --- | --- | --- | --- |
| Backstop | Shorewood | $59 | 0 | Rebound control +2, reflexes -1 | 0.8% |
| Den | Kodiak | $219 | 2 | Reflexes +2, rebound control -1 | 2.0% |

### Skates

| Skates | Brand | Price | Stage | Mods | Ankle protection |
| --- | --- | --- | --- | --- | --- |
| Pioneer, 1988 hand-me-down (starter) | Kodiak | free | 0 | Speed -2, agility -1 | 30% |
| Strider | Honest | $99 | 0 | Speed +1, agility -1 | 15% |
| Strider Plus | Honest | $159 | 0 | Speed +1, agility +1 | 10% |
| Glacier | Kodiak | $289 | 1 | Speed +3, agility -1 | 25% |
| Summit Pro | Kodiak | $549 | 2 | Speed +3, agility +1 | 25% |
| Edge Precision | Grafton | $699 | 3 | Agility +4, speed +1 | 10% |
| Atelier | Grafton | $1,099 | 4 | Agility +4, speed +2, toughness -1 | 10% |
| Goalie Skate | Honest | $129 | 0 | Positioning +1, reflexes -1 | 20% |
| Crease (goalie) | Kodiak | $399 | 2 | Positioning +2 | 30% |

Kodiak skates are stiff, protective and fast in a straight line; Grafton
skates are light, precise and agile, with thin ankles.

### Helmets and face

| Item | Brand | Price | Stage | Mods | Concussion protection |
| --- | --- | --- | --- | --- | --- |
| Garage-sale helmet (starter) | Honest | free | 0 | none | 15% |
| Lid | Honest | $49 | 0 | none | 20% |
| Toque Pro | CMC | $139 | 1 | Agility -1 | 35% |
| Featherweight | CMC | $199 | 2 | Agility +1 | 15% |
| Full Cage (face) | CMC | $39 | 0 | Stick handling -1 | +10% |
| Half Visor (face) | CMC | $45 | 0 | none | +3% |

### Gloves

| Gloves | Brand | Price | Stage | Mods | Hand / wrist protection |
| --- | --- | --- | --- | --- | --- |
| Garage-sale gloves (starter) | Kodiak | free | 0 | Stick handling -1 | 15% / 15% |
| Mitts | Honest | $45 | 0 | Stick handling -1 | 20% / 20% |
| Mitten Classic | CMC | $129 | 1 | Stick handling -1 | 30% / 25% |
| Knit-Back Pro | CMC | $179 | 2 | Stick handling +2 | 10% / 10% |
| Heritage Gauntlet | CMC | $229 | 3 | Stick handling -2, release -1 | 40% / 35% |

### Shoulder pads

| Pads | Brand | Price | Stage | Mods | Shoulder / ribs protection |
| --- | --- | --- | --- | --- | --- |
| Garage-sale (starter) | Honest | free | 0 | Agility -1 | 15% / 15% |
| Shell | Honest | $59 | 0 | Agility -1 | 20% / 20% |
| Bulwark | CMC | $169 | 1 | Agility -2, toughness +1 | 35% / 35% |
| Lightline | CMC | $139 | 2 | Agility +1 | 10% / 10% |

### Elbow pads

The injury model has no elbow, so elbow pads protect wrists and shoulders,
the parts a fall on the elbow usually hurts.

| Pads | Brand | Price | Stage | Mods | Protection |
| --- | --- | --- | --- | --- | --- |
| Garage-sale (starter) | Honest | free | 0 | none | Wrist 5% |
| Elbows | Honest | $29 | 0 | none | Wrist 10%, shoulder 5% |
| Hinge | CMC | $79 | 1 | Stick handling -1 | Wrist 15%, shoulder 10% |

### Shin guards

| Guards | Brand | Price | Stage | Mods | Knee protection |
| --- | --- | --- | --- | --- | --- |
| Garage-sale (starter) | Honest | free | 0 | none | 15% |
| Shins | Honest | $39 | 0 | none | 20% |
| Shinfort | CMC | $119 | 1 | Speed -1, agility -1 | 35% |
| Sprint Shin | CMC | $99 | 2 | Speed +1 | 10% |

### Pants

| Pants | Brand | Price | Stage | Mods | Protection |
| --- | --- | --- | --- | --- | --- |
| Garage-sale (starter) | Kodiak | free | 0 | none | Groin 15%, back 15% |
| Breezers | Honest | $59 | 0 | none | Groin 20%, back 20% |
| Tundra Pant | CMC | $159 | 1 | Agility -1, speed -1 | Groin 30%, back 35%, ribs 10% |
| Racer Pant | CMC | $139 | 2 | Agility +1, speed +1 | Groin 10%, back 10% |

### Goalie gear

| Item | Slot | Brand | Price | Stage | Mods | Protection |
| --- | --- | --- | --- | --- | --- | --- |
| Lost-and-found pads (starter) | Pads | Honest | free | 0 | Rebound control -1, reflexes -1 | Knee 20% |
| Goalie Pads | Pads | Honest | $249 | 0 | Rebound control +1, reflexes -1 | Knee 25% |
| Heritage Leathers (vintage) | Pads | Kodiak | $189 | 1 | Rebound control -2, positioning +1, toughness +1 | Knee 30% |
| Fortress | Pads | CMC | $649 | 2 | Rebound control +3, reflexes -2 | Knee 40% |
| Butterfly Lite | Pads | CMC | $599 | 2 | Reflexes +3, rebound control -2 | Knee 15% |
| Big Mitt | Catcher | CMC | $279 | 1 | Glove +3, reflexes -1 | Hand 25% |
| Quick Trap | Catcher | CMC | $299 | 2 | Glove +1, reflexes +1 | Hand 10% |
| Chest Protector | Chest | Honest | $159 | 0 | none | Shoulder 20%, ribs 25% |
| Chest Fortress | Chest | CMC | $379 | 2 | Reflexes -1, toughness +1 | Shoulder 40%, ribs 40% |
| Goalie Mask | Mask | Honest | $129 | 0 | none | Concussion 25% |
| Mask Pro | Mask | CMC | $349 | 2 | none | Concussion 45% |

### Tape and accessories

| Item | Brand | Price | Stage | Effect |
| --- | --- | --- | --- | --- |
| Cloth Tape | Honest | $4 | 0 | 3 tape jobs |
| Pro Waxed Tape | Kodiak | $7 | 1 | 5 tape jobs |
| Skate Guards | Honest | $12 | 0 | +1 full-strength game per sharpening |

## 5. Data and who owns what

### Item shape

Each entry in `catalog.json` `items` looks like this:

```json
{
  "id": "warlock_hex", "name": "Warlock HEX", "brand": "warlock",
  "slot": "stick", "price": 119, "stage": 1,
  "stick": {"material": "composite", "flex_options": [55, 65, 75, 85, 95],
            "curve": "deep", "curve_pos": "toe", "lie": "5.5", "length_in": 60},
  "mods": {"shot_release": 3, "shot_power": -1, "shot_accuracy": -1},
  "protect": {},
  "break_per_game": 0.035,
  "desc": "LOW KICK. HIGH CURSE. ..."
}
```

`mods` only ever use the canonical `Skills` keys. `protect` only uses
`Injury.PARTS` names. Services (`services.sharpening`, `profiling`,
`curve_depth`, `curve_position`, `lie`, `flex`, `tape`, `custom_order`) hold
their tables in the same shape. Lie rows carry a `physics_hook` (the proposed
physics input) and `interim_mods` (what Mechanics applies until Physics adds
the hook).

### What goes in the save

A proposal for Mechanics, who owns the save format:

```json
"money": 80,
"gear": {
  "loadout": {"stick": 3, "skates": 1, "helmet": 2},
  "inventory": [
    {"uid": 3, "item": "shorewood_lumberjack", "used": false,
     "stick": {"flex": 65, "cut_in": 0, "plug_in": 0, "curve": "mid",
               "curve_pos": "mid", "lie": "5.5", "heat_jobs": 0},
     "tape": {"style": "full", "games_left": 4}},
    {"uid": 1, "item": "kodiak_pioneer_1988",
     "edge": {"hollow": "1/2", "profile": "11ft", "games": 2.5}}
  ]
}
```

`money` goes on `Career` next to `day`. `gear` goes on the user's
`PlayerProfile` (so it saves with `to_dict()`), keyed by inventory `uid` so
two copies of the same stick can have different curves.

### How it becomes ratings

1. A pure `Gear` helper (in `scripts/career/`, Mechanics) reads the catalog
   and a profile's `gear` and returns three things:
   - `modifiers()`: item mods, plus sharpening (with fade and dull), profile,
     curve depth and position, lie (`mods` plus `interim_mods`), the flex
     table, and tape. Summed per key, each key clamped to +/- 8.
   - `protection()`: protection per body part, summed and capped at 60%.
   - `physics()`: stick reach and stick-lift multiplier from lie and length,
     for the Physics hook.
2. `PlayerProfile.refresh_modifiers()` adds `Gear.modifiers()` alongside the
   injury and fatigue modifiers it already applies. Everything downstream
   (`eff()`, `PhysicsProfile`, overall rating, the quick sim) then sees gear
   for free.
3. After an injury is rolled, Mechanics checks the part's protection and may
   drop it one severity step.
4. After each game: edge `games` go up by 1 (0.5 for a practice), tape
   `games_left` goes down, and each stick rolls `break_per_game`.

### Ownership

| Piece | Owner |
| --- | --- |
| The shop scene, its art, Bev, item data, descriptions, `catalog.json` | World and asset design |
| Rink-lobby sharpening window, placement in the arena | Rink environment |
| `money`, earnings, fees, `gear` in the save, `Gear` modifiers, protection rolls, stick breaks, edge wear | Game mechanics |
| Stick reach and stick-lift hook from lie and length | Physics |
| Visible curve, lie and length on the stick model | Controls (stick models) with World and asset design |
| The shop screen, loadout screen, price tags, stat-change preview | UI |

## 6. Flavour

### Brand voices

| Brand | Voice | Sample line |
| --- | --- | --- |
| Kodiak | Heritage, earnest, bears and lodges | "The bear on the shaft has been redrawn eleven times. The stick has not needed it once." |
| CMC, the Canadian Mitten Company | Polite, cosy, apologetic about how safe you'll feel | "Our lightest glove. We sewed less glove. Please be careful with your hands, they're lovely." |
| Warlock Hockey | Edgy, all caps, smoke and runes | "340 GRAMS OF PURE MALEVOLENCE. WARRANTY VOID IF USED NEAR A SLAPSHOT, A CROSSBAR OR A STRONG OPINION." |
| Honest Hockey Co. | Truth in advertising, to a fault | "It's a stick. It's a little heavy. It will be fine. We checked." |
| Shorewood | Lake cottage, slow, proud of trees | "Solid ash. Grown for sixty years by a tree that never once complained." |
| Grafton Blades | Swiss-watch luxury, microns | "Fitted by appointment by a man named Laurent, who measures each foot twice and sighs once." |

Every item in the catalogue has its own line in `desc`.

### Bev's lines

- First visit: "You must be the new one. Sit. Give me those skates. No, I'm not asking."
- On Uncle Ray's stick: "Is that Ray's stick? Eighty-five flex and a banana. Ray had forearms like a bridge and the aim of a sprinkler. Let me fix it before you hurt someone."
- Deep hollow: "Three-eighths. You'll turn on a dime and give change. You'll also be slower in a straight line than my sister, and she's got a hip."
- Flat hollow: "A full inch. You'll glide like a Zamboni going downhill. Don't try to stop."
- Standard: "Half inch. The way God and the 1979 instruction manual intended."
- Dull skates: "These aren't edges, they're suggestions."
- Composite curve job: "I'll heat it. I don't promise it. Composites remember what they were. Like my ex-husband."
- Low lie: "Flat lie. Blade's out in front like a rake. Good for poking. Bad for anything near your skates."
- High lie: "Upright lie. Puck stays close, like a dog that knows you've got cheese."
- Cutting: "Every inch I cut makes it stiffer. Every inch you whine makes it cost more."
- Broken Warlock: "Warlock? Again? Says right on it, 'warranty void near a slapshot'."
- Short on cash: "You've got eleven dollars. That's a sharpening and a lecture, and the lecture's free."
- Promotion to Senior AAA: "Senior AAA? In Kessler? Get your edges done the day before. That barn's ice is like a gravel road."

## 7. Open questions

**For Sean**

1. Is the beer-league economy right: you pay a season fee and earn through
   rink shifts and small sponsor bonuses until Senior AAA pays $40 a game?
2. Should shop stage come from tier or rink renovation, whichever is higher
   (this design), or only one of them?
3. Should broken sticks be in at all? They're the main money sink and give
   Warlock its character, but they can feel bad.

**For Game mechanics**

4. Agree the save keys: `money` on `Career`, `gear` on `PlayerProfile`.
5. Add a `Gear.modifiers()` call to `PlayerProfile.refresh_modifiers()`, with
   the +/- 8 per-key cap across all gear.
6. Protection: the step-down roll needs the victim's gear where
   `Injury.roll_hit` and `roll_wear` are called (quick sim and the live game),
   since those take `Skills`, not the profile. Pass protection in, or roll it
   in `PlayerProfile.add_injury()`?
7. Do AI players get gear? Suggestion: none (all zeros), so tier balance is
   unchanged, or a tier-typical kit that nets out to zero.
8. Rink-rat shifts and reffing need a way to spend a calendar day off a game
   day; is that the hub's job or the world's?
9. Stick breaks: rolled post-game in the quick sim only, or also mid-game in
   a live game (which needs a Physics or match event)?
10. Is the goalie hollow mapping (deep for reflexes, flat for positioning)
    acceptable, given goalie keys don't include skating?

**For Physics**

11. Add a gear input to `PhysicsProfile.from_skills()` (for example
    `from_skills(skills, gear := {})`) for `stick_reach_m` (poke check and
    stick-lift reach) and `stick_lift_mult`. Lie and stick length feed it.
    Until then, lie uses `hitting` as a stand-in.
12. Should lie also change the blade's angle on the ice (puck sliding off the
    heel or toe), or stay a pure reach and handling number?

**For UI**

13. Shop screen with a live before/after preview of every rating a purchase
    or service would change, the edge's games left, and the ideal-flex
    marker on the flex picker.
14. Showing protection: per body part bars, or one summary number?

**For Controls and World and asset design**

15. Should curve depth, curve position, lie and cut length be visible on the
    voxel stick model? A banana curve should look like one.
