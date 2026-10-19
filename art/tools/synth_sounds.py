#!/usr/bin/env python3
"""Synthesises RinkGM's venue sounds into assets/audio/ (16-bit mono, 22050 Hz).

    python3 art/tools/synth_sounds.py            # every sound
    python3 art/tools/synth_sounds.py plant_room # just the named ones

Everything is built from numpy noise, sines and decaying resonances; no
samples, no scipy. Loops are made in the frequency domain over exactly the
loop length (circular FFT filtering, circular reverb, tones and LFOs with a
whole number of cycles per loop), so they wrap seamlessly by construction;
a short crossfade of the ends is applied on top anyway. Every sound uses a
fixed seed, so a rerun writes the same files.

The building is a 1970s community rink: an ammonia ice plant with
reciprocating compressors, metal-halide and sodium lamps on old ballasts,
cinder-block walls, rubber matting, steel doors, and Doris the resurfacer.
"""
import os
import sys
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "audio")


# --------------------------------------------------------------------- basics

def secs(n):
	return int(round(n * SR))


def write(name, x, peak=0.89):
	x = np.asarray(x, dtype=np.float64)
	m = np.max(np.abs(x))
	if m > 0:
		x = x * (peak / m)
	pcm = np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2")
	path = os.path.join(OUT, name + ".wav")
	with wave.open(path, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(SR)
		w.writeframes(pcm.tobytes())
	print("%-24s %5.2f s  %6.1f KB" % (name + ".wav", len(x) / SR, os.path.getsize(path) / 1024.0))


def freqs(n):
	return np.fft.rfftfreq(n, 1.0 / SR)


def shape(x, gain_fn):
	"""Circular FFT filter: multiplies the spectrum by gain_fn(freq_hz)."""
	X = np.fft.rfft(x)
	return np.fft.irfft(X * gain_fn(freqs(len(x))), len(x))


def bandpass_gain(lo, hi, order=2):
	def g(f):
		f = np.maximum(f, 1e-3)
		a = 1.0 / np.sqrt(1.0 + (lo / f) ** (2 * order)) if lo > 0 else 1.0
		b = 1.0 / np.sqrt(1.0 + (f / hi) ** (2 * order)) if hi > 0 else 1.0
		return a * b
	return g


def peak_gain(fc, q, db):
	"""A resonant bump of `db` at fc (bandwidth fc/q) on a flat response."""
	def g(f):
		bw = fc / q
		return 1.0 + (10 ** (db / 20.0) - 1.0) / (1.0 + ((f - fc) / (bw * 0.5)) ** 2)
	return g


def mul(*gs):
	def g(f):
		out = np.ones_like(f)
		for gg in gs:
			out = out * gg(f)
		return out
	return g


def pink(f):
	return 1.0 / np.sqrt(np.maximum(f, 20.0))


def brown(f):
	return 1.0 / np.maximum(f, 15.0)


def noise(rng, n, gain_fn=None):
	x = rng.standard_normal(n)
	if gain_fn is not None:
		x = shape(x, gain_fn)
	return x / (np.std(x) + 1e-12)


def slow(rng, n, rate):
	"""Periodic smooth random curve in about -1..1, changing at ~rate Hz."""
	x = shape(rng.standard_normal(n), lambda f: np.exp(-(f / rate) ** 2))
	return x / (np.max(np.abs(x)) + 1e-12)


def snap(f, n):
	"""A frequency rounded to a whole number of cycles over n samples."""
	cyc = n / SR
	return max(1, round(f * cyc)) / cyc


def tone(n, f, phase=0.0, fm=None, fm_depth=0.0, loop=True):
	f = snap(f, n) if loop else f
	t = np.arange(n) / SR
	ph = 2 * np.pi * f * t + phase
	if fm is not None:
		# fm is zero-mean and periodic, so its integral is too (seamless)
		ph = ph + 2 * np.pi * fm_depth * np.cumsum(fm - np.mean(fm)) / SR
	return np.sin(ph)


def circ_reverb(rng, x, tau, mix, damp=4000.0):
	"""Circular convolution with a decaying noise tail (seamless for loops)."""
	n = len(x)
	t = np.arange(n) / SR
	ir = rng.standard_normal(n) * np.exp(-t / tau)
	ir = shape(ir, lambda f: 1.0 / np.sqrt(1.0 + (f / damp) ** 2))
	ir[0] = 0.0
	ir /= np.sqrt(np.sum(ir ** 2)) + 1e-12
	wet = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(ir), n)
	wet *= np.std(x) / (np.std(wet) + 1e-12)
	return x * (1 - mix) + wet * mix


