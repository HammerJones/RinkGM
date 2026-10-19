class_name IceGear
extends Node3D
## Everything on the ice that isn't a person: pucks (black, and light blue
## for the youngest), pylons, full-size and mini nets, the black divider pads,
## a broomball, puck buckets and the racks by the Zamboni doors. Pucks and
## pylons are physical: pucks slide, bounce off the boards, posts, pads,
## pylons and skates and stop in the twine; a puck or a skate knocks a pylon
## over and it slides until it stops. Everything is in venue space, 2D on the
## ice (Vector2(x, z)).
##
## Signals for sound (the lead thread hooks them): puck_hit(pos, what, speed)
## with what = "boards", "post", "pylon", "pad", "net", "skate", "stick",
## "goalie"; goal(net, puck); save(net, puck).

signal puck_hit(pos: Vector3, what: String, speed: float)
signal goal(net: int, puck: int)
signal save(net: int, puck: int)

const PUCK_R := 0.038
const BALL_R := 0.08
const PYLON_R := 0.12
const PAD_T := 0.17      # half thickness of a divider pad
const FULL_HALF_W := 0.915
const FULL_DEPTH := 1.1
const MINI_HALF_W := 0.61
const MINI_DEPTH := 0.6


class IcePuck:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var blue := false
	var ball := false
	var owner := -1      # skater id with it on their stick
	var in_net := -1     # net index it's sitting in
	var alive := true
	var last_touch := -1
	var y := 0.0


class IcePylon:
	var pos := Vector2.ZERO
	var home := Vector2.ZERO
	var vel := Vector2.ZERO
	var up := true
	var angle := 0.0     # lying direction when tipped
	var tag := ""        # which drill set it out
	var placed := true   # false while it's still on the rack / in a coach's arms


var pucks: Array = []    # IcePuck
var pylons: Array = []   # IcePylon
var nets: Array = []     # {pos, face, size, half_w, depth, solid, goalie, goals, tag}
var pads: Array = []     # {a, b, placed}
var props: Array = []    # {id, pos, yaw} drawn once (racks, buckets)
var rng := RandomNumberGenerator.new()

var _mm := {}            # mesh id -> MultiMeshInstance3D
var _nodes := {}         # "net:i" / "pad:i" / "prop:i" -> MeshInstance3D
var _dirty := true


func add_puck(at: Vector2, blue := false, ball := false) -> int:
	var p := IcePuck.new()
	p.pos = at
	p.blue = blue
	p.ball = ball
	pucks.append(p)
	_dirty = true
	return pucks.size() - 1


## Pucks tipped out of a bucket at `at`: a little pile, all slightly moving.
func dump_bucket(at: Vector2, n: int, blue := false) -> Array:
	var out: Array = []
	for i in n:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.6
		var k := add_puck(at + Vector2(cos(a), sin(a)) * r, blue)
		pucks[k].vel = Vector2(cos(a), sin(a)) * rng.randf_range(0.0, 0.8)
		out.append(k)
	return out


func add_pylon(at: Vector2, tag := "", placed := true) -> int:
	var c := IcePylon.new()
	c.pos = at
	c.home = at
	c.tag = tag
	c.placed = placed
	pylons.append(c)
	_dirty = true
	return pylons.size() - 1


## `face`: the way the mouth opens (into the ice). `size`: "full" or "mini".
func add_net(at: Vector2, face: Vector2, size := "full", tag := "") -> int:
	var full := size == "full"
	nets.append({"pos": at, "face": face.normalized(), "size": size, "half_w": FULL_HALF_W if full else MINI_HALF_W,
		"depth": FULL_DEPTH if full else MINI_DEPTH, "solid": true, "goalie": -1, "goals": 0, "tag": tag})
	_dirty = true
	return nets.size() - 1


## A net that's done for this drill goes back to the side (off the ice, not solid).
func park_net(i: int, at: Vector2) -> void:
	if i < 0 or i >= nets.size():
		return
	nets[i].pos = at
	nets[i].solid = false
	nets[i].parked = true
	nets[i].goalie = -1
	for p: IcePuck in pucks:
		if p.in_net == i:
			p.in_net = -1
			p.pos = at + Vector2(0.0, 1.2)
			p.vel = Vector2.ZERO


