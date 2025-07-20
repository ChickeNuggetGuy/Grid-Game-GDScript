extends Manager

#region Variables
var camera : Camera3D
var gridSystem: GridSystem
var currentGridCell : GridCell;
var visual : Node3D
#endregion

#region Functions
func _ready() -> void:
	camera = CameraController.instance;
	gridSystem = GridSystem
	visual = CSGBox3D.new()
	add_child(visual)


func _process(delta: float) -> void:
	var mp   = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mp)
	var dir  = camera.project_ray_normal(mp)
	var to   = from + dir * 1000.0  # lengthen as needed

	var space = get_tree().root.get_viewport().world_3d.direct_space_state
	var params = PhysicsRayQueryParameters3D.new()
	params.from = from
	params.to = to
	params.exclude = []
	params.collision_mask = PhysicsLayer.TERRAIN | PhysicsLayer.PLAYER
	params.collide_with_bodies = true
	params.collide_with_areas = false
	var hit = space.intersect_ray(params)

	if hit:
		if hit.collider.collision_layer == PhysicsLayer.PLAYER:
			var current_node = hit.collider
			while current_node:
				if current_node is GridObject:
					currentGridCell = current_node.grid_position_data.grid_cell
					break # Found it, stop traversing
				elif current_node.get_parent():
					current_node = current_node.get_parent()
				else:
					current_node = null
					
		else:
			var hit_pos = hit.position
			var r = gridSystem.try_get_gridCell_from_world_position(hit_pos)
			currentGridCell = r["gridCell"] if r["success"] else null
	else:
		currentGridCell = null
	
	if currentGridCell == null:
		visual.position = Vector3(-10,-10,-10)
		UiManager.currentCellUI.text = ""
	else:
		UiManager.currentCellUI.text = "Current Gridcell: " + currentGridCell.to_string()
		visual.position = currentGridCell.worldPosition

func _get_manager_name() -> String: return "GridInputManager"

func _setup_conditions(): return

func _setup(): 
	print("HELP")
	setup_completed.emit()

func _execute_conditions() -> bool: return true

func _execute(): execution_completed.emit() 
#endregion