def reverb(rng, x, tau, mix, damp=4000.0, tail=None):
	"""Linear convolution reverb for one-shots (adds a tail)."""
	tail = tail if tail is not None else tau * 4
	m = secs(tail)
	t = np.arange(m) / SR
	ir = rng.standard_normal(m) * np.exp(-t / tau)
	ir = lowpass(ir, damp)
	ir[:secs(0.008)] *= np.linspace(0, 1, secs(0.008))
	ir /= np.sqrt(np.sum(ir ** 2)) + 1e-12
	n = len(x) + m
	size = 1 << (n - 1).bit_length()
	wet = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:n]
	dry = np.concatenate([x, np.zeros(m)])
	wet *= np.sqrt(np.sum(dry ** 2)) / (np.sqrt(np.sum(wet ** 2)) + 1e-12)
	return dry * (1 - mix) + wet * mix


def lowpass(x, fc):
	"""One-pole low-pass (causal, for one-shots)."""
	a = np.exp(-2 * np.pi * fc / SR)
	y = np.empty_like(x)
	s = 0.0
	b = 1.0 - a
	for i in range(len(x)):
		s = b * x[i] + a * s
		y[i] = s
	return y


def highpass(x, fc):
	return x - lowpass(x, fc)


def biquad_bp(x, fc, q):
	"""RBJ band-pass (constant peak gain), causal, for one-shot transients."""
	w = 2 * np.pi * fc / SR
	al = np.sin(w) / (2 * q)
	b0, b2 = al, -al
	a0, a1, a2 = 1 + al, -2 * np.cos(w), 1 - al
	b0, b2, a1, a2 = b0 / a0, b2 / a0, a1 / a0, a2 / a0
	y = np.empty_like(x)
	x1 = x2 = y1 = y2 = 0.0
	for i in range(len(x)):
		v = b0 * x[i] + b2 * x2 - a1 * y1 - a2 * y2
		x2, x1 = x1, x[i]
		y2, y1 = y1, v
		y[i] = v
	return y


def modes(n, start, spec, rng=None, jitter=0.0):
	"""Decaying sinusoids [(freq, decay_s, amp), ...] starting at sample start."""
	out = np.zeros(n)
	t = np.arange(n - start) / SR
	for f, d, a in spec:
		if rng is not None and jitter:
			f *= 1 + rng.uniform(-jitter, jitter)
		out[start:] += a * np.exp(-t / d) * np.sin(2 * np.pi * f * t + (rng.uniform(0, 6.28) if rng is not None else 0))
	return out


def burst(rng, n, start, dur, lo, hi, attack=0.002):
	"""A short band-limited noise burst with a fast attack, exponential tail."""
	out = np.zeros(n)
	m = min(secs(dur * 5), n - start)
	t = np.arange(m) / SR
	env = np.minimum(1.0, t / max(attack, 1e-4)) * np.exp(-t / dur)
	b = rng.standard_normal(m) * env
	if lo > 0:
		b = highpass(b, lo)
	if hi > 0:
		b = lowpass(lowpass(b, hi), hi)
	out[start:start + m] += b
	return out


def seam(x, fade=0.05):
	"""Makes sure the loop wraps cleanly. Everything above is built circularly
	(FFT filters, reverb and tones over exactly the loop length), so the end
	already runs into the start; this only blends away any residual step at
	the wrap (from the few non-circular bits, like a click near the end) by
	crossfading the last `fade` seconds toward a copy that continues from the
	start, keeping the length (and so the loop's tones) unchanged."""
	m = secs(fade)
	y = x.copy()
	step = x[0] - x[-1] - (x[1] - x[0])  # jump at the wrap beyond the slope
	w = np.linspace(0, 1, m) ** 2
	y[-m:] += step * w
	return y


def fade_ends(x, a=0.002, r=0.02):
	x = x.copy()
	ma, mr = secs(a), secs(r)
	x[:ma] *= np.linspace(0, 1, ma)
	x[-mr:] *= np.linspace(1, 0, mr)
	return x


