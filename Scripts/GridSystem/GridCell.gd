class_name GridCell
#region Variables

var gridCoordinates: Vector3i
var world_position: Vector3

var grid_cell_state : Enums.cellState

var inventory_grid : InventoryGrid

var gridSystem: GridSystem
var grid_object : GridObject

#endregion
#region Functions
func _init(xCoord: int, layerCoord: int, zCoord: int, worldPos: Vector3, cell_state: Enums.cellState, inventory : InventoryGrid, parentGridSystem: GridSystem):
	gridCoordinates = Vector3i(xCoord,layerCoord,zCoord)
	world_position = worldPos
	self.grid_cell_state = cell_state;
	self.inventory_grid = inventory 
	self.inventory_grid.initialize()
	self.inventory_grid.connect("item_added", inventory_grid_item_added)
	self.gridSystem = parentGridSystem

func set_gridobject(target : GridObject, cell_state : Enums.cellState):
	self.grid_object = target
	grid_cell_state = cell_state
func hasGridObject():return grid_object != null

func hasSpecificGridObject(gridObjectToCheck):return grid_object == gridObjectToCheck

func _to_string() -> String:
	return str(gridCoordinates) + "state: " + str(grid_cell_state)


func inventory_grid_item_added(item_added : Item):
	
	if item_added == null: 
		print("item added was null")
		return
	
	if grid_cell_state & Enums.cellState.AIR:
		var result = GridSystem.try_get_grid_cell_of_state_below(gridCoordinates, Enums.cellState.GROUND)
		if result["success"]:
			InventoryGrid.try_transfer_item(inventory_grid, result["grid_cell"].inventory_grid, item_added)
			print("Item was in air at " + self.to_string() + " and was moved to " + result["grid_cell"].to_string())
		#Grid Cell is in air so Item should be passed downward untill ground is met
	
#endregion
