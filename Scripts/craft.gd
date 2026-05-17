class_name Craft
extends Node3D

var craft_name: String = "New Craft"
var units_on_board: Array[UnitData]
var items: Dictionary[int, int] = {}

var current_cell_index: int = -1
var home_cell_index: int = -1

var craft_state: Enums.CraftState = Enums.CraftState.HOME


func _init(
	new_craft_name: String = "New Craft",
	home_index: int = -1,
	units: Array[UnitData] = [],
	current_index: int = -1
) -> void:
	craft_name = new_craft_name
	units_on_board = units.duplicate()
	items = {}

	home_cell_index = home_index

	if current_index == -1:
		current_cell_index = home_cell_index
	else:
		current_cell_index = current_index


func try_add_unit_to_craft(
	unit_to_add: UnitData,
	origin_base: TeamBaseDefinition
) -> bool:
	if not unit_to_add:
		return false
	if not origin_base:
		return false

	if not origin_base.stationed_units.has(unit_to_add):
		print("Unit not at base of origin specified!")
		return false

	var unit_index := origin_base.stationed_units.find(unit_to_add)
	units_on_board.append(origin_base.stationed_units.pop_at(unit_index))
	return true


func try_remove_unit_from_craft(
	unit_to_remove: UnitData,
	target_base: TeamBaseDefinition
) -> bool:
	if not unit_to_remove:
		return false
	if not target_base:
		return false

	if not units_on_board.has(unit_to_remove):
		print("Unit not on craft specified!")
		return false

	var unit_index := units_on_board.find(unit_to_remove)
	target_base.stationed_units.append(units_on_board.pop_at(unit_index))
	return true

func try_add_item_to_craft(
	item_to_add: ItemData,
	origin_base: TeamBaseDefinition
) -> bool:
	if not item_to_add:
		return false
	if not origin_base:
		return false

	var item_id := item_to_add.item_id

	if not origin_base.has_item(item_to_add):
		print("Item not at base of origin specified!")
		return false

	origin_base.remove_item(item_to_add, 1)

	if items.has(item_id):
		items[item_id] += 1
	else:
		items[item_id] = 1

	return true


func try_remove_item_from_craft(
	item_to_remove: ItemData,
	target_base: TeamBaseDefinition
) -> bool:
	if not item_to_remove:
		return false
	if not target_base:
		return false

	var item_id := item_to_remove.item_id

	if not items.has(item_id):
		print("Item not on craft specified!")
		return false

	var item_count: int = items[item_id]

	if item_count <= 1:
		items.erase(item_id)
	else:
		items[item_id] = item_count - 1

	target_base.add_item(item_to_remove)
	return true


func try_remove_item_id_from_craft(
	item_id: int,
	target_base: TeamBaseDefinition
) -> bool:
	if item_id < 0:
		return false
	if not target_base:
		return false

	if not items.has(item_id):
		print("Item not on craft specified!")
		return false

	var result := InventoryManager.try_get_inventory_item(item_id)
	if not result["success"]:
		push_error("Could not resolve item id: " + str(item_id))
		return false

	var item_data: ItemData = result["inventory_item"]

	var item_count: int = items[item_id]

	if item_count <= 1:
		items.erase(item_id)
	else:
		items[item_id] = item_count - 1

	target_base.add_item(item_data)
	return true

func return_all_contents_to_base(target_base: TeamBaseDefinition) -> void:
	if not target_base:
		return

	for unit in units_on_board:
		if unit:
			target_base.stationed_units.append(unit)
	units_on_board.clear()

	for item_id in items.keys():
		var item_count: int = items[item_id]

		var result := InventoryManager.try_get_inventory_item(item_id)
		if not result["success"]:
			push_error("Could not resolve item id: " + str(item_id))
			continue

		var item_data: ItemData = result["inventory_item"]

		for i in range(item_count):
			target_base.add_item(item_data)

	items.clear()


func serialize() -> Dictionary:
	var ret_data: Dictionary = {}

	ret_data["craft_name"] = craft_name
	ret_data["craft_state"] = int(craft_state)

	var units_data: Array = []
	for unit in units_on_board:
		if unit != null:
			units_data.append(unit.serialize())

	ret_data["units_on_board"] = units_data

	var item_data: Dictionary = {}
	for item_id in items.keys():
		var count: int = items[item_id]
		if count > 0:
			item_data[int(item_id)] = count

	ret_data["current_cell_index"] = current_cell_index
	ret_data["home_cell_index"] = home_cell_index
	ret_data["position"] = position
	ret_data["items"] = item_data

	return ret_data


static func deserialize(data: Dictionary) -> Craft:
	var instance := Craft.new(
		data.get("craft_name", "No Name!"),
		int(data.get("home_cell_index", -1)),
		[],
		int(data.get("current_cell_index", -1))
	)

	var default_state := Enums.CraftState.HOME
	if instance.current_cell_index != instance.home_cell_index:
		default_state = Enums.CraftState.IDLE

	instance.craft_state = int(data.get("craft_state", default_state))

	instance.units_on_board.clear()

	var units_data: Array = data.get("units_on_board", [])
	for unit_data in units_data:
		if unit_data is Dictionary:
			instance.units_on_board.append(UnitData.deserialize(unit_data))

	instance.items.clear()

	var items_data: Dictionary = data.get("items", {})
	for item_id_key in items_data.keys():
		var item_id := int(item_id_key)
		var count := int(items_data[item_id_key])

		if item_id < 0:
			push_error("Invalid item id while loading craft item data.")
			continue

		if count <= 0:
			continue

		instance.items[item_id] = count

	return instance
