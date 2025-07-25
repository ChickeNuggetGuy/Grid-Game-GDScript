extends Manager

var inventory_grids : Dictionary[Enums.inventoryType, InventoryGrid] = {}
var inventory_slot_prefab : PackedScene
var inactive_inventory_slot_prefab : PackedScene
#region Functions
func _get_manager_name() -> String:return "InventoryManager"


func _setup_conditions() -> bool: return true


func _setup():
	setup_completed.emit()


func _execute_conditions() -> bool: return true


func _execute():
	
	inventory_slot_prefab = load("res://Scenes/UI/inventory_slot_ui.tscn") as PackedScene
	inactive_inventory_slot_prefab = load("res://Scenes/UI/inventory_slot_ui.tscn") as PackedScene
	var array : Array = UtilityMethods.load_files_of_type_from_directory("res://Data/Inventory/","InventoryGrid")
	print("init array count : " + str(array.size()))
	for child in array:
		if child is not InventoryGrid:
			continue
		
		inventory_grids[child.inventory_type] = child

	
	execution_completed.emit()


func try_get_inventory_grid(inventory_type : Enums.inventoryType):
	var retval : Dictionary = {"success": false, "inventory_grid" : null}
	
	if !inventory_grids.keys().has(inventory_type):
		return retval
	
	var inventory_instance =  inventory_grids[inventory_type].duplicate(true)
	retval["success"] = true
	retval["inventory_grid"] = inventory_instance
	return retval



#endregion
