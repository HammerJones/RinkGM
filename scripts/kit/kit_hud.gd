class_name KitHud
extends Node
## The owner's kit on screen in the venue walk (OwnerKit is the state):
##
## - Q raises the watch: the time and day, running timers, the alarm and the
##   stopwatch. Raised, T starts a 15-minute timer (Shift+T an hour), L sets
##   the alarm half an hour on from the last, K turns it off, P runs the
##   stopwatch, X clears the timers, U orders the next watch up.
## - Tab opens the bag: drag items about with the mouse, R turns the one in
##   hand, Tab / Esc closes it (an item in hand goes back where it was).
## - On the ice in shoes the owner walks at half speed and has to keep their
##   balance: the mouse (or right stick) pushes a wobbling dot back into the
##   circle. Too long outside and they go down.
## - The ball cart in the gym starts a pickup game (PickupGame): the ball
##   dribbles itself, the view aims, holding the left mouse powers the shot.
## - The game sheet at the timekeeper's desk opens the scorekeeping game
##   (ScorekeepingView) for the game on the ice.
## - The nets: picked up from the storage by the Zamboni gate, carried out in
##   the owner's arms, set down on the ice with E and lifted again the same way.
##
## venue_walk.gd builds one, forwards the keys and calls step() each frame.

const CELL := 46
const NET_COLLECT := 1.7          # metres from a net on the ice to lift it
## Until the venue has its own net storage and crampons can (Venue, #19):
## spots just inside the bay's rink door and on the workbench.
const FALLBACK_SPOTS := [
	["net_storage", VenueSpot.Kind.USE, "Big nets", {"carry": "large", "note": "net_storage", "verb": "TAKE OR RETURN"}, Vector3(34.7, 1.0, -3.4)],
	["net_storage_mini", VenueSpot.Kind.USE, "Small nets", {"carry": "mini", "note": "net_storage", "verb": "TAKE OR RETURN"}, Vector3(34.7, 0.6, -1.9)],
	["crampons_can", VenueSpot.Kind.READ, "Coffee can with a note", {"note": "crampons_note", "gives": "crampons"}, Vector3(37.9, 1.0, -4.45)],
]
const TIMER_SHORT := 15
const TIMER_LONG := 60

signal toast(text: String)

var kit: OwnerKit
var story: WalkStory
var walker: VenueWalker
var cam: Camera3D
var venue: Venue
var watch_up := false
var bag_open := false
## True while the owner is on the ice in shoes.
var balancing := false
## Seconds left of a fall (the view goes down and comes back up).
var down_t := 0.0
## Extra spots the walk looks at (fallback storage and can).
var spots: Array[VenueSpot] = []

var _layer: CanvasLayer
var _watch_panel: PanelContainer
var _watch_text: RichTextLabel
var _bag: _BagView
var _bag_panel: PanelContainer
var _bag_info: RichTextLabel
var _balance_view: _BalanceView
var _world: Node3D
var _held_mesh: MeshInstance3D
var _net_nodes: Array[Node3D] = []
var _storage_nodes := {}
var _mouse_push := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _net_large: ArrayMesh
var _store := {}
## The pickup game in the gym while one runs.
var pickup: PickupGame
## The game sheet in the scorekeeper's box while it's open.
var sheet: ScorekeepingView
var _pad_shot := false


func setup(story_: WalkStory, walker_: VenueWalker, cam_: Camera3D, venue_: Venue) -> void:
	story = story_
	walker = walker_
	cam = cam_
	venue = venue_
	_rng.randomize()
	var store := _store
	if story and story.link:
		var w: Dictionary = story.link.career.world
		if not w.has("kit"):
			w["kit"] = {}
		store = w.kit
	kit = OwnerKit.open(store)
	_net_large = Models.net().build_mesh()
	_build_ui()
	_build_world()
	if story:
		_announce(kit.sync_flags(story.flags))


