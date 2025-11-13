extends Manager
class_name UIManager

@export var ui_holder : Control
var currentCellUI : Label
var ui_windows : Dictionary[String, UIWindow] ={}
var blocking_input : bool = false
var blocking_window : UIElement = null
@export var main_inventory_ui : MainInventoryUI

@export_group("Pause menu")
@export var pause_menu_ui : PauseMenuUI

func _get_manager_name() -> String: return "UIManager"


func _setup_conditions() -> bool: return true


func _setup() -> void:
	var nodes = get_tree().get_nodes_in_group("UIWindow")
	
	for node in nodes:
		if node is UIWindow:
			var window : UIWindow = node as UIWindow
			ui_windows[window.ui_name] = window
			
	setup_completed.emit()


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
	if GameManager == null: return
	print("UI: " + str(GameManager.current_scene_type))

	
	for  window in ui_windows.values():
		var ui_window : UIWindow = window
		ui_window.setup_call()
		print("UI Manager Setup boys")
	execution_completed.emit()


func get_passable_data() -> Dictionary:
	return {}

func set_passable_data(_data : Dictionary):
	return


func try_block_input(windw : UIWindow) -> bool:
	if GameManager.managers["UnitActionManager"].is_busy:
		return false
	
	blocking_window = windw
	blocking_input = true
	return true


func unblock_input():
	blocking_input = false


func add_ui_window(window_to_add : UIWindow):
	if ui_windows == null:
		ui_windows = {}
	if ui_windows.values().has(window_to_add):
		print("UI Window already added, skipping!")
		return
	
	if ui_windows.keys().has(window_to_add.ui_name):
		print("UI Window with name '" + window_to_add.ui_name + "' already added! skipping")
		return
	
	ui_windows[window_to_add.ui_name] = window_to_add


func unitActionManager_action_selected(_selected_action : BaseActionDefinition):
	hide_non_persitent_windows()


func hide_non_persitent_windows():
	for key in ui_windows.keys():
		var ui_window = ui_windows[key]
		if ui_window == null:
			continue
		if ui_window.is_persistent_window:
			continue
		else:
			ui_window.hide_call()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and pause_menu_ui:
		pause_menu_ui.toggle()
