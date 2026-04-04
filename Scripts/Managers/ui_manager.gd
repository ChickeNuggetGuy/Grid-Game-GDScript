extends Manager
class_name UIManager

@export var ui_holder: Control
var currentCellUI: Label
var ui_windows: Dictionary = {}
var blocking_input: bool = false
var blocking_window: UIElement = null
@export var main_inventory_ui: MainInventoryUI

@export_group("Pause menu")
@export var pause_menu_ui: PauseMenuUI


func _get_manager_name() -> String:
	return "UIManager"


func _setup_conditions() -> bool:
	return true


func _setup() -> void:
	if ui_holder == null:
		push_warning("UIManager: ui_holder is null!")


func save_data() -> Dictionary:
	return {
		"filename": get_scene_file_path(),
		"parent": get_parent().get_path(),
	}


func _execute_conditions() -> bool:
	return true


func _execute() -> void:
	ui_windows.clear()

	if ui_holder == null:
		push_warning("UIManager: ui_holder is null!")
		return

	await _setup_top_level_windows(ui_holder)


func _setup_top_level_windows(node: Node) -> void:
	for child in node.get_children():
		if child is UIWindow:
			var window := child as UIWindow
			await window.setup_call()
			continue

		await _setup_top_level_windows(child)


func get_passable_data() -> Dictionary:
	return {}


func set_passable_data(_data: Dictionary) -> void:
	return


func try_block_input(windw: UIWindow) -> bool:
	if GameManager.managers.has("UnitActionManager"):
		if GameManager.managers["UnitActionManager"].is_busy:
			return false

	blocking_window = windw
	blocking_input = true
	return true


func unblock_input() -> void:
	blocking_input = false
	blocking_window = null


func add_ui_window(window_to_add: UIWindow) -> void:
	if window_to_add == null:
		return

	var key := _get_window_key(window_to_add)

	if ui_windows.has(key):
		if ui_windows[key] == window_to_add:
			return

		push_warning("UI window key already exists: " + key)
		return

	ui_windows[key] = window_to_add


func _get_window_key(window: UIWindow) -> String:
	if not window.ui_name.is_empty():
		return window.ui_name

	return window.name


func unitActionManager_action_selected(
	_selected_action: BaseActionDefinition
) -> void:
	hide_non_persitent_windows()


func hide_non_persitent_windows() -> void:
	for key in ui_windows.keys():
		var ui_window: UIWindow = ui_windows[key]

		if ui_window == null:
			continue

		if ui_window.is_persistent_window:
			continue

		ui_window.hide_call()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and pause_menu_ui:
		pause_menu_ui.toggle()
