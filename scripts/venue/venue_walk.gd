extends Node3D
## Walking the building on foot. By default this is the first hour at
## Millbrook (RINK_SIM.md 1.6, WalkStory): 05:00 Monday in the dark parking
## lot, keys under the mat, the ice lights on a panel inside the doors, Gus's
## notes, the office and the jobs in the plant room and the bay. `--free-walk`
## is the old playtest instead: lights on, start in the lobby, nothing locked.
## Inside an owner career (CareerState.rink) the walk runs on the career's
## sim and clock: the first hour only on its first morning, else from the
## office. The office desk goes back to the rink office, and the owner's game
## sends the player back to the hub.
##
##   godot --path . res://scenes/venue/venue_walk.tscn [-- --tier=3 --free-walk]
##   (or `-- --venue-walk` on the normal game)
##
## WASD / left stick walk, mouse / right stick look, Shift / L3 run,
## Space jump, Ctrl or C (held) crouch,
## E / A read, use or work on what you're looking at (or a door); A jumps
## when there's nothing in reach, B (held) crouches when no panel is open,
## O the office (in an owner career),
## Q / LB raise the watch, Tab / Back the bag (R turns what's in hand),
## Esc / B close a panel, 1 2 3 / D-pad set this room's age,
## F / Y fly. On the ice in shoes the mouse or right stick keeps the
## owner's balance (KitHud).

## UI's office screens and anything else listening: the player asked for
## screen `id` (log_book, phone, goals, ice_grid, desk) with the sim.
signal screen_requested(id: String, sim: RinkSim)

## A job spot was used: `job` is WalkStory's job dictionary.
signal job_started(job: Dictionary)

const OFFICE_SCENE := "res://scenes/ui/rink_office.tscn"
## Screen spot -> UI rink office tab.
const OFFICE_TABS := {"ice_grid": "grid", "log_book": "log", "goals": "board", "desk": "jobs"}
const JOBS_DIR := "res://scenes/world/jobs/"

var venue: Venue
var walker: VenueWalker
var cam: Camera3D
var story: WalkStory
var flying := false
var _yaw := -PI * 0.5  # facing +X, toward the front doors and the ice
var _pitch := 0.0
var _label: Label
var _toast: Label
var _toast_t := 0.0
var _panel: PanelContainer
var _panel_text: RichTextLabel
var _panel_job := {}
var _job_scene: Node
var _office: CanvasLayer
var _leaving := false
var _sun: DirectionalLight3D
var _env: Environment
var kit: KitHud
var pickup_run: PickupRun  # World: the gym's pickup games, null without a gym


