extends Manager
class_name UIManager


var ui_holder : Control
var currentCellUI : Label
var ui_windows : Dictionary[String, UIWindow] ={}
var blocking_input : bool = false
var blocking_window : UIElement = null


func on_scene_changed(new_scen: Node):
	
	for window in ui_windows.keys():
		ui_windows[window].queue_free()
	ui_windows.clear()
	
	for child in get_children(true):
		child.queue_free()
		
	#call_deferred("execute_manager_flow")
	#print( "current_scene_name " + current_scene_name)


func _get_manager_name() -> String: return "UIManager"


func _setup_conditions() -> bool: return true


func _setup() -> void:
	setup_completed.emit()


func _execute_conditions() -> bool: return true


func _execute():
	var game_manager = GameManager.Instances["GameManager"] as GameManager
	if game_manager == null: return
	print("UI: " + game_manager.current_scene_name)
	match (game_manager.current_scene_name):
		"BattleScene":
			print("BattleScene UI Loaded")
			var interface_scene : PackedScene = load("res://Scenes/Interface.tscn")
			var interface : Control = interface_scene.instantiate()
			ui_holder = interface

			interface.set_anchors_preset(Control.PRESET_FULL_RECT)
			setup_completed.emit()
			add_child(ui_holder)
			ui_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
			ui_holder.mouse_filter =Control.MOUSE_FILTER_IGNORE
			currentCellUI = Label.new()
			ui_holder.add_child(currentCellUI)
			currentCellUI.set_anchors_preset(Control.PRESET_CENTER_TOP)
			
			UnitActionManager.Instances["UnitActionManager"].connect("selected_action_changed",
					unitActionManager_action_selected )
	
		"MainMenuScene":
			print("MainMenuScene UI Loaded")
			var main_menu_scene : PackedScene = load("res://Scenes/GameScenes/MainMenuScene.tscn")
			var main_menu : Control = main_menu_scene.instantiate()
			ui_holder = main_menu
			
			GameManager.get_instance("GameManager").current_scene_node = ui_holder
			main_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
			setup_completed.emit()
			add_child(ui_holder)
			ui_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
			ui_holder.mouse_filter =Control.MOUSE_FILTER_IGNORE
			
			
			var main_menu_ui : MainMenuUI = MainMenuUI.Instance
			
			if main_menu_ui != null:
				main_menu_ui._setup()
	
	
	for  window in ui_windows.values():
		var ui_window : UIWindow = window
		ui_window.setup_call()
	
	execution_completed.emit()

func _on_exit_tree() -> void:
	

	
	Manager.get_instance("UnitActionManager").disconnect("selected_action_changed",
		unitActionManager_action_selected )



func try_block_input(windw : UIWindow) -> bool:
	if Manager.get_instance("UnitActionManager").is_busy:
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
