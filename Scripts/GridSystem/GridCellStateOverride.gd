extends Area3D
class_name GridCellStateOverride

@export var grid_position_data : GridPositionData
@export_group("Team Spawn")
@export var _spawn_override: bool
@export var team_spawn_override: Enums.unitTeam
@export var team_spawn_state_filter: Enums.cellState

@export_group("Grid Cell State")
@export var state_override: bool
@export var cell_state_override: Enums.cellState
@export var cell_state_filter: Enums.cellState

var grid_cells_in_area: Array[GridCell] = []

signal overrides_applied(changed_coords: Array[Vector3i])

func _init() -> void:
	add_to_group("grid_cell_overrides")

func set_cell_overrides(recollect: bool = false) -> Array[Vector3i]:
	var grid_system: GridSystem = GameManager.managers["GridSystem"]
	
	if grid_system == null:
		push_error("GridSystem not found in GameManager.")
		return []

	if recollect or grid_cells_in_area.is_empty():
		grid_cells_in_area.clear()

		if not grid_position_data:
			push_warning("GridPositionData is missing!")
			return []
		
		if not grid_position_data.grid_cell:
			return []
		var origin_offset = grid_position_data.parent_grid_object.grid_position_data.grid_cell.grid_coordinates
		
		for y in range(grid_position_data.grid_shape.grid_height):
			for z in range(grid_position_data.grid_shape.grid_depth):
				for x in range(grid_position_data.grid_shape.grid_width):
					
					# Only process enabled cells in shape
					if not grid_position_data.grid_shape.get_grid_shape_cell(x, y, z):
						continue
						
					var world_coord = Vector3i(x, y, z) + origin_offset
					var result = grid_system.try_get_gridCell_from_world_position(world_coord)
					
					if result["success"]:
						grid_cells_in_area.append(result["grid_cell"])

	var changed_coords: Array[Vector3i] = []
	
	print("changing: " + str(grid_cells_in_area.size()) + " cells")
	for grid_cell in grid_cells_in_area:
		if not grid_cell:
			continue

		var before_state := grid_cell.grid_cell_state
		var new_state := before_state

		if state_override:
			if cell_state_filter == Enums.cellState.NONE:
				new_state = cell_state_override
			else:
				new_state = (before_state & ~cell_state_filter) | cell_state_override
			
			grid_cell.set_cell_state_exclusive(new_state)

		if _spawn_override:
			if team_spawn_state_filter == Enums.cellState.NONE or \
			   bool(grid_cell.grid_cell_state & team_spawn_state_filter):
				grid_cell.team_spawn = team_spawn_override

		if grid_cell.grid_cell_state != before_state:
			changed_coords.append(grid_cell.grid_coordinates)
			print("Cell ", grid_cell.grid_coordinates, " state changed from ", before_state, " to ", grid_cell.grid_cell_state)

	grid_system._on_overrides_applied(changed_coords)
	return changed_coords
