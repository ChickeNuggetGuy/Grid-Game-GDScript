extends BaseActionDefinition
class_name MoveActionDefinition



func _init() -> void:
	script_path = "res://Scripts/GridObject/Actions/MoveAction/MoveAction.gd"
	super._init()

func double_click_call(_parameters : Dictionary) -> void:
	var cell_size : Vector2 = GameManager.managers["MeshTerrainManager"].cell_size
	if _parameters.has("path"):
		for cell in _parameters["path"]:
			var grid_cell : GridCell = cell as GridCell
			DebugDraw3D.draw_box((grid_cell.grid_coordinates as Vector3) +Vector3(cell_size.x, cell_size.y, cell_size.x) /2 , Quaternion.IDENTITY, Vector3.ONE, Color.MEDIUM_VIOLET_RED, true, 10)


func double_click_clear(_parameters : Dictionary) -> void:
	return


func get_can_cancel_action() -> bool: return true


func get_valid_grid_cells(starting_grid_cell : GridCell) -> Array[GridCell]:
	var walkable_empty_filter = Enums.cellState.WALKABLE
	var result = GameManager.managers["GridSystem"].try_get_neighbors_in_radius(starting_grid_cell, 8, walkable_empty_filter)

	if result["success"] == false:
		push_error(" no grid cells found that satisfy the current filter")
	
	var grid_cells : Array[GridCell] = result["grid_cells"]
	for i in range(grid_cells.size() - 1, -1, -1):
		if not Pathfinder.is_path_possible(starting_grid_cell, grid_cells[i]):
			grid_cells.remove_at(i)
			
	return grid_cells


func _get_AI_action_scores(starting_grid_cell : GridCell) -> Dictionary[GridCell, float]:
	var ret_value : Dictionary[GridCell, float]= {}
	
	for grid_cell in get_valid_grid_cells(starting_grid_cell):
		var distance_between_cells  = GameManager.managers["GridSystem"].get_distance_between_grid_cells(starting_grid_cell,grid_cell)
		var normalized_distance : float = clamp(distance_between_cells / 100, 0.0, 0.8)
		ret_value[grid_cell] = normalized_distance
	
	return ret_value


func can_execute(parameters : Dictionary) -> Dictionary:
	var ret_val = {"success": false, "costs" : {Enums.Stat.TIMEUNITS : -1, Enums.Stat.STAMINA : -1}, "reason" : "N/A", "extra_parameters" : {}}
	
	var temp_costs = {Enums.Stat.TIMEUNITS : 0, Enums.Stat.STAMINA : 0}
	
	# Check if path is possible first
	#if not Pathfinder.is_path_possible(parameters["unit"].grid_position_data.grid_cell, parameters["target_grid_cell"] ):
		#print("Path not possible from")
		#ret_val["success"] = false
		#ret_val["costs"][Enums.Stat.TIMEUNITS] = -1
		#ret_val["costs"][Enums.Stat.STAMINA] = -1
		#ret_val["reason"] = "No path possible!"
		#return ret_val
	#
	var path : Array[GridCell] = Pathfinder.find_path(parameters["start_grid_cell"], parameters["target_grid_cell"])
	
	if path == null or path.size() <= 1:  # Need at least 2 cells (start and target)
		print("Path not found or too short!")
		ret_val["success"] = false
		ret_val["costs"][Enums.Stat.TIMEUNITS] = -1
		ret_val["costs"][Enums.Stat.STAMINA] = -1
		ret_val["reason"] = "No path found!"
		return ret_val
	
	var current_gridCell: GridCell = parameters["start_grid_cell"]
	
	# Iterate through path segments (from current cell to next cell)
	for i in range(path.size() - 1):
		
		var from_cell: GridCell = path[i]
		var to_cell: GridCell = path[i + 1]
		
		# If we're not starting from the unit's current position, update tracking variables
		if i == 0 and from_cell != current_gridCell:
			# This shouldn't happen, but just in case
			current_gridCell = from_cell
		
		var get_action_result = parameters["unit"].try_get_action_definition_by_type("MoveStepActionDefinition")
		if get_action_result["success"] == false:
			return ret_val
		var move_step_result = get_action_result["action_definition"].can_execute({
				"unit": parameters["unit"], 
				"start_grid_cell": from_cell, 
				"target_grid_cell": to_cell
				})
		
		if move_step_result["success"] == false:
			ret_val["success"] = false
			ret_val["costs"][Enums.Stat.TIMEUNITS] = -1
			ret_val["costs"][Enums.Stat.STAMINA] = -1
			ret_val["reason"] = "move step failed: " + move_step_result["reason"]
			return ret_val
		else:
			for key in temp_costs.keys():
				temp_costs[key] += move_step_result["costs"][key]
	
	
	
	print("Move action can be executed. costs: ", temp_costs)
	ret_val["success"] = true
	ret_val["costs"] = temp_costs
	ret_val["reason"] = "success"
	ret_val["extra_parameters"]["path"] = path
	return ret_val


static func get_move_cost_values(grid_object: GridObject, path: Array[GridCell]) -> Dictionary[GridCell, Dictionary]:
	if not grid_object or not path or path.is_empty():
		return {}

	var ret_dict: Dictionary[GridCell, Dictionary] = {}

	var current_grid_cell: GridCell = grid_object.grid_position_data.grid_cell
	var current_direction: Enums.facingDirection = grid_object.grid_position_data.direction

	# Initialize cumulative totals
	var total_time_units: int = 0
	var total_stamina: int = 0

	for i in range(path.size()):
		var cell: GridCell = path[i]
		if current_grid_cell == cell:
			continue

		# Get rotation information to move to this cell
		var result: Dictionary = RotationHelperFunctions.get_rotation_info(current_direction, current_grid_cell, cell)

		# Calculate immediate costs for this step
		var step_time_units: int = 0
		var step_stamina: int = 0

		# Add time cost for rotation if needed
		if result.get("needs_rotation", false):
			step_time_units += 1 * result["rotation_steps"]

		# Add fixed movement costs
		step_time_units += 4
		step_stamina += 2

		# Accumulate totals
		total_time_units += step_time_units
		total_stamina += step_stamina

		# Store cumulative values at this point in the path
		ret_dict[cell] = {
			"time_units": total_time_units,
			"stamina": total_stamina
		}

		# Update position and direction for next iteration
		current_grid_cell = cell
		if result.has("target_direction"):
			current_direction = result["target_direction"]

	return ret_dict
