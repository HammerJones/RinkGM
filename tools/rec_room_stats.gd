extends SceneTree
## Prints draws, triangles and colliders per recreation-wing room at each
## age, and the venue's totals: the wing's detail budget at a glance.
##   godot --headless --path . --script res://tools/rec_room_stats.gd


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var root3d := Node3D.new()
	root.add_child(root3d)
	var venue := Venue.instantiate_for(Career.exhibition(0), true)
	root3d.add_child(venue)
	for age in 3:
		venue.set_all_ages(age)
		print("== %s total %s" % [VenueRoom.AGE_NAMES[age], venue.stats()])
		for id in RecPlan.ROOMS:
			var st := room_stats(venue.rooms[id])
			print("  %-16s draws %3d  tris %7d  colliders %4d" % [id, st.draws, st.triangles, st.colliders])
	quit(0)


## Draws (a sign counts its labels), triangles and collision shapes under one room.
static func room_stats(room: Node) -> Dictionary:
	var d := {"draws": 0, "triangles": 0, "colliders": 0}
	var stack: Array = [room]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is VenueSign:
			d.draws += n.get_child_count()
			continue
		stack.append_array(n.get_children())
		if n is MeshInstance3D and n.mesh:
			d.draws += 1
			d.triangles += Venue._tris(n.mesh)
		elif n is MultiMeshInstance3D and n.multimesh and n.multimesh.mesh:
			d.draws += 1
			d.triangles += Venue._tris(n.multimesh.mesh) * n.multimesh.instance_count
		elif n is CollisionShape3D:
			d.colliders += 1
	return d
