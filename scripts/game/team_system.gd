class_name TeamSystem
extends RefCounted
## Positional hockey: where each position (C, LW, RW, LD, RD) belongs in
## each phase of play, the way a coached team plays it. SkaterAI asks for a
## skater's spot and duty; how tightly they keep to it is the tier's
## discipline, how soon they see the phase change its anticipation.
##
## Spots are worked out in the team's attack frame: u runs along the ice
## toward the net being attacked (own goal line at -GOAL_X, theirs at
## +GOAL_X), v across it, negative on the left of a skater facing up ice.
## "Strong side" is the puck's side.
##
## Phases (from who has the puck and where):
##   OFFENCE     our puck in their zone: D on the points (D-to-D), strong-side
##               winger on the wall, weak-side winger at the net front, C in
##               the high slot as the safety.
##   ATTACK      our puck in the neutral zone: wingers in the wide lanes, C
##               through the middle, D trailing.
##   BREAKOUT    our puck in our zone: a D retrieves, the partner supports
##               behind and across, wingers on the boards at the hash marks,
##               C swinging low through the middle.
##   FORECHECK   their puck in their zone, 1-2-2: F1 pressures, F2 takes the
##               wall, F3 high in the middle, D hold the blue line (the
##               strong-side D pinches only when it's safe).
##   GAP         their puck in the neutral zone: D back off in front of the
##               carrier keeping a gap, forwards back-check to their lanes.
##   DZONE       their puck in our zone, box +1: strong-side D in the
##               corner, weak-side D at the net front, wingers on the points
##               (the strong-side one at the half-wall), C low in support.
## A loose puck plays as the phase of the team that last had it under control.

enum Phase { OFFENCE, ATTACK, BREAKOUT, FORECHECK, GAP, DZONE }
const PHASE_NAMES := ["offence", "attack", "breakout", "forecheck", "gap", "dzone"]
const ROLES := ["C", "LW", "RW", "LD", "RD"]

const GU := Rink.GOAL_X
const BU := Rink.BLUE_X
const WALL := Rink.HALF_W - 1.6     # v of a player working the boards
const POINT_V := 6.5
## Disciplined teams rotate to cover for a teammate caught out of position
## (one of the two is this far from their own spot), when swapping spots
## saves at least ROTATE_GAIN metres of skating between them (e.g. the C
## into a pinching D's spot).
const CAUGHT := 12.0
const SWITCH_V := 2.5         # m off the middle before the strong side switches
## The system follows the play, not the puck: a clear or a long pass flies
## faster than anyone skates, so the spots move with a focus that chases the
## puck at skating speed.
const FOCUS_SPEED := 9.0
const ROTATE_GAIN := 10.0


## A skater's position from their bench slot (Bench.SLOTS order). Teams on
## the ice in slot order, so line changes carry it over.
static func role_of(s: Skater, g: Node) -> String:
	var i: int = g.team_skaters(s.team).find(s)
	return Bench.SLOTS[maxi(i, 0) % Bench.SLOTS.size()]


static func is_d(role: String) -> bool:
	return role == "LD" or role == "RD"


## -1 for a left-side player, +1 for a right-side one, 0 for the C.
static func lane(role: String) -> float:
	if role == "LW" or role == "LD":
		return -1.0
	if role == "RW" or role == "RD":
		return 1.0
	return 0.0


## The phase `team` is in. `holder_team` is who has (or last had) the puck,
## -1 if nobody yet.
static func phase(team: int, holder_team: int, puck_u: float) -> Phase:
	var ours := holder_team == team or holder_team < 0
	if puck_u > BU:
		return Phase.OFFENCE if ours else Phase.FORECHECK
	if puck_u < -BU:
		return Phase.BREAKOUT if ours else Phase.DZONE
	return Phase.ATTACK if ours else Phase.GAP


## Whether `ph` is one of the phases with the puck.
static func ours(ph: int) -> bool:
	return ph == Phase.OFFENCE or ph == Phase.ATTACK or ph == Phase.BREAKOUT


