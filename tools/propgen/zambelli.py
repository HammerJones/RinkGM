"""The Zambelli 552, the ice demo's resurfacer, as hero props: the body at
2 cm voxels, the conditioner, its horizontal auger, the vertical auger
and a wheel at 1 cm,
each its own .vox with a manifest, assembled and driven by
framework/demo/zambelli.gd. Built after the four untextured views of the
reference model on Sean's 552 board (/playtest/zamboni-552) and the
control layout in its SPEC.md: a long snow tank with a sloped nose, the
operator's stand at the back with the seat on the left, the vertical auger
drum in the middle, the control block on the right, the conditioner
trailing at ice level behind the rear wheels with the auger, the blade,
the wash pipe and squeegee, the flood pipe and the towel.

    python3 tools/propgen/zambelli.py            # all five parts
    python3 tools/propgen/zambelli.py body --preview

Axes: +Y up, the front faces -Z, +X right. The body's pivot is the bottom
centre of its bounding box; BLADE_Z and the other offsets below are what
the demo node uses to hang the parts off it.
"""
from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import propgen  # noqa: E402
from propgen import PAL, Field, Scene, manifest  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
VOX_DIR = os.path.join(ROOT, "art", "props")
DATA_DIR = os.path.join(ROOT, "data", "props")
PREVIEW_DIR = os.path.join(VOX_DIR, "preview")

# the machine's colours, added to the shared palette (appended, so every
# existing prop keeps its indices)
propgen.PALETTE.update({
    "machine_blue": (38, 84, 168),
    "machine_blue2": (33, 76, 156),
    "machine_white": (236, 236, 232),
    "machine_white2": (224, 224, 220),
    "steel": (150, 152, 156),
    "steel2": (138, 140, 145),
    "tyre": (28, 28, 30),
    "tyre2": (36, 36, 38),
    "safety_yellow": (240, 190, 40),
    "seat_black": (34, 34, 36),
    "towel": (210, 205, 190),
    "towel2": (190, 186, 172),
})
propgen.NAMES[:] = list(propgen.PALETTE.keys())

# ---------------------------------------------------------------- the layout, metres

W = 2.10            # the body's width
BODY_L = 3.50       # nose to the back of the operator's stand
TANK_Z1 = 2.05      # the snow tank ends here; the stand starts
TANK_TOP = 2.20     # the tank top at its rear, by the stand
NOSE_TOP = 1.80     # the tank top at the nose: one long gentle slope
NOSE_RUN = 1.9      # the slope runs the tank's length
SEAM_Y = 1.05       # white tank above, blue chassis below
DECK_Y = 1.0        # the operator's deck
FRONT_AXLE = 0.80
REAR_AXLE = 2.75
WHEEL_R = 0.38
WHEEL_W = 0.30
WHEEL_X = 0.86      # axle centre to wheel centre
COND_W = 2.10       # the conditioner's width (ice_demo's MACHINE_W)
COND_D = 0.90       # front to back
COND_H = 0.36
COND_Z0 = 3.35      # the conditioner's front edge, from the nose
BLADE_Z = COND_Z0 + 0.45  # the blade's cutting edge, from the nose
AUGER_Z = COND_Z0 + 0.20
AUGER_R = 0.15
AUGER_L = 2.00
LIFT_L = 1.20       # the vertical auger's length
LIFT_R = 0.20

BLUE = dict(colour=PAL.machine_blue, dither=PAL.machine_blue2, amount=0.18)
WHITE = dict(colour=PAL.machine_white, dither=PAL.machine_white2, amount=0.15)
STEEL = dict(colour=PAL.steel, dither=PAL.steel2, amount=0.2)
DARK = dict(colour=PAL.grey_dark, dither=PAL.grey_dark2, amount=0.2)


def _helix(s: Scene, c, radius: float, core: float, length: float, pitch: float, thick: float,
           hand_split: bool = True) -> Field:
    """A screw flight along X about `c`: solid where the angle around the
    axis matches the flight's phase at that x, `thick` across. With
    `hand_split` the two halves wind the other way, so the flights push
    toward the middle (the conditioner's auger feeds the vertical one)."""
    x = s.X - c[0]
    dy = s.Y - c[1]
    dz = s.Z - c[2]
    r = np.hypot(dy, dz)
    theta = np.arctan2(dz, dy)
    turn = 2 * np.pi * x / pitch
    if hand_split:
        turn = np.where(x < 0, turn, -turn)
    phase = np.angle(np.exp(1j * (theta - turn)))
    across = np.abs(phase) * np.maximum(r, 1e-3)  # arc length off the flight's centre line
    d = np.maximum(np.maximum(across - thick / 2, r - radius), np.maximum(core - r, np.abs(x) - length / 2))
    return Field(d.astype(np.float32))


