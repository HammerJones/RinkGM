extends Node
## Scales the 2D UI by whole steps so RINK-OS's pixel fonts and frames stay
## sharp at any window size: 1x up to 2559 wide, 2x at 2560x1440, 3x at 4K.
## The layout area is the window divided by that step, never smaller than
## the 1280x720 every screen is built to fit. 3D renders at full resolution
## regardless (stretch mode canvas_items). Godot's own "integer" scale mode
## letterboxes instead of filling, hence this.

const BASE := Vector2i(1280, 720)

var step := 1


func _ready() -> void:
	get_window().size_changed.connect(_fit)
	_fit()


func _fit() -> void:
	var win := get_window()
	var size := win.size
	step = maxi(1, mini(size.x / BASE.x, size.y / BASE.y))
	win.content_scale_size = size / step
