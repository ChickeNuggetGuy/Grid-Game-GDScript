class_name GridObject
extends Node3D

#region Variables
var grid_position_data : GridPositionData
@export var visual :  StaticBody3D


@export var stat_holder: Node
@export var stat_library: Array[GridObjectStat] = []

@export var inventory_grid_types : Array[Enums.inventoryType] = []
var inventory_grids : Dictionary[Enums.inventoryType,InventoryGrid] = {}


@export var grid_object_animator : GridObjectAnimation
@export var grid_height : int
@export var grid_shape : GridShape
#endregion


#region Signals
signal  gridObject_stat_changed(stat : GridObjectStat, snew_vaule : int)
@warning_ignore("unused_signal")
signal gridObject_moved(owner : Unit, new_grid_cell : GridCell)

signal  grid_object_died(grid_object : GridObject)
#endregion
#region Functions

func _ready() -> void:
	visual.collision_layer =PhysicsLayersUtility.PLAYER

func _setup(gridCell : GridCell, direction : Enums.facingDirection):
	var data = GridPositionData.new(self, gridCell, direction, grid_shape, grid_height)
	add_child(data)
	grid_position_data = data
	
	stat_library.append_array(stat_holder.get_children())
	
	for stat in stat_library:
		var grid_stat : GridObjectStat = stat
		grid_stat.setUp(self)
		if grid_stat.stat_name == "Health":
			grid_stat.connect("min_value_reached", grid_object_dealth)
	
	setup_inventory_grids()


func grid_object_dealth():
	print("Grid Object Died, Removing from tree")
	self.queue_free()
	return 
func setup_inventory_grids():
	for inventory_type in inventory_grid_types:
		
		var result = InventoryManager.try_get_inventory_grid(inventory_type)
		if result["success"]:
			inventory_grids[inventory_type] =  result["inventory_grid"]



func get_stat_by_name(stat_name: String) -> GridObjectStat:
	# Assuming action_library is an Array of ActionNode objects
	for stat in stat_library:
		if stat.stat_name == stat_name: # Assuming 'n' is the property holding the name
			return stat
	
	# If the loop finishes, the action node was not found
	print("stat not found: " + stat_name)
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
		gridObject_stat_changed.emit(stat,stat.current_value)
		return retVal
	else:
		retVal["success"] = false
		retVal["new_value"] = -1
		return retVal


func check_stat_values(stats_to_check: Dictionary) -> Dictionary:
	var return_value = {"success" : false, "reasoning" : ""}
	
	var temp_costs : Dictionary = {}
	
	for stat_name in stats_to_check.keys():
		var cost = stats_to_check[stat_name]
		var stat = get_stat_by_name(stat_name)
		
		if stat == null:
			return_value["success"] = false
			return_value["reasoning"] = "stat with name: " + stat_name + " nit found!"
			return return_value
		
		if stat.current_value < cost:
			return_value["success"] = false
			return_value["reasoning"] = "not enough: " + stat_name + " value"
			return return_value
		
		if temp_costs.find_key(stat) == null:
			temp_costs[stat] = cost
		else:
			temp_costs[stat] += cost
	
	for  stat in temp_costs.keys():
		
		if stat.current_value < temp_costs[stat]:
			return_value["success"] = false
			return_value["reasoning"] = "not enough: " + stat.name + " value"
			return return_value
	
	return_value["success"] = true
	return_value["reasoning"] = "Yay"
	return return_value





func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_B:
			if UnitManager.selectedUnit == self:
				print(grid_position_data.grid_cell.inventory_grid.try_add_item(InventoryManager.get_random_item()))

#endregion
