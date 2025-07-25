class_name InventoryGridUI
extends UIWindow

@export var inventory_grid_type : Enums.inventoryType
@export var inventory_slot_holder : Container

var inventory_grid : InventoryGrid
var inventory_slots : Dictionary[Vector2i, Control] = {}

func _init() -> void:
	start_hidden = true
	UnitManager.connect("UnitSelected",unit_manager_unit_selected)

func _setup():
	var selected_unit : GridObject = UnitManager.selectedUnit
	if selected_unit == null:
		_set_current_inventory_grid(null)
		return
	
	var new_inventory_grid : InventoryGrid = null

	if inventory_grid_type == Enums.inventoryType.GROUND:
		var current_grid_cell = selected_unit.grid_position_data.grid_cell
		if current_grid_cell == null:
			_set_current_inventory_grid(null)
			return
		new_inventory_grid = current_grid_cell.gridInventory
	elif inventory_grid_type == Enums.inventoryType.MOUSEHELD:
		var mouse_inventory = self.find_child("MouseHeldInventory")
		if mouse_inventory != null and mouse_inventory.has_method("_setup"):
			mouse_inventory._setup()
			new_inventory_grid = mouse_inventory.inventory_grid
	else:
		if !selected_unit.inventory_grids.has(inventory_grid_type):
			_set_current_inventory_grid(null)
			return
		new_inventory_grid = selected_unit.inventory_grids[inventory_grid_type]
	
	_set_current_inventory_grid(new_inventory_grid)
	
	if inventory_grid == null or inventory_grid.shape == null:
		return

	if inventory_slot_holder is GridContainer:
		inventory_slot_holder.columns = inventory_grid.shape.grid_width
	
	call_deferred("draw_inventory")

func _set_current_inventory_grid(new_grid: InventoryGrid):
	if inventory_grid == new_grid:
		return

	if inventory_grid != null and inventory_grid.is_connected("inventory_changed", Callable(self, "draw_inventory")):
		inventory_grid.disconnect("inventory_changed", Callable(self, "draw_inventory"))
	
	inventory_grid = new_grid

	if inventory_grid != null:
		inventory_grid.connect("inventory_changed", Callable(self, "draw_inventory"))
	
	_clear_slots()

func _show():
	call_deferred("draw_inventory")
	super._show()

func _hide():
	super._hide()

func _clear_slots():
	for slot_control in inventory_slot_holder.get_children():
		slot_control.queue_free()
	inventory_slots.clear()

func draw_inventory():
	if inventory_grid == null or inventory_grid.shape == null:
		_clear_slots()
		return
		
	if inventory_slot_holder is GridContainer:
		if inventory_grid.shape.grid_width != null and inventory_grid.shape.grid_width > 0:
			if inventory_slot_holder.columns != inventory_grid.shape.grid_width:
				inventory_slot_holder.columns = inventory_grid.shape.grid_width
		else:
			push_error("draw_inventory: inventory_grid.shape.grid_width is invalid. Falling back to 1 column.")
			inventory_slot_holder.columns = 1
			
	var current_grid_width = inventory_grid.shape.grid_width
	var current_grid_height = inventory_grid.shape.grid_height
	
	var expected_slot_count = current_grid_width * current_grid_height
	if inventory_slots.size() != expected_slot_count:
		_clear_slots()

	for y in range(current_grid_height): 
		for x in range(current_grid_width):
			var coords = Vector2i(x,y)
			if inventory_slots.has(coords) and inventory_slots[coords] != null:
				update_slot(inventory_slots[coords] as InventorySlotUI)
			else:
				instantiate_inventory_slot_ui(coords)

func instantiate_inventory_slot_ui(grid_coords : Vector2i):
	var instantiated_slot : Control
	
	if inventory_grid == null or inventory_grid.shape == null: 
		return

	if inventory_grid.shape.get_grid_shape_cell(grid_coords.x, grid_coords.y):
		instantiated_slot = InventoryManager.inventory_slot_prefab.instantiate()
	else:
		instantiated_slot = InventoryManager.inactive_inventory_slot_prefab.instantiate()
	
	if instantiated_slot != null and instantiated_slot is InventorySlotUI:
		instantiated_slot._setup(self, grid_coords, null)
		inventory_slot_holder.add_child(instantiated_slot)
		inventory_slots[grid_coords] = instantiated_slot
		
		update_slot(instantiated_slot)
	elif instantiated_slot == null:
		push_error("Error: Failed to instantiate inventory slot UI at coords " + str(grid_coords))

func update_slot(slot : InventorySlotUI):
	if slot == null:
		push_error("Error: Trying to update a null slot")
		return
	if inventory_grid == null or inventory_grid.shape == null:
		slot.icon = null
		return
	
	if (slot.grid_coords.x < 0 || 
		slot.grid_coords.y < 0 || 
		slot.grid_coords.x >= inventory_grid.shape.grid_width ||
		slot.grid_coords.y >= inventory_grid.shape.grid_height):
		slot.icon = null
		return
	
	var item : Item = inventory_grid.has_item_at(slot.grid_coords)
	
	if item != null:
		slot.icon = item.icon
	else:
		slot.icon = null

func unit_manager_unit_selected(new_Unit : GridObject,old_unit : GridObject):
	_setup()

func inventory_slot_pressed(grid_coords : Vector2i):
	var slot = inventory_slots[grid_coords]
	
	if slot == null:
		return
		
	var item =  inventory_grid.has_item_at(grid_coords)
	
	var mouse_held_inventory = 	MainInventoryUI.intance.mouse_held_inventory_ui.inventory_grid
	var mouse_held_inventory_ui =	MainInventoryUI.intance.mouse_held_inventory_ui
	var mouse_held_item = mouse_held_inventory.has_item_at(Vector2i(0,0))
	
	if item != null:
		if inventory_grid.try_transfer_item(inventory_grid, mouse_held_inventory, item):
			MainInventoryUI.intance.mouse_held_inventory_ui.position = inventory_slots[grid_coords].global_position
			MainInventoryUI.intance.mouse_held_inventory_ui.show_call()
	elif mouse_held_item != null:
		if inventory_grid.try_transfer_item_at( mouse_held_inventory ,inventory_grid, mouse_held_item, grid_coords):
			MainInventoryUI.intance.mouse_held_inventory_ui.position =  Vector2i(-10,-10)
			MainInventoryUI.intance.mouse_held_inventory_ui.hide_call()
