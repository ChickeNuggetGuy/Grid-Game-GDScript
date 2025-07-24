extends ActionNode
class_name MoveStepActionNode


func	 can_execute(parent_gridObject:GridObject,starting_cell : GridCell, target_grid_cell : GridCell) -> Dictionary:
	var ret_val = {"can_execute": false, "cost" : -1, "reason" : "N/A"}
	
	var temp_cost = 0
		
	var neighbors = GridSystem.get_grid_cell_neighbors(starting_cell)
	
	if !neighbors.has(target_grid_cell):
		ret_val["can_execute"] = false
		ret_val["cost"] = -1
		ret_val["reason"] = "Not adjacent neighbor: " + str(starting_cell.gridCoordinates) +" "+str(target_grid_cell.gridCoordinates)
		return ret_val
	
	var result = RotationHelperFunctions.get_rotation_info(parent_gridObject.grid_position_data.direction,
			 parent_gridObject.grid_position_data.grid_cell, target_grid_cell)
		
	if result["needs_rotation"] == true:
		temp_cost += 1 * result["rotation_steps"]
	temp_cost += 4
	
		
	if parent_gridObject.get_stat_by_name("TimeUnits").current_value < temp_cost:
		ret_val["can_execute"] = false
		ret_val["cost"] = temp_cost
		ret_val["reason"] = "Not enough Time Units!"
		
	ret_val["can_execute"] = true
	ret_val["cost"] = temp_cost
	ret_val["reason"] = "success!"
	return ret_val