# ---------------------------------------------------------------- the parts


def body() -> Scene:
    v = 0.02
    s = Scene((W + 0.1, 2.45, BODY_L + 0.05), v, origin=(-(W + 0.1) / 2, 0.0, 0.0))
    hw = W / 2
    # the chassis: two rails with crossmembers, the floor pan over them
    for x in (-0.7, 0.7):
        s.add(s.box((x - 0.05, 0.30, 0.25), (x + 0.05, 0.46, BODY_L - 0.05)), **DARK)
    for z in (0.3, 1.5, 2.2, BODY_L - 0.1):
        s.add(s.box((-0.75, 0.32, z - 0.04), (0.75, 0.44, z + 0.04)), **DARK)
    s.add(s.box((-hw + 0.1, 0.44, 0.25), (hw - 0.1, 0.52, BODY_L - 0.05)), **DARK)
    # the board brush on the left, swung out under the tank on its arm
    s.add(s.box((-0.72, 0.36, 1.45), (-0.95, 0.42, 1.5)), **DARK)
    s.add(s.cylinder((-1.0, 0.3, 1.5), 0.04, 0.3, axis="y"), **DARK)
    s.add(s.cylinder((-1.0, 0.17, 1.5), 0.16, 0.14, axis="y"), PAL.binder_blue, dither=PAL.placard_blue, amount=0.4)
    # the louvred grille on each side under the stand, ahead of the conditioner
    for x in (-hw + 0.1, hw - 0.1):
        s.add(s.box((x - 0.02, 0.5, BODY_L - 0.45), (x + 0.02, 0.95, BODY_L - 0.05)), PAL.silver, dither=PAL.chrome2, amount=0.2)
        s.slots((x - 0.03, 0.55, BODY_L - 0.42), (x + 0.03, 0.9, BODY_L - 0.08), pitch=0.05, slot=0.02, along="y", colour=PAL.grey_dark)
    # the snow tank: a rounded box with the nose sloped off and two ribs on top
    tank = s.rbox((0.0, (0.42 + TANK_TOP) / 2, (0.10 + TANK_Z1) / 2), (W, TANK_TOP - 0.42, TANK_Z1 - 0.10), r=0.07)
    # the top: a gentle slope down to the nose (n . p <= k, n normalised by plane())
    run = np.hypot(NOSE_RUN, TANK_TOP - NOSE_TOP)
    nose = s.plane((0.0, NOSE_RUN, -(TANK_TOP - NOSE_TOP)), (NOSE_RUN * NOSE_TOP - (TANK_TOP - NOSE_TOP) * 0.15) / run)
    s.add(tank & nose, **BLUE)
    s.paint(tank & s.plane((0.0, 1.0, 0.0), 100.0) - s.plane((0.0, 1.0, 0.0), SEAM_Y), PAL.machine_white, dither=PAL.machine_white2, amount=0.15)
    for x in (-0.55, 0.55):
        s.add(s.rbox((x, TANK_TOP - 0.1, TANK_Z1 - 0.35), (0.16, 0.05, 0.5), r=0.015), **WHITE)
    # the bin's seams: the dump door at the front, the lid at the back, the lift strap along the side
    s.paint(s.box((-hw - 0.01, SEAM_Y + 0.02, 0.95), (hw + 0.01, SEAM_Y + 0.04, TANK_Z1 - 0.1)), PAL.grey_dark)
    s.paint(s.box((-hw + 0.15, TANK_TOP - 0.4, TANK_Z1 - 0.12), (hw - 0.15, TANK_TOP + 0.1, TANK_Z1 - 0.10)), PAL.grey_dark)
    s.paint(s.box((-hw - 0.01, 1.5, 0.3), (hw + 0.01, 1.53, TANK_Z1 - 0.05)), PAL.silver)
    for face, x in (("left", -hw), ("right", hw)):
        s.label("ZAMBELLI", (x, 0.78, 1.1), face=face, size=0.04, ink=PAL.machine_white, spacing=0)
        s.label("552", (x, 1.3, 0.5), face=face, size=0.02, ink=PAL.ink, plate=PAL.cream)
    # the front bumper, the tail lamps on the rear corners of the tank
    s.add(s.box((-hw + 0.05, 0.45, 0.04), (hw - 0.05, 0.62, 0.14)), **DARK)
    for x in (-hw + 0.2, hw - 0.2):
        s.paint(s.cylinder((x, 1.5, TANK_Z1 - 0.03), 0.07, 0.08, axis="z"), PAL.red)
    # wheel arches
    for z in (FRONT_AXLE, REAR_AXLE):
        for x in (-WHEEL_X, WHEEL_X):
            s.cut(s.cylinder((x, WHEEL_R, z), WHEEL_R + 0.08, WHEEL_W + 0.14, axis="x"))
    # the axles and the drive shaft between them
    for z in (FRONT_AXLE, REAR_AXLE):
        s.add(s.cylinder((0.0, WHEEL_R, z), 0.05, W - 0.5, axis="x"), **DARK)
        s.add(s.sphere((0.0, WHEEL_R, z), 0.13), **DARK)
    s.add(s.cylinder((0.0, WHEEL_R, (FRONT_AXLE + REAR_AXLE) / 2), 0.035, REAR_AXLE - FRONT_AXLE, axis="z"), **STEEL)
    # the operator's stand: the water tank under the deck, the deck plate, a rear step
    s.add(s.rbox((0.0, (0.45 + DECK_Y) / 2, (TANK_Z1 + BODY_L - 0.15) / 2), (W - 0.2, DECK_Y - 0.45, BODY_L - 0.15 - TANK_Z1), r=0.04), **BLUE)
    s.add(s.box((-hw, DECK_Y - 0.05, TANK_Z1), (hw, DECK_Y, BODY_L)), **STEEL)
    s.grille((-hw, DECK_Y - 0.005, TANK_Z1 + 0.1), (hw, DECK_Y + 0.01, BODY_L - 0.1), pitch=0.08, hole=0.03, depth_axis="y", colour=PAL.steel2)
    s.add(s.box((-hw + 0.1, 0.3, BODY_L - 0.2), (hw - 0.1, 0.5, BODY_L)), **DARK)
    # the tank's back wall rises above the deck a little, with the chute into it
    s.add(s.box((-hw + 0.05, DECK_Y, TANK_Z1 - 0.05), (hw - 0.05, TANK_TOP, TANK_Z1 + 0.05)), **BLUE)
    # the vertical auger drum, its upper bearing and the motor on top
    s.add(s.cylinder((0.1, (DECK_Y + 1.95) / 2, 2.32), 0.30, 1.95 - DECK_Y, axis="y", r=0.02), **BLUE)
    s.add(s.cylinder((0.1, 2.08, 2.32), 0.22, 0.3, axis="y", r=0.02), **STEEL)
    s.add(s.rbox((0.1, 2.3, 2.32), (0.22, 0.16, 0.22), r=0.03), **DARK)
    s.add(s.box((-0.1, 1.75, TANK_Z1 - 0.1), (0.3, 1.95, 2.1)), **BLUE)  # the chute to the tank
    # the seat at the left rear: pedestal, cushion, backrest
    s.add(s.cylinder((-0.6, 1.2, 3.0), 0.05, 0.4, axis="y"), **DARK)
    s.add(s.rbox((-0.6, 1.43, 3.02), (0.5, 0.12, 0.46), r=0.04), PAL.grey_mid, dither=PAL.grey_dark, amount=0.2)
    s.add(s.rbox((-0.6, 1.74, 3.28), (0.5, 0.55, 0.11), r=0.04), PAL.grey_mid, dither=PAL.grey_dark, amount=0.2)
    s.paint(s.rbox((-0.6, 1.74, 3.225), (0.36, 0.4, 0.02), r=0.02), PAL.grey_dark)  # the backrest's panel
    # the steering column, the wheel with three spokes, the dash with two gauges
    s.add(s.cylinder((-0.6, (DECK_Y + 1.58) / 2, 2.32), 0.03, 1.58 - DECK_Y, axis="y"), **DARK)
    s.add(s.cylinder((-0.6, 1.6, 2.32), 0.22, 0.04, axis="y") - s.cylinder((-0.6, 1.6, 2.32), 0.18, 0.1, axis="y"), PAL.black)
    s.add(s.cylinder((-0.6, 1.6, 2.32), 0.05, 0.05, axis="y"), PAL.black)
    for a in (0.0, 2.1, 4.2):
        c = (-0.6 + 0.1 * np.sin(a), 1.6, 2.32 + 0.1 * np.cos(a))
        s.add(s.rbox(c, (0.03 + 0.2 * abs(np.sin(a)), 0.025, 0.03 + 0.2 * abs(np.cos(a))), r=0.01), PAL.black)
    s.add(s.rbox((-0.6, 1.33, 2.12), (0.62, 0.34, 0.12), r=0.02), **BLUE)
    s.paint(s.rbox((-0.55, 1.36, 2.18), (0.36, 0.2, 0.03), r=0.01), PAL.black)
    for x in (-0.66, -0.46):
        s.paint(s.cylinder((x, 1.38, 2.18), 0.065, 0.03, axis="z"), PAL.cream)
        s.paint(s.cylinder((x, 1.38, 2.18), 0.05, 0.03, axis="z"), PAL.white)
        s.paint(s.rbox((x, 1.4, 2.18), (0.008, 0.07, 0.03)), PAL.red_dark)
    s.paint(s.rbox((-0.84, 1.3, 2.18), (0.04, 0.04, 0.03), r=0.01), PAL.green_led)  # the pilot lamp
    s.add(s.rbox((-0.38, 1.25, 2.14), (0.04, 0.03, 0.04), r=0.005), PAL.red)  # the wash pump rocker
    # the pedals
    for x in (-0.75, -0.45):
        s.add(s.rbox((x, DECK_Y + 0.04, 2.45), (0.1, 0.06, 0.14), r=0.01), PAL.rubber)
    # the control block to the right of the seat: levers, the shifter in its
    # gate, the plunger, the two T-handle valves and the blade wheel
    s.add(s.rbox((0.45, (DECK_Y + 1.5) / 2, 2.6), (0.9, 1.5 - DECK_Y, 0.9), r=0.03), **BLUE)  # the lever console
    s.add(s.rbox((0.72, (DECK_Y + 1.55) / 2, 2.7), (0.6, 1.55 - DECK_Y, 1.0), r=0.04), **BLUE)  # the wash water tank
    s.paint(s.rbox((0.72, 1.55, 2.6), (0.3, 0.03, 0.5), r=0.03), PAL.machine_blue2)  # its recessed lid
    for x, z in ((0.1, 2.6), (0.2, 2.6), (0.32, 2.6), (0.42, 2.6)):  # the white gate plates
        s.paint(s.rbox((x, 1.5, z), (0.06, 0.03, 0.18), r=0.005), PAL.machine_white)
        s.paint(s.rbox((x, 1.5, z), (0.015, 0.03, 0.14)), PAL.black)
    levers = [(0.1, 2.6, 0.2, PAL.black), (0.2, 2.6, 0.2, PAL.black), (0.32, 2.6, 0.2, PAL.black),
              (0.42, 2.6, 0.2, PAL.red), (0.62, 2.55, 0.46, PAL.black), (0.82, 2.4, 0.26, PAL.black)]
    for x, z, h, knob in levers:
        s.add(s.cylinder((x, 1.5 + h / 2, z), 0.014, h, axis="y"), PAL.chrome, dither=PAL.chrome2, amount=0.2)
        s.add(s.sphere((x, 1.5 + h, z), 0.032), knob)
    for x, z in ((0.14, 3.0), (0.5, 3.0)):  # the flood and wash valves: a stem and a bent handle
        s.add(s.cylinder((x, 1.6, z), 0.012, 0.2, axis="y"), PAL.chrome)
        s.add(s.cylinder((x, 1.7, z - 0.06), 0.016, 0.14, axis="z"), PAL.black)
    # the blade's hand wheel, flat on its block between the valves, over the
    # dark panel the lift rods run down behind
    s.add(s.rbox((0.32, 1.3, 3.05), (0.3, 0.2, 0.24), r=0.02), **BLUE)
    s.add(s.rbox((0.32, 1.1, 3.3), (0.4, 0.3, 0.1), r=0.01), **DARK)
    wheel_c = (0.32, 1.42, 3.05)
    s.add(s.cylinder(wheel_c, 0.13, 0.03, axis="y") - s.cylinder(wheel_c, 0.10, 0.1, axis="y"), PAL.black)
    s.add(s.cylinder(wheel_c, 0.035, 0.08, axis="y"), PAL.grey_dark)
    for a in (0.0, 1.5708):
        s.add(s.rbox(wheel_c, (0.025 + 0.22 * abs(np.cos(a)), 0.02, 0.025 + 0.22 * abs(np.sin(a))), r=0.005), PAL.black)
    for x in (0.12, 0.32, 0.52):  # the lift rods down into the trough
        s.add(s.cylinder((x, 1.2, 3.3), 0.012, 0.5, axis="y"), PAL.chrome, dither=PAL.chrome2, amount=0.2)
    # the water trough along the rear edge of the deck, silver, with the
    # wash pipes bending down into it
    s.add(s.box((-hw + 0.05, DECK_Y - 0.02, BODY_L - 0.22), (hw - 0.05, DECK_Y + 0.1, BODY_L)), PAL.silver, dither=PAL.chrome2, amount=0.2)
    s.cut(s.box((-hw + 0.08, DECK_Y + 0.02, BODY_L - 0.19), (hw - 0.08, DECK_Y + 0.11, BODY_L - 0.03)))
    for x in (-0.3, 0.86):
        s.add(s.cylinder((x, DECK_Y + 0.2, BODY_L - 0.12), 0.018, 0.4, axis="y"), PAL.chrome, dither=PAL.chrome2, amount=0.2)
    for x in (-hw + 0.3, hw - 0.3):
        s.paint(s.rbox((x, DECK_Y + 0.05, BODY_L), (0.1, 0.05, 0.03)), PAL.cream)
        s.paint(s.rbox((x, DECK_Y + 0.065, BODY_L), (0.08, 0.012, 0.03)), PAL.red)
    # the side rails of the stand and the step up to it on the left
    for x in (-hw + 0.03, hw - 0.03):
        s.add(s.box((x - 0.02, DECK_Y, BODY_L - 0.5), (x + 0.02, DECK_Y + 0.5, BODY_L - 0.46)), **STEEL)
        s.add(s.box((x - 0.02, DECK_Y + 0.48, BODY_L - 0.5), (x + 0.02, DECK_Y + 0.5, BODY_L)), **STEEL)
    s.add(s.box((-hw - 0.05, 0.55, 2.3), (-hw + 0.1, 0.6, 2.7)), **STEEL)
    # the conditioner's lift arms, down from the chassis behind the rear axle
    for x in (-0.6, 0.6):
        s.add(s.box((x - 0.04, 0.35, BODY_L - 0.4), (x + 0.04, 0.5, BODY_L + 0.04)), **STEEL)
    # the standpipe fill cap on the left of the tank's back wall
    s.add(s.cylinder((-0.85, 1.8, TANK_Z1 + 0.08), 0.06, 0.08, axis="z"), PAL.chrome)
    return s


