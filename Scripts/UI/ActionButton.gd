extends Button
class_name ActionButton

#region variables
var action_defintition : BaseActionDefinition

#endregion

#region signals

#endregion
func action_setup(definition : BaseActionDefinition):
	action_defintition = definition
	text = action_defintition.name
	pressed.connect(_button_pressed)
	
func _button_pressed():
	print("Hello world!")
	UnitActionManager._set_selected_action(action_defintition)
