extends Button
class_name ActionButton

#region variables
var action_node : ActionNode

#endregion

#region signals

#endregion
func action_setup(node : ActionNode):
	action_node = node
	text = action_node.name
	pressed.connect(_button_pressed)
	
func _button_pressed():
	print("Hello world!")
	UnitActionManager._set_selected_action(action_node)
