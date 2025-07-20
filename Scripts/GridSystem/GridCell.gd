class_name GridCell
#region Variables

var gridCoordinates: Vector3i
var worldPosition: Vector3

var walkable: bool = false

var gridInventory

var gridSystem: GridSystem
var gridObject

#endregion
#region Functions
func _init(xCoord: int, layerCoord: int, zCoord: int, worldPos: Vector3, walkableVal: bool, inventory, parentGridSystem: GridSystem):
	gridCoordinates = Vector3i(xCoord,layerCoord,zCoord)
	worldPosition = worldPos
	self.walkable = walkableVal;
	self.gridInventory = inventory 
	self.gridSystem = parentGridSystem
	self.gridObject = gridObject

func set_gridobject(target : GridObject):
	self.gridObject = target
func hasGridObject():return gridObject != null

func hasSpecificGridObject(gridObjectToCheck):return gridObject == gridObjectToCheck

func _to_string() -> String:
	return str(gridCoordinates) + " \nwalkable: " + str(walkable)
#endregion
