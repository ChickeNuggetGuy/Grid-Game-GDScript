extends Node
class_name GridObjectStat

#region Variables
var parent_gridobject : GridObject
@export var stat_type : Enums.Stat

@export var current_value : int


@export var min_max_values : Vector2i = Vector2i(0,100)

@export var signal_on_min : bool
@export var signal_on_max : bool
@export var signal_on_change : bool

@export var change_turn_behavior : Enums.ChangeTurnBehavior
@export var change_amount : float
#endregion

#region Signals
signal stat_value_min(parent_gridobject : GridObject)
signal stat_value_max(parent_gridobject : GridObject)
signal stat_value_changed(parent_gridobject : GridObject)
#endregion

#region Functions

func setup(gridObject : GridObject, data : Dictionary):
	if data.is_empty():
		current_value = min_max_values.y
		parent_gridobject = gridObject
	else:
		parent_gridobject = gridObject
		stat_type = data["stat_type"]
		current_value = data["current_value"]
		min_max_values = Vector2i(int(data["min_value"]), int(data["max_values"]))
	
func _add_value(value_to_add : int):
	current_value += value_to_add
	parent_gridobject.gridObject_stat_changed.emit(self, current_value)
	
	if signal_on_change:
		stat_value_changed.emit(parent_gridobject)


func try_add_value(value_to_add : int) -> bool:
	if current_value + value_to_add > min_max_values.y:
		_add_value(min_max_values.y - current_value)
		
		if signal_on_max:
			stat_value_max.emit(parent_gridobject)
	else:
		_add_value(value_to_add)
	return true


func _remove_value(value_to_remove : int):
	current_value -= value_to_remove
	parent_gridobject.gridObject_stat_changed.emit(self, current_value)
	
	if signal_on_change:
		stat_value_changed.emit(parent_gridobject)


func try_remove_value(value_to_remove : int) -> bool:
	if current_value - value_to_remove <= min_max_values.x:
		current_value = min_max_values.x
		if signal_on_min:
			stat_value_min.emit(parent_gridobject)
		return true
	
	_remove_value(value_to_remove)
	return true


func current_turn_changed():
	match change_turn_behavior:
		Enums.ChangeTurnBehavior.NONE:
			return
		Enums.ChangeTurnBehavior.MIN:
			try_remove_value(current_value)
		Enums.ChangeTurnBehavior.MAX:
			try_add_value(min_max_values.y)
		Enums.ChangeTurnBehavior.INCREMENT:
			if change_amount < 1 and change_amount > 0:
				try_add_value(roundi(min_max_values.y * change_amount))
			else:
				try_add_value(roundi(change_amount))
		Enums.ChangeTurnBehavior.DERCREMENT:
			if change_amount < 1 and change_amount > 0:
				try_remove_value(roundi(min_max_values.y * change_amount))
			else:
				try_remove_value(roundi(change_amount))


func save_data() -> Dictionary:
	var ret_dict = {
		"stat_type" : stat_type,
		"current_value" : current_value,
		"min_value" : min_max_values.x,
		"max_values" : min_max_values.y
		
	}
	return ret_dict

	#endregion
