class_name DemoSkater
extends Node3D
## Skating in the demo with the game's own mechanics: a `Skater` (its
## strides, edges, dashes, stops and turn-arounds from PhysicsProfile), a
## `Puck` on its blade through StickPuck, and the keyboard + mouse scheme
## from HumanController and PlayerInput (WASD skates, Shift dashes, Space
## stops, R turns around, the mouse is the stick, LMB looks, RMB draws a
## shot pattern that fires on release, E passes). The demo's walker is
## carried along at the skater's eyes, looking down at the blade, its own
## head and torso hidden from its camera. Every stride, stop, turn and
## glide is written into the ice through `SkateWear`.

const SELF_LAYER := CameraRig.SELF_LAYER
const PUCK_SUBSTEPS := 4
const TURN_G := 3.0  # m/s2 of lateral load under which a turn leaves no edge mark
const SURE_REACH := Skater.REACH_ONE_HAND  # m from the body: a loose puck this close is yours
# The bond (Sean, 2026-10-26): a carried puck is stuck to the blade's face
# and slides only along it, heel to toe, centred by a spring. The slide is
# pushed by the blade's own acceleration along its length and by the ice's
# drag on the puck along the blade (nothing with the blade square to the
# motion, most with it angled); snow and water under the puck weaken the
# spring; past the toe or the heel it rolls off. Retention 1..10 sets the
# spring and how much of those pushes the tape lets through; 10 never lets go.
const BOND_K := Vector2(20.0, 400.0)  # spring, 1/s2, at retention 1 and 10
const BOND_ZETA := 0.8
const BOND_SLIDE := Vector2(0.5, 0.08)  # share of the pushes that move the puck, at 1 and 10
const BOND_OFF := 0.03  # m past the end of the blade: off
const BOND_LOOSE := 5  # below this retention the puck may roll off on clean ice too
const BOND_WEAK_OFF := 0.75  # the spring this weak (snow, water) lets the puck roll off
const LET_GO_T := 0.5  # s after a shot or a pass that the puck is meant to be gone
const BOND_SNOW := 2.0  # mm of snow that takes BOND_SNOW_K off the spring
const BOND_SNOW_K := 0.7
const BOND_WATER := 1.0  # mm of water that takes BOND_WATER_K off
const BOND_WATER_K := 0.5
const KNOB_VOX := 2  # voxels of the shaft's top (the knob; the taped grip stays) not drawn
const ROLL_OFF_T := 0.6  # s a rolled-off puck is loose before sure hands may have it back

var active := false
var stride_count := 0
## Sure hands (Sean): a loose puck anywhere the stick can reach, forehand
## or backhand, is picked up at once, and a carried puck is never lost
## (a shot or a pass still leaves the blade).
var sure_hands := true
## The ice on the puck (IceTouch): snow, water, slush, crust and ruts.
var ice_feel := true
## The mouse as hands (DemoHands): lead, weight, the swing's release.
var hands_on := true
var touch := IceTouch.new()
var hands: DemoHands
## Puck retention 1 (loose) to 10 (never lets go): the number keys.
var retention := 7
## The bond's slide along the blade, m from its middle (+ toward the toe), and its rate.
var bond_u := 0.0
var bond_v := 0.0
var bonded := false
var roll_offs := 0
## How the carried puck was lost, by cause (tests, tuning).
var losses := {"roll_off": 0, "game_slip": 0, "keep_drop": 0, "cross_drop": 0}
var game: DemoRinkGame
var skater: Skater
var controller: HumanController
var _off_t := 0.0
var _let_go := 0.0
var _blade_v0 := Vector2.ZERO
var _walker: Node3D
var _sheet: IceSheet
var _to_sheet: Callable
var _cull := 0xFFFFF
var _pitch := 0.0


