extends VenueRoom
## Roof deck, steel trusses, ductwork and the banners hung from the rafters.
## Overhead: hidden in the isometric view.

const TRUSS_STEP := 6.0
const BANNERS := [
	[["// LEAGUE", VenueSign.AMBER], ["CHAMPIONS", VenueSign.WHITE], ["----", VenueSign.DIM], ["1987-88", VenueSign.CYAN, true]],
	[["// RETIRED", VenueSign.AMBER], ["#9", VenueSign.WHITE], ["----", VenueSign.DIM], ["D. PELLETIER", VenueSign.CYAN, true]],
	[["// PROVINCIAL", VenueSign.AMBER], ["FINALISTS", VenueSign.WHITE], ["----", VenueSign.DIM], ["1994", VenueSign.CYAN, true]],
]


func _ready() -> void:
	room_id = "roof"
	display_name = "Roof and rafters"
	overhead = true


func build(k: VenueKit) -> void:
	var hx := Venue.HALF_X
	var hz := Venue.HALF_Z
	var y := Venue.ROOF_Y
	k.slab(Vector3(-hx, y, -hz), Vector3(hx, y + 0.4, hz), k.by_age(Color("5e5a52"), Color("6b675e"), Color("3a3d44")), 2.0, 0.08, true)
	var steel: Color = k.by_age(Color("6d5f52"), Color("6d737a"), Color("2a2e35"))
	var x := -hx + TRUSS_STEP
	var ti := 0
	while x < hx - 0.1:
		var bottom := y - 1.4
		k.block(Vector3(x - 0.12, bottom, -hz), Vector3(x + 0.12, bottom + 0.22, hz), k.aged(steel, ti), 1.0, 0.06, false)
		k.block(Vector3(x - 0.12, y - 0.22, -hz), Vector3(x + 0.12, y, hz), k.aged(steel, ti + 1), 1.0, 0.06, false)
		var zz := -hz
		var flip := false
		while zz < hz - 0.1:
			var mid := Vector3(x, bottom + 0.7, zz + 1.5)
			var tilt := Basis(Vector3.RIGHT, (0.75 if flip else -0.75))
			k.oriented(Transform3D(tilt.scaled(Vector3(0.1, 1.9, 0.1)), mid), steel)
			k.block(Vector3(x - 0.06, bottom, zz - 0.05), Vector3(x + 0.06, y, zz + 0.05), steel, 1.0, 0.0, false)
			zz += 3.0
			flip = not flip
		x += TRUSS_STEP
		ti += 1
	# a long duct along each side wall; the worn one sags in patches
	var duct: Color = k.by_age(Color("8c8a84"), Color("a8acb0"), Color("c9ccd1"))
	for s in [-1, 1]:
		var zc: float = s * (hz - 2.0)
		var piece := 4.0
		var dx := -hx + 1.0
		var i := 0
		while dx < hx - 1.0:
			var sag := 0.15 if k.age == Age.WORN and i % 5 == 2 else 0.0
			k.block(Vector3(dx, y - 2.4 - sag, zc - 0.45), Vector3(dx + piece - 0.05, y - 1.6 - sag, zc + 0.45), k.aged(duct, i), 1.0, 0.06, false)
			dx += piece
			i += 1
	# banners: three over the lobby end, facing the ice
	for i in BANNERS.size():
		var b := VenueSign.make(BANNERS[i], 12, 4, 0.04)
		b.name = "Banner%d" % i
		b.dead = k.by_age(0.05, 0.01, 0.0)
		b.background = k.by_age(Color("1a1410"), VenueSign.BG, Color("06080d"))
		k.sign(b, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-33.0, 8.6, -8.0 + i * 8.0)))
		k.block(Vector3(-33.05, 9.5, -8.0 + i * 8.0 - 0.02), Vector3(-33.0, y - 1.4, -8.0 + i * 8.0 + 0.02), Color("1b1c1f"), 1.0, 0.0, false)
