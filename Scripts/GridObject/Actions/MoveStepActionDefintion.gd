extends BaseActionDefinition
class_name MoveStepActionDefinition


func can_execute(parameters : Dictionary) -> Dictionary:
	var ret_val = {"can_execute": false, "cost" : -1, "reason" : "N/A"}
	
	var temp_cost = 0
		
	var neighbors = GridSystem.get_grid_cell_neighbors(parameters["from_grid_cell"])
	
	if !neighbors.has(parameters["target_grid_cell"]):
		ret_val["can_execute"] = false
		ret_val["cost"] = -1
		ret_val["reason"] = "Not adjacent neighbor: " + str(parameters["from_grid_cell"].gridCoordinates) +" "+str(parameters["target_grid_cell"].gridCoordinates)
		return ret_val
	
	var result = RotationHelperFunctions.get_rotation_info(parameters["unit"].grid_position_data.direction,
			 parameters["unit"].grid_position_data.grid_cell, parameters["target_grid_cell"])
		
	if result["needs_rotation"] == true:
		temp_cost += 1 * result["rotation_steps"]
	temp_cost += 4
	
		
	if parameters["unit"].get_stat_by_name("TimeUnits").current_value < temp_cost:
		ret_val["can_execute"] = false
		ret_val["cost"] = temp_cost
		ret_val["reason"] = "Not enough Time Units!"
		
	ret_val["can_execute"] = true
	ret_val["cost"] = temp_cost
	ret_val["reason"] = "success!"
	return ret_val
