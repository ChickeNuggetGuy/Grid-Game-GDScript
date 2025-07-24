extends ActionNode
class_name MoveActionNode

func can_execute(parent_gridObject: GridObject,starting_cell: GridCell, target_grid_cell: GridCell) -> Dictionary:
	var ret_val = {"can_execute": false, "cost" : -1, "reason" : "N/A"}
	
	var temp_cost = 0
	
	# Check if path is possible first
	if not Pathfinder.is_path_possible(parent_gridObject.grid_position_data.grid_cell, target_grid_cell):
		print("Path not possible!")
		ret_val["can_execute"] = false
		ret_val["cost"] = -1
		ret_val["reason"] = "No path possible!"
		return ret_val
	
	var path = Pathfinder.find_path(parent_gridObject.grid_position_data.grid_cell, target_grid_cell)
	
	if path == null or path.size() <= 1:  # Need at least 2 cells (start and target)
		print("Path not found or too short!")
		ret_val["can_execute"] = false
		ret_val["cost"] = -1
		ret_val["reason"] = "No path found!"
		return ret_val
	
	var current_direction: Enums.facingDirection = parent_gridObject.grid_position_data.direction
	var current_gridCell: GridCell = starting_cell
	
	# Iterate through path segments (from current cell to next cell)
	for i in range(path.size() - 1):
		
		var from_cell: GridCell = path[i]
		var to_cell: GridCell = path[i + 1]
		
		# If we're not starting from the unit's current position, update tracking variables
		if i == 0 and from_cell != current_gridCell:
			# This shouldn't happen, but just in case
			current_gridCell = from_cell
		
		var move_step_result = parent_gridObject.get_action_node_by_name("MoveStep").can_execute(parent_gridObject, from_cell,to_cell )
		if move_step_result["can_execute"] == false:
			ret_val["can_execute"] = false
			ret_val["cost"] = -1
			ret_val["reason"] = "move step failed: " + move_step_result["reason"]
			return ret_val
		else:
			temp_cost = move_step_result["cost"]
		#var result = RotationHelperFunctions.get_rotation_info(current_direction, current_gridCell, to_cell)
		#
		#if result["needs_rotation"]:
			## Add rotation cost (using absolute value for steps)
			#temp_cost += 1 * abs(result["rotation_steps"])
		#
		## Add movement cost
		#temp_cost += 4
		#
		## Update for next iteration
		#current_direction = result["target_direction"]
		#current_gridCell = to_cell
	
	# Check if we have enough time units
	if temp_cost > parent_gridObject.get_stat_by_name("TimeUnits").current_value:
		print("Not enough time units! Cost: ", temp_cost)
		ret_val["can_execute"] = false
		ret_val["cost"] = temp_cost
		ret_val["reason"] = "Not enough time units!"
		return ret_val
	
	print("Move action can be executed. Cost: ", temp_cost)
	ret_val["can_execute"] = true
	ret_val["cost"] = temp_cost
	ret_val["reason"] = "success"
	return ret_val
