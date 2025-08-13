extends BaseItemActionDefinition
class_name ThrowActionDefinition



func _init() -> void:
	action_name = "Throw"
	script_path = "res://Scripts/InventorySystem/ItemActions/ThrowAction.gd"
	super._init()



func get_valid_grid_cells(starting_grid_cell : GridCell) -> Array[GridCell]:
	var walkable_empty_filter = Enums.cellState.GROUND | Enums.cellState.EMPTY
	var result = Manager.get_instance("GridSystem").try_get_neighbors_in_radius(starting_grid_cell, Vector2i(8,5), walkable_empty_filter)
	
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
	
	var temp_cost = 0
	
	var result = RotationHelperFunctions.get_rotation_info(parameters["unit"].grid_position_data.direction,
			 parameters["unit"].grid_position_data.grid_cell, parameters["target_grid_cell"])
		
	if result["needs_rotation"] == true:
		temp_cost += 1 * result["rotation_steps"]
	temp_cost += 8
	
	var calc_arc_result = Pathfinder.Instance.try_calculate_arc_path(parameters["start_grid_cell"], parameters["target_grid_cell"])
		
	if  calc_arc_result["success"]:
		var previous_vector :Vector3 = calc_arc_result["vector3_path"][0]
		for i in range(1,calc_arc_result["vector3_path"].size()):
				
			DebugDraw3D.draw_line(previous_vector, calc_arc_result["vector3_path"][i],Color.BLACK, 10)
			previous_vector = calc_arc_result["vector3_path"][i]
			
			
		for cell in calc_arc_result["grid_cell_path"]:
			var grid_cell : GridCell = cell
			DebugDraw3D.draw_box(grid_cell.world_position, Quaternion.IDENTITY,Vector3(1, 0.5, 1 ), Color.AQUAMARINE,true, 10.0)
			
			
	return { "success" : calc_arc_result["success"], "cost" : temp_cost}
