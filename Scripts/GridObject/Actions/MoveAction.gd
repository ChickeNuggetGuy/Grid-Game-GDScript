extends CompositeAction

func _init(grid_object : GridObject,start : GridCell, target : GridCell) -> void:
	name = "Move"
	cost = 0
	owner = grid_object
	target_grid_cell = target
	start_grid_cell = start


func _setup() -> void:
	return



func _execute() -> void:
	
	var path = Pathfinder.find_path(
	owner.grid_position_data.grid_cell,
	target_grid_cell
	)
	#var path : Array[GridCell] = Pathfinder.find_path(owner.grid_position_data.grid_cell, target_grid_cell)
	
	var move_action_node : MoveStepActionNode = owner.get_action_node_by_name("MoveStep")
	for i in range(path.size() - 1):
		
		var from_cell: GridCell = path[i]
		var to_cell: GridCell = path[i + 1]
		
		if from_cell == null: continue
		if to_cell == null: continue
		if to_cell == from_cell: continue
		
		var move_step_action = move_action_node.instantiate(owner,from_cell, to_cell)
		sub_actions.append(move_step_action)

	await super._execute()
			


func _action_complete() -> void:
	owner.grid_position_data.set_grid_cell(target_grid_cell)
	
