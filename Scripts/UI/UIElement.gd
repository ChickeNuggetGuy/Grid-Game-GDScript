@abstract extends Control
class_name UIElement
@export var ui_name : String

func setup_call():
	_setup()

@abstract func _setup()
