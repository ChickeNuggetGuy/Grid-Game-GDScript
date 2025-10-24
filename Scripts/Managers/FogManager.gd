extends Node
class_name FogManager

static var Instance: FogManager

@export var flip_z_in_shader := true

func _enter_tree() -> void:
	Instance = self

func setup() -> void:
	init_fog_globals()

func init_fog_globals() -> void:
	var terrain := GameManager.managers["MeshTerrainManager"]
	if terrain == null:
		push_error("FogManager: MeshTerrainManager not found!")
		return
	
	var unit_manager: UnitManager = GameManager.managers["UnitManager"]
	if unit_manager == null:
		push_error("FogManager: UnitManager not found!")
		return
	
	var player_team_holder: UnitTeamHolder = unit_manager.UnitTeams.get(Enums.unitTeam.PLAYER)
	if player_team_holder == null:
		push_error("FogManager: Player's UnitTeamHolder not found!")
		return

	var map_size_v3: Vector3i = terrain.get_map_cell_size()
	var visibility_tex_3d: ImageTexture3D = player_team_holder.visibility_texture
	
	if visibility_tex_3d == null:
		push_error("FogManager: Visibility texture from UnitTeamHolder is null!")
		return

	#RenderingServer.global_shader_parameter_set("fog_map_3d", visibility_tex_3d)
	#RenderingServer.global_shader_parameter_set("fog_dims_3d", Vector3(map_size_v3))
	#RenderingServer.global_shader_parameter_set("fog_cell_size", Vector2(terrain.cell_size.x, terrain.cell_size.y))
	#
	#RenderingServer.global_shader_parameter_set("fog_map_origin", Vector3.ZERO)
	#RenderingServer.global_shader_parameter_set("fog_flip_z", flip_z_in_shader)
