class_name GridObject
extends Node3D

var grid_position_data : GridPositionData
@export var visual :  StaticBody3D
@export var action_holder: Node
@export var action_library: Array[ActionNode] = []
@export var ap = 40


func _ready() -> void:
	visual.collision_layer =PhysicsLayersUtility.PLAYER

func _setup(gridCell : GridCell, direction : Enums.facingDirection):
	var data = GridPositionData.new(self, gridCell, direction)
	add_child(data)
	grid_position_data = data
	
	action_library.append_array(action_holder.get_children())
