"""Pixel-art logo kit for RinkGM: hand-drawn motifs, generated shapes and a
pixel wordmark, drawn at native resolution and scaled up with hard edges."""
import math
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
FONT_DIR = os.path.join(ROOT, "assets/ui/fonts/silkscreen/")

# '#' = fg, '+' = accent, 'o' = outline/dark, '.' = transparent
MOTIFS = {
    "bear": """
..oo........oo..
.o##o......o##o.
.o#+#oooooo#+#o.
..o##########o..
.o############o.
.o##oo####oo##o.
.o##o+o##o+o##o.
o##############o
o#####oooo#####o
o####o++++o####o
.o####oooo####o.
..o##########o..
...oo######oo...
.....oooooo.....""",
    "mitten": """
....oooooo....
...o######o...
..o########o..
..o########o..
.oo########o..
o##o#######o..
o##o#######o..
o###o######o..
.o###o#####o..
..o########o..
...o#######o..
...o+++++++o..
...o+++++++o..
...ooooooooo..""",
    "moose": """
oo.o.o......o.o.oo
o#o#o#o....o#o#o#o
o######o..o######o
.o######oo######o.
..oo##o####o##oo..
....o##########o..
.....o###oo###o...
.....o##o++o##o...
.....o########o...
......o######o....
......o######o....
.......o####o.....
.......o#++#o.....
........oooo......""",
    "leaf": """
.......o.......
......o#o......
...o..o#o..o...
..o#oo###oo#o..
..o#########o..
o..o#######o..o
o#oo#######oo#o
.o#####+#####o.
..o####+####o..
...o###+###o...
..o####+####o..
.ooooo#+#ooooo.
......o+o......
......o+o......
.......o.......""",
    "flame": """
....o.....
...o#o....
...o##o...
..o###o.o.
..o####o#o
.o##+###o.
.o#+++##o.
o##+++###o
o#++.++##o
o#+...+##o
o#+...+##o
.o#+++##o.
..o####o..
...oooo...""",
    "tree": """
.....o.....
....o#o....
...o###o...
..o#####o..
...o###o...
..o#####o..
.o#######o.
..o#####o..
.o#######o.
o#########o
ooooo+ooooo
....o+o....
....ooo....""",
    "cup": """
o..oooooooo..o
o.o########o.o
.oo##+##+##oo.
..o########o..
...o######o...
....o####o....
.....o##o.....
.....o##o.....
....o####o....
...o######o...
...o++++++o...
...oooooooo...""",
    "truck": """
..........ooooooo...
..........o#++++#o..
..........o#++++##o.
ooooooooooo########o
o#########o########o
o#########o########o
o##########o#######o
ooooooooooooooooooo.
..ooo.........ooo...
.o+++o.......o+++o..
..ooo.........ooo...""",
    "anchor": """
.....ooo.....
....o#o#o....
.....o#o.....
...ooo#ooo...
...o#####o...
.....o#o.....
.....o#o.....
o....o#o....o
#o...o#o...o#
o#o..o#o..o#o
.o#oo###oo#o.
..o#######o..
...ooooooo...""",
    "sticks": """
oo............oo
o#o..........o#o
.o#o........o#o.
..o#o......o#o..
...o#o....o#o...
....o#o..o#o....
.....o#oo#o.....
......o##o......
......o##o......
.....o#oo#o.....
....o#o..o#o....
.oooo#o..o#oooo.
o++++o....o++++o
.oooo......oooo.""",
    "bolt": """
.....oooo
....o##o.
...o##o..
..o##o...
.o#####o.
...o##o..
..o##o...
.o##o....
o##o.....
ooo......""",
    "mountain": """
.......o..........
......o+o.........
.....o+++o...o....
....o#+#+#o.o#o...
...o#######o###o..
..o###########o#o.
.o###############o
oooooooooooooooooo""",
    "wave": """
.....oooo.......
...oo####oo.....
..o###oo###o....
.o##oo..o##o....
.o#o...o##o.....
o##o..o##o...oo.
o###oo##o..oo##o
.o###########oo.
..o+++++++++o...
...ooooooooo....""",
    "gear": None,      # generated
    "star": None,
    "flake": None,
    "donut": None,
    "tire": None,
    "puck": """
..oooooooo..
.o########o.
o##########o
o++++++++++o
.o++++++++o.
..oooooooo..""",
    "blade": """
.................oo
................o#o
...............o#o.
..............o#o..
.............o#o...
............o#o....
...........o#o.....
oooooooooooo#o.....
o+##########o......
.oooooooooooo......""",
    "skate": """
..ooooo........
..o###o........
..o###o........
..o###oooooo...
..o#########o..
.o###########o.
.ooooooooooooo.
..o.......o....
o+++++++++++++o
.ooooooooooooo.""",
    "cross": """
...ooooo...
...o###o...
...o###o...
oooo###oooo
o#########o
o#########o
oooo###oooo
...o###o...
...o###o...
...ooooo...""",
    "zamb": """
oooooooooooo....
o##########o....
o#++++++++#oooo.
o#+oooooo+#o##o.
o#++++++++#o##o.
o##########o##o.
oooooooooooooooo
.oo..........oo.
o##o........o##o
.oo..........oo.""",
}


