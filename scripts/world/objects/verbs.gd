class_name ObjectVerbs
extends RefCounted
## The verbs a world object can name (docs/WORLD_OBJECTS.md 2.3) and the
## ones built so far. A manifest may list any KNOWN verb; the prompt only
## offers the IMPLEMENTED ones. Each verb's code is a script under
## scripts/world/objects/verbs/ with `static func run(ctx: ObjectContext,
## row: WorldObject) -> Dictionary`; it reads and writes the row's state and
## returns {"toast": ..., "read": {...}} for the walk to show. Verbs never
## reach into the room or the walk scene: everything they need is on `ctx`.

const KNOWN := ["inspect", "read", "take", "drop", "place", "open", "close", "contain", "switch", "sit", "push", "use"]

const IMPLEMENTED := {
	"inspect": preload("res://scripts/world/objects/verbs/inspect.gd"),
	"take": preload("res://scripts/world/objects/verbs/take.gd"),
	"drop": preload("res://scripts/world/objects/verbs/drop.gd"),
}

## What the prompt says for each verb.
const LABELS := {"inspect": "INSPECT", "read": "READ", "take": "TAKE", "drop": "DROP", "place": "PLACE",
	"open": "OPEN", "close": "CLOSE", "contain": "LOOK IN", "switch": "SWITCH", "sit": "SIT", "push": "PUSH", "use": "USE"}


static func known(verb: String) -> bool:
	return KNOWN.has(verb)


static func implemented(verb: String) -> bool:
	return IMPLEMENTED.has(verb)


## The verb E does on `row` when looked at: the first implemented verb the
## prop names, in the manifest's order (so "take" before "inspect" on a cup
## that lists take first). "" when nothing applies.
static func primary(row: WorldObject) -> String:
	for v in PropLibrary.verbs(row.prop):
		if implemented(str(v)) and str(v) != "drop":
			return str(v)
	return ""


static func label(verb: String) -> String:
	return LABELS.get(verb, verb.to_upper())


static func run(verb: String, ctx: ObjectContext, row: WorldObject) -> Dictionary:
	if not implemented(verb):
		return {"toast": "NOTHING TO %s HERE." % label(verb)}
	return IMPLEMENTED[verb].run(ctx, row)
