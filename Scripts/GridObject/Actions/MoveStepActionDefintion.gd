extends BaseActionDefinition
class_name MoveStepActionDefinition



func _init() -> void:
	script_path = "res://Scripts/GridObject/Actions/MoveStepAction.gd"
	super._init()



func can_execute(parameters : Dictionary) -> Dictionary:
	var ret_val = {"success": false, "costs" : {"time_units" : -1, "stamina" : -1}, "reason" : "N/A"}
	
	var temp_cost = {"time_units" : 0, "stamina" : 0}
		
	var neighbors = GridSystem.get_grid_cell_neighbors(parameters["start_grid_cell"])
	
	if !neighbors.has(parameters["target_grid_cell"]):
		ret_val["success"] = false
		ret_val["costs"]["time_units"] = -1
		ret_val["costs"]["stamina"] = -1
		ret_val["reason"] = "Not adjacent neighbor: " + str(parameters["start_grid_cell"].gridCoordinates) +" "+str(parameters["target_grid_cell"].gridCoordinates)
		return ret_val
	
	var result = RotationHelperFunctions.get_rotation_info(parameters["unit"].grid_position_data.direction,
			 parameters["unit"].grid_position_data.grid_cell, parameters["target_grid_cell"])
		
	if result["needs_rotation"] == true:
		temp_cost["time_units"] += 1 * result["rotation_steps"]
		temp_cost["stamina"] += 1 * result["rotation_steps"]
	temp_cost["time_units"] += 4
	
		
	if parameters["unit"].get_stat_by_name("time_units").current_value < temp_cost["time_units"]:
		ret_val["success"] = false
		ret_val["costs"] = temp_cost
		ret_val["reason"] = "Not enough Time Units!"
	
	if parameters["unit"].get_stat_by_name("stamina").current_value < temp_cost["stamina"]:
		ret_val["success"] = false
		ret_val["costs"] = temp_cost
		ret_val["reason"] = "Not enough Time Units!"
			
	ret_val["success"] = true
	ret_val["costs"] = temp_cost
	ret_val["reason"] = "success!"
	return ret_val