def _mask(name):
    if MOTIFS.get(name) is not None:
        rows = [r for r in MOTIFS[name].strip("\n").split("\n")]
        w = max(len(r) for r in rows)
        return [r.ljust(w, ".") for r in rows]
    n = 15
    grid = [["." for _ in range(n)] for _ in range(n)]
    c = (n - 1) / 2
    for y in range(n):
        for x in range(n):
            dx, dy = x - c, y - c
            r = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            ch = "."
            if name == "donut":
                if r <= 7.2:
                    ch = "o"
                if r <= 6.3:
                    ch = "+" if r > 4.0 else "#"
                if r <= 2.4:
                    ch = "o"
                if r <= 1.6:
                    ch = "."
                if 4.0 < r <= 6.3 and (x * 7 + y * 3) % 9 == 0:
                    ch = "#"  # sprinkles
            elif name == "tire":
                if r <= 7.2:
                    ch = "o"
                if r <= 6.4:
                    ch = "#" if r > 3.6 else "o"
                if r <= 2.8:
                    ch = "+"
                if r > 4.6 and r <= 6.4 and int((a + math.pi) / (math.pi / 8)) % 2 == 0:
                    ch = "o"  # tread
            elif name == "gear":
                teeth = 6.8 if int((a + math.pi) / (math.pi / 6)) % 2 == 0 else 5.4
                if r <= teeth + 0.4:
                    ch = "o"
                if r <= teeth - 0.4:
                    ch = "#"
                if r <= 2.6:
                    ch = "o"
                if r <= 1.6:
                    ch = "+"
            elif name == "star":
                k = 5
                rr = 7.0 / (1 + 0.55 * abs(math.cos(k * (a + math.pi / 2) / 2)) ** 0.6) if True else 0
                spike = abs(math.cos((a + math.pi / 2) * k / 2))
                lim = 3.0 + 4.2 * spike ** 3
                if r <= lim + 0.6:
                    ch = "o"
                if r <= lim - 0.3:
                    ch = "#"
            elif name == "flake":
                for i in range(6):
                    ang = i * math.pi / 3
                    px, py = math.cos(ang), math.sin(ang)
                    along = dx * px + dy * py
                    perp = abs(-dx * py + dy * px)
                    if 0 <= along <= 7 and perp <= 0.6:
                        ch = "#"
                    if 3 <= along <= 5.5 and abs(perp - (along - 3) * 0.9) <= 0.5 and perp <= 2.2:
                        ch = "#"
                if r <= 1.2:
                    ch = "+"
            grid[y][x] = ch
    return ["".join(r) for r in grid]


def draw_motif(img, name, x0, y0, fg, accent, outline, scale=1):
    m = _mask(name)
    px = img.load()
    for y, row in enumerate(m):
        for x, ch in enumerate(row):
            col = {"#": fg, "+": accent, "o": outline}.get(ch)
            if col:
                for sy in range(scale):
                    for sx in range(scale):
                        X, Y = x0 + x * scale + sx, y0 + y * scale + sy
                        if 0 <= X < img.width and 0 <= Y < img.height:
                            px[X, Y] = col
    return len(m[0]) * scale, len(m) * scale


