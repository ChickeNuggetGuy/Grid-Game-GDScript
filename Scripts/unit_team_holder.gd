class_name UnitTeamHolder
extends Node

@export var grid_objects: Dictionary = {"active": [], "inactive": []}
@export var team: Enums.unitTeam

var visibility_texture := ImageTexture3D.new()
var visibility_images: Array[Image] = []

# Track what the team can currently see (aggregated from all units)
var _team_seen_cells: Dictionary = {}
var _team_seen_objects: Array[GridObject] = []

signal visibility_updated(team: Enums.unitTeam, visibility_texture: ImageTexture3D)


func setup(unit_manager: UnitManager, data: Dictionary = {}) -> void:
	if not unit_manager.Unit_spawned.is_connected(on_unit_spawned):
		unit_manager.Unit_spawned.connect(on_unit_spawned)
	
	var unit_action_system = GameManager.managers["UnitActionManager"]
	if unit_action_system and not unit_action_system.any_action_execution_finished.is_connected(on_any_action_finished):
		unit_action_system.any_action_execution_finished.connect(on_any_action_finished)

	var terrain: MeshTerrainManager = GameManager.managers["MeshTerrainManager"]
	if not terrain:
		push_error("UnitTeamHolder: MeshTerrainManager not found!")
		return
	
	grid_objects = {"active": [], "inactive": []}
	
	if not data.is_empty():
		team = int(data["team"]) as Enums.unitTeam
	
		var active_units_data = data["grid_objects"]["active"]
		for unit_name in active_units_data:
			var unit_data = active_units_data[unit_name]
			var unit_scene = load(unit_data["filename"]) as PackedScene
			if unit_scene:
				var new_unit: GridObject = unit_scene.instantiate() as GridObject
				await add_grid_object(new_unit, unit_data, true, true)

		var inactive_units_data = data["grid_objects"]["inactive"]
		for unit_name in inactive_units_data:
			var unit_data = inactive_units_data[unit_name]
			var unit_scene = load(unit_data["filename"]) as PackedScene
			if unit_scene:
				var new_unit = unit_scene.instantiate() as GridObject
				await add_grid_object(new_unit, unit_data, false, true)

	_initialize_visibility_texture(terrain)
	call_deferred("update_team_visibility")


func _initialize_visibility_texture(terrain: MeshTerrainManager) -> void:
	var size_v3: Vector3i = terrain.get_map_cell_size()
	var fow_dims = Vector2i(size_v3.x, size_v3.y)
	visibility_images.clear()
	
	for z in size_v3.z:
		var temp_image := Image.create(fow_dims.x, fow_dims.y, false, Image.FORMAT_RGB8)
		temp_image.fill(Color.BLACK)
		visibility_images.append(temp_image)
	
	var error = visibility_texture.create(Image.FORMAT_RGB8, fow_dims.x, fow_dims.y, size_v3.z, false, visibility_images)
	if error != OK:
		push_error("Failed to create and initialize ImageTexture3D.")


func add_grid_object(grid_object: GridObject, unit_data: Dictionary, is_active: bool, loading_data: bool):
	if grid_object == null or grid_objects["active"].has(grid_object):
		return
	
	if is_active:
		grid_objects["active"].append(grid_object)
	else:
		grid_objects["inactive"].append(grid_object)
	add_child(grid_object)
	
	await grid_object._setup(loading_data, unit_data)
	
	if grid_object is Unit:
		var health_stat = grid_object.get_stat_by_type(Enums.Stat.HEALTH)
		if health_stat == null:
			print("UnitTEAM: health stat not found for " + grid_object.name)
		else:
			health_stat.stat_value_min.connect(on_grid_object_died)


