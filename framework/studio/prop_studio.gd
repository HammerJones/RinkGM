extends Node3D
## The prop studio: every .vox under art/props/ and every coded kit prop,
## drawn the way the game draws them (VoxMesher with AO, Wear's three ages
## side by side, shadows and SSAO), with the numbers that matter (triangles
## per detail level, voxels, size, collision boxes). The authoring loop for
## props: edit in MagicaVoxel, press R here.
##
##   godot --path . res://scenes/dev/prop_studio.tscn
##   drag: orbit   wheel: zoom   up/down: pick   A: AO   G: greedy
##   B: boxes   R: reload from disk   Esc: quit
##
## `-- --test=studio` builds every prop headless and prints a line per prop
## (the CI smoke test; no window needed).

const VOX_DIR := "res://art/props"
const GAP := 0.4

var entries: Array = []  # [{"id": String, "kind": "vox" | "kit", "path": String}]
var index := 0
var ao := true
var greedy := false
var show_boxes := true

var _list: ItemList
var _info: Label
var _title: Label
var _pivot: Node3D
var _cam: Camera3D
var _models: Node3D
var _yaw := 0.6
var _pitch := 0.35
var _dist := 3.0
var _dragging := false


func _ready() -> void:
	_scan()
	if OS.get_cmdline_user_args().has("--test=studio"):
		_self_test()
		return
	_build_scene()
	_build_ui()
	_show()


# --- the library ----------------------------------------------------------


func _scan() -> void:
	entries.clear()
	var dir := DirAccess.open(VOX_DIR)
	if dir:
		for f in dir.get_files():
			if f.get_extension() == "vox":
				entries.append({"id": f.get_basename(), "kind": "vox", "path": VOX_DIR + "/" + f})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	for id in Props.ids():
		entries.append({"id": id, "kind": "kit", "path": ""})


## The model for an entry at an age, weathered like the game does it.
func model_of(e: Dictionary, age: int) -> VoxelModel:
	if e.kind == "kit":
		return Props.model(e.id, age)
	var asset := VoxAsset.load_any(e.path)
	if asset == null:
		return null
	var m := asset.to_model()
	var b := asset.bounds()
	m.set_pivot(
		b.position.x + b.size.x / 2.0 + 0.5, b.position.y, b.position.z + b.size.z / 2.0 + 0.5
	)
	return Wear.weather(m, age)


func mesh_of(m: VoxelModel) -> ArrayMesh:
	return VoxMesher.build(m, {"ao": ao, "greedy": greedy})


# --- the view -------------------------------------------------------------


func _build_scene() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("2b2d33")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.62)
	e.ambient_light_energy = 0.9
	e.ssao_enabled = true
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("a8a294")
	fm.roughness = 1.0
	floor_mi.material_override = fm
	add_child(floor_mi)
	_pivot = Node3D.new()
	add_child(_pivot)
	_cam = Camera3D.new()
	_cam.fov = 45.0
	_pivot.add_child(_cam)
	_models = Node3D.new()
	add_child(_models)
	_orbit()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.custom_minimum_size.x = 300
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_title = Label.new()
	_title.text = "// PROP STUDIO"
	box.add_child(_title)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for e in entries:
		_list.add_item("%s  [%s]" % [e.id, e.kind])
	_list.item_selected.connect(
		func(i: int) -> void:
			index = i
			_show()
	)
	box.add_child(_list)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info.custom_minimum_size.y = 180
	box.add_child(_info)
	var help := Label.new()
	help.text = "drag orbit  wheel zoom  A ao  G greedy  B boxes  R reload  Esc quit"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(help)
	if not entries.is_empty():
		_list.select(0)


