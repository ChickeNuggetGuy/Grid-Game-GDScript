extends BaseActionDefinition
class_name InteractActionDefinition

@export var attack_count : int

func _init() -> void:
	action_name = "Interact"
	script_path = "res://Scripts/GridObject/Actions/InteractAction/InteractAction.gd"
	super._init()
	

func double_click_call(parameters : Dictionary) -> void:
	return


func double_click_clear(parameters : Dictionary) -> void:
	return


func get_can_cancel_action() -> bool: return true

func get_valid_grid_cells(starting_grid_cell : GridCell) -> Array[GridCell]:
	var walkable_empty_filter = Enums.cellState.NONE
	var result = GameManager.managers["GridSystem"].try_get_neighbors_in_radius(starting_grid_cell, 15, walkable_empty_filter)
	
	var grid_object : GridObject = starting_grid_cell.grid_object
	
	var grid_cells : Array[GridCell] = result["grid_cells"]
	for i in range(grid_cells.size() - 1, -1, -1):
		if not grid_cells[i].has_grid_object():
			grid_cells.remove_at(i)
			continue
		
		if not grid_cells[i].grid_object is Interactable:
			grid_cells.remove_at(i)
			continue
			
		if  grid_cells[i].grid_object == grid_object:
					grid_cells.remove_at(i)
					continue
			
		if grid_cells[i] == starting_grid_cell:
			grid_cells.remove_at(i)
	
	if result["success"] == false:
		push_error(" no grid cells found that satisfy the current filter")
	
	return grid_cells


func _get_AI_action_scores(starting_grid_cell : GridCell) -> Dictionary[GridCell, float]:
	var ret_value :  Dictionary[GridCell, float] = {}
	
	for grid_cell in get_valid_grid_cells(starting_grid_cell):
		
		#if not grid_cell.has_grid_object():
		ret_value[grid_cell] = 0.5 if grid_cell.has_grid_object() else 0
		#else:
			#ret_value[grid_cell] = 1
		#var distance_between_cells  = grid_system.get_distance_between_grid_cells(starting_grid_cell,grid_cell)
		#var normalized_distance : float = clamp(distance_between_cells / 100, 0.0, 1.0)
		
	
	return ret_value


func can_execute(parameters : Dictionary) -> Dictionary:
	var ret_value = {"success": false, "costs" : {"time_units" : -1, "stamina" : -1}, "reason" : "N/A", "extra_parameters": {}}
	
	var temp_costs = {"time_units" : 0, "stamina" : 0}
	
	var interactable : Interactable = parameters["target_grid_cell"].grid_object as Interactable
	
	if not interactable:
		ret_value["success"] = false
		ret_value["reason"] = "No valid walkable Interactable"
		return ret_value
		
	var neighboring_cells : Array[GridCell] = GameManager.managers["GridSystem"].get_grid_cell_neighbors(parameters["target_grid_cell"], Enums.cellState.WALKABLE)
	print("Neighboring cell count is: " + str(neighboring_cells.size()))
	
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
					for cost in rotate_result["costs"].keys():
						temp_costs[cost] += rotate_result["costs"][cost]
				
	else:
		# Unit needs to move. Find the BEST adjacent cell to move to.
		var best_neighbor_cell : GridCell = null
		var shortest_path : Array[GridCell] = []
		var shortest_path_length : int = INF

		for neighbor_cell in neighboring_cells:
			# Find the path from the unit's start to this potential destination
			var current_path = Pathfinder.find_path(parameters["start_grid_cell"], neighbor_cell)
			
			# If a path exists and is shorter than any we've found so far...
			if not current_path.is_empty() and current_path.size() < shortest_path_length:
				shortest_path_length = current_path.size()
				best_neighbor_cell = neighbor_cell
				shortest_path = current_path
		
		# After checking all neighbors, if we found a valid path...
		if best_neighbor_cell != null:
			# We have our path and destination. Now we calculate the cost.
			# This assumes each step in the path costs 1 time unit and 1 stamina.
			# Adjust this logic if your MoveStepAction has different costs.
			var move_cost = shortest_path.size() - 1 # Path includes start cell, so length-1 is the number of steps
			temp_costs["time_units"] += move_cost
			temp_costs["stamina"] += move_cost

			# Store the results for the MeleeAttackAction to use
			ret_value["extra_parameters"]["adjacent_target"] = best_neighbor_cell
			ret_value["extra_parameters"]["path"] = shortest_path
		else:
			# If best_neighbor_cell is still null, it means no adjacent cells were reachable.
			ret_value["success"] = false
			ret_value["reason"] = "Target is out of range (no reachable adjacent cell)"
			return ret_value
	
	temp_costs["time_units"] += interactable.costs["time_units"]
	temp_costs["stamina"] += interactable.costs["stamina"]
	ret_value["success"] = true
	ret_value["costs"] = temp_costs
	return ret_value