func _ready() -> void:
	var tier := 0
	var free := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tier="):
			tier = a.trim_prefix("--tier=").to_int()
		elif a == "--free-walk":
			free = true
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-58.0, -32.0, 0.0)
	_sun.shadow_enabled = true
	add_child(_sun)
	var rink := Rink.new()
	add_child(rink)
	venue = Venue.instantiate_for(Career.exhibition(clampi(tier, 0, LeagueTiers.count() - 1)), true)
	add_child(venue)
	venue.apply_lighting(_env, _sun)
	walker = VenueWalker.new()
	add_child(walker)
	if free:
		walker.global_position = venue.rooms["lobby"].spawn
	else:
		story = WalkStory.start(venue)
		IceView.attach(rink, story.sim.ice)  # World: the sim's ice, cell by cell, on the sheet
		var m := story.sim.minute
		if m < 7 * 60 or m >= 19 * 60:
			_env.background_color = Color("070a12")  # night outside
		if story.first_hour():
			walker.global_position = Vector3(-51.0, 0.05, 0.4)
		else:
			# in the office, by the door, facing the desk
			walker.global_position = Vector3(-42.4, venue.rooms["office"].spawn.y + 0.05, -7.0)
			_yaw = 0.0
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.05
	walker.head.add_child(cam)
	cam.current = true
	_build_ui()
	kit = KitHud.new()
	add_child(kit)
	kit.toast.connect(_show_toast)
	kit.setup(story, walker, cam, venue)
	pickup_run = PickupRun.attach_to_walk(self)  # World: pickup basketball in the gym (scripts/world/pickup)
	# World: the building's real people (WalkPeople: RinkPeople on this walk's
	# sim, T to talk, Gus's first-day offer) instead of the seated crowd;
	# `--no-people` keeps the old crowd.
	if not "--no-people" in OS.get_cmdline_user_args():
		WalkPeople.attach(self)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_color_override("font_color", RinkOS.READOUT)
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	layer.add_child(_label)
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.position = Vector2(-300, -120)
	_toast.size = Vector2(600, 40)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_color", RinkOS.ACTION)
	_toast.add_theme_color_override("font_shadow_color", Color.BLACK)
	layer.add_child(_toast)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(720, 420)
	_panel.position = Vector2(-360, -210)
	_panel.add_theme_stylebox_override("panel", RinkOS.flat(RinkOS.PANEL, 18.0))
	_panel_text = RichTextLabel.new()
	_panel_text.bbcode_enabled = true
	_panel_text.fit_content = true
	_panel_text.scroll_active = true
	_panel_text.custom_minimum_size = Vector2(684, 384)
	_panel.add_child(_panel_text)
	_panel.visible = false
	layer.add_child(_panel)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _busy():
		# on the ice in shoes the mouse mostly fights for balance
		var look := 0.35 if kit.balancing else 1.0
		if kit.balancing:
			kit.push(e.relative)
		_yaw -= e.relative.x * 0.003 * look
		_pitch = clampf(_pitch - e.relative.y * 0.003 * look, -1.45, 1.45)
	elif e is InputEventMouseButton and e.pressed:
		if not kit.bag_open:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventKey and e.pressed and not e.echo:
		if kit.key(e):
			return
		match e.keycode:
			KEY_TAB:
				if not _busy():
					kit.toggle_bag()
			KEY_ESCAPE: _close_panel()
			KEY_O:
				if story and story.link and not _busy():
					_leave_to("office")
			KEY_E: _use()
			KEY_SPACE:
				if not flying and not _busy():
					walker.jump()
			KEY_Q:
				if _panel.visible or _office:
					_close_panel()
				else:
					kit.toggle_watch()
			KEY_F: _toggle_fly()
			KEY_1: _age_here(VenueRoom.Age.WORN)
			KEY_2: _age_here(VenueRoom.Age.REPAIRED)
			KEY_3: _age_here(VenueRoom.Age.RENOVATED)
	elif e is InputEventJoypadButton and e.pressed:
		match e.button_index:
			JOY_BUTTON_A:
				if _busy() or _looked_at() or walker.nearest_door(venue):
					_use()
				elif not flying:
					walker.jump()
			JOY_BUTTON_B:
				if kit.bag_open:
					kit.toggle_bag()
				else:
					_close_panel()
			JOY_BUTTON_LEFT_SHOULDER: kit.toggle_watch()
			JOY_BUTTON_BACK:
				if kit.bag_open or not _busy():
					kit.toggle_bag()
			JOY_BUTTON_Y: _toggle_fly()
			JOY_BUTTON_DPAD_LEFT: _age_here(VenueRoom.Age.WORN)
			JOY_BUTTON_DPAD_UP: _age_here(VenueRoom.Age.REPAIRED)
			JOY_BUTTON_DPAD_RIGHT: _age_here(VenueRoom.Age.RENOVATED)


func _busy() -> bool:
	return _panel.visible or _job_scene != null or _office != null or kit.busy()


func _process(dt: float) -> void:
	if story and not _busy():
		story.tick(dt)
		if story.game_due and not _leaving:
			_leaving = true
			_show_toast("GAME NIGHT. YOUR TEAM'S IN THE ROOM. BACK TO THE HUB.")
			get_tree().create_timer(2.5).timeout.connect(_leave_to.bind("hub"))
	_toast_t -= dt
	_toast.visible = _toast_t > 0.0
	if _busy():
		walker.wish = Vector3.ZERO
		walker.crouch = false
		return
	walker.speed_scale = kit.step(dt) if not flying else 1.0
	var look := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if look.length() > 0.15:
		var k := 0.35 if kit.balancing else 1.0  # the stick is busy balancing
		_yaw -= look.x * 2.5 * dt * k
		_pitch = clampf(_pitch - look.y * 2.0 * dt * k, -1.45, 1.45)
	walker.rotation.y = _yaw
	walker.head.rotation.x = _pitch
	var mv := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left") + float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up") + float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if stick.length() > 0.15:
		mv += stick
	var basis := Basis(Vector3.UP, _yaw)
	var dir := basis * Vector3(mv.x, 0, mv.y)
	walker.running = Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_STICK)
	if flying:
		var v := (walker.head.global_transform.basis * Vector3(mv.x, 0, mv.y))
		v.y += float(Input.is_physical_key_pressed(KEY_SPACE)) - float(Input.is_physical_key_pressed(KEY_CTRL))
		walker.global_position += v * (12.0 if walker.running else 5.0) * dt
		walker.wish = Vector3.ZERO
		walker.crouch = false
	else:
		walker.wish = dir
		walker.crouch = Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_C) \
			or Input.is_joy_button_pressed(0, JOY_BUTTON_B)
	_label.text = "\n".join(_hud_lines())


