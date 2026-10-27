extends VenueRoom
## Roof deck, steel trusses, ductwork and the banners hung from the rafters.
## Overhead: hidden in the isometric view.

const TRUSS_STEP := 6.0
## Felt banners hung from the rafters over the lobby end, facing the ice
## (readables.json ids), each on two strings up to the truss.
const BANNERS := ["banner_league_8788", "banner_lumber_kings", "banner_retired_9", "banner_mallards", "banner_midget_94"]


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
	# banners: five over the lobby end, facing the ice, tops level
	var top := y - 3.0
	for i in BANNERS.size():
		var b := Readable.make(BANNERS[i])
		b.string_length = (y - 1.4) - top
		b.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-33.0, top - b.size.y * 0.5, -12.0 + i * 6.0))
		k.add(b)
