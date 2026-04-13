extends ProgressBar
class_name StatProgressBar
#region varibles
@export var stat_type : Enums.Stat
var stat : GridObjectStat
var grid_object : GridObject
#endregion


func setup(gridObject : GridObject):

	if gridObject != grid_object:
		if grid_object != null:
			grid_object.disconnect("gridObject_stat_changed", update_value)
		
		var grid_stat : GridObjectStat = gridObject.get_stat_by_type(stat_type)
		
		if not grid_stat:
			push_error("Grid stat was null!")
			return
			
		
		stat = grid_stat
		max_value = grid_stat.min_max_values.y
		min_value = grid_stat.min_max_values.x
		value = grid_stat.current_value
		grid_object = gridObject
		grid_object.gridObject_stat_changed.connect(update_value)
		


func update_value(updated_stat : GridObjectStat, new_value : int):
	if updated_stat == stat:
		value = new_value
