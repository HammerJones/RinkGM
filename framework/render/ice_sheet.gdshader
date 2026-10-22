shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// The ice sheet: four surface states per column blended per pixel with
// millimetre detail maps. See framework/ice/ice_sheet.gd for the textures.
// The state textures are tiles: each chunk's material carries its tile
// and where that tile sits in the sheet's UV.
uniform sampler2D state : filter_linear;   // r snow, g cut, b water (0..1 of 0.5 mm), a frozen
uniform sampler2D cutmap : filter_linear;  // r angle (turns), g gouge, b filled gouge (scar), a crust (0..1 of 4 mm)
uniform vec2 tile_off = vec2(0.0);         // the tile's origin in sheet UV
uniform vec2 tile_scale = vec2(1.0);       // sheet UV to tile UV
uniform sampler2D stria_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ripple_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D depthmap : filter_linear;  // r ice over the paint (0..1 of 64 mm), g water depth (0..1 of 8 mm)
uniform sampler2D markings : source_color, filter_linear_mipmap_anisotropic;  // lines and logos on the white paint
uniform bool has_markings = false;
uniform float clear_mm = 30.0;  // ice this thick lets 37% of the paint through
uniform vec3 paint_white = vec3(0.86, 0.88, 0.90);
uniform vec2 sheet = vec2(24.0, 14.0);     // metres
uniform float corner_r = 0.0;              // corner radius, metres: outside the arcs is not ice
uniform float striation_m = 1.0;           // striation tiles per metre (the map is one metre)
uniform float striation_strength = 0.9;
varying vec2 wp;

void vertex() {
	wp = UV * sheet;
}

mat2 rot(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat2(vec2(c, -s), vec2(s, c));
}

void fragment() {
	// the rink's corners: nothing is drawn outside the arcs
	vec2 q = abs(wp - sheet * 0.5) - (sheet * 0.5 - vec2(corner_r));
	if (q.x > 0.0 && q.y > 0.0 && length(q) > corner_r) {
		discard;
	}
	vec2 tuv = (UV - tile_off) * tile_scale;
	vec4 s = texture(state, tuv);
	vec4 c = texture(cutmap, tuv);
	float sn = clamp(s.r, 0.0, 1.0);
	float ct = clamp(s.g, 0.0, 1.0);
	float wt = clamp(s.b, 0.0, 1.0);
	float fz = clamp(s.a, 0.0, 1.0);
	// the cut angle is the blade's travel; the grooves run along it (the
	// map's grooves run along V, so the sample is turned a quarter turn)
	float a = (c.r - 0.5) * 6.2832 + 1.5708;
	vec2 su = rot(a) * wp * striation_m;
	vec3 n_cut = texture(stria_n, su).xyz * 2.0 - 1.0;
	vec3 n_snow = texture(snow_n, wp * 90.0).xyz * 2.0 - 1.0;
	vec3 n_rip = texture(ripple_n, wp * 6.0).xyz * 2.0 - 1.0;
	vec3 n_fresh = normalize(mix(vec3(0.0, 0.0, 1.0), n_rip, 0.25));
	vec3 n_dry = normalize(mix(n_fresh, n_cut, ct * striation_strength));
	vec3 n = normalize(mix(n_dry, n_snow, sn));
	float rough = mix(mix(0.16, 0.55, ct), 1.0, sn);
	// the paint is at a fixed depth: the lines sit on the white paint and
	// show through the ice above them, vivid when it is thin, faded and
	// blue when it is thick; clear ice (a filled chip) shows more
	vec2 dm = texture(depthmap, tuv).rg;
	float dep = dm.r * 64.0;
	float wmm = dm.g * 8.0;  // water standing in the column, mm
	float gg = clamp(c.g * 4.0, 0.0, 1.0);
	float sc = clamp(c.b * 4.0, 0.0, 1.0) * (1.0 - gg);
	float through = exp(-dep / clear_mm);
	through = mix(through, min(through * 1.8, 1.0), sc);
	vec3 under = paint_white;
	if (has_markings) {
		vec4 m = texture(markings, UV);
		under = mix(under, m.rgb, m.a);
	}
	vec3 body = mix(vec3(0.58, 0.68, 0.76), vec3(0.64, 0.71, 0.76), ct);
	vec3 alb_dry = mix(body, under, through);
	vec3 alb = mix(alb_dry, vec3(0.80, 0.82, 0.84), sn);
	// a crust: slush that set, very rough, grey-white, lumpy
	float cr = clamp(c.a * 4.0, 0.0, 1.0);
	vec3 n_crust = normalize(mix(n_snow, n_rip, 0.3) * vec3(2.2, 2.2, 1.0));
	n = normalize(mix(n, n_crust, cr));
	rough = mix(rough, 0.9, cr);
	alb = mix(alb, vec3(0.70, 0.72, 0.74), cr);
	// liquid water: a glossy layer over whatever is under it; over snow it
	// is slush, wet grey and only half glossy
	float liquid = wt * (1.0 - fz);
	float slush = liquid * sn;
	alb = mix(alb, vec3(0.55, 0.58, 0.60), slush);
	liquid *= 1.0 - 0.5 * sn;
	vec3 n_water = normalize(mix(n, n_rip, 0.6));
	n = normalize(mix(n, n_water, liquid));
	rough = mix(rough, 0.04, liquid);
	alb = mix(alb, alb * vec3(0.78, 0.86, 0.96), liquid * 0.7);
	// a pool, not a film: water standing more than a film deep lies level
	// over whatever is under it, a still mirror (the ice's grooves and
	// grain are under the surface, not on it), tinted deeper the deeper
	// it is, with a lighter wetting line round its edge
	float pool = smoothstep(0.3, 1.2, wmm) * (1.0 - fz) * (1.0 - sn);
	vec3 n_pool = normalize(mix(vec3(0.0, 0.0, 1.0), n_rip, 0.12));
	n = normalize(mix(n, n_pool, pool));
	rough = mix(rough, 0.02, pool);
	float deep = 1.0 - exp(-wmm / 3.0);
	alb = mix(alb, alb * mix(vec3(0.70, 0.80, 0.90), vec3(0.42, 0.56, 0.70), deep), pool);
	float rim = smoothstep(0.08, 0.3, wmm) * (1.0 - smoothstep(0.3, 0.7, wmm)) * (1.0 - fz) * (1.0 - sn);
	alb = mix(alb, alb * 1.12 + vec3(0.04), rim * 0.8);
	// frozen-over water: the gloss stays, the tint goes
	float set = wt * fz;
	rough = mix(rough, 0.12, set);
	alb = mix(alb, vec3(0.74, 0.83, 0.90), set * 0.5);
	// a gouge: darker trench, rougher; one that water filled is clear
	// ice, flush with the surface: glassier, a touch darker, the paint
	// showing through it more than around it
	alb *= 1.0 - 0.25 * gg;
	rough = mix(rough, 0.7, gg);
	alb = mix(alb, alb * 0.92, sc * 0.6);
	rough = mix(rough, 0.1, sc * 0.7);
	ALBEDO = alb;
	ROUGHNESS = rough;
	SPECULAR = mix(mix(0.5, 0.1, sn), 0.6, pool);
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = mix(0.8, 0.4, liquid);
}