## Brings a parked net of `size` (and `group`) out to a new spot; -1 if none.
func reuse_net(size: String, at: Vector2, face: Vector2, tag: String, group := "") -> int:
	for i in nets.size():
		var n: Dictionary = nets[i]
		if n.get("parked", false) and n.size == size and str(n.get("group", "")) == group:
			n.pos = at
			n.face = face.normalized()
			n.solid = true
			n.parked = false
			n.tag = tag
			n.goals = 0
			return i
	return -1


func add_pad(a: Vector2, b: Vector2, placed := false) -> int:
	pads.append({"a": a, "b": b, "placed": placed})
	_dirty = true
	return pads.size() - 1


func add_prop(id: String, at: Vector2, yaw := 0.0, y := 0.0) -> int:
	props.append({"id": id, "pos": at, "yaw": yaw, "y": y})
	_dirty = true
	return props.size() - 1


func count_nets(size: String) -> int:
	var n := 0
	for net: Dictionary in nets:
		n += 1 if net.size == size else 0
	return n


func free_pucks_near(at: Vector2, r: float) -> Array:
	var out: Array = []
	for i in pucks.size():
		var p: IcePuck = pucks[i]
		if p.alive and p.owner < 0 and p.in_net < 0 and not p.ball and p.pos.distance_to(at) <= r:
			out.append(i)
	out.sort_custom(func(a: int, b: int) -> bool: return pucks[a].pos.distance_to(at) < pucks[b].pos.distance_to(at))
	return out


func nearest_net(at: Vector2, tag := "") -> int:
	var best := -1
	var bd := INF
	for i in nets.size():
		var n: Dictionary = nets[i]
		if n.get("parked", false) or (tag != "" and str(n.tag) != tag):
			continue
		var d := at.distance_to(n.pos)
		if d < bd:
			bd = d
			best = i
	return best


## Lets go of a puck with a velocity (a shot or a pass).
func release(i: int, vel: Vector2) -> void:
	if i < 0 or i >= pucks.size():
		return
	var p: IcePuck = pucks[i]
	p.owner = -1
	p.vel = vel
	puck_hit.emit(Vector3(p.pos.x, 0.0, p.pos.y), "stick", vel.length())


## Pulls the pucks out of a net so they slide toward `toward` (a coach raking them out).
func rake_net(net: int, toward: Vector2) -> int:
	var n := 0
	for p: IcePuck in pucks:
		if p.in_net == net:
			p.in_net = -1
			var d := (toward - p.pos).normalized()
			p.pos = nets[net].pos + nets[net].face * 0.15 + Vector2(-d.y, d.x) * rng.randf_range(-0.4, 0.4)
			p.vel = d * rng.randf_range(1.5, 3.5)
			n += 1
	return n


func pylons_out_of_place(tag := "", tolerance := 0.3) -> Array:
	var out: Array = []
	for i in pylons.size():
		var c: IcePylon = pylons[i]
		if c.placed and (tag == "" or c.tag == tag) and (not c.up or c.pos.distance_to(c.home) > tolerance):
			out.append(i)
	return out


## A coach (or anybody) puts a pylon back on its spot.
func fix_pylon(i: int) -> void:
	var c: IcePylon = pylons[i]
	c.up = true
	c.pos = c.home
	c.vel = Vector2.ZERO


# --------------------------------------------------------------- physics

func step(dt: float, skaters: Array) -> void:
	var by_id := {}
	for s: IceSkater in skaters:
		by_id[s.id] = s
	for i in pucks.size():
		var p: IcePuck = pucks[i]
		if not p.alive:
			continue
		if p.owner >= 0:
			var s: IceSkater = by_id.get(p.owner)
			if s == null or s.hidden or s.down():
				p.owner = -1
				if s:
					s.puck = -1
				continue
			var fwd := s.forward()
			if s.backward:
				fwd = -fwd
			var side := Vector2(-fwd.y, fwd.x)
			var wob := sin(float(Time.get_ticks_msec()) * 0.009 + s.id) * 0.18
			p.pos = s.pos + fwd * (s.radius + 0.4) + side * wob
			p.vel = s.vel
			p.last_touch = s.id
			continue
		if p.in_net >= 0:
			continue
		_slide(p, dt)
		_puck_boards(p, i)
		_puck_nets(p, i)
		_puck_pads(p)
		_puck_pylons(p)
		_puck_skaters(p, i, skaters)
	for c: IcePylon in pylons:
		if not c.placed or c.up:
			continue
		var sp := c.vel.length()
		if sp > 0.0:
			c.vel = c.vel.normalized() * maxf(sp - 3.0 * dt, 0.0)
			c.pos += c.vel * dt
			var res := Rink.confine(Vector3(c.pos.x, 0, c.pos.y), PYLON_R)
			c.pos = Vector2(res[0].x, res[0].z)
	for c: IcePylon in pylons:
		if not c.placed or not c.up:
			continue
		for s: IceSkater in skaters:
			if s.hidden or not s.on_ice:
				continue
			var d := s.pos.distance_to(c.pos)
			if d < s.radius + PYLON_R * 0.6 and s.vel.length() > 1.0:
				if rng.randf() < 0.35 + (1.0 - s.skill) * 0.5:
					_tip(c, s.vel * 0.6)
				break


