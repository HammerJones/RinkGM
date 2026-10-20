extends VenueRoom
## Rink glass on top of the boards: tall panels at the ends and corners,
## shorter along the sides, none in front of the player benches. Heights come
## from VenuePhysics, which the puck and the shell's board collider use too, so
## a puck clears exactly the glass you see. Panels and frames are
## the asset kit's glass_pane and glass_frame at the room's age.
## The doors in the boards are hung here too (RinkDoors): their glass is the
## same kit panel at the same age, on the leaf, and the fixed panels stop at
## each door's opening.

const PANEL := 1.83   # the kit panel (6 ft)
const PANE_H := 1.17  # kit panel height above the boards


func _ready() -> void:
	room_id = "glass"
	display_name = "Rink glass"


## Where people stand at the glass: the end walkways behind the nets and the
## side walkways past the benches and boxes.
func places() -> Dictionary:
	var pts: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for z in [-9.0, -3.0, 3.0, 9.0]:
			pts.append(Vector3(sx * (Rink.HALF_L + 1.3), 0, z))
		for x in [13.5, 18.5, 23.0]:
			for sz in [-1.0, 1.0]:
				pts.append(Vector3(sx * x, 0, sz * 16.3))
	return {"glass": pts}


func build(k: VenueKit) -> void:
	var top := Rink.BOARD_H + 0.04
	# the asset kit's panel and its frame; panes are see-through per age.
	# Low detail: from the broadcast camera the bolts and rust are a pixel.
	var pane := Props.mesh("glass_pane", k.age, 1)
	var frame := Props.mesh("glass_frame", k.age, 1)
	RinkDoors.build(self, k)
	for smp in _pieces(_perimeter(PANEL)):
		var p: Vector2 = smp[0]
		var t: Vector2 = smp[1]
		var w: float = smp[2]
		var n := Vector2(t.y, -t.x)
		if n.dot(p) < 0.0:
			n = -n
		var h := VenuePhysics.glass_height(p, n)
		if h <= 0.0:
			continue  # open over the player benches
		# stretch the kit panel to this run's spacing and height
		var basis := Basis(Vector3(t.x, 0, t.y) * (w / PANEL), Vector3.UP * (h / PANE_H), Vector3(n.x, 0, n.y))
		var xf := Transform3D(basis, Vector3(p.x + n.x * 0.16, top, p.y + n.y * 0.16))
		k.instance(pane, xf)
		k.instance(frame, xf)


## The panels with the doors' openings taken out: a panel an opening
## overlaps is cut into the pieces either side of it (each its own stretched
## kit panel, with its own post), same sample format.
func _pieces(samples: Array) -> Array:
	var out := []
	for smp in samples:
		var p: Vector2 = smp[0]
		var t: Vector2 = smp[1]
		var w: float = smp[2]
		var wall := ""
		if absf(t.x) > 0.99 and absf(absf(p.y) - Rink.HALF_W) < 0.01:
			wall = "z+" if p.y > 0.0 else "z-"
		elif absf(t.y) > 0.99 and absf(absf(p.x) - Rink.HALF_L) < 0.01:
			wall = "x+" if p.x > 0.0 else "x-"
		var spans := RinkDoors.glass_spans(wall) if wall != "" else []
		if spans.is_empty():
			out.append(smp)
			continue
		var along := p.x if wall[0] == "z" else p.y
		var bits := [[along - w * 0.5, along + w * 0.5]]
		for s: Array in spans:
			var next := []
			for b: Array in bits:
				if s[1] <= b[0] or s[0] >= b[1]:
					next.append(b)
					continue
				if s[0] > b[0]:
					next.append([b[0], s[0]])
				if s[1] < b[1]:
					next.append([s[1], b[1]])
			bits = next
		for b: Array in bits:
			if b[1] - b[0] < 0.02:
				continue
			var c: float = (b[0] + b[1]) * 0.5
			var q := Vector2(c, p.y) if wall[0] == "z" else Vector2(p.x, c)
			out.append([q, t, b[1] - b[0]])
	return out


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
