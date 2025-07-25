class_name InventorySlotUI
extends Button

var parent: InventoryGridUI
var grid_coords: Vector2i

func _setup(parent_grid: InventoryGridUI, coords: Vector2i, item_held: Item):
	parent = parent_grid
	grid_coords = coords
	
	# Pass the grid_coords to the parent method when pressed
	pressed.connect(parent_grid.inventory_slot_pressed.bind(grid_coords))
