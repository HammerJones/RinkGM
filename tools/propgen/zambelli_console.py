"""Clears the crude controls off the Zambelli body's operator console.

The bought model's console is a handful of black blobs (levers, a wheel on
a panel, a slab) at 17 mm voxels; framework/demo/zambelli_controls.gd
builds clean controls in their place. This strips the dark voxels in the
console region of art/props/zambelli_body.vox, in place, keeping the deck
and the seat. Run after tools/propgen/zambelli_glb.py.

    python3 tools/propgen/zambelli_console.py
"""
import os
import struct
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
VOX = os.path.join(HERE, "..", "..", "art", "props", "zambelli_body.vox")
DARK = 120  # r + g + b below this is a control blob, not the blue or the deck's grey
# (x across, y along from the nose, z up) in the file's voxels: the console
# with its levers and the wheel panel, and the flat slab beside it
REGIONS = [
    ((48, 92), (189, 247), (93, 255)),
    ((95, 127), (221, 241), (92, 99)),
]


def read(path):
    d = open(path, "rb").read()
    assert d[:4] == b"VOX ", path
    pos = 8
    size = None
    voxels = None
    palette = None
    chunks = []
    while pos < len(d):
        cid = d[pos:pos + 4]
        n, m = struct.unpack("<ii", d[pos + 4:pos + 12])
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


def write(path, chunks, voxels):
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


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else VOX
    size, vox, pal, chunks = read(path)
    lum = pal[vox[:, 3].astype(int) - 1][:, :3].astype(int).sum(1)
    keep = np.ones(len(vox), dtype=bool)
    for (x0, x1), (y0, y1), (z0, z1) in REGIONS:
        inside = (
            (vox[:, 0] >= x0) & (vox[:, 0] <= x1)
            & (vox[:, 1] >= y0) & (vox[:, 1] <= y1)
            & (vox[:, 2] >= z0) & (vox[:, 2] <= z1)
        )
        keep &= ~(inside & (lum < DARK))
    print(f"{path}: {len(vox)} voxels, {int((~keep).sum())} cleared off the console")
    write(path, chunks, vox[keep])


if __name__ == "__main__":
    main()
