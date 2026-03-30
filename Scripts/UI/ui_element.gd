@abstract extends Control
class_name UIElement
@export var ui_name : String

func setup_call():
	print("setup: " + name)
	
	_setup()

@abstract func _setup()
