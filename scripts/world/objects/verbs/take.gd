extends RefCounted
## take: the row leaves the world for the bag (InventoryGrid, with the
## item's shape from the manifest through ItemCatalog). The row keeps its
## id and state while held, so a dropped thing is the same thing.


static func run(ctx: ObjectContext, row: WorldObject) -> Dictionary:
	if not PropLibrary.has_verb(row.prop, "take"):
		return {"toast": "YOU CAN'T TAKE THE %s." % row.name().to_upper()}
	if ctx.bag == null:
		return {"toast": "NO BAG."}
	if ctx.bag.add(String(row.prop)) < 0:
		return {"toast": "NO ROOM IN THE BAG FOR THE %s." % row.name().to_upper()}
	ctx.objects.take(row.id)
	ctx.notify_bag()
	return {"toast": "TAKEN: %s." % row.name().to_upper()}
