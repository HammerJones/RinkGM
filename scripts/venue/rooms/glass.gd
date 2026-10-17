extends VenueRoom
## Rink glass on top of the boards: tall panels at the ends and corners,
## shorter along the sides, none in front of the player benches. Visual only;
## the shell's board collider already stops a walker. Panels and frames are
## the asset kit's glass_pane and glass_frame at the room's age.

const PANEL := 1.83   # the kit panel (6 ft)
const PANE_H := 1.17  # kit panel height above the boards
const BENCH_GAPS := [[-11.4, -2.6], [2.6, 11.4]]


func _ready() -> void:
	room_id = "glass"
	display_name = "Rink glass"


func build(k: VenueKit) -> void:
	var top := Rink.BOARD_H + 0.04
	# the asset kit's panel and its frame; panes are see-through per age.
	# Low detail: from the broadcast camera the bolts and rust are a pixel.
	var pane := Props.mesh("glass_pane", k.age, 1)
	var frame := Props.mesh("glass_frame", k.age, 1)
	for smp in _perimeter(PANEL):
		var p: Vector2 = smp[0]
		var t: Vector2 = smp[1]
		var w: float = smp[2]
		var n := Vector2(t.y, -t.x)
		if n.dot(p) < 0.0:
			n = -n
		if _bench_front(p, n):
			continue
		var h := 1.2 if absf(n.y) > 0.99 else 2.4
		if absf(n.y) > 0.99 and n.y > 0.0 and absf(p.x) < 5.8:
			h = 1.4  # penalty boxes
		# stretch the kit panel to this run's spacing and height
		var basis := Basis(Vector3(t.x, 0, t.y) * (w / PANEL), Vector3.UP * (h / PANE_H), Vector3(n.x, 0, n.y))
		var xf := Transform3D(basis, Vector3(p.x + n.x * 0.16, top, p.y + n.y * 0.16))
		k.instance(pane, xf)
		k.instance(frame, xf)


func _bench_front(p: Vector2, n: Vector2) -> bool:
	if n.y > -0.99:
		return false
	for g in BENCH_GAPS:
		if p.x > g[0] and p.x < g[1]:
			return true
	return false


## Board line samples [[position, unit tangent, spacing], ...], about `step` apart.
func _perimeter(step: float) -> Array:
	var out := []
	var sx := Rink.HALF_L - Rink.CORNER_R
	var sz := Rink.HALF_W - Rink.CORNER_R
	var nx := int(round(sx * 2.0 / step))
	for i in nx:
		var x := -sx + (i + 0.5) * (sx * 2.0 / nx)
		out.append([Vector2(x, -Rink.HALF_W), Vector2(1, 0), sx * 2.0 / nx])
		out.append([Vector2(x, Rink.HALF_W), Vector2(1, 0), sx * 2.0 / nx])
	var nz := int(round(sz * 2.0 / step))
	for i in nz:
		var z := -sz + (i + 0.5) * (sz * 2.0 / nz)
		out.append([Vector2(-Rink.HALF_L, z), Vector2(0, 1), sz * 2.0 / nz])
		out.append([Vector2(Rink.HALF_L, z), Vector2(0, 1), sz * 2.0 / nz])
	var arc := int(round(Rink.CORNER_R * PI * 0.5 / step))
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			for i in arc:
				var a := (i + 0.5) / arc * PI * 0.5
				var dir := Vector2(cx * cos(a), cz * sin(a))
				out.append([Vector2(cx * sx, cz * sz) + dir * Rink.CORNER_R, Vector2(-dir.y, dir.x), Rink.CORNER_R * PI * 0.5 / arc])
	return out
