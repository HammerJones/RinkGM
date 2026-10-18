extends SceneTree
## Renders the PeopleArt review sheets: every age band and build, outfits,
## hair and accessories standing; a seated row on real arena seats; skaters;
## and every pose. Each person is a MultiMesh of one, the way singles are
## drawn in game. Needs a renderer (not --headless); see docs/ART.md:
##   godot --path . --script res://art/tools/people_sheet.gd -- [--out=dir] [--sheet=people|poses]

const CELL := 1.25
const ROW := 4.6

var _out := "/mnt/project-files/world-assets/people"
var _sheet := "people"
var _frames := 0
var _world: Node3D


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--sheet="):
			_sheet = arg.trim_prefix("--sheet=")
	DirAccess.make_dir_recursive_absolute(_out)
	var rows: Array = _poses_rows() if _sheet == "poses" else _people_rows()
	_layout(rows)


static func look(outfit: String, c0: String, c1: String, hair := "short", hc := "3a2a1e", acc := "none",
		build := "average", skin := 1, extra := {}) -> Dictionary:
	var l := {"outfit": outfit, "colors": [c0, c1], "hair": hair, "hair_color": hc, "accessory": acc,
		"build": build, "skin": skin}
	l.merge(extra, true)
	return l


## [title, [[look, age, pose, phase, label, seated], ...]] per row.
func _people_rows() -> Array:
	const P := PeopleArt.Pose
	var bands := [
		[look("parka", "d6407f", "eeeeea", "curly", "5a3b24", "none", "average", 0), 3, "toddler 3"],
		[look("hoodie", "2a9d8f", "d9d4c7", "short", "d4b06a", "none", "slim", 0), 6, "child 6"],
		[look("school_jacket", "1f4f9a", "eeeeea", "ponytail", "1a1714", "none", "stocky", 3), 10, "child 10"],
		[look("hoodie", "39424e", "d0202a", "mullet", "8f6a44", "none", "slim", 1), 13, "teen slim"],
		[look("casual", "7a2335", "e3d9bf", "long", "b8622d", "none", "average", 0), 15, "teen avg"],
		[look("team_jacket", "3c8d4e", "f2f2e9", "buzz", "2b2220", "none", "big", 2), 17, "teen stocky"],
		[look("casual", "2f5e8a", "d9d4c7", "short", "3a2a1e", "none", "slim", 1), 30, "adult slim"],
		[look("cardigan", "8a2f2f", "d9d4c7", "bun", "7a4a2a", "none", "average", 2), 40, "adult avg"],
		[look("parka", "3e6b3a", "c9c2b0", "bald", "3a2a1e", "none", "stocky", 3), 50, "adult stocky"],
		[look("hoodie", "1d1d22", "d6a321", "short", "1a1714", "ball_cap", "big", 1), 45, "adult big"],
		[look("cardigan", "a58fcf", "eeeeea", "bun", "b5b5b5", "reading_glasses", "average", 0), 78, "elder 78"],
	]
	var outfits_a := []
	var cs := [["c8191e", "ece7dc"], ["1d3557", "eeeeea"], ["2e8b57", "e8c547"], ["d9a62e", "1d1d22"], ["5c3d7a", "a9d3e0"],
		["8a2f2f", "e3d9bf"], ["2a9d8f", "eeeeea"], ["c8642a", "1d1d22"], ["3a86c8", "d9d4c7"]]
	var hairs := ["short", "long", "bun", "bald", "ponytail", "curly", "buzz", "mullet", "toque_hair"]
	var hcs := ["3a2a1e", "d4b06a", "8a8a8a", "5a3b24", "b8622d", "1a1714", "7a4a2a", "a8864f", "1a1714"]
	for i in 9:
		var o: String = PeopleArt.OUTFITS[i]
		outfits_a.append([look(o, cs[i][0], cs[i][1], hairs[i], hcs[i], "none", PeopleArt.BUILDS[i % 4], i % 4), 32, o])
	var outfits_b := []
	for i in range(9, PeopleArt.OUTFITS.size()):
		var o: String = PeopleArt.OUTFITS[i]
		var j := i - 9
		outfits_b.append([look(o, cs[j][0], cs[j][1], hairs[(j + 3) % 9], hcs[(j + 4) % 9], "none", PeopleArt.BUILDS[j % 4], (j + 1) % 4), 38, o])
	var accs_a := []
	var accs_b := []
	var acc_list: Array = PeopleArt.ACCESSORIES.slice(1)
	for i in acc_list.size():
		var a: String = acc_list[i]
		var o: String = ["casual", "parka", "team_jacket", "hoodie", "cardigan"][i % 5]
		var row := [look(o, cs[i % 9][0], cs[i % 9][1], hairs[i % 8], hcs[i % 9], a, "average", i % 4), 35, a]
		(accs_a if i < 10 else accs_b).append(row)
	var seated := []
	var seat_looks := [
		[look("parka", "1d3557", "d0202a", "short", "3a2a1e", "toque"), 40],
		[look("team_jacket", "c8191e", "ece7dc", "long", "d4b06a", "foam_finger", "slim", 0), 28],
		[look("cardigan", "8fbfa8", "d9d4c7", "bun", "e8e6e0", "blanket", "stocky", 1), 82],
		[look("hoodie", "d6a321", "1d1d22", "curly", "1a1714", "none", "slim", 3), 7],
		[look("parka", "d6407f", "eeeeea", "short", "d4b06a"), 3],
		[look("casual", "39424e", "c8191e", "buzz", "2b2220", "coffee", "big", 2), 50],
		[look("school_jacket", "3c8d4e", "eeeeea", "ponytail", "7a4a2a", "programme", "average", 1), 14],
		[look("coach_tracksuit", "15203f", "eeeeea", "short", "8a8a8a", "clipboard", "big", 0, {"height": 1.12}), 55],
		[look("parka", "5c3d7a", "eeeeea", "long", "b8622d", "knitting", "average", 0, {"height": 0.86}), 60],
	]
	for i in seat_looks.size():
		var pose: int = [P.SIT, P.SIT_CHEER, P.SIT, P.SIT, P.SIT, P.SIT_CLAP, P.SIT, P.SIT, P.SIT][i]
		seated.append([seat_looks[i][0], seat_looks[i][1], pose, 0.1 * i, "%s %d" % [PeopleArt.Pose.keys()[pose].to_lower(), seat_looks[i][1]], true])
	var skaters := [
		[look("hockey_gear", "c8191e", "ece7dc", "short", "3a2a1e", "helmet", "average", 1, {"accent": "1c2033"}), 24, P.SKATE, 0.0, "hockey"],
		[look("hockey_gear", "1f4f9a", "d6a321", "long", "d4b06a", "stick", "slim", 0), 11, P.SKATE, 0.4, "minor + stick"],
		[look("goalie_gear", "1f4f9a", "d6a321", "short", "3a2a1e", "none", "stocky"), 27, P.STAND, 0.0, "goalie"],
		[look("figure_dress", "5c3d7a", "a9d3e0", "bun", "1a1714", "none", "slim", 0), 12, P.SPIN, 0.0, "figure spin"],
		[look("figure_warmup", "2a9d8f", "eeeeea", "ponytail", "b8622d", "none", "slim", 1), 16, P.SKATE, 0.7, "figure warmup"],
		[look("ref_stripes", "1d1d22", "eeeeea", "short", "3a2a1e", "whistle", "average", 2), 41, P.SKATE, 0.25, "ref"],
		[look("parka", "d0202a", "eeeeea", "long", "5a3b24", "scarf", "average", 3, {"skates": true}), 34, P.SKATE, 0.55, "public skate"],
		[look("casual", "3a86c8", "e8c547", "short", "d4b06a", "helmet", "average", 0, {"skates": true, "accent": "d0202a"}), 6, P.SKATE_WOBBLY, 0.0, "learn to skate"],
		[look("cardigan", "7d8a3a", "e3d9bf", "bald", "8a8a8a", "toque", "big", 1, {"skates": true}), 72, P.SKATE_WOBBLY, 0.5, "adult beginner"],
		[look("hoodie", "8a2f2f", "eeeeea", "curly", "1a1714", "none", "average", 3, {"skates": true}), 19, P.FALL, 0.0, "fall"],
	]
	return [
		["age bands and builds", _entries(bands, P.STAND)],
		["outfits", _entries(outfits_a, P.STAND)],
		["", _entries(outfits_b, P.STAND)],
		["accessories", _entries(accs_a, P.STAND)],
		["", _entries(accs_b, P.STAND)],
		["seated on arena_seat (worn)", seated],
		["skaters", skaters],
	]


