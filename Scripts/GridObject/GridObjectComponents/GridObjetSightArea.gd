extends GridObjectComponent
class_name GridObjectSightArea

@export var sight_range_degrees : Vector2 = Vector2(46, 65)
@export var sight_depth : float = 10
var seen_cells : Dictionary[Vector3i, GridCell] = {}
var seen_gridObjects: Dictionary[Enums.unitTeam, Array] = {}
func _setup():
	#Manager.get_instance("UnitActionManager").connect("action_execution_finished", UnitActionManager_action_execution_finished)
	return


func update_sight_area() -> Dictionary:
	var ret_value = {"success": false, "seen_grid_cells" : {}, "seen_grid_objects" : []}
	if parent_grid_object == null:
		return ret_value

	seen_gridObjects.clear()

	var current_cell: GridCell = parent_grid_object.grid_position_data.grid_cell
	if current_cell == null:
		return ret_value

	var forward_dir = -parent_grid_object.global_transform.basis.z

	var result = Manager.get_instance("GridSystem").try_get_cells_in_cone(
		current_cell,
		forward_dir,
		sight_depth,
		sight_range_degrees.x, # horizontal FOV
		Enums.cellState.NONE
	)

	if result["success"]:
		seen_cells = result["cells"]
		for key in seen_cells.keys():
			var cell = seen_cells[key]
			cell.fog_status = Enums.FogState.VISIBLE
			
			if cell.has_grid_object():
				var seen_object: GridObject = cell.grid_object
					
				# Skip self
				if seen_object == parent_grid_object:
					continue

				var team = seen_object.team

				# If team key doesn't exist, create it
				if not seen_gridObjects.has(team):
					seen_gridObjects[team] = []

				# Skip if this object is already in the list
				if seen_gridObjects[team].has(seen_object):
					continue

				# Add the object
				seen_gridObjects[team].append(seen_object)

				# Debug print
				print(parent_grid_object.name, " sees ", seen_object.name)
		
		ret_value["success"] = true
		ret_value["seen_grid_cells"] = seen_cells
		ret_value["seen_grid_objects"] = seen_gridObjects
		return ret_value
		
	else:
		ret_value["success"] = false
		ret_value["seen_grid_cells"] = {}
		ret_value["seen_grid_objects"] = []
		return ret_value
		#FogManager.Instance.update_fog_texture(dict)
