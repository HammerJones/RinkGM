extends SceneTree
## The M1 character sheet for sign-off: the owner (three variants to choose
## from), Hélène Arsenault, Dale Huffman and Earl Bratt, Gus Tremblay as a
## framed photo from Florida, Earl as a portrait, four public skaters and four
## beer leaguers in mismatched gear. Each person stands and walks, front and
## three-quarter. Named people take their look and age from
## data/world/cast.json; the rest (and any missing entry) use the canon
## descriptions in docs/world.
## Needs a renderer (not --headless); see docs/ART.md:
##   godot --path . --script res://art/tools/m1_cast_sheet.gd -- [--out=file.png]

const SPACING := 0.98   # between the four views of one person
const GROUP := 4.5      # between people
const ROW := 2.75     # rows stand on shelves, one above the other
const P := PeopleArt.Pose

var _out := "/mnt/project-files/world-assets/characters/m1-cast.png"
var _frames := 0
var _world: Node3D


static func look(outfit: String, c0: String, c1: String, hair: String, hc: String, acc := "none",
		build := "average", skin := 1, extra := {}) -> Dictionary:
	var l := {"outfit": outfit, "colors": [c0, c1], "hair": hair, "hair_color": hc, "accessory": acc,
		"build": build, "skin": skin}
	l.merge(extra, true)
	return l


var _people := {}


## [look, age] for a cast id from data/world/cast.json, or the fallback.
func _from_cast(id: String, fallback: Dictionary, age: int) -> Array:
	if _people.is_empty() and FileAccess.file_exists("res://data/world/cast.json"):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/cast.json"))
		# {"cast": [...]} or {id: person}
		var list: Array = []
		if d is Dictionary:
			for key in d:
				if d[key] is Array:
					list.append_array(d[key])
				elif d[key] is Dictionary:
					list.append(d[key])
		for p in list:
			if p is Dictionary and p.has("look") and p.has("id"):
				_people[str(p.id)] = p
	if _people.has(id):
		return [_people[id].look, int(_people[id].get("age", age))]
	return [fallback, age]


## [name, note, look, age]
func _cast() -> Array:
	var helene := _from_cast("helene_arsenault", look("parka", "1d1d22", "d0202a", "bun", "b5b5b5", "scarf", "slim", 0), 67)
	var dale := _from_cast("dale_huffman", look("team_jacket", "1d3557", "d9a62e", "bald", "5a3b24", "clipboard", "big", 1), 54)
	var earl := _from_cast("earl_bratt", look("coveralls", "1d3557", "c8642a", "short", "8a8a8a", "toque", "stocky", 1), 66)
	return [
		[
			["The owner (A)", "chore coat, jeans", look("work_jacket", "c9a66b", "5b3a22", "short", "5a3b24", "none", "average", 1), 34],
			["The owner (B)", "", look("work_jacket", "59613a", "6b4423", "curly", "1a1714", "none", "stocky", 3, {"height": 1.04}), 31],
			["The owner (C)", "", look("work_jacket", "1d3557", "c8642a", "ponytail", "8a3b1f", "toque", "slim", 0, {"height": 0.94}), 29],
			["Hélène Arsenault", "figure club coach", helene[0], helene[1]],
		],
		[
			["Dale Huffman", "VBL commissioner", dale[0], dale[1]],
			["Earl Bratt", "head icemaker since 1983", earl[0], earl[1]],
		],
		[
			["Public skater: kid", "", look("parka", "d0202a", "e8c547", "short", "d4b06a", "helmet", "slim", 0, {"skates": true, "accent": "1d3557"}), 7],
			["Public skater: teen", "", look("hoodie", "5c3d7a", "eeeeea", "long", "1a1714", "none", "slim", 2, {"skates": true}), 15],
			["Public skater: parent", "", look("parka", "2a9d8f", "eeeeea", "short", "7a4a2a", "toque", "average", 1, {"skates": true}), 41],
			["Public skater: retiree", "", look("cardigan", "8a2f2f", "e3d9bf", "bald", "e8e6e0", "scarf", "big", 2, {"skates": true}), 73],
		],
		[
			["Beer leaguer", "Flood Crew sweater", look("hockey_gear", "3c8d4e", "f2f2e9", "short", "3a2a1e", "helmet", "big", 1, {"accent": "1d1d22"}), 47],
			["Beer leaguer", "", look("hockey_gear", "c8191e", "1d1d22", "mullet", "8f6a44", "stick", "average", 0, {"accent": "1f4f9a"}), 29],
			["Beer leaguer", "", look("hockey_gear", "d9a62e", "6b1f2a", "bald", "3a2a1e", "none", "stocky", 3, {"accent": "5b3a22"}), 52],
			["Beer leaguer", "", look("goalie_gear", "eeeeea", "1f4f9a", "short", "1a1714", "none", "average", 2, {"accent": "c8191e"}), 36],
		],
	]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	var rows := _cast()
	var span := GROUP * 3 + SPACING * 3
	var view_w := span + 1.4
	var view_h := ROW * rows.size() + 1.0
	DisplayServer.window_set_size(Vector2i(2600, int(2600.0 * view_h / view_w)))
	_world = Node3D.new()
	root.add_child(_world)
	_environment(_world, true)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("3a3b42")
	for ri in rows.size():
		var shelf := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(span + 1.2, 0.08, 1.4)
		fm.material = mat
		shelf.mesh = fm
		shelf.position = Vector3(span * 0.5, -ri * ROW - 0.04, 0.1)
		_world.add_child(shelf)
	var centre := Vector3(span * 0.5, -ROW * (rows.size() - 1) * 0.5, 0)
	for ri in rows.size():
		for ci in rows[ri].size():
			var c: Array = rows[ri][ci]
			_character(c[0], c[1], c[2], c[3], Vector3(ci * GROUP, -ri * ROW, 0))
	# the two who appear as pictures
	var gus := _from_cast("gus_tremblay", look("casual", "2a9d8f", "eeeeea", "bald", "e8e6e0", "reading_glasses", "big", 1), 74)
	var earl := _from_cast("earl_bratt", {}, 66)
	_portrait("Gus Tremblay", "retired to Florida; a photo on the office wall", gus[0], gus[1],
		Vector3(2 * GROUP + 0.15, -ROW, 0), true)
	_portrait("Earl Bratt", "portrait", earl[0], earl[1], Vector3(3 * GROUP + 0.15, -ROW, 0), false)
	_label("RinkGM  M1 cast  (stand / walk, front / three-quarter)", Vector3(-0.3, 2.25, 0), 60, HORIZONTAL_ALIGNMENT_LEFT)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = view_w
	cam.rotation_degrees = Vector3(-7, 0, 0)
	cam.position = centre + Vector3(0, 0.75, 0) + cam.basis.z * 40.0
	_world.add_child(cam)
	cam.current = true


