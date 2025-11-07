extends GridObject
class_name Obstacle

func _setup(gridCell, direction, unit_team) -> void:
	super._setup(gridCell, direction, unit_team)

	var grid_system: GridSystem = GameManager.managers["GridSystem"]
	var base: Vector3i = grid_position_data.grid_cell.grid_coordinates
	var shape := grid_position_data.grid_shape

	for y in range(grid_position_data.grid_height):
		for x in range(shape.grid_width):
			for z in range(shape.grid_height):
				var coords := base + Vector3i(x, y, z)
				var cell : GridCell = grid_system.get_grid_cell(coords)
				if cell != null:
					cell.set_grid_cell_state(Enums.cellState.OBSTRUCTED)
