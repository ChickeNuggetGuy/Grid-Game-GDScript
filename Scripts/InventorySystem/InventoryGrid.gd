@tool
class_name InventoryGrid 
extends Resource

#region Variables
@export var inventory_name: String = ""
@export var inventory_type: Enums.inventoryType

@export var inventory_shape: GridShape:
	set(value):
		inventory_shape = value
		# This ensures that whenever the shape is assigned (e.g., in editor or code),
		# the grid gets re-initialized to match the new shape dimensions.
		if inventory_shape != null and inventory_shape.grid_width > 0 and inventory_shape.grid_height > 0:
			initialize()
		else: # If setting to null or invalid, clear items
			_items = []
		if Engine.is_editor_hint():
			notify_property_list_changed() # To refresh inspector
	get:
		return inventory_shape

var _items: Array[Array] = [] # Represents the 2D grid: Array[Array[Item]]

@export var use_item_size: bool = true

@export var item_count: int:
	get:
		if _items == null or _items.is_empty():
			return 0
		else:
			var unique_items: Array[Item] = []
			for y in range(_items.size()):
				for x in range(_items[y].size()):
					var item: Item = _items[y][x]
					if item == null:
						continue
					if not unique_items.has(item):
						unique_items.append(item)
			return unique_items.size()
	set(value):
		pass # Read-only, similar to C# property with only get.
#endregion

#region Events
# Signal to notify UI or other systems that the inventory has changed.
signal inventory_changed()
#endregion

#region Functions
func _init():
	inventory_name = "New Inventory"
	use_item_size = true
	_items = [] # Initialize as empty array of arrays

func initialize() -> void:
	if inventory_shape == null:
		push_error("InventoryShape is null")
		_items = []
		return

	if inventory_shape.grid_width <= 0 or inventory_shape.grid_height <= 0:
		push_error("InventoryGrid must have a size with positive X and Y values.")
		_items = [] # Set to empty 2D array if invalid size
		return

	# Initialize the 2D array: Array of rows, each row is an Array of Items
	_items.clear()
	_items.resize(inventory_shape.grid_height) # Height determines number of rows
	for y in range(inventory_shape.grid_height):
		_items[y] = []
		_items[y].resize(inventory_shape.grid_width) # Width determines number of columns in each row
		# Fill with null initially
		for x in range(inventory_shape.grid_width):
			_items[y][x] = null

func try_add_item(item_to_add: Item) -> bool:
	if item_to_add == null:
		print("Cannot add null item")
		return false
		
	# Ensure the item's own shape is initialized.
	if item_to_add.shape == null:
		print("Item has no shape")
		return false

	# Iterate through every possible top-left starting position.
	for y in range(inventory_shape.grid_height):
		for x in range(inventory_shape.grid_width):
			var position = Vector2i(x, y)
			if can_place_item_at(item_to_add, position):
				_place_item_at(item_to_add, position)
				return true # Item placed, exit successfully.

	print("Could not find a valid spot for item: %s" % item_to_add.item_name)
	return false # No valid spot found in the entire grid.

func remove_item(item_to_remove: Item) -> Item:
	if item_to_remove == null:
		return null
		
	var removed_item = item_to_remove
	# Iterate using the actual dimensions of the _items array
	for y in range(_items.size()): # Iterating through rows
		for x in range(_items[y].size()): # Iterating through columns in the current row
			# Find all cells that reference this specific item instance and clear them.
			if _items[y][x] == item_to_remove:
				_items[y][x] = null
	emit_signal("inventory_changed")
	return removed_item

static func try_transfer_item(from_grid: InventoryGrid, to_grid: InventoryGrid, item_to_transfer: Item) -> bool:
	if item_to_transfer == null:
		return false
	if not from_grid.has_item(item_to_transfer):
		return false

	if not to_grid.can_place_item(item_to_transfer):
		return false

	# First remove Item from 'fromGrid'
	var removed_item = from_grid.remove_item(item_to_transfer) # GDScript returns directly

	# Then add item to 'toGrid'
	if not to_grid.try_add_item(removed_item):
		# Transfer failed! Add item back to previous inventory
		push_error("Transfer failed! Adding item back to original inventory!")
		from_grid.try_add_item(removed_item)
		return false

	return true

