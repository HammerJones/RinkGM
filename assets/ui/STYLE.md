# RINK-OS UI style

Every screen in RinkGM (match HUD, menus, career screens, mini games, and later
the rink office) uses one look: the rink's old office computer, RINK-OS. Pixel
type, `//` headers, `----` rules, `[ BRACKETED ]` buttons and text meters, drawn
crisp and in full colour on a modern screen. Sean chose it on 2026-10-17.

The project theme `assets/ui/rinkos_theme.tres` (set as `gui/theme/custom`) styles
every built-in Control automatically. `scripts/ui/rinkos.gd` (`RinkOS`) holds
the palette, fonts and text helpers, and builds that theme. Run
`scenes/ui/rinkos_showcase.tscn` to see every control in one place.

## Rules

1. **No hard-coded fonts or colours in screens.** Use the theme, a type variation
   (`label.theme_type_variation = RinkOS.TERM`) or a `RinkOS` constant.
2. **Pixel fonts only at their sizes.** Silkscreen at 16, 24, 32 or 48 px; VT323 at
   25 or 50 px. Other sizes put font pixels between screen pixels and blur them.
   The fonts are imported with antialiasing, hinting and subpixel positioning
   off; keep their `.import` files committed.
3. **No glow, scanlines or bloom on UI.** Sharp and flat.
4. **Which face for what:**
   - Silkscreen (`PIXEL`, `TITLE`, `BANNER`): titles, buttons, tabs, short labels. All caps.
   - VT323 (`TERM`, `TERM_LARGE`, `TERM_DIM`, `TermText`): numbers, clocks, stat lines, rules, controls lists.
   - Saira (default): any sentence longer than a few words.
5. **Colour has a job.** `ACTION` amber for things you can press and the game
   clock, `READOUT` cyan for live values, `GOOD` green and `ALERT` red for
   changes, `DIM` for rules and hints, `TEXT` for everything else.
6. **Terminal habits:** start section headers with `RinkOS.rule("title")`,
   show amounts with `RinkOS.meter()`, stat rows with `RinkOS.dots()`, buttons
   with `RinkOS.button()` (it adds the brackets), keys in `UPPER_SNAKE` via
   `RinkOS.key()`.
7. **Pixel corners:** panels and buttons use the 9-slice frames in
   `assets/ui/frames/` (4 px notch, 2 px border). Canvas textures use nearest
   filtering project-wide so the frames stay sharp.

## First-person overlay

Every scene walked in first person (the venue walk, the framework demos, a
job on foot) draws its hints through one node, `WalkHud`
(`framework/ui/walk_hud.gd`), and nowhere else. It fixes where each kind
of text lives and what it looks like, so a hint always reads the same:

- **Readout**, top left, `READOUT` cyan: live values. Where you are, what
  is loaded, counts. Caps.
- **Prompt**, centred just under the dot, `ACTION` amber: what a press
  does right now, as `[KEY] VERB` pairs in caps separated by three spaces,
  the thing's name first: `COFFEE MUG   [LMB] TAKE   [RMB] SHOVE   [Q] INSPECT`.
  Keys are written `LMB`, `RMB`, `WHEEL`, `CTRL+WHEEL`, `E`, `F5`.
- **Toast**, lower centre, `ACTION` amber, 3.5 s: what just happened
  (`SAVED 12 ROWS`, an inspect line).
- **Legend**, bottom left, `DIM`: the controls that always apply in this
  scene, the same `[KEY] VERB` form.
- **Panel**, centred, `PANEL` fill: long text (a notice, a screen), BBCode.
- **Dot**, 3 px, white at 60%: the centre mark everything aims through.

Nothing in the overlay takes mouse events (the captured cursor sits on the
dot). The object controls themselves are fixed in the `Interactor` and
the same everywhere: LMB take/drop, RMB throw/shove, E the thing's own
verb, Q inspect, wheel tumble, ctrl + wheel nearer/farther. A scene adds
keys for its own things and lists them in the legend.

## Signs and screens in the world

Rink signage, the arena scoreboard and any in-world screen use the same fonts,
palette and terminal habits, built with `RinkOS.sign_3d(text, colour, pixel_font)`.
It sizes the text so one font pixel equals one voxel (0.065 m), uses nearest
filtering and no lighting, so signs line up with the voxel art.

- Scoreboard: the HUD layout at arena scale. Team abbreviations and two-digit
  scores in `TEXT`, the clock and period in `ACTION`, on a `CRT` panel with a
  `BEZEL` frame.
- Wall signs and banners: Silkscreen, upper case, `TEXT` or `ACTION` on
  `PANEL`/`CRT`. Schedules, prices and times: VT323 in `READOUT`.
- The building can look old and worn (faded paint, a dead bulb in the
  scoreboard), but the UI itself is always full colour and crisp.

## The rink office

`scenes/ui/rink_office.tscn` (scripts/ui/office/) holds the management
screens: the ice grid, the plant log book, the week's P&L, the job queue and
Gus's corkboard. `FootHud` is the small clock, block and hours readout the
owner carries on foot (`scenes/ui/foot_hud_demo.tscn` shows it over the
venue walk). Screens read the sim only through `OfficeData`.

- Readings taken with the starting tools are words, never numbers
  ("amber, probably", "thick?"). A bought tool shows a number and its error
  ("-4.6 C +/-0.5"). Bad words read ALERT, good ones GOOD.
- The grid colours bookings by ice use (hockey READOUT, public GOOD, figure
  TEXT), shades free ice by slot class, marks floods with pixel ripples
  (ALERT when nobody can do it) and open bids with an ACTION dashed outline.
- In-world paper (sticky notes, the corkboard) uses its own paper colours
  with VT323 in pencil ink, kept square: rotated pixel text blurs.

## Changing the style

Edit `scripts/ui/rinkos.gd`, then rebuild the theme:

    godot --headless --path . --script res://scripts/ui/build_theme.gd

Frame images come from `assets/ui/frames/make_frames.py` (Python + Pillow).

## Fonts and licences

All three are under the SIL Open Font License 1.1; each folder in
`assets/ui/fonts/` carries its `OFL.txt`.

- Silkscreen by Jason Kottke
- VT323 by Peter Hull
- Saira by Omnibus-Type
