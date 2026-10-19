class_name Look
extends RefCounted
## The game's lighting look, in one place, so the match, the walk around the
## building and the close-up mini games are lit the same way. See the
## "Lighting" section of docs/ART.md.
##
## Indoors the light comes from the fixtures, not a sun: lamp faces glow (and
## bloom), each lamp throws a pool of light through a thin haze, the ice is
## glossy enough to mirror the lamps, and screen-space AO / indirect light
## ground everything. A soft top light stands in for the sum of the arena
## lamps so skaters keep a crisp shadow under them for gameplay.
##
## Three quality levels trade looks for frame time. `--look=low|medium|high`
## overrides the saved choice for one run (screenshots, tests):
##
##  LOW     glow, filmic tone mapping, depth fog. No screen-space effects,
##          no lamp shadows.
##  MEDIUM  + SSAO, screen-space reflections (the glossy ice), reflection
##          probe, a few shadowed lamps.
##  HIGH    + screen-space indirect light, volumetric haze (visible lamp
##          cones), more shadowed lamps.

enum Quality { LOW, MEDIUM, HIGH }
const QUALITY_NAMES := ["low", "medium", "high"]
const SAVE_PATH := "user://look.cfg"

## How much brighter than white a glowing lamp face is drawn, so the glow
## (bloom) picks lamps out and nothing else.
const LAMP_HDR := [1.35, 1.7, 1.9]

static var _quality := -1
## Environments made through setup(), re-applied when the quality changes.
static var _envs: Array[WeakRef] = []


static func quality() -> int:
	if _quality < 0:
		_quality = Quality.HIGH
		var cfg := ConfigFile.new()
		if cfg.load(SAVE_PATH) == OK:
			_quality = clampi(int(cfg.get_value("look", "quality", Quality.HIGH)), 0, 2)
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--look="):
				var q := QUALITY_NAMES.find(a.trim_prefix("--look="))
				if q >= 0:
					_quality = q
	return _quality


## Changes the quality, saves it and re-applies every live environment.
## Lights built by rooms pick it up the next time the room rebuilds.
static func set_quality(q: int) -> void:
	_quality = clampi(q, 0, 2)
	var cfg := ConfigFile.new()
	cfg.set_value("look", "quality", _quality)
	cfg.save(SAVE_PATH)
	var alive: Array[WeakRef] = []
	for w in _envs:
		var env: Environment = w.get_ref()
		if env:
			_apply_effects(env, env.get_meta("look_kind", "arena"))
			alive.append(w)
	_envs = alive
	var mat := VenueKit.glow_material()
	if mat:
		mat.albedo_color = lamp_glow()


static func at_least(q: int) -> bool:
	return quality() >= q


## A new Environment for `kind`:
##  "arena"   inside the rink building (matches and the walk)
##  "studio"  a close-up mini game on a bench, lit by its own work lights
static func make(kind := "arena") -> Environment:
	var env := Environment.new()
	setup(env, kind)
	return env


## Sets an existing Environment to the look (callers keep their own
## background and ambient colour afterwards if they set them).
static func setup(env: Environment, kind := "arena") -> void:
	env.set_meta("look_kind", kind)
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.tonemap_white = 5.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.06
	_apply_effects(env, kind)
	_envs.append(weakref(env))


static func _apply_effects(env: Environment, kind: String) -> void:
	var q := quality()
	# lamp faces are drawn brighter than white; only they cross the threshold
	env.glow_enabled = true
	env.glow_normalized = false
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.05
	env.glow_hdr_scale = 1.6
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for i in 7:
		env.set_glow_level(i, [0.0, 0.0, 0.6, 0.8, 0.9, 0.5, 0.0][i])
	env.ssao_enabled = q >= Quality.MEDIUM
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.15
	env.ssil_enabled = q >= Quality.HIGH
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.8
	env.ssr_enabled = q >= Quality.MEDIUM and kind == "arena"
	env.ssr_max_steps = 48 if q == Quality.MEDIUM else 72
	env.ssr_fade_in = 0.12
	env.ssr_fade_out = 2.4
	env.ssr_depth_tolerance = 0.25
	# a thin haze: the lamps throw visible cones on HIGH, depth fog otherwise
	env.volumetric_fog_enabled = q >= Quality.HIGH and kind == "arena"
	env.volumetric_fog_density = 0.016
	env.volumetric_fog_albedo = Color(0.92, 0.9, 0.86)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 70.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_ambient_inject = 0.15
	env.volumetric_fog_sky_affect = 0.0
	env.fog_enabled = q < Quality.HIGH and kind == "arena"
	env.fog_light_color = Color(0.5, 0.5, 0.48)
	env.fog_density = 0.0025
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0


## The colour multiplier for glowing lamp faces (VenueKit.glow_material).
static func lamp_glow() -> Color:
	var k: float = LAMP_HDR[quality()]
	return Color(k, k, k)


## How many arena lamps cast shadows at this quality.
static func shadowed_lamps() -> int:
	return [0, 2, 6][quality()]


## Sets up a fixture light the same way everywhere: soft falloff, a little
## specular, fades out with distance so a building full of rooms only pays
## for the lights near the camera, and lights the haze on HIGH.
static func fixture(l: Light3D, fade_from := 28.0) -> void:
	l.light_specular = 0.35
	l.light_volumetric_fog_energy = 1.0
	l.distance_fade_enabled = true
	l.distance_fade_begin = fade_from
	l.distance_fade_length = 8.0
	l.distance_fade_shadow = fade_from * 0.5
	if l is OmniLight3D:
		(l as OmniLight3D).shadow_normal_bias = 1.5
	l.shadow_blur = 1.4
