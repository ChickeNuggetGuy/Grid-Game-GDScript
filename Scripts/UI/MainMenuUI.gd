extends UIWindow
class_name MainMenuUI

static  var Instance : MainMenuUI
@export var play_button : Button
@export var quick_start_button : Button
@export var start_button : Button
@export var quit_button : Button
@export var map_settingsUI : UIWindow

@export var player_text_field : SpinBox
@export var enemy_text_field : SpinBox
@export var map_x_text_field : SpinBox
@export var map_y_text_field : SpinBox

func play_button_pressed():
	#map_settingsUI.show_call()
	GameManager.try_load_scene_by_type(GameManager.sceneType.GLOBE)


func quick_start_button_pressed():
	map_settingsUI.show_call()
	#GameManager.spawn_counts = Vector2(2,4)
				#
	#GameManager.map_size = Vector2(2,2) 
	#
	#GameManager.try_load_scene_by_type(GameManager.sceneType.BATTLESCENE)


func start_button_pressed():
	#set game manager values for loading into next scene
	GameManager.spawn_counts = Vector2(
				player_text_field.value,
				enemy_text_field.value)
				
	GameManager.map_size = Vector2(
				map_x_text_field.value,
				map_y_text_field.value) 
	
	GameManager.try_load_scene_by_type(GameManager.sceneType.BATTLESCENE)


func _setup():
	#super._setup()
	if not play_button.pressed.is_connected(play_button_pressed):
		play_button.pressed.connect(play_button_pressed)

	if not quick_start_button.pressed.is_connected(quick_start_button_pressed):
		quick_start_button.pressed.connect(quick_start_button_pressed)
		
	if not start_button.pressed.is_connected(start_button_pressed):
		start_button.pressed.connect(start_button_pressed)