def conditioner() -> Scene:
    v = 0.01
    s = Scene((COND_W + 0.1, 0.56, COND_D + 0.02), v, origin=(-(COND_W + 0.1) / 2, 0.0, 0.0))
    hw = COND_W / 2
    # the side plates (the skids), rounded at the front, the top plate, the front and back walls
    for x in (-hw, hw):
        s.add(s.rbox((x, COND_H / 2, COND_D / 2), (0.05, COND_H, COND_D), r=0.01), **BLUE)
    # the top plate, open over the auger so the snow it carries is in view
    s.add(s.box((-hw, COND_H - 0.03, 0.05), (hw, COND_H, COND_D - 0.05)), **WHITE)
    s.cut(s.box((-hw + 0.08, COND_H - 0.04, 0.07), (hw - 0.08, COND_H + 0.01, AUGER_Z - COND_Z0 + AUGER_R + 0.03)))
    s.add(s.box((-hw, 0.08, 0.0), (hw, COND_H, 0.03)), **BLUE)
    s.add(s.box((-hw, 0.1, COND_D - 0.05), (hw, COND_H, COND_D)), **BLUE)
    # the water trough along the top, two silver plates, and the white bar
    # with its bolts along the bottom of the back
    for x0, x1 in ((-hw + 0.12, -0.12), (0.12, hw - 0.12)):
        s.paint(s.box((x0, COND_H - 0.01, 0.35), (x1, COND_H + 0.01, COND_D - 0.1)), PAL.silver, dither=PAL.chrome2, amount=0.2)
    s.add(s.box((-hw + 0.02, 0.07, COND_D - 0.02), (hw - 0.02, 0.15, COND_D + 0.01)), **WHITE)
    for i in range(14):
        s.paint(s.rbox((-hw + 0.15 + i * 0.15, 0.11, COND_D), (0.015, 0.015, 0.03)), PAL.grey_dark)
    for x in (-hw + 0.25, hw - 0.25):  # the warning labels
        s.paint(s.rbox((x, 0.28, COND_D), (0.1, 0.06, 0.03)), PAL.cream)
        s.paint(s.rbox((x, 0.3, COND_D), (0.08, 0.015, 0.03)), PAL.red)
    # the blade: a long bar on edge behind the auger, its holder angled over it
    s.add(s.box((-hw + 0.06, 0.0, BLADE_Z - COND_Z0 - 0.03), (hw - 0.06, 0.03, BLADE_Z - COND_Z0 + 0.06)), PAL.chrome, dither=PAL.chrome2, amount=0.2)
    s.add(s.box((-hw + 0.06, 0.03, BLADE_Z - COND_Z0 - 0.01), (hw - 0.06, 0.14, BLADE_Z - COND_Z0 + 0.08)), **DARK)
    # the wash water pipe with its nozzles, and the squeegee behind them
    wz = BLADE_Z - COND_Z0 + 0.16
    s.add(s.cylinder((0.0, 0.13, wz), 0.015, COND_W - 0.2, axis="x"), PAL.chrome, dither=PAL.chrome2, amount=0.2)
    for i in range(19):
        s.add(s.cylinder((-0.9 + i * 0.1, 0.09, wz), 0.008, 0.06, axis="y"), PAL.chrome)
    s.add(s.box((-hw + 0.06, 0.0, wz + 0.05), (hw - 0.06, 0.07, wz + 0.075)), PAL.rubber)
    s.add(s.box((-hw + 0.06, 0.07, wz + 0.04), (hw - 0.06, 0.12, wz + 0.085)), **DARK)
    # the flood pipe at the back, and the towel hanging from it to the ice
    fz = COND_D - 0.16
    s.add(s.cylinder((0.0, 0.16, fz), 0.02, COND_W - 0.2, axis="x"), PAL.chrome, dither=PAL.chrome2, amount=0.2)
    for i in range(21):
        s.paint(s.cylinder((-1.0 + i * 0.1, 0.15, fz), 0.006, 0.05, axis="y"), PAL.grey_dark)
    towel = s.box((-hw + 0.04, 0.0, fz + 0.02), (hw - 0.04, 0.17, COND_D - 0.04))
    s.add(towel, PAL.towel, dither=PAL.towel2, amount=0.3)
    for i in range(12):  # the towel's folds
        s.paint(s.box((-hw + 0.1 + i * 0.17, 0.0, fz + 0.02), (-hw + 0.12 + i * 0.17, 0.15, COND_D)), PAL.towel2)
    # the lift arm stubs on top, the hydraulic ram's rod in the middle, and
    # the two chrome water pipes bending down into the trough
    for x in (-0.6, 0.6):
        s.add(s.box((x - 0.04, COND_H, 0.1), (x + 0.04, COND_H + 0.18, 0.16)), **STEEL)
        s.add(s.cylinder((x, COND_H + 0.16, 0.13), 0.025, 0.1, axis="x"), PAL.black)
    s.add(s.cylinder((0.0, COND_H + 0.1, 0.3), 0.02, 0.2, axis="y"), PAL.black)
    for x, z in ((-0.3, wz), (0.3, fz)):
        s.add(s.cylinder((x, COND_H + 0.1, z), 0.018, 0.2, axis="y"), PAL.chrome, dither=PAL.chrome2, amount=0.2)
        s.add(s.cylinder((x, COND_H + 0.2, z - 0.06), 0.018, 0.14, axis="z"), PAL.chrome, dither=PAL.chrome2, amount=0.2)
    return s


