class_name World
extends Node3D
## The world: a ChunkStreamer loading WorldChunk scenes around the focus,
## one WorldObjects registry across every loaded chunk's field, and the
## save of all of it. The game's scenes hang their own things (the match,
## the people, the clock) beside it; this only owns what streams.
##
##   var world := World.new()
##   add_child(world)
##   world.register_chunk("res://scenes/venue/chunks/lobby.tscn", AABB(...))
##   world.focus = walker.global_position     # each frame
##   world.objects.act("take", row)           # the registry
##   var save := world.to_save()              # rows per chunk, loaded or not
##   world.from_save(save)

signal chunk_loaded(chunk: WorldChunk)
signal chunk_unloaded(chunk: WorldChunk)

var streamer: ChunkStreamer
var objects: WorldObjects
var audio: ContactAudio

var focus := Vector3.ZERO:
	set(v):
		focus = v
		if streamer:
			streamer.focus = v
		for f in objects.fields if objects else []:
			f.focus = v

var _chunks := {}  # path -> WorldChunk


func _init() -> void:
	streamer = ChunkStreamer.new()
	streamer.name = "Streamer"
	add_child(streamer)
	objects = WorldObjects.new()
	objects.name = "Objects"
	add_child(objects)
	audio = ContactAudio.new()
	audio.name = "ContactAudio"
	add_child(audio)
	audio.listen_objects(objects)
	streamer.chunk_loaded.connect(_on_loaded)
	streamer.chunk_unloaded.connect(_on_unloaded)


func register_chunk(path: String, bounds: AABB) -> void:
	streamer.register(path, bounds)


func loaded_chunks() -> Array:
	return _chunks.values()


func chunk_at(pos: Vector3) -> WorldChunk:
	for c in _chunks.values():
		if c.contains(pos):
			return c
	return null


func to_save() -> Dictionary:
	return objects.to_save()


func from_save(d: Dictionary) -> void:
	objects.from_save(d)


func _on_loaded(path: String, node: Node) -> void:
	var chunk := node as WorldChunk
	if chunk == null:
		push_error("World: %s is not a WorldChunk scene" % path)
		return
	chunk.world = self
	_chunks[path] = chunk
	objects.add_field(chunk.field, chunk.chunk_id)
	audio.listen(chunk.field)
	chunk.field.focus = focus
	chunk.populate(objects)
	chunk_loaded.emit(chunk)


func _on_unloaded(path: String) -> void:
	var chunk: WorldChunk = _chunks.get(path)
	if chunk == null:
		return
	chunk_unloaded.emit(chunk)
	objects.remove_field(chunk.field)
	_chunks.erase(path)
