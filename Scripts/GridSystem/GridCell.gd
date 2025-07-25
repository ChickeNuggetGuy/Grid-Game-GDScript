class_name GridCell
#region Variables

var gridCoordinates: Vector3i
var worldPosition: Vector3

var walkable: bool = false

var gridInventory : InventoryGrid

var gridSystem: GridSystem
var gridObject

#endregion
#region Functions
func _init(xCoord: int, layerCoord: int, zCoord: int, worldPos: Vector3, walkableVal: bool, inventory : InventoryGrid, parentGridSystem: GridSystem):
	gridCoordinates = Vector3i(xCoord,layerCoord,zCoord)
	worldPosition = worldPos
	self.walkable = walkableVal;
	self.gridInventory = inventory 
	self.gridInventory.initialize()
	self.gridSystem = parentGridSystem
	self.gridObject = gridObject

func set_gridobject(target : GridObject, walkability : bool):
	self.gridObject = target
	walkable =walkability
func hasGridObject():return gridObject != null

func hasSpecificGridObject(gridObjectToCheck):return gridObject == gridObjectToCheck

func _to_string() -> String:
	return str(gridCoordinates) + " \nwalkable: " + str(walkable)
#endregion