## The skater on `puck` with an even 62 in every rating; `on_message`
## (text, seconds) takes the controller's shot and pass messages.
func setup(puck: Puck, on_message: Callable) -> void:
	game = DemoRinkGame.new()
	game.name = "Game"
	game.puck = puck
	game.hud.on_message = on_message
	add_child(game)
	skater = Skater.new()
	skater.name = "Skater"
	add_child(skater)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	skater.setup(game, 0, 9, Models.palette(0), Skills.create(Skills.SKATER_KEYS, 62.0, 0.0, rng))
	game.skaters = [skater]
	game.human = skater
	skater.stride.connect(_on_stride)
	skater.stop_spray.connect(_on_stop)
	skater.visible = false
	controller = DemoController.new()
	controller.name = "Controller"
	controller.game = game
	add_child(controller)
	hands = DemoHands.new()
	hands.name = "Hands"
	add_child(hands)
	hands.on_swing_end = _release_swing
	game.shot_hook = let_go
	controller.pass_hook = let_go
	# no body in the view (Sean: the hands got in the way): the stick and
	# its blade stay, everything else of you is on the layer the eyes skip
	var rig := skater.rig
	for part in (
		[rig.head, rig.torso, rig.hips, rig.arm_l, rig.arm_r, rig.leg_l, rig.leg_r]
		+ Array(rig.uppers)
		+ Array(rig.forearms)
		+ Array(rig.thighs)
		+ Array(rig.shins)
	):
		if part:
			part.layers = SELF_LAYER
	# no knob on the butt end (Sean: it sat big in the corner of the view,
	# right by the eyes); the taped grip stays so the stick looks whole
	if rig.stick and rig.stick.mesh:
		rig.stick.mesh = _without_top(rig.stick.mesh, KNOB_VOX * Models.STICK_V + 0.002)
		# (the rig rebuilds the shaft from its base mesh when the tuned size changes)
		if rig._shaft_base:
			rig._shaft_base = _without_top(rig._shaft_base, KNOB_VOX * Models.STICK_V + 0.002)


## `mesh` with every face in its top `cut` metres dropped (the stick's knob).
static func _without_top(mesh: Mesh, cut: float) -> Mesh:
	var y_cut := mesh.get_aabb().end.y - cut
	var out := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx_v: Variant = arr[Mesh.ARRAY_INDEX]
		var idx: PackedInt32Array = idx_v if idx_v != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(verts.size())
			for i in verts.size():
				idx[i] = i
		# the vertices of the faces kept, in order
		var kept := PackedInt32Array()
		for i in range(0, idx.size() - 2, 3):
			if (
				verts[idx[i]].y < y_cut
				and verts[idx[i + 1]].y < y_cut
				and verts[idx[i + 2]].y < y_cut
			):
				kept.append_array([idx[i], idx[i + 1], idx[i + 2]])
		if kept.is_empty():
			continue
		var trimmed := []
		trimmed.resize(Mesh.ARRAY_MAX)
		for k in Mesh.ARRAY_MAX:
			if k == Mesh.ARRAY_INDEX or arr[k] == null:
				continue
			var src: Variant = arr[k]
			var dst: Variant = src.duplicate()
			dst.resize(0)
			var per := 1
			if k == Mesh.ARRAY_TANGENT or k == Mesh.ARRAY_BONES or k == Mesh.ARRAY_WEIGHTS:
				per = src.size() / verts.size()
			for i in kept:
				for j in per:
					dst.append(src[i * per + j])
			trimmed[k] = dst
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(si), trimmed)
		out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(si))
	return out


## On the skates: the skater stands where the walker stands, facing its
## way; the walker rides the skater's eyes from here on.
func start(walker: Node3D) -> void:
	active = true
	stride_count = 0
	_walker = walker
	var yaw: float = walker.rotation.y
	skater.place(
		Vector2(walker.global_position.x, walker.global_position.z),
		Vector3(-sin(yaw), 0.0, -cos(yaw))
	)
	skater.visible = true
	walker.set("driven", true)
	walker.set("look_enabled", false)
	walker.call("set_noclip", true)
	var cam: Camera3D = walker.get("camera")
	var rig := game.camera_rig
	rig.cam = cam
	rig.yaw = yaw
	rig.look = Vector2.ZERO
	_cull = cam.cull_mask
	_pitch = cam.rotation.x
	cam.cull_mask = _cull & ~SELF_LAYER
	controller.player_input.capture_mouse()


