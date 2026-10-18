extends Node3D
## Walk-around playtest of the venue (no hockey): explore the building on
## foot, open doors, and flip the room you're standing in between worn,
## repaired and renovated.
##
##   godot --path . res://scenes/venue/venue_walk.tscn [-- --tier=3]
##   (or `-- --venue-walk` on the normal game)
##
## WASD / left stick walk, mouse / right stick look, Shift / L3 run,
## E / A open or close a door, 1 2 3 / D-pad set this room's age,
## F / Y fly, Esc frees the mouse.

var venue: Venue
var walker: VenueWalker
var cam: Camera3D
var flying := false
var _yaw := -PI * 0.5  # facing +X, from the lobby toward the ice
var _pitch := 0.0
var _label: Label
var _sun: DirectionalLight3D
var _env: Environment


func _ready() -> void:
	var tier := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tier="):
			tier = a.trim_prefix("--tier=").to_int()
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
	add_child(Rink.new())
	venue = Venue.instantiate_for(Career.exhibition(clampi(tier, 0, LeagueTiers.count() - 1)), true)
	add_child(venue)
	venue.apply_lighting(_env, _sun)
	walker = VenueWalker.new()
	add_child(walker)
	walker.global_position = venue.rooms["lobby"].spawn
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.05
	walker.head.add_child(cam)
	cam.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_color_override("font_color", VenueSign.CYAN)
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	layer.add_child(_label)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= e.relative.x * 0.003
		_pitch = clampf(_pitch - e.relative.y * 0.003, -1.45, 1.45)
	elif e is InputEventMouseButton and e.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_E: _use_door()
			KEY_F: _toggle_fly()
			KEY_1: _age_here(VenueRoom.Age.WORN)
			KEY_2: _age_here(VenueRoom.Age.REPAIRED)
			KEY_3: _age_here(VenueRoom.Age.RENOVATED)
	elif e is InputEventJoypadButton and e.pressed:
		match e.button_index:
			JOY_BUTTON_A: _use_door()
			JOY_BUTTON_Y: _toggle_fly()
			JOY_BUTTON_DPAD_LEFT: _age_here(VenueRoom.Age.WORN)
			JOY_BUTTON_DPAD_UP: _age_here(VenueRoom.Age.REPAIRED)
			JOY_BUTTON_DPAD_RIGHT: _age_here(VenueRoom.Age.RENOVATED)


func _process(dt: float) -> void:
	var look := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if look.length() > 0.15:
		_yaw -= look.x * 2.5 * dt
		_pitch = clampf(_pitch - look.y * 2.0 * dt, -1.45, 1.45)
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
	else:
		walker.wish = dir
	var room := venue.room_at(walker.global_position + Vector3(0, 0.5, 0))
	var door := walker.nearest_door(venue)
	var lines := [
		"// RINK WALK   %s" % venue.rink_name,
		"ROOM: %s [%s]" % [room.display_name if room else "-", VenueRoom.AGE_NAMES[room.age].to_upper() if room else "-"],
		"[1][2][3] SET ROOM AGE   [E] %s   [F] %s   [SHIFT] RUN" % [("OPEN " + door.label.to_upper()) if door and not door.is_open else ("CLOSE " + door.label.to_upper() if door else "DOOR"), "WALK" if flying else "FLY"],
	]
	_label.text = "\n".join(lines)


func _use_door() -> void:
	var d := walker.nearest_door(venue)
	if d:
		d.toggle()


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