func _hud_lines() -> Array:
	var room := venue.room_at(walker.global_position + Vector3(0, 0.5, 0))
	var head := "// %s   %s" % [venue.rink_name, story.clock_text() if story else "FREE WALK"]
	var where := "%s [%s]" % [room.display_name.to_upper() if room else "OUTSIDE", VenueRoom.AGE_NAMES[room.age].to_upper() if room else "-"]
	var s := _looked_at()
	var hint := ""
	if s:
		hint = "[E] " + s.prompt()
	else:
		hint = kit.hands_hint()
		var d := walker.nearest_door(venue)
		if d and not hint.begins_with("[E]"):
			hint = "[E] %s %s" % ["CLOSE" if d.is_open else "OPEN", d.label.to_upper()]
	if story and story.link:
		head += "   [O] OFFICE"
	if kit.status() != "":
		hint = kit.status()
	return [head, where, hint]


func _looked_at() -> VenueSpot:
	return walker.nearest_spot(venue, -cam.global_transform.basis.z, kit.spots)


## E / A: the spot you're looking at, else the nearest door.
func _use() -> void:
	if _panel.visible:
		if not _panel_job.is_empty():
			_quick_job()
		else:
			_close_panel()
		return
	if _job_scene or _office:
		return
	var s := _looked_at()
	if s:
		_act(story.use(s) if story else {"toast": s.prompt()})
		return
	var hands := kit.use_hands()
	if hands != "":
		_show_toast(hands)
		return
	var d := walker.nearest_door(venue)
	if d:
		if story and story.door_locked(d):
			_show_toast("LOCKED. THE KEYS MUST BE SOMEWHERE.")
		else:
			d.toggle()


func _act(a: Dictionary) -> void:
	if kit.handles(a):
		_show_toast(kit.act(a))
	elif a.has("read"):
		_show_read(a.read)
	elif a.has("job"):
		_start_job(a.job)
	elif a.has("screen"):
		_show_screen(a.screen)
	elif a.has("toast"):
		_show_toast(a.toast)


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast_t = 3.5


func _open_panel(bb: String) -> void:
	_panel_text.text = bb
	_panel.visible = true


func _close_panel() -> void:
	_panel.visible = false
	_panel_job = {}
	if _office:
		_office.queue_free()
		_office = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show_read(t: Dictionary) -> void:
	var bb := "[color=#%s]// %s[/color]\n" % [RinkOS.ACTION.to_html(false), str(t.get("title", "")).to_upper()]
	if str(t.get("author", "")) != "":
		bb += "[color=#%s]%s[/color]\n" % [RinkOS.DIM.to_html(false), t.author]
	bb += "\n%s\n" % t.get("text", "")
	if str(t.get("noticed", "")) != "":
		bb += "\n[color=#%s]> %s[/color]" % [RinkOS.READOUT.to_html(false), t.noticed]
	bb += "\n\n[color=#%s][E] CLOSE[/color]" % RinkOS.DIM.to_html(false)
	_open_panel(bb)


