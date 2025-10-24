extends BaseActionDefinition
class_name RotateActionDefinition




func _init() -> void:
	script_path = "res://Scripts/GridObject/Actions/Rotate/RotateAction.gd"
	super._init()


func double_click_call(parameters : Dictionary) -> void:
	return


func double_click_clear(parameters : Dictionary) -> void:
	return



func get_valid_grid_cells(_starting_grid_cell : GridCell) -> Array[GridCell]:
	return []


func _get_AI_action_scores(starting_grid_cell : GridCell) -> Dictionary[GridCell, float]:
	var ret_value : Dictionary[GridCell, float] = {starting_grid_cell : -1}
	return ret_value

func can_execute(parameters : Dictionary) -> Dictionary:
	var ret_val = {"success": false, "costs" : {"time_units" : -1, "stamina" : -1}, "reason" : "N/A"}
	var temp_costs =  {"time_units" : 0, "stamina" : 0}
	
	var rotate_result = RotationHelperFunctions.get_rotation_info(parameters["unit"].grid_position_data.direction,
		parameters["start_grid_cell"], parameters["target_grid_cell"])
		
	if rotate_result["needs_rotation"] == true:
		temp_costs["time_units"] += 1 * (rotate_result["rotation_steps"] )
		temp_costs["stamina"] += 1 * (rotate_result["rotation_steps"] )
	else:
		ret_val["success"] = false
		ret_val["costs"]["time_units"] = -1
		ret_val["costs"]["stamina"] = -1
		ret_val["reason"] = "No rotation needed"
		return ret_val
	
	var result = parameters["unit"].check_stat_values(temp_costs)
	
	if result["success"] == false:
		ret_val["success"] = false
		ret_val["costs"] = temp_costs
		ret_val["reason"] =result["reason"]
		return ret_val
		
	
	ret_val["success"] = true
	ret_val["costs"] = temp_costs
	ret_val["reason"] = "Success!"
	return ret_val