# --------------------------------------------------------------------- loops

def arena_room():
	"""The big room: HVAC rumble, the roof fans' blade tones, ballast buzz far off."""
	rng = np.random.default_rng(101)
	n = secs(8.0)
	rumble = noise(rng, n, mul(brown, bandpass_gain(18, 140))) * (1 + 0.25 * slow(rng, n, 0.4))
	air = noise(rng, n, mul(pink, bandpass_gain(150, 2500))) * (0.6 + 0.15 * slow(rng, n, 0.3))
	fan = np.zeros(n)
	for f0, amp in [(37.0, 0.5), (51.5, 0.35)]:
		wob = slow(rng, n, 0.25)
		am = 0.7 + 0.3 * slow(rng, n, 0.6)
		for h, ha in [(1, 1.0), (2, 0.45), (3, 0.2)]:
			fan += amp * ha * am * tone(n, f0 * h, rng.uniform(0, 6.28), wob, 0.4 * h)
	buzz = 0.05 * (tone(n, 120) + 0.5 * tone(n, 240) + 0.25 * tone(n, 360)) * (0.8 + 0.2 * slow(rng, n, 1.0))
	x = 0.35 * rumble + 0.5 * air + 0.3 * fan + buzz
	x = circ_reverb(rng, x, 1.6, 0.55, 1800)
	write("arena_room", seam(x))


def plant_room():
	"""Compressor drone, piston thrum, valve hiss and the odd relay tick."""
	rng = np.random.default_rng(202)
	n = secs(8.0)
	t = np.arange(n) / SR
	motor = 0.0
	for h, a in [(1, 1.0), (2, 0.8), (3, 0.3), (4, 0.25), (6, 0.12)]:
		motor = motor + a * tone(n, 59.8 * h, rng.uniform(0, 6.28))
	motor = np.tanh(1.6 * motor) * 0.5
	# two cylinders at 600 rpm: a thump every 1/10 s, alternating strength
	rate = snap(10.0, n)
	ph = (t * rate) % 1.0
	idx = np.floor(t * rate).astype(int)
	strength = np.where(idx % 2 == 0, 1.0, 0.7) * (0.85 + 0.15 * slow(rng, n, 0.5))
	pulse = np.exp(-ph / 0.035) * strength
	thrum = pulse * noise(rng, n, bandpass_gain(60, 700))
	knock = pulse * tone(n, 83.0, 0.0) * 0.8
	body = noise(rng, n, mul(brown, bandpass_gain(25, 400))) * (0.8 + 0.2 * slow(rng, n, 0.7))
	hiss = noise(rng, n, bandpass_gain(2500, 7000)) * (0.5 + 0.5 * (0.5 + 0.5 * slow(rng, n, 0.2)))
	ticks = np.zeros(n)
	for at in (1.37, 5.82):
		s = secs(at)
		ticks += modes(n, s, [(2350, 0.012, 1.0), (4100, 0.008, 0.6), (980, 0.03, 0.4)], rng, 0.05)
		ticks += 0.5 * burst(rng, n, s, 0.003, 1500, 9000)
	x = 0.7 * motor + 0.9 * thrum + 0.45 * knock + 0.3 * body + 0.12 * hiss + 0.35 * ticks
	x = circ_reverb(rng, x, 0.35, 0.35, 3000)
	write("plant_room", seam(x))


def fluorescent_buzz():
	"""Ballast hum: 60 Hz and its harmonics (120 Hz strongest) with a crackle."""
	rng = np.random.default_rng(303)
	n = secs(4.0)
	x = 0.0
	for h, a in [(1, 0.35), (2, 1.0), (3, 0.3), (4, 0.5), (6, 0.3), (8, 0.2), (10, 0.12), (14, 0.06), (18, 0.03)]:
		x = x + a * tone(n, 60.0 * h, rng.uniform(0, 6.28))
	x = np.tanh(2.0 * x) * (0.85 + 0.15 * slow(rng, n, 2.0))
	crackle = np.zeros(n)
	for _ in range(40):
		s = rng.integers(0, n - secs(0.01))
		crackle += rng.uniform(0.2, 1.0) * burst(rng, n, s, rng.uniform(0.0005, 0.002), 3000, 0)
	crackle *= (slow(rng, n, 1.5) > 0.2)
	x = x + 0.25 * crackle
	write("fluorescent_buzz", seam(x, 0.02))


