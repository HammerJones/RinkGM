"""The Zambelli 552 from the bought Zamboni GLB: the model voxelised with
tools/propgen/glb2vox.py and split into the props framework/demo/zambelli.gd
drives (the body, the conditioner, a wheel), rebranded. The augers stay
the generated ones from zambelli.py (the model's are inside its shell).

    python3 tools/propgen/zambelli_glb.py path/to/Zamboni.glb --preview

The GLB is not in the repository (a licensed purchase); the .vox files it
makes are. The model's materials are flat colour swatches (no lettering,
a navy blue that the renderer's lighting lifted), so the blue is mapped
to the Zambelli blue and ZAMBELLI is stamped on the tank's sides.

The split: wheels are found from where the model touches the ice (two
runs of contact along the length, two tyres across each) and cut out of
the body as cylinders; the conditioner is everything behind the rear
wheels below the deck, voxelised again at 1 cm. The script prints the
layout constants the node needs (axles, wheel radius, blade line).
"""
from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import glb2vox  # noqa: E402
import propgen  # noqa: E402
import zambelli  # noqa: E402
from propgen import Scene  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
VOX_DIR = os.path.join(ROOT, "art", "props")
DATA_DIR = os.path.join(ROOT, "data", "props")
PREVIEW_DIR = os.path.join(VOX_DIR, "preview")

LENGTH_M = 4.3          # nose to the towel; the model's units are arbitrary
NAVY = np.array([7.0, 22.0, 49.0])
BLUE = np.array([38.0, 84.0, 168.0])
WHITE = np.array([236.0, 236.0, 232.0])
COND_DECK_Y = 0.42      # the conditioner is everything behind the rear wheels under this
AUGER_FROM_COND = 0.20  # the horizontal auger's axis behind the conditioner's front wall
BLADE_FROM_COND = 0.45  # the blade's edge behind it
AUGER_R = 0.15


def recolour(mean: np.ndarray, solid: np.ndarray) -> None:
    """The navy swatch to the Zambelli blue (the model's blue reads as
    near-black without its renderer's lighting); greys stay."""
    c = mean[solid]
    d = np.linalg.norm(c - NAVY, axis=1)
    blueish = (d < 40.0) | ((c[:, 2] > c[:, 0] + 15) & (c[:, 2] > c[:, 1] + 10) & (c.sum(1) < 200))
    c[blueish] = BLUE
    mean[solid] = c


def to_scene(mean: np.ndarray, solid: np.ndarray, voxel_m: float, extra: list[tuple[int, int, int]]):
    """A Scene of the grid with the quantised palette installed in propgen
    (plus `extra` colours appended, for labels). Returns (scene, palette)."""
    pal, idx = glb2vox.quantise(mean, solid, 255 - len(extra))
    pal = np.concatenate([pal, np.array(extra, dtype=pal.dtype)]) if extra else pal
    n = solid.shape
    scene = Scene((n[0] * voxel_m, n[1] * voxel_m, n[2] * voxel_m), voxel_m)
    scene.n = tuple(int(x) for x in n)
    scene.colour = np.zeros(n, dtype=np.uint8)
    scene.colour[solid] = idx.astype(np.uint8)
    propgen.PALETTE.clear()
    propgen.PALETTE.update({f"c{i}": tuple(int(v) for v in c) for i, c in enumerate(pal)})
    propgen.NAMES[:] = list(propgen.PALETTE.keys())
    propgen.EMISSIVE.clear()
    return scene, pal


def manifest(pid: str, name: str, geo: dict, voxel_m: float, mass: float, inspect: str, sound: str) -> None:
    rec = {
        "id": pid,
        "name": name,
        "vox": f"art/props/{pid}.vox",
        "voxel_m": round(voxel_m, 5),
        "size_m": geo["size_m"],
        "pivot": geo["pivot"],
        "mass_kg": mass,
        "tags": ["machine", "resurfacer"],
        "verbs": ["inspect"],
        "inspect": inspect,
        "sound": sound,
        "source": "tools/propgen/zambelli_glb.py",
        "mesh": "merged",
        "collision_cell": 8,
        "tri_cap": 200000,
        "wear": {"renovated": "none", "repaired": "tint:8a7a60:0.08", "worn": "tint:8a7a60:0.2"},
    }
    with open(os.path.join(DATA_DIR, f"{pid}.json"), "w") as f:
        json.dump(rec, f, indent=2, sort_keys=True)
        f.write("\n")


