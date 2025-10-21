extends CompositeAction


func _init(parameters : Dictionary) -> void:
	parameters["actiom_name"] = action_name
	owner = parameters["unit"]
	target_grid_cell = parameters["target_grid_cell"]
	start_grid_cell = parameters["start_grid_cell"]
	super._init(parameters)


func _setup() -> void:
	owner.set_motion(Enums.UnitStance.MOVING)
	return



func _execute() -> void:
	
	var path = Pathfinder.find_path(
	owner.grid_position_data.grid_cell,
	target_grid_cell
	)
	#var path : Array[GridCell] = Pathfinder.find_path(owner.grid_position_data.grid_cell, target_grid_cell)
	
	var get_action_result  = owner.try_get_action_definition_by_type("MoveStepActionDefinition")
	
	if get_action_result["success"] ==  false:
		return
		
	var move_action_node : MoveStepActionDefinition = get_action_result["action_definition"]
	for i in range(path.size() - 1):
		
		var from_cell: GridCell = path[i]
		var to_cell: GridCell = path[i + 1]
		
		if from_cell == null: continue
		if to_cell == null: continue
		if to_cell == from_cell: continue
		
		var move_step_action = move_action_node.instantiate({"unit" : owner,"start_grid_cell" : from_cell,"target_grid_cell" : to_cell})
		sub_actions.append(move_step_action)

	await super._execute()
			


func _action_complete() -> void:
	owner.set_motion(Enums.UnitStance.STATIONARY)
	owner.grid_position_data.set_grid_cell(target_grid_cell)
	
