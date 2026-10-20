class_name OnIceMotion
extends RefCounted
## Moves IceSkaters like bodies on skates (or in sneakers): momentum, a top
## speed, quicker stops than starts, steering round each other, the boards,
## the nets and any zone they're kept in, falls and getting back up. After
## every step no two solid bodies overlap (a positional pass pushes apart
## whatever the steering didn't avoid), so nobody clips through anybody.
##
##   OnIceMotion.step(skaters, dt, rng, nets, hooks)
##
## `nets`: OnIceGear net dictionaries (solid frames). `hooks` (all optional
## Callables): "fell" (s), "stride" (s) once per stride, "bump" (a, b, speed).

const CELL := 1.6
const LOOK_AHEAD := 2.2
const GAP := 0.08          # what steering keeps between shoulders
const RESOLVE_ITERS := 4


static func step(list: Array, dt: float, rng: RandomNumberGenerator, nets: Array = [], hooks := {}) -> void:
	if dt <= 0.0:
		return
	var grid := _grid(list)
	for s: IceSkater in list:
		if s.hidden:
			continue
		_timers(s, dt, rng, hooks)
		var desired := _desired(s)
		if s.solid and not s.down():
			desired += _avoid(s, grid)
		_integrate(s, desired, dt)
		if s.state == "skate" and s.on_ice and not s.shoes and s.fall_rate > 0.0:
			var sp := s.vel.length() / maxf(s.max_speed, 0.1)
			if rng.randf() < s.fall_rate * (0.35 + sp) * dt:
				s.fall(rng)
				_call(hooks, "fell", [s])
		_confine(s, nets)
	grid = _grid(list)
	for i in RESOLVE_ITERS:
		if not _resolve(list, grid, rng, hooks if i == 0 else {}):
			break
		for s: IceSkater in list:
			if not s.hidden:
				_confine(s, nets)
	for s: IceSkater in list:
		if not s.hidden:
			_face_and_pose(s, dt, hooks)


## True when two solid, visible bodies overlap by more than `slack` metres.
static func overlaps(list: Array, slack := 0.02) -> Array:
	var out: Array = []
	for i in list.size():
		var a: IceSkater = list[i]
		if a.hidden or not a.solid:
			continue
		for j in range(i + 1, list.size()):
			var b: IceSkater = list[j]
			if b.hidden or not b.solid or a.on_ice != b.on_ice:
				continue
			if a.pos.distance_to(b.pos) < a.radius + b.radius - slack:
				out.append([a, b])
	return out


# ------------------------------------------------------------------ pieces

static func _grid(list: Array) -> Dictionary:
	var g := {}
	for s: IceSkater in list:
		if s.hidden or not s.solid:
			continue
		var k := _key(s.pos)
		if not g.has(k):
			g[k] = []
		g[k].append(s)
	return g


