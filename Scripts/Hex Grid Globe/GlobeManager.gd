# GlobeManager - Updated serialization
extends Manager
class_name GlobeManager

@export var hex_globe_Decorator : HexGridDecorator
@export var hex_grid_data : HexGridData
@export var funds : int = 400000

@export var mission_timer : float = 0
@export var mission_timer_min : float
@export var mission_timer_max : float
var build_base_mode : bool  = false
var send_mission_mode : bool  = false

var start_cell_index = -1
var end_cell_index = -1

#region signals
signal funds_changed(current_funds : int)
#endregion
#region Functions

#region Node functions
func _process(delta: float) -> void:
	if not execute_complete: 
		return

	var mission_defs: Array = hex_grid_data.get_definitions_by_type("MissionDefinition")
	if not mission_defs.is_empty():
		return
	elif mission_timer > 0:
		mission_timer -= delta
	else:
		spawn_mission()
		mission_timer = randf_range(mission_timer_min, mission_timer_max)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and event is InputEventMouse:
		var mouse_event: InputEventMouseButton = event
		
		if build_base_mode:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				try_place_base()
		elif send_mission_mode:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				var idx = hex_globe_Decorator.hovered_cell
				var has_mission := false
				for d in hex_grid_data.get_cell_definitions(idx):
					if d is MissionDefinition:
						has_mission = true
						break
				if has_mission:
					var mission_position : Vector3 = hex_globe_Decorator.get_cell_world_position(idx)
					var hearest_base_index : int = -1
					var nearest_distance : float = INF
					var bases = hex_grid_data.get_definitions_by_type("TeamBaseDefinition")
					var nearest_base_index : int = bases[0].cell_index
					for base in bases:
						if base.team_affiliation != Enums.unitTeam.PLAYER:
							continue
						
						var distance =hex_globe_Decorator.get_cell_world_position(base.cell_index).distance_to(mission_position)
						if distance < nearest_distance:
							nearest_distance = distance
							nearest_base_index = base.cell_index
						
					send_ship_to_mission(hearest_base_index, idx)
#endregion


func spawn_mission():
	var spawn_cell_index := -1

	var bases: Array = hex_grid_data.get_definitions_by_type(
		"TeamBaseDefinition"
	)
	if bases.is_empty():
		spawn_cell_index = hex_globe_Decorator.get_random_cell()
	else:
		var base_def = bases[randi() % bases.size()]
		var center_cell := (base_def as HexCellDefinition).cell_index

		var candidates: Array[int] = hex_globe_Decorator.get_cells_in_radius(
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
	hex_grid_data.add_cell_definition(
		spawn_cell_index,
		mission,
		hex_globe_Decorator
	)


func send_ship_to_mission(starting_cell_index : int, mission_cell_index : int):
	
	var mission_def : MissionDefinition
	for d in hex_grid_data.get_cell_definitions(mission_cell_index):
		if d is MissionDefinition:
			mission_def = d as MissionDefinition
			break
			
	var pf: GlobePathfinder = GlobePathfinder.new()
	pf.set_grid_index(hex_globe_Decorator.grid_index)
	var path := pf.find_path(start_cell_index, end_cell_index)
	path = pf.smooth_path_adjacent(path)
	
	if not path.is_empty():
		print("Sending ship to mission")
		var ship_visual := CSGSphere3D.new()
		ship_visual.radius = 1
		owner.get_tree().root.add_child(ship_visual)
		ship_visual.position = hex_globe_Decorator.get_cell_world_position(starting_cell_index)
		for i in path:
			var ship_tween := owner.create_tween()
			ship_tween.set_trans(Tween.TRANS_LINEAR)
			ship_tween.set_ease(Tween.EASE_IN_OUT)
			ship_tween.tween_property(
				ship_visual,
				"global_position",
				 hex_globe_Decorator.get_cell_world_position(i),
				0.5
			)
			await ship_tween.finished
		ship_visual.queue_free()
	else:
		print("path is null")
		
		GameManager.spawn_counts = Vector2i(2, mission_def.enemy_spawn) 
		GameManager.map_size = Vector2i(2,2)
		GameManager.try_load_scene_by_type(GameManager.sceneType.BATTLESCENE, GameManager.get_current_scene_data())

func _filter_cells_without_mission(cells: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for ci in cells:
		var defs := hex_grid_data.get_cell_definitions(ci)
		var has_mission := false
		for d in defs:
			if d is MissionDefinition:
				has_mission = true
				break
		if not has_mission:
			out.append(ci)
	return out


func try_place_definition(_cell_index : int) -> bool:
	return true



func get_cell_definitions(cell_def_filter: String) -> Array[int]:
	if hex_grid_data == null or not hex_grid_data.cell_definitions:
		return []

	var valid_cells: Array[int] = []
	
	var definitions = hex_grid_data.get_definitions_by_type(cell_def_filter)
	
	for cell_definition in definitions:
		if cell_definition != null:
			valid_cells.append(cell_definition.cell_index)

	return valid_cells


func try_place_base():
	
	if funds >= 300000:
		var index = hex_globe_Decorator.hovered_cell
		var new_base: TeamBaseDefinition = TeamBaseDefinition.new(index, Enums.unitTeam.PLAYER)
		hex_grid_data.add_cell_definition(index, new_base, hex_globe_Decorator)
		

		print("Added Base: test: " + str(hex_grid_data.get_cell_definitions(index).size()))
		try_spend_funds(300000)
	
	build_base_mode = false

func try_spend_funds(amount_to_spend: int) -> bool:
	if funds < amount_to_spend:
		return false
	
	funds -= amount_to_spend
	funds_changed.emit(funds)
	return true



#region Manager Functions
func _get_manager_name() -> String: 
	return "GlobeManager"

func _setup_conditions() -> bool: 
	return true

func _setup():
	hex_grid_data = hex_globe_Decorator.hex_grid_data
	setup_completed.emit()
	setup_complete = true
	return

func _execute_conditions() -> bool: 
	return true

func _execute():
	
	if not load_data.is_empty():
		hex_grid_data.add_cell_definitions_from_data_bulk(load_data["cell_definitions"])
		hex_globe_Decorator.request_definitions_rebuild()
		print("Loaded missions: ", hex_grid_data.get_definitions_by_type("MissionDefinition").size())
	execution_completed.emit()
	execute_complete = true
	return


func save_data() -> Dictionary:
	var save_cell_definitions = {}
	
	var cell_definitions_dict: Dictionary = hex_grid_data.get_all_cell_definitions(["CityDefinition"], true)
	
	for def_type in cell_definitions_dict.keys():
		var definitions_data_array: Array = []
		for definition in cell_definitions_dict[def_type]:
			definitions_data_array.append(definition.serialize())
		save_cell_definitions[def_type] = definitions_data_array
	

	var save_dict = {
		"filename": get_scene_file_path(),
		"parent": get_parent().get_path(),
		"cell_definitions": save_cell_definitions,
		"funds": funds
	}
	print(save_dict["cell_definitions"].keys())  # expect MissionDefinition in here
	print(((save_dict["cell_definitions"].get("MissionDefinition", []) as Array)).size())
	return save_dict


#endregion
#endregion