## World <-> attack frame for `team`.
static func to_frame(g: Node, team: int, p: Vector2) -> Vector2:
	var att: int = g.attack_side(team)
	return Vector2(p.x * att, p.y * att)


static func to_world(g: Node, team: int, f: Vector2) -> Vector2:
	var att: int = g.attack_side(team)
	return Vector2(f.x * att, f.y * att)


## Where `role` belongs in phase `ph` with the puck at `p` (attack frame).
## `carrier_role` is our carrier's position (if we have it), so the others
## fill around them. `ss` is the strong side (+1/-1), from strong_side().
static func spot(role: String, ph: Phase, p: Vector2, carrier_role := "", ss := 0.0) -> Vector2:
	if ss == 0.0:
		ss = signf(p.y) if absf(p.y) > 0.8 else 1.0
	var side := lane(role)
	var strong := side == ss
	var f := Vector2.ZERO
	match ph:
		Phase.OFFENCE:
			if is_d(role):
				# the points, sliding across with the puck
				f = Vector2(BU + 1.6, side * POINT_V + p.y * 0.15)
			elif role == "C":
				f = Vector2(GU - 9.5, ss * 1.5)  # high slot, the safety
			elif strong:
				# on the wall, a few metres off the puck to take a pass
				f = Vector2(clampf(p.x - 3.0, BU + 4.0, GU - 3.0), ss * WALL)
			else:
				f = Vector2(GU - 2.4, -ss * 1.2)  # net front / back door
			if carrier_role == "C" and role != "C" and not is_d(role):
				# the C has it low: a winger fills the high slot
				if not strong:
					f = Vector2(GU - 9.5, -ss * 1.5)
		Phase.ATTACK:
			if is_d(role):
				f = Vector2(p.x - 7.0, side * 4.0)
			elif role == "C":
				f = Vector2(p.x + 2.0, p.y * 0.3)
			else:
				f = Vector2(p.x + 3.0, side * (WALL - 1.5))
		Phase.BREAKOUT:
			if is_d(role):
				if strong:
					f = Vector2(minf(p.x, -GU + 3.0), ss * 4.0)  # retrieving
				else:
					f = Vector2(-GU + 1.5, -ss * 3.0)  # support behind and across
			elif role == "C":
				f = Vector2(-GU + 9.0, -ss * 2.0)  # swing low through the middle
			else:
				# boards at the hash marks; the weak side a little higher
				f = Vector2(-Rink.DOT_X + (0.0 if strong else 3.0), side * WALL)
		Phase.FORECHECK:
			if is_d(role):
				f = Vector2(BU + 1.2, side * POINT_V)
			elif role == "C":
				f = Vector2(BU + 4.0, p.y * 0.3)  # F3 high in the middle
			elif strong:
				f = Vector2(clampf(p.x - 3.0, BU + 3.0, GU - 4.0), ss * (WALL - 0.5))  # F2 the wall
			else:
				f = Vector2(clampf(p.x - 6.0, BU + 3.0, GU - 8.0), -ss * 3.0)
		Phase.GAP:
			if is_d(role):
				f = Vector2(maxf(p.x - 6.0, -GU + 8.0), side * 3.5 + p.y * 0.3)
			elif role == "C":
				f = Vector2(p.x - 2.5, p.y * 0.4)
			else:
				f = Vector2(p.x - 2.0, side * (WALL - 2.0))  # back-check the lane
		Phase.DZONE:
			if is_d(role):
				if strong:
					# strong-side corner, between the puck and the net
					f = Vector2(maxf(p.x, -GU + 1.0), ss * minf(absf(p.y), 7.0)).lerp(Vector2(-GU + 3.0, ss * 2.0), 0.35)
				else:
					f = Vector2(-GU + 2.2, -ss * 0.8)  # net front
			elif role == "C":
				f = Vector2(-GU + 5.0, ss * 2.0)  # low support, the slot
			elif strong:
				f = Vector2(-BU - 4.0, ss * (WALL - 1.0))  # half-wall
			else:
				f = Vector2(-BU - 1.6, -ss * POINT_V)  # weak point
	f.x = clampf(f.x, -GU + 1.0, GU - 1.0)
	f.y = clampf(f.y, -WALL, WALL)
	return f