func stop_skating() -> void:
	active = false
	skater.visible = false
	if _walker:
		_walker.set("driven", false)
		_walker.set("look_enabled", true)
		_walker.call("set_noclip", false)
		var cam: Camera3D = _walker.get("camera")
		cam.cull_mask = _cull
		cam.rotation.x = _pitch
		cam.position.y = FirstPerson.EYE
	_walker = null


## Tests and views drive the controls instead of the devices:
## `fn(frame: PlayerInput.Frame, dt)` fills the frame (null: the devices again).
func script(fn: Callable) -> void:
	controller.player_input.scripted = fn


## One tick: the controls read, the skater and the puck stepped, the
## walker's camera at the eyes, the ice marked (sheet metres through `to_sheet`).
func step(dt: float, sheet: IceSheet, to_sheet: Callable) -> void:
	if not active:
		return
	_sheet = sheet
	_to_sheet = to_sheet
	# the mouse is the stick for as long as you skate: the game's Esc lets it
	# go, and a loose cursor over the editor takes the next click there (Sean)
	if DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		controller.player_input.capture_mouse()
	var a0: Vector2 = to_sheet.call(skater.global_position)
	controller.update(dt)
	if hands_on:
		hands.shape(
			skater.ctrl,
			skater,
			dt,
			controller.player_input.mouse_sensitivity,
			skater.skill("stick_handling"),
			controller.player_input.frame.tracing
		)
	var puck := game.puck
	_let_go = maxf(0.0, _let_go - dt)
	var had := puck.controller == skater
	if had and skater.ctrl.pass_pressed:
		let_go()
	skater.physics_update(dt)
	if had and _slipped(puck):
		# the game's hands let it go (its stickhandling rhythm, a random
		# slip past the rating's pace): not here. The puck is where the
		# blade is, and it stays there (Sean: a solo skater on fresh ice
		# does not drop the puck)
		losses.game_slip += 1
		_retake(puck)
	var sdt := dt / PUCK_SUBSTEPS
	for i in PUCK_SUBSTEPS:
		var carried := puck.controller == skater
		var was_crossing := skater.crossing or skater.lifting
		StickPuck.step(game, puck, sdt, float(i + 1) / PUCK_SUBSTEPS)
		if carried and _slipped(puck):
			# the game's keep (out of the blade's reach while the stick goes
			# round the puck, or a reach the hands' lead took it past): the
			# same, it is still on the blade
			if was_crossing:
				losses.cross_drop += 1
			else:
				losses.keep_drop += 1
			_retake(puck)
		_bond(puck, sheet, to_sheet, sdt, float(i + 1) / PUCK_SUBSTEPS)
		puck.integrate(sdt)
		if ice_feel and puck.controller == null:
			touch.apply(puck, sheet, to_sheet, sdt)
		if sure_hands:
			_sure_hands()
	game.time += dt
	game.camera_rig.pull = hands.pull if hands_on else 0.0
	game.camera_rig.ride(skater, _walker, dt)
	# the ice under the blades
	var v := skater.speed()
	var a1: Vector2 = to_sheet.call(skater.global_position)
	if v > 0.05 and a1 != a0:
		var dir := (a1 - a0).normalized()
		if skater.turn_load > TURN_G:
			SkateWear.turn(sheet, a0, a1, dir, skater.turn_load, skater.yaw_rate > 0.0)
		SkateWear.glide(sheet, a0, a1, dir, v)


