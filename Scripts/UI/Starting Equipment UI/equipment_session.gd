class_name EquipmentSession
extends RefCounted

# Working copies
var craft: Craft
var pool: Dictionary[int, int] = {}
var unit_grids: Dictionary = {} 
var units: Array[UnitData] = []

func _init(source_craft: Craft) -> void:
	craft = source_craft
	units = source_craft.units_on_board.duplicate()

	# Snapshot pool from craft.items
	for item in source_craft.items:
		pool[item] = source_craft.items[item]

	# Build working InventoryGrids from each unit's equipped_items
	var inv_mgr: InventoryManager = InventoryManager
	for unit in units:
		var per_type: Dictionary = {}
		for inv_type in unit.equipped_items:
			var template: InventoryGrid = inv_mgr.try_get_inventory_grid(inv_type)
			var grid: InventoryGrid = template.duplicate(true)
			# Re-place saved items into the duplicated grid
			for entry in unit.equipped_items[inv_type]:
				if entry is Vector2i:
					var item_data: ItemData = inv_mgr.try_get_inventory_item(entry.x)["inventory_item"]
					for i in entry.y:
						grid.try_auto_place(item_data)   # assumes such a helper
			per_type[inv_type] = grid
		unit_grids[unit.get_instance_id()] = per_type


func try_move_pool_to_unit(unit: UnitData, inv_type: int, item: ItemData, cell: Vector2i) -> bool:
	if pool.get(item.item_id, 0) <= 0:
		return false
	var grid: InventoryGrid = unit_grids[unit.get_instance_id()][inv_type]
	if not grid.try_place(item, cell):
		return false
	pool[item.item_id] -= 1
	if pool[item.item_id] <= 0:
		pool.erase(item.item_id)
	return true


func try_move_unit_to_pool(unit: UnitData, inv_type: int, cell: Vector2i) -> bool:
	var grid: InventoryGrid = unit_grids[unit.get_instance_id()][inv_type]
	var item: ItemData = grid.try_remove_at(cell)
	if item == null:
		return false
	pool[item.item_id] = pool.get(item.item_id, 0) + 1
	return true


func commit() -> void:
	var inv_mgr: InventoryManager = InventoryManager

	# Write equipped_items back to units
	for unit in units:
		var per_type: Dictionary = unit_grids[unit.get_instance_id()]
		unit.equipped_items.clear()
		for inv_type in per_type:
			var grid: InventoryGrid = per_type[inv_type]
			var counts: Dictionary = {}              # item_id -> count
			for item in grid.get_placed_items():      # assumes this returns ItemData list
				counts[item.item_id] = counts.get(item.item_id, 0) + 1
			var entries: Array = []
			for id in counts:
				entries.append(Vector2i(id, counts[id]))
			unit.equipped_items[inv_type] = entries

	# Rebuild craft.items from pool
	craft.items.clear()
	for item_id in pool:
		var res = inv_mgr.try_get_inventory_item(item_id)
		if res["success"]:
			craft.items[res["inventory_item"]] = pool[item_id]
