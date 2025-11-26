extends BaseActionDefinition
class_name ChangeStanceActionDefinition

@export var target_stance : Enums.UnitStance


func get_valid_grid_cells(starting_grid_cell : GridCell) -> Array[GridCell]:
	return []


func _get_AI_action_scores(starting_grid_cell : GridCell) -> Dictionary[GridCell, float]:
	var ret_value : Dictionary[GridCell, float]= {null : -1}
	return ret_value



func double_click_call(parameters : Dictionary) -> void:
	return


func double_click_clear(parameters : Dictionary) -> void:
	return



func _init() -> void:
	script_path = "res://Scripts/GridObject/Actions/ChangeStance/ChanageStanceAction.gd"
	super._init()

func can_execute(parameters : Dictionary) -> Dictionary:
	var ret_val = {"success": false, "costs" : {Enums.Stat.TIMEUNITS : -1, Enums.Stat.STAMINA : -1}, "reason" : "N/A", "extra_parameters": {}}
	
	var temp_costs = {Enums.Stat.TIMEUNITS: 0, Enums.Stat.STAMINA : 0}
	
	var results =  parameters["unit"].check_stat_values(temp_costs)
	
	if results["success"] == false:
		ret_val["success"] = false
		ret_val["costs"][Enums.Stat.TIMEUNITS] = -1
		ret_val["costs"][Enums.Stat.STAMINA] = -1
		ret_val["reason"] = "not enough stats"
		return ret_val
	else:
		ret_val["success"] = true
		ret_val["costs"][Enums.Stat.TIMEUNITS] = temp_costs[Enums.Stat.TIMEUNITS]
		ret_val["costs"][Enums.Stat.STAMINA] = temp_costs[Enums.Stat.STAMINA]
		ret_val["reason"] = "not enough stats"
		return ret_val
		

func get_can_cancel_action() -> bool: return false
