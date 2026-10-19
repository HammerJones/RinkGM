extends VenueRoom
## Lights over the ice, using the Props kit's ceiling light. Worn: old
## sodium domes, dim, two dead and one flickering. Repaired: every lamp
## working. Renovated: LED panels, bright and cool. Every working lamp throws
## its own spot light (Look.fixture), so the ice gets real, uneven pools of
## light; apply() sets the match's top light and ambient to match, so the
## overall brightness stays where the gameplay was tuned.

const ROWS_Z := [-8.0, 0.0, 8.0]
const COLS_X := [-24.0, -16.0, -8.0, 0.0, 8.0, 16.0, 24.0]

var _spots: Array[SpotLight3D] = []
var _flicker: MeshInstance3D
var _flicker_light: SpotLight3D
var _flicker_t := 0.0
var _hidden := false
var _rng := RandomNumberGenerator.new()
## The breakers: on or off. Old metal halides (and the sodium domes) don't
## come straight on: `power` climbs from a dim strike to full over WARM_UP
## seconds. Matches start with the lights on and warm.
const WARM_UP := 40.0
var lights_on := true
var power := 1.0
var _env: Environment
var _sun: DirectionalLight3D


func _ready() -> void:
	room_id = "lighting"
	display_name = "Ice lighting"
	overhead = true
	_rng.seed = 11


func build(k: VenueKit) -> void:
	_spots.clear()
	_flicker_light = null
	_restore_power.call_deferred()
	# the Props kit's ceiling light hangs from the truss bottom chord; a glow
	# face under it does the emitting (sodium domes, later LED panels)
	var lamp: Color = k.by_age(Wear.SODIUM_DIM, Wear.SODIUM, Wear.LED)
	var mount := Venue.ROOF_Y - 1.4
	var i := 0
	for z in ROWS_Z:
		for x in COLS_X:
			k.prop("light", Vector3(x, mount, z), 0.0, false)
			var dead := k.age == Age.WORN and (i == 5 or i == 15)
			var flick := k.age == Age.WORN and i == 9
			i += 1
			if flick:
				continue  # drawn on its own below so it can flicker
			k.glow(_glow_lo(k, x, z, mount), _glow_hi(k, x, z, mount), Color("3a3936") if dead else lamp)
	if k.age == Age.WORN:
		var b := VoxelMeshBuilder.new()
		var x: float = COLS_X[2]
		var z: float = ROWS_Z[1]
		var lo := _glow_lo(k, x, z, mount)
		var hi := _glow_hi(k, x, z, mount)
		b.add_box(Transform3D(Basis.from_scale(hi - lo), (lo + hi) * 0.5), lamp)
		_flicker = MeshInstance3D.new()
		_flicker.name = "FlickerLamp"
		_flicker.mesh = b.commit(VenueKit.glow_material())
		_flicker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		k.add(_flicker)
	_add_lamp_lights(k, mount)
	if Look.at_least(Look.Quality.MEDIUM):
		# the glossy ice mirrors the stands and lamps even where the screen
		# can't (SSR only sees what is on screen)
		var probe := ReflectionProbe.new()
		probe.position = Vector3(0, 7.0, 0)
		probe.size = Vector3(Venue.HALF_X * 2.0, 15.0, 60.0)
		probe.box_projection = true
		probe.interior = true
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		probe.max_distance = 80.0
		probe.intensity = 0.7
		k.add(probe)


## One spot light under every working lamp, so the ice gets real pools of
## light (uneven when the rink is worn: dead lamps leave dark patches, the
## sodium domes are amber). The centre lamps cast shadows when the quality
## allows.
func _add_lamp_lights(k: VenueKit, mount: float) -> void:
	var col: Color = k.by_age(Color("ffd7a1"), Color("fff0da"), Color("eef4ff"))
	var energy: float = k.by_age(2.2, 2.8, 3.2)
	var shadowed := Look.shadowed_lamps()
	# the lamps nearest centre ice get the shadows
	var order: Array = []
	var i := 0
	for z in ROWS_Z:
		for x in COLS_X:
			order.append([absf(x) + absf(z) * 0.5, i, x, z])
			i += 1
	order.sort_custom(func(a, b): return a[0] < b[0])
	var shadow_ids := {}
	for j in mini(shadowed, order.size()):
		shadow_ids[order[j][1]] = true
	for o in order:
		var id: int = o[1]
		var dead := k.age == Age.WORN and (id == 5 or id == 15)
		if dead:
			continue
		var sp := SpotLight3D.new()
		sp.position = Vector3(o[2], mount - 0.9, o[3])
		sp.rotation_degrees = Vector3(-90, 0, 0)
		sp.spot_range = 22.0
		sp.spot_angle = 72.0
		sp.spot_angle_attenuation = 0.9
		sp.spot_attenuation = 0.85
		sp.light_energy = energy
		sp.light_color = col
		Look.fixture(sp, 60.0)
		sp.shadow_enabled = shadow_ids.has(id)
		sp.set_meta("energy", energy)
		if k.age == Age.WORN and id == 9:
			_flicker_light = sp
		_spots.append(sp)
		k.add(sp)


