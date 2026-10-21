class_name WorldObjects
extends Node
## Every placed thing as an object: a PropRow in a PropField with a name,
## verbs and state, and the verbs that act on it. This is the layer between
## the physics rows and the game: the prompt asks it what a row is called
## and what can be done, the interactor asks it to do the verb, a save asks
## it which rows changed.
##
##   var objects := WorldObjects.new()
##   objects.field = field                       # where rows live (one per room or chunk)
##   var row := objects.spawn("coffee_mug", xf)  # a row from the catalog, named "coffee_mug.1"
##   objects.name_of(row)                        # "Coffee mug"
##   objects.verbs_of(row)                       # ["take", "inspect", "push"]
##   var r := objects.act("take", row, actor)    # -> the inventory item; the row is gone
##   objects.act("drop", null, actor, {"item": r, "xf": xf, "velocity": v})
##   objects.to_save() / objects.from_save(d)    # rows the game placed, moved, took or changed
##
## Verbs built in: inspect (returns the text), push (wakes the row and
## shoves it), take (removes the row, returns the item), drop (spawns the
## item back, live, with a velocity), open / close (state "open"), use
## (state "on" toggles; `used` is emitted for the game to react). A game
## can register more with `add_verb`.

signal spawned(row: PropRow)
signal removed(row: PropRow)
signal acted(verb: String, row: PropRow, result: Variant)
signal inspected(row: PropRow, text: String)
signal used(row: PropRow, actor: Variant)
signal state_changed(row: PropRow, key: String, value: Variant)

## Where spawned rows go when a call names no field.
var field: PropField
## Every field this registry spawns into (for lookups by hit).
var fields: Array[PropField] = []
## Rows by id, across fields.
var rows := {}

var _counts := {}  # prop -> next number for an auto id
var _removed := {}  # ids of rows a save must forget (placed by a room, then taken)
var _verbs := {}  # verb -> Callable(row, actor, args) -> Variant


func _ready() -> void:
	if field and not fields.has(field):
		fields.append(field)
	_verbs["inspect"] = _verb_inspect
	_verbs["push"] = _verb_push
	_verbs["take"] = _verb_take
	_verbs["drop"] = _verb_drop
	_verbs["open"] = _verb_open
	_verbs["close"] = _verb_close
	_verbs["use"] = _verb_use


func add_field(f: PropField) -> void:
	if not fields.has(f):
		fields.append(f)
	if field == null:
		field = f


# --- rows ----------------------------------------------------------------


## A row of `prop` at `xf` (the field's space), from the catalog. `id`
## defaults to "<prop>.<n>"; `placed` marks it as the game's (saved) rather
## than a room's layout.
func spawn(
	prop: String, xf: Transform3D, id := "", into: PropField = null, state := {}, placed := false
) -> PropRow:
	var f := into if into else field
	if f == null:
		push_error("WorldObjects: no field to spawn into")
		return null
	if not fields.has(f):
		fields.append(f)
	var rid := id
	if rid == "":
		var n: int = _counts.get(prop, 0) + 1
		_counts[prop] = n
		rid = "%s.%d" % [prop, n]
		while rows.has(rid):
			n += 1
			_counts[prop] = n
			rid = "%s.%d" % [prop, n]
	var row := f.add(
		StringName(rid),
		StringName(prop),
		ObjectCatalog.mesh(prop),
		ObjectCatalog.boxes(prop),
		xf,
		ObjectCatalog.mass(prop)
	)
	row.state = state.duplicate(true)
	row.dirty = placed
	row.user = self
	rows[rid] = row
	_removed.erase(rid)
	spawned.emit(row)
	return row


func remove(row: PropRow) -> void:
	if row == null:
		return
	rows.erase(String(row.id))
	_removed[String(row.id)] = true
	removed.emit(row)
	_field_of(row).remove(row)


func get_row(id: String) -> PropRow:
	return rows.get(id)


## The row a physics ray hit, across every field.
func row_of(hit: Dictionary) -> PropRow:
	for f in fields:
		var r := f.row_of(hit)
		if r:
			return r
	return null


func count() -> int:
	return rows.size()


# --- names, verbs, state ---------------------------------------------------


func name_of(row: PropRow) -> String:
	return ObjectCatalog.display_name(String(row.prop))


## The verbs that apply now: a thing that is open offers close, not open.
func verbs_of(row: PropRow) -> Array:
	var out: Array = []
	for v in ObjectCatalog.verbs(String(row.prop)):
		if v == "open" and row.state.get("open", false):
			out.append("close")
		else:
			out.append(v)
	return out


func can(row: PropRow, verb: String) -> bool:
	return verbs_of(row).has(verb)


func get_state(row: PropRow, key: String, default: Variant = null) -> Variant:
	return row.state.get(key, default)


