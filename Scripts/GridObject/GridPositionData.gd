class_name GridPositionData
extends Node

#region Variables
var parent_gridobject : GridObject
var grid_height : int = 2
var grid_shape : GridShape 
var grid_cells : Array[GridCell] = []
var grid_cell : GridCell :
	get:
		if grid_cells.size() > 0:
			return grid_cells[0]
		return null
var direction : Enums.facingDirection = Enums.facingDirection.NONE
#endregion
#region Signals
signal grid_position_data_updated(grid_cell : GridCell)
#endregion
#region Functions
func _init(parent : GridObject, cell : GridCell, dir : Enums.facingDirection,
		shape : GridShape, height : int = 2):
	parent_gridobject = parent
	grid_cells = []
	set_grid_height(height)
	set_grid_shape(shape)
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

	# Clear previous grid cell references and restore original states
	for cell in grid_cells:
		cell.restore_original_state()
	
	grid_cells.clear()

	if target_grid_cell == null:
		print("gridcell is null, returning")
		return

	# Add the base cell
	grid_cells.append(target_grid_cell)
	var new_state = target_grid_cell.grid_cell_state & ~Enums.cellState.WALKABLE
	target_grid_cell.set_gridobject(parent_gridobject, new_state)

	# Add additional cells based on shape and height
	for y in range(grid_height):
		for x in range(grid_shape.grid_width):
			for z in range(grid_shape.grid_height):
				if x == 0 and y == 0 and z == 0:
					continue
					
				var offset = Vector3i(x, y, z)
				var cell_pos = target_grid_cell.grid_coordinates + offset
				var temp_grid_cell = Manager.get_instance("GridSystem").get_grid_cell(cell_pos)

				if temp_grid_cell != null and not grid_cells.has(temp_grid_cell):
					grid_cells.append(temp_grid_cell)
					var temp_new_state = temp_grid_cell.grid_cell_state & ~Enums.cellState.WALKABLE
					temp_grid_cell.set_gridobject(parent_gridobject, temp_new_state)

	grid_position_data_updated.emit(target_grid_cell)


func set_grid_shape(new_shape: GridShape):
	grid_shape = new_shape


func set_grid_height(new_height: int):
	grid_height = new_height
#endregion
