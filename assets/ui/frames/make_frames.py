#!/usr/bin/env python3
# Usage: python3 assets/ui/frames/make_frames.py assets/ui/frames (needs Pillow)
# Generates RINK-OS 9-slice frames: 16x16, 4px corner notch, 2px border.
import sys
from PIL import Image
out = sys.argv[1]
N, B, S = 4, 2, 16
def hexa(h, a=255):
    h = h.lstrip('#'); return (int(h[0:2],16), int(h[2:4],16), int(h[4:6],16), a)
def inside(x, y):
    if not (0 <= x < S and 0 <= y < S): return False
    cx = x < N or x >= S - N; cy = y < N or y >= S - N
    return not (cx and cy)
def frame(name, fill, border):
    im = Image.new('RGBA', (S, S), (0,0,0,0))
    for y in range(S):
        for x in range(S):
            if not inside(x, y): continue
            edge = any(not inside(x+dx, y+dy) for dx in range(-B, B+1) for dy in range(-B, B+1))
            im.putpixel((x, y), border if edge else fill)
    im.save(f'{out}/{name}.png')
CLEAR = (0,0,0,0)
frame('panel',          hexa('0f1b2e', 238), hexa('2f4a6e'))
frame('field',          hexa('0a1220', 245), hexa('2f4a6e'))
frame('button',         hexa('ffb22e'), hexa('ffb22e'))
frame('button_hover',   hexa('ffc85e'), hexa('ffc85e'))
frame('button_pressed', hexa('d9901c'), hexa('d9901c'))
frame('button_ghost',   hexa('2f4a6e'), hexa('2f4a6e'))
frame('button_ghost_hover', hexa('3d6090'), hexa('3d6090'))
frame('button_disabled', hexa('17243a'), hexa('2f4a6e'))
frame('focus',          CLEAR, hexa('5fe0f0'))

# Small icons (no notch): check boxes and the slider grabber.
def icon(name, w, h, draw):
    im = Image.new('RGBA', (w, h), (0,0,0,0))
    for y in range(h):
        for x in range(w):
            c = draw(x, y, w, h)
            if c: im.putpixel((x, y), c)
    im.save(f'{out}/{name}.png')
def box(x, y, w, h):
    return x < 2 or y < 2 or x >= w - 2 or y >= h - 2
icon('check_off', 16, 16, lambda x, y, w, h: hexa('2f4a6e') if box(x, y, w, h) else hexa('0a1220'))
icon('check_on', 16, 16, lambda x, y, w, h: hexa('2f4a6e') if box(x, y, w, h) else (hexa('ffb22e') if 4 <= x < 12 and 4 <= y < 12 else hexa('0a1220')))
icon('grabber', 10, 18, lambda x, y, w, h: hexa('ffb22e'))
icon('grabber_hover', 10, 18, lambda x, y, w, h: hexa('ffc85e'))
