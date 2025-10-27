extends Area3D
class_name GridCellStateOverride 
@export_group("Team Spawn") 
@export var _spawn_override : bool
@export  var team_spawn_override : Enums.unitTeam 
@export  var team_spawn_state_filter : Enums.cellState


@export_group("Grid Cell State")
@export var state_override : bool
@export var cell_state_override : Enums.cellState 
@export  var cell_state_filter : Enums.cellState

func _init() -> void:
	add_to_group("grid_cell_overrides")



func set_cell_overrides():
	var grid_system : GridSystem = GameManager.managers["GridSystem"]
	
	var result : = grid_system.try_get_grid_cells_in_area(self)
	
	if not result["success"]:
		print("Failed to get cells in grid system ")
		return
	
	var grid_cells : Array[GridCell] = result["grid_cells"]
	var cells_changed : int = 0
	for grid_cell in grid_cells:
		
		if not grid_cell:
			continue
		
		if state_override and grid_cell.grid_cell_state == cell_state_filter:
			grid_cell.grid_cell_state = cell_state_override
			cells_changed += 1
			
		if _spawn_override and grid_cell.grid_cell_state == team_spawn_state_filter:
			grid_cell.team_spawn = team_spawn_override
			cells_changed += 1
	
	print("Changed " + str(cells_changed) + "  grid cells")
