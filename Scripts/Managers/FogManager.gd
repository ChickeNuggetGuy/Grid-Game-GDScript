extends Manager
class_name FogManager


@export var fow_material : ShaderMaterial
@export var fow_material_dict : Dictionary[Material, Material]

var visibility_texture_3d_cache : ImageTexture3D = null

func _get_manager_name() -> String: return "FowManager"


func _setup_conditions() -> bool: return true

func _setup() -> void:
	setup_completed.emit()
	return


func save_data() -> Dictionary:
	var save_dict = {
		"filename" : get_scene_file_path(),
		"parent" : get_parent().get_path(),
	}
	return save_dict


func load_data(data : Dictionary):
	pass



func _execute_conditions() -> bool: return true


func _execute():
	
	init_fog_globals()
	execute_complete = true
	print("excuting fog")
	return
	

func set_global_visibility_texture(texture: ImageTexture3D):
	visibility_texture_3d_cache = texture
	if visibility_texture_3d_cache:
		# **FIX 1: Use the correct Godot 4 property for texture filtering**
		#visibility_texture_3d_cache.filter_mode = Texture3D.FILTER_NEAREST
		
		# --- FIX: The uniform name must match the shader ---
		fow_material.set_shader_parameter("visibility_texture", visibility_texture_3d_cache)


func init_fog_globals() -> void:
		
	var terrain := GameManager.managers["MeshTerrainManager"] as MeshTerrainManager
	if terrain == null:
		push_error("FogManager: MeshTerrainManager not found!")
		return
	
	var unit_manager: UnitManager = GameManager.managers["UnitManager"] as UnitManager
	if unit_manager == null:
		push_error("FogManager: UnitManager not found!")
		return
	
	var player_team_holder: UnitTeamHolder = unit_manager.UnitTeams.get(Enums.unitTeam.PLAYER) as UnitTeamHolder
	if player_team_holder == null:
		push_error("FogManager: Player's UnitTeamHolder not found!")
		return
	
	player_team_holder.visibility_updated.connect(player_visibility_updated)
	var map_size_v3: Vector3i = terrain.get_map_cell_size()
	var visibility_tex_from_holder: ImageTexture3D = player_team_holder.visibility_texture
	
	if visibility_tex_from_holder == null:
		return
	
	if debug_mode:
	# --- DEBUG PRINTS ---
		print("--- FOG MANAGER INIT ---")
		print("Texture Resolution: ", Vector3(map_size_v3))
		print("Cell Size (World): ", terrain.cell_size)
		print("Grid Origin (World): ", Vector3.ZERO)
		print("Visibility Texture Instance: ", visibility_tex_from_holder)
		print("------------------------")
	
	# Set all global shader parameters
	fow_material.set_shader_parameter("visibility_texture",visibility_tex_from_holder)
	fow_material.set_shader_parameter("texture_resolution", Vector3(map_size_v3))
	fow_material.set_shader_parameter("cell_size_world", terrain.cell_size)
	fow_material.set_shader_parameter("grid_origin_world", Vector3.ZERO)


func player_visibility_updated(team : Enums.unitTeam, texture : ImageTexture3D):
	print("Updated")
	set_global_visibility_texture(texture)



func update_fow_texture():
	var unit_manager: UnitManager = GameManager.managers["UnitManager"] as UnitManager
	if unit_manager == null:
		push_error("FogManager: UnitManager not found!")
		return
	
	var player_team_holder: UnitTeamHolder = unit_manager.UnitTeams.get(Enums.unitTeam.PLAYER) as UnitTeamHolder
	if player_team_holder == null:
		return
	
	set_global_visibility_texture(player_team_holder.visibility_texture)
