@tool
class_name GridPositionData
extends GridObjectComponent

#region Variables
@export var grid_shape : GridShape 
var grid_cells : Array[GridCell] = []
var grid_cell : GridCell :
	get:
		if grid_cells.size() > 0:
			return grid_cells[0]
		return null
@export var direction : Enums.facingDirection = Enums.facingDirection.NONE
var grid_cell_coords : Vector3i = Vector3i(-1,-1,-1)


var cell_size : Vector3 = Vector3(1, 1, 1)
var grid_offset : Vector3 = Vector3(0, 0.5, 0)
#endregion

#region Signals
signal grid_position_data_updated(grid_cell : GridCell)
#endregion

#region Functions
func _setup(data : Dictionary,  loading_data : bool) -> void:
	
	if not loading_data:
		set_grid_cell(data["grid_cell"])
		set_direction(data["direction"])
	else:
		grid_cells = []
		if grid_shape == null:
			grid_shape = GridShape.new(parent_grid_object)
		if data.has("grid_shape"):
			grid_shape._init(parent_grid_object, -1, -1,-1,  data["grid_shape"] )
		set_direction(data["direction"], true)
		
		var grid_system : GridSystem = GameManager.managers["GridSystem"]
		var grid_coords : Vector3i = NodeUtils._parse_vector3_from_string(data["grid_cell_coord"])
		set_grid_cell( grid_system.get_grid_cell(grid_coords))
		var grid_cells_array = data["grid_cells"]
		if not grid_system.execute_complete:
			await grid_system.execute_complete


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

	# Handle additional cells.
	for y in range(grid_shape.grid_height):
		for x in range(grid_shape.grid_width):
			for z in range(grid_shape.grid_depth):
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
	
	#if parent_grid_object and target_grid_cell:
		#parent_grid_object.global_position = target_grid_cell.world_position
		
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
	grid_shape.grid_height = new_height


func save_data() -> Dictionary:
	var grid_cells_dict : Dictionary = {}
	
	var index : int = 0
	for cell in grid_cells:
		grid_cells_dict[index] = [ cell.grid_coordinates.x,cell.grid_coordinates.y, cell.grid_coordinates.z]
		index += 1
	
	var save_dict = {
		"filename" : get_scene_file_path(),
		"parent" : get_parent().get_path(),
		"grid_shape" : grid_shape.save_data(),
		"grid_cell_coord" : grid_cell.grid_coordinates,
		"grid_cells" : grid_cells_dict,
		"direction" : direction,
		"world_position": grid_cell.world_position if grid_cell else get_parent().global_position
	}
	return save_dict

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	
	if not grid_shape: return
	
	# 1. Normalize World Position to Grid Space relative to offset
	var local_pos = global_position - grid_offset

	var search_pos = local_pos - Vector3(0, cell_size.y * 0.5, 0)
	
	var grid_indices_raw = search_pos / cell_size
	var grid_origin_indices = grid_indices_raw.round()
	
	# Optional: Slightly smaller than cell_size to see edges
	var draw_size = cell_size

	for y in range(grid_shape.grid_height):
		for x in range(grid_shape.grid_width):
			for z in range(grid_shape.grid_depth):
				var grid_index_offset = Vector3(x, y, z)
				
				# The integer index of the specific cell in the shape
				var current_cell_index = grid_origin_indices + grid_index_offset
				
				# 4. Convert Grid Index back to World Center Position
				# Formula: Offset + (Index * Size) + (Half Size)
				var cell_origin_world = grid_offset + (current_cell_index * cell_size)
				var draw_pos = cell_origin_world + (cell_size * 0.5)
				
				if grid_shape.get_grid_shape_cell(x,y,z):
					DebugDraw3D.draw_box(draw_pos + Vector3(0, 0.5, 0), Quaternion.IDENTITY, draw_size, Color.BLACK, true)
				else:
					DebugDraw3D.draw_box(draw_pos + Vector3(0, 0.5, 0), Quaternion.IDENTITY, draw_size, Color.GRAY, true)
