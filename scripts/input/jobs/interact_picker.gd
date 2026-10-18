class_name InteractPicker
extends RefCounted
## Picks what an on-foot press of interact (JobInput.Frame.interact_pressed)
## acts on: the nearest Node3D within reach and inside the facing cone, from
## a candidate list or the "interactable" group. Reach and facing are measured
## flat on the floor from the walker to the target's origin (a VenueDoor's is
## the middle of its opening), so a door or a bench counts the same whatever
## the eye pitch. A target can offer:
##   prompt() -> String        what the hint says ("Open door", "Oil pump")
##   interact(by) or toggle()  what happens on the press (VenueDoor has toggle)
##
## Usage, once a tick:
##   var t := picker.pick(walker.global_position, walker_facing, get_tree())
##   hint shows picker.prompt_for(t)
##   if frame.interact_pressed: picker.use(t, walker)

const GROUP := &"interactable"

var reach := 1.8              # metres, flat
var cone_deg := 40.0          # half angle of the facing cone


## The best target or null. `candidates` overrides the group when given.
func pick(from: Vector3, facing: Vector3, tree: SceneTree = null, candidates: Array = []) -> Node3D:
	var pool := candidates
	if pool.is_empty() and tree:
		pool = tree.get_nodes_in_group(GROUP)
	var dir := Vector3(facing.x, 0, facing.z).normalized()
	var cos_cone := cos(deg_to_rad(cone_deg))
	var best: Node3D = null
	var best_cost := INF
	for n in pool:
		var node := n as Node3D
		if node == null or not node.is_visible_in_tree():
			continue
		var to := node.global_position - from
		to.y = 0.0
		var d := to.length()
		if d > reach:
			continue
		var c := 1.0 if d < 0.001 else dir.dot(to / d)
		if c < cos_cone:
			continue
		# prefer what's looked at over what's merely closer
		var cost := d * (2.0 - c) * (2.0 - c)
		if cost < best_cost:
			best_cost = cost
			best = node
	return best


static func prompt_for(target: Node) -> String:
	if target == null:
		return ""
	if target.has_method("prompt"):
		return target.prompt()
	if target is VenueDoor:
		return "Close" if target.get("is_open") else "Open"
	return "Use"


## Acts on `target`; returns whether anything happened.
static func use(target: Node, by: Node = null) -> bool:
	if target == null:
		return false
	if target.has_method("interact"):
		target.interact(by)
		return true
	if target.has_method("toggle"):
		target.toggle()
		return true
	return false
