extends WorldChunk
## A chunk for the framework's world test and the streaming fixtures:
## three mugs on its floor, laid out through the registry.


func populate(objects: WorldObjects) -> void:
	for i in 3:
		var id := "%s.mug.%d" % [chunk_id, i]
		if objects.get_row(id):
			continue  # a saved row already put it (or took it) here
		var at := bounds.position + Vector3(2.0 + i * 1.5, 0.0, 2.0)
		objects.spawn("coffee_mug", Transform3D(Basis.IDENTITY, at), id, field)
