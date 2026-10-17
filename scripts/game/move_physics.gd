class_name MovePhysics
extends RefCounted
## How each unlockable stick move is executed on the ice. Controls owns the
## move catalog and gesture recognition and sets `Skater.Controls.move_id`;
## mechanics decides who knows which move (`Skater.knows`). This file owns
## what happens once a move starts: the blade's path around the body, when the
## blade is lifted, and the shot it ends in, if any.
##
## Paths are keyframes [time s, angle deg, reach m, blade height m]. Angle 0 is
## straight ahead, + is the forehand side, and past +-45 degrees the skater is
## down to one hand. The blade still moves under the skater's own speed and
## grip limits, so a weak stickhandler runs the path slower and can lose the
## puck on it. Times are for a 50 stickhandler; better hands run it faster.
##
## A shot entry fires at `release` seconds into the path:
##   wind   seconds of wind-up it is worth (sets power and accuracy like a wrist shot)
##   power  multiplier on that speed
##   error  multiplier on aim error
##   loft   target height at the net (m)

const MOVES := {
	# quick pull and snap: almost no wind-up, but much better than a flick
	&"snap_shot": {
		"needs_puck": true,
		"path": [[0.0, 20.0, 1.0, 0.0], [0.09, 55.0, 0.85, 0.0], [0.17, -5.0, 1.35, 0.0]],
		"shot": {"release": 0.15, "wind": 0.35, "power": 1.0, "error": 1.0, "loft": 0.5},
	},
	# pull the puck across to the backhand and lift it off the toe
	&"backhand_shot": {
		"needs_puck": true,
		"path": [[0.0, 20.0, 1.0, 0.0], [0.16, -40.0, 0.9, 0.0], [0.3, -10.0, 1.3, 0.0]],
		"shot": {"release": 0.27, "wind": 0.4, "power": 0.72, "error": 1.4, "loft": 0.85},
	},
	# forehand to backhand and back, puck on the blade the whole way
	&"quick_deke": {
		"needs_puck": true,
		"path": [[0.0, 20.0, 1.05, 0.0], [0.22, -40.0, 1.05, 0.0], [0.46, 40.0, 1.05, 0.0], [0.56, 20.0, 1.0, 0.0]],
	},
	# reach out, lift over the puck, set the toe down on the far side and drag
	# it back in across the body
	&"toe_drag": {
		"needs_puck": true,
		"path": [[0.0, 20.0, 1.0, 0.0], [0.1, 30.0, 1.4, 0.0], [0.22, 5.0, 1.45, 0.2],
			[0.3, -5.0, 1.4, 0.0], [0.55, -35.0, 0.75, 0.0]],
	},
	# toe drag that ends in a quick release from the new angle
	&"toe_drag_shot": {
		"needs_puck": true,
		"path": [[0.0, 20.0, 1.0, 0.0], [0.1, 30.0, 1.4, 0.0], [0.22, 5.0, 1.45, 0.2],
			[0.3, -5.0, 1.4, 0.0], [0.45, -25.0, 0.85, 0.0], [0.56, 0.0, 1.3, 0.0]],
		"shot": {"release": 0.53, "wind": 0.25, "power": 0.9, "error": 1.2, "loft": 0.4},
	},
}


static func has_move(id: StringName) -> bool:
	return MOVES.has(id)


## Path time scale for a skater: better hands run the same path faster.
static func time_scale(sk: Skater) -> float:
	return lerpf(1.35, 0.8, sk.skill("stick_handling"))


## [angle rad, reach m, height m] at `t` seconds along the path.
static func sample(id: StringName, t: float) -> Array:
	var path: Array = MOVES[id]["path"]
	if t <= path[0][0]:
		return _key(path[0])
	for i in range(1, path.size()):
		var a: Array = path[i - 1]
		var b: Array = path[i]
		if t <= b[0]:
			var f: float = (t - a[0]) / maxf(b[0] - a[0], 0.0001)
			f = f * f * (3.0 - 2.0 * f)
			return [deg_to_rad(lerpf(a[1], b[1], f)), lerpf(a[2], b[2], f), lerpf(a[3], b[3], f)]
	return _key(path[-1])


static func duration(id: StringName) -> float:
	var path: Array = MOVES[id]["path"]
	return path[-1][0]


static func _key(k: Array) -> Array:
	return [deg_to_rad(k[1]), k[2], k[3]]
