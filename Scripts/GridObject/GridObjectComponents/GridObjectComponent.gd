@abstract extends Node3D
class_name GridObjectComponent

@export var parent_grid_object : GridObject


func setup_call(parent : GridObject, extra_params : Dictionary):
	parent_grid_object = parent
	_setup(extra_params)


@abstract func _setup( extra_params : Dictionary) 
