extends Node

@onready var _heap = preload("res://Scripts/Utility/MinHeap.gd").new()

func find_path(start: GridCell, goal: GridCell, adjacent_is_valid: bool = false) -> Array[GridCell]:
	return _find_path_internal(start, goal, adjacent_is_valid)

func find_path_coords(start_coords: Vector3i, goal_coords: Vector3i, adjacent_is_valid: bool = false) -> Array:
	var dict = GameManager.managers["GridSystem"].grid_cells
	if not dict.has(start_coords) or not dict.has(goal_coords):
		return []
	return find_path(dict[start_coords], dict[goal_coords], adjacent_is_valid)

func is_path_possible(start: GridCell, goal: GridCell, adjacent_is_valid: bool = false) -> bool:
	return find_path(start, goal, adjacent_is_valid).size() > 0

func is_path_possible_coords(start_coords: Vector3i, goal_coords: Vector3i, adjacent_is_valid: bool = false) -> bool:
	return find_path_coords(start_coords, goal_coords, adjacent_is_valid).size() > 0

func _find_path_internal(start: GridCell, goal: GridCell, adjacent: bool) -> Array[GridCell]:
	var path: Array[GridCell] = []
	if start == null or goal == null:
		print("Start or goal is null!")
		return path

	if start == goal:
		return [start]

	if start.grid_cell_connections.is_empty():
		print("Start position has no connections: ", start.grid_coordinates)
		return path

	if not adjacent and not _is_cell_walkable(goal):
		print("Goal position is not walkable: ", goal.grid_coordinates, " state: ", goal.grid_cell_state)
		return path

	var targets := []
	if adjacent:
		# For adjacent pathfinding, find walkable neighbors around the goal
		for c in goal.grid_cell_connections:
			if _is_cell_walkable(c):
				targets.append(c)
		if targets.is_empty():
			print("No walkable neighbors found around goal")
			return path
		# Special case: if start is adjacent to goal, we can reach it
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

		for neighbor in current.grid_cell_connections:
			if neighbor == null:
				continue
			if closed_set.has(neighbor):
				continue
			
			# ONLY check walkability for neighbors, not for the current cell
			# This allows pathfinding from occupied start position through walkable cells
			if current != start and not _is_cell_walkable(neighbor):
				continue

			var tentative_g = g_score[current] + _cost(current, neighbor)
			if not g_score.has(neighbor) or tentative_g < g_score[neighbor]:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				var h = _min_heuristic(neighbor, targets)
				f_score[neighbor] = tentative_g + h
				_heap.push({"cell": neighbor, "f": f_score[neighbor]})

	print("No path found from ", start.grid_coordinates, " to ", goal.grid_coordinates)
	return []

func _is_cell_walkable(cell: GridCell) -> bool:
	if cell == null:
		return false
	
	# Cell is not walkable if it's obstructed
	if bool(cell.grid_cell_state & Enums.cellState.OBSTRUCTED):
		return false
	
	# Cell is not walkable if it's just air with no ground
	if bool(cell.grid_cell_state & Enums.cellState.AIR) and not bool(cell.grid_cell_state & Enums.cellState.GROUND):
		return false
		
	# Cell is walkable if it has the WALKABLE flag OR if it has GROUND but not OBSTRUCTED
	return bool(cell.grid_cell_state & Enums.cellState.WALKABLE) or \
		   (bool(cell.grid_cell_state & Enums.cellState.GROUND) and not bool(cell.grid_cell_state & Enums.cellState.OBSTRUCTED))

func _min_heuristic(a: GridCell, targets: Array) -> float:
	var best := INF
	for t in targets:
		var d = a.world_position.distance_to(t.world_position)
		best = min(best, d)
	return best

func _cost(a: GridCell, b: GridCell) -> float:
	var base_cost = a.world_position.distance_to(b.world_position)
	if absf(a.world_position.y - b.world_position.y) > 0.01:
		base_cost *= 1.2
	var dx = abs(a.grid_coordinates.x - b.grid_coordinates.x)
	var dz = abs(a.grid_coordinates.z - b.grid_coordinates.z)
	if dx + dz == 2 and a.grid_coordinates.y == b.grid_coordinates.y:
		base_cost *= 1.1
	return base_cost

