class_name ObjectField
extends Node3D
## Draws the loose rows that have no node (a dropped cup that settled and
## was demoted) as one merged mesh, the way StickField draws resting
## sticks: one draw for the whole venue, rebuilt only when a row is
## promoted, demoted, placed or taken.

var objects: WorldObjects
var _mi: MeshInstance3D
var _dirty := true


func _ready() -> void:
	_mi = MeshInstance3D.new()
	_mi.name = "Resting"
	_mi.cast_shadow = Look.cast()
	_mi.visibility_range_end = StickField.DRAW_RANGE
	add_child(_mi)
	if objects:
		objects.changed.connect(func(_w: WorldObject) -> void: _dirty = true)


func mark_dirty() -> void:
	_dirty = true


func _process(_dt: float) -> void:
	if _dirty:
		_rebuild()


func _rebuild() -> void:
	_dirty = false
	var meshes: Array[ArrayMesh] = []
	var xfs: Array[Transform3D] = []
	if objects:
		for w in objects.rows.values():
			if w.loose() and not w.held() and w.tier != WorldObject.LIVE:
				var m := PropLibrary.mesh(w.prop, w.age)
				if m:
					meshes.append(m)
					xfs.append(w.xf)
	_mi.mesh = StickField.merge(meshes, xfs)


func count() -> int:
	var n := 0
	if objects:
		for w in objects.rows.values():
			if w.loose() and not w.held() and w.tier != WorldObject.LIVE:
				n += 1
	return n