# --------------------------------------------------------------- the walk calls

func toggle_watch() -> void:
	watch_up = not watch_up
	_refresh_watch()


func toggle_bag() -> void:
	bag_open = not bag_open
	if not bag_open:
		_bag.drop_held()
	_bag_panel.visible = bag_open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if bag_open else Input.MOUSE_MODE_CAPTURED
	_refresh_bag_info()


## Mouse motion while balancing (pixels): it pushes the dot.
func push(relative: Vector2) -> void:
	_mouse_push += relative * 0.012


## One frame. Returns the walker's speed scale; a fall shows in down_t.
func step(dt: float) -> float:
	if story:
		_announce(kit.sync_flags(story.flags))
		var now := Watch.abs_minute(story.sim)
		for f in kit.watch.tick(now):
			toast.emit("BEEP BEEP. %s." % str(f.label).to_upper())
	var p := walker.global_position
	var on_ice := p.y < 0.6 and Rink.sdf(Vector2(p.x, p.z)) < 0.0
	balancing = IceBalance.needed(on_ice, kit.has_crampons()) and down_t <= 0.0
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	var input := _mouse_push + (stick if stick.length() > 0.15 else Vector2.ZERO)
	_mouse_push = _mouse_push.move_toward(Vector2.ZERO, _mouse_push.length() * minf(1.0, 14.0 * dt))
	if pickup:
		var rt := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.5
		if rt and not _pad_shot:
			pickup.hold()
		elif _pad_shot and not rt:
			pickup.release()
		_pad_shot = rt
		var room := venue.room_at(walker.global_position + Vector3(0, 0.5, 0)) if venue else null
		if room == null or room.room_id != "gym":
			toast.emit("YOU WALK OFF THE COURT.")
			pickup.queue_free()
			pickup = null
	var speed := Vector2(walker.velocity.x, walker.velocity.z).length()
	if down_t > 0.0:
		down_t -= dt
	elif kit.footing(dt, on_ice, input, speed, _steadiness()) == "fell":
		_fall()
	_balance_view.visible = balancing
	_balance_view.b = kit.balance
	_balance_view.queue_redraw()
	_sway_camera(dt)
	_held_mesh.visible = kit.carrying != ""
	_held_mesh.scale = Vector3.ONE * (1.0 if kit.carrying == "large" else 0.5)
	if watch_up:
		_refresh_watch()
	return kit.speed_scale(on_ice) if down_t <= 0.0 else 0.0


## E with nothing else in front of the owner: set a carried net down on the
## ice, or lift one that's there. Returns a toast, or "" when it did nothing.
func use_hands() -> String:
	var p := walker.global_position
	var at := Vector2(p.x, p.z)
	if kit.carrying != "":
		if not (p.y < 0.6 and Rink.sdf(at) < -0.5):
			return ""
		var fwd := -cam.global_transform.basis.z
		var spot := at + Vector2(fwd.x, fwd.z).normalized() * 1.0
		kit.set_down(spot, walker.rotation.y + PI, _ops())
		_rebuild_nets()
		return "NET DOWN. %d LARGE, %d SMALL ON THE ICE." % [_ops().nets_on[0], _ops().nets_on[1]] if _ops() else "NET DOWN."
	var i := kit.net_near(at, NET_COLLECT)
	if i >= 0 and kit.lift(i, _ops()):
		_rebuild_nets()
		return "YOU LIFT THE NET. IT'S HEAVIER THAN IT LOOKS."
	return ""


## The hint for use_hands(), or "".
func hands_hint() -> String:
	var p := walker.global_position
	if kit.carrying != "":
		return "[E] SET THE NET DOWN" if p.y < 0.6 and Rink.sdf(Vector2(p.x, p.z)) < -0.5 else "CARRYING A %s NET" % ("BIG" if kit.carrying == "large" else "SMALL")
	if kit.net_near(Vector2(p.x, p.z), NET_COLLECT) >= 0:
		return "[E] LIFT THE NET"
	return ""


