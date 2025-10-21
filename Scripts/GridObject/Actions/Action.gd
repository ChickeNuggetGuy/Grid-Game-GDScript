@abstract extends RefCounted
class_name Action

var action_name: String 
var costs: Dictionary[String, int]
var owner: GridObject = null
var start_grid_cell: GridCell = null
var target_grid_cell: GridCell = null
var multiple_executions : bool


var execution_parameters : Dictionary

func _init(parameters : Dictionary) -> void:
	execution_parameters = parameters
	parameters["action_name"] = action_name
	owner  = parameters["unit"]
	start_grid_cell = parameters["start_grid_cell"]
	target_grid_cell = parameters["target_grid_cell"]

func execute_call() -> void:
	@warning_ignore("redundant_await")
	await _setup()
	@warning_ignore("redundant_await")
	await _execute()
	await _action_complete_call()
	
@abstract func _setup() -> void
@abstract func _execute() -> void



func _action_complete_call() -> void:
	await _action_complete()
	var unit_action_manager = GameManager.managers["UnitActionManager"]
	_spend_unit_stats()
	if not multiple_executions:
		unit_action_manager._set_selected_action(
				owner.try_get_action_definition_by_type("MoveActionDefinition")["action_definition"])
	unit_action_manager.any_action_execution_finished.emit(unit_action_manager.selected_action,execution_parameters)




@abstract func _action_complete()

func _spend_unit_stats():
	if costs == null:
		push_warning("Costs are null, this is almost certainly an error!")
		return
	
	for cost_key in costs.keys():
		var result = owner.try_spend_stat_value(cost_key,costs[cost_key])
		if result["success"] == false:
			push_error("Unit could not afford action: " + str(cost_key) + " of cost: " + str(costs[cost_key]) + " this so=hould not be possible and should be validated otherwise")
			