def auger() -> Scene:
    v = 0.01
    s = Scene((AUGER_L + 0.02, AUGER_R * 2 + 0.02, AUGER_R * 2 + 0.02), v, origin=(-(AUGER_L + 0.02) / 2, 0.0, 0.0))
    c = (0.0, AUGER_R + 0.01, AUGER_R + 0.01)
    s.add(s.cylinder(c, 0.04, AUGER_L, axis="x"), **STEEL)
    s.add(_helix(s, c, AUGER_R, 0.035, AUGER_L - 0.04, 0.26, 0.022), PAL.steel, dither=PAL.grey_mid, amount=0.3)
    s.add(s.cylinder(c, 0.055, 0.12, axis="x"), **DARK)  # the centre bearing
    return s


def lift() -> Scene:
    """The vertical auger: a single screw up a shaft, built along X like the
    horizontal one (the node stands it up). Where the horizontal auger's
    two halves meet it takes the snow up into the tank."""
    v = 0.01
    s = Scene((LIFT_L + 0.02, LIFT_R * 2 + 0.02, LIFT_R * 2 + 0.02), v, origin=(-(LIFT_L + 0.02) / 2, 0.0, 0.0))
    c = (0.0, LIFT_R + 0.01, LIFT_R + 0.01)
    s.add(s.cylinder(c, 0.05, LIFT_L, axis="x"), **STEEL)
    s.add(_helix(s, c, LIFT_R, 0.045, LIFT_L - 0.04, 0.3, 0.022, hand_split=False), PAL.steel, dither=PAL.grey_mid, amount=0.3)
    return s


