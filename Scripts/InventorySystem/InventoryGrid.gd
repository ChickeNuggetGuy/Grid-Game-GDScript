@tool
class_name InventoryGrid extends Resource

#region Variables
@export var inventory_name: String = ""

# Correct way to export a resource of a specific class_name
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

var _items: Array[Array] # Represents the 2D grid: Array[Array[Item]]

@export var use_item_size: bool = true

@export var item_count: int:
	get:
		if _items == null:
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
	if not inventory_shape is GridShape:
		push_error("InventoryShape was assigned a generic Resource — please assign a GridShape asset in the Inspector.")
		return

	if inventory_shape.grid_width <= 0 or inventory_shape.grid_height <= 0:
		push_error("InventoryGrid must have a size with positive X and Y values.")
		_items = [] # Set to empty 2D array if invalid size
		return

	# Initialize the 2D array: Array of rows, each row is an Array of Items
	_items.clear()
	_items.resize(inventory_shape.grid_height) # Height determines number of rows
	for y in range(inventory_shape.grid_height):
		_items[y] = Array()
		_items[y].resize(inventory_shape.grid_width) # Width determines number of columns in each row
		_items[y].fill(null) # Fill with null initially

	# The C# code had a commented out section for initializing default InventoryShape if null.
	# In GDScript, it's typically better to ensure 'inventory_shape' is assigned in the editor,
	# or initialized within the Item's constructor/initialize_shape method.
	# If 'inventory_shape' is null at this point, the initial check would have caught it.


func try_add_item(item_to_add: Item) -> bool:
	# Ensure the item's own shape is initialized.
	# item_to_add.initialize_shape() # This should ideally be handled by the Item itself

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
	for y in range(inventory_shape.grid_height):
		for x in range(inventory_shape.grid_width):
			var position = Vector2i(x, y)
			if can_place_item_at(item_to_check, position):
				return true
	return false


func can_place_item_at(item: Item, position: Vector2i) -> bool:
	if item == null or item.shape == null:
		return false

	if use_item_size:
		# Optional: Early out if the item obviously won’t fit
		if position.x + item.shape.grid_width > inventory_shape.grid_width or \
		   position.y + item.shape.grid_height > inventory_shape.grid_height:
			return false

		for item_y in range(item.shape.grid_height):
			for item_x in range(item.shape.grid_width):
				if not item.shape.get_grid_shape_cell(item_x, item_y):
					continue

				var grid_x = position.x + item_x
				var grid_y = position.y + item_y

				# Already ensured bounds above, but safe to double-check
				if grid_x < 0 or grid_y < 0 or \
				   grid_x >= inventory_shape.grid_width or grid_y >= inventory_shape.grid_height:
					return false

				if not inventory_shape.get_grid_shape_cell(grid_x, grid_y):
					return false

				if _items[grid_y][grid_x] != null: # Accessing as _items[row][column]
					return false
	else:
		if position.x < 0 or position.y < 0 or \
		   position.x >= inventory_shape.grid_width or position.y >= inventory_shape.grid_height:
			return false

		if not inventory_shape.get_grid_shape_cell(position.x, position.y):
			return false

		if _items[position.y][position.x] != null: # Accessing as _items[row][column]
			return false

	return true

func try_place_item_at(item: Item, position: Vector2i) -> bool:
	if not can_place_item_at(item, position):
		return false

	_place_item_at(item, position)
	return true


func _place_item_at(item: Item, position: Vector2i) -> void:
	if use_item_size:
		for item_y in range(item.shape.grid_height):
			for item_x in range(item.shape.grid_width):
				# Only place a reference to the item if that part of the item's shape exists.
				if item.shape.get_grid_shape_cell(item_x, item_y):
					var grid_x = position.x + item_x
					var grid_y = position.y + item_y
					_items[grid_y][grid_x] = item # Accessing as _items[row][column]
	else:
		_items[position.y][position.x] = item # Accessing as _items[row][column]

	emit_signal("inventory_changed")

func has_item(item_to_check: Item) -> bool:
	for y in range(_items.size()):
		for x in range(_items[y].size()):
			var item: Item = _items[y][x]
			if item == null:
				continue
			if item == item_to_check: # Direct object comparison is fine in GDScript
				return true
	return false

func has_item_at(position: Vector2i) -> Item: # Returns Item or null, similar to C# out parameter pattern
	if position.y >= _items.size() or position.x >= _items[0].size(): # Check bounds using actual array dimensions
		return null # Out of bounds

	var item: Item = _items[position.y][position.x]
	return item # Will be Item or null

#endregion
