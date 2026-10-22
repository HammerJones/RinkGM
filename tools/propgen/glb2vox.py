"""A textured glTF/GLB model to a hero prop: its surface voxelised at a
chosen resolution, each voxel coloured from the base colour texture, the
colours quantised to a palette of up to 255, written as .vox with a
manifest in data/props/. The way to bring a bought model into the look of
the voxel props: the shape and the paint come from the model, the voxels
do the rest.

    python3 tools/propgen/glb2vox.py model.glb prop_id --name "Hockey skate" \
        --size 200 --up y --forward -z --preview

`--size` is the voxel count along the model's longest axis (256 is the
.vox limit). `--up` and `--forward` name the model's axes (glTF is +Y up
with the front toward -Z, which is also the props' convention, so the
defaults usually hold); `--length z` turns the model so its longest
extent runs along Z instead. `--scale` is model units to metres (1 by
default; Sketchfab FBX conversions are often in centimetres or
millimetres, so check the printed size). Output: art/props/<id>.vox,
data/props/<id>.json, and with --preview art/props/preview/<id>.png.
Needs numpy, Pillow and trimesh.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import propgen  # noqa: E402
import zambelli  # noqa: E402
from propgen import Scene  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
VOX_DIR = os.path.join(ROOT, "art", "props")
DATA_DIR = os.path.join(ROOT, "data", "props")
PREVIEW_DIR = os.path.join(VOX_DIR, "preview")


def load(path: str) -> list[dict]:
    """The model's parts in world space: each a dict of vertices, faces,
    per-vertex UVs, the base colour image (RGB uint8) or None and a flat
    colour (RGB floats) for parts without one."""
    import trimesh

    scene = trimesh.load(path, force="scene")
    parts = []
    for name, geom in scene.geometry.items():
        if not isinstance(geom, trimesh.Trimesh):
            continue
        image, flat = None, np.array([160.0, 160.0, 160.0])
        mat = getattr(geom.visual, "material", None)
        if mat is not None:
            img = getattr(mat, "baseColorTexture", None) or getattr(mat, "image", None)
            if img is not None:
                image = np.asarray(img.convert("RGB"))
            fac = getattr(mat, "baseColorFactor", None) or getattr(mat, "diffuse", None)
            if fac is not None and image is None:
                flat = np.array(fac[:3], dtype=np.float64)
                if flat.max() <= 1.0:
                    flat = flat * 255.0
        uv = getattr(geom.visual, "uv", None)
        # every node that instances this geometry, with its world transform
        nodes = [nn for nn in scene.graph.nodes_geometry if scene.graph[nn][1] == name]
        for node in nodes:
            tf, _ = scene.graph[node]
            v = trimesh.transform_points(geom.vertices, tf)
            parts.append({
                "name": name,
                "verts": v,
                "faces": np.asarray(geom.faces),
                "uvs": np.asarray(uv) if uv is not None and len(uv) == len(v) else np.zeros((len(v), 2)),
                "image": image,
                "flat": flat,
            })
    return parts


def orient(verts: np.ndarray, up: str, forward: str, length: str | None) -> np.ndarray:
    """Turns the model so `up` is +Y and `forward` is -Z (the props face
    -Z); with `length` the longest extent is put along that axis."""
    axes = {"x": 0, "y": 1, "z": 2}

    def vec(s):
        sign = -1.0 if s.startswith("-") else 1.0
        v = np.zeros(3)
        v[axes[s.strip("+-")]] = sign
        return v

    u = vec(up)
    f = -vec(forward)  # the props' front is -Z: the model's forward maps to -Z
    r = np.cross(u, f)  # right-handed: x = y cross z
    basis = np.stack([r, u, f])  # rows: new x, y, z in old coordinates
    v = verts @ basis.T
    if length:
        ext = v.max(0) - v.min(0)
        longest = int(np.argmax(ext))
        want = axes[length]
        if longest != want and longest != 1 and want != 1:
            # swap the two horizontal axes (a quarter turn about Y)
            v = v[:, [2, 1, 0]] * np.array([1.0, 1.0, -1.0])
    return v


def voxelise(parts: list[dict], size: int):
    """Surface samples on every triangle, dense enough that no voxel on the
    surface is missed, each coloured from its part's texture at its UV;
    the voxel takes the mean colour of its samples. Returns the colour
    grid (n, n, n, 3) float, the solid mask, and the voxel size in metres."""
    allv = np.concatenate([p["verts"] for p in parts])
    lo = allv.min(0)
    hi = allv.max(0)
    voxel_m = float((hi - lo).max()) / (size - 1)
    return voxelise_at(parts, voxel_m, (lo, hi + voxel_m * 0.5))


def voxelise_at(parts: list[dict], voxel_m: float, clip):
    """As voxelise(), at a given voxel size over the box `clip` (lo, hi in
    metres): samples outside the box are dropped, so a region of a model
    can be taken on its own."""
    lo = np.asarray(clip[0], dtype=np.float64)
    hi = np.asarray(clip[1], dtype=np.float64)
    n = np.maximum(np.ceil((hi - lo) / voxel_m).astype(int), 1)
    acc = np.zeros((*n, 3), dtype=np.float64)
    cnt = np.zeros(n, dtype=np.int64)
    rng = np.random.default_rng(3)
    for part in parts:
        _sample(part, lo, hi, voxel_m, n, acc, cnt, rng)
    solid = cnt > 0
    mean = np.zeros_like(acc)
    mean[solid] = acc[solid] / cnt[solid][:, None]
    return mean, solid, voxel_m


def _sample(part: dict, lo, hi, voxel_m: float, n, acc, cnt, rng) -> None:
    verts, faces, uvs, image = part["verts"], part["faces"], part["uvs"], part["image"]
    if len(faces) == 0:
        return
    a = verts[faces[:, 0]]
    b = verts[faces[:, 1]]
    c = verts[faces[:, 2]]
    ua, ub, uc = uvs[faces[:, 0]], uvs[faces[:, 1]], uvs[faces[:, 2]]
    area = 0.5 * np.linalg.norm(np.cross(b - a, c - a), axis=1)
    # samples per triangle: about four per voxel of area, at least one
    k = np.maximum(np.ceil(area / (voxel_m * voxel_m) * 4.0), 1).astype(int)
    tri = np.repeat(np.arange(len(faces)), k)
    r1 = np.sqrt(rng.random(len(tri)))
    r2 = rng.random(len(tri))
    w0 = 1.0 - r1
    w1 = r1 * (1.0 - r2)
    w2 = r1 * r2
    p = a[tri] * w0[:, None] + b[tri] * w1[:, None] + c[tri] * w2[:, None]
    uv = ua[tri] * w0[:, None] + ub[tri] * w1[:, None] + uc[tri] * w2[:, None]
    if image is not None:
        h, w = image.shape[:2]
        px = np.clip((uv[:, 0] % 1.0) * (w - 1), 0, w - 1).astype(int)
        py = np.clip(((1.0 - uv[:, 1]) % 1.0) * (h - 1), 0, h - 1).astype(int)
        col = image[py, px].astype(np.float64)
    else:
        col = np.tile(part["flat"], (len(p), 1))
    inside = ((p >= lo) & (p < hi)).all(1)
    p, col = p[inside], col[inside]
    if len(p) == 0:
        return
    ijk = np.clip(((p - lo) / voxel_m).astype(int), 0, n - 1)
    flat = np.ravel_multi_index((ijk[:, 0], ijk[:, 1], ijk[:, 2]), tuple(n))
    for ch in range(3):
        acc[..., ch] += np.bincount(flat, weights=col[:, ch], minlength=cnt.size).reshape(n)
    cnt += np.bincount(flat, minlength=cnt.size).reshape(n)


def quantise(mean: np.ndarray, solid: np.ndarray, colours: int = 255):
    """The voxels' colours to a palette (median cut via Pillow)."""
    from PIL import Image

    rgb = mean[solid].astype(np.uint8)
    strip = Image.fromarray(rgb.reshape(1, -1, 3), "RGB")
    q = strip.quantize(colors=min(colours, 255), method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = np.array(q.getpalette()[: 3 * colours]).reshape(-1, 3)
    idx = np.asarray(q, dtype=np.int32).reshape(-1) + 1  # 0 is empty in .vox
    used = idx.max()
    return pal[:used], idx


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("glb")
    ap.add_argument("prop_id")
    ap.add_argument("--name", default=None)
    ap.add_argument("--size", type=int, default=200, help="voxels along the longest axis (max 256)")
    ap.add_argument("--up", default="y")
    ap.add_argument("--forward", default="-z")
    ap.add_argument("--length", default=None, help="put the longest extent along this axis (x or z)")
    ap.add_argument("--scale", type=float, default=1.0, help="model units to metres (0.001 for a model in mm)")
    ap.add_argument("--mass", type=float, default=1.0)
    ap.add_argument("--sound", default="plastic")
    ap.add_argument("--inspect", default="")
    ap.add_argument("--colours", type=int, default=255)
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--dump-textures", default=None, help="write each part's base colour texture here")
    args = ap.parse_args()
    if not 8 <= args.size <= 256:
        raise SystemExit("--size must be 8..256")
    parts = load(args.glb)
    for part in parts:
        part["verts"] = orient(part["verts"], args.up, args.forward, args.length) * args.scale
    if args.dump_textures:
        from PIL import Image

        os.makedirs(args.dump_textures, exist_ok=True)
        for i, part in enumerate(parts):
            if part["image"] is not None:
                Image.fromarray(part["image"]).save(os.path.join(args.dump_textures, f"{i:02d}_{part['name']}.png"))
    allv = np.concatenate([p["verts"] for p in parts])
    print(f"{len(parts)} parts, extent {np.round(allv.max(0) - allv.min(0), 3)} m after scale")
    mean, solid, voxel_m = voxelise(parts, args.size)
    pal, idx = quantise(mean, solid, args.colours)
    # a Scene of the grid, with the file's own palette swapped in for the
    # writer and the preview renderer (both read propgen.PALETTE)
    n = solid.shape
    scene = Scene((n[0] * voxel_m, n[1] * voxel_m, n[2] * voxel_m), voxel_m)
    scene.n = tuple(int(x) for x in n)
    scene.colour = np.zeros(n, dtype=np.uint8)
    scene.colour[solid] = idx.astype(np.uint8)
    propgen.PALETTE.clear()
    propgen.PALETTE.update({f"c{i}": tuple(int(v) for v in c) for i, c in enumerate(pal)})
    propgen.NAMES[:] = list(propgen.PALETTE.keys())
    propgen.EMISSIVE.clear()
    os.makedirs(VOX_DIR, exist_ok=True)
    os.makedirs(DATA_DIR, exist_ok=True)
    geo = scene.write(os.path.join(VOX_DIR, f"{args.prop_id}.vox"), hollow=False)
    rec = {
        "id": args.prop_id,
        "name": args.name or args.prop_id,
        "vox": f"art/props/{args.prop_id}.vox",
        "voxel_m": round(voxel_m, 5),
        "size_m": geo["size_m"],
        "pivot": geo["pivot"],
        "mass_kg": args.mass,
        "tags": ["imported"],
        "verbs": ["inspect"],
        "inspect": args.inspect,
        "sound": args.sound,
        "source": f"tools/propgen/glb2vox.py ({os.path.basename(args.glb)})",
        "mesh": "merged",
        "collision_cell": 8,
        "tri_cap": 200000,
        "wear": {"renovated": "none", "repaired": "tint:8a7a60:0.08", "worn": "tint:8a7a60:0.2"},
    }
    with open(os.path.join(DATA_DIR, f"{args.prop_id}.json"), "w") as f:
        json.dump(rec, f, indent=2, sort_keys=True)
        f.write("\n")
    print(
        f"{args.prop_id}: {geo['size_vox']} voxels at {voxel_m * 1000:.2f} mm, {geo['voxels']} on the surface, "
        f"{len(pal)} colours, {geo['size_m']} m"
    )
    if args.preview:
        os.makedirs(PREVIEW_DIR, exist_ok=True)
        zambelli.views(scene, os.path.join(PREVIEW_DIR, f"{args.prop_id}.png"))


if __name__ == "__main__":
    main()
