"""Micro-voxel prop generator: distance fields in, MagicaVoxel files out.

The references for the look (a CRT television, an open record player, a
micro cassette, a long truck) are 100 to 256 voxels across with rounded
corners, two-tone dithered surfaces, cream label plates with black
lettering, small screws and grilles. Box builders cannot get there, so a
prop here is a small signed-distance scene voxelised at that resolution:

    s = Scene(size_m=(0.55, 0.16, 0.12), voxel_m=0.003)
    s.add(rbox(c=(0.275, 0.08, 0.06), size=(0.55, 0.16, 0.12), r=0.012), PAL.body, dither=PAL.body2)
    s.cut(rbox(...))                     # subtract
    s.add(cylinder(...), PAL.chrome)
    s.label("PLAY", at=(...), face="front", size=0.004, ink=PAL.ink, plate=PAL.cream)
    s.write("art/props/boombox.vox")     # surface voxels only, with the palette

Axes are Godot's: +Y up, the front faces -Z, +X right. Sizes and positions
are metres; `voxel_m` sets the grid. Run `python3 tools/propgen/library.py`
to regenerate every prop in the library and its manifest.

Only numpy and Pillow are needed (Pillow for the preview renderer).
"""
from __future__ import annotations

import json
import struct
from dataclasses import dataclass

import numpy as np

# ---------------------------------------------------------------- palette

# Lifted from the reference models so the library sits next to them: the
# cassette's dark teal body (two tones for the dither), the truck's greys,
# the cream plate, the record player's wood, red and amber accents.
PALETTE = {
    "body": (69, 88, 85),
    "body2": (64, 83, 79),
    "teal_dark": (45, 60, 58),
    "cream": (255, 237, 204),
    "cream2": (246, 228, 194),
    "ink": (38, 38, 38),
    "black": (24, 24, 26),
    "grey_dark": (53, 53, 53),
    "grey_dark2": (60, 60, 62),
    "grey": (107, 107, 107),
    "grey_mid": (126, 126, 126),
    "silver": (179, 179, 179),
    "silver2": (172, 172, 172),
    "chrome": (204, 204, 204),
    "chrome2": (196, 196, 196),
    "white": (231, 231, 231),
    "red": (255, 72, 59),
    "red_dark": (190, 48, 40),
    "amber": (255, 196, 64),
    "amber_dim": (190, 140, 40),
    "green_led": (120, 230, 120),
    "wood": (129, 90, 82),
    "wood2": (120, 82, 75),
    "wood_light": (180, 158, 130),
    "blue_glass": (25, 51, 66),
    "blue_glass2": (33, 62, 80),
    "screen": (61, 81, 179),
    "beige": (214, 200, 170),
    "beige2": (205, 191, 160),
    "rubber": (40, 42, 44),
    "steel_blue": (120, 125, 135),
    "steel_blue2": (112, 118, 128),
    "copper": (184, 115, 51),
    "binder_blue": (46, 92, 190),
    "binder_blue2": (40, 82, 172),
    "placard_blue": (28, 70, 160),
    "wood_dark": (96, 64, 56),
    "walnut": (92, 60, 46),
    "walnut2": (82, 52, 40),
    "walnut_dark": (62, 40, 30),
    "bakelite": (30, 29, 31),
    "bakelite2": (25, 24, 27),
    "bakelite_hi": (54, 53, 57),
}
NAMES = list(PALETTE.keys())  # palette index = position + 1


class _Pal:
    def __getattr__(self, name: str) -> int:
        return NAMES.index(name) + 1


PAL = _Pal()

# ---------------------------------------------------------------- fonts

# 5x7 bitmap font for labels (rows top to bottom, 1 = ink).
_FONT_ROWS = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
    "J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "N": ["10001", "10001", "11001", "10101", "10011", "10001", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
    "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    "3": ["11111", "00010", "00100", "00010", "00001", "10001", "01110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
    "-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
    ".": ["00000", "00000", "00000", "00000", "00000", "01100", "01100"],
    ":": ["00000", "01100", "01100", "00000", "01100", "01100", "00000"],
    "/": ["00001", "00010", "00100", "00100", "01000", "10000", "00000"],
    " ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
    "*": ["00000", "10101", "01110", "11111", "01110", "10101", "00000"],
}
FONT = {k: np.array([[c == "1" for c in row] for row in v]) for k, v in _FONT_ROWS.items()}

