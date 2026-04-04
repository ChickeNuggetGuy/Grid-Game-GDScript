extends Resource
class_name UnitData

@export var name: String = "John Smith"
@export var current_base_cell_index: int = -1

func _init(unit_name: String = "John Smith", base_cell_index: int = -1) -> void:
	name = unit_name
	current_base_cell_index = base_cell_index

func serialize() -> Dictionary:
	return {
		"name": name,
		"current_base_cell_index": current_base_cell_index,
	}

static func deserialize(data: Dictionary) -> UnitData:
	return UnitData.new(
		str(data.get("name", "John Smith")),
		int(data.get("current_base_cell_index", -1))
	)
