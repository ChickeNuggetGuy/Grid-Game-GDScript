extends Manager
class_name GlobeMissionManager

@export var mission_timer : float = 0
@export var mission_timer_min : float
@export var mission_timer_max : float

var send_mission_mode : bool  = false
var globe_manager : GlobeManager


var start_cell_index = -1
var end_cell_index = -1


func _get_manager_name() -> String: return "GlobeMissionManager"

func _setup_conditions() -> bool: return true

func _setup() -> void:
	globe_manager = GameManager.managers["GlobeManager"]

func _execute_conditions() -> bool: return true

func _execute() -> void:
	pass

func _process(delta: float) -> void:
	if not execute_complete: 
		return
	
	
	var mission_defs: Array = globe_manager.hex_grid_data.get_definitions_by_type(Enums.HexCellDefinitionType.MISSION)
	if not mission_defs.size() < 5:
		return
	elif mission_timer > 0:
		mission_timer -= delta
	else:
		spawn_mission()
		mission_timer = randf_range(mission_timer_min, mission_timer_max)

func _unhandled_input(event: InputEvent) -> void:
	
	if event.is_pressed() and event is InputEventMouse:
		var mouse_event: InputEventMouseButton = event
		
		if send_mission_mode:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				var idx = globe_manager.hex_globe_Decorator.hovered_cell
				var has_mission := false
				for d in globe_manager.hex_grid_data.get_cell_definitions(idx):
					if d is MissionDefinition:
						has_mission = true
						break
				if has_mission:
					var mission_position : Vector3 = globe_manager.hex_globe_Decorator.get_cell_world_position(idx)
					var hearest_base_index : int = -1
					var nearest_distance : float = INF
					var bases = globe_manager.hex_grid_data.get_definitions_by_type(Enums.HexCellDefinitionType.BASE)
					var nearest_base_index : int = bases[0].cell_index
					for base in bases:
						if base.team_affiliation != Enums.unitTeam.PLAYER:
							continue
						
						var distance = globe_manager.hex_globe_Decorator.get_cell_world_position(base.cell_index).distance_to(mission_position)
						if distance < nearest_distance:
							nearest_distance = distance
							nearest_base_index = base.cell_index
						
					send_ship_to_mission(hearest_base_index, idx)


func spawn_mission():
	var spawn_cell_index := -1

	var bases: Array = globe_manager.hex_grid_data.get_definitions_by_type(
		Enums.HexCellDefinitionType.BASE
	)
	if bases.is_empty():
		spawn_cell_index = globe_manager.hex_globe_Decorator.get_random_cell()
	else:
		var base_def = bases[randi() % bases.size()]
		var center_cell := (base_def as HexCellDefinition).cell_index

		var candidates: Array[int] = globe_manager.hex_globe_Decorator.get_cells_in_radius(
			center_cell,
			5
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


func send_ship_to_mission(starting_cell_index : int, mission_cell_index : int):
	
	globe_manager.hex_grid_data.cell_definitions[Enums.HexCellDefinitionType.BASE]
	var mission_def : MissionDefinition
	for d in globe_manager.hex_grid_data.get_cell_definitions(mission_cell_index):
		if d is MissionDefinition:
			mission_def = d as MissionDefinition
			break
			
	var pf: GlobePathfinder = GlobePathfinder.new()
	pf.set_grid_index(globe_manager.hex_globe_Decorator.grid_index)
	var path := pf.find_path(start_cell_index, end_cell_index)
	path = pf.smooth_path_adjacent(path)
	
	if not path.is_empty():
		print("Sending ship to mission")
		var ship_visual := CSGSphere3D.new()
		ship_visual.radius = 1
		owner.get_tree().root.add_child(ship_visual)
		ship_visual.position = globe_manager.hex_globe_Decorator.get_cell_world_position(starting_cell_index)
		for i in path:
			var ship_tween := owner.create_tween()
			ship_tween.set_trans(Tween.TRANS_LINEAR)
			ship_tween.set_ease(Tween.EASE_IN_OUT)
			ship_tween.tween_property(
				ship_visual,
				"global_position",
				 globe_manager.hex_globe_Decorator.get_cell_world_position(i),
				0.5
			)
			await ship_tween.finished
		ship_visual.queue_free()
	else:
		print("path is null")
		
		SavesManager.spawn_counts = Vector2i(2, mission_def.enemy_spawn) 
		SavesManager.map_size = Vector2i(2,2)
		SceneManager.try_load_scene_by_type(Enums.SceneType.BATTLESCENE, 
		SavesManager.get_current_scene_data(Enums.SceneType.GLOBE))

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
