shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// The ice sheet: four surface states per column blended per pixel with
// millimetre detail maps. See framework/ice/ice_sheet.gd for the textures.
uniform sampler2D state : filter_linear;   // r snow, g cut, b water (0..1 of 0.5 mm), a frozen
uniform sampler2D cutmap : filter_linear;  // r angle (turns), g gouge, b filled gouge (scar), a crust (0..1 of 4 mm)
uniform sampler2D stria_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ripple_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D markings : source_color, filter_linear;  // lines and logos under the ice
uniform bool has_markings = false;
uniform vec2 sheet = vec2(24.0, 14.0);     // metres
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
	vec4 s = texture(state, UV);
	vec4 c = texture(cutmap, UV);
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
	vec3 alb_dry = mix(vec3(0.58, 0.68, 0.76), vec3(0.64, 0.71, 0.76), ct);
	if (has_markings) {
		vec4 m = texture(markings, UV);
		alb_dry = mix(alb_dry, m.rgb, m.a * 0.85);
	}
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
	// frozen-over water: the gloss stays, the tint goes
	float set = wt * fz;
	rough = mix(rough, 0.12, set);
	alb = mix(alb, vec3(0.74, 0.83, 0.90), set * 0.5);
	// a gouge: darker trench, rougher; one that water filled is a pale
	// scar, flush with the surface, still there if you look
	float gg = clamp(c.g * 4.0, 0.0, 1.0);
	alb *= 1.0 - 0.25 * gg;
	rough = mix(rough, 0.7, gg);
	float sc = clamp(c.b * 4.0, 0.0, 1.0) * (1.0 - gg);
	alb = mix(alb, alb * 1.12 + vec3(0.04), sc * 0.8);
	rough = mix(rough, 0.3, sc * 0.5);
	ALBEDO = alb;
	ROUGHNESS = rough;
	SPECULAR = mix(0.5, 0.1, sn);
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = mix(0.8, 0.4, liquid);
}
