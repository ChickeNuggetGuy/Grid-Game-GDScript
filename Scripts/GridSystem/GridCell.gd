class_name GridCell
#region Variables

var gridCoordinates: GridCoords

var walkable: bool = false

var gridInventory

var gridSystem: GridSystem
var gridObject

#endregion
#region Functions
func _init(xCoord: int, zCoord: int, layerCoord: int, worldPos: Vector3, walkableVal: bool, inventory, parentGridSystem: GridSystem):
	gridCoordinates = GridCoords.new(xCoord,zCoord,layerCoord, worldPos)
	gridCoordinates.worldCenter = worldPos
	self.walkable = walkableVal;
	self.gridInventory = inventory 
	self.gridSystem = parentGridSystem
	self.gridObject = gridObject

func hasGridObject():return gridObject != null

func hasSpecificGridObject(gridObjectToCheck):return gridObject == gridObjectToCheck

func _to_string() -> String:
	return gridCoordinates._to_string() + " \nwalkable: " + str(walkable)
#endregion
