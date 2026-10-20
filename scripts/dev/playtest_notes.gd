extends CanvasLayer
## Playtest notes (N). Pauses the game, grabs a screenshot and a snapshot of
## the simulation, and lets the tester type what they saw. Each note is saved
## to user://playtest_notes/<session>/ as note_NNN.json + note_NNN.png, and a
## readable line is appended to notes.md in the same folder, so a tester can
## zip the folder and hand it to whoever is debugging.
##
## The snapshot includes the last few seconds of the user's skater, the puck
## and the user's inputs (sampled every physics tick, kept HISTORY_SECONDS),
## so "the puck went through my stick" can be replayed from numbers.
##
## Everything is read with get()/has_method() so the overlay works on any
## scene (career hub, match, practice) and on any branch.

const NOTES_ROOT := "user://playtest_notes"
const HISTORY_SECONDS := 6.0
const HISTORY_HZ := 30.0
const MPS_TO_MPH := 2.23694
const CATEGORIES := ["Bug", "Feel", "Visual", "Idea"]

var session_dir := ""
var note_count := 0

var _panel: PanelContainer
var _text: TextEdit
var _category: OptionButton
var _context: Label
var _toast: Label
var _toast_left := 0.0
var _history: Array[Dictionary] = []
var _sample_left := 0.0
var _pending_shot: Image
var _pending_snapshot := {}
var _was_paused := false
var _was_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _input_node: Node
var _input_mode := Node.PROCESS_MODE_INHERIT


func _ready() -> void:
	layer = 110  # above the dev menu and the pause menu
	process_mode = Node.PROCESS_MODE_ALWAYS
	session_dir = "%s/%s" % [NOTES_ROOT, Time.get_datetime_string_from_system().replace(":", "-")]
	_build()
	if "--test=notes" in OS.get_cmdline_user_args():
		_self_test.call_deferred()


func _input(event: InputEvent) -> void:
	if _panel.visible:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			close(false)
		elif event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			get_viewport().set_input_as_handled()
			if event.shift_pressed:
				# TextEdit ignores Shift+Enter, so insert the new line ourselves.
				_text.insert_text_at_caret("\n")
			else:
				close(true)
		return
	var toggle := false
	if InputMap.has_action("playtest_note"):
		toggle = event.is_action_pressed("playtest_note")
	elif event is InputEventKey and event.pressed and not event.echo:
		toggle = event.physical_keycode == KEY_N
	if toggle:
		get_viewport().set_input_as_handled()
		open()


func _physics_process(dt: float) -> void:
	if get_tree().paused:
		return
	_sample_left -= dt
	if _sample_left > 0.0:
		return
	_sample_left = 1.0 / HISTORY_HZ
	var g := _game()
	if g == null:
		return
	_history.append(_frame(g))
	while _history.size() > int(HISTORY_SECONDS * HISTORY_HZ):
		_history.pop_front()


