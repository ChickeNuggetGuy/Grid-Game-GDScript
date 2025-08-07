extends BaseActionDefinition
class_name ChangeStanceActionDefinition

@export var target_stance : Enums.UnitStance


func get_valid_grid_cells(starting_grid_cell : GridCell) -> Array[GridCell]:
	return []


func _get_AI_action_scores(starting_grid_cell : GridCell) -> Dictionary[GridCell, float]:
	var ret_value : Dictionary[GridCell, float]= {null : -1}
	return ret_value



func _init() -> void:
	script_path = "res://Scripts/GridObject/Actions/ChanageStanceAction.gd"
	super._init()

func can_execute(parameters : Dictionary) -> Dictionary:
	var ret_val = {"success": false, "costs" : {"time_units" : -1, "stamina" : -1}, "reason" : "N/A"}
	var temp_cost = {"time_units" : 2, "stamina" : 2}
	
	var results =  parameters["unit"].check_stat_values(temp_cost)
	
	if results["success"] == false:
		ret_val["success"] = false
		ret_val["costs"]["time_units"] = -1
		ret_val["costs"]["stamina"] = -1
		ret_val["reason"] = "not enough stats"
		return ret_val
	else:
		ret_val["success"] = true
		ret_val["costs"]["time_units"] = temp_cost["time_units"]
		ret_val["costs"]["stamina"] = temp_cost["stamina"]
		ret_val["reason"] = "not enough stats"
		return ret_val
		