def wheel() -> Scene:
    v = 0.01
    s = Scene((WHEEL_W + 0.02, WHEEL_R * 2 + 0.02, WHEEL_R * 2 + 0.02), v, origin=(-(WHEEL_W + 0.02) / 2, 0.0, 0.0))
    c = (0.0, WHEEL_R + 0.01, WHEEL_R + 0.01)
    tyre = s.cylinder(c, WHEEL_R, WHEEL_W, axis="x", r=0.04) - s.cylinder(c, WHEEL_R - 0.11, WHEEL_W + 0.1, axis="x")
    s.add(tyre, PAL.tyre, dither=PAL.tyre2, amount=0.3)
    # the tread: lugs round the circumference, offset on the two halves
    theta = np.arctan2(s.Z - c[2], s.Y - c[1])
    r = np.hypot(s.Z - c[2], s.Y - c[1])
    lug = 2 * np.pi / 22
    for half, off in ((-1, 0.0), (1, lug / 2)):
        on_half = (s.X * half > 0.0) & (np.abs(s.X) < WHEEL_W / 2 - 0.02)
        groove = (np.mod(theta + off, lug) > lug * 0.55) & (r > WHEEL_R - 0.03) & on_half
        s.colour[groove] = 0
    # the rim and the hub with its bolt circle
    s.add(s.cylinder(c, WHEEL_R - 0.1, WHEEL_W - 0.08, axis="x"), PAL.chrome, dither=PAL.chrome2, amount=0.25)
    s.add(s.cylinder(c, 0.08, WHEEL_W + 0.02, axis="x"), **DARK)
    for i in range(10):
        a = i * np.pi / 5
        s.paint(s.cylinder((c[0], c[1] + 0.2 * np.cos(a), c[2] + 0.2 * np.sin(a)), 0.022, WHEEL_W + 0.03, axis="x"), PAL.grey_dark)
        s.add(s.cylinder((c[0], c[1] + 0.13 * np.cos(a + 0.3), c[2] + 0.13 * np.sin(a + 0.3)), 0.012, WHEEL_W - 0.04, axis="x"), PAL.silver)
    return s


