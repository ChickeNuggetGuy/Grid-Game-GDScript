extends BaseActionDefinition
class_name MoveActionDefinition



func _init() -> void:
	script_path = "res://Scripts/GridObject/Actions/MoveAction.gd"
	super._init()



func can_execute(parameters : Dictionary) -> Dictionary:
	var ret_val = {"success": false, "costs" : {"TimeUnits" : -1, "stamina" : -1}, "reason" : "N/A"}
	
	var temp_cost = {"TimeUnits" : 0, "stamina" : 0}
	
	# Check if path is possible first
	if not Pathfinder.is_path_possible(parameters["unit"].grid_position_data.grid_cell, parameters["target_grid_cell"] ):
		print("Path not possible!")
		ret_val["success"] = false
		ret_val["costs"]["TimeUnits"] = -1
		ret_val["costs"]["stamina"] = -1
		ret_val["reason"] = "No path possible!"
		return ret_val
	
	var path = Pathfinder.find_path(parameters["unit"].grid_position_data.grid_cell, parameters["target_grid_cell"])
	
	if path == null or path.size() <= 1:  # Need at least 2 cells (start and target)
		print("Path not found or too short!")
		ret_val["success"] = false
		ret_val["costs"]["TimeUnits"] = -1
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
			ret_val["costs"]["TimeUnits"] = -1
			ret_val["costs"]["stamina"] = -1
			ret_val["reason"] = "move step failed: " + move_step_result["reason"]
			return ret_val
		else:
			temp_cost = move_step_result["costs"]
		#var result = RotationHelperFunctions.get_rotation_info(current_direction, current_gridCell, to_cell)
		#
		#if result["needs_rotation"]:
			## Add rotation costs (using absolute value for steps)
			#temp_cost += 1 * abs(result["rotation_steps"])
		#
		## Add movement costs
		#temp_cost += 4
		#
		## Update for next iteration
		#current_direction = result["target_direction"]
		#current_gridCell = to_cell
	
	# Check if we have enough time units
	if temp_cost["time_units"] > parameters["unit"].get_stat_by_name("time_units").current_value and \
			temp_cost["stamina"] > parameters["unit"].get_stat_by_name("stamina").current_value:
		print("Not enough time units! costs: ", temp_cost)
		ret_val["success"] = false
		ret_val["costs"] = temp_cost
		ret_val["reason"] = "Not enough time units!"
		return ret_val
	
	print("Move action can be executed. costs: ", temp_cost)
	ret_val["success"] = true
	ret_val["costs"] = temp_cost
	ret_val["reason"] = "success"
	return ret_val
