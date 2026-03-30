extends Button
class_name QuickTargetButton


var target_grid_object : GridObject
var quick_target_ui : QuickTargetUI


func initialize(grid_object : GridObject, quick_target : QuickTargetUI):
	quick_target_ui = quick_target
	target_grid_object = grid_object
	var health_stat =  target_grid_object.get_stat_by_type(Enums.Stat.HEALTH)
	if health_stat and health_stat.signal_on_min:
		health_stat.stat_value_min.connect(grid_object_died)
	pressed.connect(quick_target_grid_object)


func quick_target_grid_object():
	GameManager.managers["CameraController"].quick_switch_target(target_grid_object)


func grid_object_died(grid_object : GridObject):
	quick_target_ui.update_quick_target_buttons()
