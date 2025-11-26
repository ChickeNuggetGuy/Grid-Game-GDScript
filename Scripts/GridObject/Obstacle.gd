extends GridObject
class_name Obstacle

func _ready() -> void:
		collider.collision_mask = PhysicsLayer.OBSTACLE
func _setup(loading_data : bool ,data : Dictionary = {}) -> void:
	super._setup(loading_data, data)
	

	var grid_system: GridSystem = GameManager.managers["GridSystem"]
	var base: Vector3i = grid_position_data.grid_cell.grid_coordinates
	var shape := grid_position_data.grid_shape

	for y in range(shape.grid_height):
		for x in range(shape.grid_width):
			for z in range(shape.grid_depth):
				var coords := base + Vector3i(x, y, z)
				var cell : GridCell = grid_system.get_grid_cell(coords)
				if cell != null:
					cell.set_grid_cell_state(Enums.cellState.OBSTRUCTED)