## The emitting face under a light prop: the dome's bulb, or the LED panel.
func _glow_lo(k: VenueKit, x: float, z: float, mount: float) -> Vector3:
	if k.age == Age.RENOVATED:
		return Vector3(x - 0.42, mount - 0.55, z - 0.1)
	return Vector3(x - 0.2, mount - 0.86, z - 0.2)


func _glow_hi(k: VenueKit, x: float, z: float, mount: float) -> Vector3:
	if k.age == Age.RENOVATED:
		return Vector3(x + 0.42, mount - 0.53, z + 0.1)
	return Vector3(x + 0.2, mount - 0.84, z + 0.2)


## Seen from above the roof only the lamps hide; the light stays on the ice.
func set_overhead_hidden(hidden: bool) -> void:
	_hidden = hidden
	for c in get_children():
		if c is GeometryInstance3D:
			c.visible = not hidden


## Turns the ice lights on (they warm up) or off (straight away).
func switch(on: bool) -> void:
	lights_on = on
	if not on:
		_set_power(0.0)
	elif power <= 0.0:
		_set_power(0.02)


func _set_power(p: float) -> void:
	power = clampf(p, 0.0, 1.0)
	var lit := power > 0.01
	for c in get_children():
		if c is MeshInstance3D and c.mesh and c.mesh.get_surface_count() > 0 and c.mesh.surface_get_material(0) == VenueKit.glow_material():
			c.visible = lit and not _hidden
		elif c is SpotLight3D:
			c.light_energy = float(c.get_meta("energy", 0.6)) * _ramp()
			c.visible = lit
	if _env or _sun:
		apply(_env, _sun)


## Light output for the current power: a strike glow, then the slow climb.
func _ramp() -> float:
	return 0.0 if power <= 0.0 else 0.12 + 0.88 * power * power


## Sets the match's sun and ambient light for this lighting age (scaled
## down while the lights are off or warming up).
func apply(env: Environment, sun: DirectionalLight3D) -> void:
	_env = env
	_sun = sun
	var a := age
	var out := _ramp() if not lights_on or power < 1.0 else 1.0
	if sun:
		# not a sun: the sum of the lamps overhead, so skaters keep a short
		# crisp shadow straight under them; the lamp pools do the rest
		sun.rotation_degrees = Vector3(-76.0, -24.0, 0.0)
		sun.light_energy = [0.42, 0.5, 0.56][a] * lerpf(0.04, 1.0, out)
		sun.light_color = [Color(1.0, 0.92, 0.8), Color(1.0, 0.97, 0.92), Color(0.95, 0.98, 1.0)][a]
		sun.shadow_blur = 1.6
		sun.light_angular_distance = 2.0
	if env:
		env.ambient_light_color = [Color(0.8, 0.78, 0.74), Color(0.85, 0.85, 0.86), Color(0.84, 0.88, 0.96)][a]
		env.ambient_light_energy = [0.27, 0.31, 0.34][a] * lerpf(0.3, 1.0, out)
		env.background_color = Color("1b1a19")


func _process(dt: float) -> void:
	if lights_on and power < 1.0:
		_set_power(power + dt / WARM_UP)
	if power <= 0.0:
		return
	if _flicker == null or not is_instance_valid(_flicker) or _hidden:
		return
	_flicker_t -= dt
	if _flicker_t <= 0.0:
		var on := _rng.randf() < 0.7
		_flicker.visible = on
		_flicker_t = _rng.randf_range(0.04, 0.5) if on else _rng.randf_range(0.03, 0.15)
		if _flicker_light and is_instance_valid(_flicker_light):
			_flicker_light.light_energy = _flicker_light.get_meta("energy") * _ramp() * (1.0 if on else 0.08)


func _restore_power() -> void:
	if power < 1.0 or not lights_on:
		_set_power(power)
