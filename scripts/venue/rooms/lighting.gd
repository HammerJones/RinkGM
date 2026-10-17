extends VenueRoom
## Lights over the ice. Worn: old metal-halide domes, dim and patchy, two
## dead and one flickering. Repaired: every lamp working. Renovated: LED
## panels, bright and cool. A few shadowless spot lights carry the look onto
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


func _ready() -> void:
	room_id = "lighting"
	display_name = "Ice lighting"
	overhead = true
	_rng.seed = 11


func build(k: VenueKit) -> void:
	_spots.clear()
	var lamp: Color = k.by_age(Color("f2efdc"), Color("fff6e8"), Color("f2f7ff"))
	var housing: Color = k.by_age(Color("4a4540"), Color("5a5f66"), Color("1d2026"))
	var y := Venue.ROOF_Y - 1.6
	var i := 0
	for z in ROWS_Z:
		for x in COLS_X:
			if k.age == Age.RENOVATED:
				# slim LED panel
				k.block(Vector3(x - 1.4, y - 0.12, z - 0.35), Vector3(x + 1.4, y, z + 0.35), housing, 1.0, 0.0, false)
				k.glow(Vector3(x - 1.3, y - 0.14, z - 0.28), Vector3(x + 1.3, y - 0.12, z + 0.28), lamp)
			else:
				k.block(Vector3(x - 0.03, y, z - 0.03), Vector3(x + 0.03, Venue.ROOF_Y - 1.4, z + 0.03), housing, 1.0, 0.0, false)
				k.block(Vector3(x - 0.4, y - 0.45, z - 0.4), Vector3(x + 0.4, y, z + 0.4), housing, 0.4, 0.05, false)
				var dead := k.age == Age.WORN and (i == 5 or i == 15)
				var flick := k.age == Age.WORN and i == 9
				if flick:
					continue  # drawn on its own below so it can flicker
				k.glow(Vector3(x - 0.32, y - 0.47, z - 0.32), Vector3(x + 0.32, y - 0.45, z + 0.32), Color("3a3936") if dead else lamp)
			i += 1
	if k.age == Age.WORN:
		var b := VoxelMeshBuilder.new()
		var x: float = COLS_X[2]
		var z: float = ROWS_Z[1]
		b.add_box(Transform3D(Basis.from_scale(Vector3(0.64, 0.02, 0.64)), Vector3(x, y - 0.46, z)), lamp)
		_flicker = MeshInstance3D.new()
		_flicker.name = "FlickerLamp"
		_flicker.mesh = b.commit(VenueKit.glow_material())
		_flicker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		k.add(_flicker)
	var energy: float = k.by_age(0.55, 0.7, 0.85)
	for p in SPOTS:
		var sp := SpotLight3D.new()
		sp.position = p
		sp.rotation_degrees = Vector3(-90, 0, 0)
		sp.spot_range = 19.0
		sp.spot_angle = 62.0
		sp.spot_attenuation = 0.6
		sp.light_energy = energy
		sp.light_color = lamp
		sp.shadow_enabled = false
		sp.light_specular = 0.3
		sp.set_meta("energy", energy)
		_spots.append(sp)
		k.add(sp)


## Seen from above the roof only the lamps hide; the light stays on the ice.
func set_overhead_hidden(hidden: bool) -> void:
	_hidden = hidden
	for c in get_children():
		if c is MeshInstance3D:
			c.visible = not hidden


## Sets the match's sun and ambient light for this lighting age.
func apply(env: Environment, sun: DirectionalLight3D) -> void:
	var a := age
	if sun:
		sun.light_energy = [0.74, 0.84, 0.9][a]
		sun.light_color = [Color(0.98, 0.97, 0.93), Color(1.0, 0.99, 0.97), Color(0.97, 0.99, 1.0)][a]
	if env:
		env.ambient_light_color = [Color(0.86, 0.87, 0.85), Color(0.87, 0.88, 0.91), Color(0.86, 0.9, 0.98)][a]
		env.ambient_light_energy = [0.24, 0.27, 0.3][a]
		env.background_color = Color("1b1a19")


func _process(dt: float) -> void:
	if _flicker == null or not is_instance_valid(_flicker) or _hidden:
		return
	_flicker_t -= dt
	if _flicker_t <= 0.0:
		var on := _rng.randf() < 0.7
		_flicker.visible = on
		_flicker_t = _rng.randf_range(0.04, 0.5) if on else _rng.randf_range(0.03, 0.15)
		if not _spots.is_empty():
			_spots[1].light_energy = _spots[1].get_meta("energy") * (1.0 if on else 0.55)
