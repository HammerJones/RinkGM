class_name ObjectWalk
extends Node
## The walk's side of world objects (docs/WORLD_OBJECTS.md 2.2, 2.3):
## names what the look ray crosses (no node per object: the ray's hit
## bounds a segment that WorldObjects.raycast tests against the rows'
## boxes), runs the verbs (E takes or inspects, G drops the last thing
## taken), promotes dropped rows to LiveProp bodies and demotes them back
## to rows when they sleep far away or the LIVE cap is reached, and keeps
## the rows in the owner save (career.world["objects"]).
##
##   venue_walk.gd: objects = ObjectWalk.attach(self)
##   objects.hint()         the [E] line for the object you're looking at
##   objects.use()          E: the primary verb; {} when nothing applied
##   objects.drop_held()    G: drop the last thing taken
##   objects.status()       "LIVE 2/64, 391 rows, 1 loose" (the dev menu)

const REACH := 2.6
const LIVE_CAP := 64
const FAR := StickField.FAR
const CHECK := 0.5
const DROP_TOSS := 1.4

var walk: Node
var venue: Venue
var walker: VenueWalker
var cam: Camera3D
var objects: WorldObjects
var field: ObjectField
var live := {}  # row id -> LiveProp
var _t := 0.0


static func attach(walk_: Node) -> ObjectWalk:
	var ow := ObjectWalk.new()
	ow.name = "WorldObjects"
	ow.walk = walk_
	walk_.add_child(ow)
	return ow


func _ready() -> void:
	venue = walk.get("venue")
	walker = walk.get("walker")
	cam = walk.get("cam")
	objects = venue.objects
	field = ObjectField.new()
	field.name = "ObjectField"
	field.objects = objects
	venue.add_child(field)
	# the owner save keeps the rows the player changed under one key; on
	# the way back in they're merged over what the rooms just baked
	var story: WalkStory = walk.get("story")
	if story and story.link:
		var w: Dictionary = story.link.career.world
		var saved: Variant = w.get("objects")
		if saved is Dictionary:
			objects.load_dict(saved)
		elif saved is WorldObjects and saved != objects:
			objects.load_dict(saved.to_dict())
		w["objects"] = objects  # Career saves it with to_dict()


# ---------------------------------------------------------------- looking

## The row under the look ray within reach: a LIVE body the physics ray
## hits, else the first row box the ray crosses before it hits the room.
func looked() -> WorldObject:
	if cam == null or not cam.is_inside_tree():
		return null
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var to := from + dir * REACH
	var mask := (1 << (VenueKit.VENUE_LAYER - 1)) | (1 << (LiveProp.LAYER - 1))
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	var hit: Dictionary = walk.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		if hit.collider is LiveProp:
			return (hit.collider as LiveProp).row
		to = hit.position + dir * 0.08  # just into the surface it hit
	var vf := venue.global_transform.affine_inverse()
	return objects.raycast(vf * from, vf * to)


## "[E] TAKE  COFFEE CUP", the name alone when no verb applies, "" for nothing.
func hint() -> String:
	var w := looked()
	if w == null:
		return ""
	var v := ObjectVerbs.primary(w)
	if v == "":
		return w.name().to_upper()
	return "[E] %s  %s" % [ObjectVerbs.label(v), w.name().to_upper()]


## "[G] DROP COFFEE CUP" while something taken is in the bag, else "".
func drop_hint() -> String:
	var h := objects.held()
	if h.is_empty():
		return ""
	return "[G] DROP %s" % h.back().name().to_upper()


## E: runs the primary verb on what you're looking at. The result is the
## walk's to show ({"toast": ...} or {"read": ...}); {} when nothing applied.
func use() -> Dictionary:
	var w := looked()
	if w == null:
		return {}
	var v := ObjectVerbs.primary(w)
	if v == "":
		return {}
	return ObjectVerbs.run(v, context(), w)


## G: drops the last thing taken.
func drop_held() -> Dictionary:
	var h := objects.held()
	if h.is_empty():
		return {}
	return ObjectVerbs.run("drop", context(), h.back())


## Runs `verb` on `row` directly (tests, NPC brains).
func act(verb: String, row: WorldObject) -> Dictionary:
	return ObjectVerbs.run(verb, context(), row)


