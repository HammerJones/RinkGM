extends SceneTree
## Checks the PeopleArt voxel bodies: every outfit at every age band builds a
## cached mesh under the triangle budget with its pivot on the floor, a crowd
## of random looks shares few meshes, instance data round-trips, and the pose
## shader compiles and draws.
##   godot --headless --path . --script res://tools/tests/test_people_art.gd

const BUDGET := 900  # triangles per person, worst case (docs/ART.md "People")
const TARGET := 600  # what an ordinary adult should come in under

var failures := 0
var _frames := 0
var _mmi: MultiMeshInstance3D


func _initialize() -> void:
	_check_meshes()
	_check_keys()
	_check_instance_data()
	_check_helpers()
	_check_material()


func _check_meshes() -> void:
	var worst := {}
	for band_age in [3, 8, 15, 40, 80]:
		var band := PeopleArt.band_of(band_age)
		for outfit in PeopleArt.OUTFITS:
			for build in PeopleArt.BUILDS:
				# the heaviest hair and the heaviest held item with each outfit
				var look := {"outfit": outfit, "build": build, "hair": "curly", "accessory": "sign"}
				var key := PeopleArt.shape_key(look, band_age)
				var m := PeopleArt.mesh(key)
				var label := "%s/%s/%s" % [band, outfit, build]
				if m == null or m.get_surface_count() == 0:
					_fail("%s: no mesh" % label)
					continue
				if PeopleArt.mesh(key) != m:
					_fail("%s: mesh not cached" % label)
				var tris := m.surface_get_array_index_len(0) / 3
				if tris > BUDGET:
					_fail("%s: %d triangles (budget %d)" % [label, tris, BUDGET])
				worst[band] = maxi(worst.get(band, 0), tris)
				# skaters hang their blades 1 V below the pivot; the shader lifts them
				var aabb := m.get_aabb()
				var floor_y := -(PeopleArt.SKATE - PeopleArt.SHOE) * PeopleArt.V if outfit in PeopleArt.SKATE_OUTFITS else 0.0
				if absf(aabb.position.y - floor_y) > 0.001:
					_fail("%s: lowest point %.3f m, expected %.3f" % [label, aabb.position.y, floor_y])
				var body := PeopleArt.mesh(PeopleArt.layer_keys(look, band_age)[0]).get_aabb()
				if absf(body.get_center().x) > 0.01:
					_fail("%s: body not centred on the pivot (x %.2f)" % [label, body.get_center().x])
	print("triangles, worst outfit with curly hair and a sign: %s" % worst)
	# an ordinary adult in the stands
	var plain := PeopleArt.mesh(PeopleArt.shape_key({"outfit": "parka", "hair": "short", "accessory": "coffee"}, 40))
	var plain_tris := plain.surface_get_array_index_len(0) / 3
	print("adult in a parka with a coffee: %d triangles" % plain_tris)
	if plain_tris > TARGET:
		_fail("ordinary adult has %d triangles (target %d)" % [plain_tris, TARGET])
	# heights: bands clearly different, adults match the shared proportions
	var adult := PeopleArt.mesh(PeopleArt.shape_key({"outfit": "casual", "hair": "short"}, 40)).get_aabb().size.y
	var skater := PeopleArt.mesh(PeopleArt.shape_key({"outfit": "casual", "hair": "short", "skates": true}, 40)).get_aabb().size.y
	if absf(adult - PeopleArt.HEIGHT * PeopleArt.V) > 0.01:
		_fail("adult in shoes is %.3f m, expected %.3f" % [adult, PeopleArt.HEIGHT * PeopleArt.V])
	if absf(skater - adult - (PeopleArt.SKATE - PeopleArt.SHOE) * PeopleArt.V) > 0.01:
		_fail("skates should add %.2f V, got %.3f m" % [PeopleArt.SKATE - PeopleArt.SHOE, skater - adult])
	var six := PeopleArt.eye_height({}, 6) / PeopleArt.eye_height({}, 40)
	print("eye height, 6-year-old / adult: %.2f" % six)
	if six > 0.72 or six < 0.5:
		_fail("a 6-year-old should be well under adult height (ratio %.2f)" % six)


func _check_keys() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var full := {}
	var layers := {}
	for i in 500:
		var age := rng.randi_range(2, 90)
		var where: String = ["stands", "stands", "stands", "ice", "staff"][i % 5]
		var look := PeopleArt.random_look(rng, age, where)
		var key := PeopleArt.shape_key(look, age)
		full[key] = true
		for k in PeopleArt.layer_keys(look, age):
			layers[k] = true
		for c in look.get("colors", []):
			if key.contains(str(c)):
				_fail("colour %s leaked into shape key %s" % [c, key])
	print("500 random looks: %d whole-person shape keys, %d layer meshes" % [full.size(), layers.size()])
	if layers.size() > 250:
		_fail("500 people need %d layer meshes (want under 250)" % layers.size())
	# colours and height never change the key
	var a := {"outfit": "hoodie", "colors": ["d0202a", "eeeeea"], "height": 0.9, "skin": 0}
	var b := {"outfit": "hoodie", "colors": ["1d3557", "d9a62e"], "height": 1.1, "skin": 3}
	if PeopleArt.shape_key(a, 30) != PeopleArt.shape_key(b, 30):
		_fail("colours or height changed the shape key")
	# layers mesh to the same triangles as the whole person
	var look := {"outfit": "parka", "accessory": "thermos", "hair": "long"}
	var sum := 0
	for k in PeopleArt.layer_keys(look, 50):
		sum += PeopleArt.mesh(k).surface_get_array_index_len(0) / 3
	if sum != PeopleArt.mesh(PeopleArt.shape_key(look, 50)).surface_get_array_index_len(0) / 3:
		_fail("layer meshes don't add up to the whole person")


