extends Node
class_name FogManager

# Make this a simple singleton if you like: FogManager.Instance.update_fog_texture(...)
static var Instance: FogManager

var main_fog_texture : ImageTexture
# Grid/World mapping
var fog_dims: Vector2i        # number of cells: (width in X, height in Z)
var cell_size: Vector2        # world units per cell: (X, Z)
var map_origin: Vector2       # world-space XZ of cell (0,0) min-corner

# Options
@export var flip_z_in_image := true
@export var draw_test_patch := false

@export var test_material : ShaderMaterial
var fog_material : ShaderMaterial
@export var terrain_texture : Texture2D
var fog_plane 

func _enter_tree() -> void:
	Instance = self

func setup() -> void:
	init_fog()

func init_fog() -> void:
	# 1) Fetch grid dimensions and world cell size from your systems
	var terrain := Manager.get_instance("MeshTerrainManager")
	if terrain == null:
		push_error("FogManager: MeshTerrainManager not found!")
		return
	
	var unit_manager : UnitManager = Manager.get_instance("UnitManager")
	if unit_manager == null:
		push_error("FogManager: UnitManager not found!")
		return
	
	var player_team_holder :UnitTeamHolder = unit_manager.UnitTeams[Enums.unitTeam.PLAYER]
	var size_v3: Vector3 = terrain.get_map_cell_size()  # cells, not world units
	fog_dims = Vector2i(int(size_v3.x), int(size_v3.z))
	cell_size = Vector2(terrain.cell_size.x, terrain.cell_size.x)  # Ensure it's Vector2

	map_origin = Vector2.ZERO
	main_fog_texture = player_team_holder.team_textures["fow_texture"]
	# Push globals 
	RenderingServer.global_shader_parameter_set("fog_map", main_fog_texture)
	RenderingServer.global_shader_parameter_set("fog_dims", Vector2(fog_dims))
	RenderingServer.global_shader_parameter_set("cell_size", cell_size)
	RenderingServer.global_shader_parameter_set("map_origin", map_origin)
	RenderingServer.global_shader_parameter_set("fog_debug", 0)
	
	
	DebugDraw3D.draw_box(Vector3.ZERO + Vector3(0,2,0), Quaternion.IDENTITY, Vector3.ONE,
	
	Color.ORANGE, false, 100)
	
	fog_material = terrain.material
	
	fog_material.set_shader_parameter("visibility_texture", main_fog_texture)
	fog_material.set_shader_parameter("terrain_texture", terrain_texture)
	fog_material.set_shader_parameter("world_offset", Vector3(0,0,0))
	fog_material.set_shader_parameter("grid_size", fog_dims)
	fog_material.set_shader_parameter("cell_size", cell_size)
	
	


func update_fog_texture(changed_cells: Dictionary, team : Enums.unitTeam) -> void:
	# changed_cells is expected to be Dictionary[Vector3i, GridCell]
	var changed := false
	
	
	var unit_manager : UnitManager = Manager.get_instance("UnitManager")
	if unit_manager == null:
		push_error("FogManager: UnitManager not found!")
		return
		
	var team_holder :UnitTeamHolder = unit_manager.UnitTeams[team]
	var target_image = team_holder.team_textures["fow_texture"].get_image()
	var target_texture = team_holder.team_textures["fow_texture"]
	
	if target_texture == null:
		push_error("target texture for team: " + str(Enums.unitTeam.find_key(team	)) + " is null")
		return
	# Validate input
	if changed_cells == null or changed_cells.is_empty():
		return

	for key in changed_cells.keys():
		var g := key as Vector3i
		var cell: GridCell = changed_cells[key]

		# Validate cell data
		if cell == null:
			continue

		# Map grid (x,z) -> image (x,y)
		var x : int = g.x
		var z : int = g.z
		
		# Bounds checking
		if x < 0 or x >= fog_dims.x or z < 0 or z >= fog_dims.y:
			continue
			
		var y_img := _img_y_from_z(z)
		var vi := Vector2i(x, y_img)

		var next := Color(0.0, 0.0, 0.0, 1.0)
		match cell.fog_status:
			Enums.FogState.VISIBLE:
				next = Color(1.0, 1.0, 0.0, 1.0)   # visible + explored
			Enums.FogState.PREVIOUSLY_SEEN:
				next = Color(0.0, 1.0, 0.0, 1.0)   # explored only
			Enums.FogState.UNSEEN:
				next = Color(0.0, 0.0, 0.0, 1.0)   # unseen

		# Only update if pixel value is actually changing
		if target_image.get_pixelv(vi) != next:
			target_image.set_pixelv(vi, next)
			changed = true

	if changed:
		target_texture.update(target_image)

func _img_y_from_z(z: int) -> int:
	return (fog_dims.y - 1 - z) if flip_z_in_image else z

# Helper function to convert world position to fog grid coordinates
func world_to_fog_coords(world_pos: Vector3) -> Vector2i:
	var relative_pos := Vector2(world_pos.x, world_pos.z) - map_origin
	var x := int(relative_pos.x / cell_size.x)
	var z := int(relative_pos.y / cell_size.y)
	
	# Clamp to valid range
	x = clamp(x, 0, fog_dims.x - 1)
	z = clamp(z, 0, fog_dims.y - 1)
	
	return Vector2i(x, z)

# Helper function to update fog at a specific world position
func update_fog_at_world_position(world_pos: Vector3, fog_state: Enums.FogState,
		team : Enums.unitTeam) -> void:
	
	var unit_manager : UnitManager = Manager.get_instance("UnitManager")
	if unit_manager == null:
		push_error("FogManager: UnitManager not found!")
		return
		
	var team_holder :UnitTeamHolder = unit_manager.UnitTeams[team]
	var target_image = team_holder.team_textures["fow_texture"].get_image()
	var target_texture = team_holder.team_textures["fow_texture"]
	
	if target_texture == null:
		push_error("target texture for team: " + str(Enums.unitTeam.find_key(team	)) + " is null")
		return
	
	var fog_coords := world_to_fog_coords(world_pos)
	var x := fog_coords.x
	var z := fog_coords.y
	var y_img := _img_y_from_z(z)
	var vi := Vector2i(x, y_img)
	
	var next := Color(0.0, 0.0, 0.0, 1.0)
	match fog_state:
		Enums.FogState.VISIBLE:
			next = Color(1.0, 1.0, 0.0, 1.0)   # visible + explored
		Enums.FogState.PREVIOUSLY_SEEN:
			next = Color(0.0, 1.0, 0.0, 1.0)   # explored only
		Enums.FogState.UNSEEN:
			next = Color(0.0, 0.0, 0.0, 1.0)   # unseen

	if target_image.get_pixelv(vi) != next:
		target_image.set_pixelv(vi, next)
		target_texture.update(target_image)
