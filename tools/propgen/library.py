"""The retro-electronics prop library: eight props generated to sit next to
the reference models (CRT television, record player, micro cassette,
truck) in art/props/. Each prop is a function that builds a Scene; the
table at the bottom carries the manifest fields a model cannot know.

    python3 tools/propgen/library.py            # every prop
    python3 tools/propgen/library.py boombox    # one, with a preview PNG

Writes art/props/<id>.vox, data/props/<id>.json and, with --preview,
art/props/preview/<id>.png (quick render, no AO; the prop sheet is the
real look).
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from propgen import PAL, Scene, manifest  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
VOX_DIR = os.path.join(ROOT, "art", "props")
DATA_DIR = os.path.join(ROOT, "data", "props")
PREVIEW_DIR = os.path.join(VOX_DIR, "preview")


# ---------------------------------------------------------------- props


def boombox() -> Scene:
    """A late-70s portable stereo: two speakers, a cassette door, a tuner
    window, a chrome handle. 0.56 x 0.19 x 0.13 m at 3 mm voxels."""
    v = 0.003
    s = Scene((0.56, 0.24, 0.14), v)
    W, H, D = 0.56, 0.19, 0.13
    cx, cz = W / 2, D / 2
    body = s.rbox((cx, H / 2, cz), (W, H, D), r=0.012)
    s.add(body, PAL.body, dither=PAL.body2, amount=0.2)
    # chrome trim band along the top edge
    s.paint(s.box((0.0, H - 0.016, 0.0), (W, H - 0.008, D)), PAL.chrome, dither=PAL.chrome2)
    # speakers: recessed rings with a grille
    for sx in (0.10, W - 0.10):
        ring = s.cylinder((sx, 0.085, 0.0), 0.070, 0.012, axis="z")
        s.paint(ring, PAL.grey_dark)
        s.cut(s.cylinder((sx, 0.085, -0.002), 0.064, 0.010, axis="z"))
        cone = s.cylinder((sx, 0.085, 0.004), 0.064, 0.006, axis="z")
        s.add(cone, PAL.black)
        s.grille((sx - 0.064, 0.021, -0.001), (sx + 0.064, 0.149, 0.006), pitch=0.009, hole=0.0045, depth_axis="z", colour=PAL.grey)
        s.paint(s.cylinder((sx, 0.085, 0.0), 0.014, 0.014, axis="z"), PAL.chrome)
    # cassette door between the speakers
    door = s.rbox((cx, 0.070, 0.0), (0.16, 0.085, 0.010), r=0.004)
    s.paint(door, PAL.teal_dark)
    window = s.rbox((cx, 0.078, 0.0), (0.12, 0.040, 0.008), r=0.003)
    s.paint(window, PAL.blue_glass, dither=PAL.blue_glass2)
    for hx in (cx - 0.035, cx + 0.035):
        s.paint(s.cylinder((hx, 0.078, 0.0), 0.009, 0.008, axis="z"), PAL.white)
        s.paint(s.cylinder((hx, 0.078, 0.0), 0.004, 0.008, axis="z"), PAL.grey_dark)
    # piano keys under the door
    keys = ["REW", "PLAY", "FF", "STOP", "REC"]
    kw = 0.028
    for i, k in enumerate(keys):
        kx = cx - (len(keys) - 1) * kw / 2 + i * kw
        key = s.rbox((kx, 0.022, -0.004), (0.024, 0.014, 0.014), r=0.002)
        s.add(key, PAL.red if k == "REC" else PAL.silver, dither=None if k == "REC" else PAL.silver2)
        # a dark groove between keys instead of names (no room for 3 mm type)
        s.paint(s.box((kx + kw / 2 - 0.001, 0.014, -0.001), (kx + kw / 2 + 0.001, 0.030, 0.004)), PAL.black)
    # tuner window and dial
    tuner = s.rbox((cx, 0.138, 0.0), (0.24, 0.034, 0.008), r=0.003)
    s.paint(tuner, PAL.cream, dither=PAL.cream2, amount=0.15)
    s.paint(s.box((cx - 0.115, 0.130, -0.001), (cx + 0.115, 0.133, 0.004)), PAL.ink)
    for i in range(13):
        tx = cx - 0.108 + i * 0.018
        s.paint(s.box((tx - 0.001, 0.127, -0.001), (tx + 0.001, 0.136 if i % 3 == 0 else 0.133, 0.004)), PAL.ink)
    s.paint(s.box((cx + 0.030, 0.124, -0.001), (cx + 0.033, 0.152, 0.004)), PAL.red)
    s.label("FM", (cx - 0.090, 0.146, 0.0), face="front", size=v, ink=PAL.ink)
    s.label("88  96  104", (cx + 0.020, 0.146, 0.0), face="front", size=v, ink=PAL.ink)
    s.label("STEREO", (cx, H, cz + 0.030), face="top", size=v, ink=PAL.ink)
    # volume and tone knobs on the right end of the top band
    for kx in (W - 0.060, W - 0.100):
        s.add(s.cylinder((kx, H + 0.006, cz), 0.012, 0.012, axis="y"), PAL.chrome, dither=PAL.chrome2)
        s.paint(s.box((kx - 0.001, H + 0.010, cz - 0.011), (kx + 0.001, H + 0.013, cz)), PAL.red)
    # antenna stub and handle
    s.add(s.cylinder((0.040, H + 0.010, cz), 0.004, 0.020, axis="y"), PAL.chrome)
    handle = s.rbox((cx, H + 0.032, cz), (0.30, 0.012, 0.016), r=0.005) - s.rbox((cx, H + 0.032, cz), (0.27, 0.014, 0.020))
    s.add(handle, PAL.chrome, dither=PAL.chrome2)
    s.add(s.rbox((cx, H + 0.044, cz), (0.30, 0.012, 0.016), r=0.005), PAL.chrome, dither=PAL.chrome2)
    # feet
    for fx in (0.05, W - 0.05):
        for fz in (0.02, D - 0.02):
            s.add(s.cylinder((fx, -0.003, fz), 0.008, 0.008, axis="y"), PAL.rubber)
    s.screw((0.018, 0.018, 0.0), 0.004)
    s.screw((W - 0.018, 0.018, 0.0), 0.004)
    s.screw((0.018, H - 0.028, 0.0), 0.004)
    s.screw((W - 0.018, H - 0.028, 0.0), 0.004)
    return s


def vcr() -> Scene:
    """A front-loading VHS deck: silver face, tape slot, a green display,
    a row of buttons. 0.43 x 0.095 x 0.30 m at 3 mm voxels."""
    v = 0.003
    s = Scene((0.43, 0.10, 0.30), v)
    W, H, D = 0.43, 0.095, 0.30
    cx = W / 2
    s.add(s.rbox((cx, H / 2, D / 2), (W, H, D), r=0.006), PAL.grey_dark, dither=PAL.grey_dark2, amount=0.18)
    # silver face plate
    s.paint(s.box((0.0, 0.0, 0.0), (W, H, 0.012)), PAL.silver, dither=PAL.silver2, amount=0.18)
    # tape slot with a dark flap
    s.cut(s.box((0.040, 0.050, -0.002), (0.230, 0.078, 0.014)))
    s.add(s.box((0.042, 0.052, 0.010), (0.228, 0.076, 0.016)), PAL.black)
    s.label("VHS", (0.135, 0.040, 0.0), face="front", size=v, ink=PAL.ink)
    # display window
    s.paint(s.rbox((0.330, 0.064, 0.0), (0.130, 0.024, 0.008), r=0.002), PAL.black)
    s.label("12:00", (0.330, 0.064, 0.0), face="front", size=v, ink=PAL.green_led)
    # buttons
    names = ["EJECT", "REW", "PLAY", "FF", "STOP", "REC"]
    for i, k in enumerate(names):
        bx = 0.050 + i * 0.036
        s.add(s.rbox((bx, 0.022, -0.003), (0.026, 0.011, 0.010), r=0.002), PAL.red if k == "REC" else PAL.grey, dither=None if k == "REC" else PAL.grey_mid)
    s.label("PLAY", (0.122, 0.036, 0.0), face="front", size=v, ink=PAL.ink)
    s.label("STOP", (0.194, 0.036, 0.0), face="front", size=v, ink=PAL.ink)
    # power button and lamp
    s.add(s.rbox((0.395, 0.022, -0.003), (0.030, 0.011, 0.010), r=0.002), PAL.grey, dither=PAL.grey_mid)
    s.paint(s.cylinder((0.395, 0.040, 0.0), 0.003, 0.008, axis="z"), PAL.red)
    # top vents and rear ports
    s.slots((0.03, H - 0.001, 0.12), (W - 0.03, H + 0.002, 0.26), pitch=0.012, slot=0.004, along="z", colour=PAL.black)
    for px in (0.06, 0.09, 0.12):
        s.paint(s.cylinder((px, 0.045, D), 0.006, 0.008, axis="z"), PAL.amber_dim)
        s.paint(s.cylinder((px, 0.045, D), 0.003, 0.008, axis="z"), PAL.black)
    for fx in (0.03, W - 0.03):
        for fz in (0.03, D - 0.03):
            s.add(s.cylinder((fx, -0.003, fz), 0.009, 0.008, axis="y"), PAL.rubber)
    for sx in (0.015, W - 0.015):
        s.screw((sx, H / 2, 0.0), 0.004)
    return s


def vhs_tape() -> Scene:
    """A VHS cassette with a hand-written label. 0.188 x 0.025 x 0.104 m at
    1.2 mm voxels (the micro cassette's density)."""
    v = 0.0015
    s = Scene((0.19, 0.03, 0.11), v)
    W, H, D = 0.188, 0.025, 0.104
    s.add(s.rbox((W / 2, H / 2, D / 2), (W, H, D), r=0.003), PAL.grey_dark, dither=PAL.grey_dark2, amount=0.18)
    # reel windows on top
    for rx in (0.055, W - 0.055):
        s.paint(s.cylinder((rx, H, 0.050), 0.028, 0.004, axis="y"), PAL.blue_glass, dither=PAL.blue_glass2)
        s.paint(s.cylinder((rx, H, 0.050), 0.009, 0.004, axis="y"), PAL.white)
        s.paint(s.cylinder((rx, H, 0.050), 0.004, 0.004, axis="y"), PAL.grey_dark)
    # spine label (front, -z) and top label
    s.label("MILLBROOK VS KESSLER 1981", (W / 2, H / 2, 0.0), face="front", size=v, ink=PAL.ink, plate=PAL.cream, pad=0.004)
    s.paint(s.rbox((W / 2, H, 0.017), (0.150, 0.004, 0.022), r=0.002), PAL.cream)
    s.label("GAME TAPE", (W / 2, H, 0.012), face="top", size=v * 1.0, ink=PAL.ink)
    s.label("DO NOT ERASE", (W / 2, H, 0.023), face="top", size=v, ink=PAL.red)
    # flap seam and finger notch on the back
    s.paint(s.box((0.0, 0.005, D - 0.002), (W, 0.0062, D)), PAL.grey)
    s.cut(s.rbox((W / 2, 0.0, D), (0.030, 0.012, 0.010), r=0.003))
    return s


def desk_phone() -> Scene:
    """A push-button desk phone with the handset in the cradle and a coiled
    cord. 0.23 x 0.11 x 0.20 m at 1.5 mm voxels."""
    v = 0.002
    s = Scene((0.23, 0.12, 0.21), v)
    W, D = 0.23, 0.20
    # wedge body: a box cut by a sloping plane
    body = s.rbox((W / 2, 0.040, D / 2), (W, 0.080, D), r=0.008) & s.plane((0.0, 1.0, -0.45), 0.075)
    s.add(body, PAL.beige, dither=PAL.beige2, amount=0.18)
    # keypad on the slope
    for row in range(4):
        for col in range(3):
            kx = W / 2 - 0.024 + col * 0.024
            kz = 0.060 + row * 0.022
            ky = 0.075 + 0.45 * kz - 0.45 * 0.0 - 0.45 * kz + 0.45 * kz  # on the plane
            ky = 0.075 + 0.45 * kz
            s.add(s.rbox((kx, ky - 0.004, kz), (0.016, 0.010, 0.014), r=0.002), PAL.white, dither=PAL.chrome)
            digit = "123456789*0#"[row * 3 + col] if row * 3 + col < 12 else "0"
            s.label(digit if digit != "#" else "-", (kx, ky + 0.0012, kz), face="top", size=v, ink=PAL.ink)
    # cradle and handset
    s.add(s.rbox((W / 2, 0.082, 0.165), (0.20, 0.010, 0.040), r=0.004), PAL.beige, dither=PAL.beige2)
    hand = s.rbox((W / 2, 0.096, 0.165), (0.210, 0.022, 0.034), r=0.010)
    ear = s.sphere((0.03, 0.098, 0.165), 0.022) | s.sphere((W - 0.03, 0.098, 0.165), 0.022)
    s.add(hand | ear, PAL.beige, dither=PAL.beige2, amount=0.18)
    s.grille((0.012, 0.100, 0.150), (0.048, 0.122, 0.180), pitch=0.005, hole=0.002, depth_axis="y", colour=PAL.grey_dark)
    s.grille((W - 0.048, 0.100, 0.150), (W - 0.012, 0.122, 0.180), pitch=0.005, hole=0.002, depth_axis="y", colour=PAL.grey_dark)
    # label plate under the keypad and a red hold button
    s.label("MILLBROOK ARENA", (W / 2, 0.075 + 0.45 * 0.030, 0.030), face="top", size=v, ink=PAL.ink, plate=PAL.cream)
    s.add(s.rbox((W - 0.030, 0.075 + 0.45 * 0.060 - 0.003, 0.060), (0.018, 0.008, 0.012), r=0.002), PAL.red)
    # coiled cord along the left side
    for i in range(14):
        s.add(s.cylinder((0.010, 0.020 + i * 0.004, 0.030 + i * 0.009), 0.006, 0.003, axis="z"), PAL.beige2)
    for fx in (0.02, W - 0.02):
        for fz in (0.02, D - 0.02):
            s.add(s.cylinder((fx, -0.002, fz), 0.006, 0.006, axis="y"), PAL.rubber)
    return s


def walkie_talkie() -> Scene:
    """A rink staff handheld radio: rubber antenna, speaker grille, a big
    orange talk button. 0.065 x 0.25 x 0.035 m at 1 mm voxels."""
    v = 0.0014
    s = Scene((0.07, 0.26, 0.04), v)
    W, H, D = 0.065, 0.165, 0.035
    s.add(s.rbox((W / 2, H / 2, D / 2), (W, H, D), r=0.006), PAL.grey_dark, dither=PAL.grey_dark2, amount=0.18)
    s.grille((0.012, 0.100, -0.001), (W - 0.012, 0.150, 0.004), pitch=0.004, hole=0.002, depth_axis="z", colour=PAL.grey)
    s.paint(s.rbox((W / 2, 0.070, 0.0), (0.045, 0.028, 0.006), r=0.002), PAL.green_led)
    s.label("CH 4", (W / 2, 0.070, 0.0), face="front", size=v, ink=PAL.ink)
    s.label("RINK OPS", (W / 2, 0.038, 0.0), face="front", size=v, ink=PAL.cream)
    for i in range(3):
        s.add(s.rbox((0.016 + i * 0.016, 0.020, -0.003), (0.012, 0.010, 0.008), r=0.002), PAL.grey, dither=PAL.grey_mid)
    # talk button on the left side, knob and antenna on top
    s.add(s.rbox((-0.003, 0.120, D / 2), (0.008, 0.045, 0.018), r=0.003), PAL.amber, dither=PAL.amber_dim, amount=0.15)
    s.add(s.cylinder((W - 0.014, H + 0.006, D / 2), 0.008, 0.012, axis="y"), PAL.grey_dark)
    s.add(s.cylinder((0.016, H + 0.040, D / 2), 0.004, 0.080, axis="y", r=0.003), PAL.rubber)
    s.add(s.cylinder((0.016, H + 0.004, D / 2), 0.007, 0.008, axis="y"), PAL.grey)
    s.add(s.rbox((W / 2, 0.090, D + 0.002), (0.040, 0.100, 0.006), r=0.003), PAL.grey_dark)  # belt clip
    return s


def coffee_mug() -> Scene:
    """The Hot Stove mug: cream stoneware, a red band, the rink's name,
    a chip on the handle side. 0.12 x 0.10 x 0.085 m at 1 mm voxels."""
    v = 0.0014
    s = Scene((0.125, 0.105, 0.09), v)
    cx, cz, R, H = 0.045, 0.045, 0.042, 0.096
    s.add(s.cylinder((cx, H / 2, cz), R, H, axis="y", r=0.004), PAL.cream, dither=PAL.cream2, amount=0.15)
    s.cut(s.cylinder((cx, H / 2 + 0.006, cz), R - 0.005, H, axis="y", r=0.003))
    s.paint(s.cylinder((cx, 0.070, cz), R + 0.001, 0.012, axis="y") - s.cylinder((cx, 0.070, cz), R - 0.003, 0.02, axis="y"), PAL.red)
    # coffee inside
    s.add(s.cylinder((cx, 0.080, cz), R - 0.006, 0.004, axis="y"), PAL.wood2)
    # handle: a torus-ish loop from two boxes
    s.add(s.rbox((cx + R + 0.012, 0.050, cz), (0.028, 0.050, 0.012), r=0.006) - s.rbox((cx + R + 0.012, 0.050, cz), (0.014, 0.034, 0.02)), PAL.cream, dither=PAL.cream2, amount=0.15)
    # 1.6 mm cells: on a curve, one-voxel cells lose columns to sampling
    s.label("HOT STOVE", (cx, 0.050, cz - R), size=v * 1.2, ink=PAL.red_dark, around=(cx, cz, R), depth=v * 2.5)
    s.label("MILLBROOK", (cx, 0.034, cz - R), size=v * 1.2, ink=PAL.ink, around=(cx, cz, R), depth=v * 2.5)
    # the chip
    s.cut(s.sphere((cx + R + 0.004, 0.094, cz + 0.006), 0.006))
    return s


def microwave() -> Scene:
    """A canteen microwave: beige box, dark door with a window, a dial and
    a timer. 0.50 x 0.30 x 0.38 m at 3.5 mm voxels."""
    v = 0.004
    s = Scene((0.50, 0.31, 0.38), v)
    W, H, D = 0.50, 0.30, 0.38
    s.add(s.rbox((W / 2, H / 2, D / 2), (W, H, D), r=0.008), PAL.beige, dither=PAL.beige2, amount=0.18)
    # door
    door = s.rbox((0.175, H / 2, 0.0), (0.33, H - 0.030, 0.014), r=0.006)
    s.paint(door, PAL.grey_dark, dither=PAL.grey_dark2, amount=0.18)
    s.paint(s.rbox((0.175, H / 2, 0.0), (0.26, 0.17, 0.010), r=0.004), PAL.blue_glass, dither=PAL.blue_glass2)
    s.grille((0.050, 0.070, -0.002), (0.300, 0.230, 0.004), pitch=0.010, hole=0.004, depth_axis="z", colour=PAL.black)
    s.add(s.rbox((0.325, H / 2, -0.006), (0.012, 0.16, 0.012), r=0.004), PAL.chrome, dither=PAL.chrome2)  # handle
    # control panel
    s.paint(s.box((0.360, 0.020, 0.0), (W - 0.016, H - 0.020, 0.006)), PAL.beige2)
    s.add(s.cylinder((0.430, 0.200, -0.006), 0.026, 0.014, axis="z"), PAL.grey_dark)
    s.paint(s.box((0.429, 0.200, -0.016), (0.431, 0.224, 0.0)), PAL.white)
    s.label("TIME", (0.425, 0.240, 0.0), face="front", size=v, ink=PAL.ink)
    s.add(s.cylinder((0.430, 0.120, -0.006), 0.026, 0.014, axis="z"), PAL.grey_dark)
    s.label("HI LO", (0.425, 0.160, 0.0), face="front", size=v, ink=PAL.ink)
    s.add(s.rbox((0.425, 0.045, -0.004), (0.070, 0.018, 0.010), r=0.003), PAL.silver, dither=PAL.silver2)
    s.label("START", (0.425, 0.045, 0.0), face="front", size=v, ink=PAL.ink)
    s.slots((0.04, H - 0.001, 0.20), (W - 0.04, H + 0.002, 0.34), pitch=0.014, slot=0.005, along="z", colour=PAL.grey_dark)
    s.slots((W, 0.06, 0.06), (W + 0.002, 0.24, 0.32), pitch=0.014, slot=0.005, along="y", colour=PAL.grey_dark)
    for fx in (0.03, W - 0.03):
        for fz in (0.03, D - 0.03):
            s.add(s.cylinder((fx, -0.004, fz), 0.010, 0.010, axis="y"), PAL.rubber)
    return s


def wall_clock() -> Scene:
    """A schoolhouse wall clock: black steel rim, cream face, red second
    hand. 0.30 m across, 0.05 m deep, at 2 mm voxels; the pivot is the
    wall mount (centre back)."""
    v = 0.0025
    s = Scene((0.31, 0.31, 0.06), v)
    c = (0.155, 0.155, 0.03)
    s.add(s.cylinder(c, 0.150, 0.050, axis="z", r=0.008), PAL.black, dither=PAL.grey_dark, amount=0.15)
    s.cut(s.cylinder((c[0], c[1], 0.0), 0.138, 0.014, axis="z"))
    s.add(s.cylinder((c[0], c[1], 0.012), 0.138, 0.010, axis="z"), PAL.cream, dither=PAL.cream2, amount=0.12)
    # hour marks and numbers
    import math

    for i in range(60):
        a = math.radians(i * 6)
        r1 = 0.128 if i % 5 == 0 else 0.133
        x = c[0] - math.sin(a) * (r1 + 0.133) / 2  # clockwise as seen from the front (+X is the viewer's left)
        y = c[1] + math.cos(a) * (r1 + 0.133) / 2
        s.paint(s.rbox((x, y, 0.007), (0.004 if i % 5 else 0.006, 0.133 - r1 + 0.004, 0.004)), PAL.ink)
    for n in range(1, 13):
        a = math.radians(n * 30)
        x = c[0] - math.sin(a) * 0.108
        y = c[1] + math.cos(a) * 0.108
        s.label(str(n), (x, y, 0.007), face="front", size=v, ink=PAL.ink)
    s.label("MILLBROOK", (c[0], c[1] - 0.045, 0.007), face="front", size=v, ink=PAL.red_dark)
    # hands: 10:10
    for ang, length, width, col in ((math.radians(300), 0.075, 0.010, PAL.ink), (math.radians(60), 0.110, 0.008, PAL.ink), (math.radians(200), 0.120, 0.003, PAL.red)):
        for t in range(int(length / v)):
            d = t * v
            x = c[0] - math.sin(ang) * d
            y = c[1] + math.cos(ang) * d
            s.add(s.rbox((x, y, 0.004), (width, width, 0.004)), col)
    s.add(s.cylinder((c[0], c[1], 0.003), 0.008, 0.006, axis="z"), PAL.ink)
    # mount tab at the back
    s.add(s.rbox((c[0], c[1] + 0.120, 0.055), (0.030, 0.020, 0.010), r=0.003), PAL.grey_dark)
    return s


def wall_phone_booth() -> Scene:
    """The lobby pay phone, from Sean's photo: a wood-laminate booth hung on
    the wall (two side wings, a canopy, a shelf over a lower cubby with a
    blue binder in it), a black perforated panel with a cream wall phone,
    the handset hung on top with a red sticker, a coiled cord, and a blue
    placard to the right. 0.46 x 0.90 x 0.30 m at 5 mm voxels; the pivot is
    the wall mount (bottom centre of the back)."""
    v = 0.005
    s = Scene((0.46, 0.90, 0.31), v)
    W, H, D = 0.46, 0.90, 0.30
    T = 0.018  # board thickness
    wood = dict(colour=PAL.walnut, dither=PAL.walnut2, amount=0.2)
    # back board, sides, canopy, bottom
    s.add(s.box((0.0, 0.0, D - T), (W, H, D)), **wood)
    s.add(s.box((0.0, 0.0, 0.0), (T, H, D)), **wood)
    s.add(s.box((W - T, 0.0, 0.0), (W, H, D)), **wood)
    s.add(s.box((0.0, H - T, 0.0), (W, H, D)), **wood)
    s.add(s.box((0.0, 0.0, 0.0), (W, T, D)), **wood)
    # shelf with a thicker front edge, and the cubby under it
    shelf_y = 0.15
    s.add(s.box((T, shelf_y, 0.0), (W - T, shelf_y + T, D)), **wood)
    s.add(s.box((T, shelf_y - 0.008, 0.0), (W - T, shelf_y + T, 0.02)), **wood)
    # laminate grain: faint vertical lines on the outside faces and the shelf
    for face_lo, face_hi in (((-0.001, 0.0, 0.0), (0.002, H, D)), ((W - 0.002, 0.0, 0.0), (W + 0.001, H, D))):
        s.slots(face_lo, face_hi, pitch=0.022, slot=0.005, along="z", colour=PAL.walnut_dark)
    # black steel panel set into the back board, with the perforation grid
    px0, px1 = 0.155, 0.325
    py0, py1 = shelf_y + 0.06, H - T - 0.01
    panel_z = D - T - 0.006
    s.paint(s.box((px0, py0, panel_z), (px1, py1, D - T + 0.001)), PAL.black)
    s.add(s.box((px0, py0, panel_z), (px1, py1, D - T)), PAL.black)
    s.grille((px0 + 0.012, py0 + 0.02, panel_z - 0.001), (px1 - 0.012, py1 - 0.02, panel_z + 0.004), pitch=0.016, hole=0.006, depth_axis="z", colour=PAL.grey_dark)
    # the phone body on the panel
    bx, bw = 0.24, 0.10
    by0, bh = 0.52, 0.20
    bz = panel_z - 0.055
    s.add(s.rbox((bx, by0 + bh / 2, bz + 0.0275), (bw, bh, 0.055), r=0.006), PAL.cream, dither=PAL.cream2, amount=0.15)
    # keypad on the right half: 3 x 4 small keys in a dark bezel
    kx0 = bx + 0.024
    s.paint(s.rbox((kx0, by0 + 0.095, bz), (0.040, 0.066, 0.006), r=0.003), PAL.grey_dark)
    for row in range(4):
        for col in range(3):
            kx = kx0 - 0.012 + col * 0.012
            ky = by0 + 0.072 + row * 0.015
            s.add(s.rbox((kx, ky, bz - 0.002), (0.009, 0.010, 0.006), r=0.002), PAL.chrome, dither=PAL.chrome2, amount=0.15)
    # the handset hung on the left: earpiece over the hook at the top, mouthpiece at the bottom, a slim grip between
    hx = bx - 0.022
    hz = bz - 0.028
    s.add(s.rbox((hx, by0 + bh + 0.006, bz + 0.010), (0.034, 0.012, 0.030), r=0.003), PAL.grey_dark)  # the hook
    ear = s.rbox((hx, by0 + bh + 0.010, hz), (0.052, 0.046, 0.050), r=0.016)
    mouth = s.rbox((hx, by0 - 0.012, hz), (0.052, 0.046, 0.050), r=0.016)
    grip = s.rbox((hx, by0 + bh / 2, hz - 0.004), (0.030, bh, 0.034), r=0.013)
    s.add(ear | mouth | grip, PAL.cream, dither=PAL.cream2, amount=0.15)
    s.grille((hx - 0.016, by0 + bh - 0.008, hz - 0.028), (hx + 0.016, by0 + bh + 0.028, hz - 0.022), pitch=0.005, hole=0.002, depth_axis="z", colour=PAL.grey_dark)
    s.grille((hx - 0.016, by0 - 0.030, hz - 0.028), (hx + 0.016, by0 + 0.004, hz - 0.022), pitch=0.005, hole=0.002, depth_axis="z", colour=PAL.grey_dark)
    # the red sticker on the handset
    s.paint(s.rbox((hx, by0 + 0.17, hz - 0.02), (0.028, 0.022, 0.010), r=0.002), PAL.red)
    s.label("911", (hx, by0 + 0.17, hz - 0.02), face="front", size=v, ink=PAL.white)
    # coiled cord: from the mouthpiece down almost to the shelf and back up into the body's bottom
    import math
    for i in range(80):
        t = i / 79.0
        y = by0 - 0.03 - (by0 - 0.03 - shelf_y - T - 0.03) * math.sin(t * math.pi)
        x = hx + 0.044 * t
        z = hz + 0.012 + 0.012 * math.sin(i * 1.3)
        s.add(s.cylinder((x, y, z), 0.008, 0.005, axis="y"), PAL.cream2, dither=PAL.chrome2, amount=0.2)
    # the blue placard on the right wing of the back board
    s.paint(s.box((0.345, 0.62, D - T - 0.002), (0.395, 0.69, D - T + 0.001)), PAL.placard_blue)
    s.paint(s.box((0.352, 0.675, D - T - 0.002), (0.388, 0.680, D - T + 0.001)), PAL.white)
    for i in range(5):
        s.paint(s.box((0.352, 0.632 + i * 0.008, D - T - 0.002), (0.388 - (0.010 if i % 2 else 0.0), 0.634 + i * 0.008, D - T + 0.001)), PAL.white)
    # the binder in the cubby, a cable hanging out of the shelf's front
    s.add(s.rbox((0.23, T + 0.03, 0.15), (0.29, 0.06, 0.25), r=0.004), PAL.binder_blue, dither=PAL.binder_blue2, amount=0.2)
    s.paint(s.box((0.09, T + 0.012, 0.0), (0.37, T + 0.048, 0.03)), PAL.binder_blue2)
    s.paint(s.box((0.30, T + 0.02, 0.0), (0.355, T + 0.040, 0.026)), PAL.white)
    for i in range(3):
        s.add(s.cylinder((0.20 + i * 0.045, T + 0.06, 0.06), 0.004, 0.012, axis="y"), PAL.chrome)
    for i in range(20):
        s.add(s.cylinder((0.07 + i * 0.003, T + 0.02 - i * 0.004, 0.02 + i * 0.001), 0.003, 0.004, axis="y"), PAL.white)
    return s


# ---------------------------------------------------------------- the table

LIBRARY = {
    "boombox": dict(build=boombox, name="Boombox", mass_kg=4.5, sound="plastic",
        tags=["dressing_room", "lounge", "electronics", "handheld"], verbs=["take", "inspect", "push", "use"],
        inspect="A two-speaker portable from the year the rink opened. The tape door only closes if you hold it."),
    "vcr": dict(build=vcr, name="VCR", mass_kg=5.0, sound="metal",
        tags=["lounge", "office", "electronics"], verbs=["inspect", "push", "use"],
        inspect="Four-head VHS deck. The clock has read 12:00 since 1996."),
    "vhs_tape": dict(build=vhs_tape, name="VHS tape", mass_kg=0.22, sound="plastic",
        tags=["lounge", "office", "handheld", "clutter"], verbs=["take", "inspect", "push"],
        inspect="Millbrook vs Kessler, 1981. Somebody wrote DO NOT ERASE over an older label.",
        shape=[[0, 0], [1, 0]]),
    "desk_phone": dict(build=desk_phone, name="Desk phone", mass_kg=1.1, sound="plastic",
        tags=["office", "pro_shop", "electronics"], verbs=["inspect", "push", "use"],
        inspect="Beige push-button phone. The cord reaches the window if you lean."),
    "walkie_talkie": dict(build=walkie_talkie, name="Walkie-talkie", mass_kg=0.35, sound="plastic",
        tags=["rink_ops", "handheld", "electronics"], verbs=["take", "inspect", "push", "use"],
        inspect="Rink ops channel 4. The talk button sticks; everyone knows the click.",
        shape=[[0, 0]]),
    "coffee_mug": dict(build=coffee_mug, name="Coffee mug", mass_kg=0.3, sound="ceramic",
        tags=["canteen", "office", "handheld", "clutter"], verbs=["take", "inspect", "push"],
        inspect="Hot Stove mug. Chipped on the handle side.", shape=[[0, 0]]),
    "microwave": dict(build=microwave, name="Microwave", mass_kg=14.0, sound="metal",
        tags=["canteen", "dressing_room", "electronics"], verbs=["inspect", "open", "use"],
        inspect="Canteen microwave. The turntable has not turned since the playoffs."),
    "wall_phone_booth": dict(build=wall_phone_booth, name="Pay phone", mass_kg=22.0, sound="wood",
        tags=["lobby", "hallway", "electronics", "furniture"], verbs=["inspect", "use"],
        inspect="The lobby pay phone in its wood booth. Local calls were a quarter; the binder underneath is the league phone list.",
        pivot="wall"),
    "wall_clock": dict(build=wall_clock, name="Wall clock", mass_kg=1.4, sound="metal",
        tags=["lobby", "office", "dressing_room", "sign"], verbs=["inspect"],
        inspect="Schoolhouse clock, ten past ten, like every clock in every catalogue."),
}


def _pivot(spec: dict, geo: dict) -> list:
    """Bottom centre by default; a wall-hung prop pivots on its mount: the
    clock at the centre of its back, the booth at the bottom centre of its back."""
    sx, sy, sz = geo["size_vox"]
    if spec.get("pivot") == "wall":
        return [sx / 2, 0, sz]
    if spec.get("build") is wall_clock:
        return [sx / 2, sy / 2, sz]
    return geo["pivot"]


def generate(ids: list[str], preview: bool) -> None:
    os.makedirs(VOX_DIR, exist_ok=True)
    os.makedirs(DATA_DIR, exist_ok=True)
    if preview:
        os.makedirs(PREVIEW_DIR, exist_ok=True)
    for pid in ids:
        spec = LIBRARY[pid]
        scene = spec["build"]()
        geo = scene.write(os.path.join(VOX_DIR, f"{pid}.vox"))
        rec = {
            "id": pid,
            "name": spec["name"],
            "vox": f"art/props/{pid}.vox",
            "voxel_m": scene.voxel_m,
            "size_m": geo["size_m"],
            "pivot": _pivot(spec, geo),
            "mass_kg": spec["mass_kg"],
            "tags": spec["tags"],
            "verbs": spec["verbs"],
            "inspect": spec["inspect"],
            "sound": spec["sound"],
            "shape": spec.get("shape", []),
            "mesh": "merged",
            "collision_cell": 8,
            "tri_cap": 60000,
            "wear": {"worn": "tint:8a7a60:0.25", "repaired": "tint:8a7a60:0.1", "renovated": "none"},
            "source": "tools/propgen/library.py",
        }
        manifest(os.path.join(DATA_DIR, f"{pid}.json"), rec)
        print(f"{pid}: {geo['size_vox']} voxels, {geo['voxels']} surface of {geo['solid']} solid, {geo['size_m']} m")
        if preview:
            scene.preview(os.path.join(PREVIEW_DIR, f"{pid}.png"))


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    generate(args or list(LIBRARY.keys()), preview="--preview" in sys.argv)
