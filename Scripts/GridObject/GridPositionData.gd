class_name GridPositionData
extends Node

#region Variables
var parent_gridobject : GridObject
var grid_cell : GridCell = null
var direction : Enums.facingDirection = Enums.facingDirection.NONE
#endregion
#region Signals
signal grid_position_data_updated(grid_cell : GridCell)
#endregion
#region Functions
func _init(parent : GridObject, cell : GridCell, dir : Enums.facingDirection):
	parent_gridobject = parent
	set_grid_cell(cell)
	cell.set_gridobject(parent, cell.grid_cell_state)
	set_direction(dir)


func set_direction(dir :Enums.facingDirection, update_transform : bool = false):
	direction = dir
	if update_transform:
		var canonical_yaw = RotationHelperFunctions.get_yaw_for_direction(dir)
		var start_yaw = parent_gridobject.rotation.y
		var delta = wrapf(canonical_yaw - start_yaw, -PI, PI)
		var target_yaw = start_yaw + delta
		parent_gridobject.rotation = Vector3(0,target_yaw,0)
		


func set_grid_cell(target_grid_cell: GridCell):
	if target_grid_cell == null:
		print("gridcell is null, returning")
		return
		
	if grid_cell != null:
		grid_cell.set_gridobject(null, grid_cell.grid_cell_state)
	
	grid_cell = target_grid_cell

	# Remove the WALKABLE state if it's set
	var new_state = target_grid_cell.grid_cell_state & ~Enums.cellState.WALKABLE
	grid_cell.set_gridobject(parent_gridobject, new_state as Enums.cellState)

	grid_position_data_updated.emit(target_grid_cell)
#endregion