## A loose puck the stick can reach, or one that just slipped off the
## blade, is on the blade: the stick's own 220 degree arc and one-hand
## reach, no release in progress (a shot or a pass goes), the puck on the ice.
func _sure_hands() -> void:
	var puck := game.puck
	if puck.controller == skater or puck.frozen or puck.in_net_side != 0 or puck.out_of_play:
		return
	if _off_t > 0.0:
		return  # it rolled off the blade: go and get it
	if puck.position.y > StickPuck.BLADE_TOP:
		return
	var to := puck.position - skater.global_position
	to.y = 0.0
	# slipped off the blade: yours again, but a pass or a shot (let go,
	# fast, or already away) is gone
	if not _slipped(puck):
		if not puck.can_be_touched_by(skater):
			return
		if to.length() > SURE_REACH:
			return
		if (
			absf(skater.heading.signed_angle_to(to, Vector3.UP)) > Skater.ARC_HALF
			and to.length() > 0.3
		):
			return
	# yours: within the hands' feel the cup draws it onto the face from
	# where it is (no jump); further out it is on the blade at once
	puck.controller = skater
	puck.last_touch = skater
	if puck.position.distance_to(skater.blade_pos) > StickPuck.CARRY_REACH:
		var anchor := skater.puck_anchor()
		puck.position = Vector3(anchor.x, 0.0, anchor.z)
		puck.vel = skater.vel
	game.on_possession(skater)


## The carried puck on the blade's face, sliding along it on the bond's
## spring (see the consts). The bond rests while the blade is up (going
## round the puck, forehand to backhand): the puck runs on, the blade comes
## down beyond it, and the bond takes it where it meets the face.
func _bond(puck: Puck, sheet: IceSheet, to_sheet: Callable, dt: float, f: float) -> void:
	_off_t = maxf(0.0, _off_t - dt)
	var bv := Vector2(skater.blade_vel.x, skater.blade_vel.z)
	var blade_acc := (bv - _blade_v0) / maxf(dt, 0.0001)
	_blade_v0 = bv
	if puck.controller != skater or puck.frozen:
		bonded = false
		return
	if (
		skater.crossing
		or skater.lifting
		or skater.blade_height > StickPuck.BLADE_CLEAR + puck.position.y
	):
		bonded = false
		return
	if skater.winding or skater.move_id != &"":
		bonded = false
		return
	var seg := StickPuck.blade_at(skater, f)
	var c: Vector2 = seg[0]
	var ax: Vector2 = seg[1]
	var n: Vector2 = seg[2]
	var p := Vector2(puck.position.x, puck.position.z)
	if not bonded:
		# taken where it meets the face
		bonded = true
		var side := signf((p - c).dot(n))
		if side != 0.0:
			skater.puck_side = side
		elif skater.puck_side == 0.0:
			skater.puck_side = 1.0
		bond_u = clampf((p - c).dot(ax), -StickPuck.BLADE_HALF, StickPuck.BLADE_HALF)
		bond_v = Vector2(puck.vel.x - bv.x, puck.vel.z - bv.y).dot(ax)
	var t := clampf((retention - 1) / 9.0, 0.0, 1.0)
	var k := lerpf(BOND_K.x, BOND_K.y, t)
	var slide := lerpf(BOND_SLIDE.x, BOND_SLIDE.y, t)
	# the ice under the puck: snow and water loosen the tape's hold
	var a: Vector2 = to_sheet.call(puck.position)
	var snow := sheet.snow_at(a)
	var water := sheet.water_at(a)
	var weak := (
		1.0
		- BOND_SNOW_K * minf(snow / BOND_SNOW, 1.0)
		- BOND_WATER_K * minf(water / BOND_WATER, 1.0)
	)
	k *= maxf(weak, 0.1)
	# the pushes along the blade: the blade's own acceleration (the puck's
	# inertia) and the ice's drag on the puck (toward the trailing end)
	var push := -blade_acc.dot(ax)
	var sp := bv.length()
	if sp > 0.05:
		var drag := 0.12 + 0.035 * sp + IceTouch.SNOW_DRAG * minf(snow, IceTouch.SNOW_CAP)
		push -= drag * (bv / sp).dot(ax)
	push *= slide
	var cd := 2.0 * BOND_ZETA * sqrt(k)
	bond_v += (push - k * bond_u - cd * bond_v) * dt
	bond_u += bond_v * dt
	var may_roll := retention < BOND_LOOSE or weak < BOND_WEAK_OFF
	if absf(bond_u) > StickPuck.BLADE_HALF + BOND_OFF and may_roll and retention < 10:
		# off the end of the blade: loose, and not yours again for a moment.
		# On clean ice at the default retention it never does (Sean): the
		# puck rides the end of the blade instead. Snow or water under it,
		# or a low retention from the keys, lets it go
		roll_offs += 1
		losses.roll_off += 1
		bonded = false
		puck.controller = null
		puck.last_touch = skater
		puck.ignore_briefly(skater, ROLL_OFF_T)
		_off_t = ROLL_OFF_T
		puck.vel = Vector3(bv.x, 0.0, bv.y) + Vector3(ax.x, 0.0, ax.y) * bond_v
		return
	bond_u = clampf(bond_u, -StickPuck.BLADE_HALF - BOND_OFF, StickPuck.BLADE_HALF + BOND_OFF)
	var at := c + ax * bond_u + n * skater.puck_side * StickPuck.gap()
	puck.position = Vector3(at.x, 0.0, at.y)
	puck.vel = Vector3(bv.x, 0.0, bv.y) + Vector3(ax.x, 0.0, ax.y) * bond_v


