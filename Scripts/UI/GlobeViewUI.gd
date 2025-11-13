class_name GlobeViewUI
extends UIWindow

@export var funds_text : Label

func _setup() -> void:
	GameManager.managers["GlobeManager"].funds_changed.connect(globe_manager_funds_changed)
	update_visuals()
	


func build_base_on_button_pressed() -> void:
	GameManager.managers["GlobeManager"].build_base_mode = true


func globe_manager_funds_changed(current_funds):
	funds_text.text = "$" + str(current_funds)


func update_visuals():
	funds_text.text =  "$" + str(GameManager.managers["GlobeManager"].funds)


func _on_send_mission_button_pressed() -> void:
	GameManager.managers["GlobeManager"].send_mission_mode = true
