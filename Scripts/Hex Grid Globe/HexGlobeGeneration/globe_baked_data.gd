extends Resource
class_name GlobeBakedData

@export var grid_index: GridIndex
@export var cell_country_indices: PackedInt32Array = PackedInt32Array()

# def_type(int) -> Array[Dictionary]
@export var cell_definitions: Dictionary = {}
