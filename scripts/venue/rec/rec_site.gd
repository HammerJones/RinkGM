extends VenueRoom
## Outside the building: the parking lot and sidewalks around the arena and
## the recreation centre, so a walker who goes out the front doors has
## ground under their feet. Not a room (no bounds), so it never wins
## room_at().

const SITE_X := 80.0
const SITE_Z0 := -95.0
const SITE_Z1 := 60.0


func _ready() -> void:
	room_id = "rec_site"
	display_name = "Outside"
	wing = "rec"


func build(k: VenueKit) -> void:
	var asphalt: Color = k.by_age(Color("3a3b3d"), Color("343537"), Color("2c2d30"))
	var bx0 := -Venue.HALF_X
	var bx1 := Venue.HALF_X
	var bz0 := RecPlan.Z_BACK
	var bz1 := Venue.HALF_Z
	# four slabs around the building's footprint
	k.slab(Vector3(-SITE_X, -0.3, SITE_Z0), Vector3(SITE_X, -0.02, bz0), asphalt, 2.0, 0.06)
	k.slab(Vector3(-SITE_X, -0.3, bz1), Vector3(SITE_X, -0.02, SITE_Z1), asphalt, 2.0, 0.06)
	k.slab(Vector3(-SITE_X, -0.3, bz0), Vector3(bx0, -0.02, bz1), asphalt, 2.0, 0.06)
	k.slab(Vector3(bx1, -0.3, bz0), Vector3(SITE_X, -0.02, bz1), asphalt, 2.0, 0.06)
	_sidewalk(k, bx0, bx1, bz0, bz1)
	_parking(k)
	_entrance(k)
	# a dumpster and a bike rack by the workshop end, poles round the lot
	k.aged_block(Vector3(48.0, 0, -58.0), Vector3(50.0, 1.4, -56.6), Color("2a5a3a"), 0.5)
	for i in 5:
		k.block(Vector3(-49.0, 0, -50.0 + i * 0.6), Vector3(-48.95, 0.8, -49.95 + i * 0.6), Color("8f9498"), 0.3, 0.0)
	for p in [Vector2(-62, -75), Vector2(-62, -30), Vector2(-62, 15), Vector2(0, -75), Vector2(40, -75)]:
		k.block(Vector3(p.x - 0.12, 0, p.y - 0.12), Vector3(p.x + 0.12, 7.0, p.y + 0.12), Color("6a6e74"), 1.0, 0.0)
		k.block(Vector3(p.x - 0.3, 6.9, p.y - 0.8), Vector3(p.x + 0.3, 7.1, p.y + 0.8), Color("3a3d44"), 0.5, 0.0, false)
		k.glow(Vector3(p.x - 0.25, 6.88, p.y - 0.7), Vector3(p.x + 0.25, 6.9, p.y + 0.7), k.by_age(Wear.SODIUM_DIM, Wear.SODIUM, Wear.LED))


## A concrete apron round the building.
func _sidewalk(k: VenueKit, bx0: float, bx1: float, bz0: float, bz1: float) -> void:
	var conc: Color = k.by_age(Color("8a867c"), Color("9a968c"), Color("aaa8a2"))
	var w := 2.5
	k.block(Vector3(bx0 - w, -0.02, bz0 - w), Vector3(bx1 + w, 0.0, bz0), conc, 1.5, 0.05, false)
	k.block(Vector3(bx0 - w, -0.02, bz1), Vector3(bx1 + w, 0.0, bz1 + w), conc, 1.5, 0.05, false)
	k.block(Vector3(bx0 - w, -0.02, bz0), Vector3(bx0, 0.0, bz1), conc, 1.5, 0.05, false)
	k.block(Vector3(bx1, -0.02, bz0), Vector3(bx1 + w, 0.0, bz1), conc, 1.5, 0.05, false)


## The lot on the west side: painted stalls facing both entrances.
func _parking(k: VenueKit) -> void:
	var paint: Color = k.by_age(Color("b8b49a"), Color("e8e4c8"), Color("f2f0e8"))
	for col in [-56.0, -68.0]:
		for i in 26:
			var z := -78.0 + i * 3.0
			if absf(z) < 4.0:
				continue  # the lane to the arena's old front doors
			k.block(Vector3(col - 5.0, -0.02, z - 0.06), Vector3(col, -0.015, z + 0.06), paint, 1.0, 0.05, false)
	for seg in [[-78.0, -4.0], [4.0, 40.0]]:
		k.block(Vector3(-56.4, -0.02, seg[0]), Vector3(-56.0, 0.15, seg[1]), Color("8a867c"), 2.0, 0.04)  # curb islands


## The canopy over the main entrance and the centre's name on the wall.
func _entrance(k: VenueKit) -> void:
	var x := RecPlan.X_W
	var steel: Color = k.by_age(Color("5a5e64"), Color("6a6e74"), Color("2b2d33"))
	k.block(Vector3(x - 3.0, 3.0, -40.0), Vector3(x, 3.3, -34.0), steel, 1.0, 0.03, false)
	for z in [-39.8, -34.2]:
		k.block(Vector3(x - 2.9, 0, z - 0.08), Vector3(x - 2.74, 3.0, z + 0.08), steel, 1.0, 0.0)
	var name := RecPlan.centre_name(venue.get("rink_name") if venue else "COMMUNITY RINK")
	var s := VenueSign.make([["// " + name, VenueSign.CYAN]], name.length() + 3, 1, 0.06)
	s.name = "RecSign"
	s.dead = k.by_age(0.06, 0.01, 0.0)
	k.sign(s, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(x - 0.32, 3.9, -37.0)))
