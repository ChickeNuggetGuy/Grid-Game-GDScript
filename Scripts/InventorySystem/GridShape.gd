@tool
class_name GridShape extends Resource

var _grid_width: int = 3
var _grid_height: int = 3

@export var shape_grid: Array[bool]

func _init():
	_grid_width = 3
	_grid_height = 3
	_rebuild_shape_grid(0, 0, true) # Force initial build

@export var grid_width: int:
	get:
		return _grid_width
	set(value):
		if _grid_width == value or value <= 0:
			return # No change or invalid
		var old_width = _grid_width
		_grid_width = value
		_rebuild_shape_grid(old_width, _grid_height)
		if Engine.is_editor_hint():
			notify_property_list_changed()

@export var grid_height: int:
	get:
		return _grid_height
	set(value):
		if _grid_height == value or value <= 0:
			return # No change or invalid
		var old_height = _grid_height
		_grid_height = value
		_rebuild_shape_grid(_grid_width, old_height)
		if Engine.is_editor_hint():
			notify_property_list_changed()

func set_grid_shape_cell(x: int, y: int, value: bool) -> void:
	if x < 0 or x >= grid_width or y < 0 or y >= grid_height:
		push_error("SetShapeCell: Index (%s,%s) out of bounds for grid (%sx%s)." % [x, y, grid_width, grid_height])
		return

	var index = y * grid_width + x
	if index < shape_grid.size():
		shape_grid[index] = value
		if Engine.is_editor_hint():
			# This ensures that if other parts of the editor depend on this property's value,
			# they are notified. For simple checkbox changes, the direct UI update is often enough.
			# However, it's good practice if the change should trigger broader editor updates.
			notify_property_list_changed()
	else:
		push_error("SetShapeCell: Calculated index %s out of bounds for ShapeGrid.size() %s. This might indicate a mismatch between GridWidth/Height and ShapeGrid size." % [index, shape_grid.size()])

func get_grid_shape_cell(x: int, y: int) -> bool:
	if shape_grid == null:
		return false

	if x < 0 or x >= _grid_width or y < 0 or y >= _grid_height:
		# push_error("GetDoorShapeCell: Index (%s,%s) out of bounds." % [x, y]) # Can be noisy
		return false
	var index = y * _grid_width + x
	if index < shape_grid.size():
		return shape_grid[index]
	# push_error("GetDoorShapeCell: Calculated index %s out of bounds for DoorShapeGrid.size() %s." % [index, shape_grid.size()])
	return false # Default to false if out of bounds or grid not properly initialized

func _rebuild_shape_grid(old_w: int, old_h: int, force: bool = false) -> void:
	var new_size = _grid_width * _grid_height
	var new_grid : Array[bool] = []
	new_grid.resize(new_size)
	new_grid.fill(false)

	if not force and shape_grid != null and shape_grid.size() > 0 and old_w > 0 and old_h > 0:
		var min_w = min(old_w, _grid_width)
		var min_h = min(old_h, _grid_height)
		for y in range(min_h):
			for x in range(min_w):
				var old_idx = y * old_w + x
				var new_idx = y * _grid_width + x
				if old_idx < shape_grid.size():
					new_grid[new_idx] = shape_grid[old_idx]
	shape_grid = new_grid
