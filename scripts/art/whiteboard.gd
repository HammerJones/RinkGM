class_name Whiteboard
extends Node3D
## A real dry-erase board on a wall. Two layers of ink: what the people of
## the rink drew on it (a Readable, `marks`, drawn in their own hands) and the
## player's own scribbles on top, kept apart so wiping or doodling never
## touches theirs. Draw by holding the left mouse on it in the walk, wipe
## your own marks with X. The face looks along local +Z, origin at the
## board's centre on the wall.

const PX_PER_M := 220.0
const INK := Color("1b2a4a")

## readables.json id of the people's drawings (kept as the board's
## Readable for leaning in to read; what they wrote today is `people`).
var marks_id := "whiteboard_marks"
## Which board this is (its room): with the day it picks what the people
## wrote (BoardMarks), so boards differ from each other and change daily
## (evening notes W7, W15). Empty: the one shared drawing (marks_id).
var board_key := ""
## The day every board shows; set_day() moves them all on.
static var day := 0
## signature -> board key, for the current day: no two boards alike.
static var _taken := {}
var signature := ""
var _people_img: Image
var _ink_mi: MeshInstance3D
var _people_tex: ImageTexture
var size := Vector2(2.4, 1.25)
var marks: Readable
var _img: Image
var _tex: ImageTexture
var _last := Vector2i(-1, -1)
var _dirty := false


static func make(marks_id_ := "whiteboard_marks", key := "") -> Whiteboard:
	var w := Whiteboard.new()
	w.name = "Whiteboard"
	w.marks_id = marks_id_
	w.board_key = key
	var d: Dictionary = Readable.defs().get(marks_id_, {})
	if d.has("size"):
		w.size = Vector2(d.size[0], d.size[1])
	return w


func _ready() -> void:
	# the board: white melamine in an aluminium frame, a marker tray
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, size.y, 0.012)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("eef0ee")
	white.roughness = 0.22
	bm.material = white
	board.mesh = bm
	board.position.z = 0.006
	add_child(board)
	# the frame and tray as one mesh, the three markers as one (few draws:
	# a rec wing has a board in every dressing room)
	var alu := StandardMaterial3D.new()
	alu.albedo_color = Color("a9adb2")
	alu.metallic = 0.7
	alu.roughness = 0.35
	var st := SurfaceTool.new()
	for e in [[Vector3(size.x + 0.05, 0.025, 0.02), Vector3(0, size.y * 0.5 + 0.0125, 0.01)],
			[Vector3(size.x + 0.05, 0.025, 0.02), Vector3(0, -size.y * 0.5 - 0.0125, 0.01)],
			[Vector3(0.025, size.y, 0.02), Vector3(size.x * 0.5 + 0.0125, 0, 0.01)],
			[Vector3(0.025, size.y, 0.02), Vector3(-size.x * 0.5 - 0.0125, 0, 0.01)],
			[Vector3(size.x * 0.6, 0.012, 0.07), Vector3(0, -size.y * 0.5 - 0.03, 0.035)]]:
		var b := BoxMesh.new()
		b.size = e[0]
		st.append_from(b, 0, Transform3D(Basis.IDENTITY, e[1]))
	var frame := MeshInstance3D.new()
	frame.mesh = st.commit()
	frame.material_override = alu
	add_child(frame)
	var ms := SurfaceTool.new()
	for i in 3:
		var c := CylinderMesh.new()
		c.top_radius = 0.009
		c.bottom_radius = 0.009
		c.height = 0.13
		c.radial_segments = 6
		var arr := c.get_mesh_arrays()
		var cols := PackedColorArray()
		cols.resize((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		cols.fill([Color("1b2a4a"), Color("b8312f"), Color("2a7a4a")][i])
		arr[Mesh.ARRAY_COLOR] = cols
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		ms.append_from(am, 0, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.3 + i * 0.2, -size.y * 0.5 - 0.02, 0.04)))
	var pens := StandardMaterial3D.new()
	pens.vertex_color_use_as_albedo = true
	var markers := MeshInstance3D.new()
	markers.mesh = ms.commit()
	markers.material_override = pens
	add_child(markers)
	# the people's drawings
	marks = Readable.make(marks_id)
	marks.position.z = 0.0122
	add_child(marks)
	if not board_key.is_empty():
		# today's, drawn for this board, in place of the shared drawing
		marks.visible = false
		_people_img = Image.create(int(size.x * PX_PER_M), int(size.y * PX_PER_M), false, Image.FORMAT_RGBA8)
		_people_tex = ImageTexture.create_from_image(_people_img)
		var pq := QuadMesh.new()
		pq.size = size
		var pm := StandardMaterial3D.new()
		pm.albedo_texture = _people_tex
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		pm.alpha_scissor_threshold = 0.5
		pm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		pm.roughness = 0.3
		pq.material = pm
		var people := MeshInstance3D.new()
		people.name = "People"
		people.mesh = pq
		people.position.z = 0.0128
		people.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(people)
		add_to_group("whiteboards")
		redraw()
	# the player's ink, on top
	_img = Image.create(int(size.x * PX_PER_M), int(size.y * PX_PER_M), false, Image.FORMAT_RGBA8)
	_img.fill(Color(0, 0, 0, 0))
	_tex = ImageTexture.create_from_image(_img)
	var ink := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	var im := StandardMaterial3D.new()
	im.albedo_texture = _tex
	im.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	im.alpha_scissor_threshold = 0.5
	im.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	im.roughness = 0.3
	q.material = im
	ink.mesh = q
	ink.position.z = 0.0135
	ink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ink.visible = false  # until you draw: no draw call for an empty layer
	_ink_mi = ink
	add_child(ink)
	# one pick shape for the whole board: leaning in reads the marks, the
	# left mouse draws
	var body := StaticBody3D.new()
	body.collision_layer = 1 << (Readable.READ_LAYER - 1)
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, size.y, 0.03)
	cs.shape = box
	cs.position.z = 0.015
	body.add_child(cs)
	body.set_meta("readable", marks)
	body.set_meta("whiteboard", self)
	add_child(body)
	marks.set_pickable(false)  # the board's own shape picks it
	Readable.shadows(self, Look.cast())


