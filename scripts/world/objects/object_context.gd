class_name ObjectContext
extends RefCounted
## What a verb gets to work with: the store, the bag, and where the player
## is. Verbs read and write rows through this and return a result for the
## walk to show; they never reach into the room or the walk scene.

var objects: WorldObjects
var bag: InventoryGrid
## The room the player stands in and the point in front of them where a
## dropped thing starts, with the toss it gets (venue space).
var room := &""
var drop_pos := Vector3.ZERO
var drop_velocity := Vector3.ZERO
var yaw := 0.0
## Called with a row the verb wants promoted to a LIVE node (a drop), and
## after the bag changed (so the kit saves it).
var promote: Callable
var bag_changed: Callable


func notify_bag() -> void:
	if bag_changed.is_valid():
		bag_changed.call()
