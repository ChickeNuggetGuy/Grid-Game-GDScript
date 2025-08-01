extends BaseItemActionDefinition
class_name ThrowActionDefinition

var owned_item : Item

func _init() -> void:
	script_path = "res://Scripts/InventorySystem/ItemActions/ThrowAction.gd"

# factory method: builds a fresh Action instance:
func can_execute(parameters : Dictionary) -> Dictionary:
	
	var temp_cost = 0

	var target_direction = RotationHelperFunctions.get_direction_between_cells(parameters["from_grid_cell"], parameters["target_grid_cell"])
	
	var result = RotationHelperFunctions.get_rotation_info(parameters["unit"].grid_position_data.direction,
			 parameters["unit"].grid_position_data.grid_cell, parameters["target_grid_cell"])
		
	if result["needs_rotation"] == true:
		temp_cost += 1 * result["rotation_steps"]
	temp_cost += 8
	
	var calc_arc_result = Pathfinder.try_calculate_arc_path(parameters["from_grid_cell"], parameters["target_grid_cell"])
		
	if  calc_arc_result["success"]:
		var previous_vector :Vector3 = calc_arc_result["vector3_path"][0]
		for i in range(1,calc_arc_result["vector3_path"].size()):
				
			DebugDraw3D.draw_line(previous_vector, calc_arc_result["vector3_path"][i],Color.BLACK, 10)
			previous_vector = calc_arc_result["vector3_path"][i]
			
			
		for cell in calc_arc_result["grid_cell_path"]:
			var grid_cell : GridCell = cell
			DebugDraw3D.draw_box(grid_cell.worldPosition, Quaternion.IDENTITY,Vector3(1, 0.5, 1 ), Color.AQUAMARINE,true, 10.0)
			
			
	return { "success" : calc_arc_result["success"], "cost" : 10}