## WalkStory.use() results the kit handles: {"carry": kind}, {"train": machine}.
func act(a: Dictionary) -> String:
	if a.has("carry"):
		if kit.carrying != "":
			kit.put_away()
			_refresh_storage()
			return "BACK ON THE RACK."
		if not kit.pick_up(str(a.carry), _ops()):
			return "NONE LEFT IN STORAGE."
		_refresh_storage()
		return "YOU HEFT A %s NET. THE ICE IS THAT WAY." % ("BIG" if a.carry == "large" else "SMALL")
	if a.has("scorekeep"):
		if sheet == null:
			_open_sheet()
		return ""
	if a.has("pickup"):
		if pickup:
			return ""
		pickup = PickupGame.create(walker, cam, a.pickup.get("hoops", []))
		pickup.finished.connect(_pickup_done)
		_world.add_child(pickup)
		return "NEXT TEN SHOTS, THEN THE GAME RUNS ON."
	if a.has("train"):
		var player := _player()
		if player == null or story == null:
			return "TRAINING COUNTS IN AN OWNER CAREER."
		var r := kit.training.do_set(str(a.train), player, story.sim, story.advance_minutes)
		kit.save()
		return str(r.text).to_upper()
	return ""


func handles(a: Dictionary) -> bool:
	return a.has("carry") or a.has("train") or a.has("pickup") or a.has("scorekeep")


## The bag or the game sheet has the screen: the walk stands still.
func busy() -> bool:
	return bag_open or sheet != null


func _open_sheet() -> void:
	var seed_ := story.sim.day * 1440 + story.sim.minute if story else randi()
	sheet = ScorekeepingView.create(Scorekeeping.create(seed_))
	sheet.finished.connect(_sheet_done)
	_layer.add_child(sheet)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _sheet_done(result: Dictionary) -> void:
	var line := "%d OF %d CALLS CLEAN. " % [int(result.clean), int(result.of)]
	var said := story.sim.ops.sheet_kept(story.sim, float(result.quality)) if story else ""
	line += said.to_upper() if said != "" else "NO GAME ON: GOOD PRACTICE FOR THE NEXT ONE."
	toast.emit(line)
	sheet.queue_free()
	sheet = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The pickup game's line for the HUD, or "".
func status() -> String:
	return pickup.status() if pickup else ""


func _unhandled_input(e: InputEvent) -> void:
	if pickup and e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if e.pressed:
			pickup.hold()
		else:
			pickup.release()
		get_viewport().set_input_as_handled()


func _pickup_done(shots: int, makes: int) -> void:
	var line := "%d OF %d. " % [makes, shots]
	var player := _player()
	if player and story:
		var r := kit.training.pickup("basketball", PickupGame.MINUTES, shots, makes, player, story.sim, story.advance_minutes)
		kit.save()
		line += str(r.text).to_upper()
	else:
		line += "GOOD RUN."
	toast.emit(line)
	pickup.queue_free()
	pickup = null


## Keys while the watch is up or the bag is open. True when used.
func key(e: InputEventKey) -> bool:
	if sheet and e.keycode == KEY_ESCAPE:
		sheet.queue_free()
		sheet = null
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return true
	if bag_open:
		match e.keycode:
			KEY_R:
				_bag.rotate_held()
				return true
			KEY_ESCAPE, KEY_TAB:
				toggle_bag()
				return true
		return false
	if not watch_up or story == null:
		return false
	var now := Watch.abs_minute(story.sim)
	var w := kit.watch
	var said := ""
	match e.keycode:
		KEY_T:
			var m := TIMER_LONG if e.shift_pressed else TIMER_SHORT
			said = "TIMER: %d MIN." % m if w.set_timer(m, "%d-min timer" % m, now) else "NO FREE TIMER ON THIS WATCH."
		KEY_X:
			w.timers.clear()
			said = "TIMERS CLEARED."
		KEY_L:
			var at := (w.alarm if w.alarm >= 0 else (story.sim.minute / 30) * 30) + 30
			said = "ALARM %02d:%02d." % [posmod(at, 1440) / 60, at % 60] if w.set_alarm(at) else "THIS WATCH HAS NO ALARM."
		KEY_K:
			w.set_alarm(-1)
			said = "ALARM OFF."
		KEY_P:
			w.toggle_stopwatch(now)
			said = "STOPWATCH %s." % ("RUNNING" if w.stopwatch_start >= 0 else "STOPPED")
		KEY_U:
			said = _buy_watch()
		_:
			return false
	kit.save()
	_refresh_watch()
	toast.emit(said)
	return true


