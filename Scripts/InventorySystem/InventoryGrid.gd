@tool
class_name InventoryGrid
extends Resource

@export var inventory_name: String = ""
@export var inventory_type: Enums.inventoryType

@export var grid_shape: GridShape 

var _items: Array[Array] = []
@export var use_item_size : bool = true
@export var equipment_inventory : bool = false

@export var item_count: int:
	get:
		if _items == null or _items.is_empty() or grid_shape == null:
			return 0
		else:
			var unique_items: Array[Item] = []
			for y in range(grid_shape.grid_height):
				for x in range(grid_shape.grid_width):
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
	
	if grid_shape != null:
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
	if grid_shape == null:
		grid_shape = GridShape.new() 
		if Engine.is_editor_hint():
			notify_property_list_changed()


func _duplicate() -> Resource:
	var new_grid = InventoryGrid.new()

	new_grid.inventory_name = inventory_name
	new_grid.inventory_type = inventory_type
	new_grid.use_item_size = use_item_size

	if grid_shape != null:
		new_grid.grid_shape = grid_shape.duplicate(true)
	else:
		new_grid.grid_shape = null

	new_grid.initialize()

	if not _items.is_empty() and grid_shape != null and new_grid.grid_shape != null:
		var original_width = grid_shape.grid_width
		var original_height = grid_shape.grid_height

		var copy_width = min(original_width, new_grid.grid_shape.grid_width)
		var copy_height = min(original_height, new_grid.grid_shape.grid_height)

		for y in range(copy_height):
			for x in range(copy_width):
				if y < _items.size() and x < _items[y].size():
					var original_item = _items[y][x]
					if original_item != null:
						new_grid.try_place_item_at(original_item.duplicate(true), Vector2i(x,y))
	
	return new_grid


func initialize(data : Dictionary = {}) -> void:
	
	if not data.is_empty():
		print("Loading inventory Data ")
		inventory_type = data.get("inventory_type", 0) as Enums.inventoryType
		use_item_size = data.get("use_item_size",use_item_size)
		equipment_inventory = data.get("equipment_inventory",equipment_inventory)
		if grid_shape == null:
			grid_shape = GridShape.new()
		if data.has("grid_shape"):
			grid_shape.load_data(data["grid_shape"])
		
		
		if grid_shape == null:
			push_error("InventoryGrid: initialize() called with null grid_shape. Creating fallback GridShape.new().")
			grid_shape = GridShape.new()
			grid_shape.resource_local_to_scene = true 
		
		if grid_shape.grid_width <= 0 or grid_shape.grid_height <= 0:
			push_error("InventoryGrid's grid_shape has invalid dimensions (%d,%d). Cannot initialize _items array." % [grid_shape.grid_width, grid_shape.grid_height])
			_items = []
			return
			
			
		_items.clear()
		_items.resize(grid_shape.grid_height)
		for y in range(grid_shape.grid_height):
			_items[y] = []
			_items[y].resize(grid_shape.grid_width)
			for x in range(grid_shape.grid_width):
				_items[y][x] = null
				
				
		if data.has("items"):
			var items_value = data["items"]
			if items_value is Array: # New, robust format
				for item_data in items_value:
					var item_name = item_data["name"]
					var coords_dict = item_data["coords"]
					var coordinates = Vector2i(coords_dict["x"], coords_dict["y"])
					var result = InventoryManager.try_get_inventory_item(item_name)
					if result["success"]:
						try_place_item_at(result["inventory_item"].duplicate(true), coordinates)
					else:
						print("Getting Item Failed")
			elif items_value is Dictionary: # Backwards compatibility for old format
				for item_name in items_value:
					var result = InventoryManager.try_get_inventory_item(item_name)
					if not result["success"]: continue

					var coords_val = items_value[item_name]
					var coordinates := Vector2i.ZERO
					if coords_val is String:
						var parts = coords_val.trim_prefix("(").trim_suffix(")").split(",")
						if parts.size() == 2:
							var x = parts[0].strip_edges().to_int()
							var y = parts[1].strip_edges().to_int()
							coordinates = Vector2i(x, y)
						else:
							push_error("Could not parse coordinates from string for item '%s': %s" % [item_name, coords_val])
							continue
					else:
						push_error("Unexpected coordinate format for item '%s': %s" % [item_name, typeof(coords_val)])
						continue
						
					try_place_item_at(result["inventory_item"].duplicate(true), coordinates)
	else:
		if grid_shape == null:
			push_error("InventoryGrid: initialize() called with null grid_shape. Creating fallback GridShape.new().")
			grid_shape = GridShape.new()
			grid_shape.resource_local_to_scene = true 
			
		if grid_shape.grid_width <= 0 or grid_shape.grid_height <= 0:
			push_error("InventoryGrid's grid_shape has invalid dimensions (%d,%d). Cannot initialize _items array." % [grid_shape.grid_width, grid_shape.grid_height])
			_items = []
			return

		_items.clear()
		_items.resize(grid_shape.grid_height)
		for y in range(grid_shape.grid_height):
			_items[y] = []
			_items[y].resize(grid_shape.grid_width)
			for x in range(grid_shape.grid_width):
				_items[y][x] = null


