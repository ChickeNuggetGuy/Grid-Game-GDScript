extends UIWindow
class_name BaseUIWindow

@export var header_label : Label
@export var back_to_globe_button: Button
@export var units_panel_button: Button
@export var units_panel: UnitsPanelUI

@export var craft_panel_button: Button
@export var craft_panel: CraftPanelUI

var base_data : TeamBaseDefinition

func _setup() -> void:
	
	base_data = SceneManager.get_session_value("current_base",null)
	
	if header_label:
		update_header_text()
	if back_to_globe_button \
	and not back_to_globe_button.pressed.is_connected(back_to_globe_button_pressed):
		back_to_globe_button.pressed.connect(back_to_globe_button_pressed)

	if units_panel_button \
	and not units_panel_button.pressed.is_connected(units_panel_button_pressed):
		units_panel_button.pressed.connect(units_panel_button_pressed)

	if craft_panel_button \
	and not craft_panel_button.pressed.is_connected(craft_panel_button_pressed):
		craft_panel_button.pressed.connect(craft_panel_button_pressed)

func back_to_globe_button_pressed() -> void:
	print("Back to globe pressed")

	var current_base: TeamBaseDefinition = SceneManager.get_session_value(
		"current_base",
		null
	)
	_commit_definition_to_globe_state(current_base)

	var globe_data: Dictionary = SceneManager.get_session_value(
		"globe_state",
		{}
	)

	await SceneManager.change_scene(
		Enums.SceneType.GLOBE,
		globe_data
	)

func units_panel_button_pressed() -> void:
	units_panel.toggle()

func craft_panel_button_pressed() -> void:
	craft_panel.toggle()


func update_header_text():
	if not header_label:
		return
	if base_data == null:
		return 
	
	var data = SceneManager.session_data.get("globe_state")
	var team_manager = SceneManager.session_data.get("GlobeTeamManager", {})
	var team_1 = team_manager.get(1, {})
	var current_funds = team_1.get("_current_funds", -1)

	header_label.text = base_data.base_name + " \n" + str(current_funds)


func _commit_definition_to_globe_state(definition: HexCellDefinition) -> void:
	if definition == null:
		push_warning("No definition to commit.")
		return

	var globe_data: Dictionary = SceneManager.get_session_value(
		"globe_state",
		{}
	)
	if globe_data.is_empty():
		push_warning("No globe_state found in session data.")
		return

	if not globe_data.has("GlobeManager"):
		push_warning("No GlobeManager data found in globe_state.")
		return

	var globe_manager_data: Dictionary = globe_data.get("GlobeManager", {})
	var cell_definitions: Dictionary = globe_manager_data.get(
		"cell_definitions",
		{}
	)

	var definition_type: int = definition.definition_type
	var serialized_definition := definition.serialize()

	var definition_array: Array = cell_definitions.get(definition_type, [])
	var found := false

	for i in range(definition_array.size()):
		var existing_data = definition_array[i]
		if not existing_data is Dictionary:
			continue

		var existing_cell_index := int(existing_data.get("cell_index", -1))
		var existing_class_name := str(existing_data.get("class_name", ""))

		if existing_cell_index == definition.cell_index \
		and existing_class_name == definition.get_class_name():
			definition_array[i] = serialized_definition
			found = true
			break

	if not found:
		definition_array.append(serialized_definition)

	cell_definitions[definition_type] = definition_array
	globe_manager_data["cell_definitions"] = cell_definitions
	globe_data["GlobeManager"] = globe_manager_data

	SceneManager.set_session_value("globe_state", globe_data)
