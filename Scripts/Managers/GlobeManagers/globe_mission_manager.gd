extends Manager
class_name GlobeMissionManager

@export var mission_timer: float = 0.0
@export var mission_timer_min: float = 120.0
@export var mission_timer_max: float = 360.0

@export var craft_visual_scene: PackedScene
@export var travel_time_per_step: float = 0.5
@export var craft_height_offset: float = 0.5

var send_mission_mode: bool = false
var mission_in_progress: bool = false
var globe_manager: GlobeManager

var selected_base_cell_index: int = -1
var selected_craft_index: int = -1

var craft_visuals: Dictionary[int, Node3D] = {}


func _get_manager_name() -> String:
	return "GlobeMissionManager"


func _setup_conditions() -> bool:
	return true


func _setup() -> void:
	globe_manager = GameManager.managers["GlobeManager"]


func _execute_conditions() -> bool:
	return true


func _execute() -> void:
	rebuild_active_craft_visuals()


func _process(delta: float) -> void:
	if not execute_complete:
		return
	
	var globe_time_manager : GlobeTimeManager = GameManager.get_manager("GlobeTimeManager")
	
	var mission_defs: Array = globe_manager.hex_grid_data.get_definitions_by_type(
		Enums.HexCellDefinitionType.MISSION
	)

	if mission_defs.size() >= 5:
		return

	if mission_timer > 0.0:
		mission_timer -= delta * globe_time_manager.time_speed
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

	var cell_index : int = globe_manager.hex_globe_Decorator.hovered_cell
	if cell_index < 0:
		return


	send_mission_mode = false
	mission_in_progress = true

	await send_selected_craft_to_cell(cell_index)

	mission_in_progress = false


func send_selected_craft_to_cell(mission_cell_index: int) -> void:
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

	await send_ship_to_cell(craft.current_cell_index, mission_cell_index, craft)
	clear_selected_craft()


func send_ship_to_cell(
	starting_cell_index: int,
	cell_index: int,
	craft: Craft
) -> void:

	var mission_def := _get_mission_definition(cell_index)
	if mission_def:
		mission_def.on_route_craft = craft

		SavesManager.spawn_counts = Vector2i(
			craft.units_on_board.size(),
			mission_def.enemy_spawn
		)
		SavesManager.map_size = Vector2i(2, 2)

	var pf := GlobePathfinder.new()
	pf.set_grid_index(globe_manager.hex_globe_Decorator.grid_index)

	var path := pf.find_path(starting_cell_index, cell_index)
	path = pf.smooth_path_adjacent(path)

	if path.is_empty():
		print("No path found for craft")
		return

	var ship_visual := _get_or_create_craft_visual(craft)
	if not ship_visual:
		print("Failed to create craft visual")
		return

	ship_visual.global_position = _get_travel_world_position(starting_cell_index)
	craft.craft_state = Enums.CraftState.ON_ROUTE
	for i in range(1, path.size()):
		# 1. Double-check the node still exists before starting the next step
		if not is_instance_valid(ship_visual) or ship_visual.is_queued_for_deletion():
			print("Ship visual was freed mid-route. Aborting tween sequence.")
			return

		var next_position := _get_travel_world_position(path[i])


		var tween := ship_visual.create_tween()
		
		tween.set_trans(Tween.TRANS_LINEAR)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(
			ship_visual,
			"global_position",
			next_position,
			travel_time_per_step
		)

		await tween.finished

	# Ensure the craft data still exists before updating it
	if not is_instance_valid(craft):
		return

	craft.current_cell_index = cell_index

	if _is_craft_stored_at_cell(craft, cell_index):
		craft.craft_state = Enums.CraftState.HOME
		_remove_craft_visual(craft)
	else:
		craft.craft_state = Enums.CraftState.IDLE
	
	if mission_def:
		var globe_transition_data := SavesManager.build_scene_transition_data(
			Enums.SceneType.GLOBE,
			{}
		)
		SceneManager.set_session_value("globe_state", globe_transition_data)
		SceneManager.set_session_value("current_craft", craft.serialize())
		SceneManager.set_session_value("current_mission", mission_def.serialize())
		
		await SceneManager.change_scene(
			Enums.SceneType.BATTLESCENE,
			globe_transition_data)


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


func _get_craft_visual_key(craft: Craft) -> int:
	return craft.get_instance_id()


func _parent_craft_visual(visual: Node3D) -> bool:
	if visual.is_inside_tree():
		return true

	var current_scene := get_tree().current_scene
	if not current_scene:
		return false

	if visual.get_parent() != null:
		visual.get_parent().remove_child(visual)

	current_scene.add_child(visual)
	return true


func _get_or_create_craft_visual(craft: Craft) -> Node3D:
	if not craft:
		return null

	var key := _get_craft_visual_key(craft)

	if craft_visuals.has(key):
		var existing: Node3D = craft_visuals[key]

		if is_instance_valid(existing) and existing != null:
			if _parent_craft_visual(existing):
				return existing

		craft_visuals.erase(key)

	var visual := _spawn_craft_visual(craft)
	if not visual:
		return null

	if not _parent_craft_visual(visual):
		visual.queue_free()
		return null

	craft_visuals[key] = visual
	return visual


func _remove_craft_visual(craft: Craft) -> void:
	if not craft:
		return

	var key := _get_craft_visual_key(craft)

	if not craft_visuals.has(key):
		return

	var visual: Node3D = craft_visuals[key]

	if is_instance_valid(visual):
		visual.queue_free()

	craft_visuals.erase(key)


func _is_craft_stored_at_cell(craft: Craft, cell_index: int) -> bool:
	if not craft:
		return false

	return cell_index == craft.home_cell_index


func rebuild_active_craft_visuals() -> void:
	for key in craft_visuals.keys():
		var visual: Node3D = craft_visuals[key]
		if is_instance_valid(visual):
			visual.queue_free()

	craft_visuals.clear()

	var bases: Array = globe_manager.hex_grid_data.get_definitions_by_type(
		Enums.HexCellDefinitionType.BASE
	)

	for base_def in bases:
		if not base_def is TeamBaseDefinition:
			continue

		var base := base_def as TeamBaseDefinition

		for craft in base.craft_hangers:
			if not craft:
				continue

			if craft.craft_state == Enums.CraftState.HOME:
				continue

			var visual := _get_or_create_craft_visual(craft)
			if visual:
				visual.global_position = _get_travel_world_position(
					craft.current_cell_index
				)

#region Save/Load Data
func save_data() -> Dictionary:
	return {}
#endregion