func can_place_item_at(item: Item, position: Vector2i) -> bool:
	if item == null or item.grid_shape == null or position.x < 0 or position.y < 0:
		printerr("InventoryGrid: Either item is null, item grid shape is null, or position is out of bounds")
		return false

	if grid_shape == null:
		printerr("InventoryGrid: can_place_item_at() called with null grid_shape.")
		return false

	# Defensive check for _items array state
	if position.y < 0 or position.y >= _items.size() or \
	   (not _items[position.y] is Array) or _items[position.y].is_empty() or \
	   position.x < 0 or position.x >= _items[position.y].size():
		printerr("InventoryGrid: _items array not properly initialized or out of bounds for position %s in can_place_item_at. Reinitializing." % str(position))
		initialize()
		return false

	if use_item_size:
		if position.x + item.grid_shape.grid_width > grid_shape.grid_width or \
		   position.y + item.grid_shape.grid_height > grid_shape.grid_height:
			printerr("InventoryGrid: uses item size and item does not fit!")
			return false
		for item_y in range(item.grid_shape.grid_height):
			for item_x in range(item.grid_shape.grid_width):
				if item.grid_shape.get_grid_shape_cell(item_x, item_y, 0):
					var grid_x = position.x + item_x
					var grid_y = position.y + item_y
					if grid_x >= grid_shape.grid_width or grid_y >= grid_shape.grid_height:
						return false
					if not grid_shape.get_grid_shape_cell(grid_x, grid_y, 0):
						return false
					if _items[grid_y][grid_x] != null:
						return false
	else:
		if position.x >= grid_shape.grid_width or position.y >= grid_shape.grid_height:
			return false
		if not grid_shape.get_grid_shape_cell(position.x, position.y, 0):
			return false
		if _items[position.y][position.x] != null:
			printerr("InventoryGrid: already has item there!")
			return false
	return true


func _place_item_at(item: Item, position: Vector2i) -> void:
	if item == null: return

	if _items.is_empty() or \
	   position.y < 0 or position.y >= _items.size() or \
	   (not _items[position.y] is Array) or _items[position.y].is_empty() or \
	   position.x < 0 or position.x >= _items[position.y].size():
		push_error("InventoryGrid: _items array not properly initialized or out of bounds for position %s in _place_item_at. Reinitializing." % str(position))
		initialize()
		return

	if use_item_size and item.grid_shape != null:
		for item_y in range(item.grid_shape.grid_height):
			for item_x in range(item.grid_shape.grid_width):
				if item.grid_shape.get_grid_shape_cell(item_x, item_y, 0):
					var grid_x = position.x + item_x
					var grid_y = position.y + item_y
					if grid_y >= 0 and grid_y < grid_shape.grid_height and \
					   grid_x >= 0 and grid_x < grid_shape.grid_width:
						_items[grid_y][grid_x] = item
	else:
		if position.y >= 0 and position.y < grid_shape.grid_height and \
		   position.x >= 0 and position.x < grid_shape.grid_width:
			_items[position.y][position.x] = item
	
	item.current_inventory_grid = self
	item.current_invenrtory_coords = position
	emit_signal("inventory_changed")
	emit_signal("item_added", item)


func try_add_item(item_to_add: Item) -> bool:
	if item_to_add == null or item_to_add.grid_shape == null:
		print("Item was null")
		return false

	for y in range(grid_shape.grid_height):
		for x in range(grid_shape.grid_width):
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
	
	
	removed_item.current_inventory_grid = null
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
	if item_to_check == null or item_to_check.grid_shape == null:
		return false
	for y in range(grid_shape.grid_height):
		for x in range(grid_shape.grid_width):
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
	if _items == null or _items.is_empty() or grid_shape == null:
		return []
	else:
		var unique_items: Array[Item] = []
		for y in range(grid_shape.grid_height):
			for x in range(grid_shape.grid_width):
				var item: Item = _items[y][x]
				if item == null:
					continue
				if not unique_items.has(item):
					unique_items.append(item)
		return unique_items


func save_data() -> Dictionary:
	var items_list := []
	for item in try_get_item_array():
		if not item: continue
		items_list.append({
			"name": item.item_name,
			"coords": { "x": item.current_invenrtory_coords.x, "y": item.current_invenrtory_coords.y }
		})

	var ret_dict : Dictionary = {
		"inventory_type" : inventory_type as int,
		"items" : items_list,
		"grid_shape" : grid_shape.save_data(),
		"use_item_size" : use_item_size,
		"equipment_inventory" : equipment_inventory
	}
	return ret_dict