func _check_instance_data() -> void:
	var look := {"outfit": "team_jacket", "colors": ["d0202a", "eeeeea", "1d3557"], "hair_color": "d4b06a", "skin": 2, "height": 1.05}
	for pose in PeopleArt.Pose.values():
		for phase in [0.0, 0.25, 0.97]:
			for moving in [false, true]:
				var c := PeopleArt.instance_data(look, pose, phase, 34, moving)
				var d := PeopleArt.decode(c)
				if d.pose != pose or d.moving != moving or d.skates:
					_fail("pose %d moving %s came back as %s" % [pose, moving, d])
				if absf(fposmod(d.phase - phase + 0.5, 1.0) - 0.5) > 1.0 / 32.0:
					_fail("phase %.2f came back as %.2f" % [phase, d.phase])
				# exact even as half floats: integers under 2048
				for ch in [c.r, c.g, c.b, c.a]:
					if ch != floorf(ch) or ch < 0.0 or ch >= 2048.0:
						_fail("custom data %s is not a small integer" % c)
	var d := PeopleArt.decode(PeopleArt.instance_data(look, PeopleArt.Pose.SIT, 0.0, 34))
	if PeopleArt.PALETTE[d.primary] != "d0202a" or PeopleArt.PALETTE[d.accent] != "1d3557" or d.skin != 2:
		_fail("colours didn't round-trip: %s" % d)
	if absf(d.scale - 1.05) > 0.021:
		_fail("height 1.05 came back as scale %.2f" % d.scale)
	if not PeopleArt.decode(PeopleArt.instance_data({"outfit": "figure_dress"}, 0, 0.0, 12)).skates:
		_fail("a figure skater isn't flagged on skates")
	if not PeopleArt.decode(PeopleArt.instance_data({}, 0, 0.0, 80)).elder:
		_fail("an 80-year-old isn't flagged elder")


func _check_helpers() -> void:
	# gait: an adult at walking speed cycles at cadence / 2; kids cycle faster
	var adult_rate := PeopleArt.walk_phase_rate(PeopleArt.WALK_SPEED)
	if absf(adult_rate - PeopleArt.gait("walk_cadence") * 0.5) > 0.01:
		_fail("adult walk phase rate %.3f, expected cadence / 2 = %.3f" % [adult_rate, PeopleArt.gait("walk_cadence") * 0.5])
	if PeopleArt.walk_phase_rate(PeopleArt.WALK_SPEED, {}, 6) <= adult_rate:
		_fail("a 6-year-old should cycle faster than an adult at the same speed")
	if not PeopleArt.decode(PeopleArt.instance_data({}, PeopleArt.Pose.WALK, 0.0, 30, false, 3.0)).run:
		_fail("3 m/s isn't flagged as a run")
	for age in [3, 8, 15, 40, 80]:
		var l := {"build": "big", "outfit": "parka"}
		var r := PeopleArt.body_radius(l, age)
		var e := PeopleArt.eye_height(l, age)
		var s := PeopleArt.seat_offset(l, age)
		if r < 0.1 or r > 0.6 or e < 0.5 or e > 1.9:
			_fail("age %d: radius %.2f or eye height %.2f out of range" % [age, r, e])
		if absf(s.y + PeopleArt.SEAT_H) > 0.001 or s.z > 0.0:
			_fail("age %d: seat offset %s" % [age, s])


## The shader must compile and draw: a MultiMesh of one in the tree for a few frames.
func _check_material() -> void:
	var mat := PeopleArt.material()
	if mat == null or mat.shader == null or mat.shader.code.is_empty():
		_fail("no people material")
	var look := {"outfit": "hockey_gear", "accessory": "stick"}
	_mmi = MultiMeshInstance3D.new()
	var mm := PeopleArt.multimesh(PeopleArt.shape_key(look, 20), 1)
	mm.set_instance_transform(0, Transform3D.IDENTITY)
	mm.set_instance_custom_data(0, PeopleArt.instance_data(look, PeopleArt.Pose.SKATE, 0.3, 20))
	_mmi.multimesh = mm
	root.add_child(_mmi)
	if mm.mesh.surface_get_material(0) != mat:
		_fail("mesh doesn't carry the shared material")
	var params := RenderingServer.get_shader_parameter_list(mat.shader.get_rid())
	var names := []
	for p in params:
		names.append(p.name)
	if not "palette" in names or not "seat_height" in names:
		_fail("shader uniforms missing (compile failed?): %s" % [names])


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	if failures == 0:
		print("people art test: all passed (%d outfits x 5 bands x 4 builds, %d poses)" % [PeopleArt.OUTFITS.size(), PeopleArt.Pose.size()])
	quit(1 if failures else 0)
	return true


func _fail(msg: String) -> void:
	printerr(msg)
	failures += 1
