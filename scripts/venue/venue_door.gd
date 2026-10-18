class_name VenueDoor
extends Node3D
## A door in a venue wall: a swinging single or double leaf, or a roll-up
## garage door. The origin is the bottom centre of the opening; the leaf spans
## local X and the wall's thickness runs along local Z. Leaves carry their own
## colliders (venue physics layer) so a walker is blocked until it opens.

enum Kind { SWING, DOUBLE, ROLLUP }

signal toggled(is_open: bool)

var kind := Kind.SWING
var width := 1.0
var height := 2.2
var color := Color("6f4b2e")
var label := ""
var is_open := false
var leaves: Array[Node3D] = []
var _tween: Tween


static func make(kind_: int, width_: float, height_: float, color_: Color, label_ := "") -> VenueDoor:
	var d := VenueDoor.new()
	d.kind = kind_
	d.width = width_
	d.height = height_
	d.color = color_
	d.label = label_
	return d


func _ready() -> void:
	match kind:
		Kind.SWING:
			_leaf(-width * 0.5, width, 1.0)
		Kind.DOUBLE:
			_leaf(-width * 0.5, width * 0.5, 1.0)
			_leaf(width * 0.5, width * 0.5, -1.0)
		Kind.ROLLUP:
			_leaf(0.0, width, 0.0)


## A leaf hinged at local x `hinge_x`, extending `w` toward +X (dir 1) or -X
## (dir -1). dir 0 is a roll-up door centred on the opening.
func _leaf(hinge_x: float, w: float, dir: float) -> void:
	var pivot := Node3D.new()
	pivot.position.x = hinge_x
	add_child(pivot)
	leaves.append(pivot)
	var b := VoxelMeshBuilder.new()
	var t := 0.06
	var x0 := 0.0 if dir >= 0.0 else -w
	if dir == 0.0:
		x0 = -w * 0.5
	var slats := 8 if kind == Kind.ROLLUP else 1
	for i in slats:
		var y0 := height * i / slats
		var y1 := height * (i + 1) / slats
		var c := VoxelMeshBuilder.jitter_color(color, Vector2i(i, int(hinge_x * 10)), 0.05)
		b.add_box(Transform3D(Basis.from_scale(Vector3(w - 0.02, y1 - y0 - 0.01, t)), Vector3(x0 + w * 0.5, (y0 + y1) * 0.5, 0)), c)
	if kind != Kind.ROLLUP:
		# kick plate and push bar
		b.add_box(Transform3D(Basis.from_scale(Vector3(w - 0.06, 0.25, t + 0.01)), Vector3(x0 + w * 0.5, 0.15, 0)), Color("8c8f94"))
		var hx := x0 + (w - 0.12 if dir >= 0.0 else 0.12)
		b.add_box(Transform3D(Basis.from_scale(Vector3(0.05, 0.05, t + 0.08)), Vector3(hx, 1.05, 0)), Color("c9ccd1"))
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(mi)
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false  # follow the swinging pivot every frame
	body.collision_layer = 1 << (VenueKit.VENUE_LAYER - 1)
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, height, t)
	cs.shape = shape
	cs.position = Vector3(x0 + w * 0.5, height * 0.5, 0)
	body.add_child(cs)
	pivot.add_child(body)
	pivot.set_meta("dir", dir)


func open() -> void:
	_set_open(true)


func close() -> void:
	_set_open(false)


func toggle() -> void:
	_set_open(not is_open)


## Where a walker stands to use the door, on the side facing local +Z.
func use_point() -> Vector3:
	return global_transform * Vector3(0, 0, 0.9)


func _set_open(v: bool) -> void:
	if v == is_open:
		return
	is_open = v
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	for pivot in leaves:
		var dir: float = pivot.get_meta("dir")
		if dir == 0.0:
			_tween.tween_property(pivot, "position:y", height - 0.25 if v else 0.0, 1.6)
		else:
			_tween.tween_property(pivot, "rotation:y", (-dir * deg_to_rad(95.0)) if v else 0.0, 0.45)
	toggled.emit(v)