## Four views of one person: stand front, stand 3/4, walk front, walk 3/4.
func _character(name: String, note: String, l: Dictionary, age: int, at: Vector3) -> void:
	var views := [[P.STAND, PI], [P.STAND, PI - 0.65], [P.WALK, PI], [P.WALK, PI - 0.65]]
	for i in views.size():
		var pose: int = views[i][0]
		var phase := 0.3 if pose == P.WALK else 0.0
		_person(_world, l, age, pose, phase, at + Vector3(i * SPACING, 0, 0), views[i][1])
	var mid := at + Vector3(SPACING * 1.5, -0.2, 0.7)
	_label(name, mid, 46)
	if note != "":
		_label(note, mid + Vector3(0, -0.2, 0.0), 30, HORIZONTAL_ALIGNMENT_CENTER, Color("b9c0c6"))


func _person(parent: Node, l: Dictionary, age: int, pose: int, phase: float, at: Vector3, yaw: float) -> void:
	var mmi := MultiMeshInstance3D.new()
	var mm := PeopleArt.multimesh(PeopleArt.shape_key(l, age), 1)
	mm.set_instance_transform(0, Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO))
	mm.set_instance_custom_data(0, PeopleArt.instance_data(l, pose, phase, age))
	mmi.multimesh = mm
	mmi.position = at
	parent.add_child(mmi)


## A head-and-shoulders picture in a frame, rendered live from its own little
## world. `photo` gives the warm, faded look of an old print.
func _portrait(name: String, note: String, l: Dictionary, age: int, at: Vector3, photo: bool) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 640)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var w := Node3D.new()
	vp.add_child(w)
	_environment(w, false, Color("cfe3ea") if photo else Color("6d7b8c"))
	_person(w, l, age, P.STAND, 0.0, Vector3.ZERO, PI - 0.3)
	var cam := Camera3D.new()
	cam.fov = 30
	var eye := PeopleArt.eye_height(l, age)
	cam.position = Vector3(0, eye + 0.3, 2.6)
	cam.rotation_degrees = Vector3(-10, 0, 0)
	w.add_child(cam)
	cam.current = true
	# frame and picture, leaning back a touch toward the camera
	var holder := Node3D.new()
	holder.position = at + Vector3(1.2, 0.2, 0)
	holder.rotation_degrees = Vector3(-4, 0, 0)
	_world.add_child(holder)
	var frame := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(1.36, 1.66, 0.06)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color("9a6b3f") if photo else Color("2b2d33")
	fb.material = fmat
	frame.mesh = fb
	frame.position = Vector3(0, 0.83, -0.035)
	holder.add_child(frame)
	var pic := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 1.5)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_texture = vp.get_texture()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if photo:
		pmat.albedo_color = Color(1.0, 0.88, 0.7)
	q.material = pmat
	pic.mesh = q
	pic.position = Vector3(0, 0.83, 0.0)
	holder.add_child(pic)
	if photo:
		var tag := Label3D.new()
		tag.text = "GUS, CLEARWATER FLA."
		tag.font_size = 30
		tag.pixel_size = 0.004
		tag.modulate = Color("3a2a1e")
		tag.outline_size = 0
		tag.position = Vector3(0, 0.17, 0.01)
		holder.add_child(tag)
	var mid := at + Vector3(1.2, -0.2, 0.7)
	_label(name, mid, 46)
	_label(note, mid + Vector3(0, -0.2, 0), 30, HORIZONTAL_ALIGNMENT_CENTER, Color("b9c0c6"))


func _label(text: String, pos: Vector3, size: int, align := HORIZONTAL_ALIGNMENT_CENTER, col := Color.WHITE) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.0042
	label.outline_size = 10
	label.modulate = col
	label.horizontal_alignment = align
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = pos
	_world.add_child(label)


func _environment(parent: Node, shadows: bool, bg := Color("24252b")) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.89, 0.96)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = shadows
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	sun.shadow_enabled = shadows
	parent.add_child(sun)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 14:
		root.get_texture().get_image().save_png(_out)
		print("m1 cast sheet saved to ", _out)
		return true
	return false
