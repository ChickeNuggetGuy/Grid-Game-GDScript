class_name GridPositionData
extends Node

#region Variables
var parent_gridobject : GridObject
var grid_cell : GridCell = null
var direction : Enums.facingDirection = Enums.facingDirection.NONE
#endregion

#region Functions
func _init(parent : GridObject, cell : GridCell, dir : Enums.facingDirection):
	parent_gridobject = parent
	self.grid_cell = cell
	cell.set_gridobject(parent)
	self.direction = dir


func set_direction(dir :Enums.facingDirection):
	direction = dir
#endregion
