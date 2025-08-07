@tool
class_name InventoryGrid
extends Resource

@export var inventory_name: String = ""
@export var inventory_type: Enums.inventoryType

@export var shape: GridShape 

var _items: Array[Array] = []
@export var use_item_size : bool = true
@export var equipment_inventory : bool = false

@export var item_count: int:
	get:
		if _items == null or _items.is_empty() or shape == null:
			return 0
		else:
			var unique_items: Array[Item] = []
			for y in range(shape.grid_height):
				for x in range(shape.grid_width):
					var item: Item = _items[y][x]
					if item == null:
						continue
					if not unique_items.has(item):
						unique_items.append(item)
			return unique_items.size()
	set(value):
		pass

signal inventory_changed()
signal item_added(item_added : Item)
signal item_removed(item_removed : Item, new_inventory : InventoryGrid)

func _init():
	inventory_name = "New Inventory"
	use_item_size = true
	
	_items = []
	
	if shape != null:
		initialize()

	if Engine.is_editor_hint():
		call_deferred("_editor_post_load_setup")

func _post_initialize():
	if Engine.is_editor_hint():
		call_deferred("_editor_post_load_setup")
	else:
		_ensure_shape_exists_and_matches()
		initialize()

func _editor_post_load_setup():
	if Engine.is_editor_hint():
		_ensure_shape_exists_and_matches()
		call_deferred("initialize") 
		call_deferred("notify_property_list_changed")

func _ensure_shape_exists_and_matches():
	if shape == null:
		shape = GridShape.new() 
		if Engine.is_editor_hint():
			notify_property_list_changed()

func _duplicate() -> Resource:
	var new_grid = InventoryGrid.new()

	new_grid.inventory_name = inventory_name
	new_grid.inventory_type = inventory_type
	new_grid.use_item_size = use_item_size

	if shape != null:
		new_grid.shape = shape.duplicate(true)
	else:
		new_grid.shape = null

	new_grid.initialize()

	if not _items.is_empty() and shape != null and new_grid.shape != null:
		var original_width = shape.grid_width
		var original_height = shape.grid_height

		var copy_width = min(original_width, new_grid.shape.grid_width)
		var copy_height = min(original_height, new_grid.shape.grid_height)

		for y in range(copy_height):
			for x in range(copy_width):
				if y < _items.size() and x < _items[y].size():
					var original_item = _items[y][x]
					if original_item != null:
						new_grid.try_place_item_at(original_item.duplicate(true), Vector2i(x,y))
	
	return new_grid

func initialize() -> void:
	if shape == null:
		push_error("InventoryGrid: initialize() called with null shape. Creating fallback GridShape.new().")
		shape = GridShape.new()
		shape.resource_local_to_scene = true 
		
	if shape.grid_width <= 0 or shape.grid_height <= 0:
		push_error("InventoryGrid's shape has invalid dimensions (%d,%d). Cannot initialize _items array." % [shape.grid_width, shape.grid_height])
		_items = []
		return

	_items.clear()
	_items.resize(shape.grid_height)
	for y in range(shape.grid_height):
		_items[y] = []
		_items[y].resize(shape.grid_width)
		for x in range(shape.grid_width):
			_items[y][x] = null

func can_place_item_at(item: Item, position: Vector2i) -> bool:
	if item == null or item.shape == null or position.x < 0 or position.y < 0:
		return false

	if shape == null:
		push_error("InventoryGrid: can_place_item_at() called with null shape.")
		return false

	# Defensive check for _items array state
	if position.y < 0 or position.y >= _items.size() or \
	   (not _items[position.y] is Array) or _items[position.y].is_empty() or \
	   position.x < 0 or position.x >= _items[position.y].size():
		push_error("InventoryGrid: _items array not properly initialized or out of bounds for position %s in can_place_item_at. Reinitializing." % str(position))
		initialize()
		return false

	if use_item_size:
		if position.x + item.shape.grid_width > shape.grid_width or \
		   position.y + item.shape.grid_height > shape.grid_height:
			return false
		for item_y in range(item.shape.grid_height):
			for item_x in range(item.shape.grid_width):
				if item.shape.get_grid_shape_cell(item_x, item_y):
					var grid_x = position.x + item_x
					var grid_y = position.y + item_y
					if grid_x >= shape.grid_width or grid_y >= shape.grid_height:
						return false
					if not shape.get_grid_shape_cell(grid_x, grid_y):
						return false
					if _items[grid_y][grid_x] != null:
						return false
	else:
		if position.x >= shape.grid_width or position.y >= shape.grid_height:
			return false
		if not shape.get_grid_shape_cell(position.x, position.y):
			return false
		if _items[position.y][position.x] != null:
			return false
	return true

