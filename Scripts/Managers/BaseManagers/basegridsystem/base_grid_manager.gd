extends Manager
class_name BaseGridManager

const GRID_CELL_SIZE : int = 25
const GRID_SIZE_X : int = 10
const GRID_SIZE_Z : int = 10

@export var grid_cell_mesh : Mesh
var grid_system : Dictionary[Vector2i, BaseGridCell]
func _get_manager_name() -> String: return "BaseGridManager"



func _setup_conditions() -> bool: return true

func _setup() -> void:
	pass


func _execute_conditions() -> bool: return true


func _execute() -> void:
	
	for x in range(GRID_SIZE_X):
		for z in range(GRID_SIZE_Z):
			var grid_cell : BaseGridCell = BaseGridCell.new(grid_cell_mesh)
			var position : Vector3 = Vector3(x * GRID_CELL_SIZE, 0 , z * GRID_SIZE_Z)
			
			add_child(grid_cell)
			grid_cell.position = position
			
	pass

#region Save/Load Functions
func save_data() -> Dictionary:
	return {}

func load_data_call(data_dict: Dictionary) -> void:
	pass
#endregion
