class_name Moves
extends RefCounted
## Shots and stick moves a skater can know. Each one is a pattern traced with
## the right stick (mouse), in the skater's own frame: 0 deg is straight ahead,
## + is the forehand side, - the backhand, and the blade reaches 110 deg either
## way (a 220 degree arc). Starters are known from the first game; the rest are
## unlocked through progression. A locked move's pattern falls back to the
## nearest starter (a slapshot pattern without the slapshot is a wrist shot).
##
##   QUICK      flick forward from neutral                         instant, weak
##   WRIST      draw back behind the forehand hip, sweep forward     the default
##   BACKHAND   draw back behind the backhand hip, sweep forward     weaker, wilder
##   SNAP       hold out wide on the forehand (60 deg+), snap forward  quick and hard
##   SLAP       hold LT and draw back on the forehand, then forward  hardest, slow
##   ONE_TIMER  slapshot wind-up with no puck, fire as the pass lands
##   TOE_DRAG   hold RT, stick out front, pull back across to the backhand
##   LACROSSE   hold RT, sweep from the backhand round to the forehand: the
##              puck rides up on the blade behind the hip (keep RT held to
##              cradle it); push forward to throw it at the net

enum { NONE = -1, QUICK, WRIST, BACKHAND, SNAP, SLAP, ONE_TIMER, TOE_DRAG, LACROSSE }

const NAMES := {
	QUICK: "Quick shot", WRIST: "Wrist shot", BACKHAND: "Backhand", SNAP: "Snapshot",
	SLAP: "Slapshot", ONE_TIMER: "One-timer", TOE_DRAG: "Toe drag", LACROSSE: "Lacrosse",
}
const STARTER := [QUICK, WRIST, BACKHAND]
const ALL := [QUICK, WRIST, BACKHAND, SNAP, SLAP, ONE_TIMER, TOE_DRAG, LACROSSE]


static func starter() -> Dictionary:
	return _id_set(STARTER)


static func all() -> Dictionary:
	return _id_set(ALL)


static func _id_set(ids: Array) -> Dictionary:
	var d := {}
	for id in ids:
		d[id] = true
	return d
