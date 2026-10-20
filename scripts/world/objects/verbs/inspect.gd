extends RefCounted
## inspect: a close look and the manifest's `inspect` line, shown the way
## a note is read. Marks the row read.


static func run(ctx: ObjectContext, row: WorldObject) -> Dictionary:
	var rec := PropLibrary.info(row.prop)
	var text := str(rec.get("inspect", ""))
	if text == "":
		text = "%s. Nothing more to it." % row.name()
	if ctx.objects:
		ctx.objects.set_state(row.id, "read", true)
	return {"read": {"title": row.name(), "text": text}}
