extends Area3D
class_name GridCellStateOverride

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

	if recollect or grid_cells_in_area.is_empty():
		var result := grid_system.try_get_grid_cells_in_area(self)
		if not result["success"]:
			print("Failed to get cells in grid system")
			return []
		grid_cells_in_area = result["grid_cells"]

	var changed_coords: Array[Vector3i] = []

	for grid_cell in grid_cells_in_area:
		if grid_cell == null:
			continue

		var before_state := grid_cell.grid_cell_state
		var new_state := before_state

		if state_override:
			if cell_state_filter == Enums.cellState.NONE:
				# Replace entire state
				new_state = cell_state_override
			else:
				# Remove filtered bits and add override bits
				new_state = (before_state & ~cell_state_filter) | cell_state_override
			
			# Apply the new state using the proper method
			grid_cell.set_cell_state_exclusive(new_state)

		# Handle spawn override (existing logic)
		if _spawn_override:
			if team_spawn_state_filter == Enums.cellState.NONE or \
			bool(grid_cell.grid_cell_state & team_spawn_state_filter):
				grid_cell.team_spawn = team_spawn_override

		if grid_cell.grid_cell_state != before_state:
			changed_coords.append(grid_cell.grid_coordinates)
			print("Cell ", grid_cell.grid_coordinates, " state changed from ", before_state, " to ", grid_cell.grid_cell_state)

	grid_system._on_overrides_applied(changed_coords)
	return changed_coords