def lobby_room():
	"""Quiet HVAC through a ceiling diffuser, and the vending machine's fridge."""
	rng = np.random.default_rng(404)
	n = secs(8.0)
	air = noise(rng, n, mul(pink, bandpass_gain(60, 900))) * (0.9 + 0.1 * slow(rng, n, 0.3))
	vend = 0.0
	for h, a in [(1, 0.6), (2, 1.0), (3, 0.25), (5, 0.1)]:
		vend = vend + a * tone(n, 59.9 * h, rng.uniform(0, 6.28))
	comp = 0.5 * tone(n, 47.0, 0.0, slow(rng, n, 0.3), 0.3) * (0.8 + 0.2 * slow(rng, n, 0.5))
	whine = 0.04 * tone(n, 7620.0) * (0.5 + 0.5 * slow(rng, n, 0.4))
	x = 0.9 * air + 0.18 * vend + 0.25 * comp + whine
	x = circ_reverb(rng, x, 0.5, 0.3, 2500)
	write("lobby_room", seam(x))


def _voice(rng, n, loud=1.0, rate=4.5, gate_rate=0.35, gate_level=0.0, f0_lo=95, f0_hi=230):
	"""One talker: a buzzy pitched source with drifting formants, syllable gated."""
	t = np.arange(n) / SR
	f0 = snap(rng.uniform(f0_lo, f0_hi), n)
	vib = slow(rng, n, 1.2)
	ph = 2 * np.pi * f0 * t + 2 * np.pi * 0.12 * f0 * np.cumsum(vib - vib.mean()) / SR
	src = np.zeros(n)
	for h in range(1, 18):
		src += np.sin(h * ph) / h
	src = src + 0.35 * rng.standard_normal(n)
	F1, F2 = rng.uniform(350, 750), rng.uniform(1000, 2200)
	v = shape(src, mul(peak_gain(F1, 4, 18), peak_gain(F2, 5, 14), bandpass_gain(150, 3200)))
	syl = np.maximum(0.0, slow(rng, n, rate)) ** 0.8
	gate = np.clip((slow(rng, n, gate_rate) + 0.35 - gate_level) * 3, 0, 1)
	return loud * v / (np.std(v) + 1e-9) * syl * gate


def crowd_murmur():
	"""Many people talking at once across a cold room."""
	rng = np.random.default_rng(505)
	n = secs(8.0)
	x = np.zeros(n)
	for i in range(28):
		x += _voice(rng, n, rng.uniform(0.3, 1.0))
	x += 0.6 * noise(rng, n, mul(pink, bandpass_gain(200, 2500))) * (0.8 + 0.2 * slow(rng, n, 0.5))
	x = shape(x, bandpass_gain(120, 3500))
	x = circ_reverb(rng, x, 1.3, 0.6, 2200)
	write("crowd_murmur", seam(x, 0.1))


def skates_ice():
	"""Skaters going round: long carves, crossovers, the odd hockey stop."""
	rng = np.random.default_rng(606)
	n = secs(8.0)
	x = np.zeros(n)
	t_all = np.arange(n) / SR
	for k in range(5):  # skaters, each striding at their own pace
		period = rng.uniform(0.55, 0.85)
		at = rng.uniform(0, period)
		dist = rng.uniform(0.3, 1.0)
		while at < 8.0:
			dur = period * rng.uniform(0.7, 0.95)
			m = secs(dur)
			s = secs(at)
			tt = np.arange(m) / SR
			env = np.sin(np.pi * tt / dur) ** 1.5 * np.exp(-tt / (dur * 1.5))
			lo = rng.uniform(1500, 2600)
			c = noise(rng, m, mul(bandpass_gain(lo, lo * 3.2), peak_gain(lo * 1.6, 3, 6))) * env * dist
			idx = (np.arange(m) + s) % n  # wrap round the loop
			x[idx] += c * rng.uniform(0.6, 1.0)
			at += period * rng.uniform(0.9, 1.1)
	for at in (2.3, 6.1):  # hockey stops: a hard spray of snow
		m = secs(0.7)
		tt = np.arange(m) / SR
		env = np.minimum(1, tt / 0.04) * np.exp(-tt / 0.18)
		c = noise(rng, m, mul(bandpass_gain(900, 8000), peak_gain(3500, 1.5, 6))) * env * 1.6
		idx = (np.arange(m) + secs(at)) % n
		x[idx] += c
	# puck and stick ticks far off
	for at in (0.9, 3.7, 4.05, 7.2):
		x += 0.6 * modes(n, secs(at), [(1800, 0.015, 1.0), (3300, 0.01, 0.5)], rng, 0.1)
	x += 0.08 * noise(rng, n, bandpass_gain(2000, 7000)) * (0.5 + 0.5 * slow(rng, n, 0.8))
	x = circ_reverb(rng, x, 1.4, 0.5, 3500)
	write("skates_ice", seam(x))


