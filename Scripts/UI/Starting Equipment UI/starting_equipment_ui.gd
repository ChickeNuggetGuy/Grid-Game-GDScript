class_name StartingEquipmentWindow
extends UIWindow

@export var next_unit_button: Button
@export var previous_unit_button: Button
@export var inventories: Dictionary[Enums.inventoryType, InventoryGridUI]
@export var ground_inventory: InventoryGridUI
@export var unit_portrait: TextureRect
@export var unit_name_label: Label
@export var launch_button: Button

signal mission_equipment_confirmed(units: Array, ground: InventoryGrid)

var unit_grids: Dictionary = {}
var ground_grid: InventoryGrid

var all_units: Array[UnitData] = []
var current_unit_data: UnitData
var _current_index: int = 0

var equipment_cell: GridCell = null
func _ready() -> void:
	super._ready()
	next_unit_button.pressed.connect(_show_next_unit)
	previous_unit_button.pressed.connect(_show_previous_unit)
	launch_button.pressed.connect(_on_launch)



func open_for_craft(craft_data: Dictionary) -> void:
	_build_unit_grids(craft_data)

	equipment_cell = _prepare_ground_cell_from_craft(craft_data)

	if equipment_cell == null:
		push_error("StartingEquipmentWindow: could not prepare equipment cell.")
		return

	ground_grid = equipment_cell.inventory_grid

	if all_units.is_empty():
		push_error("StartingEquipmentWindow: no units on craft")
		return

	ground_inventory.bind(ground_grid, true)

	_current_index = 0
	_refresh_current_unit()
	show_call()


func _prepare_ground_cell_from_craft(craft_data: Dictionary) -> GridCell:
	var grid_system := GameManager.get_manager("GridSystem") as GridSystem
	if grid_system == null:
		push_error("StartingEquipmentWindow: GridSystem not found.")
		return null

	var inv_mgr :InventoryManager = InventoryManager
	if inv_mgr == null:
		push_error("StartingEquipmentWindow: InventoryManager not found.")
		return null

	var result := grid_system.try_get_player_equipment_cell(
		Enums.unitTeam.PLAYER
	)

	if not result["success"]:
		push_error("StartingEquipmentWindow: no player equipment cell found.")
		return null

	var cell: GridCell = result["grid_cell"]
	if cell == null:
		return null

	if cell.inventory_grid == null:
		var grid_result = inv_mgr.try_get_inventory_grid(
			Enums.inventoryType.GROUND
		)

		if not grid_result["success"]:
			push_error("StartingEquipmentWindow: could not create ground grid.")
			return null

		cell.inventory_grid = grid_result["inventory_grid"]

	cell.inventory_grid.clear_items()

	var items_dict: Dictionary = craft_data.get("items", {})

	for item_id_key in items_dict:
		var item_id := int(item_id_key)
		var count := int(items_dict[item_id_key])

		var item_result = inv_mgr.try_get_inventory_item(item_id)
		if not item_result["success"]:
			push_warning("Could not resolve craft item id: " + str(item_id))
			continue

		for i in range(count):
			var item_copy: ItemData = item_result["inventory_item"].duplicate(true)

			if not cell.inventory_grid.try_add_item(item_copy):
				push_warning(
					"Equipment ground cell full. Could not place item id: "
					+ str(item_id)
				)

	return cell
# ─── Build working data ─────────────────────────────────────────────────

func _build_ground_grid(craft_data: Dictionary) -> void:
	var inv_mgr: InventoryManager = InventoryManager
	var result = inv_mgr.try_get_inventory_grid(Enums.inventoryType.GROUND)
	if not result["success"]:
		push_error("GROUND inventory type missing from InventoryManager")
		return
		
	ground_grid = result["inventory_grid"]

	var items_dict: Dictionary = craft_data.get("items", {})
	for item_id in items_dict:
		var res = inv_mgr.try_get_inventory_item(int(item_id))
		if not res["success"]:
			continue
		for i in int(items_dict[item_id]):
			var item_copy: ItemData = res["inventory_item"].duplicate(true)
			if not ground_grid.try_add_item(item_copy):
				push_warning("Ground grid full; item dropped: " + str(item_id))


func _build_unit_grids(craft_data: Dictionary) -> void:
	all_units.clear()
	unit_grids.clear()

	for data in craft_data.get("units_on_board", []):
		if not data is Dictionary:
			continue
		var unit: UnitData = UnitData.deserialize(data)
		if unit == null:
			continue
		all_units.append(unit)
		unit_grids[unit] = _make_grids_for_unit(unit)


func _make_grids_for_unit(unit: UnitData) -> Dictionary:
	var inv_mgr: InventoryManager = InventoryManager
	var grids: Dictionary = {}

	# One working InventoryGrid per UI slot the scene defines.
	for inv_type in inventories.keys():
		var res = inv_mgr.try_get_inventory_grid(inv_type)
		if not res["success"]:
			push_error("Failed loading inventory type: " + Enums.inventoryType.find_key(inv_type))
			continue
		var grid: InventoryGrid = res["inventory_grid"]

		# Pre-populate from the unit's saved equipped_items.
		if unit.equipped_items.has(inv_type):
			for entry in unit.equipped_items[inv_type]:
				if not (entry is Vector2i):
					continue
				var item_res = inv_mgr.try_get_inventory_item(entry.x)
				if not item_res["success"]:
					continue
				for i in range(entry.y):
					grid.try_add_item(item_res["inventory_item"].duplicate(true))
		
		grids[inv_type] = grid
	return grids


# ─── Unit navigation ────────────────────────────────────────────────────

func _show_next_unit() -> void:
	if all_units.size() <= 1: return
	_current_index = (_current_index + 1) % all_units.size()
	_refresh_current_unit()


func _show_previous_unit() -> void:
	if all_units.size() <= 1: return
	_current_index = (_current_index - 1 + all_units.size()) % all_units.size()
	_refresh_current_unit()


func _refresh_current_unit() -> void:
	current_unit_data = all_units[_current_index]

	if unit_portrait:
		unit_portrait.texture = current_unit_data.icon
	if unit_name_label:
		unit_name_label.text = current_unit_data.name
	
	# Rebind each fixed InventoryGridUI to this unit's working grid.
	var grids: Dictionary = unit_grids[current_unit_data]
	for inv_type in inventories:
		var ui: InventoryGridUI = inventories[inv_type]
		if grids.has(inv_type):
			ui.bind(grids[inv_type])
		else:
			push_error("Could not find " + Enums.inventoryType.find_key(inv_type))
			ui.bind(null)   # or ui.visible = false


# ─── Commit ─────────────────────────────────────────────────────────────

func _on_launch() -> void:
	for unit in all_units:
		_write_equipped_items_back(unit)
	hide_call()
	mission_equipment_confirmed.emit(all_units, ground_grid)


func _write_equipped_items_back(unit: UnitData) -> void:
	unit.equipped_items.clear()
	for inv_type in unit_grids[unit]:
		var grid: InventoryGrid = unit_grids[unit][inv_type]
		var counts: Dictionary = {}
		for item in grid.try_get_item_array():
			if item == null:
				continue
			counts[item.item_id] = counts.get(item.item_id, 0) + 1

		var entries: Array = []
		for id in counts:
			entries.append(Vector2i(id, counts[id]))
		unit.equipped_items[inv_type] = entries