def motif_size(name, scale=1):
    m = _mask(name)
    return len(m[0]) * scale, len(m) * scale


def _font(size, bold=True):
    return ImageFont.truetype(FONT_DIR + ("Silkscreen-Bold.ttf" if bold else "Silkscreen-Regular.ttf"), size)


def text(draw, xy, s, fill, size=8, bold=True, anchor="mm"):
    draw.fontmode = "1"
    draw.text(xy, s, fill=fill, font=_font(size, bold), anchor=anchor)


def text_w(s, size=8, bold=True):
    return _font(size, bold).getlength(s)


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def shape(draw, kind, box, fill, edge, accent=None):
    x0, y0, x1, y1 = box
    if kind == "circle":
        draw.ellipse(box, fill=edge)
        draw.ellipse((x0 + 2, y0 + 2, x1 - 2, y1 - 2), fill=fill)
        if accent:
            draw.ellipse((x0 + 4, y0 + 4, x1 - 4, y1 - 4), outline=accent)
    elif kind == "shield":
        w = x1 - x0
        pts = [(x0, y0), (x1, y0), (x1, y0 + (y1 - y0) * 0.55), (x0 + w / 2, y1), (x0, y0 + (y1 - y0) * 0.55)]
        draw.polygon(pts, fill=edge)
        inner = [(x0 + 2, y0 + 2), (x1 - 2, y0 + 2), (x1 - 2, y0 + (y1 - y0) * 0.55 - 1), (x0 + w / 2, y1 - 3), (x0 + 2, y0 + (y1 - y0) * 0.55 - 1)]
        draw.polygon(inner, fill=fill)
        if accent:
            draw.line([(x0 + 4, y0 + 4), (x1 - 4, y0 + 4)], fill=accent)
    elif kind == "diamond":
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        draw.polygon([(cx, y0), (x1, cy), (cx, y1), (x0, cy)], fill=edge)
        draw.polygon([(cx, y0 + 3), (x1 - 3, cy), (cx, y1 - 3), (x0 + 3, cy)], fill=fill)
    elif kind == "roundrect":
        draw.rounded_rectangle(box, radius=4, fill=edge)
        draw.rounded_rectangle((x0 + 2, y0 + 2, x1 - 2, y1 - 2), radius=3, fill=fill)
        if accent:
            draw.line([(x0 + 4, y1 - 5), (x1 - 4, y1 - 5)], fill=accent)
    elif kind == "oval":
        draw.ellipse(box, fill=edge)
        draw.ellipse((x0 + 2, y0 + 2, x1 - 2, y1 - 2), fill=fill)
    elif kind == "banner":
        draw.rectangle(box, fill=edge)
        draw.rectangle((x0 + 2, y0 + 2, x1 - 2, y1 - 2), fill=fill)
        if accent:
            draw.rectangle((x0 + 2, y0 + 2, x1 - 2, y0 + 3), fill=accent)
            draw.rectangle((x0 + 2, y1 - 3, x1 - 2, y1 - 2), fill=accent)


