extends Manager
class_name GridInputManager
#region Variables
var gridSystem: GridSystem
var current_grid_cell : GridCell;
var visual : Node3D

var label_3d_holder : Node3D

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

	# Clear old debug visuals first
	for child in label_3d_holder.get_children():
		child.queue_free()

	var mp   = get_viewport().get_mouse_position()
	var from = get_tree().root.get_viewport().get_camera_3d().project_ray_origin(mp)
	var dir  = get_viewport().get_camera_3d().project_ray_normal(mp)
	var to   = from + dir * 1000.0

	var space = get_tree().root.get_viewport().world_3d.direct_space_state
	var params = PhysicsRayQueryParameters3D.new()
	params.from = from
	params.to = to
	params.exclude = []
	params.collision_mask = PhysicsLayer.TERRAIN | PhysicsLayer.GRIDOBJECT | PhysicsLayer.OBSTACLE
	params.collide_with_bodies = true
	params.collide_with_areas = false
	var hit = space.intersect_ray(params)

	if hit:
		# Check if the hit is on GRIDOBJECT layer but NOT on OBSTACLE layer
		if (hit.collider.collision_layer & PhysicsLayer.GRIDOBJECT) and \
		   not (hit.collider.collision_layer & PhysicsLayer.OBSTACLE):
			# Try to get grid cell from GridObject directly
			var current_node = hit.collider
			current_grid_cell = null
			while current_node:
				if current_node is GridObject:
					current_grid_cell = current_node.grid_position_data.grid_cell
					break
				elif current_node.get_parent():
					current_node = current_node.get_parent()
				else:
					break
		else:
			# Fallback to standard grid cell detection (e.g. for obstacles or terrain)
			var hit_pos = hit.position
			var r = gridSystem.try_get_gridCell_from_world_position(hit_pos)
			if r["success"]:
				if r["grid_cell"].grid_cell_state == Enums.cellState.AIR:
					var temp_cell = gridSystem.get_cell_below_recursive(r["grid_cell"].grid_coordinates, Enums.cellState.GROUND)
					current_grid_cell = temp_cell
				else:
					current_grid_cell = r["grid_cell"]
			else:
				current_grid_cell = null
	else:
		current_grid_cell = null

	if current_grid_cell == null:
		visual.position = Vector3(-10, -10, -10)
		return
	else:
		visual.position = current_grid_cell.world_position

	var unit_manager : UnitManager = GameManager.managers["UnitManager"]
	if not unit_manager:
		return

	var selected_unit : Unit = unit_manager.selectedUnit
	if not selected_unit:
		return

	var path : Array[GridCell] = Pathfinder.find_path(selected_unit.grid_position_data.grid_cell, current_grid_cell)
	if path.is_empty():
		return

	var new_path_dict = MoveActionDefinition.get_move_cost_values(selected_unit, path)
	if not new_path_dict or new_path_dict.size() < 1:
		return
		
	# Create new labels for time units
	for cell in new_path_dict.keys():
		var next_cell_index = path.find(cell) + 1
		var label_3d : Label3D = Label3D.new()
		label_3d.autowrap_mode = TextServer.AUTOWRAP_OFF
		label_3d.text = str(new_path_dict[cell]["time_units"])
		label_3d.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		label_3d.modulate = Color.YELLOW
		label_3d.pixel_size = .01
		label_3d.font_size = 16
		label_3d.position = cell.world_position + Vector3(0, 1, 0)
		label_3d_holder.add_child(label_3d)

		if next_cell_index < path.size():
			DebugDraw3D.draw_arrow(
				cell.world_position + Vector3(0, 0.5, 0),
				path[next_cell_index].world_position + Vector3(0, 0.5, 0),
				Color.WEB_GREEN,
				0.8
			)
		else:
			DebugDraw3D.draw_box(cell.grid_coordinates, Quaternion.IDENTITY, Vector3(1,1,1), Color.BLACK)


func _get_manager_name() -> String: return "GridInputManager"


func _setup_conditions() -> bool: return true


func _setup(): 
	gridSystem = GameManager.managers["GridSystem"]
	visual = CSGBox3D.new()
	visual.use_collision =false 
	add_child(visual)
	setup_completed.emit()
	label_3d_holder = Node3D.new()
	label_3d_holder.name = "label 3D holder"
	add_child(label_3d_holder)


func save_data() -> Dictionary:
	var save_dict = {
		"filename" : get_scene_file_path(),
		"parent" : get_parent().get_path(),
	}
	return save_dict


func _execute_conditions() -> bool: return true


func _execute(): execution_completed.emit() 


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if current_grid_cell != null:
				grid_cell_selected.emit(current_grid_cell)
#endregion