static var _focus := {}  # team -> [time, frame position]

## Where the play is for `team` (attack frame), following the puck at
## skating speed. Snaps to it after a faceoff or a restart.
static func focus(g: Node, team: int) -> Vector2:
	var p := to_frame(g, team, Vector2(g.puck.position.x, g.puck.position.z))
	var f: Array = _focus.get(team, [-1.0, p])
	var dt: float = g.time - f[0]
	if dt < 0.0 or dt > 0.5:
		f = [g.time, p]
	elif dt > 0.0:
		f = [g.time, (f[1] as Vector2).move_toward(p, FOCUS_SPEED * dt)]
	_focus[team] = f
	return f[1]


## The puck's side of the ice for `team` (attack frame), which only switches
## once the puck is clearly across, so a puck wobbling through the middle
## doesn't send the wingers back and forth between the wall and the net.
static var _ss := {}

static func strong_side(team: int, p: Vector2) -> float:
	var ss: float = _ss.get(team, 1.0)
	if absf(p.y) > SWITCH_V:
		ss = signf(p.y)
	_ss[team] = ss
	return ss


## The defending player who goes at the puck in phase `ph` (F1): the nearest
## forward up ice, in our zone the nearest of the strong-side D and the C.
static func presser(g: Node, team: int, ph: Phase, p: Vector2) -> Skater:
	var best: Skater = null
	var best_d := INF
	var pw := to_world(g, team, p)
	var ss := strong_side(team, p)
	for s: Skater in g.team_skaters(team):
		if s.changing or s.stick_broken:
			continue
		var r := role_of(s, g)
		var ok := not is_d(r)
		if ph == Phase.DZONE:
			ok = r == "C" or (is_d(r) and lane(r) == ss)
		if not ok:
			continue
		var d := Vector2(s.position.x, s.position.z).distance_to(pw)
		if d < best_d:
			best_d = d
			best = s
	return best


## Everyone's spot for `team` this phase (world space), with disciplined
## teams rotating spots between players when that saves enough skating.
## The human keeps their own role; nobody swaps with them. Cached per frame.
static var _cache := {}

static func assignments(g: Node, team: int, ph: Phase, p: Vector2, carrier: Skater, discipline: float) -> Dictionary:
	var key := "%d/%d/%.3f" % [team, ph, g.time]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 32:
		_cache.clear()
	var team_s: Array = g.team_skaters(team)
	var carrier_role := role_of(carrier, g) if carrier != null and carrier.team == team else ""
	var out := {}
	var ss := strong_side(team, p)
	for s: Skater in team_s:
		out[s] = to_world(g, team, spot(role_of(s, g), ph, p, carrier_role, ss))
	if discipline > 0.5:
		# fill for a teammate who's caught out: swap two spots when it saves
		# a lot of skating (never the human's, never the carrier's)
		for a: Skater in team_s:
			for b: Skater in team_s:
				if a == b or a == g.human or b == g.human or a == carrier or b == carrier:
					continue
				var pa := Vector2(a.position.x, a.position.z)
				var pb := Vector2(b.position.x, b.position.z)
				var da: float = pa.distance_to(out[a])
				var db: float = pb.distance_to(out[b])
				if maxf(da, db) < CAUGHT:
					continue
				var swap: float = pa.distance_to(out[b]) + pb.distance_to(out[a])
				if da + db - swap > ROTATE_GAIN * lerpf(1.6, 1.0, discipline):
					var t: Vector2 = out[a]
					out[a] = out[b]
					out[b] = t
	_cache[key] = out
	return out
