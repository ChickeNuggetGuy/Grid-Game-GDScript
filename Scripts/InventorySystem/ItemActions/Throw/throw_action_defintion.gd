extends BaseItemActionDefinition
class_name ThrowActionDefinition



func _init() -> void:
	action_name = "Throw"
	script_path = "res://Scripts/InventorySystem/ItemActions/Throw/throw_action.gd"
	super._init()

func double_click_call(parameters : Dictionary) -> void:
	if parameters.has("path"):
		print(parameters["path"].size())


func double_click_clear(_parameters : Dictionary) -> void:
	return

func get_can_cancel_action() -> bool: return false

func get_valid_grid_cells(starting_grid_cell : GridCell) -> Array[GridCell]:
	var walkable_empty_filter = Enums.cellState.GROUND | Enums.cellState.EMPTY
	var result = GameManager.managers["GridSystem"].try_get_neighbors_in_radius(starting_grid_cell, Vector2i(8,5), walkable_empty_filter)
	
	if result["success"] == false:
		push_error(" no grid cells found that satisfy the current filter")
	
	return result["grid_cell_array"]


func _get_AI_action_scores(starting_grid_cell : GridCell) -> Dictionary[GridCell, float]:
	var ret_value : Dictionary[GridCell, float] = {starting_grid_cell : -1}
	#
	#var grid_system : GridSystem = GridSystem.Instance
	#for grid_cell in get_valid_grid_cells(starting_grid_cell):
		#var distance_between_cells  = grid_system.get_distance_between_grid_cells(starting_grid_cell,grid_cell)
		#var normalized_distance : float = clamp(distance_between_cells / 100, 0.0, 1.0)
		#ret_value[grid_cell] = normalized_distance
	
	return ret_value


func can_execute(parameters : Dictionary) -> Dictionary:
	var ret_val = {"success": false, "costs" : {Enums.Stat.TIMEUNITS : -1, Enums.Stat.STAMINA : -1}, "reason" : "N/A", "extra_parameters" : {}}
	
	
	var unit : Unit = parameters["unit"]
	var temp_costs = {Enums.Stat.TIMEUNITS : 0, Enums.Stat.STAMINA : 0}
	
	var result = RotationHelperFunctions.get_rotation_info(parameters["unit"].grid_position_data.direction,
			 parameters["unit"].grid_position_data.grid_cell, parameters["target_grid_cell"])
		
	if result["needs_rotation"] == true:
		temp_costs[Enums.Stat.TIMEUNITS] += 1 * result["rotation_steps"]

	#Throw costs
	#TODO: Make the tro cost use item stats such as weight.
	temp_costs[Enums.Stat.TIMEUNITS] += 8 
	temp_costs[Enums.Stat.TIMEUNITS] += 16
	
	var calc_arc_result = Pathfinder.try_calculate_arc_path(parameters["start_grid_cell"], parameters["target_grid_cell"], 3,
	unit.grid_position_data.grid_cells)
		
	if  calc_arc_result["success"]:
		var previous_vector :Vector3 = calc_arc_result["vector3_path"][0]
		for i in range(1,calc_arc_result["vector3_path"].size()):
				
			DebugDraw3D.draw_line(previous_vector, calc_arc_result["vector3_path"][i],Color.BLACK, 10)
			previous_vector = calc_arc_result["vector3_path"][i]
			
			
		for cell in calc_arc_result["grid_cell_path"]:
			var grid_cell : GridCell = cell
			DebugDraw3D.draw_box(grid_cell.world_position, Quaternion.IDENTITY,Vector3(1, 0.5, 1 ), Color.AQUAMARINE,true, 10.0)
			
		ret_val["success"] = true
		ret_val["costs"] = temp_costs
		ret_val["extra_parameters"]["grid_cell_path"] = calc_arc_result["grid_cell_path"]
		ret_val["extra_parameters"]["vector3_path"] = calc_arc_result["vector3_path"]
		ret_val["reason"] = "Success"
		return ret_val
	else:
		ret_val["success"] = false
		ret_val["costs"] = 0
		ret_val["reason"] = calc_arc_result["reason"]
		return ret_val
