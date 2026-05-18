extends Resource
class_name UnitData

@export var name: String = "John Smith"
@export var icon: Texture2D = preload("res://icon.svg")
@export var current_base_cell_index: int = -1

@export var stats: Dictionary[Enums.Stat, int] = {}

@export var equipped_items: Dictionary[Enums.inventoryType, Array] = {}

func _init(
	unit_name: String = "John Smith",
	base_cell_index: int = -1
) -> void:
	name = unit_name
	current_base_cell_index = base_cell_index
	equipped_items = {}


func serialize() -> Dictionary:
	var item_data: Dictionary = {}
	for inventory_type in equipped_items:
		var entries: Array = []
		for entry in equipped_items[inventory_type]:
			if entry is Vector2i:
				entries.append({"item_id": entry.x, "count": entry.y})
		item_data[int(inventory_type)] = entries

	return {
		"name": name,
		"current_base_cell_index": current_base_cell_index,
		"equipped_items": item_data,
	}


static func deserialize(data: Dictionary) -> UnitData:
	var instance := UnitData.new(
		str(data.get("name", "John Smith")),
		int(data.get("current_base_cell_index", -1))
	)

	var saved_items: Dictionary = data.get("equipped_items", {})
	for key in saved_items:
		var inventory_type: Enums.inventoryType = int(key)
		var entries: Array = saved_items[key]
		var items: Array = []
		for entry in entries:
			if entry is Dictionary:
				items.append(Vector2i(
					int(entry.get("item_id", -1)),
					int(entry.get("count", 0))
				))
		instance.equipped_items[inventory_type] = items

	return instance


static func generate_random_unit(unit_name : String = "Jhon Smith", base_cell_index : int = -1) -> UnitData:
	var new_unit_data: UnitData = UnitData.new(unit_name, base_cell_index)

	new_unit_data.stats[Enums.Stat.HEALTH] = randi_range(55, 100)
	new_unit_data.stats[Enums.Stat.TIMEUNITS] = randi_range(35, 70)
	new_unit_data.stats[Enums.Stat.STAMINA] = randi_range(55, 90)
	new_unit_data.stats[Enums.Stat.BRAVERY] = randi_range(30, 90)

	return new_unit_data


func get_stat_by_type(stat_type: Enums.Stat) -> int:
	
	var stat : int = stats.get(stat_type, null)
	
	if not stat:
		return -1
	else:
		return stat
