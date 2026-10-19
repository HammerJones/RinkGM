extends RecRoom
## The hall washrooms, men's (west) and women's (east), split by a tiled
## partition: stalls against the arena wall, sinks and a mirror by the door.
## Worn ones have an out-of-order stall and a running tap.

const SPLIT := -16.5


func floor_color(k: VenueKit) -> Color:
	return k.by_age(Color("8f9a92"), Color("b9c2bb"), Color("d8dcdc"))


func floor_tile() -> float:
	return 0.4


func paint(k: VenueKit) -> Color:
	return k.by_age(Color("a9b8ae"), Color("cfd8d2"), Color("f0f2f2"))


## Just inside each door.
func places() -> Dictionary:
	return {"washroom": [Vector3(-18.5, 0, -38.6), Vector3(-14.5, 0, -38.6)]}


func furnish(k: VenueKit) -> void:
	partition(k, "z", SPLIT, z0, z1, paint(k))
	for half in [[x0, SPLIT, true], [SPLIT, x1, false]]:
		_half(k, half[0] + (0.15 if half[0] == x0 else 0.1), half[1] - (0.1 if half[1] == SPLIT else 0.15), half[2])
	RecDetail.washrooms(self, k)  # World: detail pass (#23, #27)


func _half(k: VenueKit, a: float, b: float, mens: bool) -> void:
	var stall: Color = k.by_age(Color("6a7a70"), Color("7a8a90"), Color("3a3d44"))
	var porcelain := Color("e8e8e2") if k.age != Age.WORN else Color("cfcbbd")
	# three stalls against the arena wall (z -30), partitions 1.8 m high
	var n := 3
	var w := (b - a) / n
	for i in n:
		var sx := a + i * w
		if i > 0:
			k.block(Vector3(sx - 0.02, 0.15, -32.0), Vector3(sx + 0.02, 1.95, -30.0), stall, 0.5, 0.03)
		k.block(Vector3(sx + 0.1, 0, -30.7), Vector3(sx + 0.55, 0.45, -30.1), porcelain, 0.2, 0.02)
		k.block(Vector3(sx + 0.15, 0.45, -30.3), Vector3(sx + 0.5, 0.85, -30.05), porcelain, 0.2, 0.02)
		# stall front with a door (left ajar, so a walker can look in)
		k.block(Vector3(sx + 0.02, 0.15, -32.02), Vector3(sx + 0.15, 1.95, -31.98), stall, 0.5, 0.03)
		k.block(Vector3(sx + w - 0.15, 0.15, -32.02), Vector3(sx + w - 0.02, 1.95, -31.98), stall, 0.5, 0.03)
		var leaf := Transform3D(Basis(Vector3.UP, 0.9), Vector3(sx + 0.15, 1.05, -32.0))
		k.oriented(leaf * Transform3D(Basis.from_scale(Vector3(w - 0.32, 1.75, 0.03)), Vector3((w - 0.32) * 0.5, 0, 0)), stall.lightened(0.05))
		if k.age == Age.WORN and i == 1:
			wall_sign(k, [["OUT OF ORDER", VenueSign.RED]], 12, 1, 0.012, Vector3(sx + w * 0.5, 1.5, -31.97), Vector3(0, 0, -1), "OutOfOrder", Color("eeeae0"))
	# sinks and the mirror on the partition / outer wall side, near the door
	var sink_x := b - 0.35 if mens else a + 0.35
	var face := sink_x + (0.3 if mens else -0.3)
	for j in 2:
		var sz := -37.6 + j * 1.0
		k.block(Vector3(sink_x - 0.25, 0.8, sz - 0.3), Vector3(sink_x + 0.25, 0.9, sz + 0.3), porcelain, 0.2, 0.02)
		k.block(Vector3(sink_x - 0.06, 0, sz - 0.06), Vector3(sink_x + 0.06, 0.8, sz + 0.06), Color("b8bcc2"), 0.2, 0.0, false)
	k.glass(Vector3(face - 0.02, 1.2, -38.0), Vector3(face, 2.0, -35.7), false, Color(0.85, 0.9, 0.95, 0.55))
	if mens:
		for j in 2:
			var uz := -35.4 + j * 0.8
			k.block(Vector3(a, 0.5, uz - 0.2), Vector3(a + 0.3, 1.1, uz + 0.2), porcelain, 0.2, 0.02)
	rec_light(k, Vector3((a + b) * 0.5, h - 0.4, -35.0), 5.0)
	var sign_x := (a + b) * 0.5
	wall_sign(k, [["// " + ("MEN" if mens else "WOMEN"), VenueSign.CYAN]], 9, 1, 0.02, Vector3(sign_x, 2.3, z0 + 0.15), Vector3(0, 0, 1), "Sign%s" % ("Men" if mens else "Women"))


func lights(k: VenueKit) -> void:
	var lit: Color = k.by_age(Color("e6eed8"), Color("f4f6f0"), Color("fff6e6"))
	for x in [-18.3, -14.7]:
		for z in [-37.5, -32.5]:
			k.glow(Vector3(x - 0.5, h - 0.05, z - 0.15), Vector3(x + 0.5, h - 0.01, z + 0.15), lit)
