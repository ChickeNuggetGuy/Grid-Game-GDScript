extends CompositeAction
class_name RangedAttackAction

var item : Item

func _init(parameters : Dictionary) -> void:
	name = "Ranged Attack"
	cost = 12
	owner = parameters["unit"]
	target_grid_cell = parameters["target_grid_cell"]
	start_grid_cell = parameters["start_grid_cell"]
	item = parameters["item"]



func _setup():
	return

func _execute() -> void:
	
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
	
	var throw_visual = CSGSphere3D.new()
	throw_visual.radius = 0.5
	owner.get_tree().root.add_child(throw_visual)
	throw_visual.position =  start_grid_cell.world_position + Vector3(0, 0.5, 0)

	var ranged_tween = owner.create_tween()
	ranged_tween.tween_property(throw_visual, "position", target_grid_cell.world_position + Vector3(0, 0.5, 0), 0.1)
	await ranged_tween.finished
	
	throw_visual.queue_free() 
	
	if target_grid_cell.hasGridObject():
		var health_stat = target_grid_cell.grid_object.get_stat_by_name("Health")  
		if health_stat != null:
			health_stat.try_remove_value(10)
	return



func _action_complete():
	return
