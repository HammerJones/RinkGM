class_name ChunkStreamer
extends Node3D
## Loads and frees chunk scenes around a focus point without hitching: a
## chunk is a PackedScene with a bounding box, requested through
## ResourceLoader's threaded loader when `focus` comes within `load_radius`
## of its box and freed again past `unload_radius` (the gap stops a chunk
## flapping at the edge). Rooms, stands, the town's blocks: anything the
## player cannot see all of at once goes through here.
##
##   streamer.register("res://scenes/venue/chunks/lobby.tscn", AABB(...))
##   streamer.focus = walker.global_position
##   streamer.chunk_loaded.connect(func(path, node): ...)

signal chunk_loaded(path: String, node: Node)
signal chunk_unloaded(path: String)

const CHECK := 0.25

@export var load_radius := 40.0
@export var unload_radius := 55.0
## Most chunks instantiated per check, so a fast walker still spreads the work.
@export var per_check := 2

var focus := Vector3.ZERO

var _chunks := {}  # path -> {aabb, node, loading}
var _t := CHECK


func register(path: String, aabb: AABB) -> void:
	_chunks[path] = {"aabb": aabb, "node": null, "loading": false}


func unregister(path: String) -> void:
	_free_chunk(path)
	_chunks.erase(path)


func is_loaded(path: String) -> bool:
	return _chunks.has(path) and _chunks[path].node != null


func node_of(path: String) -> Node:
	return _chunks[path].node if _chunks.has(path) else null


func loaded_count() -> int:
	var n := 0
	for c in _chunks.values():
		if c.node:
			n += 1
	return n


## Forces a check now (the first frame of a scene, or a teleport).
func refresh() -> void:
	_t = CHECK


func _process(dt: float) -> void:
	_t += dt
	if _t < CHECK:
		return
	_t = 0.0
	var budget := per_check
	for path in _chunks:
		var c: Dictionary = _chunks[path]
		var d := _distance(c.aabb, focus)
		if c.node:
			if d > unload_radius:
				_free_chunk(path)
			continue
		if c.loading:
			var status := ResourceLoader.load_threaded_get_status(path)
			if status == ResourceLoader.THREAD_LOAD_LOADED and budget > 0:
				budget -= 1
				c.loading = false
				var scene: PackedScene = ResourceLoader.load_threaded_get(path)
				if scene:
					var node := scene.instantiate()
					add_child(node)
					c.node = node
					chunk_loaded.emit(path, node)
			elif (
				status == ResourceLoader.THREAD_LOAD_FAILED
				or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
			):
				c.loading = false
				push_error("ChunkStreamer: failed to load %s" % path)
			continue
		if d <= load_radius:
			c.loading = true
			ResourceLoader.load_threaded_request(path, "PackedScene")


func _free_chunk(path: String) -> void:
	var c: Dictionary = _chunks[path]
	if c.node:
		c.node.queue_free()
		c.node = null
		chunk_unloaded.emit(path)
	c.loading = false


static func _distance(aabb: AABB, p: Vector3) -> float:
	var q := p.clamp(aabb.position, aabb.end)
	return q.distance_to(p)
