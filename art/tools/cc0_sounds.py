#!/usr/bin/env python3
"""Builds RinkGM's recorded sounds into assets/audio/ from CC0 sources
(16-bit mono, 22050 Hz), replacing synth_sounds.py's placeholders under the
same names, and writes assets/audio/CREDITS.md.

    python3 art/tools/cc0_sounds.py             # every recorded sound
    python3 art/tools/cc0_sounds.py puck_post   # just the named ones

Needs ffmpeg and network access to freesound.org / kenney.nl. Sources are
cached in ~/.cache/rinkgm_cc0. Only CC0 sources: a Freesound page that does
not say Creative Commons 0 stops the build. Freesound sounds are taken from
the public HQ preview (128 kbps mp3), which is plenty for 22 kHz mono.

Loudness: each sound is scaled so its active RMS (the loud part, tails and
silence ignored) matches the placeholder it replaces, since the mix in
RinkSound / WorldSound / VenueSound was tuned against those; then a soft
limiter keeps peaks under 0.95. A sharp hit is not pushed more than ~3 dB
into the limiter, so it can end up quieter than its placeholder rather than
squashed. GAIN nudges a sound from that match.
"""
import json
import os
import re
import subprocess
import sys
import time
import wave
import zipfile

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "audio")
CACHE = os.path.expanduser("~/.cache/rinkgm_cc0")


# -------------------------------------------------------------------- sources

class Source:
	def __init__(self, title, author, url, licence="CC0 1.0"):
		self.title, self.author, self.url, self.licence = title, author, url, licence


def _get(url, path):
	if not os.path.exists(path):
		os.makedirs(os.path.dirname(path), exist_ok=True)
		subprocess.run(["curl", "-sSLf", "-m", "180", "-o", path + ".part", url], check=True)
		os.replace(path + ".part", path)
	return path


def _page(url):
	for wait in (2, 5, 10, 20, 0):  # freesound throttles bursts of requests
		r = subprocess.run(["curl", "-sSLf", "-m", "40", url], capture_output=True, text=True)
		if r.returncode == 0:
			return r.stdout
		time.sleep(wait)
	sys.exit("could not fetch " + url)


def freesound(sid):
	"""(samples, Source) for Freesound sound `sid`, from its HQ preview."""
	meta_path = os.path.join(CACHE, "freesound", "%d.json" % sid)
	if not os.path.exists(meta_path):
		page = _page("https://freesound.org/s/%d/" % sid)
		if "Creative Commons 0" not in page and "publicdomain/zero" not in page:
			sys.exit("freesound %d is not CC0" % sid)
		lq = re.search(r"https://cdn\.freesound\.org/previews/\d+/%d_\d+-[hl]q\.mp3" % sid, page).group(0)
		canon = re.search(r"https://freesound\.org/people/([^/\"]+)/sounds/%d/" % sid, page)
		title = re.search(r'<meta property="og:title" content="([^"]*)"', page) \
			or re.search(r"<title>Freesound - (.*?) by [^<]*</title>", page)
		meta = {"preview": re.sub(r"-lq\.mp3$", "-hq.mp3", lq), "url": canon.group(0),
			"author": canon.group(1), "title": re.sub(r" by %s$" % re.escape(canon.group(1)), "", title.group(1))}
		os.makedirs(os.path.dirname(meta_path), exist_ok=True)
		json.dump(meta, open(meta_path, "w"))
	meta = json.load(open(meta_path))
	mp3 = _get(meta["preview"], os.path.join(CACHE, "freesound", "%d.mp3" % sid))
	return decode(mp3), Source(meta["title"], meta["author"], meta["url"])