def zamboni_idle():
	"""Doris idling: a propane four-banger, exhaust pulses, a loose panel."""
	rng = np.random.default_rng(707)
	n = secs(6.0)
	t = np.arange(n) / SR
	fire = snap(26.0, n)  # ~780 rpm, four cylinders
	wob = slow(rng, n, 0.5)
	ph = (t * fire + 0.4 * np.cumsum(wob - wob.mean()) / SR) % 1.0
	pulse = np.exp(-ph / 0.18)
	cyc = np.floor(t * fire).astype(int) % 4
	pulse *= np.array([1.0, 0.85, 0.95, 0.8])[cyc]
	exhaust = pulse * noise(rng, n, mul(brown, bandpass_gain(30, 500)))
	tone_ = 0.0
	for h, a in [(1, 1.0), (2, 0.6), (3, 0.3), (4, 0.15)]:
		tone_ = tone_ + a * tone(n, fire * h, rng.uniform(0, 6.28))
	block = noise(rng, n, mul(pink, bandpass_gain(200, 2500))) * 0.3
	rattle = np.zeros(n)
	for i in range(int(6.0 * fire)):
		if rng.random() < 0.35:
			rattle += modes(n, secs(i / fire + 0.004), [(640, 0.01, 1.0), (1530, 0.006, 0.6)], rng, 0.08)
	whine = 0.05 * tone(n, 410.0, 0.0, slow(rng, n, 0.3), 3.0)
	x = 1.0 * exhaust + 0.5 * np.tanh(tone_) + 0.25 * block + 0.15 * rattle + whine
	x = circ_reverb(rng, x, 0.5, 0.3, 3000)
	write("zamboni_idle", seam(x))


# ------------------------------------------------------------------ one-shots

def _step(rng, surface, heavy=False):
	n = secs(0.5)
	x = np.zeros(n)
	g = 1.6 if heavy else 1.0
	heel, toe = secs(0.004), secs(rng.uniform(0.055, 0.09))
	if surface == "rubber":  # soft matting: a dull thud, hardly any click
		x += g * modes(n, heel, [(rng.uniform(85, 120), 0.035, 1.0), (rng.uniform(190, 260), 0.02, 0.4)], rng, 0.05)
		x += g * 0.8 * burst(rng, n, heel, 0.012, 0, 1200)
		x += 0.35 * burst(rng, n, toe, 0.01, 0, 900)
		x += 0.04 * burst(rng, n, toe + secs(0.03), 0.03, 1500, 5000)  # squeak of the sole
		x = reverb(rng, x, 0.25, 0.15, 2000, 0.4)
	elif surface == "concrete":  # gritty heel strike in a block room
		x += g * modes(n, heel, [(rng.uniform(110, 150), 0.025, 0.8), (rng.uniform(600, 900), 0.008, 0.3)], rng, 0.05)
		x += g * 0.9 * burst(rng, n, heel, 0.006, 900, 6000)
		x += g * 0.5 * burst(rng, n, heel, 0.012, 0, 500)
		x += 0.45 * burst(rng, n, toe, 0.008, 1200, 6000)
		x += 0.12 * burst(rng, n, toe + secs(0.01), 0.04, 3000, 8000)  # grit scuff
		x = reverb(rng, x, 0.35, 0.3, 3500, 0.6)
	else:  # tile: a bright click with a little ring
		x += g * modes(n, heel, [(rng.uniform(1700, 2100), 0.01, 0.7), (rng.uniform(2900, 3400), 0.006, 0.4), (rng.uniform(120, 160), 0.02, 0.6)], rng, 0.04)
		x += g * 1.0 * burst(rng, n, heel, 0.004, 1500, 8000)
		x += 0.5 * burst(rng, n, toe, 0.004, 1800, 8000)
		x = reverb(rng, x, 0.4, 0.3, 4500, 0.6)
	return fade_ends(x[:secs(0.55)])


