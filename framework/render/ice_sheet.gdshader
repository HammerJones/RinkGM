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
// The heatmap: the surface coloured by its height alone, the lowest
// column dark blue, the middle green, the highest red, a gradient
// between. heat_lo/heat_hi are mesh heights (IceSheet.height_range()).
uniform bool heatmap = false;
uniform float heat_lo = 0.0;
uniform float heat_hi = 0.001;
// heat_mode 1 colours by height, 2 by the column's temperature: its
// steady temperature between the pad and the air from its thickness
// (depthmap.a, 0..1 of 64 mm) plus what a flood warmed it (depthmap.b,
// 0..1 of 10 K), as IceSheet.thermal() reckons it; temp_lo..temp_hi C.
uniform int heat_mode = 1;
uniform float pad_c = -9.0;
uniform float room_c = 8.0;
uniform float h_air = 6.0;
uniform float k_ice = 2.2;
uniform float temp_lo = -10.0;
uniform float temp_hi = 0.0;
varying vec2 wp;
varying float hy;

void vertex() {
	wp = UV * sheet;
	hy = VERTEX.y;
}

vec3 heat_colour(float t) {
	// dark blue .. blue .. green .. yellow .. red, four even ramps
	vec3 c0 = vec3(0.02, 0.02, 0.35);
	vec3 c1 = vec3(0.05, 0.35, 1.0);
	vec3 c2 = vec3(0.05, 0.85, 0.15);
	vec3 c3 = vec3(1.0, 0.92, 0.05);
	vec3 c4 = vec3(0.9, 0.05, 0.02);
	float u = clamp(t, 0.0, 1.0) * 4.0;
	if (u < 1.0) {
		return mix(c0, c1, u);
	} else if (u < 2.0) {
		return mix(c1, c2, u - 1.0);
	} else if (u < 3.0) {
		return mix(c2, c3, u - 2.0);
	}
	return mix(c3, c4, u - 3.0);
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
	// snow: a dusting already reads, a few tenths of a millimetre hides the
	// ice; matte, bright white, lumpy (the grain's bumps also shade it)
	float snw = smoothstep(0.0, 0.6, sn);
	vec3 n_snowy = normalize(n_snow * vec3(1.7, 1.7, 1.0));
	vec3 n = normalize(mix(n_dry, n_snowy, snw));
	float rough = mix(mix(0.16, 0.55, ct), 1.0, snw);
	float lumps = 0.86 + 0.14 * n_snow.z;
	// the paint is at a fixed depth: the lines sit on the white paint and
	// show through the ice above them, vivid when it is thin, faded and
	// blue when it is thick; clear ice (a filled chip) shows more
	vec4 dm4 = texture(depthmap, tuv);
	vec2 dm = dm4.rg;
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
	vec3 alb = mix(alb_dry, vec3(0.94, 0.95, 0.97) * lumps, snw);
	// a crust: slush that set, very rough, grey-white, lumpy
	float cr = clamp(c.a * 4.0, 0.0, 1.0);
	vec3 n_crust = normalize(mix(n_snow, n_rip, 0.3) * vec3(2.2, 2.2, 1.0));
	n = normalize(mix(n, n_crust, cr));
	rough = mix(rough, 0.9, cr);
	alb = mix(alb, vec3(0.70, 0.72, 0.74), cr);
	// liquid water: a glossy layer over whatever is under it; over snow it
	// is slush: wet, grey, a little see-through (the ice shows through the
	// soaked snow), lumpy, and only a little glossy, until it sets and is
	// a crust
	float liquid = wt * (1.0 - fz);
	float slush = clamp(liquid * 2.0, 0.0, 1.0) * snw;
	vec3 slush_col = mix(alb_dry, vec3(0.60, 0.64, 0.69), 0.55);
	alb = mix(alb, slush_col, slush);
	vec3 n_slush = normalize(mix(n_snow, n_rip, 0.4) * vec3(1.3, 1.3, 1.0));
	n = normalize(mix(n, n_slush, slush));
	rough = mix(rough, 0.3, slush);
	liquid *= 1.0 - 0.75 * snw;
	vec3 n_water = normalize(mix(n, n_rip, 0.6));
	n = normalize(mix(n, n_water, liquid));
	rough = mix(rough, 0.04, liquid);
	alb = mix(alb, alb * vec3(0.78, 0.86, 0.96), liquid * 0.7);
	// a pool, not a film: water standing more than a film deep lies level
	// over whatever is under it, a still mirror (the ice's grooves and
	// grain are under the surface, not on it), tinted deeper the deeper
	// it is, with a lighter wetting line round its edge
	float pool = smoothstep(0.3, 1.2, wmm) * (1.0 - fz) * (1.0 - snw);
	vec3 n_pool = normalize(mix(vec3(0.0, 0.0, 1.0), n_rip, 0.12));
	n = normalize(mix(n, n_pool, pool));
	rough = mix(rough, 0.02, pool);
	float deep = 1.0 - exp(-wmm / 3.0);
	alb = mix(alb, alb * mix(vec3(0.70, 0.80, 0.90), vec3(0.42, 0.56, 0.70), deep), pool);
	float rim = smoothstep(0.08, 0.3, wmm) * (1.0 - smoothstep(0.3, 0.7, wmm)) * (1.0 - fz) * (1.0 - snw);
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
	if (heatmap) {
		// matte, lit a little by its own colour so shadow does not read
		// as a hollow; the relief still shades through the lighting
		float ht = (hy - heat_lo) / max(heat_hi - heat_lo, 1e-6);
		if (heat_mode == 2) {
			float h = max(dm4.a * 64.0, 2.0) * 0.001;
			float g = 2.0 * k_ice / h;
			float t = (h_air * room_c + g * pad_c) / (h_air + g) + dm4.b * 10.0;
			if (wmm > 0.02) {
				t = max(t, 0.0);  // standing water sits at 0 C
			}
			ht = (t - temp_lo) / max(temp_hi - temp_lo, 1e-6);
		}
		vec3 hc = heat_colour(ht);
		ALBEDO = hc;
		EMISSION = hc * 0.35;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
		NORMAL_MAP = vec3(0.5, 0.5, 1.0);
		NORMAL_MAP_DEPTH = 0.0;
	} else {
		ALBEDO = alb;
		ROUGHNESS = rough;
		SPECULAR = mix(mix(0.5, 0.08, snw), 0.6, pool);
		NORMAL_MAP = n * 0.5 + 0.5;
		NORMAL_MAP_DEPTH = mix(0.8, 0.4, liquid);
	}
}