## Full team visibility update - used on game start and when needed
func update_team_visibility():
	var active_grid_objects = grid_objects["active"]
	if active_grid_objects.is_empty():
		return

	var previous_seen_cells: Dictionary = _team_seen_cells.duplicate()
	var previous_seen_objects: Array[GridObject] = _team_seen_objects.duplicate()
	
	# Reset team-wide tracking
	_team_seen_cells.clear()
	_team_seen_objects.clear()

	# Gather visibility from all units
	for grid_object in active_grid_objects:
		if not grid_object is Unit:
			continue
		
		var unit_result = _get_unit_sight_data(grid_object)
		if not unit_result["success"]:
			continue
		
		_team_seen_cells.merge(unit_result["seen_cells"])
		for obj in unit_result["seen_objects"]:
			if not _team_seen_objects.has(obj):
				_team_seen_objects.append(obj)

	# Determine cells that are no longer visible
	var cells_to_update: Dictionary = _team_seen_cells.duplicate()
	for cell_key in previous_seen_cells.keys():
		if not _team_seen_cells.has(cell_key):
			var cell: GridCell = previous_seen_cells[cell_key]
			cell.fog_status = Enums.FogState.PREVIOUSLY_SEEN
			cells_to_update[cell_key] = cell

	_update_visibility_texture(cells_to_update)
	
	if team == Enums.unitTeam.PLAYER:
		_update_world_visibility(previous_seen_objects, _team_seen_objects)


## Optimized single unit update - used after actions
func update_single_unit_visibility(unit: Unit):
	if not grid_objects["active"].has(unit):
		return
	
	var previous_seen_cells: Dictionary = _team_seen_cells.duplicate()
	var previous_seen_objects: Array[GridObject] = _team_seen_objects.duplicate()
	
	# Get this unit's sight component and its previously seen data
	var component_result = unit.try_get_grid_object_component_by_type("GridObjectSightArea")
	if not component_result["success"]:
		return
	
	var sight_area: GridObjectSightArea = component_result["grid_object_component"]
	var unit_previous_cells: Dictionary = sight_area.seen_cells.duplicate()
	
	# Update this unit's sight
	var sight_result = sight_area.update_sight_area(team == Enums.unitTeam.PLAYER)
	if not sight_result["success"]:
		return
	
	# Rebuild team-wide visibility
	# For efficiency, we only need to recalculate if cells this unit previously saw
	# might now be unseen by the whole team
	_rebuild_team_visibility_from_units()
	
	# Find cells that changed
	var cells_to_update: Dictionary = {}
	
	# Cells this unit now sees
	for cell_key in sight_result["seen_grid_cells"]:
		cells_to_update[cell_key] = sight_result["seen_grid_cells"][cell_key]
	
	# Cells that were seen before but might not be anymore
	for cell_key in unit_previous_cells.keys():
		if not _team_seen_cells.has(cell_key):
			var cell: GridCell = unit_previous_cells[cell_key]
			cell.fog_status = Enums.FogState.PREVIOUSLY_SEEN
			cells_to_update[cell_key] = cell

	_update_visibility_texture(cells_to_update)
	
	if team == Enums.unitTeam.PLAYER:
		_update_world_visibility(previous_seen_objects, _team_seen_objects)


## Rebuild team visibility from all unit sight areas (without raycasting)
func _rebuild_team_visibility_from_units():
	_team_seen_cells.clear()
	_team_seen_objects.clear()
	
	for grid_object in grid_objects["active"]:
		if not grid_object is Unit:
			continue
		
		var component_result = grid_object.try_get_grid_object_component_by_type("GridObjectSightArea")
		if not component_result["success"]:
			continue
		
		var sight_area: GridObjectSightArea = component_result["grid_object_component"]
		_team_seen_cells.merge(sight_area.seen_cells)
		
		for team_key in sight_area.seen_gridObjects:
			for obj in sight_area.seen_gridObjects[team_key]:
				if not _team_seen_objects.has(obj):
					_team_seen_objects.append(obj)


## Get sight data from a unit without modifying state
func _get_unit_sight_data(unit: Unit) -> Dictionary:
	var result = {"success": false, "seen_cells": {}, "seen_objects": []}
	
	var component_result = unit.try_get_grid_object_component_by_type("GridObjectSightArea")
	if not component_result["success"]:
		return result
	
	var sight_area: GridObjectSightArea = component_result["grid_object_component"]
	var sight_result = sight_area.update_sight_area(team == Enums.unitTeam.PLAYER)
	
	if not sight_result["success"]:
		return result
	
	result["success"] = true
	result["seen_cells"] = sight_result["seen_grid_cells"]
	
	var seen_objects: Array[GridObject] = []
	for team_key in sight_result["seen_grid_objects"]:
		for obj in sight_result["seen_grid_objects"][team_key]:
			if not seen_objects.has(obj):
				seen_objects.append(obj)
	result["seen_objects"] = seen_objects
	
	return result


