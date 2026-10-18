extends Node3D
## Animation studio: one skater on a treadmill acting out each animation in
## turn (AnimClips), seen from three cameras, with live sliders for every
## AnimTuning number the clip uses. Run scenes/anim/anim_studio.tscn.
##
## Keys: LEFT / RIGHT clip, SPACE pause, S slow motion (1, 1/2, 1/4),
## T turntable, C main camera, TAB tuning panel. The panel's SAVE writes
## assets/anim/anim_tuning.tres, which the game then uses.
##
## Command line (after `--`):
##   --clip=<id>          start on this clip (ids in AnimClips.LIST)
##   --reel               play every clip (or --clips=a,b,c) once and quit,
##                        printing "SEG <seconds> <id>" at each clip's start
##   --loops=<n>          loops of each clip in the reel (default 2)
##   --turntable=<deg/s>  spin the skater for the main camera (default 0)
##   --cam=<name>         three_quarter, side, front, back or top
##   --no-insets          hide the side and front views
##   --test=anim          headless check of every clip (used by tools/ci.sh)
## Record a reel with Godot's movie writer:
##   godot --path . --write-movie reel.avi --fixed-fps 30 --resolution 1280x720 \
##     res://scenes/anim/anim_studio.tscn -- --reel

const CAMS := {
	"three_quarter": Vector3(35.0, 1.5, 5.2),  # degrees round from the front, height, distance
	"side": Vector3(90.0, 1.0, 4.6),
	"front": Vector3(0.0, 1.0, 4.6),
	"back": Vector3(180.0, 1.4, 5.2),
	"top": Vector3(20.0, 6.0, 3.0),
}
const SPEEDS := [1.0, 0.5, 0.25]


class Stats:
	extends RefCounted
	var shots := 0
	var checks := 0


var puck: Puck
var stats := Stats.new()
var puppet: AnimPuppet
var tuning := AnimTuning.current()

var _clip := 0
var _t := 0.0
var _loops := 0
var _mem := {}
var _paused := false
var _speed_i := 0
var _turntable := 0.0
var _cam_name := "three_quarter"
var _cam: Camera3D
var _insets: Array[Camera3D] = []
var _inset_box: Control
var _insets_on := true
var _ice_mat: ShaderMaterial
var _ice_offset := Vector2.ZERO
var _puck_air := 0.0

var _reel := false
var _reel_loops := 2
var _reel_list: Array = []
var _reel_i := 0
var _clock := 0.0
var _test := false
var _test_log := {}
var _test_fail: Array[String] = []

var _title: Label
var _note: Label
var _hint: Label
var _panel: PanelContainer
var _sliders: VBoxContainer
var _status: Label


func is_frozen() -> bool:
	return false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var only: Array = []
	var start := &""
	var insets := true
	for a in args:
		if a.begins_with("--clip="):
			start = StringName(a.trim_prefix("--clip="))
		elif a == "--reel":
			_reel = true
		elif a.begins_with("--clips="):
			only = Array(a.trim_prefix("--clips=").split(",")).map(func(x): return StringName(x))
		elif a.begins_with("--loops="):
			_reel_loops = maxi(1, a.trim_prefix("--loops=").to_int())
		elif a.begins_with("--turntable="):
			_turntable = a.trim_prefix("--turntable=").to_float()
		elif a.begins_with("--cam="):
			_cam_name = a.trim_prefix("--cam=")
		elif a == "--no-insets":
			insets = false
		elif a == "--test=anim":
			_test = true
	_build_world()
	_build_puppet()
	_build_ui()
	_insets_on = insets and not _test
	_inset_box.visible = _insets_on
	if _test:
		_reel = true
		_reel_loops = 1
	if _reel:
		for c in AnimClips.LIST:
			if only.is_empty() or c.id in only:
				_reel_list.append(AnimClips.index_of(c.id))
		_panel.visible = false
		_hint.visible = false
		_start_clip(_reel_list[0])
	else:
		_start_clip(maxi(0, AnimClips.index_of(start)))


# ------------------------------------------------------------------ world

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = RinkOS.CRT
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("b8c8e0")
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 12.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25.0, -150.0, 0.0)
	fill.light_energy = 0.35
	add_child(fill)

	# the treadmill: a disc of ice whose markings slide under the skater
	var ice := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 3.2
	disc.bottom_radius = 3.2
	disc.height = 0.2
	disc.radial_segments = 64
	ice.mesh = disc
	ice.position.y = -0.1
	_ice_mat = ShaderMaterial.new()
	_ice_mat.shader = _ice_shader()
	ice.material_override = _ice_mat
	add_child(ice)
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 3.18
	ring.outer_radius = 3.3
	ring.rings = 64
	rim.mesh = ring
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = RinkOS.BEZEL
	rim.material_override = rim_mat
	rim.scale.y = 0.5
	add_child(rim)

	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.h_offset = 0.8  # skater left of centre, clear of the side views
	add_child(_cam)
	_cam.make_current()


