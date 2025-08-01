class_name GridObject
extends Node3D

#region Variables
var grid_position_data : GridPositionData
@export var visual :  StaticBody3D
@export var action_holder: Node
@export var action_library: Array[BaseActionDefinition] = []
var action_queue : Array[Action]

@export var stat_holder: Node
@export var stat_library: Array[GridObjectStat] = []

@export var inventory_grid_types : Array[Enums.inventoryType] = []
var inventory_grids : Dictionary[Enums.inventoryType,InventoryGrid] = {}

#endregion


#region Signals
signal  gridObject_stat_changed(stat : GridObjectStat, snew_vaule : int)
signal gridObject_moved(unit : GridObject, new_grid_cell : GridCell)
#endregion
#region Functions

func _ready() -> void:
	visual.collision_layer =PhysicsLayersUtility.PLAYER

func _setup(gridCell : GridCell, direction : Enums.facingDirection):
	var data = GridPositionData.new(self, gridCell, direction)
	add_child(data)
	grid_position_data = data
	
	stat_library.append_array(stat_holder.get_children())
	
	for stat in stat_library:
		var grid_stat = stat
		grid_stat.setUp(self)
	
	setup_inventory_grids()


func setup_inventory_grids():
	for inventory_type in inventory_grid_types:
		
		var result = InventoryManager.try_get_inventory_grid(inventory_type)
		if result["success"]:
			print("success: " + str(inventory_type))
			inventory_grids[inventory_type] =  result["inventory_grid"]



func get_action_node_by_index(i: int) -> BaseActionDefinition:
	var a = action_library[i]
	if a == null:
		print("Action not found at index")
		return null
	else:
		return a

func try_get_action_definition_by_type(type_to_find: String) -> Dictionary:
	var retval : Dictionary = {"success": false, "action_definition" : null}

	var target_script_path: String = ""
	# First, try to find the script path for the given type_string if it's a custom class_name
	var global_classes = ProjectSettings.get_global_class_list()
	for class_info in global_classes:
		if class_info["class"] == type_to_find:
			target_script_path = class_info["path"]
			break

	# Assuming action_library is an Array of ActionNode objects (or whatever base class they extend)
	for action_def in action_library:
		# 1. Check if it's a built-in engine class
		if action_def.is_class(type_to_find):
			retval["success"] = true
			retval["action_definition"] = action_def
			return retval

		# 2. Check if it's a custom class_name
		if target_script_path != "":
			if action_def.get_script() != null and action_def.get_script().resource_path == target_script_path:
				retval["success"] = true
				retval["action_definition"] = action_def
				return retval
	
	# If the loop finishes, the action node was not found
	print("Action not found: " + type_to_find)
	return retval


func get_stat_by_name(name: String) -> GridObjectStat:
	# Assuming action_library is an Array of ActionNode objects
	for stat in stat_library:
		if stat.stat_name == name: # Assuming 'n' is the property holding the name
			return stat
	
	# If the loop finishes, the action node was not found
	print("Action not found: " + name)
	return null


func try_spend_stat_value(stat_name : String, amount_to_spend : int) -> Dictionary:
	var retVal: Dictionary = {"success": false, "new_value": 0}
	var stat = get_stat_by_name(stat_name)
	if stat == null:
		retVal["success"] = false
		retVal["new_value"] = -1
		return retVal
	
	if stat.try_remove_value(amount_to_spend):
		retVal["success"] = true
		retVal["new_value"] = stat.current_value
		return retVal
	else:
		retVal["success"] = false
		retVal["new_value"] = -1
		return retVal

func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_B:
			if UnitManager.selectedUnit == self:
				print(grid_position_data.grid_cell.inventory_grid.try_add_item(InventoryManager.get_random_item()))

#endregion
