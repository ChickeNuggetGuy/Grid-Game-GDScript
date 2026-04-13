@tool
class_name GridShape
extends Resource

signal dimensions_changed

var parent_grid_object: GridObject
var _internal_setting: bool = false

@export var grid_width: int = 3:
	set(value):
		if value <= 0:
			return
		if _internal_setting:
			grid_width = value
			return

		_internal_setting = true
		var old_w := grid_width
		grid_width = value
		_resize_grid_internal(old_w, grid_depth, grid_height)
		_internal_setting = false

		notify_property_list_changed()
		emit_changed()
		dimensions_changed.emit()

@export var grid_depth: int = 3:
	set(value):
		if value <= 0:
			return
		if _internal_setting:
			grid_depth = value
			return

		_internal_setting = true
		var old_d := grid_depth
		grid_depth = value
		_resize_grid_internal(grid_width, old_d, grid_height)
		_internal_setting = false

		notify_property_list_changed()
		emit_changed()
		dimensions_changed.emit()

@export var grid_height: int = 1:
	set(value):
		if value <= 0:
			return
		if _internal_setting:
			grid_height = value
			return

		_internal_setting = true
		var old_h := grid_height
		grid_height = value
		_resize_grid_internal(grid_width, grid_depth, old_h)
		_internal_setting = false

		notify_property_list_changed()
		emit_changed()
		dimensions_changed.emit()

@export var shape_grid: Array[int] = []

func _init(
	parent = null,
	width: int = -1,
	depth: int = -1,
	height: int = -1,
	data: Dictionary = {}
):
	resource_local_to_scene = true
	parent_grid_object = parent

	if width != -1 and depth != -1 and height != -1:
		_internal_setting = true
		grid_width = width
		grid_depth = depth
		grid_height = height
		_internal_setting = false
		_resize_grid_internal(0, 0, 0, true)
	elif not data.is_empty():
		load_data(data)
	else:
		if shape_grid.is_empty():
			_resize_grid_internal(0, 0, 0, true)

func _get_index(x: int, y: int, z: int) -> int:
	return x + (z * grid_width) + (y * grid_width * grid_depth)

func _resize_grid_internal(
	prev_w: int,
	prev_d: int,
	prev_h: int,
	force_clear: bool = false
):
	var new_size := grid_width * grid_depth * grid_height
	var temp_grid: Array[int] = []
	temp_grid.resize(new_size)
	temp_grid.fill(0)

	if not force_clear and not shape_grid.is_empty():
		for y in range(min(prev_h, grid_height)):
			for z in range(min(prev_d, grid_depth)):
				for x in range(min(prev_w, grid_width)):
					var old_idx := x + (z * prev_w) + (y * prev_w * prev_d)
					var new_idx := x + (z * grid_width) + (
						y * grid_width * grid_depth
					)

					if old_idx < shape_grid.size() and new_idx < temp_grid.size():
						temp_grid[new_idx] = shape_grid[old_idx]

	shape_grid = temp_grid

func get_grid_shape_cell(x: int, y: int, z: int) -> bool:
	if not _is_in_bounds(x, y, z):
		return false

	var index := _get_index(x, y, z)
	return shape_grid[index] == 1 if index < shape_grid.size() else false

func set_grid_shape_cell(x: int, y: int, z: int, value: bool):
	if not _is_in_bounds(x, y, z):
		return

	var index := _get_index(x, y, z)
	if index >= shape_grid.size():
		return

	shape_grid[index] = 1 if value else 0
	emit_changed()

func _is_in_bounds(x: int, y: int, z: int) -> bool:
	return (
		x >= 0 and x < grid_width
		and y >= 0 and y < grid_height
		and z >= 0 and z < grid_depth
	)

func get_inventory_cell(x: int, row: int) -> bool:
	return get_grid_shape_cell(x, 0, row)

func set_inventory_cell(x: int, row: int, value: bool):
	set_grid_shape_cell(x, 0, row, value)

func save_data() -> Dictionary:
	return {
		"grid_width": grid_width,
		"grid_depth": grid_depth,
		"grid_height": grid_height,
		"shape_grid": shape_grid
	}

func load_data(data: Dictionary):
	_internal_setting = true
	grid_width = data.get("grid_width", 3)
	grid_depth = data.get("grid_depth", 3)
	grid_height = data.get("grid_height", 1)
	_internal_setting = false

	var loaded_grid: Array[int] = []
	var raw_grid_data = data.get("shape_grid", [])

	if raw_grid_data is Array:
		for d in raw_grid_data:
			loaded_grid.append(int(d))

	var expected_size := grid_width * grid_depth * grid_height

	if loaded_grid.size() == expected_size:
		shape_grid = loaded_grid
	elif loaded_grid.size() > 0:
		shape_grid = loaded_grid
		shape_grid.resize(expected_size)
	else:
		shape_grid.resize(expected_size)
		shape_grid.fill(0)

	notify_property_list_changed()
	emit_changed()
	dimensions_changed.emit()
