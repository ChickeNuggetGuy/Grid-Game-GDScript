extends BaseItemActionDefinition
class_name MeleeAttackActionDefinition

@export var attack_count : int

func _init() -> void:
	action_name = "Melee Attack"
	script_path = "res://Scripts/InventorySystem/ItemActions/MeleeAttack/MeleeAttackAction.gd"
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
		
		#if not grid_cell.has_grid_object():
		ret_value[grid_cell] = 1 if grid_cell.has_grid_object() else 0
		#else:
			#ret_value[grid_cell] = 1
		#var distance_between_cells  = grid_system.get_distance_between_grid_cells(starting_grid_cell,grid_cell)
		#var normalized_distance : float = clamp(distance_between_cells / 100, 0.0, 1.0)
		
	
	return ret_value


func can_execute(parameters : Dictionary) -> Dictionary:
	var ret_value = {"success": false, "costs" : {Enums.Stat.TIMEUNITS : -1, Enums.Stat.STAMINA : -1}, "reason" : "N/A", "extra_parameters": {}}
	
	var temp_costs = {Enums.Stat.TIMEUNITS : 0, Enums.Stat.STAMINA : 0}
	
	if not parent_item :
		ret_value["success"] = false
		ret_value["reason"] = "Item was null"
		return ret_value
	
	var neighboring_cells : Array[GridCell] = GameManager.managers["GridSystem"].get_grid_cell_neighbors(parameters["target_grid_cell"], Enums.cellState.WALKABLE)

	if neighboring_cells.is_empty():
		ret_value["success"] = false
		ret_value["reason"] = "No valid walkable neighbors found near target"
		return ret_value
		
	if neighboring_cells.has(parameters["start_grid_cell"]):
		# Unit is already adjacent, no move needed. Check for rotation.
		print("Does not Need to move")
		var result = RotationHelperFunctions.get_rotation_info(parameters["unit"].grid_position_data.direction,
		parameters["unit"].grid_position_data.grid_cell, parameters["target_grid_cell"])
		
		if result["needs_rotation"] == true:
			var rotate_action_def : RotateActionDefinition = parameters["unit"].try_get_action_definition_by_type("RotateActionDefinition")
			
			if not rotate_action_def:
				ret_value["success"] = false
				ret_value["reason"] = "Unit does not have rotate action which is needed"
				return ret_value
			else:
				var rotate_result = rotate_action_def.can_execute(parameters)
				if not rotate_result["success"]:
					ret_value["success"] = false
					ret_value["reason"] = rotate_result["reason"]
					return ret_value
				else:
					for  rotate_cost in rotate_result["costs"].keys():
						temp_costs[rotate_cost] += rotate_result["costs"][rotate_cost]
				
	else:
		# Unit needs to move. Find the BEST adjacent cell to move to.
		var best_neighbor_cell : GridCell = null
		var shortest_path : Array[GridCell] = []
		var shortest_path_length : int = int(INF) # Use infinity to ensure the first path is always shorter

		for neighbor_cell in neighboring_cells:
			# Find the path from the unit's start to this potential destination
			var current_path = Pathfinder.find_path(parameters["start_grid_cell"], neighbor_cell)
			
			# If a path exists and is shorter than any we've found so far...
			if not current_path.is_empty() and current_path.size() < shortest_path_length:
				# ...this becomes our new best option.
				shortest_path_length = current_path.size()
				best_neighbor_cell = neighbor_cell
				shortest_path = current_path
		
		# After checking all neighbors, if we found a valid path...
		if best_neighbor_cell != null:
			# We have our path and destination. Now we calculate the cost.
			# This assumes each step in the path costs 1 time unit and 1 stamina.
			# Adjust this logic if your MoveStepAction has different costs.
			var move_cost = shortest_path.size() - 1 # Path includes start cell, so length-1 is the number of steps
			temp_costs[Enums.Stat.TIMEUNITS] += move_cost
			temp_costs[Enums.Stat.STAMINA] += move_cost

			# Store the results for the MeleeAttackAction to use
			ret_value["extra_parameters"]["adjacent_target"] = best_neighbor_cell
			ret_value["extra_parameters"]["path"] = shortest_path
		else:
			# If best_neighbor_cell is still null, it means no adjacent cells were reachable.
			ret_value["success"] = false
			ret_value["reason"] = "Target is out of range (no reachable adjacent cell)"
			return ret_value

	attack_count = parent_item.extra_values.get("attack_count", 1)
	var attack_cost = parent_item.extra_values.get("attack_cost", 1)
	
	temp_costs[Enums.Stat.TIMEUNITS] += attack_count * attack_cost
	temp_costs[Enums.Stat.STAMINA] += attack_count * attack_cost
	ret_value["success"] = true
	ret_value["costs"] = temp_costs
	return ret_value