func _place_item_at(item: Item, position: Vector2i) -> void:
	if item == null: return

	# Defensive check for _items array state
	if _items.is_empty() or \
	   position.y < 0 or position.y >= _items.size() or \
	   (not _items[position.y] is Array) or _items[position.y].is_empty() or \
	   position.x < 0 or position.x >= _items[position.y].size():
		push_error("InventoryGrid: _items array not properly initialized or out of bounds for position %s in _place_item_at. Reinitializing." % str(position))
		initialize()
		return

	if use_item_size and item.shape != null:
		for item_y in range(item.shape.grid_height):
			for item_x in range(item.shape.grid_width):
				if item.shape.get_grid_shape_cell(item_x, item_y):
					var grid_x = position.x + item_x
					var grid_y = position.y + item_y
					if grid_y >= 0 and grid_y < shape.grid_height and \
					   grid_x >= 0 and grid_x < shape.grid_width:
						_items[grid_y][grid_x] = item
	else:
		if position.y >= 0 and position.y < shape.grid_height and \
		   position.x >= 0 and position.x < shape.grid_width:
			_items[position.y][position.x] = item
	
	item.current_inventory_grid = self
	emit_signal("inventory_changed")
	emit_signal("item_added", item)

func try_add_item(item_to_add: Item) -> bool:
	if item_to_add == null or item_to_add.shape == null:
		return false

	for y in range(shape.grid_height):
		for x in range(shape.grid_width):
			var position = Vector2i(x, y)
			if can_place_item_at(item_to_add, position):
				_place_item_at(item_to_add, position)
				return true
	return false

func remove_item(item_to_remove: Item) -> Item:
	if item_to_remove == null:
		return null
	var removed_item = item_to_remove
	for y in range(_items.size()):
		for x in range(_items[y].size()):
			if _items[y][x] == item_to_remove:
				_items[y][x] = null
	emit_signal("inventory_changed")
	emit_signal("item_removed", item_to_remove, null)
	return removed_item

static func try_transfer_item(from_grid: InventoryGrid, to_grid: InventoryGrid, item_to_transfer: Item) -> bool:
	if item_to_transfer == null:
		print("item given asnull")
	
	if not from_grid.has_item(item_to_transfer):
		print("from inventory does not have item")
	
	if not to_grid.can_place_item(item_to_transfer):
		print("to inventory does not have item")
		return false

	var removed_item = from_grid.remove_item(item_to_transfer)
	if not to_grid.try_add_item(removed_item):
		push_error("Transfer failed! Adding item back to original inventory!")
		from_grid.try_add_item(removed_item)
		return false
	return true

static func try_transfer_item_at(from_grid: InventoryGrid, to_grid: InventoryGrid, item_to_transfer: Item, coords: Vector2i) -> bool:
	if item_to_transfer == null or not from_grid.has_item(item_to_transfer) or not to_grid.can_place_item_at(item_to_transfer, coords):
		return false

	var removed_item = from_grid.remove_item(item_to_transfer)
	if not to_grid.try_place_item_at(removed_item, coords):
		push_error("Transfer failed! Adding item back to original inventory!")
		from_grid.try_add_item(removed_item)
		return false
	return true

func can_place_item(item_to_check: Item) -> bool:
	if item_to_check == null or item_to_check.shape == null:
		return false
	for y in range(shape.grid_height):
		for x in range(shape.grid_width):
			var position = Vector2i(x, y)
			if can_place_item_at(item_to_check, position):
				return true
	return false

func try_place_item_at(item: Item, position: Vector2i) -> bool:
	if not can_place_item_at(item, position):
		return false
	_place_item_at(item, position)
	return true

func has_item(item_to_check: Item) -> bool:
	if item_to_check == null:
		return false
	for y in range(_items.size()):
		for x in range(_items[y].size()):
			var item: Item = _items[y][x]
			if item == null:
				continue
			if item == item_to_check:
				return true
	return false

func has_item_at(position: Vector2i) -> Item:
	if _items.is_empty() or \
	   position.y < 0 or position.y >= _items.size() or \
	   position.x < 0 or position.x >= _items[0].size():
		return null
	return _items[position.y][position.x]


func try_get_item_array() -> Array[Item]:
	if _items == null or _items.is_empty() or shape == null:
		return []
	else:
		var unique_items: Array[Item] = []
		for y in range(shape.grid_height):
			for x in range(shape.grid_width):
				var item: Item = _items[y][x]
				if item == null:
					continue
				if not unique_items.has(item):
					unique_items.append(item)
		return unique_items
			