def ground_runs(solid: np.ndarray, voxel_m: float) -> list[tuple[float, float]]:
    """Where the model touches the ice along its length: (z0, z1) metres."""
    g = solid[:, :2, :].any(1).any(0)
    runs, start = [], None
    for z, on in enumerate(g):
        if on and start is None:
            start = z
        if not on and start is not None:
            runs.append((start * voxel_m, z * voxel_m))
            start = None
    if start is not None:
        runs.append((start * voxel_m, len(g) * voxel_m))
    return runs


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("glb")
    ap.add_argument("--preview", action="store_true")
    args = ap.parse_args()
    parts = glb2vox.load(args.glb)
    allv = np.concatenate([p["verts"] for p in parts])
    raw_len = float((allv.max(0) - allv.min(0)).max())
    scale = LENGTH_M / raw_len
    # the model's length runs along its X with the nose at -X; the props face -Z
    for p in parts:
        p["verts"] = glb2vox.orient(p["verts"], "y", "-x", None) * scale
    allv = np.concatenate([p["verts"] for p in parts])
    lo = allv.min(0)
    for p in parts:
        p["verts"] = p["verts"] - lo  # the ice at y = 0, the nose at z = 0, the left side at x = 0
    ext = allv.max(0) - lo
    print(f"machine {np.round(ext, 3)} m (x width, y height, z length)")

    # -- the whole machine, 256 voxels along its length
    mean, solid, vm = glb2vox.voxelise(parts, 256)
    recolour(mean, solid)
    runs = ground_runs(solid, vm)
    print("ice contact along z:", [(round(a, 2), round(b, 2)) for a, b in runs])
    axles = [((a + b) / 2) for a, b in runs[:2]]
    cond_z0 = runs[2][0] if len(runs) > 2 else axles[1] + 0.4
    # the wheels: in each axle's run, the tyre columns across x split in two
    g = solid[:, :2, :]
    xs_on = np.nonzero(g[:, :, int(runs[0][0] / vm):int(runs[0][1] / vm)].any((1, 2)))[0] * vm
    split = (xs_on.min() + xs_on.max()) / 2
    left = xs_on[xs_on < split]
    right = xs_on[xs_on > split]
    wheel_x = [((left.min() + left.max()) / 2 + vm / 2), ((right.min() + right.max()) / 2 + vm / 2)]
    wheel_w = max(left.max() - left.min(), right.max() - right.min()) + vm
    # the tyre's radius from its contact patch: the chord two voxels up
    chord = runs[0][1] - runs[0][0]
    wheel_r = (chord / 2) ** 2 / (2 * 2 * vm)
    print(f"axles z {axles[0]:.3f} {axles[1]:.3f}, wheel x {wheel_x[0]:.3f} {wheel_x[1]:.3f}, "
          f"width {wheel_w:.3f}, radius {wheel_r:.3f}, conditioner from z {cond_z0:.3f}")

    # -- the body: the machine without its wheels and conditioner
    X = (np.arange(solid.shape[0]) + 0.5) * vm
    Y = (np.arange(solid.shape[1]) + 0.5) * vm
    Z = (np.arange(solid.shape[2]) + 0.5) * vm
    XX, YY, ZZ = np.meshgrid(X, Y, Z, indexing="ij")
    body = solid.copy()
    for az in axles:
        for wx in wheel_x:
            wheel = (np.hypot(YY - wheel_r, ZZ - az) <= wheel_r + 0.03) & (np.abs(XX - wx) <= wheel_w / 2 + 0.03)
            body &= ~wheel
    cond_box = (ZZ >= cond_z0) & (YY <= COND_DECK_Y)
    body &= ~cond_box
    scene, pal = to_scene(mean, body, vm, [tuple(int(v) for v in WHITE)])
    white_i = len(pal)  # palette index of the appended white (indices start at 1)
    # ZAMBELLI along the tank's sides, white on the blue
    # the tank's sides are a little inside the bounding box (mirrors, steps),
    # so the stamp reaches 8 cm in and only recolours the skin it meets
    tank_z = (cond_z0 - 1.2) * 0.5  # about the tank's middle
    skin = np.nonzero(body[:, int(0.9 / vm), int(tank_z / vm)])[0]
    for face, x in (("left", (skin.min() + 0.5) * vm), ("right", (skin.max() + 0.5) * vm)):
        scene.label("ZAMBELLI", (x, 0.9, tank_z + 0.15), face=face, size=0.04, ink=white_i, spacing=1, depth=0.05)
    os.makedirs(VOX_DIR, exist_ok=True)
    os.makedirs(DATA_DIR, exist_ok=True)
    geo = scene.write(os.path.join(VOX_DIR, "zambelli_body.vox"), hollow=False)
    manifest("zambelli_body", "Zambelli 552", geo, vm, 3200.0,
             "The rink's resurfacer. Her name is Doris and she has opinions about the plant room floor.", "metal")
    body_lo = np.array(scene.bounds()[0]) * vm
    print(f"zambelli_body: {geo['size_vox']} at {vm * 1000:.1f} mm, bbox from {np.round(body_lo, 3)}, pivot z {geo['pivot'][2] * vm + body_lo[2]:.3f}")
    if args.preview:
        os.makedirs(PREVIEW_DIR, exist_ok=True)
        zambelli.views(scene, os.path.join(PREVIEW_DIR, "zambelli_body.png"))

    # -- one wheel (the front right) at 1 cm, the cylinder only
    vm_w = 0.01
    clip = (wheel_x[1] - wheel_w / 2 - 0.02, 0.0, axles[0] - wheel_r - 0.02), (wheel_x[1] + wheel_w / 2 + 0.02, 2 * wheel_r + 0.02, axles[0] + wheel_r + 0.02)
    wparts = clip_parts(parts, clip)
    wmean, wsolid, _ = glb2vox.voxelise_at(wparts, vm_w, clip)
    recolour(wmean, wsolid)
    Xw = (np.arange(wsolid.shape[0]) + 0.5) * vm_w + clip[0][0]
    Yw = (np.arange(wsolid.shape[1]) + 0.5) * vm_w + clip[0][1]
    Zw = (np.arange(wsolid.shape[2]) + 0.5) * vm_w + clip[0][2]
    XW, YW, ZW = np.meshgrid(Xw, Yw, Zw, indexing="ij")
    wsolid &= (np.hypot(YW - wheel_r, ZW - axles[0]) <= wheel_r + 0.03) & (np.abs(XW - wheel_x[1]) <= wheel_w / 2 + 0.03)
    wscene, _ = to_scene(wmean, wsolid, vm_w, [])
    geo = wscene.write(os.path.join(VOX_DIR, "zambelli_wheel.vox"), hollow=False)
    manifest("zambelli_wheel", "Resurfacer wheel", geo, vm_w, 45.0, "A studded tyre on a steel rim.", "rubber")
    print(f"zambelli_wheel: {geo['size_vox']} at 1 cm")
    if args.preview:
        zambelli.views(wscene, os.path.join(PREVIEW_DIR, "zambelli_wheel.png"))

    # -- the conditioner at 1 cm, its top opened over the auger
    vm_c = 0.01
    clip = (0.0, 0.0, cond_z0), (ext[0], COND_DECK_Y, ext[2] + 0.01)
    cparts = clip_parts(parts, clip)
    cmean, csolid, _ = glb2vox.voxelise_at(cparts, vm_c, clip)
    recolour(cmean, csolid)
    Zc = (np.arange(csolid.shape[2]) + 0.5) * vm_c + cond_z0
    Yc = (np.arange(csolid.shape[1]) + 0.5) * vm_c
    Xc = (np.arange(csolid.shape[0]) + 0.5) * vm_c
    XC, YC, ZC = np.meshgrid(Xc, Yc, Zc, indexing="ij")
    auger_z = cond_z0 + AUGER_FROM_COND
    opening = (np.abs(ZC - auger_z) <= AUGER_R + 0.04) & (YC >= 0.2) & (XC > 0.12) & (XC < ext[0] - 0.12)
    csolid &= ~opening
    cscene, _ = to_scene(cmean, csolid, vm_c, [])
    geo = cscene.write(os.path.join(VOX_DIR, "zambelli_conditioner.vox"), hollow=False)
    manifest("zambelli_conditioner", "Conditioner", geo, vm_c, 400.0,
             "The conditioner: the auger, the blade, the wash pipe and squeegee, the flood pipe and the towel.", "metal")
    c_lo = np.array(cscene.bounds()[0]) * vm_c
    c_hi = (np.array(cscene.bounds()[1]) + 1) * vm_c
    print(f"zambelli_conditioner: {geo['size_vox']} at 1 cm, z {cond_z0 + c_lo[2]:.3f}..{cond_z0 + c_hi[2]:.3f}, height {c_hi[1]:.3f}")
    if args.preview:
        zambelli.views(cscene, os.path.join(PREVIEW_DIR, "zambelli_conditioner.png"))

    print("\nzambelli.gd constants:")
    print(f"  BLADE_Z {cond_z0 + BLADE_FROM_COND:.3f}  COND_Z0 {cond_z0:.3f}  AUGER_Z {auger_z:.3f}  COND_H {c_hi[1]:.2f}")
    print(f"  COND_PIVOT_Z {cond_z0 + (c_lo[2] + c_hi[2]) / 2:.3f}  COND_X0 {(c_lo[0] + c_hi[0]) / 2 - ext[0] / 2:.3f}  COND_W {ext[0]:.3f}")
    print(f"  BODY_PIVOT_Z {body_lo[2] + geo_center_z(scene, vm):.3f}  BODY_Y0 {body_lo[1]:.3f}  BODY_X0 {body_lo[0] + geo_center_x(scene, vm) - ext[0] / 2:.3f}")
    print(f"  FRONT_AXLE {axles[0]:.3f}  REAR_AXLE {axles[1]:.3f}  WHEEL_R {wheel_r:.3f}  WHEEL_X {(wheel_x[1] - wheel_x[0]) / 2:.3f}")


def geo_center_z(scene: Scene, vm: float) -> float:
    b = scene.bounds()
    return (b[1][2] - b[0][2] + 1) / 2 * vm


def geo_center_x(scene: Scene, vm: float) -> float:
    b = scene.bounds()
    return (b[1][0] - b[0][0] + 1) / 2 * vm


def clip_parts(parts: list[dict], clip) -> list[dict]:
    """The parts with any vertex inside the clip box (the sampler drops
    the rest of their samples)."""
    lo, hi = np.array(clip[0]), np.array(clip[1])
    out = []
    for p in parts:
        v = p["verts"]
        if ((v >= lo - 0.05) & (v <= hi + 0.05)).all(1).any():
            out.append(p)
    return out


if __name__ == "__main__":
    main()
