class_name IceView
extends Node
## Shows an IceSlab on the Rink's ice plane: a shader over the painted
## markings, fed two small data textures (one texel per fine cell) that are
## rewritten only where the slab says it changed. Skate gouges as scratches,
## the blade's striations along the way it cut, loose snow (and the ridge
## along the boards), glossy standing water against the matte of a dry cut,
## thick ice a little milkier.
##
##   var view := IceView.attach(rink, sim.ice)   # after the Rink is in the tree
##   view.ice = run.ice                          # the drive scene's copy, live
##
## Members of the "ice_view" group, so a job scene can find the venue's.

const SHADER := """
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D markings : source_color, filter_nearest;
uniform sampler2D surf : filter_linear;   // r gouge, g texture, b snow, a liquid water
uniform sampler2D cutmap : filter_linear; // r cut angle, g striation, b frozen, a thickness
uniform vec2 rink_size = vec2(60.96, 25.9);
uniform float snow_gain = 1.0;
uniform int debug_view = 0;

varying vec2 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (UV - 0.5) * rink_size;
}

void fragment() {
	vec4 s = texture(surf, UV);
	vec4 c = texture(cutmap, UV);
	vec3 base = texture(markings, UV).rgb;
	float gouge = s.r;
	float tex = s.g;
	float snow = clamp(s.b * snow_gain, 0.0, 1.0);
	float wet = clamp(s.a, 0.0, 1.0);
	// skate scratches: short streaks in every direction, thicker with the gouges
	float sc = 0.0;
	for (int k = 0; k < 3; k++) {
		float fk = float(k);
		float a = vnoise(wpos * 0.7 + fk * 13.1) * 6.2832 + fk * 2.1;
		vec2 d = vec2(cos(a), sin(a));
		vec2 q = vec2(dot(wpos, d) * 1.6, dot(wpos, vec2(-d.y, d.x)) * 16.0);
		float line = 1.0 - abs(fract(q.y + vnoise(vec2(q.x * 0.7, fk * 3.0)) * 2.0) - 0.5) * 2.0;
		float fw = fwidth(q.y) * 2.0 + 0.02;
		float seg = smoothstep(0.45, 0.75, vnoise(vec2(q.x, floor(q.y) * 1.7) + fk * 7.0));
		sc = max(sc, smoothstep(0.86 - fw, 0.86 + fw, line) * seg);
	}
	float scratches = sc * smoothstep(0.0, 0.35, gouge);
	float haze = clamp(gouge * 1.6 + tex * 0.9, 0.0, 1.0);
	// the blade's lines, across the way it went
	float ang = c.r * 3.14159;
	vec2 cd = vec2(cos(ang), sin(ang));
	float across = dot(wpos, vec2(-cd.y, cd.x));
	float stripes = 0.5 + 0.5 * sin(across * 120.0 + vnoise(wpos * 2.5) * 5.0);
	float stri = c.g * stripes;
	// snow lies in drifts
	float sn = clamp(snow * (0.3 + 1.4 * vnoise(wpos * 4.0) * vnoise(wpos * 11.0 + 3.0) * 1.6), 0.0, 1.0);
	sn = smoothstep(0.05, 0.9, sn);
	// clean glossy ice shows the paint through a grey-blue skin; anything
	// that scatters light (scratches, cut lines, frost, snow) reads white
	float white = clamp(haze * 0.75 + scratches * 0.8 + stri * 0.55, 0.0, 1.0);
	vec3 col = base * mix(vec3(0.64, 0.70, 0.77), vec3(1.0), white);
	col = mix(col, vec3(0.98), scratches * 0.35);
	col = mix(col, col * vec3(0.97, 0.99, 1.0) + 0.03, clamp(c.a, 0.0, 1.0) * 0.5);
	col = mix(col, vec3(0.97, 0.98, 1.0) + vec3(hash(floor(wpos * 60.0))) * 0.03, sn);
	col *= mix(1.0, 0.72, wet * (1.0 - sn));
	ALBEDO = col;
	if (debug_view == 1) { ALBEDO = s.rgb; }
	if (debug_view == 2) { ALBEDO = c.rgb; }
	float matte = 0.1 + haze * 0.5 + scratches * 0.3 + stri * 0.35 + sn * 0.6;
	ROUGHNESS = clamp(mix(matte, 0.03, wet), 0.02, 1.0);
	SPECULAR = mix(0.4, 0.75, wet);
	CLEARCOAT = wet * 0.9;
	CLEARCOAT_ROUGHNESS = 0.04;
	// a little relief from the scratches and the snow
	vec2 e = vec2(dFdx(scratches + sn * 0.6), dFdy(scratches + sn * 0.6));
	NORMAL_MAP = normalize(vec3(0.5 - e.x * 0.8, 0.5 - e.y * 0.8, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.35 * (1.0 - wet);
}
"""

const UPDATE_EVERY := 0.1  # s between texture uploads at most

var ice: IceSlab:
	set(v):
		ice = v
		_rev = -1
		_full = true
