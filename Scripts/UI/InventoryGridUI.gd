class_name InventoryGridUI
extends UIWindow

@export var inventory_grid_type : Enums.inventoryType
@export var inventory_slot_holder : Container

var inventory_grid : InventoryGrid
var inventory_slots : Dictionary[Vector2i, InventorySlotUI] = {}

func _init() -> void:
	start_hidden = true
	UnitManager.connect("UnitSelected",unit_manager_unit_selected)

func _setup():

	if inventory_grid != null:
		inventory_grid.disconnect("inventory_changed", Callable(self, "draw_inventory"))
	
	var selected_unit : GridObject = UnitManager.selectedUnit
	if selected_unit == null:
		return
	
	if inventory_grid_type == Enums.inventoryType.GROUND:
		var current_grid_cell = selected_unit.grid_position_data.grid_cell
		
		if current_grid_cell == null:
			return
		
		inventory_grid = current_grid_cell.gridInventory
	else:
		if !selected_unit.inventory_grids.has(inventory_grid_type):
			return
		inventory_grid = selected_unit.inventory_grids[inventory_grid_type]
	
	if inventory_grid == null:
		return
	
	# Connect the signal properly
	inventory_grid.connect("inventory_changed", Callable(self, "draw_inventory"))
	
	if inventory_slot_holder is GridContainer:
		inventory_slot_holder.columns = inventory_grid.inventory_shape.grid_width
	
	draw_inventory()

func _show():
	draw_inventory()
	super._show()

func draw_inventory():
	# Check if inventory_grid is valid
	if inventory_grid == null or inventory_grid.inventory_shape == null:
		return
		
	# Iterate in the same order as the inventory grid expects
	for y in inventory_grid.inventory_shape.grid_height: 
		for x in inventory_grid.inventory_shape.grid_width:
			var coords = Vector2i(x,y)
			if inventory_slots.keys().has(coords) and inventory_slots[coords] != null:
				update_slot(inventory_slots[coords])
			else:
				instantiate_inventory_slot_ui(coords)

func instantiate_inventory_slot_ui(grid_coords : Vector2i):
	var instantiated_slot : InventorySlotUI
	
	# Check if the grid cell is active/valid
	if inventory_grid.inventory_shape.get_grid_shape_cell(grid_coords.x, grid_coords.y):
		instantiated_slot = InventoryManager.inventory_slot_prefab.instantiate()
	else:
		instantiated_slot = InventoryManager.inactive_inventory_slot_prefab.instantiate()
	
	# Ensure the instantiated slot is valid before setting it up
	if instantiated_slot != null:
		instantiated_slot._setup(self, grid_coords, null)
		inventory_slot_holder.add_child(instantiated_slot)
		inventory_slots[grid_coords] = instantiated_slot
		
		# Immediately update the slot to ensure correct icon state
		update_slot(instantiated_slot)
	else:
		print("Error: Failed to instantiate inventory slot UI")

func update_slot(slot : InventorySlotUI):
	# Check if slot is valid
	if slot == null:
		print("Error: Trying to update a null slot")
		return
	
	# Check if inventory_grid is valid
	if inventory_grid == null or inventory_grid.inventory_shape == null:
		slot.icon = null
		return
	
	# Ensure we're accessing valid coordinates
	if (slot.grid_coords.x < 0 || 
		slot.grid_coords.y < 0 || 
		slot.grid_coords.x >= inventory_grid.inventory_shape.grid_width ||
		slot.grid_coords.y >= inventory_grid.inventory_shape.grid_height):
		slot.icon = null
		return
	
	# Check if there's an item at this position using the proper method
	var item : Item = inventory_grid.has_item_at(slot.grid_coords)
	
	# Check if item is valid before accessing its icon
	if item != null:
		slot.icon = item.icon
	else:
		slot.icon = null


func unit_manager_unit_selected(new_Unit : GridObject,old_unit : GridObject):
	print("TEST")
	_setup()
func inventory_slot_pressed(grid_coords : Vector2i):
	return
