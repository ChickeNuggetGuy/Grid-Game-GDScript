class_name InventorySlotUI
extends Button

var parent : InventoryGridUI
var grid_coords : Vector2i

func _setup(parent_grid : InventoryGridUI, coords : Vector2i, item_held : Item):
	parent = parent_grid
	grid_coords = coords
	
	pressed.connect(parent.inventory_slot_pressed)