func try_calculate_arc_path(start_pos: GridCell, end_pos: GridCell, attempts: int = 3) -> Dictionary:
	var ret_val = {"success": false, "grid_cell_path": [], "vector3_path": []}

	var start = start_pos
	var end = end_pos
	var cell_size = GameManager.managers["MeshTerrainManager"].cell_size

	if start.grid_cell_state & Enums.cellState.OBSTRUCTED or \
	   end.grid_cell_state & Enums.cellState.OBSTRUCTED:
		print("Start or end point is obstructed.")
		return ret_val

	var direction = end.world_position - start.world_position
	var distance = direction.length()

	if distance < 0.1:
		ret_val["success"] = true
		ret_val["grid_cell_path"] = [start]
		ret_val["vector3_path"] = [start.world_position]
		return ret_val

	for attempt in range(attempts):
		var height_factor = 0.3 + (attempt * 0.2)
		var arc_height = distance * height_factor

		var num_points = max(10, int(distance / min(cell_size.x, cell_size.y) * 2))

		ret_val = {"success": false, "grid_cell_path": [], "vector3_path": []}
		var path_valid = true
		var last_grid_cell: GridCell = null
		var smooth_path = []

		for i in range(num_points + 1):
			var t = float(i) / num_points

			var current_pos = start.world_position.lerp(end.world_position, t)
			var vertical_offset = -4 * arc_height * t * (t - 1)
			var arc_pos = current_pos + Vector3.UP * vertical_offset

			smooth_path.append(arc_pos)

			var get_grid_cell_result = GameManager.managers["GridSystem"].try_get_gridCell_from_world_position(arc_pos, true)
			if not get_grid_cell_result["success"]:
				print("Failed to get grid cell at position: ", arc_pos)
				path_valid = false
				break

			var grid_cell: GridCell = get_grid_cell_result["grid_cell"]

			if grid_cell.grid_cell_state & Enums.cellState.OBSTRUCTED:
				print("Obstacle detected at: ", grid_cell.grid_coordinates)
				path_valid = false
				break

			if grid_cell.grid_cell_state & Enums.cellState.OBSTRUCTED:
				print("Invalid cell state for arc path at: ", grid_cell.grid_coordinates, " State: ", grid_cell.grid_cell_state)
				path_valid = false
				break

			if last_grid_cell == null or not _are_grid_cells_equal(last_grid_cell, grid_cell):
				ret_val["grid_cell_path"].append(grid_cell)
				last_grid_cell = grid_cell

		if path_valid and ret_val["grid_cell_path"].size() > 0:
			ret_val["success"] = true
			ret_val["vector3_path"] = smooth_path
			print("Arc path found with ", ret_val["grid_cell_path"].size(), " cells")
			return ret_val

	print("All ", attempts, " attempts failed to find a valid arc path")
	return {"success": false, "grid_cell_path": [], "vector3_path": []}

func _are_grid_cells_equal(cell1: GridCell, cell2: GridCell) -> bool:
	if cell1 == null or cell2 == null:
		return cell1 == cell2
	return cell1.grid_coordinates == cell2.grid_coordinates


func debug_pathfinding_issue(start: GridCell, goal: GridCell):
	print("=== PATHFINDING DEBUG ===")
	print("Start cell: ", start.grid_coordinates if start else "NULL")
	print("Start state: ", start.grid_cell_state if start else "NULL")
	print("Start walkable: ", _is_cell_walkable(start))
	print("Start connections: ", start.grid_cell_connections.size() if start else "NULL")
	
	print("Goal cell: ", goal.grid_coordinates if goal else "NULL") 
	print("Goal state: ", goal.grid_cell_state if goal else "NULL")
	print("Goal walkable: ", _is_cell_walkable(goal))
	print("Goal connections: ", goal.grid_cell_connections.size() if goal else "NULL")
	
	if start and start.grid_cell_connections.size() > 0:
		print("Start's neighbors:")
		for neighbor in start.grid_cell_connections:
			if neighbor:
				print("  - ", neighbor.grid_coordinates, " state: ", neighbor.grid_cell_state, " walkable: ", _is_cell_walkable(neighbor))
	
	print("=========================")
