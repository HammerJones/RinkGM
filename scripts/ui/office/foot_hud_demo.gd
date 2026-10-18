extends Node
## The on-foot clock over the venue walk-around, driven by a demo M1 sim that
## advances 15 minutes every two real seconds. For checking the HUD in place:
##   godot --path . res://scenes/ui/foot_hud_demo.tscn [-- --screenshot=out.png]

var sim: RinkSim
var hud: FootHud
var _t := 0.0


func _ready() -> void:
	add_child(load("res://scenes/venue/venue_walk.tscn").instantiate())
	sim = OfficeData.demo_sim(2, 5 * 60 + 40)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var anchor := MarginContainer.new()
	anchor.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	anchor.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	anchor.add_theme_constant_override("margin_top", 16)
	anchor.add_theme_constant_override("margin_right", 16)
	layer.add_child(anchor)
	hud = FootHud.new()
	anchor.add_child(hud)
	hud.show_sim(sim)
	RinkOS.capture_from_args(self)


func _process(delta: float) -> void:
	_t += delta
	if _t >= 2.0:
		_t = 0.0
		sim.advance(OfficeData.CELL_MIN)
		hud.show_sim(sim)
