extends Node

static func _create_neighbor_offsets() -> Array:
	var arr := []
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for dl in range(-1, 2):
				if dx == 0 and dz == 0 and dl == 0:
					continue
				arr.append(Vector3i(dx, dl, dz))
	return arr

@onready var NEIGHBOR_OFFSETS = _create_neighbor_offsets()
@onready var _heap = preload("res://Scripts/Utility/MinHeap.gd").new()

func find_path(start: GridCell, goal: GridCell, adjacent_is_valid: bool=false) -> Array:
	return _find_path_internal(start, goal, adjacent_is_valid)

func find_path_coords(start_coords: Vector3i, goal_coords: Vector3i, adjacent_is_valid: bool=false) -> Array:
	var dict = GridSystem.grid_cells
	if not dict.has(start_coords) or not dict.has(goal_coords):
		return []
	return find_path(dict[start_coords], dict[goal_coords], adjacent_is_valid)

func is_path_possible(start: GridCell, goal: GridCell, adjacent_is_valid: bool=false) -> bool:
	return find_path(start, goal, adjacent_is_valid).size() > 0

func is_path_possible_coords(start_coords: Vector3i, goal_coords: Vector3i, adjacent_is_valid: bool=false) -> bool:
	return find_path_coords(start_coords, goal_coords, adjacent_is_valid).size() > 0

func _find_path_internal(start: GridCell, goal: GridCell, adjacent: bool) -> Array:
	var path := []
	if start == null or goal == null:
		return path
	var dict = GridSystem.grid_cells
	if not adjacent and not goal.grid_cell_state & Enums.cellState.WALKABLE:
		return path
	if start == goal and goal.grid_cell_state & Enums.cellState.WALKABLE:
		return [start]

	var targets := []
	if adjacent:
		var gk = goal.gridCoordinates
		for off in NEIGHBOR_OFFSETS:
			var nk = gk + off
			if dict.has(nk) and dict[nk].walkable:
				targets.append(dict[nk])
		if targets.is_empty():
			return path
		if start in targets:
			return [start]
	else:
		targets.append(goal)

	var closed_set := {}
	var g_score := {}
	var f_score := {}
	var came_from := {}

	g_score[start] = 0.0
	f_score[start] = _min_heuristic(start, targets)
	_heap.clear()
	_heap.push({"cell": start, "f": f_score[start]})

	while not _heap.is_empty():
		var rec = _heap.pop()
		var current: GridCell = rec.cell
		if current in targets:
			while current:
				path.insert(0, current)
				current = came_from.get(current, null)
			return path

		closed_set[current] = true
		var ckey = current.gridCoordinates

		for off in NEIGHBOR_OFFSETS:
			var nk = ckey + off
			if not dict.has(nk):
				continue
			var neighbor = dict[nk]
			if closed_set.has(neighbor):
				continue

			var tentative_g = g_score[current] + _cost(current, neighbor)
			if not g_score.has(neighbor) or tentative_g < g_score[neighbor]:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				var h = _min_heuristic(neighbor, targets)
				f_score[neighbor] = tentative_g + h
				_heap.push({"cell": neighbor, "f": f_score[neighbor]})
	return []  # no path found

func _min_heuristic(a: GridCell, targets: Array) -> float:
	var best = INF
	for t in targets:
		var dx = a.gridCoordinates.x - t.gridCoordinates.x
		var dz = a.gridCoordinates.z - t.gridCoordinates.z
		var dl = a.gridCoordinates.y - t.gridCoordinates.y
		best = min(best, Vector3(dx, dl, dz).length())
	return best

func _cost(a: GridCell, b: GridCell) -> float:
	var dx = a.gridCoordinates.x - b.gridCoordinates.x
	var dz = a.gridCoordinates.z - b.gridCoordinates.z
	var dl = a.gridCoordinates.y - b.gridCoordinates.y
	return Vector3(dx, dl, dz).length()



func try_calculate_arc_path(start_pos: GridCell, end_pos: GridCell, attempts: int = 3) -> Dictionary:
	var ret_val = {"success": false, "grid_cell_path": [], "vector3_path": []}
	
	var start = start_pos
	var end = end_pos
	var cell_size = GridSystem.gridCellSize

	# Validate start and end points
	if start.grid_cell_state & Enums.cellState.OBSTRUCTED \
			or end.grid_cell_state & Enums.cellState.OBSTRUCTED:
		print("Start or end point is obstructed.")
		return ret_val

	# Calculate the direction and distance
	var direction = end.worldPosition - start.worldPosition
	var distance = direction.length()

	# Try different arc heights
	for attempt in range(attempts):
		# Calculate arc height with variation for each attempt
		# Base height with variation factor (0.1 to 0.3 for first 3 attempts)
		var height_factor = 0.5 + (attempt * 0.2)
		var arc_height = distance * height_factor
		
		print("Attempt ", attempt + 1, " with arc height: ", arc_height)

		# Number of points to sample along the arc
		var num_points = int(distance / (cell_size.y * 0.5)) + 1

		# Keep track of the last added grid cell to avoid duplicates
		var last_grid_cell: GridCell = null
		
		# Reset return value for this attempt
		ret_val = {"success": false, "grid_cell_path": [], "vector3_path": []}
		var path_valid = true
		
		# Store positions for the smooth path
		var smooth_path = []

		for i in range(num_points + 1):
			var t = float(i) / num_points # Interpolation factor (0 to 1)

			# Calculate the current position along the straight line
			var current_pos = start.worldPosition.lerp(end.worldPosition, t)

			# Calculate the vertical offset for the arc (parabolic shape)
			var vertical_offset = -4 * arc_height * t * (t - 1) # Parabola formula

			# Apply the vertical offset to create the arc
			var arc_pos = current_pos + Vector3.UP * vertical_offset
			
			# Store the smooth path position
			smooth_path.append(arc_pos)

			# Convert world position to grid coordinates
			var get_grid_cell_result = GridSystem.try_get_gridCell_from_world_position(arc_pos)
			if not get_grid_cell_result["success"]:
				print("Failed to get grid cell at position: ", arc_pos)
				path_valid = false
				break
			
			var grid_cell: GridCell = get_grid_cell_result["grid_cell"]

			# Validate if the cell is air
			if grid_cell.grid_cell_state & Enums.cellState.OBSTRUCTED:
				print("Obstacle detected at: ", grid_cell)
				path_valid = false
				break # Break inner loop to try a different height

			# Only add the grid cell if it's different from the last one
			if last_grid_cell == null or not _are_grid_cells_equal(last_grid_cell, grid_cell):
				ret_val["grid_cell_path"].append(grid_cell)
				last_grid_cell = grid_cell

		# If path is valid, return it with both paths
		if path_valid:
			ret_val["success"] = true
			ret_val["vector3_path"] = smooth_path
			return ret_val

	# If all attempts failed
	print("All ", attempts, " attempts failed to find a valid path")
	ret_val = {"success": false, "grid_cell_path": [], "vector3_path": []}
	return ret_val

# Helper function to compare grid cells
func _are_grid_cells_equal(cell1: GridCell, cell2: GridCell) -> bool:
	# Compare grid cells based on their world positions
	return cell1.worldPosition == cell2.worldPosition
