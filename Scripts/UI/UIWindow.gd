extends UIElement
class_name UIWindow

#region Varibles
var is_shown : bool
@export var start_hidden : bool = false
@export var input_key : Key
@export var visual : Control
#endregion

#region Functions
func _ready() -> void:
	UiManager.add_ui_window(self)
	if start_hidden:
		hide_call()
	else:
		show_call()
func show_call():
	_show()

func _show():
	visual.show()
	visual.set_process(true)
	is_shown = true


func hide_call():
	_hide()

func _hide():
	visual.hide()
	visual.set_process(false)
	is_shown = false


func toggle():
	if is_shown:
		hide_call()
	else:
		show_call()


func  _setup():
	var ui_elements : Array = UtilityMethods.find_children_by_type(self, "UIElement")
	
	if ui_elements == null or ui_elements.size() < 1:
		return
	
	for element in ui_elements:
		if element is UIElement:
			element.setup_call()


func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == input_key:
			toggle()
#endregion