def render(scene: Scene, az_deg: float, el_deg: float, px: int = 640) -> np.ndarray:
    """An orthographic render of the scene's surface from azimuth `az` (0
    looks at the front, 90 at the right side, 180 at the back) and
    elevation `el` (negative looks up from under the floor)."""
    keep = scene.surface()
    xs, ys, zs = np.nonzero(keep)
    idx = scene.colour[xs, ys, zs]
    cols = np.array([(0, 0, 0)] + [propgen.PALETTE[n] for n in propgen.NAMES], dtype=np.float32) / 255.0
    c = cols[idx]
    g = np.pad(scene.colour > 0, 1)
    top = ~g[xs + 1, ys + 2, zs + 1]
    bottom = ~g[xs + 1, ys, zs + 1]
    front = ~g[xs + 1, ys + 1, zs]
    back = ~g[xs + 1, ys + 1, zs + 2]
    right = ~g[xs + 2, ys + 1, zs + 1]
    left = ~g[xs, ys + 1, zs + 1]
    a = np.radians(az_deg)
    e = np.radians(el_deg)
    # the view direction and the shade of each visible face
    view = np.array([np.sin(a) * np.cos(e), np.sin(e), -np.cos(a) * np.cos(e)])
    light = np.array([0.4, 0.8, -0.45])
    light /= np.linalg.norm(light)
    normals = {"top": (0, 1, 0), "bottom": (0, -1, 0), "front": (0, 0, -1), "back": (0, 0, 1), "right": (1, 0, 0), "left": (-1, 0, 0)}
    masks = {"top": top, "bottom": bottom, "front": front, "back": back, "right": right, "left": left}
    shade = np.full(len(xs), 0.45)
    for name, n in normals.items():
        n = np.array(n, dtype=np.float32)
        if n @ view <= 0.0:
            continue
        s = 0.55 + 0.45 * max(0.0, float(n @ light))
        shade = np.where(masks[name], np.maximum(shade, s), shade)
    n = np.array(scene.n)
    X = xs - n[0] / 2
    Y = ys - n[1] / 2
    Z = zs - n[2] / 2
    xr = X * np.cos(a) + Z * np.sin(a)
    zr = -X * np.sin(a) + Z * np.cos(a)
    u = xr
    v = Y * np.cos(e) + zr * np.sin(e)
    depth = -zr * np.cos(e) + Y * np.sin(e)
    ext = n.max() * 1.05
    scale = px / ext
    U = ((u / ext + 0.5) * px).astype(int)
    V = ((0.5 - v / ext) * px).astype(int)
    img = np.full((px, px, 3), (0.17, 0.18, 0.2), dtype=np.float32)
    zbuf = np.full((px, px), -np.inf)
    r = max(1, int(np.ceil(scale)))
    rgb = c * shade[:, None]
    order = np.argsort(depth)
    for i in order:
        uu, vv = U[i], V[i]
        if 0 <= uu < px and 0 <= vv < px:
            img[vv:vv + r, uu:uu + r] = rgb[i]
    return (np.clip(img, 0, 1) * 255).astype(np.uint8)


