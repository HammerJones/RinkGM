extends SceneTree
## Renders every prop in the kit at each renovation age to one PNG, for
## reviewing the look. Needs a renderer (not --headless); see docs/ART.md for the cloud recipe:
##   godot --path . --script res://art/tools/prop_sheet.gd -- --out=props.png [--ids=door,light] [--lod=1]

const COL_GAP := 3.2
const ROW_GAP := 4.2

var _out := "prop_sheet.png"
var _frames := 0
var _lod := 0


func _initialize() -> void:
	var ids: Array = Props.ids()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--ids="):
			ids = Array(arg.trim_prefix("--ids=").split(","))
		elif arg.begins_with("--lod="):
			_lod = int(arg.trim_prefix("--lod="))
	var view_h := ROW_GAP * ids.size() * 0.56 + 2.0
	DisplayServer.window_set_size(Vector2i(1800, int(1800.0 * view_h / 11.0)))
	var world := Node3D.new()
	root.add_child(world)
	_environment(world)
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(COL_GAP * 3 + 2, 0.1, ROW_GAP * ids.size() + 2)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("3a3b42")
	floor_mesh.material = floor_mat
	var fl := MeshInstance3D.new()
	fl.mesh = floor_mesh
	fl.position = Vector3(COL_GAP, -0.05, ROW_GAP * (ids.size() - 1) * 0.5)
	world.add_child(fl)
	for r in ids.size():
		for age in 3:
			var mi := MeshInstance3D.new()
			mi.mesh = Props.mesh(ids[r], age, _lod)
			mi.position = Vector3(age * COL_GAP, 0, r * ROW_GAP)
			mi.rotation.y = PI - 0.55  # props face -Z; turn them three-quarters to the camera
			if ids[r] == "light":
				mi.position.y = 1.6
			elif ids[r] == "rink_sign":
				mi.position.y = 0.8
			elif ids[r] == "resurfacer":
				mi.scale = Vector3.ONE * 0.6
			world.add_child(mi)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = view_h
	cam.rotation_degrees = Vector3(-34, 0, 0)
	var centre := Vector3(COL_GAP, 0.8, ROW_GAP * (ids.size() - 1) * 0.5)
	cam.position = centre + cam.basis.z * 30.0
	world.add_child(cam)
	cam.current = true


func _environment(parent: Node) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("24252b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.89, 0.96)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.shadow_enabled = true
	parent.add_child(sun)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 10:
		root.get_texture().get_image().save_png(_out)
		print("prop sheet saved to ", _out)
		return true
	return false