def kenney(pack, member):
	"""(samples, Source) for `member` (a path inside the zip) of Kenney pack `pack`."""
	zpath = os.path.join(CACHE, "kenney", pack + ".zip")
	if not os.path.exists(zpath):
		url = re.search(r"https://kenney\.nl/media/pages/assets/%s/[^\"]+\.zip" % pack,
			_page("https://kenney.nl/assets/" + pack)).group(0)
		_get(url, zpath)
	dest = os.path.join(CACHE, "kenney", pack)
	if not os.path.isdir(dest):
		zipfile.ZipFile(zpath).extractall(dest)
	return decode(os.path.join(dest, member)), Source(
		"%s (%s)" % (os.path.basename(member), pack), "Kenney", "https://kenney.nl/assets/" + pack)


def decode(path):
	raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
		capture_output=True, check=True).stdout
	return np.frombuffer(raw, dtype="<f4").astype(np.float64)


# ---------------------------------------------------------------------- edits

def secs(n):
	return int(round(n * SR))


def env(x, win):
	n = max(1, secs(win))
	return np.sqrt(np.convolve(x * x, np.ones(n) / n, "same"))


def filt(x, lo=0.0, hi=0.0):
	"""Zero-phase 2nd-order-ish high/low pass in the frequency domain."""
	X = np.fft.rfft(x)
	f = np.maximum(np.fft.rfftfreq(len(x), 1.0 / SR), 1e-3)
	g = np.ones_like(f)
	if lo > 0:
		g /= np.sqrt(1.0 + (lo / f) ** 4)
	if hi > 0:
		g /= np.sqrt(1.0 + (f / hi) ** 4)
	return np.fft.irfft(X * g, len(x))


def cut(x, t, dur, fade_out=None, pre=0.004):
	"""A one-shot of `dur` s starting just before `t`, with short fades."""
	a = max(0, secs(t - pre))
	s = x[a:a + secs(dur)].copy()
	fi = secs(0.002)
	s[:fi] *= np.linspace(0.0, 1.0, fi)
	fo = secs(fade_out if fade_out is not None else min(0.3, dur * 0.4))
	s[-fo:] *= np.linspace(1.0, 0.0, fo) ** 2
	return s


def loop(x, t, dur, xf=0.6):
	"""A seamless loop of `dur` s from `t`: the material after the loop end
	crossfades (equal power) into the head, so the wrap is continuous."""
	a, n, m = secs(t), secs(dur), secs(xf)
	s = x[a:a + n + m].copy()
	assert len(s) == n + m, "source too short for the loop"
	w = np.sqrt(np.linspace(0.0, 1.0, m))
	out = s[:n].copy()
	out[:m] = s[:m] * w + s[n:n + m] * w[::-1]
	return out


def room(x, rt60=1.6, wet_db=-16.0, tail=None, seed=1):
	"""Adds a cold concrete-and-steel arena tail (exponentially decaying,
	low-passed noise IR) under a dry recording made outdoors or close up."""
	rng = np.random.default_rng(seed)
	n = secs(rt60 * 1.1)
	t = np.arange(n) / SR
	ir = rng.standard_normal(n) * np.exp(-6.91 * t / rt60)
	ir = filt(ir, 120.0, 3500.0)
	ir[: secs(0.012)] = 0.0  # pre-delay
	ir /= np.sqrt(np.sum(ir ** 2))
	m = len(x) + n
	wet = np.fft.irfft(np.fft.rfft(x, m) * np.fft.rfft(ir, m), m)
	y = np.zeros(m)
	y[: len(x)] += x
	y += wet * 10 ** (wet_db / 20.0)
	if tail is not None:
		y = y[: secs(tail)]
	fo = secs(min(0.4, len(y) / SR * 0.3))
	y[-fo:] *= np.linspace(1.0, 0.0, fo) ** 2
	return y


def active_rms(x):
	e = env(x, 0.05)
	k = e[e > e.max() * 0.25]
	return float(np.sqrt(np.mean(k ** 2))) if len(k) else float(np.sqrt(np.mean(x ** 2)))


def read_wav(path):
	with wave.open(path) as w:
		return np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32767.0


# ------------------------------------------------------------------- recipes
# name -> (build() returning (samples, [Source]), what was done to it)