var mesh: MeshInstance3D
var material: ShaderMaterial
## 1 shows the surface data texture, 2 the cut one (for checking the view).
var debug_view := 0
var _img_a: Image
var _img_b: Image
var _tex_a: ImageTexture
var _tex_b: ImageTexture
var _buf_a := PackedByteArray()
var _buf_b := PackedByteArray()
var _rev := -1
var _full := true
var _acc := 0.0


## Puts a view on `rink`'s ice plane (a Rink node, already built) showing
## `ice_`. Returns the view (a child of the rink).
static func attach(rink: Node, ice_: IceSlab) -> IceView:
	var v := IceView.new()
	v.name = "IceView"
	v.mesh = find_ice_mesh(rink)
	v.ice = ice_
	rink.add_child(v)
	v._setup()
	return v


## The Rink's ice plane: the PlaneMesh the size of the sheet.
static func find_ice_mesh(rink: Node) -> MeshInstance3D:
	for c in rink.get_children():
		var mi := c as MeshInstance3D
		if mi and mi.mesh is PlaneMesh and ((mi.mesh as PlaneMesh).size - Vector2(Rink.LENGTH, Rink.WIDTH)).length() < 0.01:
			return mi
	return null


func _ready() -> void:
	add_to_group("ice_view")
	if material == null:
		# the Rink builds its ice in its own _ready, after its children's
		_setup_late.call_deferred()


func _setup_late() -> void:
	if mesh == null:
		mesh = find_ice_mesh(get_parent())
	_setup()


func _setup() -> void:
	if material != null or mesh == null:
		return
	var markings: Texture2D = null
	var pm := mesh.mesh as PlaneMesh
	if pm and pm.material is StandardMaterial3D:
		markings = (pm.material as StandardMaterial3D).albedo_texture
	_buf_a.resize(IceSlab.FCELLS * 4)
	_buf_b.resize(IceSlab.FCELLS * 4)
	_img_a = Image.create_from_data(IceSlab.FW, IceSlab.FD, false, Image.FORMAT_RGBA8, _buf_a)
	_img_b = Image.create_from_data(IceSlab.FW, IceSlab.FD, false, Image.FORMAT_RGBA8, _buf_b)
	_tex_a = ImageTexture.create_from_image(_img_a)
	_tex_b = ImageTexture.create_from_image(_img_b)
	var sh := Shader.new()
	sh.code = SHADER
	material = ShaderMaterial.new()
	material.shader = sh
	if markings:
		material.set_shader_parameter("markings", markings)
	material.set_shader_parameter("surf", _tex_a)
	material.set_shader_parameter("cutmap", _tex_b)
	material.set_shader_parameter("rink_size", Vector2(Rink.LENGTH, Rink.WIDTH))
	material.set_shader_parameter("debug_view", debug_view)
	mesh.material_override = material
	refresh(true)


func _process(dt: float) -> void:
	_acc += dt
	if _acc < UPDATE_EVERY:
		return
	_acc = 0.0
	refresh()


## Rewrites the texels the slab has changed since the last call (all of them
## when `full`), and uploads the two textures.
func refresh(full := false) -> void:
	if ice == null or material == null:
		return
	ice.flush()
	if not full and not _full and ice.revision == _rev:
		return
	var r := Rect2i(0, 0, IceSlab.FW, IceSlab.FD) if (full or _full) else ice.dirty
	_full = false
	_rev = ice.revision
	ice.dirty = Rect2i()
	if r.size == Vector2i.ZERO:
		return
	r = r.intersection(Rect2i(0, 0, IceSlab.FW, IceSlab.FD))
	for fz in range(r.position.y, r.end.y):
		var row := fz * IceSlab.FW
		for fx in range(r.position.x, r.end.x):
			var i := row + fx
			var o := i * 4
			_buf_a[o] = clampi(int(ice.g[i] / IceSlab.GOUGE_MAX * 255.0), 0, 255)
			_buf_a[o + 1] = clampi(int(ice.r[i] * 255.0), 0, 255)
			_buf_a[o + 2] = clampi(int(ice.s[i] / IceSlab.SNOW_FULL_MM * 255.0), 0, 255)
			_buf_a[o + 3] = clampi(int(ice.liquid_at(i) / 0.4 * 255.0), 0, 255)
			_buf_b[o] = clampi(int(ice.ang[i] * 255.0), 0, 255)
			_buf_b[o + 1] = clampi(int(ice.stri[i] * 255.0), 0, 255)
			_buf_b[o + 2] = clampi(int(ice.frozen_at(i) * 255.0), 0, 255)
			_buf_b[o + 3] = clampi(int((ice.t[i] - 20.0) / 40.0 * 255.0), 0, 255)
	_img_a.set_data(IceSlab.FW, IceSlab.FD, false, Image.FORMAT_RGBA8, _buf_a)
	_img_b.set_data(IceSlab.FW, IceSlab.FD, false, Image.FORMAT_RGBA8, _buf_b)
	_tex_a.update(_img_a)
	_tex_b.update(_img_b)
