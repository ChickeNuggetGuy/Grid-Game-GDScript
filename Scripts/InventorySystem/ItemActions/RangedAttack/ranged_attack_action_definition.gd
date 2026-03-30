extends BaseItemActionDefinition
class_name RangedAttackActionDefinition


func _init() -> void:
	action_name = "Ranged Attack"
	script_path = "res://Scripts/InventorySystem/ItemActions/RangedAttack/RangedAttackAction.gd"
	multiple_exectutions = true
	super._init()
	

func double_click_call(_parameters : Dictionary) -> void:
	return


func double_click_clear(_parameters : Dictionary) -> void:
	return


func get_can_cancel_action() -> bool: return true

func get_valid_grid_cells(starting_grid_cell : GridCell) -> Array[GridCell]:

	var grid_object : GridObject = starting_grid_cell.grid_object
	
	var sight_area_result = grid_object.try_get_grid_object_component_by_type("GridObjectSightArea")
	if not sight_area_result["success"]:
		return	[]

	var sight_area: GridObjectSightArea = sight_area_result["grid_object_component"]
	
	
	var grid_cells : Array[GridCell] = []
	for cell in sight_area.seen_cells.values():
		if not cell.has_grid_object():
			continue
			
		if  cell.grid_object == grid_object:
			continue
			
		if cell == starting_grid_cell:
			continue
		
		if cell.grid_object.team == Enums.unitTeam.NONE:
			continue
		
		
		if cell.grid_object.team == grid_object.team:
			continue
		
		grid_cells.append(cell)
	
	return grid_cells


func _get_AI_action_scores(starting_grid_cell : GridCell) -> Dictionary[GridCell, float]:
	var ret_value :  Dictionary[GridCell, float] = {}
	
	for grid_cell in get_valid_grid_cells(starting_grid_cell):
		
		ret_value[grid_cell] = 1

		#var distance_between_cells  = grid_system.get_distance_between_grid_cells(starting_grid_cell,grid_cell)
		#var normalized_distance : float = clamp(distance_between_cells / 100, 0.0, 1.0)
		
	
	return ret_value


func can_execute(parameters : Dictionary) -> Dictionary:
	var ret_val = {"success": false, "costs" : {Enums.Stat.TIMEUNITS : -1, Enums.Stat.STAMINA : -1}, "reason" : "N/A", "extra_parameters" : {}}
	
	var temp_costs = {Enums.Stat.TIMEUNITS : 0, Enums.Stat.STAMINA : 0}
	
	
	var unit = parameters["unit"]
	var target_grid_cell = parameters["target_grid_cell"]
	
	var result = RotationHelperFunctions.get_rotation_info(unit.grid_position_data.direction,
		unit.grid_position_data.grid_cell, target_grid_cell)
		
	if result["needs_rotation"] == true:
		var get_action_result = unit.try_get_action_definition_by_type("RotateActionDefinition")
		if get_action_result["success"] == false:
			# If rotation is needed but the unit cannot rotate, this action cannot be executed.
			push_error("RangedAttackActionDefinition: Unit needs to rotate but lacks RotateActionDefinition.")
			ret_val["reason"] = "Unit needs to rotate but lacks RotateActionDefinition"
			return ret_val
		
		
		temp_costs[Enums.Stat.TIMEUNITS] +=  1 * result["rotation_steps"]

	var sight_area_result = unit.try_get_grid_object_component_by_type("GridObjectSightArea")
	if not sight_area_result["success"]:
		ret_val["reason"] = "Unit has no GridObjectSightArea component"
		push_error("RangedAttackActionDefinition: Unit has no GridObjectSightArea component.")
		return ret_val

	var sight_area: GridObjectSightArea = sight_area_result["grid_object_component"]

	# Check if target cell or target object is in the sight area's lists.
	var target_in_seen_cells = sight_area.seen_cells.has(target_grid_cell.grid_coordinates)
	
	var target_object_is_seen = false
	var target_grid_object = target_grid_cell.grid_object
	if target_grid_object:
		for team_array in sight_area.seen_gridObjects.values():
			if team_array.has(target_grid_object):
				target_object_is_seen = true
				break
	
	if not (target_in_seen_cells or target_object_is_seen):
		ret_val["reason"] = "target cell not seen"
		return ret_val
	
	
	var item_costs : Dictionary = parent_item.item_costs
	
	if not item_costs:
		ret_val["success"] = false
		ret_val["reason"] = "Item does not have cost values"
		return ret_val
	
	for key in item_costs.keys():
		temp_costs[key] += item_costs[key]

	ret_val["success"] = true
	ret_val["costs"] = temp_costs
	return ret_val
