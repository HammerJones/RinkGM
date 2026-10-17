extends VenueRoom
## Rink glass on top of the boards: tall panels at the ends and corners,
## shorter along the sides, none in front of the player benches. Visual only;
## the shell's board collider already stops a walker. Worn glass is fogged
## and scuffed with dull stanchions; renovated glass is clear with
## seamless black frames.

const PANEL := 1.22  # 4 ft panels
const BENCH_GAPS := [[-11.4, -2.6], [2.6, 11.4]]


func _ready() -> void:
	room_id = "glass"
	display_name = "Rink glass"


func build(k: VenueKit) -> void:
	var top := Rink.BOARD_H + 0.04
	var tint: Color = k.by_age(Color(0.82, 0.86, 0.8, 0.24), Color(0.8, 0.9, 0.95, 0.18), Color(0.8, 0.92, 1.0, 0.1))
	var post: Color = k.by_age(Color("7d7a72"), Color("9aa0a6"), Color("1d2026"))
	for smp in _perimeter(PANEL):
		var p: Vector2 = smp[0]
		var t: Vector2 = smp[1]
		var n := Vector2(t.y, -t.x)
		if n.dot(p) < 0.0:
			n = -n
		if _bench_front(p, n):
			continue
		var h := 1.2 if absf(n.y) > 0.99 else 2.4
		if absf(n.y) > 0.99 and n.y > 0.0 and absf(p.x) < 5.8:
			h = 1.4  # penalty boxes
		var basis := Basis(Vector3(t.x, 0, t.y), Vector3.UP, Vector3(n.x, 0, n.y))
		var c := Vector3(p.x + n.x * 0.16, top + h * 0.5, p.y + n.y * 0.16)
		k.oriented(Transform3D(basis.scaled(Vector3(PANEL - 0.04, h, 0.02)), c), tint, true)
		var edge := Vector3(t.x, 0, t.y) * (PANEL * 0.5)
		k.oriented(Transform3D(basis.scaled(Vector3(0.05, h + 0.02, 0.07)), c + edge), post)
		if k.age == VenueRoom.Age.WORN and posmod(hash(p), 6) == 0:
			# a scuffed panel: puck marks low on the glass
			k.oriented(Transform3D(basis.scaled(Vector3(PANEL * 0.6, 0.35, 0.025)), c + Vector3(0, -h * 0.5 + 0.3, 0)), Color(0.5, 0.48, 0.42, 0.35), true)


func _bench_front(p: Vector2, n: Vector2) -> bool:
	if n.y > -0.99:
		return false
	for g in BENCH_GAPS:
		if p.x > g[0] and p.x < g[1]:
			return true
	return false


## Board line samples [[position, unit tangent], ...], `step` apart.
func _perimeter(step: float) -> Array:
	var out := []
	var sx := Rink.HALF_L - Rink.CORNER_R
	var sz := Rink.HALF_W - Rink.CORNER_R
	var nx := int(round(sx * 2.0 / step))
	for i in nx:
		var x := -sx + (i + 0.5) * (sx * 2.0 / nx)
		out.append([Vector2(x, -Rink.HALF_W), Vector2(1, 0)])
		out.append([Vector2(x, Rink.HALF_W), Vector2(1, 0)])
	var nz := int(round(sz * 2.0 / step))
	for i in nz:
		var z := -sz + (i + 0.5) * (sz * 2.0 / nz)
		out.append([Vector2(-Rink.HALF_L, z), Vector2(0, 1)])
		out.append([Vector2(Rink.HALF_L, z), Vector2(0, 1)])
	var arc := int(round(Rink.CORNER_R * PI * 0.5 / step))
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			for i in arc:
				var a := (i + 0.5) / arc * PI * 0.5
				var dir := Vector2(cx * cos(a), cz * sin(a))
				out.append([Vector2(cx * sx, cz * sz) + dir * Rink.CORNER_R, Vector2(-dir.y, dir.x)])
	return out
