extends BaseActionDefinition
class_name MoveActionDefinition



func _init() -> void:
	script_path = "res://Scripts/GridObject/Actions/MoveAction.gd"
	super._init()


func get_valid_grid_cells(starting_grid_cell : GridCell) -> Array[GridCell]:
	var walkable_empty_filter = Enums.cellState.WALKABLE
	var result = GridSystem.try_get_neighbors_in_radius(starting_grid_cell, Vector2i(8,5), walkable_empty_filter)
	
	if result["success"] == false:
		push_error(" no grid cells found that satisfy the current filter")
	
	return result["grid_cell_array"]


func _get_AI_action_scores(starting_grid_cell : GridCell) -> Dictionary[GridCell, float]:
	var ret_value : Dictionary[GridCell, float]= {}
	
	var grid_system : GridSystem = GridSystem
	for grid_cell in get_valid_grid_cells(starting_grid_cell):
		var distance_between_cells  = grid_system.get_distance_between_grid_cells(starting_grid_cell,grid_cell)
		var normalized_distance : float = clamp(distance_between_cells / 100, 0.0, 1.0)
		ret_value[grid_cell] = normalized_distance
	
	return ret_value



func can_execute(parameters : Dictionary) -> Dictionary:
	var ret_val = {"success": false, "costs" : {"time_units" : -1, "stamina" : -1}, "reason" : "N/A"}
	
	var temp_costs = {"time_units" : 0, "stamina" : 0}
	
	# Check if path is possible first
	if not Pathfinder.is_path_possible(parameters["unit"].grid_position_data.grid_cell, parameters["target_grid_cell"] ):
		print("Path not possible!")
		ret_val["success"] = false
		ret_val["costs"]["time_units"] = -1
		ret_val["costs"]["stamina"] = -1
		ret_val["reason"] = "No path possible!"
		return ret_val
	
	var path = Pathfinder.find_path(parameters["unit"].grid_position_data.grid_cell, parameters["target_grid_cell"])
	
	if path == null or path.size() <= 1:  # Need at least 2 cells (start and target)
		print("Path not found or too short!")
		ret_val["success"] = false
		ret_val["costs"]["time_units"] = -1
		ret_val["costs"]["stamina"] = -1
		ret_val["reason"] = "No path found!"
		return ret_val
	
	var current_gridCell: GridCell = parameters["start_grid_cell"]
	
	# Iterate through path segments (from current cell to next cell)
	for i in range(path.size() - 1):
		
		var from_cell: GridCell = path[i]
		var to_cell: GridCell = path[i + 1]
		
		# If we're not starting from the unit's current position, update tracking variables
		if i == 0 and from_cell != current_gridCell:
			# This shouldn't happen, but just in case
			current_gridCell = from_cell
		
		var get_action_result = parameters["unit"].try_get_action_definition_by_type("MoveStepActionDefinition")
		if get_action_result["success"] == false:
			return ret_val
		var move_step_result = get_action_result["action_definition"].can_execute({
				"unit": parameters["unit"], 
				"start_grid_cell": from_cell, 
				"target_grid_cell": to_cell
				})
		
		if move_step_result["success"] == false:
			ret_val["success"] = false
			ret_val["costs"]["time_units"] = -1
			ret_val["costs"]["stamina"] = -1
			ret_val["reason"] = "move step failed: " + move_step_result["reason"]
			return ret_val
		else:
			for key in temp_costs.keys():
				temp_costs[key] +=move_step_result["costs"][key]
	
	# Check if we have enough stats
	var result = parameters["unit"].check_stat_values(temp_costs)
	
	if result["success"] == false:
		ret_val["success"] = false
		ret_val["costs"] = temp_costs
		ret_val["reason"] =result["reason"]
		return ret_val
		
	
	print("Move action can be executed. costs: ", temp_costs)
	ret_val["success"] = true
	ret_val["costs"] = temp_costs
	ret_val["reason"] = "success"
	return ret_val
