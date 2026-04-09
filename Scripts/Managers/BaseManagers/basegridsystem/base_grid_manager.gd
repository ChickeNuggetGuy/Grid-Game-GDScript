extends Manager
class_name BaseGridManager

const GRID_CELL_SIZE: int = 25
const GRID_SIZE_X: int = 10
const GRID_SIZE_Z: int = 10
const RAY_LENGTH: int = 400

@export var grid_cell_scene: PackedScene
var grid_cells: Dictionary[Vector2i, BaseGridCell] = {}

var current_base_data : TeamBaseDefinition

func _get_manager_name() -> String:
	return "BaseGridManager"


func _setup_conditions() -> bool:
	return true


func _setup() -> void:
	pass



func _execute() -> void:
	if grid_cell_scene == null:
		push_error("grid_cell_scene is not assigned")
		return

	current_base_data = SceneManager.get_session_value("current_base")
	grid_cells.clear()

	for x in range(GRID_SIZE_X):
		for z in range(GRID_SIZE_Z):
			var grid_cell_node = grid_cell_scene.instantiate()
			var grid_cell: BaseGridCell = grid_cell_node as BaseGridCell

			if grid_cell == null:
				push_error("grid_cell_scene does not instantiate a BaseGridCell")
				return

			var position: Vector3 = Vector3(
				x * GRID_CELL_SIZE,
				0,
				z * GRID_CELL_SIZE
			)

			add_child(grid_cell_node)
			grid_cell_node.position = position
			grid_cells[Vector2i(x, z)] = grid_cell
			
			grid_cell.grid_coordinates = Vector2i(x, z)
			grid_cell.world_position = position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var camera_controller: CameraController = \
				GameManager.get_manager("CameraController")

			if not camera_controller:
				print("Cant find Camera Controller")
				return

			var space_state = get_tree().root.get_world_3d().direct_space_state
			var camera3d = camera_controller.camera_3d
			var from = camera3d.project_ray_origin(event.position)
			var to = from + camera3d.project_ray_normal(event.position) * RAY_LENGTH

			var query = PhysicsRayQueryParameters3D.create(from, to)
			query.collide_with_areas = true

			var result: Dictionary = space_state.intersect_ray(query)

			if result.size() > 0:
				var hit_position: Vector3 = result["position"]
				var grid_cell_result = try_get_gridCell_from_world_position(
					hit_position
				)

				if grid_cell_result["success"]:
					print(grid_cell_result["grid_cell"].grid_coordinates)



func try_get_gridCell_from_world_position(
	worldPosition: Vector3,
	nullGetNearest: bool = false
) -> Dictionary:
	var retVal: Dictionary = {
		"success": false,
		"grid_cell": null
	}

	var x_coord = int(floor(worldPosition.x / GRID_CELL_SIZE))
	var z_coord = int(floor(worldPosition.z / GRID_CELL_SIZE))

	x_coord = clamp(x_coord, 0, GRID_SIZE_X - 1)
	z_coord = clamp(z_coord, 0, GRID_SIZE_Z - 1)

	var target_key = Vector2i(x_coord, z_coord)

	if grid_cells.has(target_key):
		retVal["grid_cell"] = grid_cells[target_key]
		retVal["success"] = true
		return retVal
	elif not nullGetNearest:
		return retVal

	var minDistanceSq := INF
	var nearest_cell: BaseGridCell = null

	for key_coords in grid_cells.keys():
		var candidate_cell: BaseGridCell = grid_cells[key_coords]
		var dist_sq: float = (
			candidate_cell.global_position - worldPosition
		).length_squared()

		if dist_sq < minDistanceSq:
			minDistanceSq = dist_sq
			nearest_cell = candidate_cell

	if nearest_cell != null:
		retVal["grid_cell"] = nearest_cell
		retVal["success"] = true

	return retVal


#region Save/Load Functions
func save_data() -> Dictionary:
	return {}

func load_data_call(data_dict: Dictionary) -> void:
	pass
#endregion
