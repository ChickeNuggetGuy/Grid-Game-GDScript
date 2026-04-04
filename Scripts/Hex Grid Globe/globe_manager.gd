# GlobeManager - Updated serialization
extends Manager
class_name GlobeManager

@export var hex_globe_Decorator : HexGridDecorator
@export var hex_grid_data : HexGridData
@export var funds : int = 400000


var build_base_mode : bool  = false


#region signals
signal funds_changed(current_funds : int)
#endregion
#region Functions

#region Node functions

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and event is InputEventMouse:
		var mouse_event: InputEventMouseButton = event
		
		if build_base_mode:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				try_place_base()
		else:
			
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				var definitions = hex_grid_data.get_cell_definitions(hex_globe_Decorator.hovered_cell)
				for def in definitions:
					if def is TeamBaseDefinition:
						open_base_scene(def)
						break
#endregion


func open_base_scene(base: TeamBaseDefinition) -> void:
	var globe_transition_data := SavesManager.build_scene_transition_data(
		Enums.SceneType.GLOBE,
		{}
	)

	SceneManager.set_session_value("globe_state", globe_transition_data)
	SceneManager.set_session_value("current_base", base)

	await SceneManager.change_scene(Enums.SceneType.BASE, {})

func try_place_definition(_cell_index : int) -> bool:
	return true


func get_cell_definitions(def_type_filter: Enums.HexCellDefinitionType) -> Array[int]:
	if hex_grid_data == null or not hex_grid_data.cell_definitions:
		return []

	var valid_cells: Array[int] = []
	
	var definitions = hex_grid_data.get_definitions_by_type(def_type_filter)
	
	for cell_definition in definitions:
		if cell_definition != null:
			valid_cells.append(cell_definition.cell_index)

	return valid_cells


func try_place_base():
	
	if funds >= 300000:
		var index = hex_globe_Decorator.hovered_cell
		var new_base: TeamBaseDefinition = TeamBaseDefinition.new(index, Enums.unitTeam.PLAYER)
		hex_grid_data.add_cell_definition(index,Enums.HexCellDefinitionType.BASE, new_base, hex_globe_Decorator)
		

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
		if load_data.has("funds"):
			funds = int(load_data["funds"])
			funds_changed.emit(funds)

		if load_data.has("cell_definitions"):
			hex_grid_data.clear()
			hex_grid_data.add_cell_definitions_from_data_bulk(
				load_data["cell_definitions"]
			)
			hex_globe_Decorator.request_definitions_rebuild()

			print(
				"Loaded missions: ",
				hex_grid_data.get_definitions_by_type(
					Enums.HexCellDefinitionType.MISSION
				).size()
			)

	return

func save_data() -> Dictionary:
	var save_cell_definitions = {}
	
	var cell_definitions_dict: Dictionary = hex_grid_data.get_all_cell_definitions([Enums.HexCellDefinitionType.CITY], true)
	
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