## Moves every keyed board in `tree` on to day `d` (call it when the rink's
## day turns over, e.g. on RinkSim.day_ended).
static func set_day(tree: SceneTree, d: int) -> void:
	if d != day:
		_taken.clear()
	day = d
	for n in tree.get_nodes_in_group("whiteboards"):
		(n as Whiteboard).redraw()


## Redraws what the people wrote for this board and the current day,
## salting the pick until no other board shows the same thing today.
func redraw() -> void:
	if _people_img == null:
		return
	if _taken.get(signature, "") == board_key:
		_taken.erase(signature)
	for salt in 16:
		signature = BoardMarks.draw(_people_img, board_key, day, salt)
		var owner_key: String = _taken.get(signature, board_key)
		if owner_key == board_key:
			break
	_taken[signature] = board_key
	_people_tex.update(_people_img)


## The whiteboard a pick ray hit, or null.
static func from_collider(c: Object) -> Whiteboard:
	if c and c is Node and (c as Node).has_meta("whiteboard"):
		return (c as Node).get_meta("whiteboard")
	return null


## Draws with the marker at world point `p`, joined to the last point of
## this stroke.
func draw_at(p: Vector3) -> void:
	var l := to_local(p)
	var px := Vector2i(int((l.x / size.x + 0.5) * _img.get_width()), int((0.5 - l.y / size.y) * _img.get_height()))
	if _last.x < 0:
		_last = px
	var steps := maxi(1, int(Vector2(px - _last).length()))
	for i in steps + 1:
		var q := Vector2(_last).lerp(Vector2(px), float(i) / steps)
		_dot(Vector2i(q.round()))
	_last = px
	_dirty = true
	_ink_mi.visible = true


## The marker lifted: the next draw starts a new stroke.
func end_stroke() -> void:
	_last = Vector2i(-1, -1)


## Wipes the player's own marks (the people's stay).
func wipe() -> void:
	_img.fill(Color(0, 0, 0, 0))
	_dirty = true


## How much of the player's layer has ink (0..1), for tests.
func ink_coverage() -> float:
	var n := 0
	for y in range(0, _img.get_height(), 4):
		for x in range(0, _img.get_width(), 4):
			if _img.get_pixel(x, y).a > 0.5:
				n += 1
	return float(n) / float((_img.get_width() / 4) * (_img.get_height() / 4))


func _dot(c: Vector2i) -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x := c.x + dx
			var y := c.y + dy
			if x >= 0 and y >= 0 and x < _img.get_width() and y < _img.get_height():
				_img.set_pixel(x, y, INK)


func _process(_dt: float) -> void:
	if _dirty:
		_tex.update(_img)
		_dirty = false