func _slide(p: IcePuck, dt: float) -> void:
	var sp := p.vel.length()
	if sp <= 0.0:
		return
	var decel := (1.4 if p.ball else 0.35) + sp * 0.015
	p.vel = p.vel / sp * maxf(sp - decel * dt, 0.0)
	p.pos += p.vel * dt


func _r(p: IcePuck) -> float:
	return BALL_R if p.ball else PUCK_R


func _puck_boards(p: IcePuck, _i: int) -> void:
	var res := Rink.confine(Vector3(p.pos.x, 0, p.pos.y), _r(p))
	var n: Vector2 = res[1]
	if n == Vector2.ZERO:
		return
	p.pos = Vector2(res[0].x, res[0].z)
	var vn := p.vel.dot(n)
	if vn > 0.0:
		p.vel -= n * vn * (1.0 + (0.4 if p.ball else 0.55))
		p.vel *= 0.92
		if vn > 1.5:
			puck_hit.emit(Vector3(p.pos.x, 0.05, p.pos.y), "boards", vn)


func _puck_nets(p: IcePuck, i: int) -> void:
	var r := _r(p)
	for ni in nets.size():
		var net: Dictionary = nets[ni]
		if net.get("parked", false):
			continue
		var face: Vector2 = net.face
		var side := Vector2(-face.y, face.x)
		var rel: Vector2 = p.pos - net.pos
		var lx := rel.dot(face)     # + in front of the goal line
		var lz := rel.dot(side)
		var hw: float = net.half_w
		var depth: float = net.depth
		# posts
		for sgn in [-1.0, 1.0]:
			var post: Vector2 = net.pos + side * hw * sgn
			var off := p.pos - post
			var d := off.length()
			if d < r + 0.04 and d > 0.0001:
				var nrm := off / d
				var vn := p.vel.dot(nrm)
				if vn < 0.0:
					p.vel -= nrm * vn * 1.6
					p.pos = post + nrm * (r + 0.041)
					puck_hit.emit(Vector3(post.x, 0.3, post.y), "post", -vn)
				return
		if lx < 0.0 and lx > -depth and absf(lz) < hw:
			# behind the goal line between the posts
			if p.vel.dot(face) < 0.0 and lx > -0.35:
				p.in_net = ni
				p.vel = Vector2.ZERO
				p.pos = net.pos - face * minf(0.3, depth * 0.6) + side * clampf(lz, -hw + 0.1, hw - 0.1)
				net.goals = int(net.goals) + 1
				puck_hit.emit(Vector3(p.pos.x, 0.2, p.pos.y), "net", 0.0)
				goal.emit(ni, i)
				return
		# the frame from outside: the back and the sides
		var hd := depth * 0.5
		var c: Vector2 = net.pos - face * hd
		var rel2 := p.pos - c
		var qx := rel2.dot(face)
		var qz := rel2.dot(side)
		if absf(qx) < hd + r and absf(qz) < hw + r and not (qx > hd - 0.05 and absf(qz) < hw):
			var ex := hd + r - absf(qx)
			var ez := hw + r - absf(qz)
			var nrm2 := face * signf(qx) if ex < ez else side * signf(qz)
			var vn2 := p.vel.dot(nrm2)
			if vn2 < 0.0:
				p.vel -= nrm2 * vn2 * 1.4
				puck_hit.emit(Vector3(p.pos.x, 0.1, p.pos.y), "net", -vn2)
			p.pos += nrm2 * minf(ex, ez)


