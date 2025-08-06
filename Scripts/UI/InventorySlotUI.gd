class_name InventorySlotUI
extends Button

var parent: InventoryGridUI
var grid_coords: Vector2i

func _setup(parent_grid: InventoryGridUI, coords: Vector2i, _item_held: Item):
	parent = parent_grid
	grid_coords = coords


func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				parent.inventory_slot_pressed(grid_coords, true)
				# Let the default behavior handle the click
			MOUSE_BUTTON_RIGHT:
				parent.inventory_slot_pressed(grid_coords, false)
				accept_event()  # Prevent default behavior if needed
