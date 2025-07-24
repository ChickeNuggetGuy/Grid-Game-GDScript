extends Node
class_name GridObjectStat

#region Variables
var parent_gridobject : GridObject
@export var stat_name : String

@export var current_value : int


@export var min_max_values : Vector2i = Vector2i(0,100)
#endregion

#region Functions

func setUp(gridObject : GridObject):
	current_value = min_max_values.y
	parent_gridobject = gridObject
	
func _add_value(value_to_add : int):
	current_value += value_to_add
	parent_gridobject.gridObject_stat_changed.emit(self, current_value)


func try_add_value(value_to_add : int) -> bool:
	if current_value + value_to_add > min_max_values.y:
		return false
	
	_add_value(value_to_add)
	return true


func _remove_value(value_to_remove : int):
	current_value -= value_to_remove
	parent_gridobject.gridObject_stat_changed.emit(self, current_value)

func try_remove_value(value_to_remove : int) -> bool:
	if current_value - value_to_remove <= min_max_values.x:
		return false
	
	_remove_value(value_to_remove)
	return true
#endregion
