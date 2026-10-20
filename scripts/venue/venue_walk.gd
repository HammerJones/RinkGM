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
## Esc / B close a panel or the office computer, 1 2 3 / D-pad set this room's age,
## F / Y fly. On the ice in shoes the mouse or right stick keeps the
## owner's balance (KitHud).
##
## Notes, signs and manuals are real objects (Readable), read where they
## hang: E leans in on the one you're looking at (or the one a READ spot is
## about), right mouse (held) leans in on whatever is ahead, left mouse takes
## a loose note down and sticks the held one to whatever you click (a wall,
## a door, the cork board, another sign), F crumples the held note. On a
## whiteboard the left mouse (held) draws and X wipes your own marks.

## UI's office screens and anything else listening: the player asked for
## screen `id` (log_book, phone, goals, ice_grid, desk) with the sim.
signal screen_requested(id: String, sim: RinkSim)

## A job spot was used: `job` is WalkStory's job dictionary.
signal job_started(job: Dictionary)

const OFFICE_SCENE := "res://scenes/ui/rink_office.tscn"
## Screen spot -> UI rink office tab. The plant log book isn't one: it's
## read where it hangs, in the plant room.
const OFFICE_TABS := {"ice_grid": "grid", "goals": "board", "desk": "jobs"}
const JOBS_DIR := "res://scenes/world/jobs/"
## How far away a readable can be leaned in on, and taken down or stuck up.
const READ_REACH := 3.6
const HAND_REACH := 2.2
const FOV := 70.0
const LEAN_FOV := 30.0

var venue: Venue
var walker: VenueWalker
var cam: Camera3D
var story: WalkStory
var flying := false
var _yaw := -PI * 0.5  # facing +X, toward the front doors and the ice
var _pitch := 0.0
var _label: Label
var _prompt: Label   # the [E] line, under the middle of the screen
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
## The note in your hand, if any, and whether it's held up close.
var _held: Readable
var _held_close := false
## The readable being leaned in on (the view aims at it and narrows).
var _inspect: Readable
var _lean := false
## The whiteboard the left mouse is drawing on.
var _drawing: Whiteboard
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
	_env = Look.make("arena")
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
	cam.fov = FOV
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
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.position = Vector2(-300, 28)
	_prompt.size = Vector2(600, 40)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_color", RinkOS.ACTION)
	_prompt.add_theme_color_override("font_shadow_color", Color.BLACK)
	layer.add_child(_prompt)
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.position = Vector2(-300, -120)
	_toast.size = Vector2(600, 40)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_color", RinkOS.ACTION)
	_toast.add_theme_color_override("font_shadow_color", Color.BLACK)
	layer.add_child(_toast)
	# a small dot in the middle of the view: what E, the mouse and leaning aim at
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.6)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.size = Vector2(3, 3)
	dot.position = Vector2(-1.5, -1.5)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dot)
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
		# on the ice in shoes the mouse mostly fights for balance; slower
		# while leaning in
		var look := (0.35 if kit.balancing else 1.0) * cam.fov / FOV
		if kit.balancing:
			kit.push(e.relative)
		_yaw -= e.relative.x * 0.003 * look
		_pitch = clampf(_pitch - e.relative.y * 0.003 * look, -1.45, 1.45)
		if _inspect and e.relative.length() > 30.0:
			_inspect = null
	elif e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_RIGHT:
			_lean = e.pressed
		elif e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			if _drawing:
				_drawing.end_stroke()
				_drawing = null
		elif e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if not _busy():
				_hand()
		elif e.pressed and not kit.bag_open:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventKey and e.pressed and not e.echo:
		if kit.key(e):
			return
		match e.keycode:
			KEY_TAB:
				if not _busy():
					kit.toggle_bag()
			KEY_ESCAPE:
				_inspect = null
				_close_panel()
			KEY_O:
				if story and story.link and not _busy():
					_leave_to("office")
			KEY_E: _use()
			KEY_SPACE:
				if not flying and not _busy():
					walker.jump()
			KEY_Q:
				_inspect = null
				if _panel.visible or _office:
					_close_panel()
				else:
					kit.toggle_watch()
			KEY_F:
				if _held:
					_crumple()
				else:
					_toggle_fly()
			KEY_X:
				var wb := _looked_whiteboard()
				if wb and not _busy():
					wb.wipe()
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
		_prompt.text = ""
		return
	walker.speed_scale = kit.step(dt) if not flying else 1.0
	_aim(dt)
	if _drawing:
		if _looked_whiteboard() == _drawing:
			_drawing.draw_at(_ray(HAND_REACH, 1 << (Readable.READ_LAYER - 1)).position)
		else:
			_drawing.end_stroke()
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
	if _inspect and mv.length() > 0.2:
		_inspect = null  # walking away
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
	_prompt.text = _hint()


