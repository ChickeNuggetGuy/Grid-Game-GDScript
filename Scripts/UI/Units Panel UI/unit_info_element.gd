extends UIElement
class_name UnitInfoElement

var current_unit : Unit 
@export var unit_name_label : Label


func _setup() -> void:
	if current_unit:
		unit_name_label.text = current_unit.name
	pass