func _process(dt: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= dt
		_toast.visible = _toast_left > 0.0


# --- open / close ---------------------------------------------------------

func is_open() -> bool:
	return _panel.visible


func open() -> void:
	if _panel.visible:
		return
	# The last drawn frame doesn't have the panel in it yet.
	_pending_shot = get_viewport().get_texture().get_image() if DisplayServer.get_name() != "headless" else null
	_pending_snapshot = snapshot()
	_was_paused = get_tree().paused
	get_tree().paused = true
	_release_mouse()
	_context.text = _context_line(_pending_snapshot)
	_text.text = ""
	_panel.visible = true
	_text.grab_focus()


## Saves the note when `keep` and the text isn't empty, then resumes the game.
func close(keep: bool) -> void:
	if not _panel.visible:
		return
	_panel.visible = false
	var body := _text.text.strip_edges()
	if keep and not body.is_empty():
		var n := save_note(body, CATEGORIES[_category.selected], _pending_snapshot, _pending_shot)
		_show_toast("Note %d saved" % n)
	_pending_shot = null
	_pending_snapshot = {}
	get_tree().paused = _was_paused
	_restore_mouse()


## Writes one note and returns its number.
func save_note(body: String, category: String, snap: Dictionary, shot: Image) -> int:
	DirAccess.make_dir_recursive_absolute(session_dir)
	note_count += 1
	var stem := "%s/note_%03d" % [session_dir, note_count]
	var record := {"note": note_count, "category": category, "text": body, "snapshot": snap}
	if shot != null:
		shot.save_png(stem + ".png")
		record["screenshot"] = stem.get_file() + ".png"
	var f := FileAccess.open(stem + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(record, "\t"))
	f.close()
	var md_path := session_dir + "/notes.md"
	var md := FileAccess.open(md_path, FileAccess.READ_WRITE if FileAccess.file_exists(md_path) else FileAccess.WRITE)
	md.seek_end()
	md.store_string("- **#%d %s** (%s): %s\n" % [note_count, category, _context_line(snap), body.replace("\n", " / ")])
	md.close()
	return note_count


func open_folder() -> void:
	DirAccess.make_dir_recursive_absolute(session_dir)
	OS.shell_open(ProjectSettings.globalize_path(session_dir))


# --- what gets recorded ---------------------------------------------------

## Everything a debugger would want to know about the moment of the note.
func snapshot() -> Dictionary:
	var s := {
		"time": Time.get_datetime_string_from_system(),
		"build": _build_id(),
		"scene": get_tree().current_scene.scene_file_path if get_tree().current_scene != null else "",
		"fps": Engine.get_frames_per_second(),
		"window": str(DisplayServer.window_get_size()) if DisplayServer.get_name() != "headless" else "headless",
	}
	var tuning := get_node_or_null("/root/Tuning")
	if tuning != null:
		s["physics_blend"] = tuning.get("blend")
	var cs := get_node_or_null("/root/CareerState")
	var c: Object = cs.get("career") if cs != null else null
	if c != null:
		s["career"] = {"slot": cs.get("slot"), "season": c.get("season_number"), "tier": c.get("tier"), "day": c.get("day")}
	var g := _game()
	if g != null:
		s["match"] = {
			"mode": "practice" if g.get("practice") else ("career" if g.get("career_mode") else "exhibition"),
			"period": g.get("period"), "clock": snappedf(g.get("clock"), 0.1), "score": g.get("score"),
			"state": g.get("state"), "overtime": g.get("overtime"),
			"camera": g.get("camera_rig").get("mode") if g.get("camera_rig") != null else null,
		}
		var me: Object = g.call("user_skater") if g.has_method("user_skater") else g.get("human")
		if me != null:
			s["you"] = _skater(me, true)
		var puck: Object = g.get("puck")
		if puck != null:
			s["puck"] = _puck(puck)
		var others := []
		for sk in g.get("skaters"):
			if sk != me:
				others.append(_skater(sk, false))
		s["others"] = others
		s["history"] = _history.duplicate()
	return s


func _frame(g: Node) -> Dictionary:
	var f := {"t": g.get("time")}
	var me: Object = g.call("user_skater") if g.has_method("user_skater") else g.get("human")
	if me != null:
		f["you"] = {"pos": _v(me.get("global_position")), "vel": _v(me.get("vel")), "blade": _v(me.get("blade_pos"))}
		var ctrl: Object = me.get("ctrl")
		if ctrl != null:
			f["in"] = {"move": _v(ctrl.get("move")), "stick": _v(ctrl.get("stick")), "shoot": ctrl.get("shoot"),
				"dash": ctrl.get("dash"), "stop": ctrl.get("stop"), "lift": ctrl.get("lift"), "tilt": ctrl.get("tilt"),
				"move_id": str(ctrl.get("move_id"))}
	var puck: Object = g.get("puck")
	if puck != null:
		f["puck"] = {"pos": _v(puck.get("global_position")), "vel": _v(puck.get("vel")), "owner": _who(puck.get("controller"))}
	return f


func _skater(sk: Object, full: bool) -> Dictionary:
	var vel: Vector3 = sk.get("vel") if sk.get("vel") != null else Vector3.ZERO
	var d := {"who": _who(sk), "team": sk.get("team"), "pos": _v(sk.get("global_position")),
		"vel": _v(vel), "mph": snappedf(Vector2(vel.x, vel.z).length() * MPS_TO_MPH, 0.1)}
	if full:
		d["heading"] = _v(sk.get("heading"))
		d["blade"] = _v(sk.get("blade_pos"))
		d["stamina"] = sk.get("stamina")
		d["move"] = str(sk.get("move_id"))
		d["stick_health"] = sk.get("stick_health")
		var skills: Object = sk.get("skills")
		if skills != null and skills.get("values") != null:
			var ratings := {}
			for k in skills.get("values"):
				ratings[k] = snappedf(skills.get("values")[k], 0.1)
			d["skills"] = ratings
	return d


func _puck(p: Object) -> Dictionary:
	var vel: Vector3 = p.get("vel") if p.get("vel") != null else Vector3.ZERO
	return {"pos": _v(p.get("global_position")), "vel": _v(vel), "mph": snappedf(vel.length() * MPS_TO_MPH, 0.1),
		"owner": _who(p.get("controller")), "last_touch": _who(p.get("last_touch")), "frozen": p.get("frozen")}


func _context_line(s: Dictionary) -> String:
	var parts: Array[String] = []
	var m: Dictionary = s.get("match", {})
	if not m.is_empty():
		if m.mode == "practice":
			parts.append("practice")
		else:
			parts.append("P%s %d:%02d  %s-%s" % [m.period, int(m.clock) / 60, int(m.clock) % 60, m.score[0], m.score[1]])
	var you: Dictionary = s.get("you", {})
	if not you.is_empty():
		parts.append("you %s mph" % you.mph)
	var c: Dictionary = s.get("career", {})
	if not c.is_empty():
		parts.append("%s s%s day %s" % [c.slot, c.season, c.day])
	parts.append(str(s.get("scene", "")).get_file())
	return "  ".join(parts)


func _build_id() -> String:
	var path := "res://build_info.txt"  # written by the export step when present
	return FileAccess.get_file_as_string(path).strip_edges() if FileAccess.file_exists(path) else "dev"


func _who(sk: Object) -> String:
	if sk == null:
		return ""
	return "T%s#%s" % [sk.get("team"), sk.get("number")]


func _v(v: Variant) -> Array:
	if v is Vector3:
		return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]
	if v is Vector2:
		return [snappedf(v.x, 0.01), snappedf(v.y, 0.01)]
	return []


