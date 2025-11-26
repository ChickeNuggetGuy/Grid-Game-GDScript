extends BaseActionDefinition
class_name InteractActionDefinition

@export var attack_count : int

func _init() -> void:
	action_name = "Interact"
	script_path = "res://Scripts/GridObject/Actions/InteractAction/InteractAction.gd"
	multiple_exectutions = false
	super._init()
	

func double_click_call(parameters : Dictionary) -> void:
	return


func double_click_clear(parameters : Dictionary) -> void:
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
		
		if not cell.grid_object is Interactable:
			continue
			
		if  cell.grid_object == grid_object:
					continue
			
		if cell == starting_grid_cell:
			continue
		
		grid_cells.append(cell)
	
	return grid_cells


func _get_AI_action_scores(starting_grid_cell : GridCell) -> Dictionary[GridCell, float]:
	var ret_value :  Dictionary[GridCell, float] = {}
	
	for grid_cell in get_valid_grid_cells(starting_grid_cell):
		
		if grid_cell.has_grid_object() and grid_cell.grid_object is Interactable:
			ret_value[grid_cell] = 0.2
		else:
			ret_value[grid_cell] = 0
		#var distance_between_cells  = grid_system.get_distance_between_grid_cells(starting_grid_cell,grid_cell)
		#var normalized_distance : float = clamp(distance_between_cells / 100, 0.0, 1.0)
		
	
	return ret_value


func can_execute(parameters : Dictionary) -> Dictionary:
	var ret_value = {"success": false, "costs" : {Enums.Stat.TIMEUNITS : -1, Enums.Stat.STAMINA : -1}, "reason" : "N/A", "extra_parameters": {}}
	
	var temp_costs = {Enums.Stat.TIMEUNITS: 0, Enums.Stat.STAMINA : 0}
	
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
	
	temp_costs[Enums.Stat.TIMEUNITS] += interactable.costs[Enums.Stat.TIMEUNITS]
	temp_costs[Enums.Stat.STAMINA] += interactable.costs[Enums.Stat.STAMINA]
	ret_value["success"] = true
	ret_value["costs"] = temp_costs
	return ret_value