static func _key(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


static func _timers(s: IceSkater, dt: float, rng: RandomNumberGenerator, _hooks: Dictionary) -> void:
	if s.state == "fallen":
		s.state_t -= dt
		if s.state_t <= 0.0:
			s.state = "getting_up"
			s.state_t = rng.randf_range(1.0, 2.2) * (1.3 if s.age < 8 else 1.0)
	elif s.state == "getting_up":
		s.state_t -= dt
		if s.state_t <= 0.0:
			s.state = "skate"


static func _desired(s: IceSkater) -> Vector2:
	if s.down() or s.speed_want <= 0.0:
		return Vector2.ZERO
	var to := s.target - s.pos
	var d := to.length()
	if d < 0.05:
		return Vector2.ZERO
	# arrive: slow so they can stop by the target
	var v := minf(s.speed_want, sqrt(2.0 * s.brake * 0.6 * maxf(d - s.arrive * 0.3, 0.0)) + 0.3)
	return to / d * v


## Separation from neighbours and a sidestep round whoever is ahead.
static func _avoid(s: IceSkater, grid: Dictionary) -> Vector2:
	var push := Vector2.ZERO
	var k := _key(s.pos)
	var fwd := s.vel.normalized() if s.vel.length() > 0.3 else Vector2.ZERO
	var spd := s.vel.length()
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var cell: Array = grid.get(Vector2i(k.x + dx, k.y + dz), [])
			for n: IceSkater in cell:
				if n == s or n.on_ice != s.on_ice:
					continue
				var off := s.pos - n.pos
				var dist := off.length()
				var near := s.radius + n.radius + GAP
				if n.id == s.partner:
					near = s.radius + n.radius + 0.02
				if dist < 0.0001:
					off = Vector2(cos(s.id), sin(s.id))
					dist = 0.0001
				if dist < near + 0.7:
					var w := (near + 0.7 - dist) / 0.7
					push += off / dist * w * w * (2.5 + spd * 0.4)
				# someone ahead in my lane: go round them, on the side I'm already on
				if fwd != Vector2.ZERO and dist < LOOK_AHEAD + spd * 0.4 and n.id != s.partner:
					var ahead := -off.dot(fwd)
					if ahead > 0.0:
						var lat := -off - fwd * ahead
						var clear := near + 0.25
						if lat.length() < clear:
							var side := Vector2(-fwd.y, fwd.x)
							var sgn := -1.0 if lat.dot(side) > 0.0 else 1.0
							if lat.length() < 0.02:
								sgn = 1.0 if (s.id & 1) == 0 else -1.0
							var rel := maxf(spd - n.vel.dot(fwd), 0.2)
							push += side * sgn * rel * (1.0 - ahead / (LOOK_AHEAD + spd * 0.4)) * 1.2
	return push


static func _integrate(s: IceSkater, desired: Vector2, dt: float) -> void:
	var dv := desired - s.vel
	var lim := s.accel
	if s.down():
		lim = 2.5  # sliding on their backside
	elif desired.length() < s.vel.length() or desired.dot(s.vel) < 0.0:
		lim = s.brake
	if s.shoes:
		lim *= 0.6  # sneakers on ice: nothing to push or stop with
	if dv.length() > lim * dt:
		dv = dv.normalized() * lim * dt
	s.vel += dv
	var cap := s.max_speed * 1.15
	if s.vel.length() > cap:
		s.vel = s.vel.normalized() * cap
	s.pos += s.vel * dt


static func _confine(s: IceSkater, nets: Array) -> void:
	if s.on_ice:
		var p := s.pos
		var d := Rink.sdf(p)
		if d > -s.radius:
			var n := Rink.board_normal(p)
			s.pos = p - n * (d + s.radius)
			var out := s.vel.dot(n)
			if out > 0.0:
				s.vel -= n * out * 1.2
		for net: Dictionary in nets:
			_push_out_of_net(s, net)
	# the box holds whoever is in it; someone walking back to it from outside isn't teleported in
	if s.box.size != Vector2.ZERO and s.box.grow(1.0).has_point(s.pos):
		var r := s.radius
		var x0 := s.box.position.x + r
		var x1 := s.box.end.x - r
		var z0 := s.box.position.y + r
		var z1 := s.box.end.y - r
		var p2 := Vector2(clampf(s.pos.x, x0, maxf(x0, x1)), clampf(s.pos.y, z0, maxf(z0, z1)))
		if p2.x != s.pos.x:
			s.vel.x = 0.0
		if p2.y != s.pos.y:
			s.vel.y = 0.0
		s.pos = p2


## A net is a solid box from its goal line back `depth` metres.
static func _push_out_of_net(s: IceSkater, net: Dictionary) -> void:
	if not net.get("solid", true):
		return
	var face: Vector2 = net.face
	var side := Vector2(-face.y, face.x)
	var hw: float = net.half_w + 0.06
	var hd: float = net.depth * 0.5
	var c: Vector2 = net.pos - face * hd
	var rel := s.pos - c
	var lx := rel.dot(face)
	var lz := rel.dot(side)
	var qx := clampf(lx, -hd, hd)
	var qz := clampf(lz, -hw, hw)
	var closest := c + face * qx + side * qz
	var off := s.pos - closest
	var d := off.length()
	if d < s.radius:
		if d < 0.0001:
			# inside the box: out the nearest face
			var ex := hd - absf(lx)
			var ez := hw - absf(lz)
			if ex < ez:
				off = face * signf(lx if lx != 0.0 else 1.0)
				s.pos = c + face * (signf(lx if lx != 0.0 else 1.0) * (hd + s.radius)) + side * lz
			else:
				off = side * signf(lz if lz != 0.0 else 1.0)
				s.pos = c + face * lx + side * (signf(lz if lz != 0.0 else 1.0) * (hw + s.radius))
		else:
			s.pos = closest + off / d * s.radius
			off = off / d
		var into := s.vel.dot(off)
		if into < 0.0:
			s.vel -= off * into


## Pushes overlapping bodies apart; a hard knock can put a shaky skater down.
static func _resolve(list: Array, grid: Dictionary, rng: RandomNumberGenerator, hooks: Dictionary) -> bool:
	var any := false
	var seen := {}
	for s: IceSkater in list:
		if s.hidden or not s.solid:
			continue
		var k := _key(s.pos)
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var cell: Array = grid.get(Vector2i(k.x + dx, k.y + dz), [])
				for n: IceSkater in cell:
					if n.id <= s.id or n.on_ice != s.on_ice:
						continue
					var off := s.pos - n.pos
					var dist := off.length()
					var need := s.radius + n.radius + 0.005
					if dist >= need:
						continue
					any = true
					if dist < 0.0001:
						off = Vector2(1, 0).rotated(float(s.id * 7 + n.id))
						dist = 0.0001
					var nrm := off / dist
					var corr := (need - dist)
					# the one standing still or down gets pushed less
					var ws := 0.5
					if s.down() and not n.down():
						ws = 0.3
					elif n.down() and not s.down():
						ws = 0.7
					s.pos += nrm * corr * ws
					n.pos -= nrm * corr * (1.0 - ws)
					var rel := (s.vel - n.vel).dot(nrm)
					if rel < 0.0:
						# inelastic: they share the closing speed
						s.vel -= nrm * rel * 0.5
						n.vel += nrm * rel * 0.5
						var key := s.id * 100003 + n.id
						if not hooks.is_empty() and not seen.has(key) and -rel > 1.2:
							seen[key] = true
							_call(hooks, "bump", [s, n, -rel])
							for who: IceSkater in [s, n]:
								if who.on_ice and not who.shoes and who.state == "skate" and rng.randf() < clampf((-rel - 1.0) * 0.35 * (1.0 - who.skill), 0.0, 0.9):
									who.fall(rng)
									_call(hooks, "fell", [who])
	return any


static func _face_and_pose(s: IceSkater, dt: float, hooks: Dictionary) -> void:
	var spd := s.vel.length()
	if s.down():
		s.pose = PeopleArt.Pose.FALL if s.state == "fallen" else PeopleArt.Pose.WORK
		return
	var want_yaw := s.yaw
	if spd > 0.35:
		var d := -s.vel if s.backward else s.vel
		want_yaw = atan2(-d.x, -d.y)
	elif s.face != Vector2.ZERO:
		want_yaw = atan2(-s.face.x, -s.face.y)
	s.yaw = lerp_angle(s.yaw, want_yaw, clampf(dt * 7.0, 0.0, 1.0))
	if s.spin_rate != 0.0:
		s.yaw = wrapf(s.yaw + s.spin_rate * dt, -PI, PI)
	var skating := s.on_ice and not s.shoes and bool(s.look.get("skates", true))
	var rate := PeopleArt.skate_phase_rate(spd) if skating else PeopleArt.walk_phase_rate(spd, s.look, s.age)
	var before := s.phase
	if spd > 0.2:
		s.phase = fmod(s.phase + dt * rate, 1.0)
		if s.phase < before and skating and spd > 1.0:
			_call(hooks, "stride", [s])
	if s.pose_lock >= 0:
		s.pose = s.pose_lock
	elif s.carry != "":
		s.pose = PeopleArt.Pose.CARRY
	elif skating:
		if spd > 0.35:
			s.pose = PeopleArt.Pose.SKATE_WOBBLY if s.skill < 0.28 else PeopleArt.Pose.SKATE
		else:
			s.pose = PeopleArt.Pose.STAND
	else:
		s.pose = PeopleArt.Pose.WALK if spd > 0.25 else PeopleArt.Pose.STAND


static func _call(hooks: Dictionary, key: String, args: Array) -> void:
	var c: Variant = hooks.get(key)
	if c is Callable and (c as Callable).is_valid():
		(c as Callable).callv(args)
