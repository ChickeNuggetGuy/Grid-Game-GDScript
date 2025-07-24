@tool
class_name Item extends Resource

@export var item_name: String
@export_multiline var description: String
@export var icon: Texture2D

var parent_grid_object: GridObject

@export var shape: GridShape

var action_blueprints : Array[ActionNode]

func _init():
	# Initialize properties if needed, though exported properties usually handle this.
	item_name = ""
	description = ""
	icon = null
	shape = null # Ensure it's null by default to trigger InitializeShape
	action_blueprints = []

func initialize_shape() -> void:
	if shape != null:
		return

	shape = GridShape.new()
	# Assuming GridShape's constructor sets default GridWidth and GridHeight
	# If not, you might need to set them here, e.g., shape.grid_width = 3, shape.grid_height = 3
	for x in range(shape.grid_width):
		for y in range(shape.grid_height):
			shape.set_grid_shape_cell(x, y, true)