func _show() -> void:
	for c in _models.get_children():
		c.queue_free()
	if entries.is_empty():
		_info.text = "no props: put a .vox in %s" % VOX_DIR
		return
	var e: Dictionary = entries[index]
	var lines: Array[String] = [e.id, e.kind if e.kind == "kit" else e.path]
	var widest := 0.0
	var meshes: Array = []
	for age in 3:
		var m := model_of(e, age)
		if m == null:
			lines.append("%s: failed to load" % Wear.NAMES[age])
			meshes.append(null)
			continue
		var full := mesh_of(m)
		var lod := VoxMesher.build(m, {"ao": ao, "greedy": true})
		var boxes := m.collision_boxes()
		var aabb := full.get_aabb()
		widest = maxf(widest, aabb.size.x)
		meshes.append([full, boxes, aabb])
		lines.append(
			(
				"%s: %d vox, %d tris (lod %d), %d boxes, %.2f x %.2f x %.2f m"
				% [
					Wear.NAMES[age],
					m.voxels.size(),
					_tris(full),
					_tris(lod),
					boxes.size(),
					aabb.size.x,
					aabb.size.y,
					aabb.size.z
				]
			)
		)
	var x := -(widest + GAP)
	var tallest := 0.0
	for age in 3:
		if meshes[age] == null:
			x += widest + GAP
			continue
		var holder := Node3D.new()
		holder.position.x = x
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[age][0]
		mi.material_override = PropMaterial.shared()
		holder.add_child(mi)
		if show_boxes:
			for b in meshes[age][1]:
				holder.add_child(_wire(b))
		_models.add_child(holder)
		tallest = maxf(tallest, meshes[age][2].size.y)
		x += widest + GAP
	_pivot.position = Vector3(0, tallest * 0.5, 0)
	_dist = maxf(2.0, (widest * 3 + GAP * 2) * 1.2 + tallest)
	_orbit()
	lines.append("ao %s  greedy %s" % ["on" if ao else "off", "on" if greedy else "off"])
	_info.text = "\n".join(lines)


func _wire(b: AABB) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = b.size
	mi.mesh = bm
	mi.position = b.get_center()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.4, 0.2, 0.9)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.wireframe = true
	mi.material_override = mat
	return mi


func _orbit() -> void:
	if _pivot == null:
		return
	_pivot.rotation = Vector3(-_pitch, _yaw, 0)
	_cam.position = Vector3(0, 0, _dist)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_dist = maxf(0.5, _dist * 0.9)
			_orbit()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_dist = minf(40.0, _dist * 1.1)
			_orbit()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.01
		_pitch = clampf(_pitch + mm.relative.y * 0.01, -0.2, 1.4)
		_orbit()
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_A:
				ao = not ao
				_show()
			KEY_G:
				greedy = not greedy
				_show()
			KEY_B:
				show_boxes = not show_boxes
				_show()
			KEY_R:
				_scan()
				_list.clear()
				for e in entries:
					_list.add_item("%s  [%s]" % [e.id, e.kind])
				index = clampi(index, 0, maxi(entries.size() - 1, 0))
				if not entries.is_empty():
					_list.select(index)
				_show()
			KEY_DOWN:
				_step(1)
			KEY_UP:
				_step(-1)
			KEY_ESCAPE:
				get_tree().quit()


func _step(d: int) -> void:
	if entries.is_empty():
		return
	index = posmod(index + d, entries.size())
	_list.select(index)
	_show()


static func _tris(mesh: ArrayMesh) -> int:
	if mesh == null or mesh.get_surface_count() == 0:
		return 0
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3


# --- headless smoke test --------------------------------------------------


func _self_test() -> void:
	var failures := 0
	var vox := 0
	for e in entries:
		for age in 3:
			var m := model_of(e, age)
			if m == null or m.voxels.is_empty():
				push_error("studio: %s %s has no model" % [e.id, Wear.NAMES[age]])
				failures += 1
				continue
			var mesh := VoxMesher.build(m)
			if _tris(mesh) == 0:
				push_error("studio: %s %s has no mesh" % [e.id, Wear.NAMES[age]])
				failures += 1
		if e.kind == "vox":
			vox += 1
	print(
		(
			"studio: %d props (%d .vox, %d kit), ao mesher ok"
			% [entries.size(), vox, entries.size() - vox]
		)
	)
	if failures == 0:
		print("studio test: all passed")
	get_tree().quit(1 if failures else 0)
