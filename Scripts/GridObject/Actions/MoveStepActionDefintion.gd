extends BaseActionDefinition
class_name MoveStepActionDefinition



func _init() -> void:
	script_path = "res://Scripts/GridObject/Actions/MoveStepAction.gd"
	super._init()


func get_valid_grid_cells(starting_grid_cell : GridCell) -> Array[GridCell]:
	var walkable_empty_filter = Enums.cellState.WALKABLE | Enums.cellState.EMPTY
	var result = GridSystem.try_get_neighbors_in_radius(starting_grid_cell, Vector2i(1,2), walkable_empty_filter)
	
	if result["success"] == false:
		push_error(" no grid cells found that satisfy the current filter")
	
	return result["grid_cell_array"]


func _get_AI_action_scores(starting_grid_cell : GridCell) -> Dictionary[GridCell, float]:
	var ret_value : Dictionary[GridCell, float]= { starting_grid_cell :-1}
	
	#var grid_system : GridSystem = GridSystem
	#for grid_cell in get_valid_grid_cells(starting_grid_cell):
		#var distance_between_cells  = grid_system.get_distance_between_grid_cells(starting_grid_cell,grid_cell)
		#var normalized_distance : float = clamp(distance_between_cells / 100, 0.0, 1.0)
		#ret_value[grid_cell] = normalized_distance
	
	return ret_value



func can_execute(parameters : Dictionary) -> Dictionary:
	var ret_val = {"success": false, "costs" : {"time_units" : -1, "stamina" : -1}, "reason" : "N/A"}
	
	var temp_cost = {"time_units" : 0, "stamina" : 0}
		
	var neighbors = GridSystem.get_grid_cell_neighbors(parameters["start_grid_cell"])
	
	if !neighbors.has(parameters["target_grid_cell"]):
		ret_val["success"] = false
		ret_val["costs"]["time_units"] = -1
		ret_val["costs"]["stamina"] = -1
		ret_val["reason"] = "Not adjacent neighbor: " + str(parameters["start_grid_cell"].gridCoordinates) +" "+str(parameters["target_grid_cell"].gridCoordinates)
		return ret_val
	
	var result = RotationHelperFunctions.get_rotation_info(parameters["unit"].grid_position_data.direction,
			 parameters["unit"].grid_position_data.grid_cell, parameters["target_grid_cell"])
		
	if result["needs_rotation"] == true:
		temp_cost["time_units"] += 1 * result["rotation_steps"]
		temp_cost["stamina"] += 1 * result["rotation_steps"]
	temp_cost["time_units"] += 4
	
		
	if parameters["unit"].get_stat_by_name("time_units").current_value < temp_cost["time_units"]:
		ret_val["success"] = false
		ret_val["costs"] = temp_cost
		ret_val["reason"] = "Not enough Time Units!"
	
	if parameters["unit"].get_stat_by_name("stamina").current_value < temp_cost["stamina"]:
		ret_val["success"] = false
		ret_val["costs"] = temp_cost
		ret_val["reason"] = "Not enough Time Units!"
			
	ret_val["success"] = true
	ret_val["costs"] = temp_cost
	ret_val["reason"] = "success!"
	return ret_val
