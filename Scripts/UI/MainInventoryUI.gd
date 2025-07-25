class_name MainInventoryUI
extends UIWindow

var inventory_ui_grids : Dictionary[Enums.inventoryType, InventoryGridUI] = {}
@export var inventory_grids_holder : Control

func _setup():
	for child in inventory_grids_holder.get_children():
		if child is InventoryGridUI:
			var inventory_ui = child as InventoryGridUI
			
			inventory_ui_grids[inventory_ui.inventory_grid_type] = inventory_ui
			print("Inventory UI of type: "+ str(inventory_ui.inventory_grid_type) + " detected, adding to dictionary")
			#TODO:determine  if I should setup the children inventoryGridUI's now or at a seperate time
			inventory_ui.setup_call()


func _show():
	if inventory_ui_grids.size() > 0:
	
		for inventory_ui in inventory_ui_grids.values():
			inventory_ui.show_call()
		
	super._show()


func _hide():
	if inventory_ui_grids.size() > 0:
	
		for inventory_ui in inventory_ui_grids.values():
			inventory_ui.hide_call()
		
	super._hide()
