class_name OnIceDraw
extends RefCounted
## Draws IceSkaters with PeopleArt: one MultiMesh per body, head and
## held-item layer (PeopleArt.layer_keys), the same way RinkPeople draws the
## stands, so a slammed public skate is a few dozen draws.
##
##   var draw := OnIceDraw.new(self)   # parent Node3D in venue space
##   draw.mark_dirty()                 # after the roster changes
##   draw.draw(skaters)                # every frame

var _parent: Node3D
var _mm := {}         # layer key -> MultiMeshInstance3D
var _dirty := true
var _prefix := "OnIce"


func _init(parent: Node3D, prefix := "OnIce") -> void:
	_parent = parent
	_prefix = prefix


func mark_dirty() -> void:
	_dirty = true


func draw(list: Array) -> void:
	if _parent == null or not is_instance_valid(_parent) or not _parent.is_inside_tree():
		return
	if _dirty:
		_rebuild(list)
	var filled := {}
	var hide_xf := Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(0, -50, 0))
	for s: IceSkater in list:
		var xf := Transform3D(Basis(Vector3.UP, s.yaw), s.pos3())
		if s.hidden:
			xf = hide_xf
		var spd := s.vel.length()
		var data := PeopleArt.instance_data(s.look, s.pose, s.phase, s.age, spd > 0.25, spd)
		for key in s.keys:
			if not _mm.has(key):
				continue
			var mm: MultiMesh = _mm[key].multimesh
			var i := int(filled.get(key, 0))
			if i >= mm.instance_count:
				continue
			filled[key] = i + 1
			mm.set_instance_transform(i, xf)
			mm.set_instance_custom_data(i, data)
	# unused instances (someone left since the rebuild) go out of sight
	for key in _mm:
		var mm2: MultiMesh = _mm[key].multimesh
		for i in range(int(filled.get(key, 0)), mm2.instance_count):
			mm2.set_instance_transform(i, hide_xf)


func _rebuild(list: Array) -> void:
	_dirty = false
	var counts := {}
	for s: IceSkater in list:
		s.keys = PeopleArt.layer_keys(s.look, s.age)
		for key in s.keys:
			counts[key] = int(counts.get(key, 0)) + 1
	for key in _mm.keys():
		if not counts.has(key):
			_mm[key].queue_free()
			_mm.erase(key)
	for key in counts:
		if not _mm.has(key):
			var mmi := MultiMeshInstance3D.new()
			mmi.name = _prefix + "_" + str(key).validate_node_name()
			mmi.cast_shadow = Look.cast()
			mmi.multimesh = PeopleArt.multimesh(key, counts[key])
			_parent.add_child(mmi)
			_mm[key] = mmi
		var m: MultiMesh = _mm[key].multimesh
		if m.instance_count != counts[key]:
			m.instance_count = counts[key]


func clear() -> void:
	for key in _mm:
		if is_instance_valid(_mm[key]):
			_mm[key].queue_free()
	_mm.clear()
