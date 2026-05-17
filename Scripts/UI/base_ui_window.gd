extends UIWindow
class_name BaseUIWindow

@export var header_label : Label
@export var back_to_globe_button: Button
@export var buy_sell_button : Button
@export var units_panel_button: Button
@export var units_panel: UnitsPanelUI


@export var craft_panel_button: Button
@export var craft_panel: CraftPanelUI

@export var buy_sell_panel : BuySellWindow

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

	if buy_sell_button \
	and not buy_sell_button.pressed.is_connected(buy_sell_panel_button_pressed):
		buy_sell_button.pressed.connect(buy_sell_panel_button_pressed)

	if buy_sell_panel and not buy_sell_panel.base_data_changed.is_connected(_on_base_data_changed):
		buy_sell_panel.base_data_changed.connect(_on_base_data_changed)

	if craft_panel and not craft_panel.base_data_changed.is_connected(_on_base_data_changed):
		craft_panel.base_data_changed.connect(_on_base_data_changed)

	if units_panel and not units_panel.base_data_changed.is_connected(_on_base_data_changed):
		units_panel.base_data_changed.connect(_on_base_data_changed)
func back_to_globe_button_pressed() -> void:
	print("Back to globe pressed")

	var current_base: TeamBaseDefinition = SceneManager.get_session_value(
		"current_base",
		null
	)
	SceneManager.commit_definition_to_globe_state(current_base)

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

func buy_sell_panel_button_pressed() -> void:
	buy_sell_panel.toggle()

func update_header_text():
	if not header_label:
		return
	if base_data == null:
		return 
	
	var data = SceneManager.session_data.get("globe_state")
	var team_manager = data.get("GlobeTeamManager", {})
	var team_1 = team_manager.get("1", {})
	var current_funds = team_1.get("_current_funds", -1)

	header_label.text = base_data.base_name + " \n" + str(current_funds)

func _on_base_data_changed() -> void:
	base_data = SceneManager.get_session_value("current_base", null)
	if base_data == null:
		return

	update_header_text()

	if units_panel:
		units_panel.refresh_unit_list(base_data.stationed_units)
		
	if craft_panel:
		craft_panel.refresh_item_lists()
		
