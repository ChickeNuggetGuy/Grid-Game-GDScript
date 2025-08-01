extends CompositeAction

func _init(parameters : Dictionary) -> void:
	name = "Move Step"
	cost = 4 
	owner = parameters["unit"]
	target_grid_cell = parameters["target_grid_cell"]
	start_grid_cell = parameters["start_grid_cell"]
	print("MoveStepAction created with base cost: ", cost)

func _setup():
	return
	
func _execute() -> void:
	if start_grid_cell == target_grid_cell:
		return
	
	# Check if rotation is needed
	var dir_dictionary = RotationHelperFunctions.get_direction_between_cells(
		start_grid_cell,
		target_grid_cell
	)
	
	if dir_dictionary["direction"] != owner.grid_position_data.direction:
		var get_action_result = owner.try_get_action_definition_by_type("RotateActionDefinition")
		
		if get_action_result["success"] == false:
			return
	
		var rotate_action_node : RotateActionDefinition = get_action_result["action_definition"]
		var rotate_action = rotate_action_node.instantiate({"unit" : owner,"start_grid_cell" : start_grid_cell,"target_grid_cell" : target_grid_cell})
		sub_actions.append(rotate_action)
	
	await super._execute()
		
	var move_tween = owner.create_tween()
	move_tween.tween_property(owner, "position", target_grid_cell.worldPosition, 0.5)
	await move_tween.finished

func _action_complete() -> void:
	#var success = owner.try_spend_stat_value("TimeUnits", cost)
	#var remaining = owner.get_stat_by_name("TimeUnits").current_value
	owner.grid_position_data.set_grid_cell(target_grid_cell)
