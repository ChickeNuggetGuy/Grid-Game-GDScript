extends Resource
class_name GlobeHexBaked

@export var subdivisions: int
@export var cells_mesh: ArrayMesh
@export var grid_mesh: ArrayMesh
@export var centers: PackedVector3Array
@export var neighbors: Array[PackedInt32Array]
@export var polygons: Array[PackedVector3Array]
