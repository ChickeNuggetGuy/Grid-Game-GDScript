class_name GridPositionData
extends GridObjectComponent

#region Variables
@export var grid_height : int = 2
@export var grid_shape : GridShape 
var grid_cells : Array[GridCell] = []
var grid_cell : GridCell :
	get:
		if grid_cells.size() > 0:
			return grid_cells[0]
		return null
@export var direction : Enums.facingDirection = Enums.facingDirection.NONE
#endregion

#region Signals
signal grid_position_data_updated(grid_cell : GridCell)
#endregion

#region Functions
func _setup(extra_params: Dictionary) -> void:
	grid_cells = []
	set_grid_cell(extra_params["grid_cell"])
	set_direction(extra_params["direction"])

func detect_grid_position():
	var grid_system : GridSystem = GameManager.managers["GridSystem"]
	
	var new_grid_cell_result = grid_system.try_get_gridCell_from_world_position(parent_grid_object.global_position)
	
	if new_grid_cell_result["success"]:
		set_grid_cell(new_grid_cell_result["grid_cell"])

func set_direction(dir :Enums.facingDirection, update_transform : bool = false):
	direction = dir
	if update_transform:
		var canonical_yaw = RotationHelperFunctions.get_yaw_for_direction(dir)
		var start_yaw = parent_grid_object.rotation.y
		var delta = wrapf(canonical_yaw - start_yaw, -PI, PI)
		var target_yaw = start_yaw + delta
		parent_grid_object.rotation = Vector3(0,target_yaw,0)

func set_grid_cell(target_grid_cell: GridCell):
	# Clear previous grid cell references and restore original states
	for cell in grid_cells:
		if cell != null:
			cell.restore_original_state()
	
	grid_cells.clear()

	if target_grid_cell == null:
		print("gridcell is null, returning")
		return

	# Add the base cell and mark it as obstructed
	grid_cells.append(target_grid_cell)
	target_grid_cell.remove_cell_state(Enums.cellState.WALKABLE)
	target_grid_cell.add_cell_state(Enums.cellState.OBSTRUCTED)
	target_grid_cell.set_gridobject(parent_grid_object, target_grid_cell.grid_cell_state)

	# Handle additional cells...
	for y in range(grid_height):
		for x in range(grid_shape.grid_width):
			for z in range(grid_shape.grid_height):
				if x == 0 and y == 0 and z == 0:
					continue
					
				var offset = Vector3i(x, y, z)
				var cell_pos = target_grid_cell.grid_coordinates + offset
				var temp_grid_cell : GridCell = GameManager.managers["GridSystem"].get_grid_cell(cell_pos)

				if temp_grid_cell != null and not grid_cells.has(temp_grid_cell):
					grid_cells.append(temp_grid_cell)
					if temp_grid_cell.grid_cell_state | Enums.cellState.GROUND:
						temp_grid_cell.remove_cell_state(Enums.cellState.WALKABLE)
						temp_grid_cell.add_cell_state(Enums.cellState.OBSTRUCTED)
					temp_grid_cell.set_gridobject(parent_grid_object, temp_grid_cell.grid_cell_state)
		
	grid_position_data_updated.emit(target_grid_cell)

func update_parent_visability():
	if !grid_cell:
		return
		
	var team_holder = GameManager.managers["UnitManager"].UnitTeams[Enums.unitTeam.PLAYER]
	var grid_data = team_holder.get_grid_cell_visibility_data(grid_cell)
		
	if grid_data["fog_state"] == Enums.FogState.UNSEEN:
		parent_grid_object.visual.hide()
	else:
		parent_grid_object.visual.show()

func set_grid_shape(new_shape: GridShape):
	grid_shape = new_shape

func set_grid_height(new_height: int):
	grid_height = new_height
#endregion
