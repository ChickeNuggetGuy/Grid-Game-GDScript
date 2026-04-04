extends UIElement
class_name TimeControlButton

@export var time_speed : int
@export var button : Button

func _setup():
	
	button.text = str(time_speed) + "x"
	if button:
		button.pressed.connect(_time_button_pressed)



func _time_button_pressed():
	var globe_time_manager : GlobeTimeManager = GameManager.managers["GlobeTimeManager"]
	
	if not globe_time_manager:
		push_warning("Globe Time Manager not found!")
		return
	
	globe_time_manager.set_time_speed(time_speed)
