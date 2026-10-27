class_name RinkDoor
extends VenueDoor
## A door cut into the rink boards over one of the walker's gates
## (Shell.GATES): a section of the boards themselves on hinges, so when it is
## shut it is the boards, flush on the ice side with no lip or gap.
##
##   BENCH    a swinging board section with no glass over it (the four
##            player-bench gates, on the line-change spots)
##   RINK     the same board section with a pane of the rink glass on top
##            (the penalty boxes, the two wide doors on the far side)
##   ZAMBONI  a wide double door, boards below and glass above, in the +X
##            end boards in front of the resurfacer bay's rink door; it
##            folds right back against the boards and opens by itself as
##            Doris drives up to it (watch_doris)
##
## The origin is the bottom centre of the opening on the board line (the ice
## face); local +X runs along the boards and local +Z points away from the
## ice, the way the leaves swing. A leaf is the board profile (kick plate,
## board, cap: as Rink draws it) THICK deep. The single doors swing 95 deg
## on a hinge line set back behind the jamb (POST_HINGE), so the open leaf
## stands clear of the whole opening, beside it; the Zamboni door's leaves
## hinge at their walkway corners and fold right back flat against the
## boards either side. The leaves carry only their
## colliders here; RinkDoors draws every leaf of every rink door as one
## skinned mesh (and one for the glass), so nine doors cost two draws.
##
## In a match the doors stay shut and are only something to look at: the
## puck is kept in by Rink.confine, which knows nothing about them.

enum Style { BENCH, RINK, ZAMBONI }

const Benches := preload("res://scripts/venue/rooms/benches.gd")

## The board profile Rink._build_boards draws: [y0, y1, depth from the ice].
const PROFILE := [[0.0, 0.2, 0.2], [0.2, Rink.BOARD_H - 0.08, 0.18], [Rink.BOARD_H - 0.08, Rink.BOARD_H + 0.04, 0.32]]
const THICK := 0.32       # the cap, the deepest part of the profile
const HINGE_Z := 0.33     # the Zamboni door's hinge line, just behind the cap
## The single doors' hinge line: along the boards behind the jamb, and
## halfway through them.
const POST_HINGE := Vector2(0.18, 0.17)
const SEAM := 0.004       # each side of a leaf, so it never rubs the boards

var style := Style.BENCH
## Which boards: "z-" (bench side), "z+" (far side) or "x+" (resurfacer end).
var wall := "z-"
## The opening along the wall, world (venue) metres: [from, to].
var span := Vector2.ZERO
## Glass over the boards on the leaf, metres (0: none).
var glass_h := 0.0
## Single leaves: true when the hinge is at local -X.
var hinge_left := true
## Opens as Doris comes up to it and shuts once she's through (ZAMBONI).
var watch_doris := false

var _watch_t := 0.0
var _doris_last := {}
var _doris_opened := false


## The door over Shell.GATES entry `gate` ([wall, from, to]).
static func for_gate(gate: Array) -> RinkDoor:
	var d := RinkDoor.new()
	d.wall = gate[0]
	d.span = Vector2(gate[1], gate[2])
	d.width = snappedf(d.span.y - d.span.x, 0.001)
	var mid := (d.span.x + d.span.y) * 0.5
	var p := Vector2(mid, -Rink.HALF_W)
	var n := Vector2(0, -1)
	match d.wall:
		"z-":
			d.style = Style.BENCH
			d.position = Vector3(mid, 0, -Rink.HALF_W)
			d.rotation.y = PI
		"z+":
			d.style = Style.RINK
			d.position = Vector3(mid, 0, Rink.HALF_W)
			p = Vector2(mid, Rink.HALF_W)
			n = Vector2(0, 1)
		"x+":
			d.style = Style.ZAMBONI
			d.kind = VenueDoor.Kind.DOUBLE
			d.position = Vector3(Rink.HALF_L, 0, mid)
			d.rotation.y = PI * 0.5
			p = Vector2(Rink.HALF_L, mid)
			n = Vector2(1, 0)
	d.glass_h = 0.0 if d.style == Style.BENCH else VenuePhysics.glass_height(p, n)
	d.height = VenuePhysics.board_top() + d.glass_h
	if d.style == Style.ZAMBONI:
		# folds flat back against the boards, clear of the walkway
		d.swing = PI
		d.swing_time = 1.4
		d.watch_doris = true
		d.label = "Zamboni door"
	elif d.style == Style.BENCH:
		# hinged on the line-change side, away from the bench's end wall
		# (it stands right at the other edge), opening into the bench
		var bench := -1 if mid < 0.0 else 1
		var ends: Array = Benches.BENCHES[0] + Benches.BENCHES[1]
		var hinge_x := d.span.x if _nearest(ends, d.span.x) > _nearest(ends, d.span.y) else d.span.y
		d.hinge_left = d.to_local_x(hinge_x) < 0.0
		var centre := absf(absf(mid) - 3.05) < 0.5
		d.label = "Ice gate %s %s" % ["home" if bench < 0 else "away", "centre" if centre else "far"]
	else:
		# hinged on the centre-ice side: tucks against the timekeeper's wall
		# in the boxes, swings out of the way along the far walkway
		var hinge_x: float = d.span.x if absf(d.span.x) < absf(d.span.y) else d.span.y
		d.hinge_left = d.to_local_x(hinge_x) < 0.0
		var box := absf(mid) < VenuePhysics.BOX_HALF
		d.label = "%s %s" % ["Penalty box" if box else "Rink door", ("home" if mid < 0.0 else "away") if box else ("west" if mid < 0.0 else "east")]
	d.name = d.label.replace(" ", "_")
	return d


