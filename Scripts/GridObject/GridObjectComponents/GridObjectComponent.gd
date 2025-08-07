@abstract extends Node3D
class_name GridObjectComponent

@export var parent_grid_object : GridObject


func setup_call(parent : GridObject):
	parent_grid_object = parent
	_setup()


@abstract func _setup() 
