class_name CameraRig
extends Node3D
## Follow camera. The camera button cycles the views:
##   END        behind the play, looking down the length of the ice at the net
##              you attack (the default)
##   FIRST      first person, from your skater's eyes
##   BROADCAST  the side-on TV view
##   ISOMETRIC  orthographic, matching the reference renders
## The human's controls are camera-relative (HumanController reads
## forward_flat / right_flat), so "up" on the stick is always into the screen.
## Holding free look (LMB / LB) turns the view from where the camera stands
## without turning the controls; letting go eases it back.

enum Mode { END, FIRST, BROADCAST, ISOMETRIC }

var mode := Mode.END
var cam: Camera3D
var _center := Vector3.ZERO
var _end_dir := 1.0       # +1 attacking +x, -1 attacking -x (swaps between periods)
var _fp_yaw := 0.0
var _fp_pitch := 0.0
var _hidden_rig: Node3D
var zoom := 16.0
## Free look: yaw (right +) and pitch (up +) on top of the mode's view.
var look := Vector2.ZERO
var looking := false
var _base_basis := Basis.IDENTITY   # the view before free look: the controls use it
const LOOK_YAW := deg_to_rad(160.0)
const LOOK_PITCH := deg_to_rad(55.0)

const END_BACK := 10.5    # how far behind the focus the end camera sits
const END_HEIGHT := 6.5
const END_AHEAD := 7.0    # it looks at a point this far up the ice
const EYE_HEIGHT := 1.55
const FP_PITCH := deg_to_rad(-36.0)   # looks down enough to see the blade


func _ready() -> void:
	cam = Camera3D.new()
	cam.far = 300.0
	add_child(cam)
	cam.current = true
	# `-- --camera=end|first|broadcast|iso` starts in that view
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--camera="):
			var names := ["end", "first", "broadcast", "iso"]
			mode = maxi(0, names.find(arg.trim_prefix("--camera="))) as Mode
	_place()


func toggle() -> void:
	set_mode((mode + 1) % Mode.size())


func set_mode(m: Mode) -> void:
	mode = m
	_show_body()
	if mode == Mode.FIRST:
		var h := _human()
		if h:
			_fp_yaw = atan2(-h.heading.x, -h.heading.z)
	_place()


## Adds `delta` (radians, x right, y up) to the free look while `held`.
func free_look(delta: Vector2, held: bool) -> void:
	looking = held and mode != Mode.ISOMETRIC
	if looking:
		look.x = clampf(look.x + delta.x, -LOOK_YAW, LOOK_YAW)
		look.y = clampf(look.y + delta.y, -LOOK_PITCH, LOOK_PITCH)


func follow(focus: Vector3, dt: float) -> void:
	if not looking:
		look = look.lerp(Vector2.ZERO, 1.0 - exp(-6.0 * dt))
	var h := _human()
	if h:
		var ax := h.attack_goal().x
		if ax != 0.0:
			_end_dir = signf(ax)
	if mode == Mode.FIRST and h:
		_follow_eyes(h, dt)
		return
	var target := Vector3(clampf(focus.x, -24.0, 24.0), 0, clampf(focus.z, -6.0, 6.0) * 0.5)
	if mode == Mode.END:
		# down the ice the side-to-side play matters, the length can lag a little
		target = Vector3(clampf(focus.x, -26.0, 26.0), 0, clampf(focus.z, -11.0, 11.0) * 0.7)
	_center = _center.lerp(target, 1.0 - exp(-3.0 * dt))
	_place()


func forward_flat() -> Vector3:
	var f := -_base_basis.z
	f.y = 0.0
	return f.normalized()


func right_flat() -> Vector3:
	var r := _base_basis.x
	r.y = 0.0
	return r.normalized()


## Projects the mouse onto the ice plane, or returns null.
func mouse_on_ice() -> Variant:
	var mp := get_viewport().get_mouse_position()
	var origin := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	if absf(dir.y) < 0.0001:
		return null
	var t := -origin.y / dir.y
	if t < 0.0:
		return null
	return origin + dir * t


func _human() -> Skater:
	var g := get_parent()
	return g.get("human") as Skater if g else null


## First person: eyes in the head, turning with the skater (smoothed so the
## stride doesn't shake the view), looking down past the chest at the blade.
## Your own head and torso are drawn on a layer this camera skips (they still
## cast shadows), so the view isn't filled with jersey; arms and stick show.
func _follow_eyes(h: Skater, dt: float) -> void:
	var want := atan2(-h.heading.x, -h.heading.z)
	_fp_yaw = lerp_angle(_fp_yaw, want, 1.0 - exp(-9.0 * dt))
	_fp_pitch = lerpf(_fp_pitch, FP_PITCH, 1.0 - exp(-6.0 * dt))
	var eye := h.global_position + Vector3(0, EYE_HEIGHT, 0)
	if h.rig and h.rig.head:
		eye = h.rig.head.global_position + Vector3(0, 0.1, 0) + h.heading * 0.12
		_hide_body(h.rig)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 85.0
	cam.near = 0.05
	cam.cull_mask = ~SELF_LAYER
	cam.transform = Transform3D(Basis.from_euler(Vector3(_fp_pitch, _fp_yaw, 0)), eye)
	_center = h.global_position
	_apply_look()


const SELF_LAYER := 1 << 19


func _hide_body(rig: Node3D) -> void:
	if _hidden_rig != rig:
		_show_body()
		_hidden_rig = rig
	for part in [rig.head, rig.torso]:
		if part:
			part.layers = SELF_LAYER


func _show_body() -> void:
	if is_instance_valid(_hidden_rig):
		for part in [_hidden_rig.head, _hidden_rig.torso]:
			if part:
				part.layers = 1
	_hidden_rig = null
	if cam:
		cam.cull_mask = 0xFFFFF


func _place() -> void:
	if cam == null:
		return
	cam.near = 0.05
	match mode:
		Mode.END:
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			cam.fov = 55.0
			var back := Vector3(-_end_dir * END_BACK, END_HEIGHT, 0)
			cam.position = _center + back
			cam.look_at(_center + Vector3(_end_dir * END_AHEAD, 0, 0), Vector3.UP)
		Mode.BROADCAST:
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			cam.fov = 45.0
			cam.position = _center + Vector3(0, 12.0, 13.5)
			cam.look_at(_center + Vector3(0, 0, -1.0), Vector3.UP)
		Mode.ISOMETRIC:
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = zoom
			cam.position = _center + Vector3(-22.0, 25.0, 22.0)
			cam.look_at(_center, Vector3.UP)
		Mode.FIRST:
			# placed by follow() once there is a skater to look out of
			return
	_apply_look()


## Turns the view by the free look, from where the camera stands.
func _apply_look() -> void:
	_base_basis = cam.basis
	if mode == Mode.ISOMETRIC or look.is_zero_approx():
		return
	cam.basis = (Basis(Vector3.UP, -look.x) * _base_basis * Basis(Vector3.RIGHT, look.y)).orthonormalized()
