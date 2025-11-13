extends Manager

var inventory_items : Dictionary[String, Item] = {}

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
	return

func _init():
	
	inventory_slot_prefab = load("res://Scenes/UI/inventory_slot_ui.tscn") as PackedScene
	inactive_inventory_slot_prefab = load("res://Scenes/UI/inactive_inventory_slot_ui.tscn") as PackedScene
	
	var array : Array = UtilityMethods.load_files_of_type_from_directory("res://Data/Inventory/","InventoryGrid")
	print("init array count : " + str(array.size()))
	for child in array:
		if child is not InventoryGrid:
			continue
		inventory_grids[child.inventory_type] = child
	
	
	var item_array : Array = UtilityMethods.load_files_of_type_from_directory("res://Data/Inventory/Items/", "Item")
	for child in item_array:
		if child is not Item:
			continue
		var typed_item = child as Item
		typed_item._setup()
		inventory_items[child.item_name] = child

	
	execution_completed.emit()


func save_data() -> Dictionary:
	var save_dict = {
		"filename" : get_scene_file_path(),
		"parent" : get_parent().get_path(),
	}
	return save_dict


func load_data(data : Dictionary):
	pass



func try_gry_inventory_item(item_name : String) -> Dictionary:
	var retval : Dictionary = {"success": false, "inventory_item" : null}

	if not inventory_items.keys().has(item_name):
		return retval
	
	var item_instance =  inventory_items[item_name].duplicate(true)
	retval["success"] = true
	retval["inventory_item"] = item_instance
	return retval


func get_random_item() -> Item:
	var ret_item: Item = null
	if inventory_items.size() == 0:
		return ret_item  

	var random_index = randi_range(0, inventory_items.size() - 1) 
	ret_item = inventory_items[inventory_items.keys()[random_index]].duplicate(true)
	return ret_item


func try_get_inventory_grid(inventory_type : Enums.inventoryType):
	var retval : Dictionary = {"success": false, "inventory_grid" : null}
	
	if !inventory_grids.keys().has(inventory_type):
		return retval
	
	var inventory_instance : InventoryGrid =  inventory_grids[inventory_type].duplicate(true)
	inventory_instance.initialize()
	retval["success"] = true
	retval["inventory_grid"] = inventory_instance
	return retval



#endregion