func _hud_lines() -> Array:
	var room := venue.room_at(walker.global_position + Vector3(0, 0.5, 0))
	var head := "// %s   %s" % [venue.rink_name, story.clock_text() if story else "FREE WALK"]
	var where := "%s [%s]" % [room.display_name.to_upper() if room else "OUTSIDE", VenueRoom.AGE_NAMES[room.age].to_upper() if room else "-"]
	if story and story.link:
		head += "   [O] OFFICE"
	return [head, where]


## The [E] line (shown under the middle of the screen, playtest #20): what
## you can do with what you're looking at or holding, else the nearest door.
func _hint() -> String:
	if kit.status() != "":
		return kit.status()
	var s := _looked_at()
	var r := _looked_readable(READ_REACH)
	if _held:
		return "[LMB] STICK IT HERE   [E] %s   [F] CRUMPLE" % ("LOWER" if _held_close else "LOOK CLOSER")
	if _inspect:
		return "[E] STEP BACK"
	if _looked_whiteboard():
		return "[E] LEAN IN   [LMB] DRAW   [X] WIPE YOUR MARKS"
	if r:
		var lean := "[E] LEAN IN"
		if r.movable and _looked_readable(HAND_REACH) == r:
			lean += "   [LMB] TAKE DOWN"
		return lean
	if s:
		return "[E] " + s.prompt()
	var hint := kit.hands_hint()
	var d := walker.nearest_door(venue)
	if d and not hint.begins_with("[E]"):
		hint = "[E] %s %s" % ["CLOSE" if d.is_open else "OPEN", d.label.to_upper()]
	return hint


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
	if _held:
		_held_close = not _held_close
		_place_held()
		return
	if _inspect:
		_inspect = null
		return
	var s := _looked_at()
	var r := _looked_readable(READ_REACH)
	if r == null and s and s.kind == VenueSpot.Kind.READ:
		r = _readable_for(s.id)
	if r:
		_inspect = r
		# a READ spot about this readable still counts as read (flags, keys)
		if s and s.kind == VenueSpot.Kind.READ and story and (s.id == r.story or _readable_for(s.id) == r):
			var a := story.use(s)
			a.erase("read")
			_act(a)
		return
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
		if str(job.get("in_place", "")) == "doris_hatch":
			_doris_hatch_ctx(ctx)
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
	bb += "[color=#%s]The mini game for this one isn't in yet.[/color]\n\n[color=#%s][E] DO IT THE QUICK WAY   [ESC] LEAVE IT[/color]" % [RinkOS.DIM.to_html(false), RinkOS.ACTION.to_html(false)]
	_open_panel(bb)


## World: a repair through Doris's hatch plays where she's parked, the camera
## leaning in from the walker's eye (playtest W2; JobScene's in-place ctx).
func _doris_hatch_ctx(ctx: Dictionary) -> void:
	var cam := get_viewport().get_camera_3d()
	var from := cam.global_position if cam else Vector3.ZERO
	var best: DorisModel = null
	for n in get_tree().get_nodes_in_group("doris_model"):
		var d := n as DorisModel
		if d and d.is_visible_in_tree() and (best == null or d.global_position.distance_to(from) < best.global_position.distance_to(from)):
			best = d
	if best == null:
		return
	ctx["place"] = best.global_transform * DorisModel.hatch_frame()
	ctx["host"] = best
	if cam:
		ctx["eye"] = cam.global_transform


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
	set_noclip(not flying)


## Fly through walls (F / Y, or the dev menu's noclip).
func set_noclip(on: bool) -> void:
	flying = on
	walker.set_physics_process(not flying)
	walker.velocity = Vector3.ZERO


func _age_here(age: int) -> void:
	var room := venue.room_at(walker.global_position + Vector3(0, 0.5, 0))
	if room:
		venue.set_room_age(room.room_id, age)
		if room.room_id == "lighting" or room.room_id == "shell":
			venue.apply_lighting(_env, _sun)


## The readable straight ahead within `reach`, if any (walls block the view).
func _looked_readable(reach: float) -> Readable:
	var hit := _ray(reach, (1 << (VenueKit.VENUE_LAYER - 1)) | (1 << (Readable.READ_LAYER - 1)))
	return Readable.from_collider(hit.get("collider")) if hit else null


## The whiteboard straight ahead within reach (to draw on), if any.
func _looked_whiteboard() -> Whiteboard:
	var hit := _ray(HAND_REACH, (1 << (VenueKit.VENUE_LAYER - 1)) | (1 << (Readable.READ_LAYER - 1)))
	return Whiteboard.from_collider(hit.get("collider")) if hit else null


