# The ice and the resurface

How Millbrook's sheet is simulated, how it's measured, and how the owner
drives Doris over it until a driver is hired (playtest #45). Everything here
is in `scripts/world/sim/ice_slab.gd` (the ice), `scripts/world/ice/` (the
machine run, the autopilot, the gauges, the view) and `scripts/world/jobs/`
(the three mini games). The sources for the numbers are in section 8.

## 1. The ice model (IceSlab v2)

### 1.1 Two grids

| Grid | Size | Cell | Holds |
| --- | --- | --- | --- |
| Fine | 240 x 104 | 0.254 x 0.249 m (10 in) | thickness `t`, gouge depth `g`, surface texture `r`, snow `s`, liquid water `w`, heat still to give up `hq`/`hq0`, cut angle `ang`, blade striations `stri` |
| Coarse | 20 x 8 | 3.05 x 3.24 m | block averages (`thick`, `smooth`, ...) the old API and the rest of the game read |

Fine cells are indexed `fz * 240 + fx`. Rink metres: x runs along the sheet
(home end at -x), y is world z (bench side at -z). Cells outside the rounded
boards are never touched (`inside`). A static geometry cache holds each cell's
distance to the boards (`board_m`), the floor heave under it, its block and
traffic weight.

Skater wear is lazy: `wear_sessions(hours, skaters)` and `run()` add to
pending totals that `flush()` turns into gouge strokes, snow and melt cell by
cell. Machines call `flush()` once and then work the fine arrays directly.
`wear(pos, amount)` is the immediate version for events and NPC skaters (one
skater crossing a spot is about 0.001 skater hours; a goalie's crease over a
game about 0.5).

States come out of the numbers (`states()`): wet, snowed up, cold, warm,
melting, thick, thin, bowled, dished. `profile()` reports the bowl (ice a
metre off the boards against the middle) and the dish (the lowest 3 m patch
under the middle). The new Millbrook sheet has a 22 mm bowl at the boards (a
12 mm coarse edge lip) and Earl's 6.5 mm dip at the home blue line.

### 1.2 Water

`add_water(i, mm, temp_c)` lays water on a cell. It fills gouges first (hot
water melts into them better), wipes out the blade's striations
(`stri *= exp(-mm * 3)`), and adds heat to give up: `mm * (C * T + L)`,
C = 4.18 kJ/kg K and L = 334 kJ/kg. Ice is 1.09 times the volume of its water.

`settle(passes)` lets standing water run downhill to lower neighbours until
a 0.15 mm film is left pinned to the surface, so floods pool in the dish
and run to the boards on a bowled sheet.

### 1.3 Hot water bonds

Hot water melts into the old surface and bonds; cold water sits on top with
air in it. The resurface quality is scaled by `0.8 + 0.2 * (T - 15) / 45`
(clamped to 0.8..1.04), so 60 C water gives full quality and tap water about
80%. The heat costs gas: `ResurfacerSim.heat_cost(litres, temp_c)` =
litres x 4.18 x (T - 10) / 1000 x $0.0148 per MJ. A full 1100 L tank at 60 C
is about $3.40, matching `RinkSim.FLOOD_GAS`.

### 1.4 Freezing

`freeze(seconds)` takes heat out of the cells that still hold water. The flux
per square metre is `(freeze_kw / AREA + SLAB_SINK) x temperature factor`:

- `freeze_kw` is the plant's pull (320 kW on 25 mm of ice, less on thick ice);
- `SLAB_SINK` = 0.5 kW/m2 is the cold slab soaking heat down and the air
  taking it up, which is what really freezes a fresh flood in the first
  ten minutes;
- pools deeper than 1 mm freeze slower.

A 0.8 mm (1/32 in) flood at 60 C on -5 C ice freezes in about 12 minutes;
pros wait 10 to 20 minutes before skaters go on. The ice view shows standing
water glossy and dark until it freezes.

### 1.5 Save

`to_dict()` keeps every v1 key and adds `fine`: each array deflated as 16-bit
steps in base64 (thickness stays raw float32), plus the plates and the RNG
state. `load_dict()` reads v2, or rebuilds the fine grid block by block from a
v1 save.

## 2. The ice view

`IceView` (`scripts/world/ice/ice_view.gd`) puts a shader on the venue's ice
mesh (`IceView.attach(rink, ice)`, done by `venue_walk.gd`). It packs the
fine grid into two RGBA8 textures, uploading only the dirty rectangle, at
most every 0.1 s:

| Texture | r | g | b | a |
| --- | --- | --- | --- | --- |
| surf | gouge / 4 mm | texture | snow / 3 mm | liquid / 0.4 mm |
| cut | blade angle | striations | frozen | (thickness - 20) / 40 mm |

Clean glossy ice shows the paint through a grey-blue skin; scratches, cut
lines, frost and snow read white; standing water is darker, a little blue,
with a clearcoat; snow lies in drifts and along the boards; water soaks the
snow into slush. `debug_view` 1, 2 and 3 show the surf, cut, and water,
frozen and snow channels.

## 3. Measuring the ice

`IceMeasure` (`scenes/world/jobs/ice_measure.tscn`), from the ice kit on the
zamboni bay bench.

### 3.1 Depth plates and the dial caliper

One plate is set into the slab at centre ice at the start. Drill down to it
and put the caliper's depth rod in: the popup is a close-up of a
"Mitsutoya" dial caliper. Read it like the real thing: the beam line the
jaw has passed, plus the needle on the dial.

- Metric: 1 mm a needle turn, 50 divisions of 0.02 mm.
- Imperial: 0.1 in a turn, 100 divisions of 0.001 in.
- `IceGauges.caliper(mm, metric)` gives the beam, dial division and needle
  angle; `IceGauges.caliper_mm(beam, div, metric)` reads it back.

The other eight plates go in at the faceoff dots: pick an empty dot and E
orders one (`RinkSim.job("install_plate", {"spot": id})`, 2 h, $65). The
hole is melted out and the plate frozen in the next day; that day the ice
is closed (`RinkSim.ice_closed(day)`): sessions are cancelled (-3
satisfaction each), floods skipped, no skaters. Schedule it and take the
revenue hit.

### 3.2 The survey laser and rod

The tripod laser stands at centre ice, 1298 mm up. Pick a spot on the
clipboard (15 spots, three lines along the sheet), stand the rod there and
read where the red line crosses the E-pattern graduations (`IceGauges.rod`:
cm blocks and mm ticks, "126.3 cm"). Write it down: the clipboard shows each
spot as mm high or low against centre ice (`IceGauges.rise_mm`). The rod is
read to about 0.6 mm (sigma). This is how the player finds high corners for
the edger.

### 3.3 Upgrades (SimInstrument "ice_level")

| Tier | Sigma | Price | What it does |
| --- | --- | --- | --- |
| Laser and survey rod | 0.6 mm | owned | the clipboard survey above |
| Lidar scanner and tablet | 0.25 mm | $3,400 | a heat map of the whole sheet (`IceGauges.lidar`) |
| Level-Sense resurfacer | 0.1 mm | $149,000 | a new machine (`buy_tool("level_sense")`) that takes the scan and sets the blade and water itself (`doris.auto_level`) |

## 4. Driving Doris (playtest #45)

`DorisDrive` (`scenes/world/jobs/doris_drive.tscn`), from "Drive Doris" in
the bay. `ResurfaceRun` is the machine and the ice cell by cell;
`ResurfaceAutopilot` drives the standard pattern (Earl, tests, the shots).
Until a driver is hired the owner drives: `RinkSim.owner_waits()` holds the
day's floods in `floods_waiting` until the owner is on site. With
`earl_hired` the job finishes at once on Earl's autopilot.

### 4.1 The machine

| | Real (526 / 552 class) | Doris (Zambelli 546, gas) |
| --- | --- | --- |
| Ice-making water | 192-195 US gal | 1100 L (290 gal), so a full tank laid evenly is 1/32 in |
| Wash water | 72 gal | 270 L |
| Snow tank | 125 cu ft compacted | 3.5 m3, packed 0.6 t/m3 |
| Blade | 77 in | 1.956 m |
| Turning | 16 ft radius at the conditioner | 27 degrees max steer |
| Speed | about 7-9 mph when cutting | 2.2 m/s cut, 3.9 m/s top |

The flood tank is bigger than a real 526's so the canvas rule holds: a full
tank laid perfectly raises the ice 1/32 in, and a 65% valve (3.75 L/s wide
open) empties it over the standard pattern.

### 4.2 The controls (the 552's, one for one)

Doris is a Zambelli 546, the gas machine that looks the same as the 552 Electric (Sean, 2026-10-20), modelled on his 552 reference (`playtest/zamboni-552/SPEC.md`):
`DorisModel` (`scripts/art/doris_model.gd`) builds her with every control
as its own moving part, and `DorisModel.CONTROLS` lists them with their
grip points. The driver sits at the left rear; the dash with the gauges is
ahead of the steering wheel, the round auger housing stands in the middle,
and the control block is to the right of the seat. Decals read ZAMBELLI,
the in-world brand (an original wordmark).

| Control (spec) | Where | Input | In the run |
| --- | --- | --- | --- |
| Steering wheel | front left | A/D | `steer` (27 degrees max) |
| Accelerator, brake pedals | the floor | W, S/Space | the pedal drives her the way the shifter points; shifted against her way she brakes first |
| Forward / Neutral / Reverse | gated plate, block front left | wheel moves it, E steps F, N, R | `gear` 1, 0, -1; parked in N |
| Vertical auger | lever, left of the pair | E | `auger_v`: off, nothing lifts to the tank and the trough overflows |
| Horizontal auger | lever, right of the pair | E | `auger_h`: off, the cut stays on the ice as loose snow |
| Conditioner up / down | lever (spring centred) | E | `cond_down`; `cond_pos` travels in 5.5 s and the blade cuts only fully down |
| Bin up / down | lever, block front right | E | `dump`: the bin tilts up over the pit, the dump door swings (8 s) |
| Flood water | T-handle on the block | wheel 5% a notch | `flood_valve`, 90 degrees back = 100% |
| Wash water | T-handle by the right wall | wheel 5% a notch | `wash_valve` meters the wash flow |
| Vertical auger plunger | rod with a ball knob | E holds | clears a jam (6 s, conditioner fully up) |
| Blade level wheel | hand wheel, right | wheel 1/8 turn a notch; clockwise lower | 1/32 in a turn, stop at 1/8 in; past 3/32 in the blade skips |
| Wash water pump | rocker on the dash | E | `wash_on` |
| Key | on the dash | E | the motor on / off; parked in the bay, off finishes the job |
| Standpipe hose | blue cap on the dash | E | fills both tanks in the bay (18 L/s) |
| Towel | pull by the seat | E | up for a dry cut |

The speedo and the fuel gauge on the dash have needles, the LCD under
them reads the gear, the speed and the tanks. Look at a control and its
name shows in the middle of the screen. Mouse wheel adjusts; on a pad the
d-pad picks and the triggers adjust.

The bin window (inset, top right) shows the snow coming up: the blade
should fill it about halfway on a normal cut. The augers lift at most
0.011 m3/s through a 0.03 m3 trough; a full bin (98%) or a choked trough
jams them and the cut behind is ruined until it's dumped at the pit.

### 4.3 Cuts and the pattern

| Cut | Blade | Wash | Flood | Towel | Effect |
| --- | --- | --- | --- | --- | --- |
| Normal | 1/16 in on the wheel (bite 0.5: takes about 1/32 in, half a bin) | on | 65% | down | cuts under the gouges and lays back what it took |
| Dry | 1/16 in | off | off | up | thins the ice; dry snow lifts without jamming |
| Flood | up | off | 65% | down | thickens the ice about 1/32 in a full tank |

The standard pattern: two laps round the outside (the first 1.42 m off the
boards, then a blade width less overlap further in, corners cut 2 m in),
then up the middle and loops filling in the rest, each turn at least five
lanes wide so the machine never makes a tight U-turn on the ice, then home
up the middle. About 9 minutes; the normal autopilot run covers 94% of the
sheet at quality 0.91, takes gouges from 0.81 to 0.11 mm and leaves the ice
0.2 mm thicker.

Gus rides along on the first cut and talks about the snow rate, the water
and the pattern.

### 4.4 The result

`ResurfaceRun.result()` is the job's args for `RinkSim.job("resurface")`:
quality, kind, ice_state (the worked IceSlab, adopted by the sim),
thickness_change_mm, flatness and level_sd_mm before and after, gouges
before and after, coverage, evenness, flood_coverage, jams, board_hits,
water and wash used, ice cut, snow left on the ice, the bin, flood_temp_c,
gas_cost, fuel_used and minutes. `complete` needs 90% coverage, no jams,
and (on a wet cut) 90% flood coverage. An empty tank leaves the cut
incomplete.

### 4.5 Repairs through the hatch (playtest W2)

Doris's repairs happen where she's parked, in the resurfacer bay. The bay's
Doris is the working `DorisModel`; the USE spot "doris" on her right side
("OPEN DORIS'S SERVICE HATCH") starts the plug change with
`in_place: "doris_hatch"`. `VenueWalk` passes the job scene
`place` (`DorisModel.hatch_frame()` on her), `host` (Doris) and `eye` (the
walker's camera). `JobScene` then plays in place: no teleport, the
diorama's own room (`backdrop`) hidden, `host.open_for_service(true)`
swings the hatch up and swaps her motor bay for the job's parts, and the
camera leans in from the walker's eye to the step's view. Closing the job
shuts the hatch. Any JobScene can play in place the same way.

## 5. Hand tools

`IceHand` (`scenes/world/jobs/ice_hand.tscn`), walked from behind on the ice.
The work happens on a copy of the sim's sheet that goes back as `ice_state`.

| Tool | Spot | Controls | What it does |
| --- | --- | --- | --- |
| Big hose | wall spool in the bay | E opens the nozzle, wheel sets flow | 61 m (200 ft) of 1.5 in hose, 1.6 L/s wide open of hot water (`IceSlab.hose_at`); heavy floods only where needed; it runs off downhill and freezes like any flood; the sim bills the heat (`hose_flood`) |
| Edger | bay floor | E starts the disc, wheel sets the depth (1 to 4.8 mm a pass) | takes high strips and corners down (`IceSlab.edge_at`) and spits its snow a pace out onto the ice for Doris to pick up (`edge_ice`) |
| Ice chipper | bay wall | E swings | drags the slush ridge that builds along the boards out where the blade can reach (`IceSlab.chip_at`, `chip_ice`) |

## 6. Sound hooks

The scenes play nothing; the lead's audio listens to these.

| Signal | Where | When |
| --- | --- | --- |
| `blade_scrape(quality, skipping)` | DorisDrive | while the blade is down, 4 Hz; skipping past 3/32 in |
| `flood_flow(rate, state)` | DorisDrive | rate 0..1; state "off", "trickle", "good" or "rush" |
| `wash_pump(on)` | DorisDrive | on change |
| `auger(jammed)` | DorisDrive | on change |
| `bin_dump` | DorisDrive | the dump starts |
| `engine(rpm)` | DorisDrive | 4 Hz |
| `hose(on)` | DorisDrive (standpipe), IceHand (big hose) | on change |
| `control_moved(id)` | DorisDrive | the driver works a control (`DorisModel.CONTROLS` id): a lever's clunk, a valve's squeak |
| `hose_flow(rate)` | IceHand | 4 Hz while the hose is out |
| `edger(on, load)` | IceHand | on change and while cutting |
| `chipper(hit)` | IceHand | each swing, litres moved |

## 7. RinkSim jobs and APIs

| Job | Hours | Cost | Args |
| --- | --- | --- | --- |
| `resurface` | from the run's minutes | gas from the run | ResurfaceRun.result() (ice_state) or the old quick path |
| `install_plate` | 2 | $65 | spot, day |
| `ice_depth` | 0.3 | | readings from IceMeasure, else the sim reads the plates |
| `ice_survey` | 0.6 | | readings and points from IceMeasure |
| `hose_flood` | 0.4 | heat of the litres | ice_state, litres, temp_c |
| `edge_ice` | 1.5 | $2 gas | ice_state |
| `chip_ice` | 1.0 | | ice_state |

Also: `owner_on_site(minutes)`, `owner_waits()`, `flood_waiting()`,
`ice_closed(day)`, `plate_pending(spot)`, `depth_readings(spot)`,
`survey_readings(points)`. `walk_story.gd` calls `owner_on_site()` each tick.

Tests: `tools/tests/test_ice.gd` (freeze time, water spreading, hot water,
wear, gauges, the three cuts, a deep blade jamming, an empty tank, the sim
jobs, the drive, measuring and hand-tool scenes). Shots:
`tools/ice_shots.gd`.

## 8. Sources

| Source | Numbers taken |
| --- | --- |
| Zamboni Model 526 spec (zamboni.com/machines/model-526) | 192 gal ice-making water, 72 gal wash water, 125 cu ft compacted snow tank, 77 in blade, 16 ft turning radius at the conditioner, 6,930 lb dry |
| Zamboni USA booklet and Level-Ice brochure (zamboni.com brochures) | 552: 195 gal, 125 cu ft; the laser levelling system reads the ice to 0.02 in and drives the blade |
| Pro Whiz Ice articles (pwice.com/?p=4686, 4698, 4729) | 1/16 to 1/8 in shaved a pass, 140-160 F flood water, about 1/32 in laid a flood, 10-15 minutes a resurface |
| Arena Guide, flood water treatment (arena-guide.com) | hot floods at 140-160 F, why hot water bonds |
| Middlesex Centre arena (middlesexcentre.ca/node/2114) | drilling the ice at 29 spots twice a week, 1.25 in target, calipers |
| Giant Bomb, "Being a Zamboni driver" | the controls (blade height, main water lever, the plunger for the vertical auger), edges first then overlapping loops, raise the blade on the overlaps |
| Jalopnik, single-machine resurfacing estimate | about 7 minutes and 3/4 mile a resurface |
| Hockey Canada rink technical guidelines (2024) | ice 1 to 1.5 in thick, -5 to -3 C surface |
| Wikipedia, Ice resurfacer | machine layout: blade, horizontal and vertical augers, wash water, towel |
