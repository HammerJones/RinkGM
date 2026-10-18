extends VenueRoom
## Lights over the ice, using the Props kit's ceiling light. Worn: old
## sodium domes, dim, two dead and one flickering. Repaired: every lamp
## working. Renovated: LED panels, bright and cool. A few shadowless spot lights carry the look onto
## the ice, and apply() sets the match's sun and ambient to match, so the
## overall brightness stays where the gameplay was tuned.

const ROWS_Z := [-8.0, 0.0, 8.0]
const COLS_X := [-24.0, -16.0, -8.0, 0.0, 8.0, 16.0, 24.0]
const SPOTS := [Vector3(-18, 13.5, -5), Vector3(0, 13.5, -5), Vector3(18, 13.5, -5), Vector3(-18, 13.5, 5), Vector3(0, 13.5, 5), Vector3(18, 13.5, 5)]

var _spots: Array[SpotLight3D] = []
var _flicker: MeshInstance3D
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
	var spot_col: Color = k.by_age(Color("ffe9cc"), Color("fff1dc"), Color("f2f7ff"))
	var energy: float = k.by_age(0.55, 0.7, 0.85)
	for p in SPOTS:
		var sp := SpotLight3D.new()
		sp.position = p
		sp.rotation_degrees = Vector3(-90, 0, 0)
		sp.spot_range = 19.0
		sp.spot_angle = 62.0
		sp.spot_attenuation = 0.6
		sp.light_energy = energy
		sp.light_color = spot_col
		sp.shadow_enabled = false
		sp.light_specular = 0.3
		sp.set_meta("energy", energy)
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
		sun.light_energy = [0.74, 0.84, 0.9][a] * lerpf(0.04, 1.0, out)
		sun.light_color = [Color(0.98, 0.97, 0.93), Color(1.0, 0.99, 0.97), Color(0.97, 0.99, 1.0)][a]
	if env:
		env.ambient_light_color = [Color(0.86, 0.87, 0.85), Color(0.87, 0.88, 0.91), Color(0.86, 0.9, 0.98)][a]
		env.ambient_light_energy = [0.24, 0.27, 0.3][a] * lerpf(0.3, 1.0, out)
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
		if not _spots.is_empty():
			_spots[1].light_energy = _spots[1].get_meta("energy") * (1.0 if on else 0.55)


func _restore_power() -> void:
	if power < 1.0 or not lights_on:
		_set_power(power)