func _ice_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec2 offset;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float line(float v, float spacing, float w) {
	float f = abs(fract(v / spacing + 0.5) - 0.5) * spacing;
	return 1.0 - smoothstep(w, w + 0.01, f);
}
void fragment() {
	vec2 p = wpos.xz + offset;
	vec3 ice = vec3(0.86, 0.91, 0.96);
	float grid = max(line(p.x, 1.0, 0.012), line(p.y, 1.0, 0.012));
	float blue = line(p.x, 6.0, 0.15);
	float red = line(p.x + 3.0, 6.0, 0.08);
	float dots = 1.0 - smoothstep(0.1, 0.12, length(fract(p / 3.0) * 3.0 - 1.5));
	vec3 col = mix(ice, vec3(0.62, 0.72, 0.84), grid * 0.6);
	col = mix(col, vec3(0.16, 0.33, 0.72), blue);
	col = mix(col, vec3(0.78, 0.12, 0.14), max(red, dots));
	float r = length(wpos.xz);
	col = mix(col, vec3(0.04, 0.07, 0.12), smoothstep(2.6, 3.2, r) * 0.6);
	ALBEDO = col;
	ROUGHNESS = 0.25;
	SPECULAR = 0.6;
}
"""
	return sh


func _build_puppet() -> void:
	puck = Puck.new()
	puck.visible = false
	add_child(puck)
	puppet = AnimPuppet.new()
	add_child(puppet)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	# middling, fixed ratings so wind-ups play the same every run
	puppet.setup(self, 0, 9, Models.palette(0), Skills.create(Skills.SKATER_KEYS, 55.0, 0.0, rng))
	puppet.restart(Vector3.FORWARD)


# --------------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var head := VBoxContainer.new()
	head.position = Vector2(24, 18)
	head.add_theme_constant_override("separation", 2)
	root.add_child(head)
	head.add_child(RinkOS.label("// ANIMATION STUDIO ---- TREADMILL", RinkOS.PIXEL))
	_title = RinkOS.label("", RinkOS.TITLE)
	head.add_child(_title)
	_note = RinkOS.label("", RinkOS.TERM)
	head.add_child(_note)

	_hint = RinkOS.label("%s/%s CLIP   %s PAUSE   %s SLOW   %s TURNTABLE   %s CAMERA   %s TUNING" % [
		RinkOS.key("LEFT"), RinkOS.key("RIGHT"), RinkOS.key("SPACE"), RinkOS.key("S"), RinkOS.key("T"),
		RinkOS.key("C"), RinkOS.key("TAB")], RinkOS.TERM_DIM)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.position = Vector2(24, -44)
	root.add_child(_hint)

	# side and front views down the right edge
	_inset_box = VBoxContainer.new()
	_inset_box.anchor_left = 1.0
	_inset_box.anchor_right = 1.0
	_inset_box.offset_left = -296
	_inset_box.offset_right = -16
	_inset_box.offset_top = 16
	_inset_box.add_theme_constant_override("separation", 6)
	root.add_child(_inset_box)
	for v in ["side", "front"]:
		var box := VBoxContainer.new()
		box.add_child(RinkOS.label("// " + v.to_upper(), RinkOS.PIXEL))
		var svc := SubViewportContainer.new()
		svc.stretch = true
		svc.custom_minimum_size = Vector2(280, 300)
		var sv := SubViewport.new()
		sv.world_3d = get_viewport().world_3d
		sv.msaa_3d = Viewport.MSAA_2X
		var c := Camera3D.new()
		c.fov = 40.0
		c.set_meta("view", v)
		sv.add_child(c)
		svc.add_child(sv)
		box.add_child(svc)
		_inset_box.add_child(box)
		_insets.append(c)

	# tuning sliders for the clip's groups, on the right
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -446
	_panel.offset_right = -16
	_panel.offset_top = 16
	_panel.offset_bottom = -16
	_panel.visible = false
	root.add_child(_panel)
	var pv := VBoxContainer.new()
	_panel.add_child(pv)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pv.add_child(scroll)
	_sliders = VBoxContainer.new()
	_sliders.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_sliders)
	var row := HBoxContainer.new()
	pv.add_child(row)
	var save := RinkOS.button("SAVE")
	save.pressed.connect(_save)
	row.add_child(save)
	var reset := RinkOS.button("RESET CLIP", false)
	reset.pressed.connect(_reset_groups)
	row.add_child(reset)
	_status = RinkOS.label("", RinkOS.TERM_DIM)
	pv.add_child(_status)


func _fill_sliders() -> void:
	for c in _sliders.get_children():
		c.queue_free()
	var groups: Array = AnimClips.LIST[_clip].groups
	for g in groups:
		_sliders.add_child(RinkOS.label(RinkOS.rule(g.to_upper(), 30), RinkOS.TERM_DIM))
		for p in tuning.tunables():
			if p.group != g:
				continue
			var name_l := RinkOS.label(p.name.trim_prefix(g + "_").replace("_", " ").to_upper(), RinkOS.PIXEL)
			var val := RinkOS.label("", RinkOS.TERM)
			val.custom_minimum_size.x = 70
			val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			var s := HSlider.new()
			s.min_value = p.min
			s.max_value = p.max
			s.step = p.step
			s.value = tuning.get(p.name)
			s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			s.focus_mode = Control.FOCUS_NONE
			val.text = _fmt(s.value)
			var key: String = p.name
			s.value_changed.connect(func(v: float) -> void:
				tuning.set(key, v)
				val.text = _fmt(v))
			var line := HBoxContainer.new()
			line.add_child(s)
			line.add_child(val)
			_sliders.add_child(name_l)
			_sliders.add_child(line)


static func _fmt(v: float) -> String:
	return ("%.3f" % v).rstrip("0").rstrip(".") if absf(v) < 10.0 else "%.1f" % v


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(AnimTuning.PATH.get_base_dir())
	var err := ResourceSaver.save(tuning, AnimTuning.PATH)
	_status.text = "// SAVED %s" % AnimTuning.PATH if err == OK else "// SAVE FAILED (%s)" % error_string(err)


func _reset_groups() -> void:
	var fresh := AnimTuning.new()
	for p in tuning.tunables():
		if p.group in AnimClips.LIST[_clip].groups:
			tuning.set(p.name, fresh.get(p.name))
	_fill_sliders()
	_status.text = "// CLIP VALUES RESET (NOT SAVED)"


# ------------------------------------------------------------------- loop

func _start_clip(i: int) -> void:
	_clip = wrapi(i, 0, AnimClips.LIST.size())
	_t = 0.0
	_loops = 0
	_mem = {}
	var c: Dictionary = AnimClips.LIST[_clip]
	puppet.restart(puppet.heading)
	puppet.rig.celebrate(&"", 0.001)
	puck.visible = false
	_title.text = "%02d/%02d  %s" % [_clip + 1, AnimClips.LIST.size(), c.title.to_upper()]
	_note.text = "%s  [tuning: %s]" % [c.note, ", ".join(c.groups)]
	if _reel:
		print("SEG %.2f %s" % [_clock, c.id])
	_fill_sliders()


func _physics_process(dt: float) -> void:
	if _paused:
		return
	dt *= SPEEDS[_speed_i]
	var c: Dictionary = AnimClips.LIST[_clip]
	_t += dt
	if _t >= c.len:
		_t = 0.0
		_loops += 1
		_mem = {}
		puppet.restart(puppet.heading)
		puck.visible = false
		if _reel and _loops >= _reel_loops:
			_test_clip_done(c.id)
			_reel_i += 1
			if _reel_i >= _reel_list.size():
				_finish_reel()
				return
			_start_clip(_reel_list[_reel_i])
			c = AnimClips.LIST[_clip]
	puppet.spin = _turntable
	AnimClips.run(c.id, puppet, _t, dt, _mem)
	puppet.step(dt)
	_ice_offset += Vector2(puppet.vel.x, puppet.vel.z) * dt
	_ice_mat.set_shader_parameter("offset", _ice_offset)
	_fly_puck(dt)
	if _test:
		_test_frame(c.id)


func _process(dt: float) -> void:
	_clock += dt
	_place_cam(_cam, _cam_name)
	for c in _insets:
		_place_cam(c, c.get_meta("view"))


## Puts a camera round the skater: angles are measured from the direction
## the skater faces, so the views ride along with the turntable only when
## it is off (with it on, the main camera stays still and the skater spins).
func _place_cam(c: Camera3D, view: String) -> void:
	var v: Vector3 = CAMS.get(view, CAMS.three_quarter)
	var face := Vector3.FORWARD if (c == _cam and _turntable != 0.0) else puppet.heading
	var dir := face.rotated(Vector3.UP, -deg_to_rad(v.x))
	var look := Vector3(0, 0.8, 0)
	c.position = look + dir * v.z + Vector3.UP * (v.y - 0.8)
	c.look_at(look if view != "top" else Vector3(0, 0.3, 0))


func _fly_puck(dt: float) -> void:
	if puppet.holding or puppet.free_puck:
		puck.visible = true
		_puck_air = 0.0
		return
	if not puck.visible:
		return
	_puck_air += dt
	puck.vel.y -= Puck.GRAVITY * dt
	puck.position += puck.vel * dt
	if puck.position.y < 0.0:
		puck.position.y = 0.0
		puck.vel.y = 0.0
	if _puck_air > 1.0:
		puck.visible = false


func _unhandled_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_RIGHT:
			_start_clip(_clip + 1)
		KEY_LEFT:
			_start_clip(_clip - 1)
		KEY_SPACE:
			_paused = not _paused
		KEY_S:
			_speed_i = (_speed_i + 1) % SPEEDS.size()
			_status.text = "// SPEED x%s" % _fmt(SPEEDS[_speed_i])
		KEY_T:
			_turntable = 0.0 if _turntable != 0.0 else 30.0
		KEY_C:
			var names := CAMS.keys()
			_cam_name = names[(names.find(_cam_name) + 1) % names.size()]
		KEY_TAB:
			# the panel takes the side views' place while it is open
			_panel.visible = not _panel.visible
			_inset_box.visible = _insets_on and not _panel.visible


func _finish_reel() -> void:
	if _test:
		var expect := {
			&"wrist_shot": "follow", &"snap_shot": "follow", &"slapshot": "follow", &"backhand": "follow",
			&"backhand_snap": "follow", &"pass_forehand": "pass", &"pass_backhand": "pass",
			&"check": "check", &"fall_back": "fall", &"fall_forward": "fall",
			&"cel_arms_up": "celebrate", &"cel_fist_pump": "celebrate", &"cel_knee_slide": "celebrate",
			&"hockey_stop": "brake", &"cross_left": "cross", &"cross_right": "cross",
			&"stickhandle": "handled",
		}
		for id in expect:
			if not _test_log.get(id, {}).has(expect[id]):
				_fail("%s never showed %s" % [id, expect[id]])
		for f in _test_fail:
			printerr("FAIL: ", f)
		print("anim test: %s" % ("all passed" if _test_fail.is_empty() else "%d failure(s)" % _test_fail.size()))
		get_tree().quit(1 if _test_fail.size() else 0)
		return
	get_tree().quit()


# ------------------------------------------------------------------- test

## Records what the rig did this frame and checks the pose is sane.
func _test_frame(id: StringName) -> void:
	var r := puppet.rig
	if not _test_log.has(id):
		_test_log[id] = {}
	var seen: Dictionary = _test_log[id]
	if r._follow > 0.0 and r._follow_h >= 1.0:
		seen["follow"] = true
	if r._follow > 0.0 and r._follow_h < 1.0:
		seen["pass"] = true
	if r._check > 0.5:
		seen["check"] = true
	if r._fall > 0.8:
		seen["fall"] = true
	if r.celebrating() != &"":
		seen["celebrate"] = true
	if r._brake > 0.5:
		seen["brake"] = true
	if r._cross > 0.5:
		seen["cross"] = true
	if puppet.position != Vector3.ZERO:
		_fail("%s: the skater left the treadmill" % id)
	# the two-handed clips keep the bottom hand on the shaft
	if id in [&"neutral", &"stickhandle", &"glide", &"stride_easy"] and r._bottom_off:
		_fail("%s: the bottom hand can't reach the stick" % id)
	if puppet.free_puck:
		# the loose puck goes from face to face (the blade lifting over it)
		# and stays within the stick's reach
		var side: float = seen.get("side", 0.0)
		if puppet._puck_side != 0.0 and puppet._puck_side != side:
			seen["side"] = puppet._puck_side
			seen["flips"] = seen.get("flips", 0) + 1
			if seen.flips >= 4:
				seen["handled"] = true
		if Vector2(puck.position.x, puck.position.z).length() > 2.0:
			_fail("%s: the puck got away" % id)
	for part in [r.hips, r.torso, r.head, r.stick, r.blade] + Array(r.thighs) + Array(r.shins) + Array(r.uppers) + Array(r.forearms):
		var gt: Transform3D = part.global_transform
		if not (gt.origin.is_finite() and gt.basis.x.is_finite() and gt.basis.y.is_finite()):
			_fail("%s: %s has a broken transform" % [id, part.name])
			return
	# the skates stay on (or just above) the ice unless the skater is down
	if r._fall < 0.1 and r.celebrating() == &"":
		for sh in r.shins:
			var foot: Vector3 = sh.global_transform * Vector3(0, -SkaterRig.SHIN, 0)
			if foot.y < -0.05 or foot.y > 0.4:
				_fail("%s: a skate is at height %.2f" % [id, foot.y])
				return


func _fail(msg: String) -> void:
	if not msg in _test_fail:
		_test_fail.append(msg)


func _test_clip_done(id: StringName) -> void:
	if _test:
		print("anim test: %s ok" % id)