static func _nearest(xs: Array, x: float) -> float:
	var best := INF
	for v: float in xs:
		best = minf(best, absf(v - x))
	return best


## World coordinate along the wall -> local x of this door.
func to_local_x(along: float) -> float:
	var mid := (span.x + span.y) * 0.5
	# the bench side and the end boards face the other way round
	return along - mid if wall == "z+" else mid - along


## Each leaf, closed, in door space: [hinge edge x, leaf width, dir, pivot]
## (dir 1: extends toward +X from the hinge edge; -1 toward -X; pivot is
## the hinge line).
func leaf_specs() -> Array:
	var w := width
	if kind == VenueDoor.Kind.DOUBLE:
		return [[-w * 0.5, w * 0.5, 1.0, Vector3(-w * 0.5, 0, HINGE_Z)], [w * 0.5, w * 0.5, -1.0, Vector3(w * 0.5, 0, HINGE_Z)]]
	var hx := -w * 0.5 if hinge_left else w * 0.5
	var dir := 1.0 if hinge_left else -1.0
	return [[hx, w, dir, Vector3(hx - dir * POST_HINGE.x, 0, POST_HINGE.y)]]


## The leaf's local x range (door space, closed), seams taken off.
static func leaf_range(spec: Array) -> Vector2:
	var hx: float = spec[0]
	var w: float = spec[1]
	var dir: float = spec[2]
	var x0 := hx if dir > 0.0 else hx - w
	return Vector2(x0 + SEAM, x0 + w - SEAM)


func _ready() -> void:
	# hinges and colliders only: the leaves are drawn by RinkDoors' rig
	for spec in leaf_specs():
		var pivot := Node3D.new()
		pivot.position = spec[3]
		add_child(pivot)
		leaves.append(pivot)
		pivot.set_meta("dir", spec[2])
		var r := leaf_range(spec)
		var body := AnimatableBody3D.new()
		body.sync_to_physics = false
		body.collision_layer = 1 << (VenueKit.VENUE_LAYER - 1)
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(r.y - r.x, height, THICK)
		cs.shape = shape
		cs.position = Vector3((r.x + r.y) * 0.5, height * 0.5, THICK * 0.5) - pivot.position
		body.add_child(cs)
		pivot.add_child(body)
	set_process(watch_doris)


## Where a walker stands to use it: on the walkway side, or on the ice when
## that's nearer (it opens from both sides).
func use_point() -> Vector3:
	return global_transform * Vector3(0, 0, 0.9)


# ---------------------------------------------------------------- Doris

## The Zamboni door watches for Doris (any DorisModel in the tree, the one
## DorisDrive drives or a parked one): it opens while she drives toward the
## opening or has any part of her in it, and shuts once she's clear of it.
## A parked Doris never opens it, and it never shuts a door someone else
## opened.
func _process(dt: float) -> void:
	_watch_t += dt
	if _watch_t < 0.1 or not is_inside_tree():
		return
	_watch_t = 0.0
	var need := false
	var stay := false
	var inv := global_transform.affine_inverse()
	for n in get_tree().get_nodes_in_group("doris_model"):
		var dm := n as Node3D
		if dm == null or not dm.is_visible_in_tree():
			continue
		var s := doris_state(inv * dm.global_transform, _doris_last.get(dm.get_instance_id(), Vector3.INF))
		_doris_last[dm.get_instance_id()] = s.at
		need = need or s.need
		stay = stay or s.stay
	if need and not is_open:
		open()
		_doris_opened = true
	elif _doris_opened and is_open and not stay and not need:
		close()
		_doris_opened = false
	elif not is_open:
		_doris_opened = false


## What Doris at `xf` (her model transform in door space; front faces -Z,
## origin her pivot) asks of the door, given where she was a tick ago:
## {at, need (open it), stay (keep it open)}.
func doris_state(xf: Transform3D, last: Vector3) -> Dictionary:
	var at := xf.origin
	var half := width * 0.5
	var front := ResurfaceRun.BODY_FRONT - DorisModel.AXLE_Z
	var rear := ResurfaceRun.BODY_REAR + DorisModel.AXLE_Z
	var hw := ResurfaceRun.BODY_HALF_W
	var straddle := false
	for c: Vector3 in [Vector3(hw, 0, -front), Vector3(-hw, 0, -front), Vector3(hw, 0, rear), Vector3(-hw, 0, rear), Vector3(0, 0, -front), Vector3(0, 0, rear)]:
		var q := xf * c
		if q.z > 0.0 and q.z < THICK + 0.6 and absf(q.x) < half + 0.3:
			straddle = true
	var toward := false
	if last != Vector3.INF:
		var moved := Vector3(at.x - last.x, 0, at.z - last.z)
		var to_line := Vector3(0, 0, -signf(at.z) if absf(at.z) > 0.01 else 0.0)
		toward = moved.length() > 0.01 and moved.normalized().dot(to_line) > cos(deg_to_rad(25.0)) \
			and absf(at.x) < half - 1.0 and absf(at.z) < 4.5
	var zone := absf(at.x) < half + 2.0 and absf(at.z) < 6.0
	return {"at": at, "need": straddle or toward, "stay": straddle or zone}
