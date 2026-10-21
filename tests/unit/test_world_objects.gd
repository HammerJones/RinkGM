class_name TestWorldObjects
extends GdUnitTestSuite
## gdUnit4 suite for the object layer: the catalog over data/props/, and
## WorldObjects' names, verbs, state and save format on a field in a
## scene. The end-to-end run (carrying, picking) is the objects demo's
## `--test=objects` mode.


func test_catalog_has_every_manifest_with_known_verbs() -> void:
	var ids := ObjectCatalog.ids()
	assert_int(ids.size()).is_greater_equal(12)
	for id in ids:
		var rec := ObjectCatalog.info(id)
		(
			assert_str(rec.get("name", ""))
			. override_failure_message("%s has a name" % id)
			. is_not_empty()
		)
		for v in ObjectCatalog.verbs(id):
			(
				assert_bool(ObjectCatalog.VERBS_KNOWN.has(v))
				. override_failure_message("%s: verb %s is known" % [id, v])
				. is_true()
			)
		assert_float(ObjectCatalog.mass(id)).is_greater(0.0)


func test_catalog_item_only_for_takeable_props() -> void:
	assert_bool(ObjectCatalog.item("coffee_mug").is_empty()).is_false()
	assert_str(ObjectCatalog.item("coffee_mug").name).is_equal("Coffee mug")
	assert_bool(ObjectCatalog.item("microwave").is_empty()).is_true()


func test_catalog_meshes_and_boxes_load() -> void:
	var mesh := ObjectCatalog.mesh("coffee_mug")
	assert_object(mesh).is_not_null()
	assert_int(mesh.get_surface_count()).is_equal(1)
	assert_int(ObjectCatalog.boxes("coffee_mug").size()).is_greater(0)
	assert_int(ObjectCatalog.mesh_lod("coffee_mug").get_surface_count()).is_equal(1)


func test_objects_names_verbs_state_and_save() -> void:
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	var field := PropField.new()
	root.add_child(field)
	var objects := WorldObjects.new()
	objects.field = field
	root.add_child(objects)
	var mug := objects.spawn("coffee_mug", Transform3D(Basis.IDENTITY, Vector3(1, 0, 2)))
	var micro := objects.spawn("microwave", Transform3D(Basis.IDENTITY, Vector3(3, 0, 2)))
	assert_str(String(mug.id)).is_equal("coffee_mug.1")
	assert_str(objects.name_of(mug)).is_equal("Coffee mug")
	assert_bool(objects.verbs_of(mug).has("take")).is_true()
	assert_bool(objects.verbs_of(micro).has("open")).is_true()
	assert_bool(objects.can(micro, "take")).is_false()
	# open toggles the verb offered
	assert_bool(objects.act("open", micro)).is_true()
	assert_bool(objects.verbs_of(micro).has("close")).is_true()
	assert_bool(objects.verbs_of(micro).has("open")).is_false()
	# a verb the thing lacks does nothing
	assert_object(objects.act("take", micro)).is_null()
	# save keeps only changed rows; take records a removal
	var save := objects.to_save()
	assert_int(save.rows.size()).is_equal(1)
	var item: Dictionary = objects.act("take", mug)
	assert_str(item.prop).is_equal("coffee_mug")
	assert_int(objects.count()).is_equal(1)
	save = objects.to_save()
	assert_bool(save.removed.has("coffee_mug.1")).is_true()
	# load spawns the mug back from a drop record and keeps the state
	objects.act(
		"drop", null, null, {"item": item, "xf": Transform3D(Basis.IDENTITY, Vector3(0, 1, 0))}
	)
	assert_object(objects.get_row("coffee_mug.1")).is_not_null()
	assert_bool(objects.get_state(micro, "open")).is_true()
	root.remove_child(field)
	field.free()
