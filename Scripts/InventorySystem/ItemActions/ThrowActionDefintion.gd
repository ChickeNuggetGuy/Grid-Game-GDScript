extends BaseItemActionDefinition
class_name ThrowActionDefinition

var owned_item : Item

# factory method: builds a fresh Action instance:
func can_execute(parameters : Dictionary) -> Dictionary:
		var calc_arc_result = Pathfinder.try_calculate_arc_path(parameters["from_grid_cell"], parameters["target_grid_cell"])
		
		return { "success" : calc_arc_result["success"], "cost" : 10 }
