class_name GridCoords

var x: int = -1
var z: int = -1
var layer: int = -1
var worldCenter: Vector3

func _init(xCoord: int, zCoord: int, layerCoord: int, center: Vector3 = Vector3.ZERO):
	x =xCoord
	z = zCoord
	layer = layerCoord
	worldCenter = center

func _to_string() -> String:
	return " (X: " +str(x) + ",Z: " + str(z) + ",Y: " + str(layer) + ")";