func _ray(reach: float, mask: int, exclude: Array[RID] = []) -> Dictionary:
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_transform.basis.z * reach, mask, exclude)
	return get_world_3d().direct_space_state.intersect_ray(q)


## The nearest readable belonging to world readable `story_id` near you.
func _readable_for(story_id: String) -> Readable:
	var best: Readable = null
	var best_d := READ_REACH
	for n in get_tree().get_nodes_in_group("readables"):
		var r := n as Readable
		if r and r != _held and r.story == story_id:
			var d := r.face_center().distance_to(cam.global_position)
			if d < best_d:
				best_d = d
				best = r
	return best


## Leaning in: the view turns to the readable being inspected and narrows
## until it fills most of the screen; right mouse narrows it on anything.
func _aim(dt: float) -> void:
	var fov := LEAN_FOV if _lean else FOV
	if _inspect and not is_instance_valid(_inspect):
		_inspect = null
	if _inspect:
		var to := _inspect.face_center() - cam.global_position
		var t := 1.0 - exp(-8.0 * dt)
		_yaw = lerp_angle(_yaw, atan2(-to.x, -to.z), t)
		_pitch = lerpf(_pitch, clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.45, 1.45), t)
		var aspect := get_viewport().get_visible_rect().size.aspect()
		var extent := maxf(_inspect.size.y, _inspect.size.x / aspect)
		fov = clampf(rad_to_deg(2.0 * atan(extent * 0.5 / 0.8 / maxf(to.length(), 0.1))), 8.0, FOV)
	cam.fov = lerpf(cam.fov, fov, 1.0 - exp(-10.0 * dt))


## Left mouse: take down the loose note ahead, or stick the held one up.
func _hand() -> void:
	if _held:
		_stick_held()
		return
	var wb := _looked_whiteboard()
	if wb:
		_inspect = null
		_drawing = wb
		return
	var r := _looked_readable(HAND_REACH)
	if r == null or not r.movable:
		return
	_inspect = null
	_held = r
	_held_close = false
	r.set_pickable(false)
	r.reparent(cam, false)
	_place_held()


## The held note in front of the view: low in the hand, or up close.
func _place_held() -> void:
	var extent := maxf(_held.size.y, _held.size.x / 1.78)
	var d := clampf(extent / (2.0 * tan(deg_to_rad(FOV * 0.5))) / 0.8, 0.16, 0.6)
	if _held_close:
		_held.transform = Transform3D(Basis.IDENTITY, Vector3(0, 0, -d))
	else:
		_held.transform = Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0.08, -0.16, -d * 1.3))


## Sticks the held note to whatever is ahead (wall, door, board, sign),
## flat against it, upright, and parented to it so it moves with it.
func _stick_held() -> void:
	var hit := _ray(HAND_REACH, (1 << (VenueKit.VENUE_LAYER - 1)) | (1 << (Readable.READ_LAYER - 1)))
	if hit.is_empty():
		_show_toast("NOTHING TO STICK IT TO.")
		return
	var n: Vector3 = hit.normal
	var up := Vector3.UP
	if absf(n.y) > 0.9:
		# on a table or the floor: the top edge away from you
		var f := -cam.global_transform.basis.z
		up = Vector3(f.x, 0, f.z).normalized() if Vector2(f.x, f.z).length() > 0.01 else Vector3.FORWARD
	var x := up.cross(n).normalized()
	var y := n.cross(x).normalized()
	var r := _held
	_held = null
	var target: Node = hit.collider
	r.reparent(target, false)
	r.global_transform = Transform3D(Basis(x, y, n), hit.position + n * 0.0015)
	r.set_pickable(true)


## F with a note in hand: it's a paper ball now, dropped where you stand.
func _crumple() -> void:
	var ball := RigidBody3D.new()
	ball.name = "CrumpledNote"
	ball.collision_layer = 0
	ball.collision_mask = 1 << (VenueKit.VENUE_LAYER - 1)
	ball.mass = 0.02
	var mesh := SphereMesh.new()
	mesh.radius = 0.032
	mesh.height = 0.055
	mesh.radial_segments = 5
	mesh.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = Readable.KINDS.get(_held.kind, Readable.KINDS.paper)[1]
	m.roughness = 0.95
	mesh.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.rotation = Vector3(0.6, 1.1, 0.3)
	ball.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.03
	cs.shape = sh
	ball.add_child(cs)
	venue.add_child(ball)
	var f := -cam.global_transform.basis.z
	ball.global_position = cam.global_position + f * 0.3 + Vector3(0, -0.1, 0)
	ball.linear_velocity = f * 1.2 + Vector3(0, 0.6, 0) + walker.velocity
	ball.angular_velocity = Vector3(3, 5, 2)
	_held.queue_free()
	_held = null