# --------------------------------------------------------------- internals

func _ops() -> RinkOps:
	return story.sim.ops if story else null


func _player() -> PlayerProfile:
	return story.link.career.user() if story and story.link else null


## Agility steadies the owner; a tired one wobbles.
func _steadiness() -> float:
	var p := _player()
	var agility := float(p.skills.values.get("agility", 50.0)) if p else 50.0
	var tired := story.sim.fatigue if story else 0.0
	return clampf(agility / 100.0 - tired / 250.0, 0.1, 0.9)


func _fall() -> void:
	down_t = 1.6
	var p := walker.global_position
	var had := kit.carrying
	var inj := kit.fall(Vector2(p.x, p.z), walker.rotation.y + PI, _player(), _rng, _ops())
	if had != "":
		_rebuild_nets()
	var line := "DOWN YOU GO."
	if had != "":
		line += " THE NET SKIDS AWAY."
	if inj:
		line += " YOUR %s IS SORE: %d DAY%s." % [str(inj.part).to_upper(), inj.days_out, "" if inj.days_out == 1 else "S"]
	toast.emit(line)
	kit.save()


## The view sways with the dot, and drops to the ice in a fall.
func _sway_camera(dt: float) -> void:
	var roll := 0.0
	var dip := 0.0
	if down_t > 0.0:
		var t := 1.0 - down_t / 1.6
		var fall_curve := sin(clampf(t * 3.0, 0.0, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.55, 1.0, t))
		roll = 0.6 * fall_curve
		dip = -1.25 * fall_curve
	elif balancing:
		roll = kit.balance.pos.x * 0.12
		dip = -absf(kit.balance.pos.y) * 0.05
	cam.rotation.z = lerpf(cam.rotation.z, roll, minf(1.0, 12.0 * dt))
	cam.position.y = lerpf(cam.position.y, dip, minf(1.0, 12.0 * dt))


func _buy_watch() -> String:
	var order := Watch.MODELS.keys()
	var i := order.find(kit.watch.model)
	if i < 0 or i + 1 >= order.size():
		return "THIS IS AS GOOD A WATCH AS THERE IS."
	var next: String = order[i + 1]
	var price := float(Watch.MODELS[next].price)
	if story == null or story.sim.money < price:
		return "THE %s IS $%.0f." % [str(Watch.MODELS[next].name).to_upper(), price]
	story.sim.book("kit", -price)
	kit.watch.upgrade(next)
	return "NEW WATCH: %s ($%.0f)." % [str(Watch.MODELS[next].name).to_upper(), price]


func _announce(got: Array) -> void:
	for n in got:
		toast.emit("IN THE BAG: %s." % str(n).to_upper())
	if not got.is_empty() and bag_open:
		_bag.queue_redraw()


# --------------------------------------------------------------- building

