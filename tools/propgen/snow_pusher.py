"""The snow pusher: a wide white blade on a yellow shaft with a black
D-grip (Sean's photo: "the original snow pusher", about 3 ft wide and 1 ft
tall), modelled in its pushing pose, the blade's bottom edge on the ground
and the shaft rising back to the hands.

    python3 tools/propgen/snow_pusher.py --preview

Writes art/props/snow_pusher.vox and data/props/snow_pusher.json at 1 cm.
"""
from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from propgen import PAL, Scene, manifest  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
BLADE_W = 0.91  # 3 ft
BLADE_H = 0.30  # 1 ft
BLADE_R = 0.42  # the curve's radius, the face concave toward the pusher
SHAFT_L = 1.45
SHAFT_R = 0.016
LEAN = np.deg2rad(52.0)  # the shaft from vertical, pushing


def build() -> Scene:
    v = 0.01
    s = Scene((BLADE_W + 0.02, 1.30, 1.40), v)
    cx = BLADE_W / 2 + 0.01
    # the blade: a slice of a cylinder shell, axis across, the ground edge
    # at the front (-z here is the front: it faces away from the pusher)
    ax = (cx, BLADE_R, 0.12 + BLADE_R)
    shell = s.cylinder(ax, BLADE_R, BLADE_W, axis="x") - s.cylinder(ax, BLADE_R - 0.02, BLADE_W + 0.04, axis="x")
    keep = s.box((0.0, 0.0, 0.0), (BLADE_W + 0.02, BLADE_H, 0.12 + BLADE_R))
    s.add(shell & keep, PAL.white)
    # the wear strip along the ground edge, a shade greyer
    s.paint(s.box((0.0, 0.0, 0.0), (BLADE_W + 0.02, 0.025, 0.4)), PAL.chrome)
    # the bracket: a black wedge behind the blade's middle, the socket in it
    foot = (cx, 0.10, 0.17)
    s.add(s.rbox((cx, 0.11, 0.19), (0.28, 0.16, 0.10), r=0.01), PAL.black)
    # the shaft: spheres strung along the lean, yellow, to the grip
    top = (cx, foot[1] + SHAFT_L * np.cos(LEAN), foot[2] + SHAFT_L * np.sin(LEAN))
    n = int(SHAFT_L / (v * 0.7))
    for k in range(n + 1):
        t = k / n
        p = (cx, foot[1] + (top[1] - foot[1]) * t, foot[2] + (top[2] - foot[2]) * t)
        s.add(s.sphere(p, SHAFT_R), PAL.amber)
    # the label band, white with a dark edge, a third of the way up
    for k in range(int(0.14 / (v * 0.7))):
        t = 0.33 + k * v * 0.7 / SHAFT_L
        p = (cx, foot[1] + (top[1] - foot[1]) * t, foot[2] + (top[2] - foot[2]) * t)
        s.paint(s.sphere(p, SHAFT_R + 0.004), PAL.white)
    # the D-grip: a black loop at the top, in the plane of the lean
    grip_c = (cx, top[1] + 0.05 * np.cos(LEAN), top[2] + 0.05 * np.sin(LEAN))
    outer = s.rbox(grip_c, (0.13, 0.13, 0.13), r=0.04)
    inner = s.rbox(grip_c, (0.07, 0.13, 0.07), r=0.02)
    s.add(outer - inner, PAL.black)
    s.add(s.sphere(top, 0.025), PAL.black)
    return s


def main() -> None:
    preview = "--preview" in sys.argv
    s = build()
    vox = os.path.join(ROOT, "art", "props", "snow_pusher.vox")
    geo = s.write(vox)
    rec = {
        "id": "snow_pusher",
        "name": "Snow pusher",
        "vox": "art/props/snow_pusher.vox",
        "voxel_m": s.voxel_m,
        "size_m": geo["size_m"],
        "pivot": geo["pivot"],
        "mass_kg": 2.4,
        "tags": ["tool", "rink"],
        "verbs": ["inspect"],
        "inspect": "The snow pusher. Three feet of blade, and whoever is holding it.",
        "sound": "plastic",
        "shape": [],
        "mesh": "merged",
        "collision_cell": 8,
        "tri_cap": 60000,
        "wear": {"worn": "tint:8a7a60:0.25", "repaired": "tint:8a7a60:0.1", "renovated": "none"},
        "source": "tools/propgen/snow_pusher.py",
    }
    manifest(os.path.join(ROOT, "data", "props", "snow_pusher.json"), rec)
    print(f"snow_pusher: {geo['size_vox']} voxels, {geo['voxels']} surface, {geo['size_m']} m, pivot {geo['pivot']}")
    if preview:
        s.preview(os.path.join(ROOT, "art", "props", "preview", "snow_pusher.png"))


if __name__ == "__main__":
    main()
