@abstract extends  Node
class_name ActionNode

@export_category("Core")
@export var action_script: Script
@export_category("Core")
@export var cost: int

@abstract func can_execute(parrent_gridObject:GridObject,from_cell: GridCell, target_grid_cell : GridCell) -> Dictionary
# factory method: builds a fresh Action instance
func instantiate(owner: GridObject, start_cell:GridCell, target_cell :GridCell , custom_cost : int = -1) -> Action:
	var a: Action = action_script.new(owner, start_cell, target_cell)
	a.name  = name

	return a