## A job: World and assets' mini game when its scene exists (its root has
## begin(ctx) and emits finished(result)), straight to the sim when it has no
## scene (the plant round), else the quick way at the owner's skill.
func _start_job(job: Dictionary) -> void:
	job_started.emit(job)
	var path: String = job.get("scene", "")
	if path == "":
		var done := story.finish_job(job, {})
		_show_toast(str(done.get("text", "DONE.")).to_upper())
		return
	if ResourceLoader.exists(path):
		_job_scene = load(path).instantiate()
		var ctx := {"sim": story.sim, "job": job.job, "target": job.target, "room": job.room, "args": job.args}
		if _job_scene.has_signal("finished"):
			_job_scene.finished.connect(_on_job_finished.bind(job))
		add_child(_job_scene)
		if _job_scene.has_method("begin"):
			_job_scene.begin(ctx)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	_panel_job = job
	var bb := "[color=#%s]// %s[/color]\n\n" % [RinkOS.ACTION.to_html(false), str(job.job).replace("_", " ").to_upper()]
	var note := story.spot_text(job)
	if not note.is_empty():
		bb += "%s\n\n" % note.text
	bb += "[color=#%s]The mini game for this one isn't in yet.[/color]\n\n[color=#%s][E] DO IT THE QUICK WAY   [Q] LEAVE IT[/color]" % [RinkOS.DIM.to_html(false), RinkOS.ACTION.to_html(false)]
	_open_panel(bb)


func _quick_job() -> void:
	var r := story.finish_job(_panel_job, {})
	_close_panel()
	_show_toast(str(r.get("text", "")).to_upper() if r.get("text", "") != "" else "DONE.")


func _on_job_finished(result: Dictionary, job: Dictionary) -> void:
	var r := story.finish_job(job, result)
	if is_instance_valid(_job_scene):
		_job_scene.queue_free()
	_job_scene = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_show_toast(str(r.get("text", "")).to_upper())


## Office screens belong to UI: the spots UI's rink office covers open it on
## that tab with the walk's sim (Q / Esc / B to leave); the rest get a plain
## readout of the sim.
func _show_screen(id: String) -> void:
	screen_requested.emit(id, story.sim if story else null)
	if story == null:
		return
	var sim := story.sim
	if id == "desk" and story.link:
		_leave_to("office")
		return
	if OFFICE_TABS.has(id) and ResourceLoader.exists(OFFICE_SCENE):
		var office: Node = load(OFFICE_SCENE).instantiate()
		_office = CanvasLayer.new()
		_office.layer = 10
		_office.add_child(office)
		add_child(_office)
		office.sim = sim
		office.open(OFFICE_TABS[id])
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	var lines := []
	match id:
		"desk":
			lines = ["// THE DESK", "----", "%s" % sim.clock_text(), "CASH      $%.0f" % sim.money, "HOURS LEFT %.1f" % sim.hours_left]
		"phone":
			lines = ["// THE PHONE", "----", "A beige rotary phone. Nobody on the line yet.", "A card under a thumbtack: DUKES DON'T CALL HERE."]
		"goals":
			lines = ["// THIS WEEK (GUS)", "----", "1. KEEP EVERY BOOKING", "2. GET THE ICE UNDER 40 MM", "3. DECIDE ABOUT COMPRESSOR 1", "4. WIN BACK ONE MINOR HOCKEY SLOT"]
		"ice_grid":
			lines = ["// ICE GRID", "----"]
			for org_id in sim.contracts:
				var o := RinkContracts.org(org_id)
				for slot in o.slots:
					lines.append("%s %02d:00  %s" % [RinkSim.DAY_NAMES[int(slot[0])].to_upper(), int(slot[1]), str(o.name).to_upper()])
		"log_book":
			lines = ["// PLANT LOG", "----"]
			var rd := sim.readings()
			for k in rd:
				lines.append("%-14s %s" % [k.to_upper(), str(rd[k])])
		_:
			lines = ["// " + id.to_upper()]
	_open_panel("\n".join(lines) + "\n\n[color=#%s][E] CLOSE[/color]" % RinkOS.DIM.to_html(false))


## Out of the walk in an owner career, with the career saved: to the rink
## office or the hub.
func _leave_to(where: String) -> void:
	_leaving = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var cs: Node = get_node_or_null("/root/CareerState")
	if cs == null:
		return
	if cs.career:
		cs.career.save()
	if where == "office":
		cs.open_office()
	else:
		cs.back_to_hub()


func _toggle_fly() -> void:
	flying = not flying
	walker.set_physics_process(not flying)
	walker.velocity = Vector3.ZERO


func _age_here(age: int) -> void:
	var room := venue.room_at(walker.global_position + Vector3(0, 0.5, 0))
	if room:
		venue.set_room_age(room.room_id, age)
		if room.room_id == "lighting" or room.room_id == "shell":
			venue.apply_lighting(_env, _sun)
