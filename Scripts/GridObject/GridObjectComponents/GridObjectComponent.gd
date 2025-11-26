@abstract extends Node3D
class_name GridObjectComponent

@export var parent_grid_object : GridObject


func setup_call(parent : GridObject, extra_params : Dictionary, loading_data : bool):
	parent_grid_object = parent
	_setup(extra_params, loading_data)


@abstract func _setup( extra_params : Dictionary, loading_data : bool)


func save_data() -> Dictionary:
	return {}
