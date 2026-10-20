extends SceneTree
## Renders every manifest prop (PropLibrary, data/props/) at its three ages
## to one contact-sheet PNG: a cell per (prop, age), ages across, two props
## per row, each cell framed to the prop's bounds with its name and age
## under it. Needs a renderer (run under xvfb; lavapipe or llvmpipe is fine):
##   xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/prop_sheet.gd -- --out=prop_sheet.png [--ids=a,b]
## CI uploads it as the prop-sheet artefact (.github/workflows/ci.yml).

const CELL := 256
const PER_ROW := 2  # props per row (three age cells each)

var _out := "prop_sheet.png"
var _ids: Array = []
var _cells: Array = []   # [id, age]
var _i := 0
var _frame := 0
var _sheet: Image
var _cam: Camera3D
var _holder: Node3D
var _label: Label3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--ids="):
			_ids = Array(a.trim_prefix("--ids=").split(","))
	if _ids.is_empty():
		_ids = PropLibrary.ids()
	for id in _ids:
		for age in 3:
			_cells.append([id, age])
	DisplayServer.window_set_size(Vector2i(CELL, CELL))
	var rows := ceili(float(_ids.size()) / PER_ROW)
	_sheet = Image.create(CELL * 3 * PER_ROW, CELL * rows, false, Image.FORMAT_RGB8)
	_sheet.fill(Color("1e2128"))
	var env := Look.make("arena")
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2a2e38")
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, 140.0, 0.0)
	fill.light_energy = 0.35
	root.add_child(fill)
	_holder = Node3D.new()
	root.add_child(_holder)
	_label = Label3D.new()
	_label.font_size = 48
	_label.pixel_size = 0.004
	_label.modulate = Color("e8e4da")
	_label.outline_size = 10
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(_label)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.near = 0.01
	_cam.far = 100.0
	root.add_child(_cam)
	_cam.current = true
	_place()


## The prop of the current cell at the origin, the camera three-quarter on
## and framed to its bounds, the label under it.
func _place() -> void:
	for c in _holder.get_children():
		c.queue_free()
	var id: String = _cells[_i][0]
	var age: int = _cells[_i][1]
	var mi := MeshInstance3D.new()
	mi.mesh = PropLibrary.mesh(id, age)
	_holder.add_child(mi)
	var b := PropLibrary.bounds(id, age)
	var centre := b.get_center()
	var extent := maxf(b.size.length() * 0.62, 0.12)
	var dir := Vector3(-0.55, 0.45, -1.0).normalized()  # the front (-Z) and the viewer's right
	_cam.size = extent * 2.0 * 1.4
	_cam.look_at_from_position(centre + dir * 10.0, centre, Vector3.UP)
	_label.text = "%s\n%s" % [PropLibrary.display_name(id), Wear.NAMES[age]]
	_label.position = centre - Vector3(0, extent * 1.0, 0)
	_label.pixel_size = extent * 0.0045
	_frame = 0


func _process(_dt: float) -> bool:
	_frame += 1
	if _frame < 6:
		return false
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if img.get_size() != Vector2i(CELL, CELL):
		img.resize(CELL, CELL)
	var col := (_i / 3) % PER_ROW * 3 + _i % 3
	var row := _i / (3 * PER_ROW)
	_sheet.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i(col * CELL, row * CELL))
	_i += 1
	if _i >= _cells.size():
		_sheet.save_png(_out)
		print("prop sheet: %s (%d props x 3 ages)" % [_out, _ids.size()])
		return true
	_place()
	return false