def badge(spec, scale=8):
    """Square emblem: a shape with a motif and an arched-free short name."""
    W = H = 64
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = [hexc(x) for x in spec["colors"]]
    while len(c) < 3:
        c.append(hexc("eeeeea"))
    bg, fg, acc = c[0], c[1], c[2]
    dark = hexc(spec.get("outline", "17181b"))
    shape(d, spec.get("shape", "circle"), (1, 1, W - 2, H - 2), bg, dark, acc)
    label = spec.get("short", "")
    w0, h0 = motif_size(spec["motif"])
    max_h = 22 if spec.get("shape") == "shield" else 30
    ms = 2 if w0 * 2 <= 40 and h0 * 2 <= max_h else 1
    mw, mh = motif_size(spec["motif"], ms)
    top = 9 if spec.get("shape") != "shield" else 7
    if label:
        draw_motif(img, spec["motif"], (W - mw) // 2, top, fg, acc, dark, ms)
        text(d, (W / 2, min(top + mh + 9, 36 if spec.get("shape") == "shield" else H - 13)), label, fg, size=8)
    else:
        draw_motif(img, spec["motif"], (W - mw) // 2, (H - mh) // 2, fg, acc, dark, ms)
    return img.resize((W * scale, H * scale), Image.NEAREST)


def wordmark(spec, scale=8):
    """Brand or sponsor mark: motif left, name and slogan right, on a plate."""
    c = [hexc(x) for x in spec["colors"]]
    while len(c) < 3:
        c.append(hexc("eeeeea"))
    bg, fg, acc = c[0], c[1], c[2]
    dark = hexc(spec.get("outline", "17181b"))
    name = spec["text"].upper()
    size = 8
    tw = int(text_w(name, size))
    sub = spec.get("sub", "")
    sw = int(text_w(sub.upper(), 8, False)) if sub else 0
    mw, mh = motif_size(spec["motif"])
    W = max(tw, sw) + mw + 16
    H = max(mh + 8, 30)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    shape(d, spec.get("shape", "roundrect"), (0, 0, W - 1, H - 1), bg, dark, acc if spec.get("stripe") else None)
    draw_motif(img, spec["motif"], 5, (H - mh) // 2, fg, acc, dark)
    tx = 5 + mw + 4
    if sub:
        lum = lambda c: 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
        sc = acc if abs(lum(acc) - lum(bg)) > 70 else fg
        text(d, (tx, H / 2 - 6), name, fg, size=size, anchor="lm")
        text(d, (tx, H / 2 + 6), sub.upper(), sc, size=8, bold=False, anchor="lm")
    else:
        text(d, (tx, H / 2), name, fg, size=size, anchor="lm")
    return img.resize((W * scale, H * scale), Image.NEAREST)


def sheet(images, cols, bg="24252b", pad=24, label=None):
    rows = (len(images) + cols - 1) // cols
    cw = max(i.width for _, i in images) + pad
    ch = max(i.height for _, i in images) + pad + 36
    out = Image.new("RGBA", (cols * cw + pad, rows * ch + pad + (60 if label else 0)), hexc(bg))
    d = ImageDraw.Draw(out)
    oy = 0
    if label:
        d.fontmode = "1"
        d.text((pad, 14), label, fill=hexc("f4f8ff"), font=_font(32))
        oy = 60
    for k, (name, im) in enumerate(images):
        x = pad + (k % cols) * cw + (cw - pad - im.width) // 2
        y = oy + pad + (k // cols) * ch
        out.alpha_composite(im, (x, y))
        d.fontmode = "1"
        d.text((pad + (k % cols) * cw + (cw - pad) // 2, y + im.height + 18), name, fill=hexc("b9c0c6"), font=_font(16, False), anchor="mm")
    return out

MOTIFS.update({
    "crown": """
o.....oo.....o
#o...o##o...o#
#+o..o##o..o+#
##+oo####oo+##
##############
#+##+####+##+#
##############
oooooooooooooo
o++++++++++++o
oooooooooooooo""",
    "gull": """
oo..............oo
o#oo..........oo#o
.o##oo......oo##o.
..o###oo..oo###o..
...o####oo####o...
....o###++###o....
.....oo####oo.....
.......o##o.......
........oo........""",
    "loon": """
......ooo.........
.....o###o........
....o#+###o.......
.ooo#######o......
o++o########o.....
.ooo#####.##o.....
.....o###.###oooo.
....o###.#.#####o.
...o#####.#.###o..
..o############o..
..oooooooooooooo..""",
    "ghost": """
....oooooo....
..oo######oo..
.o##########o.
.o##++##++##o.
o###++##++###o
o############o
o#####oo#####o
o####o..o####o
o#####oo#####o
o############o
o############o
o##o##o##o##oo
.oo.oo.oo.oo..""",
    "rocket": """
......oo......
.....o##o.....
....o####o....
....o#++#o....
....o#++#o....
....o####o....
....o####o....
...o######o...
..o#o####o#o..
.o##o####o##o.
.oooo+oo+oooo.
....o+..+o....
.....o..o.....""",
    "scorpion": """
.........ooo..
........o##+o.
........o#o.o.
........o#o...
..o.o...o#o...
.o#o#o.o##o...
o##o##o###o...
.o#######o....
..o#####o.....
.o#o###o#o....
o#o.o#o.o#o...
.o...o...o....""",
    "anvil": """
oooooooooooooo
o############o
.o##########o.
..oooo##oooo..
.....o##o.....
....o####o....
...o######o...
..oooooooooo..""",
    "paddle": """
.....oo......
....o##o.....
....o##o.....
.....oo......
.....o#o.....
.....o#o.....
.....o#o.....
....o###o....
...o#####o...
...o##+##o...
...o##+##o...
...o#####o...
....o###o....
.....ooo.....""",
    "cloud": """
.....oooo.......
....o####o......
..ooo#####oooo..
.o###########o..
o#############o.
o##############o
.oooooooooooooo.
...o.o..o.o.....
..o.o..o.o......
.o.o..o.o.......""",
    "pick": """
...ooooooo....
.oo#######oo..
o##ooo#oooo##o
.oo..o#o...oo.
.....o#o......
.....o#o......
.....o#o......
.....o#o......
.....o+o......
.....o+o......
......o.......""",
    "paw": """
..oo.oo.oo..
.o##o##o##o.
.o##o##o##o.
o#oo.oo.oo#o
o#o......o#o
.o.oooooo.o.
..o######o..
.o########o.
.o########o.
..o######o..
...oooooo...""",
    "house": """
......oo......
.....o##o.....
....o####o....
...o######o...
..o########o..
.o##########o.
oo##########oo
.o####++####o.
.o###++++###o.
.o###+..+###o.
.o###+..+###o.
.oooooooooooo.""",
    "pizza": """
....oooooo....
..oo++++++oo..
.o+########+o.
o+###oo#####+o
o+##o++o####+o
o+###oo##ooo..
o+#######o....
o+###oo##ooo..
.o+#o++o###+o.
..oo#oo####o..
....oooooo....""",
    "arcs": """
...ooooooo...
.oo+++++++oo.
o+oo.....oo+o
.o.ooooooo.o.
..o+++++++o..
...o.....o...
....o###o....
.....o#o.....
....o###o....
.....o#o.....
.....o#oo....
......ooo....""",
    "bone": """
.oo.......oo.
o##o.....o##o
o###ooooo###o
.o#+++++++#o.
o###ooooo###o
o##o.....o##o
.oo.......oo.""",
    "tower": """
o.oo.oo.oo.o
o#o#o#o#o#o#
o##########o
o###oooo###o
o##o++++o##o
o##########o
o####oo####o
o###o..o###o
o###o..o###o
o##########o
o##########o
oooooooooooo""",
    "hexagon": """
....oooooo....
...o######o...
..o########o..
.o##########o.
o############o
o++++++++++++o
o############o
.o##########o.
..o########o..
...o######o...
....oooooo....""",
    "tape": """
...oooooooo...
.oo########oo.
o###oooooo###o
o##o++++++o##o
o##o++..++o##o
o##o++..++o##o
o##o++++++o##o
o###oooooo###o
.oo########oo.
...oooooooo...""",
    "plain": """
oooooooooo
o########o
o#oooooo#o
o########o
oooooooooo""",
})

MOTIFS.update({
    "mug": """
.oooooooo.....
o+++++++++o...
o++o+++o++o...
oooooooooooooo
.o########ooo#o
.o##.##.##o.o#o
.o##.##.##o.o#o
.o##.##.##ooo#o
.o##.##.##oooo.
.o########o....
.o########o....
..oooooooo.....""",
    "tooth": """
.oooo..oooo.
o####oo####o
o##########o
o#+########o
o#+########o
o##########o
.o########o.
.o###oo###o.
.o##o..o##o.
.o##o..o##o.
..oo....oo..""",
    "plunger": """
......oo......
.....o##o.....
.....o##o.....
.....o##o.....
.....o##o.....
.....o##o.....
.....o##o.....
...oooooooo...
..o++++++++o..
.o++++++++++o.
o++++++++++++o
oooooooooooooo""",
    "fish": """
.....ooooo.........
...oo#####oo....oo.
..o##########o.o#o.
.o##o#########o##o.
o###############o..
o#+++++++++++++#o..
.o#############o##o
..oo#########oo.o#o
....ooooooooo....oo""",
})
