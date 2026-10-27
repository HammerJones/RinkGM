"""The rink kit: dasher board sections and glass panels (Sean, 2026-10-22).

Boards are white panels 42 in tall with a yellow kick plate along the foot
and a blue dasher cap on top, on a steel frame behind; straight sections
in a few lengths and curved ones on the 8.5 m corner radius. Glass is
4 ft wide in 6 ft and 8 ft heights: the frame (two aluminium posts and
the bottom channel) is the voxel model, the pane is declared in the
manifest (`pane`) and drawn see-through by the engine (RinkKit).

    python3 tools/propgen/rink_kit.py --preview

Writes art/props/board_*.vox, art/props/glass_*.vox and their manifests
at 2 cm. Axes are the prop's: +Y up, the ice side faces -Z, pivot at the
bottom centre of the bounding box.
"""
from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from propgen import PAL, Field, Scene, manifest  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
VOX_M = 0.02
BOARD_H = 1.07  # 42 in to the top of the panel
BOARD_T = 0.10  # the panel with its frame
KICK_H = 0.20  # the yellow kick plate
CAP_H = 0.04  # the blue dasher cap
CAP_LIP = 0.02  # the cap over the panel's faces
CORNER_R = 8.5  # the ice's corner radius: the front face of a curved section
GLASS_W = 1.2192  # 4 ft
GLASS_T = 0.012  # tempered, half an inch
POST_W = 0.05
POST_D = 0.08
CHANNEL_H = 0.06

STRAIGHT = {"board_1m": 1.0, "board_2m": 2.0, "board_4m": 4.0}
CURVED = {"board_curve_eighth": np.pi / 16, "board_curve_quarter": np.pi / 8}  # of a corner
GLASS = {"glass_4x6": 1.8288, "glass_4x8": 2.4384}


def _finish(s: Scene, front: Field, depth: float, length: float) -> None:
    """Paints a board's panel: the kick plate low on the ice side, the cap
    on top, dark steel uprights on the back. `front` is the solid panel
    without the cap, `depth` the panel's z extent at its ends."""
    # the kick plate: the bottom of the ice face a shade proud
    kick = s.box((-9.0, 0.0, -9.0), (9.0, KICK_H, 9.0))
    face = front.grow(VOX_M * 0.6) - front.grow(-VOX_M * 0.6)
    s.add(face & kick & s.plane((0, 0, 1), depth * 0.5), PAL.kick_yellow)
    # the cap rail over the top, lipped over both faces
    cap = s.box((-9.0, BOARD_H, -9.0), (9.0, BOARD_H + CAP_H, 9.0))
    s.add(front.grow(CAP_LIP) & cap, PAL.dasher_blue)
    # the frame behind: uprights every metre and a bottom rail, dark steel
    back = front.grow(VOX_M * 0.6) - front.grow(-VOX_M * 0.6)
    back = back & s.plane((0, 0, -1), -depth * 0.5) & s.box((-9.0, 0.0, -9.0), (9.0, BOARD_H - 0.02, 9.0))
    n = max(2, int(round(length)) + 1)
    for k in range(n):
        x = -length / 2 + length * k / (n - 1)
        x = np.clip(x, -length / 2 + 0.05, length / 2 - 0.05)
        s.paint(back & s.box((x - 0.04, 0.0, -9.0), (x + 0.04, 9.0, 9.0)), PAL.grey_dark)
    s.paint(back & s.box((-9.0, 0.0, -9.0), (9.0, 0.08, 9.0)), PAL.grey_dark)


def straight(length: float) -> Scene:
    s = Scene((length, BOARD_H + CAP_H, BOARD_T + 2 * CAP_LIP), VOX_M,
              origin=(-length / 2, 0.0, -CAP_LIP))
    panel = s.box((-length / 2, 0.0, 0.0), (length / 2, BOARD_H, BOARD_T))
    s.add(panel, PAL.board_white, dither=PAL.board_white2, amount=0.3)
    _finish(s, panel, BOARD_T, length)
    return s


def curved(angle: float) -> Scene:
    """An arc of the corner, its ice face at CORNER_R, the chord along x,
    the face's ends at z = 0 and its middle bowed to +z (concave to the
    ice at -z)."""
    half = angle / 2
    length = 2 * (CORNER_R + BOARD_T) * np.sin(half)
    sag = CORNER_R * (1 - np.cos(half))
    depth = sag + BOARD_T
    s = Scene((length + 2 * VOX_M, BOARD_H + CAP_H, depth + 2 * CAP_LIP), VOX_M,
              origin=(-length / 2 - VOX_M, 0.0, -CAP_LIP))
    zc = -CORNER_R * np.cos(half)
    rad = np.hypot(s.X, s.Z - zc)
    shell = Field(np.maximum(CORNER_R - rad, rad - (CORNER_R + BOARD_T)))
    wedge = Field(np.abs(np.arctan2(s.X, s.Z - zc)) - half)
    tall = s.box((-9.0, 0.0, -9.0), (9.0, BOARD_H, 9.0))
    panel = shell & wedge & tall
    s.add(panel, PAL.board_white, dither=PAL.board_white2, amount=0.3)
    # the kick plate and cap follow the arc; the back frame is painted by radius
    kick = s.box((-9.0, 0.0, -9.0), (9.0, KICK_H, 9.0))
    s.add(Field(np.maximum(CORNER_R - VOX_M * 0.6 - rad, rad - CORNER_R - VOX_M * 0.6)) & wedge & kick,
          PAL.kick_yellow)
    cap = s.box((-9.0, BOARD_H, -9.0), (9.0, BOARD_H + CAP_H, 9.0))
    s.add(shell.grow(CAP_LIP) & wedge & cap, PAL.dasher_blue)
    back = Field(np.abs(rad - (CORNER_R + BOARD_T)) - VOX_M * 0.6) & wedge & tall
    n = max(2, int(round(length)) + 1)
    for k in range(n):
        a = -half + angle * k / (n - 1)
        a = np.clip(a, -half + 0.05 / CORNER_R, half - 0.05 / CORNER_R)
        ang = Field(np.abs(np.arctan2(s.X, s.Z - zc) - a) * CORNER_R - 0.04)
        s.paint(back & ang, PAL.grey_dark)
    s.paint(back & s.box((-9.0, 0.0, -9.0), (9.0, 0.08, 9.0)), PAL.grey_dark)
    return s


