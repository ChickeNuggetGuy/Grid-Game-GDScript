class_name GridCell

#region Variables
var grid_coordinates: Vector3i
var world_position: Vector3

var fog_status: Enums.FogState = Enums.FogState.VISIBLE
var original_grid_cell_state: Enums.cellState
var grid_cell_state: Enums.cellState

var inventory_grid: InventoryGrid
var grid_object: GridObject

#endregion

#region Functions
func _init(xCoord: int, layerCoord: int, zCoord: int, worldPos: Vector3,
		cell_state: Enums.cellState,
		fog_state: Enums.FogState,
		inventory: InventoryGrid):
	grid_coordinates = Vector3i(xCoord, layerCoord, zCoord)
	world_position = worldPos
	original_grid_cell_state = cell_state
	grid_cell_state = cell_state
	fog_status = fog_state
	inventory_grid = inventory 
	inventory_grid.initialize()
	inventory_grid.connect("item_added", inventory_grid_item_added)

func set_gridobject(target: GridObject, cell_state: Enums.cellState):
	grid_object = target
	grid_cell_state = cell_state

func restore_original_state():
	grid_cell_state = original_grid_cell_state
	grid_object = null

func get_original_state() -> Enums.cellState:
	return original_grid_cell_state

func has_grid_object() -> bool:
	return grid_object != null

func has_specific_gridObject(gridObjectToCheck) -> bool:
	return grid_object == gridObjectToCheck

func _to_string() -> String:
	return str(grid_coordinates) + " state: " + str(grid_cell_state)

func inventory_grid_item_added(item_added: Item):
	if item_added == null: 
		print("item added was null")
		return
	
	if grid_cell_state & Enums.cellState.AIR:
		var result =GameManager.managers[" GridSystem"].Instance.try_get_grid_cell_of_state_below(grid_coordinates, Enums.cellState.GROUND)
		if result["success"]:
			InventoryGrid.try_transfer_item(inventory_grid, result["grid_cell"].inventory_grid, item_added)
			print("Item was in air at " + self.to_string() + " and was moved to " + result["grid_cell"].to_string())

#endregion
