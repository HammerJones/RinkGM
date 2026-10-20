class_name OnIceBroomball
extends OnIceGame
## Broomball (docs/world/ON_ICE.md 5): late evening after the beer league,
## college and community teams in sneakers with brooms and an orange ball,
## six a side, one ref. It wants the ice snowed up by the game before it: on
## freshly flooded (bare, wet) ice people's feet go out from under them.
## grip() is 0 (glass) to 1 (nicely snowed up) and drives the slips.
## Needs nets; no bucket of pucks.

var slip_rate := 0.0


func _spawn() -> void:
	super._spawn()
	var cfg := OnIceData.section("broomball")
	var g := grip()
	slip_rate = float(cfg.get("slip_per_second_bare", 0.05)) * (1.0 - g) + 0.002
	for s: IceSkater in skaters:
		s.shoes = true
		s.look["skates"] = false
		if s.role != "ref":
			s.role = "broomball" if s.role == "player" else s.role
			s.max_speed = float(cfg.get("run_speed", 3.4)) * lerpf(0.85, 1.1, s.skill) * lerpf(0.6, 1.0, g)
			s.accel = lerpf(1.6, 2.6, g)
		s.fall_rate = 0.0
	_draw.mark_dirty()


## How well sneakers hold: snow on the ice is good, a fresh wet flood is not.
func grip() -> float:
	var cfg := OnIceData.section("broomball")
	var snow := ice_snow()
	var wet := ice_wet()
	return clampf(snow / float(cfg.get("grip_snow", 0.25)), 0.0, 1.0) * clampf(1.0 - wet * 1.5, 0.0, 1.0)


func look_for(role: String, age: int, extra := {}) -> Dictionary:
	if role == "player" or role == "goalie":
		var l := super.look_for("broomball", age, extra)
		if role == "goalie":
			l.accessory = "helmet"
		return l
	var l2 := super.look_for(role, age, extra)
	l2.skates = false
	return l2


func doors_closed() -> bool:
	return true


func _start_bucket() -> void:
	# no pucks to bring: a ball, and a quick knock-around
	for side in 2:
		for sid in teams[side].skaters + teams[side].goalies:
			by_id(sid).task = {"state": "warmup"}
	game_phase = "warmup"
	phase_t = 0.0


func _start_warmup(fast: bool) -> void:
	game_phase = "warmup"
	phase_t = 0.0
	if fast:
		_put_nets()
		for side in 2:
			for sid in teams[side].skaters + teams[side].goalies:
				var s := by_id(sid)
				s.on_ice = true
				s.pos = Vector2(-teams[side].dir * rng.randf_range(4.0, 22.0), rng.randf_range(-9.0, 9.0))


func _warmup() -> void:
	# a few minutes of running about on their own end
	for side in 2:
		for sid in teams[side].skaters + teams[side].goalies:
			var s := by_id(sid)
			if s and not s.down():
				route(s, _half_point(side, s) + Vector2(sin(t * 0.3 + s.id) * 3.0, cos(t * 0.2 + s.id) * 2.0), 2.0)


func _shot_scale() -> float:
	return 0.45  # a broom and a ball


func _think(dt: float) -> void:
	super._think(dt)
	# sneakers on ice: running, cutting and stopping all risk a slip
	for s: IceSkater in skaters:
		if s.hidden or not s.on_ice or s.down() or s.role == "ref":
			continue
		var effort := clampf(s.vel.length() / maxf(s.max_speed, 0.1), 0.0, 1.0) + (0.6 if s.speed_want < 0.1 and s.vel.length() > 1.5 else 0.0)
		if rng.randf() < slip_rate * (0.3 + effort) * dt:
			s.fall(rng)
			on_fell(s)
