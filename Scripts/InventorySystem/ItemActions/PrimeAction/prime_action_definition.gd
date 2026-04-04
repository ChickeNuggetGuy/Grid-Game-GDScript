extends BaseItemActionDefinition
class_name PrimeActionDefinition


func _init() -> void:
	action_name = "Prime"
	script_path = "res://Scripts/InventorySystem/ItemActions/primeAction/prime_action.gd"
	multiple_exectutions = false
	super._init()
	

func double_click_call(parameters : Dictionary) -> void:
	return


func double_click_clear(parameters : Dictionary) -> void:
	return


func get_can_cancel_action() -> bool: return false

func get_valid_grid_cells(starting_grid_cell : GridCell) -> Array[GridCell]:
	return []


func _get_AI_action_scores(starting_grid_cell : GridCell) -> Dictionary[GridCell, float]:
	var ret_value :  Dictionary[GridCell, float] = {starting_grid_cell: 0}
	return ret_value


func can_execute(_parameters : Dictionary) -> Dictionary:
	var ret_value = {"success": false, "costs" : {Enums.Stat.TIMEUNITS : -1, Enums.Stat.STAMINA : -1}, "reason" : "N/A", "extra_parameters": {}}
	
	var temp_costs = {Enums.Stat.TIMEUNITS: 0, Enums.Stat.STAMINA : 0}
	
	var result  = parent_item.try_get_item_component("ExplosiveComponent")
	
	if result["success"] == false:
		ret_value["success"] = false
		ret_value["reason"] = "Item is not primable " + result["reason"]
		return ret_value
	
	
	for cost in result["component"].costs:
		temp_costs[cost] += result["component"].costs[cost
	]
	ret_value["success"] = true
	ret_value["extra_parameters"]["explosive_component"] = result["component"]
	ret_value["costs"] = temp_costs
	return ret_value
