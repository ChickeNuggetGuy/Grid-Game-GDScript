extends CompositeAction

var arc_path_results : Dictionary
var item : Item
var starting_inventory : InventoryGrid

func _init(parameters : Dictionary) -> void:
	action_name = "Throw"
	costs = {"time_units" :8, "stamina" : 2}
	owner = parameters["unit"]
	target_grid_cell = parameters["target_grid_cell"]
	start_grid_cell = parameters["start_grid_cell"]
	starting_inventory = parameters["starting_inventory"]
	arc_path_results = Pathfinder.try_calculate_arc_path(start_grid_cell, target_grid_cell)
	item = parameters.get("item")



func _setup() -> void:
	return



func _execute() -> bool:
	
	
	# Check if rotation is needed
	var dir_dictionary = RotationHelperFunctions.get_direction_between_cells(
		start_grid_cell,
		target_grid_cell
	)
	
	if dir_dictionary["direction"] != owner.grid_position_data.direction:
		var get_action_result = owner.try_get_action_definition_by_type("RotateActionDefinition")
		
		if get_action_result["success"] == false:
			return false
	
		var rotate_action_node : RotateActionDefinition = get_action_result["action_definition"]
		var rotate_action = rotate_action_node.instantiate({"unit" : owner, "start_grid_cell" : start_grid_cell,"target_grid_cell" : target_grid_cell})
		sub_actions.append(rotate_action)
	
	
	await super._execute()
	
	var throw_visual = CSGSphere3D.new()
	throw_visual.radius = .08
	owner.get_tree().root.add_child(throw_visual)
	throw_visual.position =  arc_path_results["vector3_path"][0]
	for position in arc_path_results["vector3_path"]:
		
		var throw_tween = owner.create_tween()
		throw_tween.tween_property(throw_visual, "position", position, 0.03)
		await throw_tween.finished
	
	throw_visual.queue_free() 
	
	return true


func _action_complete():
	var end_grid_cell : GridCell =arc_path_results["grid_cell_path"][ arc_path_results["grid_cell_path"].size() - 1]
	InventoryGrid.try_transfer_item(starting_inventory, 
			end_grid_cell.inventory_grid, item)
			
	return


func action_cancel():
	return
