@abstract class_name HexCellDefinition

var cell_index : int = -1

func _init(index : int = -1) -> void:
	cell_index = index

@abstract func get_class_name() -> String
@abstract func get_cell_color() -> Color

func serialize() -> Dictionary:
	return {
		"class_name": get_class_name(),
		"cell_index": cell_index
	}
