extends CompositeAction

func _init(parameters : Dictionary) -> void:
	action_name = "Move Step"
	costs = {"time_units" : 4, "stamina" : 1 }
	owner = parameters["unit"]
	target_grid_cell = parameters["target_grid_cell"]
	start_grid_cell = parameters["start_grid_cell"]
	#print("MoveStepAction created with base cost: ", parameters)

func _setup() -> void:
	#owner.grid_object_animator.start_locomotion_animation(owner.get_stance(), Vector2(0.5,0))
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
	move_tween.tween_property(owner, "position", target_grid_cell.world_position, 0.5)
	await move_tween.finished

func _action_complete() -> void:
	#var remaining = owner.get_stat_by_name("TimeUnits").current_value
	owner.grid_position_data.set_grid_cell(target_grid_cell)
	owner.gridObject_moved.emit(owner, target_grid_cell)
