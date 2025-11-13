class_name PauseMenuUI
extends UIWindow

@export var scene_type : GameManager.sceneType
@export var resume_button: Button
@export var save_game_button : Button
@export var load_game_button : Button
@export var settings_button : Button
@export var exit_menu_button : Button
@export var exit_button: Button

#region Signal listeners

func _on_resume_button_pressed() -> void:
	hide_call()


func _on_save_button_pressed() -> void:
	GameManager.save_game_data(GameManager.get_current_scene_data(),GameManager.current_save_file)


func _on_load_button_pressed() -> void:
	pass
	#GameManager.try_load_scene_by_type(scene_type)

func _on_settings_button_pressed() -> void:
	pass # Replace with function body.


func _on_exit_menu_button_pressed() -> void:
	pass # Replace with function body.


func _on_exit_game_button_pressed() -> void:
	GameManager.guit_game()

#endregion
