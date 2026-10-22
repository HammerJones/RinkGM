"""The Zambelli's console controls from the bought Zamboni GLB, as props.

The body prop is voxelised at 17 mm, which turns its controls into blobs.
This takes each control out of the model at 3 mm as its own prop and
clears its blob off art/props/zambelli_body.vox, leaving the deck and
the plates: the row of four levers (the operator's left to right, the
horizontal auger's, the conditioner's, the vertical auger's and the
bin's; the augers' alike and the other two alike, so two props), drive
select ahead on the left, the stalk with the ball at the row's right
end, the blade's handwheel lying on its column at the rear, and the
flood and wash valves either side of it, each a post with a handle.
Run after tools/propgen/zambelli_glb.py; it prints, for
framework/demo/zambelli.gd, where each control's foot sits in the
Zambelli's frame (the post or shaft the control turns on) and the
prop's offset from that foot.

    python3 tools/propgen/zambelli_lever.py path/to/Zamboni.glb --preview
"""
from __future__ import annotations

import argparse
import json
import os
import struct
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import glb2vox  # noqa: E402
import zambelli  # noqa: E402
from zambelli_glb import DATA_DIR, LENGTH_M, PREVIEW_DIR, VOX_DIR, manifest, to_scene  # noqa: E402

BLADE_Z = 3.519  # framework/demo/zambelli.gd: the blade's edge, the frame's origin, from the nose
VOXEL_M = 0.003
DECK_TOP = 1.66  # everything under this is the deck and the plates, which stay on the body
# the console, in the grid frame zambelli_glb.py lays the model out in (the ice
# at y = 0, the nose at z = 0, the left side at x = 0): each entry is a clip box
# and the props its components become, left to right; None keeps a component
# (it is cleared off the body but is another entry's twin)
CONTROLS = [
    ("the row of levers", ((0.74, 1.60, 3.55), (1.09, 1.95, 3.80)), [
        ("zambelli_lever", "Auger lever", "A lever on the resurfacer's console: a chromed shaft with a rubber knob."),
        ("zambelli_lever_cond", "Lift lever", "A sprung lever on the resurfacer's console: push it and it comes back."),
        None, None]),
    ("drive select", ((0.76, 1.60, 3.33), (0.87, 1.90, 3.51)), [
        ("zambelli_drive", "Drive select", "Forward, neutral, reverse: the resurfacer's gear lever.")]),
    ("the stalk", ((1.08, 1.60, 3.63), (1.20, 2.15, 3.77)), [
        ("zambelli_stalk", "Console stalk", "A tall stalk with a ball on top, beside the levers.")]),
    ("the handwheel", ((0.97, 1.60, 3.87), (1.26, 1.96, 4.17)), [
        ("zambelli_handwheel", "Blade handwheel", "The blade's handwheel: a turn is half a millimetre of blade.")]),
    ("the flood valve", ((0.78, 1.60, 3.87), (0.99, 2.04, 3.96)), [
        ("zambelli_valve_flood", "Flood valve", "The flood water valve: a quarter turn opens it.")]),
    ("the wash valve", ((1.25, 1.60, 3.87), (1.46, 2.04, 3.96)), [
        ("zambelli_valve_wash", "Wash valve", "The wash water valve: a quarter turn opens it.")]),
]


def load(glb: str) -> tuple[list[dict], np.ndarray]:
    """The model's parts in the grid frame. Returns the parts and the
    machine's extent."""
    parts = glb2vox.load(glb)
    allv = np.concatenate([p["verts"] for p in parts])
    scale = LENGTH_M / float((allv.max(0) - allv.min(0)).max())
    for p in parts:
        p["verts"] = glb2vox.orient(p["verts"], "y", "-x", None) * scale
    allv = np.concatenate([p["verts"] for p in parts])
    lo = allv.min(0)
    for p in parts:
        p["verts"] = p["verts"] - lo
    return parts, allv.max(0) - lo


def read_vox(path: str):
    d = open(path, "rb").read()
    assert d[:4] == b"VOX ", path
    pos = 8
    size = voxels = palette = None
    chunks = []
    while pos < len(d):
        cid = d[pos:pos + 4]
        n, _ = struct.unpack("<ii", d[pos + 4:pos + 12])
        body = d[pos + 12:pos + 12 + n]
        pos += 12 + n
        chunks.append((cid, body))
        if cid == b"SIZE":
            size = struct.unpack("<iii", body)
        elif cid == b"XYZI":
            cnt = struct.unpack("<i", body[:4])[0]
            voxels = np.frombuffer(body[4:4 + 4 * cnt], dtype=np.uint8).reshape(cnt, 4).copy()
        elif cid == b"RGBA":
            palette = np.frombuffer(body, dtype=np.uint8).reshape(256, 4).copy()
    return size, voxels, palette, chunks


def write_vox(path: str, chunks, voxels) -> None:
    out = bytearray(b"VOX " + struct.pack("<i", 150))
    body = bytearray()
    for cid, data in chunks:
        if cid == b"MAIN":
            continue
        if cid == b"XYZI":
            data = struct.pack("<i", len(voxels)) + voxels.astype(np.uint8).tobytes()
        body += cid + struct.pack("<ii", len(data), 0) + data
    out += b"MAIN" + struct.pack("<ii", 0, len(body)) + body
    open(path, "wb").write(out)


