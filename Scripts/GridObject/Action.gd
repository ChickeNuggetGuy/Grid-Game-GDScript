extends RefCounted
class_name Action

var name: String = ""
var cost: int = 0
var owner: GridObject = null
var target_grid_cell: GridCell = null

func can_execute() -> bool:
	return owner.ap >= cost

func execute() -> void:
	push_error("execute() not implemented for %s" % self)
