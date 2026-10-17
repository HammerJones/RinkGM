extends VenueRoom
## The scoreboard, live with score, period and clock (the HUD layout at
## arena scale: teams and scores in TEXT, period and clock in ACTION). A worn or repaired rink
## has the old board bolted to the +X end wall (dead pixels on a worn one);
## renovating it hangs a four-sided board over centre ice. The housings are
## the asset kit's "scoreboard"; the centre-hung one is overhead (hidden in
## iso view).

const WALL_X := Venue.HALF_X - Venue.WALL_T
## The centre-hung board's ceiling mount; the kit board's bottom is 3.8 m
## below it, above the broadcast camera's view.
const HUNG_MOUNT_Y := Venue.ROOF_Y - 1.4
const _START := {"home": 0, "away": 0, "period": "1ST", "clock": "20:00"}

var _faces: Array[VenueSign] = []


func _ready() -> void:
	room_id = "scoreboard"
	display_name = "Scoreboard"


func build(k: VenueKit) -> void:
	_faces.clear()
	overhead = k.age == Age.RENOVATED
	visible = true
	if overhead:
		_hung(k)
	else:
		_wall(k)


func _wall(k: VenueKit) -> void:
	var y0 := 6.6
	var xf := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(WALL_X, y0, 0))
	k.prop("scoreboard", xf.origin, PI * 0.5, false)
	var s := _face_sign(k, xf, Props.scoreboard_faces(k.age)[0], _wall_lines(_START, "HOME", "AWAY"), 16, 3, 3)
	s.name = "WallBoard"
	s.dead = k.by_age(0.03, 0.006, 0.0)
	var sponsor := VenueSign.make([["// " + rink_name(), VenueSign.WHITE]], rink_name().length() + 3, 1, 0.03)
	sponsor.name = "WallBoardName"
	sponsor.background = home_primary().darkened(0.55)
	k.sign(sponsor, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(WALL_X - 0.36, y0 + 3.35, 0)))


func _hung(k: VenueKit) -> void:
	# the kit's four-sided board hangs from a ceiling mount like the lights
	var xf := Transform3D(Basis.IDENTITY, Vector3(0, HUNG_MOUNT_Y, 0))
	k.prop("scoreboard", xf.origin, 0.0, false)
	var f := 0
	for face in Props.scoreboard_faces(k.age):
		var s := _face_sign(k, xf, face, _hung_lines(_START, "HOME", "AWAY"), 11, 3, 2)
		s.name = "Face%d" % f
		f += 1


## A RINK-OS sign on one of the kit scoreboard's display faces, scaled
## down if the text would not fit the face.
func _face_sign(k: VenueKit, xf: Transform3D, face: Dictionary, lines: Array, cols: int, rows: int, px_scale: int) -> VenueSign:
	var size: Vector2 = face.size
	var px := 0.03
	var probe := VenueSign.make(lines, cols, rows, px, px_scale)
	var fit := minf(size.x / probe.size_m().x, size.y / probe.size_m().y)
	probe.free()
	var s := VenueSign.make(lines, cols, rows, px * fit * 0.97, px_scale)
	var n: Vector3 = xf.basis * (face.normal as Vector3)
	var basis := Basis(Vector3.UP, atan2(n.x, n.z))
	k.sign(s, Transform3D(basis, xf * (face.center as Vector3) + n * 0.01))
	_faces.append(s)
	return s


func show_score(st: Dictionary, home: String, away: String) -> void:
	var lines := _hung_lines(st, home, away) if overhead else _wall_lines(st, home, away)
	for f in _faces:
		if is_instance_valid(f):
			f.set_lines(lines)


func _hung_lines(st: Dictionary, home: String, away: String) -> Array:
	return [
		["%-4s %2d" % [home, st.home], VenueSign.WHITE],
		["%-4s %2d" % [away, st.away], VenueSign.WHITE],
		["%s %s" % [st.period, st.clock], VenueSign.AMBER, true],
	]


func _wall_lines(st: Dictionary, home: String, away: String) -> Array:
	return [
		["%-4s %2d  %2d %4s" % [home, st.home, st.away, away], VenueSign.WHITE],
		["----", VenueSign.DIM],
		["      %s  %s" % [st.period, st.clock], VenueSign.AMBER, true],
	]
