extends ActionNode
class_name RotateActionNode


func	 can_execute(parent_gridObject:GridObject,starting_cell : GridCell, target_grid_cell : GridCell) -> Dictionary:
	var ret_val = {"can_execute": false, "cost" : -1, "reason" : "N/A"}
	var temp_cost = 0
	
	var result = RotationHelperFunctions.get_rotation_info(parent_gridObject.grid_position_data.direction,
		starting_cell, target_grid_cell)
		
	if result["needs_rotation"] == true:
		temp_cost += 1 * (result["rotation_steps"] )
	else:
		ret_val["can_execute"] = false
		ret_val["cost"] = -1
		ret_val["reason"] = "No rotation needed"
		return ret_val
	
	if parent_gridObject.get_stat_by_name("TimeUnits").current_value < temp_cost:
		ret_val["can_execute"] = false
		ret_val["cost"] = temp_cost
		ret_val["reason"] = "Not enough Time Units!"
		return ret_val
	
	ret_val["can_execute"] = true
	ret_val["cost"] = temp_cost
	ret_val["reason"] = "Success!"
	return ret_val
