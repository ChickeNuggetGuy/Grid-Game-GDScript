class_name MainInventoryUI
extends UIWindow

#region Varibales
static var intance : MainInventoryUI
var inventory_ui_grids : Dictionary[Enums.inventoryType, InventoryGridUI] = {}
@export var inventory_grids_holder : Control
@export var mouse_held_inventory_ui : InventoryGridUI

#endregion

func _setup():
	intance = self
	UnitActionManager.connect("action_execution_started",UnitActionManager_action_started)
	for child in inventory_grids_holder.get_children():
		if child is InventoryGridUI:
			var inventory_ui = child as InventoryGridUI
			
			inventory_ui_grids[inventory_ui.inventory_grid_type] = inventory_ui
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


func UnitActionManager_action_started(_action : BaseActionDefinition, execution_parameters : Dictionary):
	if is_shown:
		hide()
