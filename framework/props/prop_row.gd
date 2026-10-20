class_name PropRow
extends RefCounted
## One placed thing in a PropField: pure data plus the handles the field
## uses to draw and collide it. Everything a room places, drops or stacks is
## a row; the field decides per frame whether the row is drawn from a
## MultiMesh with a static collider (INSTANCED) or is a rigid body (LIVE).

enum Tier { INSTANCED, LIVE }

## Stable id ("lobby.cup.17"), kept across saves.
var id: StringName
## What it is: a prop id for PropLibrary / Props, or anything the owner likes.
var prop: StringName
## The shared mesh every copy draws.
var mesh: Mesh
## Shape-following boxes in the prop's own space (metres).
var boxes: Array[AABB] = []
## Where it is. The field writes this back when a live body settles.
var xf := Transform3D.IDENTITY
var mass := 1.0
## Free-form state the game keeps ("open", "on", "contents"...).
var state := {}
## Anything the owner wants to hang on the row (an object record, a verb list).
var user: Variant = null

var tier := Tier.INSTANCED
# field handles
var batch: RefCounted = null  # PropField._Batch
var slot := -1
var body := RID()  # the static body while INSTANCED
var node: RigidBody3D = null  # the body while LIVE
var cell := Vector3i.ZERO


func position() -> Vector3:
	return node.global_position if node else xf.origin


## Bounds in world space from the shape boxes (or a small box when none).
func world_aabb() -> AABB:
	var t := node.global_transform if node else xf
	if boxes.is_empty():
		return AABB(t.origin - Vector3(0.05, 0.05, 0.05), Vector3(0.1, 0.1, 0.1))
	var out := t * boxes[0]
	for i in range(1, boxes.size()):
		out = out.merge(t * boxes[i])
	return out


func to_dict() -> Dictionary:
	var t := node.global_transform if node else xf
	return {
		"id": String(id),
		"prop": String(prop),
		"xf":
		[
			t.basis.x.x,
			t.basis.x.y,
			t.basis.x.z,
			t.basis.y.x,
			t.basis.y.y,
			t.basis.y.z,
			t.basis.z.x,
			t.basis.z.y,
			t.basis.z.z,
			t.origin.x,
			t.origin.y,
			t.origin.z
		],
		"state": state.duplicate(true),
	}


static func xf_from(a: Array) -> Transform3D:
	if a.size() != 12:
		return Transform3D.IDENTITY
	return Transform3D(
		Basis(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8])),
		Vector3(a[9], a[10], a[11])
	)
