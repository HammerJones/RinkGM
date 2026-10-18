extends SceneTree
## Renders every prop in the kit at each renovation age to one PNG, for
## reviewing the look. Needs a renderer (not --headless); see docs/ART.md for the cloud recipe:
##   godot --path . --script res://art/tools/prop_sheet.gd -- --out=props.png [--ids=door,light] [--lod=1] [--yaw=deg]
## With --age=worn|repaired|renovated it renders that one age instead, in a
## labelled grid of --cols columns (default 5; "-" in --ids leaves a cell
## empty), e.g. the plant room:
##   ... -- --age=worn --ids=compressor_recip,chiller,... --out=plant_worn.png

const COL_GAP := 3.2
const ROW_GAP := 4.2

var _out := "prop_sheet.png"
var _frames := 0
var _lod := 0
var _yaw := PI - 0.55  # props face -Z; turn them three-quarters to the camera
var _age := -1
var _cols := 5


func _initialize() -> void:
	var ids: Array = Props.ids()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--ids="):
			ids = Array(arg.trim_prefix("--ids=").split(","))
		elif arg.begins_with("--lod="):
			_lod = int(arg.trim_prefix("--lod="))
		elif arg.begins_with("--yaw="):
			_yaw = deg_to_rad(float(arg.trim_prefix("--yaw=")))
		elif arg.begins_with("--age="):
			_age = Wear.NAMES.find(arg.trim_prefix("--age="))
		elif arg.begins_with("--cols="):
			_cols = int(arg.trim_prefix("--cols="))
	if _age >= 0:
		_grid(ids)
		return
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
			mi.rotation.y = _yaw
			if ids[r] == "light":
				mi.position.y = 1.6
			elif ids[r] == "rink_sign":
				mi.position.y = 0.8
			elif ids[r] == "scoreboard":
				mi.scale = Vector3.ONE * 0.45
				mi.position.y = 1.7 if age == Wear.RENOVATED else 0.3
			elif ids[r] == "glass_pane":
				var fr := MeshInstance3D.new()
				fr.mesh = Props.mesh("glass_frame", age, _lod)
				fr.position = mi.position
				fr.rotation.y = mi.rotation.y
				world.add_child(fr)
			elif ids[r] == "resurfacer" or ids[r] == "penalty_box":
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


## One age, a labelled grid. Props keep their real size; wall props are
## lifted to a mounting height.
func _grid(ids: Array) -> void:
	const CELL := 4.4
	const CELL_Z := 5.4
	var rows := ceili(float(ids.size()) / _cols)
	var view_w := CELL * _cols + 0.6
	var view_h := CELL_Z * rows * 0.62 + 1.6
	DisplayServer.window_set_size(Vector2i(2000, int(2000.0 * view_h / view_w)))
	var world := Node3D.new()
	root.add_child(world)
	_environment(world)
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(CELL * _cols + 4, 0.1, CELL_Z * rows + 4)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("3a3b42")
	floor_mesh.material = floor_mat
	var fl := MeshInstance3D.new()
	fl.mesh = floor_mesh
	var centre := Vector3(CELL * (_cols - 1) * 0.5, 0, CELL_Z * (rows - 1) * 0.5)
	fl.position = centre - Vector3(0, 0.05, 0)
	world.add_child(fl)
	for i in ids.size():
		var at := Vector3((i % _cols) * CELL, 0, (i / _cols) * CELL_Z)
		if ids[i] == "-":
			continue  # an empty cell, e.g. behind something tall
		var mi := MeshInstance3D.new()
		mi.mesh = Props.mesh(ids[i], _age, _lod)
		mi.position = at
		mi.rotation.y = _yaw
		if ids[i] in ["ammonia_detector", "light", "rink_sign"]:
			mi.position.y = 1.0
		world.add_child(mi)
		var label := Label3D.new()
		label.text = ids[i]
		label.font_size = 64
		label.pixel_size = 0.0045
		label.outline_size = 12
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position = at + Vector3(0, 0.25, 2.1)
		world.add_child(label)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = view_w
	cam.rotation_degrees = Vector3(-34, 0, 0)
	cam.position = centre + Vector3(0, 0.9, 0) + cam.basis.z * 40.0
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