def puck_boards():
	x, src = freesound(450719)  # four clean single hits; this is the second
	return room(filt(cut(x, 3.946, 0.9, 0.5), 50.0), rt60=1.4, wet_db=-14.0), [src]


def puck_post():
	x, src = freesound(406490)  # one strike, then the pipe rings for seconds
	return cut(filt(x, 90.0), 0.0, 3.3, 1.6), [src]


def glass_rattle():
	x, src = freesound(455758)  # the second slam: a sharp hit, then the pane rattles
	return room(filt(cut(x, 5.968, 1.1, 0.5), 160.0), rt60=1.2, wet_db=-18.0), [src]


RECIPES = {
	"puck_boards": (puck_boards, "one hit cut out, low rumble filtered, short arena tail added"),
	"puck_post": (puck_post, "one strike and its ring cut to 3.3 s, rumble filtered"),
	"glass_rattle": (glass_rattle, "the hard-close hit and pane rattle cut out, light arena tail added"),
}
GAIN = {}


def placeholder_rms(name):
	"""Active RMS of synth_sounds.py's placeholder for `name` (rebuilt from its
	fixed seed into the cache, so a rerun levels the same way)."""
	import synth_sounds
	synth_sounds.OUT = os.path.join(CACHE, "placeholders")
	path = os.path.join(synth_sounds.OUT, name + ".wav")
	if not os.path.exists(path):  # its builder makes a set of files; build them all once
		os.makedirs(synth_sounds.OUT, exist_ok=True)
		for build in synth_sounds.ALL.values():
			build()
	return active_rms(read_wav(path))


def write(name, x):
	path = os.path.join(OUT, name + ".wav")
	x = np.asarray(x, dtype=np.float64)
	x = x - np.mean(x)
	x *= placeholder_rms(name) / (active_rms(x) + 1e-12)
	x *= 10 ** (GAIN.get(name, 0.0) / 20.0)
	x *= min(1.0, 1.35 / np.max(np.abs(x)))  # sharp hits: at most ~3 dB into the limiter
	ceil, knee = 0.95, 0.76
	over = np.abs(x) > knee
	x[over] = np.sign(x[over]) * (knee + (ceil - knee) * np.tanh((np.abs(x[over]) - knee) / (ceil - knee)))
	pcm = np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2")
	with wave.open(path, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(SR)
		w.writeframes(pcm.tobytes())
	print("%-24s %5.2f s  peak %.2f  %6.1f KB" % (name + ".wav", len(x) / SR, np.max(np.abs(x)), os.path.getsize(path) / 1024.0))


CREDITS_HEAD = """# Sound credits

Recorded sounds in this folder come from CC0 (public domain) sources only and
are built by `art/tools/cc0_sounds.py`, which downloads, cuts, filters and
levels them (16-bit mono, 22050 Hz, loudness matched to the placeholder each
one replaced). CC0 needs no attribution; it is recorded here anyway so every
file can be traced to its source. Every other .wav here is synthesised by
`art/tools/synth_sounds.py` and has no outside source.

| File | Source | Author | Licence | Edits |
|---|---|---|---|---|
"""


def credits(rows):
	path = os.path.join(OUT, "CREDITS.md")
	old = {}
	if os.path.exists(path):
		for line in open(path):
			m = re.match(r"\| `([a-z0-9_]+)\.wav` \|", line)
			if m:
				old[m.group(1)] = line
	old.update(rows)
	with open(path, "w") as f:
		f.write(CREDITS_HEAD)
		for name in sorted(old):
			f.write(old[name])


if __name__ == "__main__":
	names = sys.argv[1:] or list(RECIPES)
	rows = {}
	for nm in names:
		build, edits = RECIPES[nm]
		x, srcs = build()
		write(nm, x)
		rows[nm] = "| `%s.wav` | %s | %s | %s | %s |\n" % (nm,
			"<br>".join("[%s](%s)" % (s.title.replace("|", "/"), s.url) for s in srcs),
			", ".join(sorted({s.author for s in srcs})), ", ".join(sorted({s.licence for s in srcs})), edits)
	credits(rows)
