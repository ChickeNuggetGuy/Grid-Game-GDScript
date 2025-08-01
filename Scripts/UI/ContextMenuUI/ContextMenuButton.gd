extends Button
class_name ContextMenuButton

var callable : Callable

func initialize(c : Callable, acion_name : String):
	self.callable = c
	text = acion_name
	pressed.connect(on_button_preseed)

func on_button_preseed():
	print("Context button pressed")
	callable.call()
