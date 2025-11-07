class_name GridCell

#region Variables
var grid_coordinates: Vector3i
var world_position: Vector3
var grid_cell_connections : Array[GridCell] = []

var fog_status: Enums.FogState = Enums.FogState.UNSEEN
var original_grid_cell_state: Enums.cellState
var grid_cell_state: Enums.cellState

var inventory_grid: InventoryGrid
var grid_object: GridObject

var team_spawn : Enums.unitTeam = Enums.unitTeam.ANY

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

func inventory_grid_item_added(item_added: Item) -> void:
	var grid_system : GridSystem = GameManager.managers["GridSystem"]
	if item_added == null:
		print("item added was null")
		return

	if grid_cell_state & Enums.cellState.AIR:
		var result = GameManager.managers["GridSystem"].Instance.\
			try_get_grid_cell_of_state_below(
				grid_coordinates,
				Enums.cellState.GROUND
			)
		if result["success"]:
			InventoryGrid.try_transfer_item(
				inventory_grid,
				result["grid_cell"].inventory_grid,
				item_added
			)
			print(
				"Item was in air at "
				+ self.to_string()
				+ " and was moved to "
				+ result["grid_cell"].to_string()
			)

	# Bitflag-safe checks
	if bool(grid_cell_state & Enums.cellState.OBSTRUCTED) or \
		bool(grid_cell_state & Enums.cellState.AIR):
		clear_connections()
	elif bool(grid_cell_state & Enums.cellState.WALKABLE):
		grid_system.generate_connections_for_cell(
			self,
			grid_system.get_tree().root.world_3d.direct_space_state
		)

func set_grid_cell_connections(connected_grid_cells : Array[GridCell]):
	grid_cell_connections.append_array(connected_grid_cells)


func clear_connections() -> void:
	grid_cell_connections.clear()

func add_connection(other: GridCell) -> void:
	if other == null or other == self:
		return
	if not grid_cell_connections.has(other):
		grid_cell_connections.append(other)

func has_connection(other: GridCell) -> bool:
	return grid_cell_connections.has(other)


func add_cell_state(state: Enums.cellState) -> void:
	var old_state = grid_cell_state
	grid_cell_state = grid_cell_state | state
	if old_state != grid_cell_state:
		_handle_state_change()

func remove_cell_state(state: Enums.cellState) -> void:
	var old_state = grid_cell_state
	grid_cell_state = grid_cell_state & ~state
	if old_state != grid_cell_state:
		_handle_state_change()

func set_cell_state_exclusive(state: Enums.cellState) -> void:
	var old_state = grid_cell_state
	grid_cell_state = state
	if old_state != grid_cell_state:
		_handle_state_change()

func _handle_state_change() -> void:
	var grid_system: GridSystem = GameManager.managers["GridSystem"]
	var cs = GameManager.managers["MeshTerrainManager"].cell_size
	
	# Debug visualization
	DebugDraw3D.draw_box(
		world_position,
		Quaternion.IDENTITY,
		Vector3(cs.x, cs.y, cs.x),
		Color.YELLOW,
		true,
		25
	)
	
	# Handle connections based on new state
	if bool(grid_cell_state & Enums.cellState.AIR):
		# Only clear connections for AIR cells
		clear_connections()
	elif bool(grid_cell_state & Enums.cellState.WALKABLE):
		# Generate connections for walkable cells
		grid_system.generate_connections_for_cell(
			self,
			grid_system.get_tree().root.world_3d.direct_space_state
		)
	# DON'T clear connections for OBSTRUCTED cells - units need to move out of them

# Update the existing set_grid_cell_state method:
func set_grid_cell_state(state: Enums.cellState) -> void:
	set_cell_state_exclusive(state)
#endregion
