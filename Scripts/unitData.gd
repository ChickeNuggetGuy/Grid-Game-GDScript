extends Resource
class_name UnitData

@export var name: String = "John Smith"
@export var icon : Texture2D
@export var current_base_cell_index: int = -1

@export var stats : Dictionary[Enums.Stat, int] = {}

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


static func generate_random_unit() -> UnitData:
	var new_unit_data : UnitData = UnitData.new("John Smith")
	
	new_unit_data.stats[Enums.Stat.HEALTH] = randi_range(55, 100)
	new_unit_data.stats[Enums.Stat.TIMEUNITS] = randi_range(35, 70)
	new_unit_data.stats[Enums.Stat.STAMINA] = randi_range(55, 90)
	new_unit_data.stats[Enums.Stat.BRAVERY] = randi_range(30, 90)
	
	return new_unit_data