## Anchors `c` to `preset` with its top-left `at` from the anchor point
## (offsets, so it stays put whatever the window size).
static func place(c: Control, preset: int, at: Vector2, size_: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = at.x
	c.offset_top = at.y
	c.offset_right = at.x + size_.x
	c.offset_bottom = at.y + size_.y
	c.custom_minimum_size = size_

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_watch_panel = PanelContainer.new()
	_watch_panel.add_theme_stylebox_override("panel", RinkOS.flat(Color(0.03, 0.04, 0.05, 0.92), 12.0))
	place(_watch_panel, Control.PRESET_BOTTOM_LEFT, Vector2(24, -24), Vector2.ZERO)
	_watch_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_watch_text = RichTextLabel.new()
	_watch_text.bbcode_enabled = true
	_watch_text.fit_content = true
	_watch_text.custom_minimum_size = Vector2(440, 0)
	_watch_text.add_theme_font_override("normal_font", RinkOS.TERM_FONT)
	_watch_text.add_theme_font_size_override("normal_font_size", RinkOS.TERM_SIZE)
	_watch_panel.add_child(_watch_text)
	_watch_panel.visible = false
	_layer.add_child(_watch_panel)

	_bag_panel = PanelContainer.new()
	_bag_panel.add_theme_stylebox_override("panel", RinkOS.flat(RinkOS.PANEL, 16.0))
	place(_bag_panel, Control.PRESET_CENTER, Vector2(-CELL * 4, -CELL * 4), Vector2.ZERO)
	var vb := VBoxContainer.new()
	_bag_panel.add_child(vb)
	vb.add_child(RinkOS.label("// THE BAG", RinkOS.TITLE))
	_bag = _BagView.new()
	_bag.hud = self
	vb.add_child(_bag)
	_bag_info = RichTextLabel.new()
	_bag_info.bbcode_enabled = true
	_bag_info.fit_content = true
	_bag_info.custom_minimum_size = Vector2(CELL * 8, 0)
	vb.add_child(_bag_info)
	_bag_panel.visible = false
	_layer.add_child(_bag_panel)

	_balance_view = _BalanceView.new()
	place(_balance_view, Control.PRESET_CENTER_BOTTOM, Vector2(-80, -330), Vector2(160, 160))
	_balance_view.visible = false
	_layer.add_child(_balance_view)


func _build_world() -> void:
	_world = Node3D.new()
	add_child(_world)
	_held_mesh = MeshInstance3D.new()
	_held_mesh.mesh = _net_large
	# held low out front by the crossbar, the frame dragging toward the ice
	_held_mesh.position = Vector3(-0.5, -1.55, -1.2)
	_held_mesh.rotation = Vector3(0.15, PI, 0.0)
	_held_mesh.visible = false
	cam.add_child(_held_mesh)
	if venue and venue.spot("net_storage") == null:
		for f in FALLBACK_SPOTS:
			var s := VenueSpot.make(f[1], f[0], f[2], f[3], 1.4)
			s.position = f[4]
			_world.add_child(s)
			spots.append(s)
		_refresh_storage()
	_rebuild_nets()


## The stacks by the gate show what's left in storage.
func _refresh_storage() -> void:
	for s in spots:
		if not s.data.has("carry"):
			continue
		var kind: String = s.data.carry
		if _storage_nodes.has(kind):
			_storage_nodes[kind].queue_free()
		var stack := Node3D.new()
		var n := kit.in_storage(kind, _ops())
		for i in n:
			var m := MeshInstance3D.new()
			m.mesh = _net_large
			m.scale = Vector3.ONE * (1.0 if kind == "large" else 0.5)
			m.position = Vector3(0.12 * i if kind == "large" else 0.0, 0.0 if kind == "large" else 0.62 * (i / 4), 0.0 if kind == "large" else -0.95 * (i % 4) + 1.4)
			m.rotation.y = PI * 0.5
			stack.add_child(m)
		stack.position = Vector3(s.position.x - 0.2, 0.0, s.position.z)
		_world.add_child(stack)
		_storage_nodes[kind] = stack


func _rebuild_nets() -> void:
	for n in _net_nodes:
		n.queue_free()
	_net_nodes.clear()
	for e in kit.nets_out:
		var m := MeshInstance3D.new()
		m.mesh = _net_large
		m.scale = Vector3.ONE * (1.0 if e.kind == "large" else 0.5)
		m.position = Vector3(float(e.pos[0]), 0.0, float(e.pos[1]))
		m.rotation.y = float(e.yaw)
		_world.add_child(m)
		_net_nodes.append(m)
	_refresh_storage()


func _refresh_watch() -> void:
	_watch_panel.visible = watch_up
	if not watch_up:
		return
	var now := Watch.abs_minute(story.sim) if story else 0
	var wd := story.sim.weekday() if story else 1
	var dark := story != null and (story.sim.minute < 7 * 60 or story.sim.minute >= 19 * 60) \
		and venue.room_at(walker.global_position + Vector3(0, 0.5, 0)) == null
	var face := kit.watch.read(now, wd, dark)
	var spec := kit.watch.spec()
	var lines := ["[color=#%s]%s[/color]" % [RinkOS.DIM.to_html(false), str(spec.name).to_upper()]]
	if not face.lit:
		lines.append("[font_size=50][color=#202a20]--:--[/color][/font_size]")
		lines.append("[color=#%s]TOO DARK TO READ. NO BACKLIGHT.[/color]" % RinkOS.DIM.to_html(false))
	else:
		lines.append("[font_size=50][color=#%s]%s[/color][/font_size]  %s" % [RinkOS.READOUT.to_html(false), face.time, face.day])
		for t in face.timers:
			lines.append("[color=#%s]%s[/color]  %s" % [RinkOS.ACTION.to_html(false), Watch.minutes_text(int(t.left)), t.label])
		if face.alarm != "":
			lines.append("ALARM %s" % face.alarm)
		if face.stopwatch != "":
			lines.append("STOPWATCH %s" % face.stopwatch)
	lines.append("")
	lines.append("[color=#%s][T] TIMER 15  [SHIFT+T] 60  [X] CLEAR\n[L] ALARM +30  [K] OFF  [P] STOPWATCH\n[U] BETTER WATCH  [Q] LOWER[/color]" % RinkOS.DIM.to_html(false))
	_watch_text.text = "\n".join(lines)


func _refresh_bag_info(hover := -1) -> void:
	var lines: Array = []
	var uid := hover if hover > 0 else _bag.held_uid
	if uid > 0:
		var it := kit.bag.get_item(uid)
		if not it.is_empty():
			var inf := ItemCatalog.info(it.id)
			lines.append("[color=#%s]%s[/color]  %s" % [RinkOS.ACTION.to_html(false), str(inf.name).to_upper(), inf.get("desc", "")])
	if kit.carrying != "":
		lines.append("In your arms: a %s net." % ("big" if kit.carrying == "large" else "small"))
	if kit.has_crampons():
		lines.append("The crampons go on when you step on the ice.")
	lines.append("[color=#%s][CLICK] PICK UP / PUT DOWN  [R] TURN  [TAB] CLOSE[/color]" % RinkOS.DIM.to_html(false))
	_bag_info.text = "\n".join(lines)


func _bag_changed() -> void:
	kit.save()
	_refresh_bag_info()


# --------------------------------------------------------------- views

## The bag's grid: click an item to pick it up, click again to put it down
## where it fits (a green ghost), R turns it.
class _BagView extends Control:
	var hud: KitHud
	var held_uid := -1
	var held_rot := 0
	## Which cell of the item the mouse took it by.
	var _grab := Vector2i.ZERO
	var _hover := Vector2i(-1, -1)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _get_minimum_size() -> Vector2:
		var g := hud.kit.bag.size if hud and hud.kit else InventoryGrid.START_SIZE
		return Vector2(g.x * CELL + 2, g.y * CELL + 2)

	func _cell(p: Vector2) -> Vector2i:
		return Vector2i(floori(p.x / CELL), floori(p.y / CELL))

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			_hover = _cell(e.position)
			hud._refresh_bag_info(hud.kit.bag.uid_at(_hover))
			queue_redraw()
		elif e is InputEventMouseButton and e.pressed:
			if e.button_index == MOUSE_BUTTON_LEFT:
				_click(_cell(e.position))
			elif e.button_index == MOUSE_BUTTON_RIGHT:
				rotate_held()
			accept_event()

	func _click(c: Vector2i) -> void:
		var bag := hud.kit.bag
		if held_uid < 0:
			var uid := bag.uid_at(c)
			if uid > 0:
				var it := bag.get_item(uid)
				held_uid = uid
				held_rot = int(it.rot)
				_grab = c - (it.pos as Vector2i)
		elif bag.move(held_uid, c - _grab, held_rot):
			held_uid = -1
			hud._bag_changed()
		queue_redraw()

	func rotate_held() -> void:
		if held_uid > 0:
			held_rot = posmod(held_rot + 1, 4)
			_grab = Vector2i.ZERO
			queue_redraw()

	## Closing with something in hand: it stays where it was.
	func drop_held() -> void:
		held_uid = -1

	func _draw() -> void:
		var bag := hud.kit.bag
		for y in bag.size.y:
			for x in bag.size.x:
				draw_rect(Rect2(x * CELL + 1, y * CELL + 1, CELL - 2, CELL - 2), Color(1, 1, 1, 0.05))
				draw_rect(Rect2(x * CELL, y * CELL, CELL, CELL), RinkOS.BEZEL, false, 1.0)
		for it in bag.items:
			if int(it.uid) == held_uid:
				continue
			_draw_item(it.id, it.pos, int(it.rot), _colour(it.id), 1.0)
		if held_uid > 0 and _hover.x >= 0:
			var id: String = bag.get_item(held_uid).id
			var ok := bag.fits(id, _hover - _grab, held_rot, held_uid)
			_draw_item(id, _hover - _grab, held_rot, RinkOS.GOOD if ok else RinkOS.ALERT, 0.55)

	func _draw_item(id: String, pos: Vector2i, rot: int, col: Color, alpha: float) -> void:
		for c in ItemCatalog.shape(id, rot):
			var v: Vector2i = pos + c
			draw_rect(Rect2(v.x * CELL + 4, v.y * CELL + 4, CELL - 8, CELL - 8), Color(col, alpha))
		var p: Vector2i = pos + ItemCatalog.shape(id, rot)[0]
		draw_string(RinkOS.PIXEL_FONT, Vector2(p.x * CELL + 6, p.y * CELL + 18), str(ItemCatalog.display_name(id)).substr(0, 6).to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, CELL * 2, 8, Color(RinkOS.ON_ACTION, alpha))

	static func _colour(id: String) -> Color:
		var hues := [RinkOS.ACTION, RinkOS.READOUT, RinkOS.GOOD, Color("c79bf2"), Color("f29b9b"), Color("9bb8f2")]
		return hues[posmod(hash(id), hues.size())]


## The balance game: the circle, the wobbling dot, and how close to going down.
class _BalanceView extends Control:
	var b: IceBalance

	func _draw() -> void:
		if b == null:
			return
		var r := size.x * 0.5
		var c := size * 0.5
		draw_circle(c, r, Color(0, 0, 0, 0.35))
		draw_arc(c, r * IceBalance.CIRCLE_R, 0.0, TAU, 48, RinkOS.GOOD, 2.0)
		draw_arc(c, r, 0.0, TAU, 64, RinkOS.BEZEL, 1.5)
		var col := RinkOS.READOUT.lerp(RinkOS.ALERT, b.danger())
		draw_circle(c + b.pos * r, 7.0, col)
		if b.danger() > 0.0:
			draw_arc(c, r + 6.0, -PI * 0.5, -PI * 0.5 + TAU * b.danger(), 48, RinkOS.ALERT, 4.0)