func context() -> ObjectContext:
	var c := ObjectContext.new()
	c.objects = objects
	var kit: KitHud = walk.get("kit")
	c.bag = kit.kit.bag if kit and kit.kit else null
	var f := -cam.global_transform.basis.z if cam else Vector3.FORWARD
	var flat := Vector3(f.x, 0, f.z).normalized() if Vector2(f.x, f.z).length() > 0.01 else Vector3.FORWARD
	var at := cam.global_position + f * 0.45 - Vector3(0, 0.15, 0) if cam else walker.global_position + Vector3(0, 1.2, 0)
	var vf := venue.global_transform.affine_inverse()
	c.drop_pos = vf * at
	c.drop_velocity = vf.basis * (f * DROP_TOSS + walker.velocity)
	c.yaw = walker.rotation.y
	var room := venue.room_at(c.drop_pos)
	c.room = StringName(room.room_id) if room else &""
	c.promote = promote
	c.bag_changed = func() -> void:
		if kit and kit.kit:
			kit.kit.save()
	return c


# ---------------------------------------------------------------- tiers

## Gives a row a rigid body (awake with `velocity`, else asleep). Over the
## cap the farthest sleeping body is demoted first; when every body is
## awake the row stays a row. Returns the node, or null.
func promote(row: WorldObject, velocity := Vector3.ZERO) -> LiveProp:
	if live.has(row.id):
		return live[row.id]
	if live.size() >= LIVE_CAP:
		_demote_farthest()
	if live.size() >= LIVE_CAP:
		return null
	var p := LiveProp.make(row)
	p.asleep = velocity == Vector3.ZERO
	row.tier = WorldObject.LIVE
	row.node = p
	live[row.id] = p
	venue.add_child(p)
	if velocity != Vector3.ZERO:
		p.linear_velocity = velocity
		p.angular_velocity = Vector3(0.6, 0.3, 0.2)
	p.settled.connect(_on_settled)
	field.mark_dirty()
	return p


## The node goes; the row keeps where it came to rest.
func demote(row: WorldObject) -> void:
	var p: LiveProp = live.get(row.id)
	if p == null:
		return
	_record_rest(p)
	live.erase(row.id)
	row.tier = WorldObject.BAKED
	row.node = null
	p.queue_free()
	field.mark_dirty()


func live_count() -> int:
	return live.size()


func status() -> String:
	return "LIVE %d/%d, %d rows, %d loose, %d held" % [live.size(), LIVE_CAP, objects.count(), objects.count_loose(), objects.held().size()]


func _on_settled(p: LiveProp) -> void:
	_record_rest(p)


func _record_rest(p: LiveProp) -> void:
	if p.row == null or not is_instance_valid(p):
		return
	var xf := p.transform
	var room := venue.room_at(xf.origin + Vector3(0, 0.1, 0))
	objects.move(p.row.id, StringName(room.room_id) if room else p.row.room, xf)


func _process(dt: float) -> void:
	_t += dt
	if _t < CHECK:
		return
	_t = 0.0
	_tier()


## Every CHECK seconds: sleeping bodies far from the walker go back to rows;
## loose rows near the walker get a (sleeping) body while the cap allows,
## nearest first, so what you can reach is solid and what you can't is cheap.
func _tier() -> void:
	var eye := venue.global_transform.affine_inverse() * walker.global_position
	for id in live.keys():
		var p: LiveProp = live[id]
		if not is_instance_valid(p):
			live.erase(id)
			continue
		if p.sleeping and p.position.distance_to(eye) > FAR:
			demote(p.row)
	var near: Array = []
	for w in objects.rows.values():
		if w.loose() and not w.held() and w.tier != WorldObject.LIVE:
			var d: float = w.xf.origin.distance_to(eye)
			if d < FAR:
				near.append([d, w])
	near.sort_custom(func(a, b): return a[0] < b[0])
	for e in near:
		if live.size() >= LIVE_CAP:
			break
		promote(e[1])


func _demote_farthest() -> void:
	var eye := venue.global_transform.affine_inverse() * walker.global_position
	var far: LiveProp = null
	var far_d := -1.0
	for p in live.values():
		if is_instance_valid(p) and p.sleeping:
			var d: float = p.position.distance_to(eye)
			if d > far_d:
				far_d = d
				far = p
	if far:
		demote(far.row)
