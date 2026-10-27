extends Control
## The UI lab: every RINK-OS screen on a busy demo rink, at the window sizes
## players will have, so styling and layout can be checked in seconds
## without playing into a career. The window scales the UI by whole steps
## (project stretch: canvas_items, integer), so 2560x1440 shows the
## 1280x720 layout drawn at 2x, and the pixel fonts stay sharp.
##
##   F1-F4   window 1280x720, 1600x900, 1920x1080, 2560x1440
##   F5/F6   next/previous screen
##   `-- --screen=office:cal|office:grid|...|showcase` opens one;
##   `-- --size=1920x1080` sets the window; `-- --screenshot=x.png` saves a frame;
##   `-- --arm=<job id>` opens the calendar holding that job, ready to hand out.

const SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const OFFICE := preload("res://scenes/ui/rink_office.tscn")
const SHOWCASE := "res://scenes/ui/rinkos_showcase.tscn"

var screens: Array = []  ## "office:<tab>" for each office tab, then "showcase"
var at := 0
var sim: RinkSim
var _screen: Node
var _info: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for t in load("res://scripts/ui/office/rink_office.gd").TABS:
		screens.append("office:" + t[0])
	screens.append("showcase")
	sim = OfficeData.demo_sim(3, 14 * 60, 7, true)
	_sample_orders()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screen="):
			at = maxi(screens.find(a.trim_prefix("--screen=")), 0)
		elif a.begins_with("--size="):
			var wh := a.trim_prefix("--size=").split("x")
			_resize(Vector2i(int(wh[0]), int(wh[1])))
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_info = RinkOS.label("", RinkOS.TERM_DIM)
	_info.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_info.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_info.position -= Vector2(12, 4)
	layer.add_child(_info)
	get_window().size_changed.connect(_show_info)
	_open()


## A few jobs already handed out, so the calendar has some on it.
func _sample_orders() -> void:
	var cast := Cast.load_region(1)
	var plan := [["nicole_kerr", "ice_check", 1, 7 * 60], ["shawn_kuzyk", "clean_building", 0, 15 * 60],
		["andre_clarke", "compressor_oil_change", 1, 8 * 60], ["maria_dunlop", "dump_snow", 0, 19 * 60]]
	for x in plan:
		for p: Person in cast.people.values():
			if p.name.to_lower().replace(" ", "_").replace("é", "e") == x[0]:
				WorkOrders.assign(sim, p, x[1], sim.day + x[2], x[3], {"compressor": 0})


func _open() -> void:
	if _screen:
		_screen.queue_free()
	var s: String = screens[at]
	if s.begins_with("office:"):
		var o := OFFICE.instantiate()
		o.sim = sim
		o.tab = s.trim_prefix("office:")
		_screen = o
	else:
		_screen = load(SHOWCASE).instantiate()
	add_child(_screen)
	move_child(_screen, 0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--arm=") and s == "office:cal":
			_screen._cal_cursor = Vector2i(3, 24)  # André's lane, 11:00
			_screen._cal_arm(a.trim_prefix("--arm="), {"compressor": 1})
	_show_info()


func _show_info() -> void:
	if _info == null:
		return
	var win := get_window().size
	var vis := get_viewport().get_visible_rect().size
	_info.text = "UI LAB // %s // %dx%d @%dx // F1-F4 SIZE  F5 NEXT" % [screens[at].to_upper(), win.x, win.y, roundi(float(win.x) / vis.x)]


func _resize(s: Vector2i) -> void:
	get_window().size = s
	get_window().move_to_center()


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	match e.keycode:
		KEY_F1, KEY_F2, KEY_F3, KEY_F4:
			_resize(SIZES[e.keycode - KEY_F1])
		KEY_F5:
			at = (at + 1) % screens.size()
			_open()
		KEY_F6:
			at = posmod(at - 1, screens.size())
			_open()
		_:
			return
	get_viewport().set_input_as_handled()
