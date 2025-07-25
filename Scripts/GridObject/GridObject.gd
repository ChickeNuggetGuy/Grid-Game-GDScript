class_name GridObject
extends Node3D

#region Variables
var grid_position_data : GridPositionData
@export var visual :  StaticBody3D
@export var action_holder: Node
@export var action_library: Array[ActionNode] = []
var action_queue : Array[Action]

@export var stat_holder: Node
@export var stat_library: Array[GridObjectStat] = []

@export var inventory_grid_types : Array[Enums.inventoryType] = []
var inventory_grids : Dictionary[Enums.inventoryType,InventoryGrid] = {}

#endregion


#region Signals
signal  gridObject_stat_changed(stat : GridObjectStat, snew_vaule : int)
#endregion
#region Functions

func _ready() -> void:
	visual.collision_layer =PhysicsLayersUtility.PLAYER

func _setup(gridCell : GridCell, direction : Enums.facingDirection):
	var data = GridPositionData.new(self, gridCell, direction)
	add_child(data)
	grid_position_data = data
	
	action_library.append_array(action_holder.get_children())
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



func get_action_node_by_index(i: int) -> ActionNode:
	var a = action_library[i]
	if a == null:
		print("Action not found at index")
		return null
	else:
		return a


func get_action_node_by_name(name: String) -> ActionNode:
	# Assuming action_library is an Array of ActionNode objects
	for action_node in action_library:
		if action_node.name == name: # Assuming 'n' is the property holding the name
			print(action_node.name) # Print the name of the found node
			return action_node
	
	# If the loop finishes, the action node was not found
	print("Action not found: " + name)
	return null


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
				print(grid_position_data.grid_cell.gridInventory.try_add_item(InventoryManager.get_random_item()))

#endregion