def footsteps():
	for surface, count, seed in [("rubber", 4, 801), ("concrete", 4, 802), ("tile", 3, 803)]:
		rng = np.random.default_rng(seed)
		for i in range(count):
			write("footstep_%s_%d" % (surface, i + 1), _step(rng, surface), 0.8)


def door_creak_open():
	"""A steel door's push bar clacks, then the dry hinge groans as it swings."""
	rng = np.random.default_rng(901)
	n = secs(1.6)
	x = np.zeros(n)
	# push bar: latch retracts with a clack
	x += modes(n, secs(0.01), [(1250, 0.02, 1.0), (2900, 0.012, 0.6), (520, 0.04, 0.5)], rng, 0.03)
	x += 0.8 * burst(rng, n, secs(0.01), 0.004, 1000, 8000)
	# hinge stick-slip: impulses at an irregular, gliding rate
	t = secs(0.18)
	end = secs(1.25)
	exc = np.zeros(n)
	rate_curve = lambda u: 160 + 260 * np.sin(np.pi * u) ** 0.7 + 90 * np.sin(7.3 * u)
	while t < end:
		u = (t - secs(0.18)) / (end - secs(0.18))
		amp = np.sin(np.pi * u) ** 0.5 * (0.6 + 0.4 * rng.random())
		exc[t] += amp
		t += max(1, int(SR / (rate_curve(u) * rng.uniform(0.85, 1.15))))
	creak = biquad_bp(exc, 620, 6) + 0.7 * biquad_bp(exc, 1340, 8) + 0.45 * biquad_bp(exc, 2450, 10) + 0.3 * biquad_bp(exc, 3900, 12)
	x += 0.9 * creak / (np.max(np.abs(creak)) + 1e-9)
	# the leaf's own boom as it moves
	x += 0.2 * burst(rng, n, secs(0.2), 0.4, 0, 180)
	x = reverb(rng, x, 0.3, 0.25, 3500, 0.4)
	write("door_creak_open", fade_ends(x[:n]))


def door_close_latch():
	"""The closer pulls it to: a thud of steel into the frame and the latch clicking home."""
	rng = np.random.default_rng(902)
	n = secs(0.9)
	x = np.zeros(n)
	s = secs(0.02)
	x += modes(n, s, [(72, 0.09, 1.0), (178, 0.06, 0.7), (415, 0.04, 0.45), (960, 0.02, 0.25), (2100, 0.012, 0.15)], rng, 0.02)
	x += 0.9 * burst(rng, n, s, 0.015, 0, 600)
	x += 0.4 * burst(rng, n, s, 0.004, 1500, 8000)
	l = s + secs(0.045)
	x += 0.55 * modes(n, l, [(2600, 0.008, 1.0), (4300, 0.005, 0.6), (1450, 0.012, 0.5)], rng, 0.03)
	x += 0.3 * burst(rng, n, l, 0.002, 2000, 9000)
	x += 0.15 * modes(n, l + secs(0.06), [(2650, 0.006, 1.0), (1500, 0.01, 0.4)], rng, 0.03)  # rattle
	x = reverb(rng, x, 0.35, 0.3, 3000, 0.5)
	write("door_close_latch", fade_ends(x[:n]))


def breaker_clunk():
	"""Throwing a big old breaker: a hard mechanical clunk in a steel box."""
	rng = np.random.default_rng(903)
	n = secs(0.7)
	x = np.zeros(n)
	x += 0.5 * burst(rng, n, secs(0.005), 0.01, 800, 5000)  # the handle starts to move
	s = secs(0.04)
	x += modes(n, s, [(310, 0.07, 1.0), (520, 0.05, 0.8), (870, 0.04, 0.6), (1650, 0.02, 0.4), (3100, 0.01, 0.3)], rng, 0.03)
	x += burst(rng, n, s, 0.004, 1500, 9000)
	x += 0.8 * burst(rng, n, s, 0.02, 0, 300)
	x = reverb(rng, x, 0.3, 0.25, 3000, 0.4)
	write("breaker_clunk", fade_ends(x[:n]))


