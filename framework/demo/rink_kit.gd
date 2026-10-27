class_name RinkKit
extends RefCounted
## The rink kit in a scene: dasher board sections and glass panels from
## tools/propgen/rink_kit.py (art/props/board_*.vox, glass_*.vox and their
## manifests). `board(id)` is a section's voxels with a box collider over
## it; `glass(id)` is a panel's frame voxels with the pane the manifest
## declares (`pane`) drawn see-through, and one collider over the lot.
## Both stand on their bottom centre with the ice side facing -Z, like
## every prop. `ids(kind)` lists the kit's boards or glass.

const GLASS_TINT := Color(0.8, 0.9, 0.96, 0.2)


## The kit's ids of one kind: "board" or "glass".
static func ids(kind: String) -> Array:
	var out := []
	for id in ObjectCatalog.ids():
		var rec := ObjectCatalog.info(id)
		if (kind == "board" and rec.has("board")) or (kind == "glass" and rec.has("pane")):
			out.append(id)
	return out


## A board section: `length_m()` of white panel, its kick plate and cap.
static func board(id: String) -> StaticBody3D:
	var rec := ObjectCatalog.info(id)
	var b := _body(id, rec)
	var spec: Dictionary = rec.get("board", {})
	var size: Array = rec.get("size_m", [1.0, 1.1, 0.12])
	_collider(
		b,
		Vector3(float(spec.get("length_m", size[0])), float(size[1]), float(size[2])),
		Vector3(0.0, float(size[1]) / 2, 0.0)
	)
	return b


## A glass panel: the frame's voxels and the pane between its posts.
static func glass(id: String) -> StaticBody3D:
	var rec := ObjectCatalog.info(id)
	var b := _body(id, rec)
	var pane: Dictionary = rec.get("pane", {})
	var ps: Array = pane.get("size_m", [1.12, 1.77, 0.012])
	var at: Array = pane.get("at", [0.0, 0.06, 0.0])
	var mi := MeshInstance3D.new()
	mi.name = "Pane"
	var bm := BoxMesh.new()
	bm.size = Vector3(float(ps[0]), float(ps[1]), float(ps[2]))
	mi.mesh = bm
	mi.position = Vector3(float(at[0]), float(at[1]) + float(ps[1]) / 2, float(at[2]))
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = GLASS_TINT
	mat.roughness = 0.05
	mat.metallic = 0.1
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	b.add_child(mi)
	var size: Array = rec.get("size_m", [1.22, 1.83, 0.08])
	_collider(
		b,
		Vector3(float(size[0]), float(size[1]), float(size[2])),
		Vector3(0.0, float(size[1]) / 2, 0.0)
	)
	return b


## The piece's length along its face, metres (a curved section's chord).
static func length_m(id: String) -> float:
	var rec := ObjectCatalog.info(id)
	var spec: Dictionary = rec.get("board", {})
	var size: Array = rec.get("size_m", [1.0, 1.0, 1.0])
	return float(spec.get("length_m", size[0]))


static func _body(id: String, rec: Dictionary) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = str(rec.get("id", id)).to_pascal_case()
	b.collision_layer = Layers.bit(Layers.VENUE)
	b.collision_mask = 0
	var mi := MeshInstance3D.new()
	mi.name = "Voxels"
	mi.mesh = ObjectCatalog.mesh(id)
	mi.material_override = PropMaterial.shared()
	b.add_child(mi)
	return b


static func _collider(b: StaticBody3D, size: Vector3, at: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = at
	b.add_child(cs)


## A glass panel's width, metres (the 4 ft the kit is made in).
static func glass_w() -> float:
	var rec := ObjectCatalog.info("glass_4x6")
	var size: Array = rec.get("size_m", [1.2192, 1.83, 0.08])
	return float(size[0])
