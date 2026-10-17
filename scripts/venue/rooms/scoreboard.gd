extends VenueRoom
## The scoreboard, live with score, period and clock. A worn or repaired rink
## has the old board bolted to the +X end wall (dead pixels on a worn one);
## renovating it hangs a four-sided board over centre ice with LED rings in
## the home colour. The centre-hung board is overhead (hidden in iso view).

const WALL_X := Venue.HALF_X - Venue.WALL_T
const HUNG_Y := 10.6   # bottom of the centre-hung board, above the broadcast camera's view
const HUNG_W := 4.6
const HUNG_H := 2.4

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
	var frame: Color = k.by_age(Color("4a3f36"), Color("3a3d44"), Color("15171b"))
	var y0 := 6.6
	k.block(Vector3(WALL_X - 0.35, y0, -4.2), Vector3(WALL_X, y0 + 2.9, 4.2), frame, 0.5, 0.08, false)
	for z in [-3.0, 3.0]:
		k.block(Vector3(WALL_X - 0.3, y0 - 0.5, z - 0.08), Vector3(WALL_X, y0, z + 0.08), frame.darkened(0.3), 0.5, 0.0, false)
	var s := VenueSign.make(_wall_lines({"home": 0, "away": 0, "period": "1ST", "clock": "20:00"}, "HOME", "AWAY"), 16, 3, 0.026, 3)
	s.name = "WallBoard"
	s.dead = k.by_age(0.03, 0.006, 0.0)
	k.sign(s, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(WALL_X - 0.36, y0 + 1.45, 0)))
	_faces.append(s)
	var sponsor := VenueSign.make([["// " + rink_name(), VenueSign.WHITE]], rink_name().length() + 3, 1, 0.03)
	sponsor.name = "WallBoardName"
	sponsor.background = home_primary().darkened(0.55)
	k.sign(sponsor, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(WALL_X - 0.36, y0 + 3.2, 0)))


func _hung(k: VenueKit) -> void:
	var frame := Color("15171b")
	var hw := HUNG_W * 0.5
	var y := HUNG_Y
	k.block(Vector3(-hw, y, -hw), Vector3(hw, y + HUNG_H, hw), frame, 0.5, 0.06, false)
	k.block(Vector3(-hw - 0.1, y + HUNG_H, -hw - 0.1), Vector3(hw + 0.1, y + HUNG_H + 0.25, hw + 0.1), frame.darkened(0.2), 0.5, 0.05, false)
	k.block(Vector3(-hw - 0.1, y - 0.25, -hw - 0.1), Vector3(hw + 0.1, y, hw + 0.1), frame.darkened(0.2), 0.5, 0.05, false)
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var cx: float = c.x * (hw - 0.2)
		var cz: float = c.y * (hw - 0.2)
		k.block(Vector3(cx - 0.02, y + HUNG_H + 0.25, cz - 0.02), Vector3(cx + 0.02, Venue.ROOF_Y - 1.4, cz + 0.02), Color("1b1c1f"), 1.0, 0.0, false)
	var ring := home_primary().lightened(0.25)
	k.glow(Vector3(-hw - 0.11, y + HUNG_H + 0.05, -hw - 0.11), Vector3(hw + 0.11, y + HUNG_H + 0.15, hw + 0.11), ring)
	k.glow(Vector3(-hw - 0.11, y - 0.15, -hw - 0.11), Vector3(hw + 0.11, y - 0.05, hw + 0.11), ring)
	for f in 4:
		var s := VenueSign.make(_hung_lines({"home": 0, "away": 0, "period": "1ST", "clock": "20:00"}, "HOME", "AWAY"), 11, 3, 0.031, 2)
		s.name = "Face%d" % f
		var basis := Basis(Vector3.UP, f * PI * 0.5)
		k.sign(s, Transform3D(basis, basis * Vector3(0, 0, hw + 0.01) + Vector3(0, y + HUNG_H * 0.5, 0)))
		_faces.append(s)


func show_score(st: Dictionary, home: String, away: String) -> void:
	var lines := _hung_lines(st, home, away) if overhead else _wall_lines(st, home, away)
	for f in _faces:
		if is_instance_valid(f):
			f.set_lines(lines)


func _hung_lines(st: Dictionary, home: String, away: String) -> Array:
	return [
		["%-4s %2d" % [home, st.home], VenueSign.CYAN],
		["%-4s %2d" % [away, st.away], VenueSign.AMBER],
		["%s %s" % [st.period, st.clock], VenueSign.GREEN],
	]


func _wall_lines(st: Dictionary, home: String, away: String) -> Array:
	return [
		["%-4s %2d  %2d %4s" % [home, st.home, st.away, away], VenueSign.CYAN],
		["----", VenueSign.DIM],
		["   %s %s" % [st.period, st.clock], VenueSign.GREEN],
	]
