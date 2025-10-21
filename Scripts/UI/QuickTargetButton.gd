extends Button
class_name QuickTargetButton


var target_grid_object : GridObject



func initialize(grid_object : GridObject):
	target_grid_object = grid_object
	pressed.connect(quick_target_grid_object)


func quick_target_grid_object():
	GameManager.managers["CameraController"].quick_switch_target(target_grid_object)