# ---------------------------------------------------------------- distance fields


@dataclass
class Field:
    """A signed distance field sampled on the scene grid (metres)."""

    d: np.ndarray

    def __or__(self, other: "Field") -> "Field":
        return Field(np.minimum(self.d, other.d))

    def __and__(self, other: "Field") -> "Field":
        return Field(np.maximum(self.d, other.d))

    def __sub__(self, other: "Field") -> "Field":
        return Field(np.maximum(self.d, -other.d))

    def grow(self, r: float) -> "Field":
        return Field(self.d - r)


class Scene:
    """A voxel grid in metres. Shapes are evaluated on the grid's cell
    centres; a cell is solid where the field is at or below zero."""

    def __init__(self, size_m, voxel_m: float, origin=(0.0, 0.0, 0.0)):
        self.voxel_m = voxel_m
        self.origin = np.array(origin, dtype=np.float32)
        self.n = tuple(int(np.ceil(s / voxel_m)) for s in size_m)
        xs = (np.arange(self.n[0]) + 0.5) * voxel_m + self.origin[0]
        ys = (np.arange(self.n[1]) + 0.5) * voxel_m + self.origin[1]
        zs = (np.arange(self.n[2]) + 0.5) * voxel_m + self.origin[2]
        self.X, self.Y, self.Z = np.meshgrid(xs, ys, zs, indexing="ij")
        self.colour = np.zeros(self.n, dtype=np.uint8)  # palette index, 0 = empty
        self.rng = np.random.default_rng(7)

    # -- shapes (all return a Field on this grid) --------------------------

    def rbox(self, c, size, r=0.0) -> Field:
        """Box centred at `c` with full `size`, corners rounded by `r`."""
        h = np.array(size, dtype=np.float32) / 2 - r
        q = np.stack([np.abs(self.X - c[0]) - h[0], np.abs(self.Y - c[1]) - h[1], np.abs(self.Z - c[2]) - h[2]])
        outside = np.linalg.norm(np.maximum(q, 0), axis=0)
        inside = np.minimum(np.max(q, axis=0), 0)
        return Field(outside + inside - r)

    def box(self, lo, hi, r=0.0) -> Field:
        lo = np.array(lo, dtype=np.float32)
        hi = np.array(hi, dtype=np.float32)
        return self.rbox((lo + hi) / 2, hi - lo, r)

    def cylinder(self, c, radius, height, axis="y", r=0.0) -> Field:
        """Cylinder centred at `c` along `axis` (full `height`), edge rounded by `r`."""
        a = {"x": (self.Y, self.Z, self.X), "y": (self.X, self.Z, self.Y), "z": (self.X, self.Y, self.Z)}[axis]
        ci = {"x": (c[1], c[2], c[0]), "y": (c[0], c[2], c[1]), "z": (c[0], c[1], c[2])}[axis]
        rad = np.hypot(a[0] - ci[0], a[1] - ci[1]) - (radius - r)
        hgt = np.abs(a[2] - ci[2]) - (height / 2 - r)
        q = np.stack([rad, hgt])
        return Field(np.linalg.norm(np.maximum(q, 0), axis=0) + np.minimum(np.max(q, axis=0), 0) - r)

    def sphere(self, c, radius) -> Field:
        return Field(np.sqrt((self.X - c[0]) ** 2 + (self.Y - c[1]) ** 2 + (self.Z - c[2]) ** 2) - radius)

    def plane(self, normal, offset) -> Field:
        """Half-space: solid where n . p <= offset."""
        n = np.array(normal, dtype=np.float32)
        n /= np.linalg.norm(n)
        return Field(self.X * n[0] + self.Y * n[1] + self.Z * n[2] - offset)

    # -- painting ------------------------------------------------------------

    def add(self, f: Field, colour: int, dither: int | None = None, amount: float = 0.5) -> None:
        """Fills the field with `colour`; `dither` mixes a second colour in
        at `amount` (the reference models' grainy surfaces)."""
        m = f.d <= 0.0
        if dither is None:
            self.colour[m] = colour
        else:
            noise = self.rng.random(self.n) < amount
            self.colour[m & ~noise] = colour
            self.colour[m & noise] = dither

    def paint(self, f: Field, colour: int, dither: int | None = None, amount: float = 0.5) -> None:
        """Recolours existing voxels inside the field (a label plate, a stripe)."""
        m = (f.d <= 0.0) & (self.colour > 0)
        if dither is None:
            self.colour[m] = colour
        else:
            noise = self.rng.random(self.n) < amount
            self.colour[m & ~noise] = colour
            self.colour[m & noise] = dither

    def cut(self, f: Field) -> None:
        self.colour[f.d <= 0.0] = 0

    def grille(self, lo, hi, pitch: float, hole: float, depth_axis="z", colour: int | None = None) -> None:
        """A grid of square holes `hole` wide every `pitch` over the box lo..hi,
        cut through along `depth_axis` (speaker cloth, vents)."""
        lo = np.array(lo, dtype=np.float32)
        hi = np.array(hi, dtype=np.float32)
        axes = [a for a in "xyz" if a != depth_axis]
        coords = {"x": self.X, "y": self.Y, "z": self.Z}
        inside = np.ones(self.n, dtype=bool)
        for a, i in zip("xyz", range(3)):
            inside &= (coords[a] >= lo[i]) & (coords[a] <= hi[i])
        for a in axes:
            i = "xyz".index(a)
            phase = np.mod(coords[a] - lo[i], pitch)
            inside &= phase < hole
        if colour is None:
            self.colour[inside] = 0
        else:
            self.colour[inside & (self.colour > 0)] = colour

    def slots(self, lo, hi, pitch: float, slot: float, along="x", colour: int | None = None) -> None:
        """Parallel slots (vents) across the box lo..hi, repeating along `along`."""
        lo = np.array(lo, dtype=np.float32)
        hi = np.array(hi, dtype=np.float32)
        coords = {"x": self.X, "y": self.Y, "z": self.Z}
        inside = np.ones(self.n, dtype=bool)
        for a, i in zip("xyz", range(3)):
            inside &= (coords[a] >= lo[i]) & (coords[a] <= hi[i])
        i = "xyz".index(along)
        inside &= np.mod(coords[along] - lo[i], pitch) < slot
        if colour is None:
            self.colour[inside] = 0
        else:
            self.colour[inside & (self.colour > 0)] = colour

    def screw(self, c, radius: float, face="front", depth: float | None = None) -> None:
        """A screw head: a dark disc with a lighter rim and a slot, set a
        voxel into the surface. `face` is where it sits (front/back/top/
        left/right)."""
        depth = depth or self.voxel_m
        axis, sign = {"front": ("z", -1), "back": ("z", 1), "top": ("y", 1), "bottom": ("y", -1), "left": ("x", -1), "right": ("x", 1)}[face]
        disc = self.cylinder(c, radius, depth * 2, axis=axis)
        self.paint(disc, PAL.grey_dark)
        rim = self.cylinder(c, radius, depth * 2, axis=axis) - self.cylinder(c, radius * 0.7, depth * 3, axis=axis)
        self.paint(rim, PAL.silver)
        slot_size = [radius * 1.4, radius * 1.4, radius * 1.4]
        slot_size["xyz".index(axis)] = depth * 2
        other = [a for a in "xyz" if a != axis][0]
        slot_size["xyz".index(other)] = radius * 0.35
        self.paint(self.rbox(c, slot_size), PAL.black)

    def label(self, text: str, at, face="front", size: float | None = None, ink: int = PAL.ink,
              plate: int | None = None, pad: float = 0.002, depth: float | None = None, spacing: int = 1,
              around=None) -> None:
        """Stamps `text` onto the surface at `at` (the label's centre, on
        the face) in the 5x7 font: each glyph cell is `size` metres (default
        one voxel). `plate` first paints a rounded plate behind the text.
        `around=(cx, cz, radius)` wraps the text onto a vertical cylinder
        (a mug, a can) instead of a flat face; `at` is then the point on
        the cylinder the text is centred on."""
        if around is not None:
            self._label_around(text, at, around, size, ink, plate, pad, depth, spacing)
            return
        size = size or self.voxel_m
        depth = depth or self.voxel_m * 1.5
        glyphs = [FONT.get(ch.upper(), FONT[" "]) for ch in text]
        cols = sum(g.shape[1] for g in glyphs) + spacing * (len(glyphs) - 1)
        rows = 7
        w = cols * size
        h = rows * size
        # the face's in-plane axes (u right, v up) and the depth axis
        if face in ("front", "back"):
            ua, va, da, sgn = "x", "y", "z", (-1 if face == "front" else 1)
        elif face in ("top", "bottom"):
            ua, va, da, sgn = "x", "z", "y", (1 if face == "top" else -1)
        else:
            ua, va, da, sgn = "z", "y", "x", (1 if face == "right" else -1)
        # a model faces -Z, so from the front +X is on the viewer's left:
        # text on the front and top runs toward -X
        uflip = -1 if face in ("front", "top", "left") else 1
        vflip = -1 if face == "bottom" else 1
        coords = {"x": self.X, "y": self.Y, "z": self.Z}
        U, V, D = coords[ua], coords[va], coords[da]
        cu, cv, cd = at["xyz".index(ua)], at["xyz".index(va)], at["xyz".index(da)]
        in_depth = np.abs(D - cd) <= depth
        if plate is not None:
            pm = (np.abs(U - cu) <= w / 2 + pad) & (np.abs(V - cv) <= h / 2 + pad) & in_depth
            self.colour[pm & (self.colour > 0)] = plate
        # glyph mask in (col,row) cells
        mask = np.zeros((rows, cols), dtype=bool)
        x = 0
        for g in glyphs:
            mask[:, x:x + g.shape[1]] = g
            x += g.shape[1] + spacing
        col_idx = np.floor((uflip * (U - cu) + w / 2) / size).astype(int)
        row_idx = np.floor((h / 2 - vflip * (V - cv)) / size).astype(int)
        valid = (col_idx >= 0) & (col_idx < cols) & (row_idx >= 0) & (row_idx < rows) & in_depth
        hit = np.zeros(self.n, dtype=bool)
        hit[valid] = mask[row_idx[valid], col_idx[valid]]
        self.colour[hit & (self.colour > 0)] = ink

    def _label_around(self, text, at, around, size, ink, plate, pad, depth, spacing) -> None:
        size = size or self.voxel_m
        depth = depth or self.voxel_m * 1.5
        cx, cz, R = around
        glyphs = [FONT.get(ch.upper(), FONT[" "]) for ch in text]
        cols = sum(g.shape[1] for g in glyphs) + spacing * (len(glyphs) - 1)
        rows = 7
        w = cols * size
        h = rows * size
        a0 = np.arctan2(at[0] - cx, -(at[2] - cz))  # angle of the label centre, 0 at -z
        ang = np.arctan2(self.X - cx, -(self.Z - cz))
        da = np.angle(np.exp(1j * (ang - a0)))
        U = -da * R  # arc length from the centre, running toward -x (the viewer's right)
        V = self.Y
        radial = np.hypot(self.X - cx, self.Z - cz)
        in_depth = np.abs(radial - R) <= depth
        if plate is not None:
            pm = (np.abs(U) <= w / 2 + pad) & (np.abs(V - at[1]) <= h / 2 + pad) & in_depth
            self.colour[pm & (self.colour > 0)] = plate
        mask = np.zeros((rows, cols), dtype=bool)
        x = 0
        for g in glyphs:
            mask[:, x:x + g.shape[1]] = g
            x += g.shape[1] + spacing
        col_idx = np.floor((U + w / 2) / size).astype(int)
        row_idx = np.floor((h / 2 - (V - at[1])) / size).astype(int)
        valid = (col_idx >= 0) & (col_idx < cols) & (row_idx >= 0) & (row_idx < rows) & in_depth
        hit = np.zeros(self.n, dtype=bool)
        hit[valid] = mask[row_idx[valid], col_idx[valid]]
        self.colour[hit & (self.colour > 0)] = ink

    # -- output --------------------------------------------------------------

    def surface(self) -> np.ndarray:
        """Boolean mask of solid cells with at least one empty 6-neighbour."""
        g = np.pad(self.colour > 0, 1)
        inner = (g[:-2, 1:-1, 1:-1] & g[2:, 1:-1, 1:-1] & g[1:-1, :-2, 1:-1]
                 & g[1:-1, 2:, 1:-1] & g[1:-1, 1:-1, :-2] & g[1:-1, 1:-1, 2:])
        return (self.colour > 0) & ~inner

    def bounds(self):
        xs, ys, zs = np.nonzero(self.colour)
        if len(xs) == 0:
            return None
        return (xs.min(), ys.min(), zs.min()), (xs.max(), ys.max(), zs.max())

    def write(self, path: str, hollow: bool = True) -> dict:
        """Writes a .vox (one model, RGBA palette). Godot (x, y, z) becomes
        file (size_x - 1 - x, z, y), the rotation VoxWriter and VoxReader
        use, so the front (-Z here) faces MagicaVoxel's camera (-Y there).
        Returns the manifest geometry: size in voxels and metres, pivot
        (bottom centre), voxel count."""
        keep = self.surface() if hollow else (self.colour > 0)
        xs, ys, zs = np.nonzero(keep)
        b = self.bounds()
        lo = np.array(b[0])
        hi = np.array(b[1])
        size = hi - lo + 1
        if size.max() > 256:
            raise ValueError(f"{path}: model is {size} voxels; .vox holds at most 256 a side")
        gx = xs - lo[0]
        gy = ys - lo[1]
        gz = zs - lo[2]
        fx = size[0] - 1 - gx
        fy = gz
        fz = gy
        idx = self.colour[xs, ys, zs]
        xyzi = np.stack([fx, fy, fz, idx], axis=1).astype(np.uint8).tobytes()
        pal = bytearray(1024)
        for i, name in enumerate(NAMES):
            r, g, bl = PALETTE[name]
            pal[i * 4:i * 4 + 4] = bytes((r, g, bl, 255))
        for i in range(len(NAMES), 256):
            pal[i * 4:i * 4 + 4] = bytes((0, 0, 0, 255))
        chunks = b""
        chunks += b"SIZE" + struct.pack("<II", 12, 0) + struct.pack("<III", int(size[0]), int(size[2]), int(size[1]))
        chunks += b"XYZI" + struct.pack("<II", 4 + len(xyzi), 0) + struct.pack("<I", len(xs)) + xyzi
        chunks += b"RGBA" + struct.pack("<II", 1024, 0) + bytes(pal)
        with open(path, "wb") as f:
            f.write(b"VOX " + struct.pack("<I", 150) + b"MAIN" + struct.pack("<II", 0, len(chunks)) + chunks)
        return {
            "size_vox": [int(size[0]), int(size[1]), int(size[2])],
            "size_m": [round(float(size[0] * self.voxel_m), 4), round(float(size[1] * self.voxel_m), 4), round(float(size[2] * self.voxel_m), 4)],
            "pivot": [round(float(size[0]) / 2, 1), 0, round(float(size[2]) / 2, 1)],
            "voxels": int(len(xs)),
            "solid": int((self.colour > 0).sum()),
        }

    def preview(self, path: str, px: int = 420) -> None:
        """A quick three-quarter orthographic render (no AO) to look at while
        iterating; the prop studio and prop sheet are the real view."""
        from PIL import Image

        keep = self.surface()
        xs, ys, zs = np.nonzero(keep)
        if len(xs) == 0:
            return
        idx = self.colour[xs, ys, zs]
        cols = np.array([(0, 0, 0)] + [PALETTE[n] for n in NAMES], dtype=np.float32) / 255.0
        c = cols[idx]
        g = np.pad(self.colour > 0, 1)
        top = ~g[xs + 1, ys + 2, zs + 1]
        front = ~g[xs + 1, ys + 1, zs]
        side = ~g[xs + 2, ys + 1, zs + 1]
        shade = np.where(top, 1.0, np.where(front, 0.82, np.where(side, 0.66, 0.5)))
        a = np.radians(-35)
        e = np.radians(30)
        n = np.array(self.n)
        X = xs - n[0] / 2
        Y = ys - n[1] / 2
        Z = zs - n[2] / 2
        # camera looks from -z, +x; rotate about y
        xr = X * np.cos(a) + Z * np.sin(a)
        zr = -X * np.sin(a) + Z * np.cos(a)
        u = xr
        v = Y * np.cos(e) + zr * np.sin(e)
        depth = -zr * np.cos(e) + Y * np.sin(e)
        ext = n.max() * 1.1
        scale = px / ext
        U = ((u / ext + 0.5) * px).astype(int)
        V = ((0.5 - v / ext) * px).astype(int)
        img = np.full((px, px, 3), (0.17, 0.18, 0.2), dtype=np.float32)
        r = max(1, int(np.ceil(scale)) + 1)
        rgb = c * shade[:, None]
        for i in np.argsort(depth):
            uu, vv = U[i], V[i]
            if 0 <= uu < px and 0 <= vv < px:
                img[vv:vv + r, uu:uu + r] = rgb[i]
        Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(path)


def manifest(path: str, rec: dict) -> None:
    with open(path, "w") as f:
        json.dump(rec, f, indent=2, sort_keys=True)
        f.write("\n")
