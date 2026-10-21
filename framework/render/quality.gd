class_name Quality
extends RefCounted
## Rendering quality in one place: three presets, each a dictionary of the
## knobs the look depends on, applied to a scene's Environment, its key
## light and its PropFields. The look is tuned by editing a preset, the
## budget tests say which preset they measured, and a settings screen
## only has to call `Quality.apply(name, ...)`.
##
##   Quality.apply("high", {"env": env, "sun": sun, "fields": [field]})
##   Quality.current                       # the preset name in force
##   Quality.preset("medium").draw_range   # a value
##
## SDFGI and SSAO take effect on the Forward+ renderer; the Compatibility
## renderer ignores them (it has no SDFGI and no SSAO).

const PRESETS := {
	"low":
	{
		"ssao": false,
		"sdfgi": false,
		"glow": false,
		"shadow_size": 2048,
		"shadow_splits": 2,
		"shadow_distance": 40.0,
		"draw_range": 35.0,
		"lod_distance": 4.0,
		"prop_shadows": false,
		"msaa": Viewport.MSAA_DISABLED,
	},
	"medium":
	{
		"ssao": true,
		"sdfgi": false,
		"glow": true,
		"shadow_size": 4096,
		"shadow_splits": 3,
		"shadow_distance": 60.0,
		"draw_range": 60.0,
		"lod_distance": 7.0,
		"prop_shadows": true,
		"msaa": Viewport.MSAA_2X,
	},
	"high":
	{
		"ssao": true,
		"sdfgi": true,
		"glow": true,
		"shadow_size": 8192,
		"shadow_splits": 4,
		"shadow_distance": 90.0,
		"draw_range": 90.0,
		"lod_distance": 10.0,
		"prop_shadows": true,
		"msaa": Viewport.MSAA_4X,
	},
}

static var current := "medium"


static func names() -> Array:
	return PRESETS.keys()


static func preset(name: String) -> Dictionary:
	return PRESETS.get(name, PRESETS["medium"])


## Applies the preset. `targets` may carry: env (Environment or
## WorldEnvironment), sun (DirectionalLight3D), fields (Array of PropField),
## viewport (Viewport, for MSAA).
static func apply(name: String, targets := {}) -> void:
	var p := preset(name)
	current = name if PRESETS.has(name) else "medium"
	var env: Variant = targets.get("env")
	if env is WorldEnvironment:
		env = env.environment
	if env is Environment:
		env.ssao_enabled = p.ssao
		env.sdfgi_enabled = p.sdfgi
		env.glow_enabled = p.glow
		if p.glow:
			env.glow_intensity = 0.6
			env.glow_bloom = 0.05
			env.glow_hdr_threshold = 1.2
	var sun: Variant = targets.get("sun")
	if sun is DirectionalLight3D:
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = p.shadow_distance
		sun.directional_shadow_mode = (
			DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			if p.shadow_splits >= 4
			else (
				DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
				if p.shadow_splits <= 2
				else DirectionalLight3D.SHADOW_ORTHOGONAL
			)
		)
		RenderingServer.directional_shadow_atlas_set_size(p.shadow_size, true)
	for f in targets.get("fields", []):
		if f is PropField:
			f.draw_range = p.draw_range
			f.lod_distance = p.lod_distance
			f.cast_shadows = p.prop_shadows
	var vp: Variant = targets.get("viewport")
	if vp is Viewport:
		vp.msaa_3d = p.msaa
