"""One console lever from the bought Zamboni GLB, as its own prop.

The body prop is voxelised at 17 mm, which turns its levers into blobs.
This takes the leftmost lever of the row on the console (the operator's
left, the horizontal auger's) out of the model at 3 mm, writes it as
art/props/zambelli_lever.vox with its manifest, and clears the blob it
replaces off art/props/zambelli_body.vox, leaving the plate it stands on.
Run after tools/propgen/zambelli_glb.py; it prints where the lever's
foot sits in the Zambelli's frame for framework/demo/zambelli.gd.

    python3 tools/propgen/zambelli_lever.py path/to/Zamboni.glb --preview
"""
from __future__ import annotations

import argparse
import os
import struct
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import glb2vox  # noqa: E402
import zambelli  # noqa: E402
import zambelli_glb  # noqa: E402
from zambelli_glb import DATA_DIR, LENGTH_M, PREVIEW_DIR, VOX_DIR, manifest, to_scene  # noqa: E402

BODY_X0 = 0.035  # framework/demo/zambelli.gd: the body prop's pivot off the centreline
BLADE_Z = 3.519  # ... and the blade's edge, the frame's origin, from the nose
VOXEL_M = 0.003
# the lever row sits here on the deck; the lever's own meshes in the model
# are its shaft, its knob and the boss under it (the plate is another)
CLIP = ((0.74, 1.60, 3.55), (0.94, 1.95, 3.80))
LEVER_MESHES = {"mesh_id6", "mesh_id12", "mesh_id16"}
PLATE_TOP = 1.656  # the slotted plate's top: the lever starts above it
DARK = 120  # a body voxel with r + g + b under this is a control, not the deck


def load(glb: str) -> tuple[list[dict], np.ndarray]:
    """The model's parts in the Zambelli's grid frame, as zambelli_glb lays
    them out: the ice at y = 0, the nose at z = 0, the left side at x = 0.
    Returns the parts and the machine's extent."""
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


def clear_body(lo: np.ndarray, hi: np.ndarray) -> None:
    """Clears the dark voxels of the body prop inside the grid-frame box
    (lo, hi), metres, above the plate."""
    path = os.path.join(VOX_DIR, "zambelli_body.vox")
    size, vox, pal, chunks = read_vox(path)
    vm = zambelli_glb.json.load(open(os.path.join(DATA_DIR, "zambelli_body.json")))["voxel_m"]
    # file (x, y, z) is grid (size_x - 1 - x, z, y)
    gx = size[0] - 1 - vox[:, 0].astype(int)
    gy = vox[:, 2].astype(int)
    gz = vox[:, 1].astype(int)
    lo_i = np.floor(lo / vm).astype(int)
    hi_i = np.ceil(hi / vm).astype(int)
    inside = (gx >= lo_i[0]) & (gx <= hi_i[0]) & (gy >= lo_i[1]) & (gy <= hi_i[1]) & (gz >= lo_i[2]) & (gz <= hi_i[2])
    lum = pal[vox[:, 3].astype(int) - 1][:, :3].astype(int).sum(1)
    drop = inside & (lum < DARK)
    print(f"zambelli_body: {int(drop.sum())} voxels of the lever's blob cleared")
    write_vox(path, chunks, vox[~drop])


def main() -> None:
    from scipy import ndimage

    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("glb")
    ap.add_argument("--preview", action="store_true")
    args = ap.parse_args()
    parts, ext = load(args.glb)
    lever_parts = [p for p in parts if p["name"] in LEVER_MESHES]
    mean, solid, _ = glb2vox.voxelise_at(lever_parts, VOXEL_M, CLIP)
    lo = np.array(CLIP[0])
    ys = (np.arange(solid.shape[1]) + 0.5) * VOXEL_M + lo[1]
    solid[:, ys < PLATE_TOP, :] = False
    lab, n = ndimage.label(solid)
    best, best_x = None, 1e9
    for i in range(1, n + 1):
        m = lab == i
        if m.sum() < 500:
            continue
        x = np.nonzero(m)[0].mean()
        if x < best_x:
            best, best_x = m, x
    assert best is not None, "no lever found in the clip"
    ii, jj, kk = np.nonzero(best)
    blo = np.array([ii.min(), jj.min(), kk.min()])
    bhi = np.array([ii.max(), jj.max(), kk.max()]) + 1
    sub_solid = best[blo[0]:bhi[0], blo[1]:bhi[1], blo[2]:bhi[2]]
    sub_mean = mean[blo[0]:bhi[0], blo[1]:bhi[1], blo[2]:bhi[2]]
    scene, _ = to_scene(sub_mean, sub_solid, VOXEL_M, [])
    geo = scene.write(os.path.join(VOX_DIR, "zambelli_lever.vox"), hollow=False)
    manifest("zambelli_lever", "Console lever", geo, VOXEL_M, 1.2,
             "A lever on the resurfacer's console: a chromed shaft with a rubber knob.", "metal")
    m_lo = lo + blo * VOXEL_M
    m_hi = lo + bhi * VOXEL_M
    foot = np.array([(m_lo[0] + m_hi[0]) / 2, m_lo[1], (m_lo[2] + m_hi[2]) / 2])
    print(f"zambelli_lever: {geo['size_vox']} at {VOXEL_M * 1000:.0f} mm, {int(sub_solid.sum())} voxels, "
          f"grid box {np.round(m_lo, 3)}..{np.round(m_hi, 3)}")
    print("zambelli.gd constants (the lever's foot in the Zambelli's frame):")
    print(f"  LEVER_POS Vector3({foot[0] - ext[0] / 2:.3f}, {foot[1]:.3f}, {foot[2] - BLADE_Z:.3f})")
    clear_body(m_lo - VOXEL_M, m_hi + VOXEL_M)
    if args.preview:
        os.makedirs(PREVIEW_DIR, exist_ok=True)
        zambelli.views(scene, os.path.join(PREVIEW_DIR, "zambelli_lever.png"))


if __name__ == "__main__":
    main()