def glass(height: float) -> Scene:
    """The frame of one panel: two posts and the bottom channel; the pane
    goes between the posts, declared in the manifest."""
    w = GLASS_W
    s = Scene((w, height, POST_D), VOX_M, origin=(-w / 2, 0.0, -POST_D / 2))
    for sx in (-1.0, 1.0):
        x = sx * (w / 2 - POST_W / 2)
        s.add(s.rbox((x, height / 2, 0.0), (POST_W, height, POST_D), r=0.006), PAL.alu, dither=PAL.alu2, amount=0.3)
    s.add(s.rbox((0.0, CHANNEL_H / 2, 0.0), (w, CHANNEL_H, POST_D), r=0.006), PAL.alu, dither=PAL.alu2, amount=0.3)
    # the clip strips that hold the pane's edges, a shade darker, up each post
    for sx in (-1.0, 1.0):
        x = sx * (w / 2 - POST_W)
        s.paint(s.box((x - 0.005, CHANNEL_H, -GLASS_T), (x + 0.005, height, GLASS_T)), PAL.grey)
    return s


def _record(pid: str, name: str, s: Scene, geo: dict, extra: dict) -> dict:
    rec = {
        "id": pid,
        "name": name,
        "vox": f"art/props/{pid}.vox",
        "voxel_m": s.voxel_m,
        "size_m": geo["size_m"],
        "pivot": geo["pivot"],
        "tags": ["rink", "kit"],
        "verbs": ["inspect"],
        "sound": "wood",
        "shape": [],
        "mesh": "merged",
        "collision_cell": 8,
        "tri_cap": 60000,
        "wear": {"worn": "tint:8a7a60:0.12", "repaired": "tint:8a7a60:0.05", "renovated": "none"},
        "source": "tools/propgen/rink_kit.py",
    }
    rec.update(extra)
    return rec


def _preview(s: Scene, path: str, pane: dict | None) -> None:
    if pane:
        # draw the pane in the preview only, a pale blue sheet
        w, h, t = pane["size_m"]
        s.add(s.rbox((0.0, CHANNEL_H + h / 2, 0.0), (w - 2 * POST_W, h, VOX_M)), PAL.blue_glass2)
    s.preview(path)


def main() -> None:
    preview = "--preview" in sys.argv
    vox_dir = os.path.join(ROOT, "art", "props")
    data_dir = os.path.join(ROOT, "data", "props")
    prev_dir = os.path.join(vox_dir, "preview")
    jobs = []
    for pid, length in STRAIGHT.items():
        jobs.append((pid, f"Dasher board, {length:g} m", straight(length), 18.0 * length,
                     {"board": {"length_m": length, "height_m": BOARD_H + CAP_H, "thickness_m": BOARD_T}}))
    for pid, angle in CURVED.items():
        s = curved(angle)
        chord = 2 * (CORNER_R + BOARD_T) * np.sin(angle / 2)
        jobs.append((pid, f"Dasher board, corner {np.degrees(angle):g} deg", s, 18.0 * chord,
                     {"board": {"length_m": round(float(chord), 4), "height_m": BOARD_H + CAP_H,
                                "thickness_m": BOARD_T, "radius_m": CORNER_R, "angle_deg": round(float(np.degrees(angle)), 3)}}))
    for pid, height in GLASS.items():
        feet = round(height / 0.3048)
        jobs.append((pid, f"Glass, 4 x {feet} ft", glass(height), 9.0 * height,
                     {"pane": {"size_m": [round(GLASS_W - 2 * POST_W, 4), round(height - CHANNEL_H, 4), GLASS_T],
                               "at": [0.0, CHANNEL_H, 0.0]}}))
    for pid, name, s, mass, extra in jobs:
        geo = s.write(os.path.join(vox_dir, f"{pid}.vox"))
        rec = _record(pid, name, s, geo, {"mass_kg": round(mass, 1), "inspect": name + "."} | extra)
        manifest(os.path.join(data_dir, f"{pid}.json"), rec)
        print(f"{pid}: {geo['size_vox']} voxels, {geo['voxels']} surface, {geo['size_m']} m")
        if preview:
            _preview(s, os.path.join(prev_dir, f"{pid}.png"), extra.get("pane"))


if __name__ == "__main__":
    main()
