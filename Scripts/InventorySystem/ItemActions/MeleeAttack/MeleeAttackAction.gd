extends CompositeAction
class_name MeleeAttackAction

var item : Item
var path : Array[GridCell]

const MAX_TWEEN_DURATION := 0.6
const MIN_TWEEN_DURATION := 0.05


func _init(parameters : Dictionary) -> void:
	parameters["action_name"] = "Melee Attack"
	owner = parameters["unit"]
	costs = {"time_units" : 0 }
	target_grid_cell = parameters["target_grid_cell"]
	start_grid_cell = parameters["start_grid_cell"]
	item = parameters["item"]
	
	if parameters.get("path", null) != null:
		path = parameters["path"]
	super._init(parameters)



func _setup():
	return

func _execute() -> bool:
	if path != null:
		var get_action_result  = owner.try_get_action_definition_by_type("MoveActionDefinition")
	
		if get_action_result["success"] ==  false:
			push_error("Unit is missing MoveActionDefinition, cannot move for melee attack.")
			return false
		
		var move_action_def : MoveActionDefinition = get_action_result["action_definition"]
		
		var move_target_cell = path.back()
		var move_action = move_action_def.instantiate({
			"unit": owner,
			"start_grid_cell": owner.grid_position_data.grid_cell,
			"target_grid_cell":  move_target_cell, 
			"path" : path
			})
		sub_actions.append(move_action)

	if not await super._execute():
		return false

	for i in range(item["extra_values"].get("attack_count", 1)):
		var target_grid_object = target_grid_cell.grid_object

		if target_grid_object != null:
			var health_stat = target_grid_object.get_stat_by_name("Health")
			if health_stat != null:
				health_stat.try_remove_value(item["extra_values"].get("damage", 10)) # Value was 100 but print says 10, adjusted for consistency
				print(
					"damaged unit for 10 health. new health is " +
					str(health_stat.current_value)
				)

		await owner.get_tree().create_timer(0.8).timeout
	return true


func _action_complete():
	return


func action_cancel():
	owner.grid_positiondata.detect_grid_position()
