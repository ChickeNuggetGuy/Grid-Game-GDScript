extends GridObjectComponent
class_name GridObjectSightArea

@export var sight_range_degrees: Vector2 = Vector2(46, 65)
@export var sight_depth: float = 10


var seen_cells: Dictionary = {}
var seen_gridObjects: Dictionary = {}

func _setup(_extra_params: Dictionary):
	pass

func has_line_of_sight(from_cell: GridCell, to_cell: GridCell) -> bool:
	if from_cell == to_cell:
		return true
	var sight_height_offset = 2
	var from_pos: Vector3 = from_cell.world_position + Vector3(0, sight_height_offset, 0)
	var to_pos: Vector3 = to_cell.world_position + Vector3(0, sight_height_offset, 0)
	
	# Create raycast query
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	

	query.collision_mask = 	~(PhysicsLayer.OBSTACLE | PhysicsLayer.TERRAIN)
	
	var result = space_state.intersect_ray(query)
	
	return result.is_empty()


func update_sight_area(set_cell_visibility: bool) -> Dictionary:
	if parent_grid_object == null or parent_grid_object.grid_position_data.grid_cell == null:
		return {"success": false, "seen_grid_cells": {}, "seen_grid_objects": {}}

	var current_cell: GridCell = parent_grid_object.grid_position_data.grid_cell
	var forward_dir: Vector3 = -parent_grid_object.global_transform.basis.z

	var main_sight_result = GameManager.managers["GridSystem"].try_get_cells_in_cone(
		current_cell,
		forward_dir,
		sight_depth,
		sight_range_degrees.x,
		Enums.cellState.NONE
	)

	var peripheral_sight_result = GameManager.managers["GridSystem"].try_get_cells_in_cone(
		current_cell,
		forward_dir,
		4, 
		181, 
		Enums.cellState.NONE
	)

	if not main_sight_result["success"]:
		return {"success": false, "seen_grid_cells": {}, "seen_grid_objects": {}}
		
	var potential_cells: Dictionary = main_sight_result["cells"]
	if peripheral_sight_result["success"]:
		potential_cells.merge(peripheral_sight_result["cells"])

	var newly_seen_cells: Dictionary = {current_cell.grid_coordinates: current_cell}

	for cell in potential_cells.values():
		if cell == current_cell:
			continue
			
		if has_line_of_sight(current_cell, cell):
			newly_seen_cells[cell.grid_coordinates] = cell

	var newly_seen_objects: Dictionary = {}
	
	for cell in newly_seen_cells.values():
		if set_cell_visibility:
			cell.fog_status = Enums.FogState.VISIBLE

		if cell.has_grid_object() and cell.grid_object != parent_grid_object and cell.grid_object is Unit:
			var seen_object: GridObject = cell.grid_object
			var team = seen_object.team

			if not newly_seen_objects.has(team):
				newly_seen_objects[team] = []
			
			if not newly_seen_objects[team].has(seen_object):
				newly_seen_objects[team].append(seen_object)

	self.seen_cells = newly_seen_cells
	self.seen_gridObjects = newly_seen_objects

	return {
		"success": true,
		"seen_grid_cells": self.seen_cells,
		"seen_grid_objects": self.seen_gridObjects
	}
