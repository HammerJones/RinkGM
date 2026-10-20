class_name MovePhysics
extends RefCounted
## How each learned shot and stick move plays out on the ice. Controls owns
## the catalog (Moves, scripts/core/moves.gd) and the patterns that trigger
## them (StickGestures sets `Skater.Controls.move_id`); mechanics decides who
## knows which (`Skater.knows`). This file owns what happens once one
## starts: the blade's path around the body, how high it lifts, and how hard
## and accurate each kind of shot is.
##
## Paths are keyframes [time s, angle deg, reach m, blade height m], starting
## from wherever the blade was. Angle 0 is straight ahead, + is the forehand
## side, and past +-45 degrees the skater is down to one hand. The blade still
## moves under the skater's own speed and grip limits, so a weak stickhandler
## runs the path slower and can lose the puck on it. Times are for a 50
## stickhandler; better hands run it faster.
##
## A `shot` fires at `release` seconds into the path, as strong as a wrist
## shot of `wind`, times `power`, with `error` times its aim error and a
## face angle in `loft_deg`.
## `glue` keeps the puck on the blade for the whole move (it can't be carried
## up in the air by friction alone). `cradle` holds the end of the path until
## the stick is pushed forward to throw it (`wind` sets the throw like a wrist
## shot of that wind-up) or `hold` seconds pass.

const MOVES := {
	# pulled out to the side and snapped forward: almost no wind-up, but much
	# better than a flick
	&"snap_shot": {
		"needs_puck": true,
		"path": [[0.08, -5.0, 1.35, 0.0]],
		"shot": {"release": 0.06, "wind": 0.35, "power": 1.0, "error": 1.0, "loft_deg": 8.0},
	},
	# the same off the backhand: weaker and wilder, but it gets up
	&"backhand_shot": {
		"needs_puck": true,
		"path": [[0.1, 10.0, 1.3, 0.0]],
		"shot": {"release": 0.08, "wind": 0.4, "power": 0.72, "error": 1.4, "loft_deg": 11.0},
	},
	# forehand to backhand and back, puck on the blade the whole way
	&"quick_deke": {
		"needs_puck": true,
		"path": [[0.2, -40.0, 1.05, 0.0], [0.42, 40.0, 1.05, 0.0], [0.52, 20.0, 1.0, 0.0]],
	},
	# lift the blade over the puck, set the toe down on its forehand side and
	# drag it back in across the body to the backhand
	&"toe_drag": {
		"needs_puck": true,
		"path": [[0.06, 8.0, 1.4, 0.2], [0.13, 12.0, 1.35, 0.2], [0.17, 8.0, 1.35, 0.0], [0.45, -40.0, 0.75, 0.0]],
	},
	# toe drag that ends in a quick release from the new angle
	&"toe_drag_shot": {
		"needs_puck": true,
		"path": [[0.06, 8.0, 1.4, 0.2], [0.13, 12.0, 1.35, 0.2], [0.17, 8.0, 1.35, 0.0], [0.38, -30.0, 0.85, 0.0],
			[0.5, 0.0, 1.3, 0.0]],
		"shot": {"release": 0.47, "wind": 0.25, "power": 0.9, "error": 1.2, "loft_deg": 7.0},
	},
	# scoop it onto the blade round the front and carry it up behind the
	# forehand hip
	&"lacrosse": {
		"needs_puck": true,
		"glue": true,
		"path": [[0.3, 100.0, 0.8, 1.05]],
		"cradle": {"hold": 1.6, "wind": 0.4},
	},
}

## Per-kind adjustments for shots that aren't a move's own `shot` (Moves
## catalog ids), applied on top of the wind-up:
##   wind      the shot is as strong as a wrist shot of this wind-up, however long it was held
##   aim_wind  ... and as accurate as one of this wind-up
##   power, error  multipliers;  loft_deg  how far the face is opened (degrees above flat)
const SHOTS := {
	&"backhand": {"power": 0.8, "error": 1.3},
	&"lacrosse": {"wind": 0.4, "power": 0.9, "error": 1.25, "loft_deg": 13.0},
}


static func has_move(id: StringName) -> bool:
	return MOVES.has(id)


static func glued(id: StringName) -> bool:
	return MOVES.has(id) and MOVES[id].get("glue", false)


## Path time scale for a skater: better hands run the same path faster.
static func time_scale(sk: Skater) -> float:
	return lerpf(1.35, 0.8, sk.skill("stick_handling"))


## [angle rad, reach m, height m] at `t` seconds along the path, which starts
## from the blade's position `from` (body frame) when the move began.
static func sample(id: StringName, t: float, from: Vector2) -> Array:
	var path: Array = [[0.0, rad_to_deg(atan2(from.y, from.x)), from.length(), 0.0]] + MOVES[id]["path"]
	for i in range(1, path.size()):
		var a: Array = path[i - 1]
		var b: Array = path[i]
		if t <= b[0]:
			var f: float = clampf((t - a[0]) / maxf(b[0] - a[0], 0.0001), 0.0, 1.0)
			f = f * f * (3.0 - 2.0 * f)
			return [deg_to_rad(lerpf(a[1], b[1], f)), lerpf(a[2], b[2], f), lerpf(a[3], b[3], f)]
	var k: Array = path[-1]
	return [deg_to_rad(k[1]), k[2], k[3]]


static func duration(id: StringName) -> float:
	var path: Array = MOVES[id]["path"]
	return path[-1][0]
