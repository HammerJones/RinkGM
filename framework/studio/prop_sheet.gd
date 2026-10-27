extends SceneTree
## Renders every .vox under art/props/ (or the ids given) to one contact
## sheet, as the game draws them: VoxMesher with AO, a key light with
## shadows, SSAO. Needs a display (a virtual one is fine):
##
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 \
##       --rendering-method gl_compatibility --script res://framework/studio/prop_sheet.gd \
##       -- [ids...] [--out=path] [--tile=400] [--yaw=-38]
##
## or tools/prop_sheet.sh. Writes art/props/preview/sheet.png and one
## art/props/preview/<id>.png per prop (a three-quarter view, framed by the
## prop's bounds). This is how a prop gets looked at before it is reviewed:
## a person opens the sheet, Claude reads the image.

const VOX_DIR := "res://art/props"
const OUT_DIR := "res://art/props/preview"
const DEFAULT_TILE := 400
const COLUMNS := 4

var ids: Array = []
var tile := DEFAULT_TILE
var yaw := -38.0  # camera angle around the prop, degrees; 0 looks straight at the front
var out_path := OUT_DIR + "/sheet.png"
var index := 0
var frame := 0
var tiles: Array = []  # [id, Image]
var _cam: Camera3D
var _holder: Node3D
var _label: Label
var _wait := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.trim_prefix("--out=")
		elif a.begins_with("--tile="):
			tile = int(a.trim_prefix("--tile="))
		elif a.begins_with("--yaw="):
			yaw = float(a.trim_prefix("--yaw="))
		elif not a.begins_with("--"):
			ids.append(a)
	if ids.is_empty():
		var dir := DirAccess.open(VOX_DIR)
		if dir:
			for f in dir.get_files():
				if f.get_extension() == "vox":
					ids.append(f.get_basename())
		ids.sort()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	print("prop_sheet: %d props" % ids.size())


## The scene is built on the first frame, once the window exists.
func _setup() -> void:
	root.size = Vector2i(tile, tile)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("2b2d33")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.63, 0.68)
	e.ambient_light_energy = 0.8
	e.ssao_enabled = true
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 40, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -120, 0)
	fill.light_energy = 0.35
	root.add_child(fill)
	_holder = Node3D.new()
	root.add_child(_holder)
	_cam = Camera3D.new()
	_cam.fov = 35.0
	root.add_child(_cam)
	_label = Label.new()
	_label.position = Vector2(8, tile - 28)
	root.add_child(_label)


func _process(_dt: float) -> bool:
	frame += 1
	if frame == 1:
		_setup()
	if frame < 3:
		return false
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			_capture()
			index += 1
		return false
	if index >= ids.size():
		_write_sheet()
		quit()
		return true
	_show(ids[index])
	_wait = 4
	return false


func _show(id: String) -> void:
	for c in _holder.get_children():
		c.queue_free()
	var asset := VoxAsset.load_any("%s/%s.vox" % [VOX_DIR, id])
	if asset == null:
		push_error("prop_sheet: %s failed to load" % id)
		return
	var mesh: ArrayMesh = asset.mesh
	if mesh == null:
		var m := asset.to_model()
		var b := asset.bounds()
		m.set_pivot(
			b.position.x + b.size.x / 2.0 + 0.5, b.position.y, b.position.z + b.size.z / 2.0 + 0.5
		)
		mesh = VoxMesher.build(m, {"greedy": true})
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = PropMaterial.shared()
	_holder.add_child(mi)
	var aabb := mesh.get_aabb()
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(aabb.get_longest_axis_size() * 2.5, aabb.get_longest_axis_size() * 2.5)
	floor_mi.mesh = plane
	floor_mi.position.y = aabb.position.y - 0.001
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("3a3c42")
	fm.roughness = 1.0
	floor_mi.material_override = fm
	_holder.add_child(floor_mi)
	var centre := aabb.get_center()
	var radius := aabb.size.length() * 0.5
	var dist := radius / tan(deg_to_rad(_cam.fov * 0.5)) * 1.15
	var dir := Vector3(sin(deg_to_rad(yaw)), 0.55, -cos(deg_to_rad(yaw))).normalized()
	_cam.position = centre + dir * dist
	_cam.look_at(centre, Vector3.UP)
	var lod_tris := 0
	if asset.mesh_lod and asset.mesh_lod.get_surface_count() > 0:
		lod_tris = asset.mesh_lod.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3
	_label.text = (
		"%s  %d tris (lod %d)  %.2f x %.2f x %.2f m"
		% [
			id,
			mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3,
			lod_tris,
			aabb.size.x,
			aabb.size.y,
			aabb.size.z
		]
	)


func _capture() -> void:
	var img := root.get_viewport().get_texture().get_image()
	var id: String = ids[index]
	img.save_png("%s/%s.png" % [OUT_DIR, id])
	tiles.append([id, img])
	print("  %s" % _label.text)


func _write_sheet() -> void:
	if tiles.is_empty():
		return
	var cols := mini(COLUMNS, tiles.size())
	var rows := ceili(float(tiles.size()) / cols)
	var sheet := Image.create(cols * tile, rows * tile, false, Image.FORMAT_RGB8)
	sheet.fill(Color("2b2d33"))
	for i in tiles.size():
		var img: Image = tiles[i][1]
		img.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(
			img, Rect2i(0, 0, tile, tile), Vector2i((i % cols) * tile, (i / cols) * tile)
		)
	sheet.save_png(out_path)
	print("prop_sheet: wrote %s (%d props)" % [out_path, tiles.size()])
