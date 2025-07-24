@abstract extends RefCounted
class_name Action

var name: String = ""
var cost: int = 0
var owner: GridObject = null
var start_grid_cell: GridCell = null
var target_grid_cell: GridCell = null



func _init(grid_object : GridObject, start_cell:GridCell , target_cell : GridCell) -> void:
	owner  =grid_object
	start_grid_cell = start_cell
	target_grid_cell = target_cell

func execute_call() -> void:
	await _execute()
	await _action_complete_call()
	
@abstract func _setup() -> void
@abstract func _execute() -> void
func _action_complete_call() -> void:
	await _action_complete()
@abstract func _action_complete()
