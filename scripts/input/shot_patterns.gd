class_name ShotPatterns
extends RefCounted
## The traced shots: holding right click turns the mouse into a pen, and the
## pattern drawn picks the shot. Templates are Sean's sketches (19 Oct), in
## screen pixels with y up the screen (toward the net) and the start at the
## origin; each ends in the long forward stroke that releases the puck.
##
##   wrist shot   a short pull back to the forehand, then straight forward
##   snap shot    across, a short drop, then straight forward
##   slap shot    across, a long drop (the backswing), then all the way forward
##   toe drag     pull it in and across, back and forth, then forward
##
## match(trace) compares the drawn path with every template, size and
## position aside, and grades how close the best one is (0..1), how fast its
## forward stroke went and whether it reads as a shot at all.

const KINDS: Array[StringName] = [&"wrist_shot", &"snap_shot", &"slapshot", &"toe_drag_shot"]
const NAMES := {&"wrist_shot": "WRIST SHOT", &"snap_shot": "SNAP SHOT", &"slapshot": "SLAP SHOT", &"toe_drag_shot": "TOE DRAG SHOT"}

## Points in px, y up, from Sean's sketch (the slap shot's backswing drawn a
## little deeper than sketched, so it reads apart from the snap shot).
const TEMPLATES := {
	&"wrist_shot": [Vector2(0, 0), Vector2(30, -47), Vector2(15, 103)],
	&"snap_shot": [Vector2(0, 0), Vector2(55, 0), Vector2(80, -59), Vector2(55, 158)],
	&"slapshot": [Vector2(0, 0), Vector2(67, 4), Vector2(70, -130), Vector2(70, 172), Vector2(65, 222)],
	&"toe_drag_shot": [Vector2(0, 0), Vector2(-22, -16), Vector2(-7, -83), Vector2(11, -86), Vector2(11, -23), Vector2(33, -88), Vector2(33, 202)],
}

const SAMPLES := 48
## A path shorter than this (px) is a click, not a shot.
const MIN_LENGTH := 60.0
## Mean distance (as a share of the path's length) where the match reaches 0.
const MISS_AT := 0.16
## The accuracy skill widens that window up to this much.
const SKILL_WIDEN := 1.8

static var _cache := {}


## `trace` is Array of Vector3(x px, y px up, t seconds). `accuracy` is the
## shot accuracy skill 0..1. Returns {kind, match 0..1, speed px/s of the
## forward stroke, length px, ok}. ok is false for a click or a path too
## short to be any shot.
static func match(trace: Array, accuracy := 0.5) -> Dictionary:
	var pts := PackedVector2Array()
	for p in trace:
		pts.append(Vector2(p.x, p.y))
	var length := _length(pts)
	var out := {"kind": &"wrist_shot", "match": 0.0, "speed": 0.0, "length": length, "ok": false, "error": 1.0}
	if trace.size() < 3 or length < MIN_LENGTH:
		return out
	var drawn := _normalize(_resample(pts, SAMPLES))
	var best := INF
	for kind in KINDS:
		var d := _distance(drawn, template(kind))
		if d < best:
			best = d
			out.kind = kind
	var window := MISS_AT * lerpf(1.0, SKILL_WIDEN, clampf(accuracy, 0.0, 1.0))
	out.error = best
	out.match = clampf(1.0 - best / window, 0.0, 1.0)
	out.speed = forward_speed(trace)
	out.ok = true
	return out


## The template for `kind`, resampled and normalized like a drawn path.
static func template(kind: StringName) -> PackedVector2Array:
	if not _cache.has(kind):
		var raw := PackedVector2Array()
		for p in TEMPLATES[kind]:
			raw.append(p)
		_cache[kind] = _normalize(_resample(raw, SAMPLES))
	return _cache[kind]


## The template's points in px at its sketch size (for the overlay).
static func outline(kind: StringName) -> PackedVector2Array:
	var raw := PackedVector2Array()
	for p in TEMPLATES[kind]:
		raw.append(p)
	return raw


## Speed (px/s) of the final forward stroke: from the lowest point after the
## last turn upward to the end.
static func forward_speed(trace: Array) -> float:
	var n := trace.size()
	if n < 2:
		return 0.0
	var low := n - 1
	for i in range(n - 1, -1, -1):
		if trace[i].y <= trace[low].y:
			low = i
		elif trace[i].y > trace[low].y + 12.0:
			break   # rising again before the stroke: that's an earlier part of the pattern
	var dy: float = trace[n - 1].y - trace[low].y
	var dt: float = trace[n - 1].z - trace[low].z
	if dy <= 0.0:
		return 0.0
	return dy / maxf(dt, 1.0 / 120.0)


static func _length(pts: PackedVector2Array) -> float:
	var l := 0.0
	for i in range(1, pts.size()):
		l += pts[i].distance_to(pts[i - 1])
	return l


## Evenly spaced along the path's length.
static func _resample(pts: PackedVector2Array, n: int) -> PackedVector2Array:
	var total := _length(pts)
	var out := PackedVector2Array([pts[0]])
	if total <= 0.0:
		for i in n - 1:
			out.append(pts[0])
		return out
	var step := total / (n - 1)
	var acc := 0.0
	var i := 1
	var prev := pts[0]
	while i < pts.size() and out.size() < n:
		var seg := prev.distance_to(pts[i])
		if acc + seg >= step and seg > 0.0:
			var q := prev.lerp(pts[i], (step - acc) / seg)
			out.append(q)
			prev = q
			acc = 0.0
		else:
			acc += seg
			prev = pts[i]
			i += 1
	while out.size() < n:
		out.append(pts[pts.size() - 1])
	return out


## Start at the origin, length 1: size and position don't matter, shape and
## direction do (a pattern drawn sideways isn't the same shot).
static func _normalize(pts: PackedVector2Array) -> PackedVector2Array:
	var l := maxf(_length(pts), 0.001)
	var o := pts[0]
	var out := PackedVector2Array()
	for p in pts:
		out.append((p - o) / l)
	return out


static func _distance(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var d := 0.0
	for i in a.size():
		d += a[i].distance_to(b[i])
	return d / a.size()