## A shot or a pass is on its way (the game's shot, the flick pass, [E]):
## the puck is meant to leave, and nothing takes it straight back.
func let_go() -> void:
	_let_go = LET_GO_T


## A puck that just left the blade without being sent: still the skater's
## last touch, within arm's reach, and not let go (a shot or a pass is;
## the speed is only a backstop, a game slip can fling it at a fast sweep).
func _slipped(puck: Puck) -> bool:
	if puck.controller != null or _let_go > 0.0:
		return false
	if puck.last_touch != skater and puck.last_touch != null:
		return false
	var to := puck.position - skater.global_position
	to.y = 0.0
	var near := to.length() < 1.2 or puck.position.distance_to(skater.blade_pos) < 0.8
	return near and (puck.vel - skater.vel).length() < 15.0


## Back on the blade at once, no ignore timer (the game's slips set one).
func _retake(puck: Puck) -> void:
	puck.controller = skater
	puck.last_touch = skater
	puck.ignore_briefly(skater, 0.0)


## The swing ended (DemoHands): the shot goes now, as if RMB were let go.
func _release_swing() -> void:
	Input.action_release(&"shot_trace")


func _on_stride(at: Vector3, speed: float, foot: int) -> void:
	stride_count += 1
	if _sheet == null:
		return
	var h := skater.heading
	SkateWear.stride(_sheet, _to_sheet.call(at), Vector2(h.x, h.z), float(foot), speed)


func _on_stop(at: Vector3, speed: float) -> void:
	if _sheet == null:
		return
	var d := Vector2(skater.vel.x, skater.vel.z)
	if d.length() < 0.1:
		return
	SkateWear.stop(
		_sheet,
		_to_sheet.call(at),
		d.normalized(),
		speed,
		skater.profile.stop_decel,
		Skater.STOP_EVERY
	)


func vel2() -> Vector2:
	return Vector2(skater.vel.x, skater.vel.z)


func state_text() -> String:
	var puck_s := "LOOSE ON %s" % touch.surface
	if skater.has_puck():
		puck_s = (
			"ON THE %s %+.0f CM"
			% ["FOREHAND" if skater.puck_side >= 0.0 else "BACKHAND", bond_u * 100.0]
		)
	return (
		"SKATING %.1f M/S%s%s   STRIDES %d   PUCK %s   RETENTION %d   HANDS %.0f PX/S"
		% [
			skater.speed(),
			"  STOPPING" if skater.braking else "",
			"  BACKWARDS" if skater.backwards else "",
			stride_count,
			puck_s,
			retention,
			hands.hand_speed
		]
	)


## The blade, world: where a puck is carried.
func blade_world() -> Vector3:
	return skater.blade_pos
