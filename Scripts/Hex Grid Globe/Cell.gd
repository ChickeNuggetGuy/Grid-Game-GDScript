class_name Cell
	
var id: int = -1
var center_unit: Vector3 = Vector3.ZERO
var polygon: PackedVector3Array = PackedVector3Array()
var neighbors: PackedInt32Array = PackedInt32Array()
var is_pentagon: bool = false
var color: Color = Color.WHITE
