extends Manager

var database : ItemDatabase = preload("res://Data/Inventory/Items/ItemDatabase.tres")

var inventory_grids : Dictionary[Enums.inventoryType, InventoryGrid] = {}

var inventory_slot_prefab : PackedScene = preload("res://Scenes/UI/inventory_slot_ui.tscn") as PackedScene
var inactive_inventory_slot_prefab : PackedScene =preload("res://Scenes/UI/inactive_inventory_slot_ui.tscn") as PackedScene


#region Functions



func _get_manager_name() -> String:return "InventoryManager"


func _setup_conditions() -> bool: return true


func _ready() -> void:
	
	var array : Array = UtilityMethods.load_files_of_type_from_directory("res://Data/Inventory/","InventoryGrid")
	print("init array count : " + str(array.size()))
	for child in array:
		if child is not InventoryGrid:
			continue
		inventory_grids[child.inventory_type] = child

func _setup():
	pass




func _execute_conditions() -> bool: return true


func _execute():
	pass



func save_data() -> Dictionary:
	var save_dict = {
		"filename" : get_scene_file_path(),
		"parent" : get_parent().get_path(),
	}
	return save_dict


func try_get_inventory_item(item_id : int) -> Dictionary:
	var retval : Dictionary = {"success": false, "inventory_item" : null}

	if not database.items.keys().has(item_id):
		return retval
	
	var item_instance =  database.items[item_id].duplicate(true)
	retval["success"] = true
	retval["inventory_item"] = item_instance
	return retval


func get_random_item() -> ItemData:
	var ret_item: ItemData = null
	if database.items.size() == 0:
		return ret_item  

	var random_index = randi_range(0, database.items.size() - 1) 
	ret_item = database.items[database.items.keys()[random_index]].duplicate(true)
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
