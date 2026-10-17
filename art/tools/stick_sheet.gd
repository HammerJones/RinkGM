extends SceneTree
## Renders the skater stick (shaft + blade, put together the way SkaterRig
## does) on the ice, for reviewing the blade and heel. Needs a renderer; see
## docs/ART.md for the cloud recipe:
##   godot --path . --script res://art/tools/stick_sheet.gd -- --out=stick.png [--view=full|heel|top]

const LIE_DEG := 47.0  # shaft angle off the ice for the review pose

var _out := "stick_sheet.png"
var _view := "full"
var _frames := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--view="):
			_view = arg.trim_prefix("--view=")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var world := Node3D.new()
	root.add_child(world)
	_environment(world)
	var ice := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6, 0.1, 6)
	var ice_mat := StandardMaterial3D.new()
	ice_mat.albedo_color = Color("eef4f8")
	box.material = ice_mat
	ice.mesh = box
	ice.position.y = -0.05
	world.add_child(ice)

	var pal := Models.palette(0)
	var blade := VoxelPart.make(Models.blade(pal))
	world.add_child(blade)
	var shaft := VoxelPart.make(Models.shaft(pal))
	var lie := deg_to_rad(LIE_DEG)
	var y := Vector3(-cos(lie), sin(lie), 0)
	var x := (Vector3.RIGHT - y * y.x).normalized()
	shaft.transform = Transform3D(Basis(x, y, x.cross(y)), Models.blade_heel)
	world.add_child(shaft)
	var puck := VoxelPart.make(Models.puck())
	puck.position = Vector3(0.45, 0, 0.05)
	world.add_child(puck)

	var cam := Camera3D.new()
	world.add_child(cam)
	match _view:
		"heel":
			cam.fov = 30
			cam.look_at_from_position(Vector3(-0.1, 0.12, 0.75), Vector3(-0.1, 0.06, 0.0))
		"top":
			cam.fov = 35
			cam.look_at_from_position(Vector3(-0.05, 0.9, 0.35), Vector3(-0.05, 0.0, 0.0))
		_:
			cam.fov = 40
			cam.look_at_from_position(Vector3(-0.35, 0.55, 2.3), Vector3(-0.35, 0.55, 0.0))
	cam.current = true


func _environment(parent: Node) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2b2f3a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.89, 0.96)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.shadow_enabled = true
	parent.add_child(sun)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 10:
		root.get_texture().get_image().save_png(_out)
		print("stick sheet saved to ", _out)
		return true
	return false
