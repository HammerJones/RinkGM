shader_type spatial;
render_mode cull_back, depth_draw_opaque;

// The one material every voxel prop draws with. Albedo is the vertex colour
// (palette, dither and baked ambient occlusion are all in it). Two things
// vary per thing drawn:
//   tint       multiplies the albedo (the renovation ages: a grimy worn tint,
//              a clean one), from the MultiMesh custom data (rgb) on an
//              instanced row or the instance uniform on a live body
//   highlight  0..1, the look-at glow on the thing under the centre dot,
//              from custom data (a) or the uniform
// A row with no custom data written has rgb = 0, which falls back to the
// uniforms, so a plain MeshInstance3D draws untinted.

uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform vec3 highlight_colour : source_color = vec3(1.0, 0.92, 0.6);
// A live body gets its own copy of the material with these set (plain
// uniforms, so the Compatibility renderer works too); batches leave them
// at the defaults and use the custom data.
uniform vec4 inst_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float inst_highlight : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_tint;
varying float v_highlight;

void vertex() {
	vec4 cd = INSTANCE_CUSTOM;
	bool has_custom = dot(cd.rgb, cd.rgb) > 0.0;
	v_tint = has_custom ? cd.rgb : inst_tint.rgb;
	v_highlight = has_custom ? cd.a : inst_highlight;
}

void fragment() {
	vec3 albedo = COLOR.rgb * v_tint;
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	if (v_highlight > 0.0) {
		// a soft glow plus a rim so the whole outline reads, not just the lit faces
		float rim = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
		EMISSION = (albedo * 0.35 + highlight_colour * (0.15 + 0.45 * rim * rim)) * v_highlight;
	}
}