func _entries(list: Array, pose: int) -> Array:
	var out := []
	for e in list:
		out.append([e[0], e[1], pose, 0.0, e[2]])
	return out


func _poses_rows() -> Array:
	var adult := look("team_jacket", "d0202a", "eeeeea", "short", "3a2a1e", "none", "average", 1)
	var kid := look("parka", "2a9d8f", "e8c547", "ponytail", "b8622d", "none", "slim", 0)
	var staff := look("canteen_apron", "2f5e8a", "eeeeea", "bun", "5a3b24", "none", "stocky", 2)
	var skater := look("figure_warmup", "5c3d7a", "a9d3e0", "bun", "1a1714", "none", "slim", 0)
	var rows := []
	for who in [[adult, 35, "adult"], [kid, 8, "child 8"]]:
		var r := []
		for name in PeopleArt.Pose.keys():
			var pose: int = PeopleArt.Pose[name]
			var l: Dictionary = who[0]
			if pose == PeopleArt.Pose.CARRY or pose == PeopleArt.Pose.WORK:
				l = staff if who[2] == "adult" else l
			if pose in [PeopleArt.Pose.SKATE, PeopleArt.Pose.SKATE_WOBBLY, PeopleArt.Pose.SPIN, PeopleArt.Pose.FALL]:
				l = skater.duplicate() if who[2] == "adult" else l.duplicate()
				l.skates = true
			var seated := pose in [PeopleArt.Pose.SIT, PeopleArt.Pose.SIT_CLAP, PeopleArt.Pose.SIT_CHEER]
			r.append([l, who[1], pose, 0.15, name.to_lower(), seated])
		rows.append(["every pose: %s" % who[2], r])
	# a walk cycle and a skate stride, eight phases each
	for cyc in [[PeopleArt.Pose.WALK, adult, "walk cycle"], [PeopleArt.Pose.SKATE, skater, "skate stride"]]:
		var r := []
		for i in 8:
			var l: Dictionary = cyc[1].duplicate()
			if cyc[0] == PeopleArt.Pose.SKATE:
				l.skates = true
			r.append([l, 30, cyc[0], i / 8.0, "phase %d/8" % i])
		rows.append([cyc[2], r])
	return rows