def clear_body(lo: np.ndarray, hi: np.ndarray) -> int:
    """Clears the body prop inside the grid-frame box (lo, hi), metres,
    above the deck: the control's blob. Returns how many voxels."""
    path = os.path.join(VOX_DIR, "zambelli_body.vox")
    size, vox, pal, chunks = read_vox(path)
    vm = json.load(open(os.path.join(DATA_DIR, "zambelli_body.json")))["voxel_m"]
    # file (x, y, z) is grid (size_x - 1 - x, z, y)
    gx = size[0] - 1 - vox[:, 0].astype(int)
    gy = vox[:, 2].astype(int)
    gz = vox[:, 1].astype(int)
    lo_i = np.floor(lo / vm).astype(int)
    hi_i = np.ceil(hi / vm).astype(int)
    lo_i[1] = max(lo_i[1], int(np.ceil(DECK_TOP / vm)))
    inside = (gx >= lo_i[0]) & (gx <= hi_i[0]) & (gy >= lo_i[1]) & (gy <= hi_i[1]) & (gz >= lo_i[2]) & (gz <= hi_i[2])
    write_vox(path, chunks, vox[~inside])
    return int(inside.sum())


def components(parts: list[dict], clip) -> list[tuple[np.ndarray, np.ndarray, np.ndarray]]:
    """The solid pieces standing on the deck inside the clip, at 3 mm, left
    to right: each a (mask, colour grid, grid-frame origin) over the clip."""
    from scipy import ndimage

    lo, hi = np.array(clip[0]), np.array(clip[1])
    near = [p for p in parts if ((p["verts"] >= lo - 0.05) & (p["verts"] <= hi + 0.05)).all(1).any()]
    mean, solid, _ = glb2vox.voxelise_at(near, VOXEL_M, clip)
    ys = (np.arange(solid.shape[1]) + 0.5) * VOXEL_M + lo[1]
    solid[:, ys < DECK_TOP, :] = False
    lab, n = ndimage.label(solid)
    found = []
    for i in range(1, n + 1):
        m = lab == i
        if m.sum() < 300:
            continue
        found.append((np.nonzero(m)[0].mean(), m))
    found.sort(key=lambda t: t[0])
    return [(m, mean, lo) for _, m in found]


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("glb")
    ap.add_argument("--preview", action="store_true")
    args = ap.parse_args()
    parts, ext = load(args.glb)
    placed = []
    for what, clip, props in CONTROLS:
        pieces = components(parts, clip)
        assert len(pieces) >= len(props), f"{what}: {len(pieces)} pieces found, {len(props)} wanted"
        for k, spec in enumerate(props):
            m, mean, lo = pieces[k]
            ii, jj, kk = np.nonzero(m)
            blo = np.array([ii.min(), jj.min(), kk.min()])
            bhi = np.array([ii.max(), jj.max(), kk.max()]) + 1
            m_lo = lo + blo * VOXEL_M
            m_hi = lo + bhi * VOXEL_M
            # the foot: where the control's post or shaft meets the deck, the
            # centre of its lowest 3 cm; the prop's pivot is its box's bottom centre
            base = jj < blo[1] + 10
            foot = np.array([lo[0] + (ii[base].mean() + 0.5) * VOXEL_M, m_lo[1], lo[2] + (kk[base].mean() + 0.5) * VOXEL_M])
            centre = np.array([(m_lo[0] + m_hi[0]) / 2, m_lo[1], (m_lo[2] + m_hi[2]) / 2])
            cleared = clear_body(m_lo - VOXEL_M, m_hi + VOXEL_M)
            pid = spec[0] if spec else "(twin)"
            placed.append((pid, foot, centre - foot))
            if spec is None:
                print(f"{what} #{k}: a twin, {cleared} body voxels cleared")
                continue
            pid, name, inspect = spec
            sub_solid = m[blo[0]:bhi[0], blo[1]:bhi[1], blo[2]:bhi[2]]
            sub_mean = mean[blo[0]:bhi[0], blo[1]:bhi[1], blo[2]:bhi[2]]
            scene, _ = to_scene(sub_mean, sub_solid, VOXEL_M, [])
            geo = scene.write(os.path.join(VOX_DIR, f"{pid}.vox"), hollow=False)
            manifest(pid, name, geo, VOXEL_M, 1.2, inspect, "metal")
            print(f"{pid}: {geo['size_vox']} at {VOXEL_M * 1000:.0f} mm, {int(sub_solid.sum())} voxels, "
                  f"grid box {np.round(m_lo, 3)}..{np.round(m_hi, 3)}, {cleared} body voxels cleared")
            if args.preview:
                os.makedirs(PREVIEW_DIR, exist_ok=True)
                zambelli.views(scene, os.path.join(PREVIEW_DIR, f"{pid}.png"))
    print("\nzambelli.gd: each control's foot in the Zambelli's frame, and the prop's offset from it")
    for pid, foot, off in placed:
        print(f"  {pid:22s} foot Vector3({foot[0] - ext[0] / 2:.3f}, {foot[1]:.3f}, {foot[2] - BLADE_Z:.3f})"
              f"  offset Vector3({off[0]:.3f}, 0.0, {off[2]:.3f})")


if __name__ == "__main__":
    main()
