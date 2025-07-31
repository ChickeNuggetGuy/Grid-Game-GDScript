extends BaseActionDefinition
class_name RotateActionDefinition


func	 can_execute(parameters : Dictionary) -> Dictionary:
	var ret_val = {"can_execute": false, "cost" : -1, "reason" : "N/A"}
	var temp_cost = 0
	
	var result = RotationHelperFunctions.get_rotation_info(parameters["unit"].grid_position_data.direction,
		parameters["from_grid_cell"], parameters["target_grid_cell"])
		
	if result["needs_rotation"] == true:
		temp_cost += 1 * (result["rotation_steps"] )
	else:
		ret_val["can_execute"] = false
		ret_val["cost"] = -1
		ret_val["reason"] = "No rotation needed"
		return ret_val
	
	if parameters["unit"].get_stat_by_name("TimeUnits").current_value < temp_cost:
		ret_val["can_execute"] = false
		ret_val["cost"] = temp_cost
		ret_val["reason"] = "Not enough Time Units!"
		return ret_val
	
	ret_val["can_execute"] = true
	ret_val["cost"] = temp_cost
	ret_val["reason"] = "Success!"
	return ret_val
