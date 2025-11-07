extends Resource
class_name HexGridData

signal definitions_changed

var cell_definitions: Dictionary = {} # int -> Array[HexCellDefinition]
var _dirty := false
var hex_decorator : HexGridDecorator



func _init(decorator : HexGridDecorator) -> void:
	hex_decorator = decorator
	
func add_cell_definition(
	cell_index: int,
	definition: HexCellDefinition,
	hex_decorator: HexGridDecorator
) -> void:
	if not cell_definitions.has(cell_index):
		cell_definitions[cell_index] = []
	cell_definitions[cell_index].append(definition)

	if hex_decorator and hex_decorator.is_inside_tree():
		hex_decorator.request_definitions_rebuild()

func add_cell_definitions_bulk(items: Array) -> void:
	for it in items:
		var idx: int = int(it["index"])
		var defn: HexCellDefinition = it["def"]
		add_cell_definition(idx, defn, hex_decorator)
	_dirty = true

func get_cell_definitions(cell_index: int) -> Array:
	if cell_definitions.has(cell_index):
		return cell_definitions[cell_index]
	return []

func get_defined_cell_indices() -> Array:
	return cell_definitions.keys()

func is_dirty() -> bool:
	return _dirty

func clear_dirty() -> void:
	_dirty = false

func clear() -> void:
	cell_definitions.clear()
	_dirty = true
	emit_signal("definitions_changed")
