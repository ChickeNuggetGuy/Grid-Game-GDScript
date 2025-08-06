@tool
class_name GridShape
extends Resource

@export var grid_width: int = 3:
	set(value):
		if value <= 0: return
		if _internal_setting:
			grid_width = value
			return
		_internal_setting = true
		grid_width = value
		_resize_grid_internal(false, _old_grid_width_for_setter, grid_height)
		_internal_setting = false
		if Engine.is_editor_hint():
			notify_property_list_changed()

@export var grid_height: int = 3:
	set(value):
		if value <= 0: return
		if _internal_setting:
			grid_height = value
			return
		_internal_setting = true
		grid_height = value
		_resize_grid_internal(false, grid_width, _old_grid_height_for_setter)
		_internal_setting = false
		if Engine.is_editor_hint():
			notify_property_list_changed()

var _internal_setting: bool = false
var _old_grid_width_for_setter: int = 0
var _old_grid_height_for_setter: int = 0

@export var shape_grid: Array[int] = []

func _init(width: int = -1, height: int = -1):
	resource_local_to_scene = true 

	if width != -1 and height != -1:
		_internal_setting = true
		self.grid_width = width
		self.grid_height = height
		_internal_setting = false
		_resize_grid_internal(true)

func _post_initialize():
	_internal_setting = true
	if grid_width <= 0: self.grid_width = 3
	if grid_height <= 0: self.grid_height = 3
	_internal_setting = false

	var expected_size = grid_width * grid_height
	if shape_grid.is_empty() and expected_size > 0:
		_resize_grid_internal(true) 
	elif shape_grid.size() != expected_size and expected_size > 0:
		var old_grid_width_from_data : int  = 0
		if shape_grid.size() > 0 and grid_height > 0:
			@warning_ignore("integer_division")
			old_grid_width_from_data = shape_grid.size() / grid_height
		_resize_grid_internal(false, old_grid_width_from_data, grid_height)

func _resize_grid_internal(rebuild_from_scratch: bool = false, previous_width: int = -1, previous_height: int = -1):
	var new_size = grid_width * grid_height
	var temp_grid: Array[int] = []
	temp_grid.resize(new_size)
	temp_grid.fill(0) 

	if not rebuild_from_scratch and shape_grid != null and not shape_grid.is_empty() and previous_width > 0 and previous_height > 0:
		var min_w = min(previous_width, grid_width)
		var min_h = min(previous_height, grid_height)
		for y in range(min_h):
			for x in range(min_w):
				var old_idx = y * previous_width + x
				var new_idx = y * grid_width + x
				if old_idx < shape_grid.size() and new_idx < temp_grid.size():
					temp_grid[new_idx] = shape_grid[old_idx]
	
	shape_grid = temp_grid

func get_grid_shape_cell(x: int, y: int) -> bool:
	if x < 0 or x >= grid_width or y < 0 or y >= grid_height:
		return false
	var index = y * grid_width + x
	return shape_grid[index] == 1 if index < shape_grid.size() else false

func set_grid_shape_cell(x: int, y: int, value: bool):
	if x < 0 or x >= grid_width or y < 0 or y >= grid_height:
		return
	var index = y * grid_width + x
	if index < shape_grid.size():
		shape_grid[index] = 1 if value else 0