## Update the 3D texture with changed cells
func _update_visibility_texture(cells_to_update: Dictionary):
	var did_pixels_change := false
	
	for cell_pos: Vector3i in cells_to_update:
		var cell: GridCell = cells_to_update[cell_pos]
		
		if cell_pos.z < 0 or cell_pos.z >= visibility_images.size():
			continue
		
		var image_slice: Image = visibility_images[cell_pos.z]

		var pixel_color: Color
		match cell.fog_status:
			Enums.FogState.VISIBLE:
				pixel_color = Color.WHITE
			Enums.FogState.PREVIOUSLY_SEEN:
				pixel_color = Color(0.5, 0.5, 0.5)
			_:
				pixel_color = Color.BLACK

		if image_slice.get_pixel(cell_pos.x, cell_pos.y) != pixel_color:
			image_slice.set_pixel(cell_pos.x, cell_pos.y, pixel_color)
			did_pixels_change = true

	if did_pixels_change:
		visibility_texture.update(visibility_images)
	
	visibility_updated.emit(team, visibility_texture)


## Update which grid objects are visible in the game world (player team only)
func _update_world_visibility(previous_objects: Array[GridObject], current_objects: Array[GridObject]):
	# Collect all objects that need visibility checks
	var objects_to_check: Dictionary = {}
	for obj in previous_objects:
		objects_to_check[obj] = true
	for obj in current_objects:
		objects_to_check[obj] = true

	# Update enemy visibility based on player sight
	for obj in objects_to_check:
		if is_instance_valid(obj) and obj.team != Enums.unitTeam.PLAYER:
			if obj.visual:
				obj.visual.visible = current_objects.has(obj)
	
	# Player units always visible
	for grid_object in grid_objects["active"]:
		if grid_object.visual:
			grid_object.visual.visible = true

	# Update all units' visibility based on fog state
	var unit_manager : UnitManager =  GameManager.managers["UnitManager"]
	if not unit_manager:
		return
		
	for team_holder in unit_manager.unit_teams.values():
		for grid_object in team_holder.grid_objects["active"]:
			if is_instance_valid(grid_object) and grid_object.grid_position_data:
				grid_object.grid_position_data.update_parent_visability()


func get_grid_cell_visibility_data(grid_cell: GridCell) -> Dictionary:
	var return_value := {"cell_state": Enums.cellState.NONE, "fog_state": Enums.FogState.UNSEEN}
	if not grid_cell:
		return return_value

	var coords = grid_cell.grid_coordinates 
	
	if coords.z < 0 or coords.z >= visibility_images.size():
		return return_value
	
	var image_slice: Image = visibility_images[coords.z]
	
	if coords.x < 0 or coords.x >= image_slice.get_width() or coords.y < 0 or coords.y >= image_slice.get_height():
		return return_value

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


func on_any_action_finished(_current_action_def, grid_object : GridObject):
	if grid_object and grid_object.team == team:
		update_single_unit_visibility(grid_object)


func on_grid_object_died(gridObject: GridObject):
	if grid_objects["active"].has(gridObject):
		grid_objects["inactive"].append(gridObject)
		grid_objects["active"].erase(gridObject)
		
		gridObject.hide()
		gridObject.position = Vector3(-500, -500, -500)
		
		# Recalculate team visibility since we lost a unit
		if team == Enums.unitTeam.PLAYER:
			update_team_visibility()


func on_unit_spawned(new_unit):
	update_team_visibility()


func save_data() -> Dictionary:
	var save_dict = {
		"filename" : get_scene_file_path(),
		"parent" : get_parent().get_path(),
		"team" : team,
		"grid_objects" : {"active" : {}, "inactive" : {}}
	}
	
	for key in grid_objects.keys():
		for grid_object in grid_objects[key]:
			save_dict["grid_objects"][key][grid_object.name] = grid_object.save_data()

	return save_dict
