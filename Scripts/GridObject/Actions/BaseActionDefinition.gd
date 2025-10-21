@abstract extends  Resource
class_name BaseActionDefinition

@export_category("Core")
var script_path : String
var action_script: Script
@export_category("Core")
@export var action_name: String
@export_category("Core")
@export var show_in_ui: bool = false
@export_category("Core")
@export var cost: int
@export var multiple_exectutions : bool = true
@export var extra_parameters : Dictionary
@export var double_click_activation : bool = false


@abstract func double_click_call(parameters : Dictionary) -> void
@abstract func double_click_clear(parameters : Dictionary) -> void

@abstract func can_execute(parameters : Dictionary) -> Dictionary
@abstract func get_valid_grid_cells(starting_grid_cell : GridCell) -> Array[GridCell]

@abstract func _get_AI_action_scores(starting_grid_cell : GridCell) -> Dictionary[GridCell, float]

func calculate_best_AI_action_score(starting_grid_cell : GridCell) -> Dictionary:
	var ret_value = {"grid_cell" : null, "action_score" : -1.0}
	var ai_action_scores = _get_AI_action_scores(starting_grid_cell)
	
	if ai_action_scores.is_empty():
		return ret_value
	
	var max_value : float = -INF  # Use negative infinity for proper comparison
	var max_key = starting_grid_cell
	
	for key in ai_action_scores.keys():
		var test_value : float = ai_action_scores[key]
		if test_value > max_value:
			max_value = test_value
			max_key = key
	
	ret_value["grid_cell"] = max_key
	ret_value["action_score"] = max_value
	print(str(max_value))
	return ret_value


func _init() -> void:
	if script_path == null or script_path == "":
		push_error("Script path for: " + self.action_name+ " is invalid!")
		return
	load_action_script()


func load_action_script():
		action_script = load(script_path)


func instantiate(parameters : Dictionary) -> Action:
	if action_script == null:
		load_action_script()
	var a: Action = action_script.new(parameters)
	a.action_name  = self.resource_name
	return a


func _sort_by_action_score(a: float, b: float) -> bool:
	return a > b
