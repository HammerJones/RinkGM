extends VenueRoom
## The scoreboard, live with score, period and clock: a classic light panel
## (BulbBoard), seven-segment digits made of bulbs with painted HOME / GUEST
## / PERIOD lettering, laid out like an old arena wall board: HOME score |
## MM:SS | GUEST score, period under the clock. A worn or repaired rink has
## the old board bolted to the +X end wall (a few dead bulbs and tired wiring
## on a worn one) with the rink name painted on its header; renovating it
## hangs a four-sided board over centre ice. The housings are the asset
## kit's "scoreboard"; the centre-hung one is overhead (hidden in iso view).
## `mode` "clock" shows the time of day instead (set via show_time()).

const WALL_X := Venue.HALF_X - Venue.WALL_T
## The centre-hung board's ceiling mount; the kit board's bottom is 3.8 m
## below it, above the broadcast camera's view.
const HUNG_MOUNT_Y := Venue.ROOF_Y - 1.4
## The wall housing's sponsor header (kit voxels): centre height, size, and
## its front (the painted strip is thick enough to cover its lamp knobs).
const _HEADER_Y := 40.5 * Models.V
const _HEADER_SIZE := Vector2(96.0, 7.0) * Models.V
const _HEADER_Z := -4.0 * Models.V

## "game" (score, period, clock) or "clock" (time of day, scores dark).
var mode := "game":
	set(v):
		mode = v
		if _board:
			_board.mode = v

var _board: BulbBoard
var _time := Vector2i(-1, 0)


func _ready() -> void:
	room_id = "scoreboard"
	display_name = "Scoreboard"


func build(k: VenueKit) -> void:
	overhead = k.age == Age.RENOVATED
	visible = true
	_board = BulbBoard.make(k.age, hash(rink_name()))
	_board.name = "Board"
	_board.mode = mode
	if _time.x >= 0:
		_board.show_time(_time.x, _time.y)
	if overhead:
		_hung(k)
	else:
		_wall(k)
	k.add(_board)


func _wall(k: VenueKit) -> void:
	var xf := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(WALL_X, 6.6, 0))
	k.prop("scoreboard", xf.origin, PI * 0.5, false)
	_board.add_face(k, _face_xf(xf, Props.scoreboard_faces(k.age)[0]), Props.scoreboard_faces(k.age)[0].size, false)
	var header := xf * Transform3D(Basis(Vector3.UP, PI), Vector3(0, _HEADER_Y, _HEADER_Z))
	BulbBoard.paint_strip(k, header, _HEADER_SIZE, rink_name(), home_primary().darkened(0.35), Color("efe6cf"), 0.085)


func _hung(k: VenueKit) -> void:
	# the kit's four-sided board hangs from a ceiling mount like the lights
	var xf := Transform3D(Basis.IDENTITY, Vector3(0, HUNG_MOUNT_Y, 0))
	k.prop("scoreboard", xf.origin, 0.0, false)
	for face in Props.scoreboard_faces(k.age):
		_board.add_face(k, _face_xf(xf, face), face.size, true, rink_name(), Color("121214"), Color("f4f1ea"))


## A display face of the kit housing as a transform looking out of it.
func _face_xf(xf: Transform3D, face: Dictionary) -> Transform3D:
	var n: Vector3 = xf.basis * (face.normal as Vector3)
	return Transform3D(Basis(Vector3.UP, atan2(n.x, n.z)), xf * (face.center as Vector3))


func show_score(st: Dictionary, _home: String, _away: String) -> void:
	if is_instance_valid(_board):
		_board.show_score(st)


## The time of day (24-hour) for "clock" mode, kept across rebuilds.
func show_time(hours: int, minutes: int) -> void:
	_time = Vector2i(hours, minutes)
	if is_instance_valid(_board):
		_board.show_time(hours, minutes)