func _puck_pads(p: IcePuck) -> void:
	var r := _r(p)
	for pad: Dictionary in pads:
		if not pad.placed:
			continue
		var a: Vector2 = pad.a
		var b: Vector2 = pad.b
		var ab := b - a
		var t := clampf((p.pos - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var q := a + ab * t
		var off := p.pos - q
		var d := off.length()
		if d < PAD_T + r:
			var nrm := off / d if d > 0.0001 else Vector2(1, 0)
			p.pos = q + nrm * (PAD_T + r)
			var vn := p.vel.dot(nrm)
			if vn < 0.0:
				p.vel -= nrm * vn * 1.45
				if -vn > 1.0:
					puck_hit.emit(Vector3(p.pos.x, 0.1, p.pos.y), "pad", -vn)


func _puck_pylons(p: IcePuck) -> void:
	for c: IcePylon in pylons:
		if not c.placed:
			continue
		var off := p.pos - c.pos
		var d := off.length()
		var reach := (PYLON_R if c.up else PYLON_R * 0.7) + _r(p)
		if d < reach and d > 0.0001:
			var nrm := off / d
			var vn := p.vel.dot(nrm)
			if vn < 0.0:
				if c.up and -vn > 2.0:
					_tip(c, -nrm * (-vn) * 0.3)
				elif not c.up:
					c.vel += -nrm * (-vn) * 0.25
				p.vel -= nrm * vn * 1.5
				p.vel *= 0.8
				puck_hit.emit(Vector3(c.pos.x, 0.15, c.pos.y), "pylon", -vn)
			p.pos = c.pos + nrm * reach


func _tip(c: IcePylon, push: Vector2) -> void:
	c.up = false
	c.vel = push
	c.angle = atan2(-push.x, -push.y) if push.length() > 0.01 else rng.randf() * TAU


func _puck_skaters(p: IcePuck, i: int, skaters: Array) -> void:
	var sp := p.vel.length()
	for s: IceSkater in skaters:
		if s.hidden or not s.on_ice or s.id == p.last_touch and sp > 4.0:
			continue
		var off := p.pos - s.pos
		var d := off.length()
		var reach := s.radius + _r(p) + (0.35 if s.catching and s.puck < 0 else 0.0)
		if d >= reach or d < 0.0001:
			continue
		if s.role == "goalie" and sp > 2.0:
			continue  # goalies are handled by the net's save logic
		if s.catching and s.puck < 0 and not s.down() and sp < 16.0:
			_take(p, i, s)
			return
		var nrm := off / d
		var vn := p.vel.dot(nrm)
		if vn < 0.0:
			p.vel -= nrm * vn * 1.3
			p.vel *= 0.7
			if -vn > 2.0:
				puck_hit.emit(Vector3(p.pos.x, 0.05, p.pos.y), "skate", -vn)
		p.pos = s.pos + nrm * (s.radius + _r(p))


func _take(p: IcePuck, i: int, s: IceSkater) -> void:
	p.owner = s.id
	p.last_touch = s.id
	s.puck = i
	s.catching = false


## The goalie in front of `net` gets a body on a puck coming at them.
func goalie_check(goalie: IceSkater, net: int) -> void:
	if goalie == null or goalie.down() or net < 0 or net >= nets.size():
		return
	var n: Dictionary = nets[net]
	for i in pucks.size():
		var p: IcePuck = pucks[i]
		if not p.alive or p.owner >= 0 or p.in_net >= 0:
			continue
		var sp := p.vel.length()
		if sp < 3.0 or p.vel.dot(n.face) > -1.0:
			continue
		if p.pos.distance_to(goalie.pos) < goalie.radius + 0.45:
			var chance := clampf(0.5 + 0.42 * goalie.skill - (sp - 15.0) * 0.012, 0.25, 0.95)
			if rng.randf() < chance:
				var out: Vector2 = n.face.rotated(rng.randf_range(-1.1, 1.1))
				p.vel = out * sp * rng.randf_range(0.12, 0.3)
				p.pos = goalie.pos + n.face * (goalie.radius + 0.1)
				p.last_touch = goalie.id
				puck_hit.emit(Vector3(p.pos.x, 0.3, p.pos.y), "goalie", sp)
				save.emit(net, i)
			else:
				p.last_touch = goalie.id  # through the five-hole


# ------------------------------------------------------------------ draw

func _process(_dt: float) -> void:
	draw()


func draw() -> void:
	if not is_inside_tree():
		return
	if _dirty:
		_rebuild()
	var lists := {"puck_black": [], "puck_blue": [], "ball": [], "pylon": []}
	for p: IcePuck in pucks:
		if not p.alive:
			continue
		var id := "ball" if p.ball else ("puck_blue" if p.blue else "puck_black")
		lists[id].append(Transform3D(Basis.IDENTITY, Vector3(p.pos.x, p.y, p.pos.y)))
	for c: IcePylon in pylons:
		if not c.placed:
			continue
		if c.up:
			lists.pylon.append(Transform3D(Basis.IDENTITY, Vector3(c.pos.x, 0, c.pos.y)))
		else:
			var bs := Basis(Vector3.UP, c.angle) * Basis(Vector3.RIGHT, -PI * 0.5)
			lists.pylon.append(Transform3D(bs, Vector3(c.pos.x, 0.09, c.pos.y)))
	for id in lists:
		var arr: Array = lists[id]
		var mmi: MultiMeshInstance3D = _mm.get(id)
		if mmi == null:
			mmi = MultiMeshInstance3D.new()
			mmi.name = "Gear_" + id
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = OnIceArt.mesh(id)
			mmi.multimesh = mm
			add_child(mmi)
			_mm[id] = mmi
		var m: MultiMesh = mmi.multimesh
		if m.instance_count < arr.size() or m.instance_count > arr.size() + 32:
			m.instance_count = arr.size() + 8
		for k in m.instance_count:
			m.set_instance_transform(k, arr[k] if k < arr.size() else Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(0, -50, 0)))
	for k in nets.size():
		var n: Dictionary = nets[k]
		var mi: MeshInstance3D = _nodes.get("net:%d" % k)
		if mi:
			var f: Vector2 = n.face
			mi.transform = Transform3D(Basis(Vector3.UP, atan2(-f.x, -f.y)), Vector3(n.pos.x, 0, n.pos.y))
	for k in pads.size():
		var mi2: MeshInstance3D = _nodes.get("pad:%d" % k)
		if mi2:
			mi2.visible = bool(pads[k].placed)


func _rebuild() -> void:
	_dirty = false
	for k in nets.size():
		var key := "net:%d" % k
		if not _nodes.has(key):
			var mi := MeshInstance3D.new()
			mi.name = "Net%d" % k
			mi.mesh = OnIceArt.mesh("full_net" if nets[k].size == "full" else "mini_net")
			add_child(mi)
			_nodes[key] = mi
	for k in pads.size():
		var key2 := "pad:%d" % k
		if not _nodes.has(key2):
			var pd: Dictionary = pads[k]
			var a: Vector2 = pd.a
			var b: Vector2 = pd.b
			var d := b - a
			var mi2 := MeshInstance3D.new()
			mi2.name = "Pad%d" % k
			mi2.mesh = OnIceArt.mesh("pad")
			mi2.transform = Transform3D(Basis(Vector3.UP, -atan2(d.y, d.x)), Vector3((a.x + b.x) * 0.5, 0, (a.y + b.y) * 0.5))
			add_child(mi2)
			_nodes[key2] = mi2
	for k in props.size():
		var key3 := "prop:%d" % k
		if not _nodes.has(key3):
			var pr: Dictionary = props[k]
			var at: Vector2 = pr.pos
			var mi3 := MeshInstance3D.new()
			mi3.name = "Prop_%s%d" % [pr.id, k]
			mi3.mesh = OnIceArt.mesh(str(pr.id))
			mi3.transform = Transform3D(Basis(Vector3.UP, float(pr.yaw)), Vector3(at.x, float(pr.y), at.y))
			add_child(mi3)
			_nodes[key3] = mi3


## Moves a prop (a bucket being carried, a rack) and redraws it.
func move_prop(k: int, at: Vector2, y := 0.0) -> void:
	if k < 0 or k >= props.size():
		return
	props[k].pos = at
	props[k].y = y
	var mi: MeshInstance3D = _nodes.get("prop:%d" % k)
	if mi:
		mi.position = Vector3(at.x, y, at.y)
