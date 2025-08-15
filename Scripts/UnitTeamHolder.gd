class_name UnitTeamHolder
extends Node

@export var grid_objects : Dictionary[String, Array]
@export var team : Enums.unitTeam

var team_textures : Dictionary[String, ImageTexture]

func setup() -> void:
	grid_objects = {"active" : [], "not_active": []}
	Manager.get_instance("UnitActionManager").connect("action_execution_finished",
			 on_any_action_finished )
	
	
	team_textures = {}
	var terrain := Manager.get_instance("MeshTerrainManager")
	if terrain == null:
		push_error("Unit Team Holder: MeshTerrainManager not found!")
		return
		
	var size_v3: Vector3 = terrain.get_map_cell_size()  # cells, not world units
	var fog_dims = Vector2i(int(size_v3.x), int(size_v3.z))
	var cell_size = Vector2(terrain.cell_size.x, terrain.cell_size.x)  # Ensure it's Vector2

	var map_origin = Vector2.ZERO

	# 3) Create fog image/texture (RG8: R=visible, G=explored)
	var fog_image = Image.create(
		fog_dims.x,
		fog_dims.y,
		false,
		Image.FORMAT_RG8
	)
	fog_image.fill(Color(0.0, 0.0, 0.0, 1.0))  # unseen + unexplored (ensure alpha is set)

	team_textures["fow_texture"] = ImageTexture.create_from_image(fog_image)


func on_any_action_finished(_current_action_def: BaseActionDefinition, _execution_parameters: Dictionary):
	var active_grid_objects = grid_objects["active"]
	
	if active_grid_objects == null or active_grid_objects.size() < 1:
		return
	
	var previously_seen_cells: Dictionary[Vector3i, GridCell] = {}
	var updated_grid_cells: Dictionary[Vector3i, GridCell] = {}
	
	for grid_object in active_grid_objects:
		if grid_object is not Unit:
			continue
		
		var unit = grid_object as Unit
		var component_result = unit.try_get_grid_object_component_by_type("GridObjectSightArea")
		
		if not component_result["success"] or component_result["grid_object_component"] == null:
			continue
		
		var sight_area: GridObjectSightArea = component_result["grid_object_component"]
		previously_seen_cells.merge(sight_area.seen_cells)
		var sight_result = sight_area.update_sight_area()
		
		if not sight_result["success"]:
			continue
		
		updated_grid_cells.merge(sight_result["seen_grid_cells"])
	
	# Find the difference: keys in previously_seen_cells but not in updated_grid_cells
	var no_longer_visible_cells: Dictionary[Vector3i, GridCell] = {}
	for cell_key in previously_seen_cells.keys():
		if not updated_grid_cells.has(cell_key):
			previously_seen_cells[cell_key].fog_status = Enums.FogState.PREVIOUSLY_SEEN
			no_longer_visible_cells[cell_key] = previously_seen_cells[cell_key]
	
	updated_grid_cells.merge(no_longer_visible_cells)
	# Now you can use no_longer_visible_cells for further processing
	# For example, update the fog texture to hide these cells
	FogManager.Instance.update_fog_texture(updated_grid_cells, team)