func _layout(rows: Array) -> void:
	var cols := 0
	for r in rows:
		cols = maxi(cols, r[1].size())
	var view_w := CELL * cols + 4.2  # room on the left for the row titles
	var view_h := ROW * rows.size() * 0.47 + 1.2
	DisplayServer.window_set_size(Vector2i(2400, int(2400.0 * view_h / view_w)))
	_world = Node3D.new()
	root.add_child(_world)
	_environment()
	var fl := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(CELL * cols + 6, 0.1, ROW * rows.size() + 6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("3a3b42")
	fm.material = mat
	fl.mesh = fm
	var centre := Vector3(CELL * (cols - 1) * 0.5, 0, ROW * (rows.size() - 1) * 0.5)
	fl.position = centre - Vector3(0, 0.05, 0)
	_world.add_child(fl)
	for ri in rows.size():
		var z := ri * ROW
		if rows[ri][0] != "":
			_label(rows[ri][0], Vector3(-0.75, 0.0, z + 0.55), 34, HORIZONTAL_ALIGNMENT_RIGHT)
		var ents: Array = rows[ri][1]
		for ci in ents.size():
			var e: Array = ents[ci]
			var at := Vector3(ci * CELL, 0, z)
			var seated: bool = e.size() > 5 and e[5]
			_person(e[0], e[1], e[2], e[3], at, seated)
			_label(e[4], at + Vector3(0, 0.0, 0.55), 30)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = view_w
	cam.rotation_degrees = Vector3(-28, 0, 0)
	cam.position = centre + Vector3(-1.3, 1.0, 0) + cam.basis.z * 40.0
	_world.add_child(cam)
	cam.current = true


## One person as a MultiMesh of one, the way singles are drawn in game; seated
## people get a worn arena seat with the pivot from seat_offset().
func _person(l: Dictionary, age: int, pose: int, phase: float, at: Vector3, seated: bool) -> void:
	var yaw := PI - 0.5  # three-quarters to the camera
	var basis := Basis(Vector3.UP, yaw)
	var feet := at
	if seated:
		var seat := MeshInstance3D.new()
		seat.mesh = Props.mesh("arena_seat", Wear.WORN)
		seat.position = at
		seat.rotation.y = yaw
		_world.add_child(seat)
		# the seat point is the top centre of the seat pan
		var seat_point := at + Vector3(0, PeopleArt.SEAT_H, 0)
		feet = seat_point + basis * PeopleArt.seat_offset(l, age)
	var mmi := MultiMeshInstance3D.new()
	var mm := PeopleArt.multimesh(PeopleArt.shape_key(l, age), 1)
	mm.set_instance_transform(0, Transform3D(basis, Vector3.ZERO))
	mm.set_instance_custom_data(0, PeopleArt.instance_data(l, pose, phase, age))
	mmi.multimesh = mm
	mmi.position = feet
	_world.add_child(mmi)


func _label(text: String, pos: Vector3, size: int, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.004
	label.outline_size = 10
	label.horizontal_alignment = align
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = pos
	_world.add_child(label)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("24252b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.89, 0.96)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.shadow_enabled = true
	_world.add_child(sun)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 12:
		var path := "%s/%s.png" % [_out, "people-poses" if _sheet == "poses" else "people-sheet"]
		root.get_texture().get_image().save_png(path)
		print("people sheet saved to ", path)
		return true
	return false
