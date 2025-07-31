class_name GridCell
#region Variables

var gridCoordinates: Vector3i
var worldPosition: Vector3

var grid_cell_state : Enums.cellState

var gridInventory : InventoryGrid

var gridSystem: GridSystem
var gridObject

#endregion
#region Functions
func _init(xCoord: int, layerCoord: int, zCoord: int, worldPos: Vector3, cell_state: Enums.cellState, inventory : InventoryGrid, parentGridSystem: GridSystem):
	gridCoordinates = Vector3i(xCoord,layerCoord,zCoord)
	worldPosition = worldPos
	self.grid_cell_state = cell_state;
	self.gridInventory = inventory 
	self.gridInventory.initialize()
	self.gridSystem = parentGridSystem
	self.gridObject = gridObject

func set_gridobject(target : GridObject, cell_state : Enums.cellState):
	self.gridObject = target
	grid_cell_state = cell_state
func hasGridObject():return gridObject != null

func hasSpecificGridObject(gridObjectToCheck):return gridObject == gridObjectToCheck

func _to_string() -> String:
	return str(gridCoordinates) + "state: " + str(grid_cell_state)
#endregion
