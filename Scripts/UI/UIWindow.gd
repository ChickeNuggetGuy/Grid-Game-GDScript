extends UIElement
class_name UIWindow

#region Varibles
var is_shown : bool
@export var start_hidden : bool = false
@export var block_inputs : bool
@export var input_key : Key
@export var visual : Control
@export var is_persistent_window = true
#endregion

#region Functions
func _ready() -> void:
	self.add_to_group("UIWindow")
	


func show_call():
	_show()

func _show():
	if block_inputs and GameManager.managers["UnitActionManager"].is_busy:
		return
	
	if visual != null:
		visual.show()
		visual.set_process(true)
	else:
		push_warning("Visual for UI Window is null!")
	is_shown = true
	if block_inputs:
		GameManager.managers["UIManager"].try_block_input(self)


func hide_call():
	_hide()

func _hide():
	if visual == null:
		push_warning("Visual for UI Window is null!")
	else:
		visual.hide()
		visual.set_process(false)
	
	if GameManager.managers["UIManager"].blocking_input and GameManager.managers["UIManager"].blocking_window == self:
		GameManager.managers["UIManager"].unblock_input()
	is_shown = false


func toggle():
	if is_shown:
		hide_call()
	else:
		show_call()


func  _setup():
	
	var ui_elements : Array = UtilityMethods.find_children_by_type(self, "UIElement")
	
	
	for element in ui_elements:
		if element is UIElement:
			element.setup_call()
	
	if start_hidden:
		hide_call()
	else:
		show_call()
	


func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == input_key:
			toggle()
#endregion