func set_state(row: PropRow, key: String, value: Variant) -> void:
	row.state[key] = value
	row.dirty = true
	state_changed.emit(row, key, value)


## Does `verb` to `row` for `actor` (anything: the walker, an NPC, null).
## Returns what the verb returns (inspect: the text; take: the item).
func act(verb: String, row: PropRow, actor: Variant = null, args := {}) -> Variant:
	if not _verbs.has(verb):
		push_error("WorldObjects: unknown verb %s" % verb)
		return null
	if row != null and verb != "drop" and not can(row, verb):
		return null
	var result: Variant = _verbs[verb].call(row, actor, args)
	acted.emit(verb, row, result)
	return result


## Registers a verb: `fn(row, actor, args) -> Variant`.
func add_verb(verb: String, fn: Callable) -> void:
	_verbs[verb] = fn


# --- the built-in verbs ----------------------------------------------------


func _verb_inspect(row: PropRow, _actor: Variant, _args: Dictionary) -> Variant:
	var text := ObjectCatalog.inspect_text(String(row.prop))
	if text == "":
		text = name_of(row) + "."
	inspected.emit(row, text)
	return text


## A shove: the row wakes and takes an impulse (`args.impulse`, a Vector3,
## default a nudge away from the actor).
func _verb_push(row: PropRow, actor: Variant, args: Dictionary) -> Variant:
	var f := _field_of(row)
	var body := f.wake(row)
	if body == null:
		return false
	var imp: Vector3 = args.get("impulse", Vector3.ZERO)
	if imp == Vector3.ZERO:
		var from: Vector3 = (
			actor.global_position if actor is Node3D else body.global_position - Vector3.FORWARD
		)
		var dir := body.global_position - from
		dir.y = 0.0
		imp = (dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD) * 1.5 * body.mass
	body.apply_central_impulse(imp)
	row.dirty = true
	return true


## Takes the row out of the world; returns the inventory item (with the
## row's state, so a dropped thing is the thing that was taken).
func _verb_take(row: PropRow, _actor: Variant, _args: Dictionary) -> Variant:
	var item := ObjectCatalog.item(String(row.prop))
	if item.is_empty():
		return null
	item["id"] = String(row.id)
	item["state"] = row.state.duplicate(true)
	remove(row)
	return item


## Puts an item back as a live row at `args.xf` with `args.velocity`.
func _verb_drop(_row: PropRow, _actor: Variant, args: Dictionary) -> Variant:
	var item: Dictionary = args.get("item", {})
	if item.is_empty():
		return null
	var xf: Transform3D = args.get("xf", Transform3D.IDENTITY)
	var row := spawn(
		str(item.prop), xf, str(item.get("id", "")), args.get("field"), item.get("state", {}), true
	)
	if row == null:
		return null
	var body := _field_of(row).wake(row)
	if body:
		body.linear_velocity = args.get("velocity", Vector3.ZERO)
		body.angular_velocity = args.get("spin", Vector3.ZERO)
	return row


func _verb_open(row: PropRow, _actor: Variant, _args: Dictionary) -> Variant:
	set_state(row, "open", true)
	return true


func _verb_close(row: PropRow, _actor: Variant, _args: Dictionary) -> Variant:
	set_state(row, "open", false)
	return true


func _verb_use(row: PropRow, actor: Variant, _args: Dictionary) -> Variant:
	set_state(row, "on", not row.state.get("on", false))
	used.emit(row, actor)
	return row.state.on


# --- save ----------------------------------------------------------------


## The rows the game changed (placed, moved, taken, state) and the ids it
## removed, so a room laid out from code can be rebuilt and then patched.
func to_save() -> Dictionary:
	var out: Array = []
	for id in rows:
		var row: PropRow = rows[id]
		if row.dirty or row.node != null:
			out.append(row.to_dict())
	var gone := _removed.keys()
	gone.sort()
	return {"rows": out, "removed": gone}


## Applies a save: removes the ids it lists, moves or spawns the rows it
## carries (a row that exists is moved and given the saved state).
func from_save(d: Dictionary) -> void:
	for id in d.get("removed", []):
		var row: PropRow = rows.get(str(id))
		if row:
			remove(row)
		else:
			_removed[str(id)] = true
	for rec in d.get("rows", []):
		var id := str(rec.get("id", ""))
		var xf := PropRow.xf_from(rec.get("xf", []))
		var row: PropRow = rows.get(id)
		if row:
			_field_of(row).move_row(row, xf)
			row.state = rec.get("state", {}).duplicate(true)
			row.dirty = true
		else:
			spawn(str(rec.get("prop", "")), xf, id, null, rec.get("state", {}), true)


func _field_of(row: PropRow) -> PropField:
	for f in fields:
		if f.get_row(row.id) == row:
			return f
	return field
