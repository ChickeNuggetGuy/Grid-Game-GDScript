class_name UnitTeamHolder
extends Node

@export var grid_objects: Dictionary = {"active": [], "inactive": []}
@export var team: Enums.unitTeam

var visibility_texture := ImageTexture3D.new()

var visibility_images: Array[Image] = []

signal visibility_updated(team : Enums.unitTeam, visibility_texture : ImageTexture3D)

func setup(unit_manager : UnitManager) -> void:
	unit_manager.Unit_spawned.connect(on_unit_spawned)
	var unit_action_system = GameManager.managers["UnitActionManager"]
	if unit_action_system:
		unit_action_system.any_action_execution_finished.connect(on_any_action_finished)

	var terrain := GameManager.managers["MeshTerrainManager"]
	if not terrain:
		push_error("UnitTeamHolder: MeshTerrainManager not found!")
		return

	var size_v3: Vector3i = terrain.get_map_cell_size()
	
	# --- FIX: Set dimensions to (X, Y) ---
	var fow_dims = Vector2i(size_v3.x, size_v3.y)

	visibility_images.clear()
	# --- FIX: Iterate over Z (depth) ---
	for z in size_v3.z:
		# --- FIX: Create images with size (X, Y) ---
		var temp_image := Image.create(fow_dims.x, fow_dims.y, false, Image.FORMAT_RGB8)
		temp_image.fill(Color.BLACK)
		visibility_images.append(temp_image)

	# --- FIX: Create texture with (Width=X, Height=Y, Depth=Z) ---
	var error = visibility_texture.create(Image.FORMAT_RGB8, fow_dims.x, fow_dims.y, size_v3.z, false, visibility_images)
	if error != OK:
		push_error("Failed to create and initialize ImageTexture3D.")
		return

	update_team_visibility()

func add_grid_object(grid_object: GridObject):
	if grid_object == null or grid_objects["active"].has(grid_object):
		return

	grid_objects["active"].append(grid_object)
	add_child(grid_object)

	var health_stat = grid_object.get_stat_by_name("Health")
	health_stat.stat_value_min.connect(on_grid_object_died)


func update_team_visibility():
	var active_grid_objects = grid_objects["active"]
	if active_grid_objects.is_empty():
		return

	var previously_seen_cells: Dictionary = {}
	var updated_grid_cells: Dictionary = {}

	for grid_object in active_grid_objects:
		if not grid_object is Unit:
			continue

		var component_result = grid_object.try_get_grid_object_component_by_type("GridObjectSightArea")
		if not component_result["success"]:
			continue

		var sight_area: GridObjectSightArea = component_result["grid_object_component"]
		previously_seen_cells.merge(sight_area.seen_cells)
		var sight_result = sight_area.update_sight_area(team == Enums.unitTeam.PLAYER)

		if sight_result["success"]:
			updated_grid_cells.merge(sight_result["seen_grid_cells"])

	var no_longer_visible_cells: Dictionary = {}
	for cell_key in previously_seen_cells.keys():
		if not updated_grid_cells.has(cell_key):
			var cell = previously_seen_cells[cell_key]
			cell.fog_status = Enums.FogState.PREVIOUSLY_SEEN
			no_longer_visible_cells[cell_key] = cell

	updated_grid_cells.merge(no_longer_visible_cells)

	var did_pixels_change := false
	for cell_pos: Vector3i in updated_grid_cells:
		var cell: GridCell = updated_grid_cells[cell_pos]
		
		# --- FIX: Use Z for the image array index ---
		if cell_pos.z < 0 or cell_pos.z >= visibility_images.size():
			continue
		
		# --- FIX: Use Z for the image array index ---
		var image_slice: Image = visibility_images[cell_pos.z]

		var pixel_color: Color
		match cell.fog_status:
			Enums.FogState.VISIBLE:
				pixel_color = Color.WHITE
			Enums.FogState.PREVIOUSLY_SEEN:
				pixel_color = Color(0.5, 0.5, 0.5)
			_: # UNSEEN
				pixel_color = Color.BLACK

		# --- FIX: Use (X, Y) for setting the pixel ---
		if image_slice.get_pixel(cell_pos.x, cell_pos.y) != pixel_color:
			image_slice.set_pixel(cell_pos.x, cell_pos.y, pixel_color)
			did_pixels_change = true

	if did_pixels_change:
		visibility_texture.update(visibility_images)
	
	
	visibility_updated.emit(team, visibility_texture)
	for grid_object in grid_objects["active"]:
		grid_object.grid_position_data.update_parent_visability()


func get_grid_cell_visibility_data(grid_cell: GridCell) -> Dictionary:
	var return_value := {"cell_state": Enums.cellState.NONE, "fog_state": Enums.FogState.UNSEEN}
	if not grid_cell:
		return return_value

	var coords = grid_cell.grid_coordinates 
	
	# --- FIX: Use Z for the image array index ---
	if coords.z < 0 or coords.z >= visibility_images.size():
		return return_value
	
	# --- FIX: Use Z for the image array index ---
	var image_slice: Image = visibility_images[coords.z]
	
	# --- FIX: Use (X, Y) for bounds checking ---
	if coords.x < 0 or coords.x >= image_slice.get_width() or coords.y < 0 or coords.y >= image_slice.get_height():
		return return_value

	# Read from the CPU-side image array for 100% accuracy.
	# --- FIX: Use (X, Y) to get the pixel ---
	var grid_cell_color: Color = image_slice.get_pixel(coords.x, coords.y)

	if grid_cell_color.is_equal_approx(Color.WHITE):
		return_value["cell_state"] = grid_cell.grid_cell_state
		return_value["fog_state"] = Enums.FogState.VISIBLE
	elif grid_cell_color.is_equal_approx(Color(0.5, 0.5, 0.5)):
		return_value["cell_state"] = grid_cell.grid_cell_state
		return_value["fog_state"] = Enums.FogState.PREVIOUSLY_SEEN
	else:
		return_value["cell_state"] = grid_cell.grid_cell_state
		return_value["fog_state"] = Enums.FogState.UNSEEN
		
	return return_value


func on_any_action_finished(_current_action_def, _execution_parameters):
	update_team_visibility()


func on_grid_object_died(gridObject: GridObject):
	if grid_objects["active"].has(gridObject):
		grid_objects["inactive"].append(gridObject)
		grid_objects["active"].erase(gridObject)
		print("Unit Died")


func on_unit_spawned(new_unit):
	update_team_visibility()
