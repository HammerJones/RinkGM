class_name OwnerKit
extends RefCounted
## What the owner has on them in the walk: the watch on their wrist, the bag
## (a grid inventory), what they're carrying in their arms (a net), their
## footing on the ice, and their training for the day. The walk scene
## (KitHud) shows it and feeds it input; this keeps the state and the rules,
## and saves into `store` (the career's world["kit"], or a scratch dict in a
## free walk), so it all comes back the next morning.
##
## WalkStory's pickup flags ("keys", "spark_plugs", "crampons", ...) turn
## into bag items the first time they're set (ItemCatalog.for_flag).

## What a net weighs on the owner's balance (IceBalance load units).
const LOADS := {"large": 1.0, "mini": 0.4}

var watch := Watch.new()
var bag := InventoryGrid.new()
var training := Training.new()
var balance := IceBalance.create()
## "" or the net in the owner's arms: "large" or "mini".
var carrying := ""
## Nets the owner has set down on the ice: [{"kind", "pos": [x, z], "yaw"}].
var nets_out: Array = []
var store := {}
## Flags already turned into items, so a crumpled note doesn't come back.
var _given := {}


## The kit saved in `store_` (empty for a new owner, who starts with the
## gas-station watch on and the rink keys' flag still to find).
static func open(store_: Dictionary) -> OwnerKit:
	var k := OwnerKit.new()
	k.store = store_
	if store_.has("watch"):
		k.watch = Watch.from_dict(store_.watch)
	if store_.has("bag"):
		k.bag = InventoryGrid.from_dict(store_.bag)
	if store_.has("training"):
		k.training = Training.from_dict(store_.training)
	k.carrying = str(store_.get("carrying", ""))
	k.nets_out = (store_.get("nets_out", []) as Array).duplicate(true)
	k._given = (store_.get("given", {}) as Dictionary).duplicate()
	return k


## Writes the kit back into `store` (the career saves it with the world).
func save() -> void:
	store["watch"] = watch.to_dict()
	store["bag"] = bag.to_dict()
	store["training"] = training.to_dict()
	store["carrying"] = carrying
	store["nets_out"] = nets_out.duplicate(true)
	store["given"] = _given.duplicate()


## New items for flags the walk set since last time. Returns their display
## names ("Gus's ice crampons"); an item with no room stays owed until there is.
func sync_flags(flags: Dictionary) -> Array:
	var got: Array = []
	for f in flags:
		var id := ItemCatalog.for_flag(str(f))
		if id == "" or _given.has(f):
			continue
		if bag.add(id) > 0:
			_given[f] = true
			got.append(ItemCatalog.display_name(id))
	if not got.is_empty():
		save()
	return got


## Gus's crampons go on whenever the owner steps on the ice with them in the bag.
func has_crampons() -> bool:
	return bag.has("crampons")


func carried_load() -> float:
	return float(LOADS.get(carrying, 0.0))


## Walking speed multiplier: half on the ice in shoes (IceBalance.SPEED_SCALE).
func speed_scale(on_ice: bool) -> float:
	return IceBalance.SPEED_SCALE if IceBalance.needed(on_ice, has_crampons()) else 1.0


## One frame of footing. Off the ice, or with crampons on, the wobble rests.
## Returns "fell" on the frame the owner goes down.
func footing(dt: float, on_ice: bool, input: Vector2, speed: float, steadiness := 0.5) -> String:
	if not IceBalance.needed(on_ice, has_crampons()):
		if balance.pos != Vector2.ZERO or balance.out_time > 0.0:
			balance.reset()
		return ""
	balance.steadiness = steadiness
	return balance.tick(dt, input, speed, carried_load())


## The owner went down: a carried net drops where they fell, and a career
## owner gets a sore day or two (Injury.slip) unless already hurt. Returns
## the injury or null.
func fall(at: Vector2, yaw: float, player: PlayerProfile, rng: RandomNumberGenerator, ops: RinkOps = null) -> Injury:
	if carrying != "":
		set_down(at, yaw, ops)
	if player == null or player.injury != null:
		return null
	var inj := Injury.slip(rng)
	player.injury = inj
	player.refresh_modifiers()
	return inj


## Takes a net from the storage by the gate. False with full arms or none left.
func pick_up(kind: String, ops: RinkOps) -> bool:
	if carrying != "" or not LOADS.has(kind) or in_storage(kind, ops) <= 0:
		return false
	carrying = kind
	save()
	return true


## Nets of `kind` still in storage: what the rink owns, less those on the ice
## (RinkOps.nets_on) and the one in the owner's arms.
func in_storage(kind: String, ops: RinkOps) -> int:
	var owned := RinkOps.NETS_LARGE if kind == "large" else RinkOps.NETS_MINI
	var on := int(ops.nets_on[0 if kind == "large" else 1]) if ops else 0
	return owned - on - (1 if carrying == kind else 0)


## Puts the carried net down at `at` (ice x, z). The sim counts it as on the ice.
func set_down(at: Vector2, yaw: float, ops: RinkOps = null) -> void:
	if carrying == "":
		return
	nets_out.append({"kind": carrying, "pos": [at.x, at.y], "yaw": yaw})
	if ops:
		_count(ops, carrying, 1)
	carrying = ""
	save()


## Picks a net back up off the ice (index into nets_out).
func lift(i: int, ops: RinkOps = null) -> bool:
	if carrying != "" or i < 0 or i >= nets_out.size():
		return false
	carrying = str(nets_out[i].kind)
	nets_out.remove_at(i)
	if ops:
		_count(ops, carrying, -1)
	save()
	return true


## Back into storage.
func put_away() -> void:
	carrying = ""
	save()


## The net set down nearest `at` within `reach` metres, or -1.
func net_near(at: Vector2, reach := 1.6) -> int:
	var best := -1
	var best_d := reach
	for i in nets_out.size():
		var p: Array = nets_out[i].pos
		var d := at.distance_to(Vector2(float(p[0]), float(p[1])))
		if d < best_d:
			best_d = d
			best = i
	return best


## Keeps the sim's count of nets on the ice in step with the owner's hands.
static func _count(ops: RinkOps, kind: String, by: int) -> void:
	if kind == "large":
		ops.set_nets(int(ops.nets_on[0]) + by, int(ops.nets_on[1]))
	else:
		ops.set_nets(int(ops.nets_on[0]), int(ops.nets_on[1]) + by)