def views(scene: Scene, path: str, px: int = 560) -> None:
    """Four views on one sheet: front right, back left, back right, from below."""
    from PIL import Image

    tiles = [render(scene, 35, 28, px), render(scene, 215, 28, px), render(scene, 145, 24, px), render(scene, 200, -35, px)]
    sheet = Image.new("RGB", (px * 2, px * 2))
    for i, t in enumerate(tiles):
        sheet.paste(Image.fromarray(t), ((i % 2) * px, (i // 2) * px))
    sheet.save(path)


PARTS = {
    "zambelli_body": dict(build=body, name="Zambelli 552", mass_kg=3200.0, sound="metal",
                          inspect="The rink's resurfacer. Her name is Doris and she has opinions about the plant room floor."),
    "zambelli_conditioner": dict(build=conditioner, name="Conditioner", mass_kg=400.0, sound="metal",
                                 inspect="The conditioner: the auger, the blade, the wash pipe and squeegee, the flood pipe and the towel."),
    "zambelli_auger": dict(build=auger, name="Horizontal auger", mass_kg=60.0, sound="metal",
                           inspect="The horizontal auger. Both halves wind toward the middle, where the vertical auger takes over."),
    "zambelli_lift": dict(build=lift, name="Vertical auger", mass_kg=40.0, sound="metal",
                          inspect="The vertical auger. It takes the snow from the middle of the conditioner up into the tank."),
    "zambelli_wheel": dict(build=wheel, name="Resurfacer wheel", mass_kg=45.0, sound="rubber",
                           inspect="A studded tyre on a steel rim."),
}


def generate(ids: list[str], preview: bool) -> None:
    os.makedirs(VOX_DIR, exist_ok=True)
    os.makedirs(DATA_DIR, exist_ok=True)
    if preview:
        os.makedirs(PREVIEW_DIR, exist_ok=True)
    for pid in ids:
        spec = PARTS[pid]
        scene = spec["build"]()
        geo = scene.write(os.path.join(VOX_DIR, f"{pid}.vox"))
        rec = {
            "id": pid,
            "name": spec["name"],
            "vox": f"art/props/{pid}.vox",
            "voxel_m": scene.voxel_m,
            "size_m": geo["size_m"],
            "pivot": geo["pivot"],
            "mass_kg": spec["mass_kg"],
            "tags": ["machine", "resurfacer"],
            "verbs": ["inspect"],
            "inspect": spec["inspect"],
            "sound": spec["sound"],
            "shape": [],
            "mesh": "merged",
            "collision_cell": 8,
            "tri_cap": 200000,
            "wear": {"worn": "tint:8a7a60:0.2", "repaired": "tint:8a7a60:0.08", "renovated": "none"},
            "source": "tools/propgen/zambelli.py",
        }
        manifest(os.path.join(DATA_DIR, f"{pid}.json"), rec)
        print(f"{pid}: {geo['size_vox']} voxels, {geo['voxels']} surface of {geo['solid']} solid, {geo['size_m']} m")
        if preview:
            views(scene, os.path.join(PREVIEW_DIR, f"{pid}.png"))


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    ids = [a if a.startswith("zambelli_") else f"zambelli_{a}" for a in args]
    generate(ids or list(PARTS.keys()), preview="--preview" in sys.argv)
