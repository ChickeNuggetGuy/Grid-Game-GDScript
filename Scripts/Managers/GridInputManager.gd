extends Manager
class_name GridInputManager
#region Variables
var gridSystem: GridSystem
var currentGridCell : GridCell;
var visual : Node3D


#endregion

signal grid_cell_selected(grid_cell : GridCell)
#region Functions



func on_scene_changed(_new_scene: Node):
	if not GameManager.Instance.current_scene_name == "BattleScene":
		queue_free()

func _on_exit_tree() -> void:
	return

func _process(_delta: float) -> void:
	if not execute_complete: return
		
	if !GameManager.execution_completed:
		return
	var mp   = get_viewport().get_mouse_position()
	var from = get_tree().root.get_viewport().get_camera_3d().project_ray_origin(mp)
	var dir  = get_viewport().get_camera_3d().project_ray_normal(mp)
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
			if r["success"]:
				if r["grid_cell"].grid_cell_state == Enums.cellState.AIR:
					var temp_cell = gridSystem.get_cell_below_recursive(r["grid_cell"].grid_coordinates, Enums.cellState.GROUND)
					
					if temp_cell == null:
						currentGridCell = null
						
					else:
						currentGridCell = temp_cell
						
				else:
					currentGridCell = r["grid_cell"]
					
			else:
				currentGridCell = null
				
	else:
		currentGridCell = null
	
	if currentGridCell == null:
		visual.position = Vector3(-10,-10,-10)
		#UiManager.currentCellUI.text = ""
	else:
		#UiManager.currentCellUI.text = "Current Gridcell: " + currentGridCell.to_string()
		visual.position = currentGridCell.world_position


func _get_manager_name() -> String: return "GridInputManager"


func _setup_conditions() -> bool: return true


func _setup(): 
	gridSystem = GameManager.managers["GridSystem"]
	visual = CSGBox3D.new()
	add_child(visual)
	setup_completed.emit()


func _execute_conditions() -> bool: return true


func _execute(): execution_completed.emit() 


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if currentGridCell != null:
				grid_cell_selected.emit(currentGridCell)
		
#endregion