def lamp_strike():
	"""A metal-halide lamp striking: a crack, then a ragged ballast buzz settling down."""
	rng = np.random.default_rng(904)
	n = secs(2.6)
	t = np.arange(n) / SR
	x = np.zeros(n)
	x += 1.2 * burst(rng, n, secs(0.02), 0.006, 600, 9000)  # the arc strikes
	x += 0.5 * burst(rng, n, secs(0.11), 0.004, 1000, 9000)  # and re-strikes
	buzz = 0.0
	for h, a in [(1, 0.3), (2, 1.0), (3, 0.4), (4, 0.6), (5, 0.2), (6, 0.35), (8, 0.2), (10, 0.12), (12, 0.08)]:
		buzz = buzz + a * np.sin(2 * np.pi * 60.0 * h * t + rng.uniform(0, 6.28))
	flutter = 0.7 + 0.3 * np.sin(2 * np.pi * (9 + 4 * t) * t) * np.exp(-t / 0.8)
	env = np.minimum(1, np.maximum(0, t - 0.02) / 0.05) * (0.25 + 0.75 * np.exp(-np.maximum(0, t - 0.1) / 0.7))
	b = np.tanh(2.5 * buzz) * flutter * env
	b[: secs(0.02)] = 0
	whine = 0.06 * np.sin(2 * np.pi * np.cumsum(2400 + 600 * (1 - np.exp(-t / 0.6))) / SR) * env
	x += 0.55 * b + whine
	x = reverb(rng, x, 0.8, 0.35, 3000, 1.2)
	write("lamp_strike", fade_ends(x[:n], r=0.25))


def crowd_cheer():
	"""A goal: the house comes up roaring, claps, whistles, then settles."""
	rng = np.random.default_rng(905)
	n = secs(3.8)
	t = np.arange(n) / SR
	x = np.zeros(n)
	for i in range(26):
		v = _voice(rng, n, rng.uniform(0.4, 1.0), rate=3.0, gate_rate=0.6, gate_level=-0.6, f0_lo=150, f0_hi=330)
		x += v
	env = np.minimum(1, t / 0.35) ** 1.5 * np.exp(-np.maximum(0, t - 1.0) / 1.0)
	x = x * env
	x += 0.8 * noise(rng, n, mul(pink, bandpass_gain(250, 4000))) * env
	claps = np.zeros(n)
	for _ in range(160):
		at = rng.uniform(0.25, 3.3)
		if rng.random() < np.exp(-max(0, at - 1.2) / 1.0):
			claps += rng.uniform(0.3, 1.0) * burst(rng, n, secs(at), 0.006, 900, 4500)
	x += 1.2 * claps / (np.max(np.abs(claps)) + 1e-9) * np.std(x) * 6
	whistle = 0.12 * np.sin(2 * np.pi * np.cumsum(2700 + 300 * np.sin(2 * np.pi * 1.5 * t)) / SR)
	whistle *= np.clip((t - 0.5) / 0.1, 0, 1) * np.clip((1.6 - t) / 0.1, 0, 1)
	x += whistle * np.std(x) * 4
	x = reverb(rng, x, 1.3, 0.55, 2500, 2.0)
	write("crowd_cheer", fade_ends(x, r=0.3))


ALL = {
	"arena_room": arena_room, "plant_room": plant_room, "fluorescent_buzz": fluorescent_buzz,
	"lobby_room": lobby_room, "crowd_murmur": crowd_murmur, "crowd_cheer": crowd_cheer,
	"skates_ice": skates_ice, "zamboni_idle": zamboni_idle, "footsteps": footsteps,
	"door_creak_open": door_creak_open, "door_close_latch": door_close_latch,
	"breaker_clunk": breaker_clunk, "lamp_strike": lamp_strike,
}

if __name__ == "__main__":
	os.makedirs(OUT, exist_ok=True)
	names = sys.argv[1:] or list(ALL)
	for nm in names:
		ALL[nm]()
