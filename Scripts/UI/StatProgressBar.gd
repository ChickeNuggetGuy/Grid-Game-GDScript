extends ProgressBar
class_name StatProgressBar
#region varibles
@export var stat_type : Enums.Stat
var stat : GridObjectStat
var grid_object : GridObject
#endregion


func setup(gridObject : GridObject, grid_stat : GridObjectStat):

	if gridObject != grid_object:
		if grid_object != null:
			grid_object.disconnect("gridObject_stat_changed", update_value)
		
		stat = grid_stat
		max_value = grid_stat.min_max_values.y
		min_value = grid_stat.min_max_values.x
		grid_object = gridObject
		grid_object.gridObject_stat_changed.connect(update_value)


func update_value(updated_stat : GridObjectStat, new_value : int):
	if updated_stat == stat:
		value = new_value
