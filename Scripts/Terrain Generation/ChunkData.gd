extends Resource
class_name ChunkData

enum ChunkType {
	PROCEDURAL,
	MAN_MADE
}

@export var chunk_coordinates: Vector2i = Vector2i.ZERO
@export var chunk_type: int = ChunkType.PROCEDURAL
@export var chunk_go_index: String = "ShipChunk"

var chunk = null
var chunk_node = null

func _init(
		coords: Vector2i = Vector2i.ZERO,
		type: int = ChunkType.PROCEDURAL,
		_chunk_node = null) -> void:
	chunk_coordinates = coords
	chunk_type = type
	chunk_node = _chunk_node
	if chunk_node:
		if chunk_node.has_node("Chunk"):
			chunk = chunk_node.get_node("Chunk")

func get_chunk_node():
	return chunk_node

func set_chunk_node(value) -> void:
	chunk_node = value

func get_chunk_type() -> int:
	return chunk_type

func get_chunk_go_index() -> String:
	return "ShipChunk"