func _game() -> Node:
	var s := get_tree().current_scene
	return s if s != null and "score" in s and "clock" in s else null


# --- mouse ----------------------------------------------------------------

## A match captures the mouse for the virtual stick; free it while typing.
func _release_mouse() -> void:
	_was_mouse_mode = Input.mouse_mode
	var g := _game()
	var ctl: Object = g.get("controller") if g != null else null
	_input_node = ctl.get("player_input") as Node if ctl != null else null
	if _input_node != null:
		_input_mode = _input_node.process_mode
		_input_node.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _restore_mouse() -> void:
	if is_instance_valid(_input_node):
		_input_node.process_mode = _input_mode
		if _was_mouse_mode == Input.MOUSE_MODE_CAPTURED and _input_node.has_method("capture_mouse"):
			_input_node.call("capture_mouse")
			_input_node = null
			return
	_input_node = null
	Input.mouse_mode = _was_mouse_mode


# --- UI -------------------------------------------------------------------

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"HudPanel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.custom_minimum_size = Vector2(720, 0)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.position.y -= 40
	if str(ProjectSettings.get_setting("gui/theme/custom", "")).is_empty():
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.06, 0.08, 1.0)
		sb.set_content_margin_all(12)
		_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)

	var title := Label.new()
	title.text = "// PLAYTEST NOTE"
	title.theme_type_variation = &"PixelLabel"
	box.add_child(title)
	_context = Label.new()
	_context.theme_type_variation = &"TermDimLabel"
	box.add_child(_context)

	var row := HBoxContainer.new()
	box.add_child(row)
	_category = OptionButton.new()
	for c in CATEGORIES:
		_category.add_item(c)
	_category.focus_mode = Control.FOCUS_NONE
	row.add_child(_category)
	var hint := Label.new()
	hint.text = "Enter saves   Shift+Enter new line   Esc cancels"
	hint.theme_type_variation = &"TermDimLabel"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hint)

	_text = TextEdit.new()
	_text.custom_minimum_size = Vector2(0, 120)
	_text.placeholder_text = "What happened? What did you expect?"
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(_text)

	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var folder := Button.new()
	folder.text = "Open notes folder"
	folder.theme_type_variation = &"GhostButton"
	folder.focus_mode = Control.FOCUS_NONE
	folder.pressed.connect(open_folder)
	buttons.add_child(folder)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.theme_type_variation = &"GhostButton"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(close.bind(false))
	buttons.add_child(cancel)
	var save := Button.new()
	save.text = "Save note"
	save.focus_mode = Control.FOCUS_NONE
	save.pressed.connect(close.bind(true))
	buttons.add_child(save)
	_panel.visible = false

	_toast = Label.new()
	_toast.theme_type_variation = &"TermLabel"
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toast.position += Vector2(-24, 16)
	_toast.visible = false
	add_child(_toast)


func _show_toast(msg: String) -> void:
	_toast.text = "// " + msg + "  (N for another)"
	_toast_left = 2.5
	_toast.visible = true


# --- headless check (`-- --test=notes`, listed in tools/tests/game_tests.txt) ---

func _self_test() -> void:
	await get_tree().create_timer(2.0).timeout  # let the match run so history fills
	var fails: Array[String] = []
	session_dir = "user://playtest_notes/_selftest"
	open()
	if not get_tree().paused:
		fails.append("game not paused while the note is open")
	_text.text = "puck went through my stick"
	_category.selected = 1
	close(true)
	if get_tree().paused:
		fails.append("game still paused after saving")
	var path := session_dir + "/note_%03d.json" % note_count
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not data is Dictionary:
		fails.append("note file missing or unreadable: " + path)
	else:
		if data.text != "puck went through my stick" or data.category != "Feel":
			fails.append("note text or category not saved")
		var snap: Dictionary = data.snapshot
		if _game() != null:
			for key in ["match", "you", "puck", "history"]:
				if not snap.has(key):
					fails.append("snapshot missing " + key)
			if snap.get("history", []).size() < 10:
				fails.append("history too short: %d frames" % snap.get("history", []).size())
	if not FileAccess.file_exists(session_dir + "/notes.md"):
		fails.append("notes.md not written")
	open()
	close(true)  # empty text: nothing saved
	if FileAccess.file_exists(session_dir + "/note_%03d.json" % (note_count + 1)):
		fails.append("an empty note was saved")
	for f in fails:
		print("  FAIL: ", f)
	print("notes test: ", "all passed" if fails.is_empty() else "FAILED %d" % fails.size())
	for file in DirAccess.get_files_at(session_dir):
		DirAccess.remove_absolute(session_dir + "/" + file)
	get_tree().quit(0 if fails.is_empty() else 1)
