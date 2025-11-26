extends BaseActionDefinition
class_name RotateActionDefinition




func _init() -> void:
	script_path = "res://Scripts/GridObject/Actions/Rotate/RotateAction.gd"
	super._init()


func double_click_call(_parameters : Dictionary) -> void:
	return


func double_click_clear(_parameters : Dictionary) -> void:
	return

func get_can_cancel_action() -> bool: return false

func get_valid_grid_cells(_starting_grid_cell : GridCell) -> Array[GridCell]:
	return []


func _get_AI_action_scores(starting_grid_cell : GridCell) -> Dictionary[GridCell, float]:
	var ret_value : Dictionary[GridCell, float] = {starting_grid_cell : -1}
	return ret_value

func can_execute(parameters : Dictionary) -> Dictionary:
	var ret_val = {"success": false, "costs" : {Enums.Stat.TIMEUNITS : -1, Enums.Stat.STAMINA : -1}, "reason" : "N/A"}
	var temp_costs =  {Enums.Stat.TIMEUNITS : 0, Enums.Stat.STAMINA : 0}
	
	var rotate_result = RotationHelperFunctions.get_rotation_info(parameters["unit"].grid_position_data.direction,
		parameters["start_grid_cell"], parameters["target_grid_cell"])
	
	print( parameters["target_grid_cell"])
	if rotate_result["needs_rotation"] == true:
		temp_costs[Enums.Stat.TIMEUNITS] += 1 * (rotate_result["rotation_steps"] )
		temp_costs[Enums.Stat.STAMINA] += 1 * (rotate_result["rotation_steps"] )
	else:
		ret_val["success"] = false
		ret_val["costs"][Enums.Stat.TIMEUNITS] = -1
		ret_val["costs"][Enums.Stat.STAMINA] = -1
		ret_val["reason"] = "No rotation needed. " + "current: " + str(parameters["unit"].grid_position_data.direction) + " target: " +  str(rotate_result["target_direction"])
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
