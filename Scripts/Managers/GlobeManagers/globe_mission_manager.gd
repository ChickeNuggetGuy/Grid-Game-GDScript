extends Manager
class_name GlobeMissionManager

@export var mission_timer: float = 0.0
@export var mission_timer_min: float = 30.0
@export var mission_timer_max: float = 90.0

@export var craft_visual_scene: PackedScene
@export var travel_time_per_step: float = 0.5
@export var craft_height_offset: float = 0.5

var send_mission_mode: bool = false
var mission_in_progress: bool = false
var globe_manager: GlobeManager

var selected_base_cell_index: int = -1
var selected_craft_index: int = -1


func _get_manager_name() -> String:
	return "GlobeMissionManager"


func _setup_conditions() -> bool:
	return true


func _setup() -> void:
	globe_manager = GameManager.managers["GlobeManager"]


func _execute_conditions() -> bool:
	return true


func _execute() -> void:
	pass


func _process(delta: float) -> void:
	if not execute_complete:
		return

	var mission_defs: Array = globe_manager.hex_grid_data.get_definitions_by_type(
		Enums.HexCellDefinitionType.MISSION
	)

	if mission_defs.size() >= 5:
		return

	if mission_timer > 0.0:
		mission_timer -= delta
	else:
		spawn_mission()
		mission_timer = randf_range(mission_timer_min, mission_timer_max)


func arm_craft_for_mission(base_cell_index: int, craft_index: int) -> bool:
	var base := _get_base_definition(base_cell_index)
	if not base:
		return false

	if craft_index < 0 or craft_index >= base.craft_hangers.size():
		return false

	var craft := base.craft_hangers[craft_index]
	if not craft:
		return false

	selected_base_cell_index = base_cell_index
	selected_craft_index = craft_index
	send_mission_mode = true
	return true


func clear_selected_craft() -> void:
	selected_base_cell_index = -1
	selected_craft_index = -1
	send_mission_mode = false


func _unhandled_input(event: InputEvent) -> void:
	if not execute_complete:
		return

	if not send_mission_mode:
		return

	if mission_in_progress:
		return

	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return

	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	var mission_cell_index : int = globe_manager.hex_globe_Decorator.hovered_cell
	if mission_cell_index < 0:
		return

	var mission_def := _get_mission_definition(mission_cell_index)
	if not mission_def:
		return

	send_mission_mode = false
	mission_in_progress = true

	await send_selected_craft_to_mission(mission_cell_index)

	mission_in_progress = false


func send_selected_craft_to_mission(mission_cell_index: int) -> void:
	var base := _get_base_definition(selected_base_cell_index)
	if not base:
		clear_selected_craft()
		return

	if selected_craft_index < 0 or selected_craft_index >= base.craft_hangers.size():
		clear_selected_craft()
		return

	var craft := base.craft_hangers[selected_craft_index]
	if not craft:
		clear_selected_craft()
		return

	await send_ship_to_mission(craft.current_cell_index, mission_cell_index, craft)
	clear_selected_craft()


func send_ship_to_mission(
	starting_cell_index: int,
	mission_cell_index: int,
	craft: Craft
) -> void:
	var mission_def := _get_mission_definition(mission_cell_index)
	if not mission_def:
		print("Mission definition not found at cell: ", mission_cell_index)
		return

	var pf := GlobePathfinder.new()
	pf.set_grid_index(globe_manager.hex_globe_Decorator.grid_index)

	var path := pf.find_path(starting_cell_index, mission_cell_index)
	path = pf.smooth_path_adjacent(path)

	if path.is_empty():
		print("No path found for craft")
		return

	var ship_visual := _spawn_craft_visual(craft)
	if not ship_visual:
		print("Failed to create craft visual")
		return

	var current_scene := get_tree().current_scene
	if not current_scene:
		ship_visual.queue_free()
		return

	current_scene.add_child(ship_visual)
	ship_visual.global_position = _get_travel_world_position(starting_cell_index)

	for i in range(1, path.size()):
		var next_position := _get_travel_world_position(path[i])

		var tween := create_tween()
		tween.set_trans(Tween.TRANS_LINEAR)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(
			ship_visual,
			"global_position",
			next_position,
			travel_time_per_step
		)

		await tween.finished

	craft.current_cell_index = mission_cell_index

	ship_visual.queue_free()
	
	SceneManager.set_session_value("current_craft", craft.serialize())
	
	SavesManager.spawn_counts = Vector2i(
		craft.units_on_board.size(),
		mission_def.enemy_spawn
	)
	SavesManager.map_size = Vector2i(2, 2)

	await SceneManager.change_scene(
		Enums.SceneType.BATTLESCENE,
		SavesManager.get_current_scene_data(Enums.SceneType.GLOBE)
	)


func _spawn_craft_visual(craft: Craft) -> Node3D:
	if craft_visual_scene:
		var instance := craft_visual_scene.instantiate()
		if instance is Node3D:
			instance.name = craft.craft_name
			return instance
		else:
			instance.queue_free()

	var fallback := CSGSphere3D.new()
	fallback.name = craft.craft_name
	fallback.radius = .1
	return fallback


func _get_travel_world_position(cell_index: int) -> Vector3:
	var surface_pos := globe_manager.hex_globe_Decorator.get_cell_world_position(
		cell_index
	)
	return surface_pos + surface_pos.normalized() * craft_height_offset


func _get_base_definition(cell_index: int) -> TeamBaseDefinition:
	var defs := globe_manager.hex_grid_data.get_cell_definitions(cell_index)
	for def in defs:
		if def is TeamBaseDefinition:
			return def
	return null


func _get_mission_definition(cell_index: int) -> MissionDefinition:
	var defs := globe_manager.hex_grid_data.get_cell_definitions(cell_index)
	for def in defs:
		if def is MissionDefinition:
			return def
	return null


func spawn_mission() -> void:
	var spawn_cell_index := -1

	var bases: Array = globe_manager.hex_grid_data.get_definitions_by_type(
		Enums.HexCellDefinitionType.BASE
	)

	if bases.is_empty():
		spawn_cell_index = globe_manager.hex_globe_Decorator.get_random_cell()
	else:
		var base_def = bases[randi() % bases.size()]
		var center_cell := (base_def as HexCellDefinition).cell_index

		var candidates: Array[int] = (
			globe_manager.hex_globe_Decorator.get_cells_in_radius(center_cell, 5)
		)
		candidates.erase(center_cell)
		candidates = _filter_cells_without_mission(candidates)

		if not candidates.is_empty():
			spawn_cell_index = candidates.pick_random()

	if spawn_cell_index == -1:
		return

	var mission := MissionDefinition.new(spawn_cell_index)
	globe_manager.hex_grid_data.add_cell_definition(
		spawn_cell_index,
		Enums.HexCellDefinitionType.MISSION,
		mission,
		globe_manager.hex_globe_Decorator
	)


func _filter_cells_without_mission(cells: Array[int]) -> Array[int]:
	var out: Array[int] = []

	for ci in cells:
		var defs := globe_manager.hex_grid_data.get_cell_definitions(ci)
		var has_mission := false

		for d in defs:
			if d is MissionDefinition:
				has_mission = true
				break

		if not has_mission:
			out.append(ci)

	return out


#region Save/Load Data
func save_data() -> Dictionary:
	return {}
#endregion
