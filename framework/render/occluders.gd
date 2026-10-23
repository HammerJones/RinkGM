class_name Occluders
extends RefCounted
## Occlusion culling helpers. Godot culls what is hidden behind an
## OccluderInstance3D; the editor can bake those from a scene, but a room
## built from code (every VenueKit room, the demo) wants them at runtime.
## `from_boxes` turns a room's walls, floors and counters into one
## occluder node: anything fully behind them is skipped by the renderer.
##
##   Occluders.from_boxes(room, [AABB(...), AABB(...)])
##
## Occlusion culling itself is the project setting
## rendering/occlusion_culling/use_occlusion_culling (on).


## One OccluderInstance3D under `parent` covering every box (in the
## parent's space). Boxes are shrunk by `inset` so a wall never occludes
## the thing standing against it.
static func from_boxes(parent: Node3D, boxes: Array, inset := 0.02) -> OccluderInstance3D:
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	for b in boxes:
		var box: AABB = b
		var lo := box.position + Vector3.ONE * inset
		var hi := box.end - Vector3.ONE * inset
		if hi.x <= lo.x or hi.y <= lo.y or hi.z <= lo.z:
			continue
		var base := verts.size()
		for corner in [
			Vector3(lo.x, lo.y, lo.z),
			Vector3(hi.x, lo.y, lo.z),
			Vector3(hi.x, hi.y, lo.z),
			Vector3(lo.x, hi.y, lo.z),
			Vector3(lo.x, lo.y, hi.z),
			Vector3(hi.x, lo.y, hi.z),
			Vector3(hi.x, hi.y, hi.z),
			Vector3(lo.x, hi.y, hi.z),
		]:
			verts.append(corner)
		# twelve triangles, outward winding does not matter for occluders
		for tri in [
			[0, 1, 2],
			[0, 2, 3],
			[4, 6, 5],
			[4, 7, 6],
			[0, 4, 5],
			[0, 5, 1],
			[1, 5, 6],
			[1, 6, 2],
			[2, 6, 7],
			[2, 7, 3],
			[3, 7, 4],
			[3, 4, 0],
		]:
			for i in tri:
				indices.append(base + i)
	var occ := ArrayOccluder3D.new()
	occ.set_arrays(verts, indices)
	var node := OccluderInstance3D.new()
	node.name = "Occluders"
	node.occluder = occ
	parent.add_child(node)
	return node