static func try_transfer_item_at(from_grid: InventoryGrid, to_grid: InventoryGrid, item_to_transfer: Item, coords: Vector2i) -> bool:
	if item_to_transfer == null:
		return false
	if not from_grid.has_item(item_to_transfer):
		return false

	if not to_grid.can_place_item_at(item_to_transfer, coords):
		return false

	# First remove Item from 'fromGrid'
	var removed_item = from_grid.remove_item(item_to_transfer) # GDScript returns directly

	# Then add item to 'toGrid'
	if not to_grid.try_place_item_at(removed_item, coords):
		# Transfer failed! Add item back to previous inventory
		push_error("Transfer failed! Adding item back to original inventory!")
		from_grid.try_add_item(removed_item)
		return false

	return true
#endregion

#region Helper Functions

func can_place_item(item_to_check: Item) -> bool:
	if item_to_check == null or item_to_check.shape == null:
		return false
		
	for y in range(inventory_shape.grid_height):
		for x in range(inventory_shape.grid_width):
			var position = Vector2i(x, y)
			if can_place_item_at(item_to_check, position):
				return true
	return false

func can_place_item_at(item: Item, position: Vector2i) -> bool:
	if item == null or item.shape == null:
		return false

	# Check bounds first
	if position.x < 0 or position.y < 0:
		return false

	if use_item_size:
		# Check if the item would fit within the grid boundaries
		if position.x + item.shape.grid_width > inventory_shape.grid_width or \
		   position.y + item.shape.grid_height > inventory_shape.grid_height:
			return false

		# Check each cell that the item would occupy
		for item_y in range(item.shape.grid_height):
			for item_x in range(item.shape.grid_width):
				# Only check cells that are part of the item's shape
				if item.shape.get_grid_shape_cell(item_x, item_y):
					var grid_x = position.x + item_x
					var grid_y = position.y + item_y

					# Double-check bounds (shouldn't be needed due to earlier check, but safe)
					if grid_x >= inventory_shape.grid_width or grid_y >= inventory_shape.grid_height:
						return false

					# Check if the inventory shape allows this cell
					if not inventory_shape.get_grid_shape_cell(grid_x, grid_y):
						return false

					# Check if the cell is already occupied
					if _items[grid_y][grid_x] != null:
						return false
	else:
		# For single-cell items
		if position.x >= inventory_shape.grid_width or position.y >= inventory_shape.grid_height:
			return false

		if not inventory_shape.get_grid_shape_cell(position.x, position.y):
			return false

		if _items[position.y][position.x] != null:
			return false

	return true

func try_place_item_at(item: Item, position: Vector2i) -> bool:
	if not can_place_item_at(item, position):
		return false

	_place_item_at(item, position)
	return true

func _place_item_at(item: Item, position: Vector2i) -> void:
	if item == null:
		return
		
	if use_item_size and item.shape != null:
		for item_y in range(item.shape.grid_height):
			for item_x in range(item.shape.grid_width):
				# Only place a reference to the item if that part of the item's shape exists.
				if item.shape.get_grid_shape_cell(item_x, item_y):
					var grid_x = position.x + item_x
					var grid_y = position.y + item_y
					# Additional bounds check
					if grid_y >= 0 and grid_y < _items.size() and \
					   grid_x >= 0 and grid_x < _items[grid_y].size():
						_items[grid_y][grid_x] = item
	else:
		if position.y >= 0 and position.y < _items.size() and \
		   position.x >= 0 and position.x < _items[position.y].size():
			_items[position.y][position.x] = item

	emit_signal("inventory_changed")

func has_item(item_to_check: Item) -> bool:
	if item_to_check == null:
		return false
		
	for y in range(_items.size()):
		for x in range(_items[y].size()):
			var item: Item = _items[y][x]
			if item == null:
				continue
			if item == item_to_check: # Direct object comparison is fine in GDScript
				return true
	return false

func has_item_at(position: Vector2i) -> Item:
	# Check bounds using actual array dimensions
	if _items.is_empty() or \
	   position.y < 0 or position.y >= _items.size() or \
	   position.x < 0 or position.x >= _items[0].size():
		return null # Out of bounds

	var item: Item = _items[position.y][position.x]
	return item

#endregion
