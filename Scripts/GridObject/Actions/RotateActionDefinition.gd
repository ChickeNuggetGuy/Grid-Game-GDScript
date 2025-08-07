extends BaseActionDefinition
class_name RotateActionDefinition




func _init() -> void:
	script_path = "res://Scripts/GridObject/Actions/RotateAction.gd"
	super._init()

func get_valid_grid_cells(starting_grid_cell : GridCell) -> Array[GridCell]:
	return []


func _get_AI_action_scores(starting_grid_cell : GridCell) -> Dictionary[GridCell, float]:
	var ret_value : Dictionary[GridCell, float] = {starting_grid_cell : -1}
	return ret_value

func can_execute(parameters : Dictionary) -> Dictionary:
	var ret_val = {"success": false, "costs" : {"time_units" : -1, "stamina" : -1}, "reason" : "N/A"}
	var temp_costs =  {"time_units" : 0, "stamina" : 0}
	
	var result = RotationHelperFunctions.get_rotation_info(parameters["unit"].grid_position_data.direction,
		parameters["start_grid_cell"], parameters["target_grid_cell"])
		
	if result["needs_rotation"] == true:
		temp_costs["time_units"] += 1 * (result["rotation_steps"] )
		temp_costs["stamina"] += 1 * (result["rotation_steps"] )
	else:
		ret_val["success"] = false
		ret_val["costs"]["time_units"] = -1
		ret_val["costs"]["stamina"] = -1
		ret_val["reason"] = "No rotation needed"
		return ret_val
	
	if parameters["unit"].get_stat_by_name("time_units").current_value < temp_costs["time_units"] and \
			parameters["unit"].get_stat_by_name("stamina").current_value < temp_costs["stamina"]:
		ret_val["success"] = false
		ret_val["costs"] = temp_costs
		ret_val["reason"] = "Not enough Time Units!"
		return ret_val
	
	ret_val["success"] = true
	ret_val["costs"] = temp_costs
	ret_val["reason"] = "Success!"
	return ret_val
