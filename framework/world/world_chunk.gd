class_name WorldChunk
extends Node3D
## One piece of the world that streams in and out as a unit: a room, a
## stand, a block of the town. The convention every chunk scene follows:
##
##   - the root is a WorldChunk with `chunk_id` and `bounds` (world space)
##   - it owns one PropField ("Props") for the things placed in it; the
##     scene's layout code spawns them through World.objects when the
##     chunk enters the tree (`populate` is called once per load)
##   - its walls and floors are StaticBody3D on Layers.VENUE and are listed
##     in `occluder_boxes` so Occluders.from_boxes culls behind them
##   - anything that must only run while the chunk is loaded (people in
##     it, a machine's loop) hangs under it and goes with it
##
## The World registers the chunk's field with the objects registry under
## chunk_id on enter and takes it back on exit, which is what makes a moved
## cup still moved when the room is streamed back in.

## Stable id, the key for the chunk's saved rows.
@export var chunk_id := ""
## The chunk's extent in world space; the streamer's load radius measures to it.
@export var bounds := AABB(Vector3.ZERO, Vector3(16, 4, 16))
## Walls, floors and counters to occlude behind (world space); empty for none.
@export var occluder_boxes: Array[AABB] = []

var field: PropField
var world: Node = null  # the World that loaded it, when any


func _enter_tree() -> void:
	if field == null:
		field = get_node_or_null("Props") as PropField
	if field == null:
		field = PropField.new()
		field.name = "Props"
		add_child(field)
	if not occluder_boxes.is_empty() and get_node_or_null("Occluders") == null:
		Occluders.from_boxes(self, occluder_boxes)


## Lays the chunk out: the subclass spawns its rows through `objects` and
## builds its geometry. Called by World once each time the chunk loads,
## after the field is registered (so saved rows are already applied and a
## row the layout would place twice is skipped by id).
func populate(_objects: WorldObjects) -> void:
	pass


## True when `pos` (world space) is inside the chunk's bounds.
func contains(pos: Vector3) -> bool:
	return bounds.has_point(pos)
