extends Node
class_name Pathfinder

static  var Instance : Pathfinder

func _init() -> void:
	Instance = self


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

func find_path(start: GridCell, goal: GridCell, adjacent_is_valid: bool = false) -> Array:
	return _find_path_internal(start, goal, adjacent_is_valid)

func find_path_coords(start_coords: Vector3i, goal_coords: Vector3i, adjacent_is_valid: bool = false) -> Array:
	var dict = Manager.get_instance("GridSystem").grid_cells
	if not dict.has(start_coords) or not dict.has(goal_coords):
		return []
	return find_path(dict[start_coords], dict[goal_coords], adjacent_is_valid)

func is_path_possible(start: GridCell, goal: GridCell, adjacent_is_valid: bool = false) -> bool:
	return find_path(start, goal, adjacent_is_valid).size() > 0

func is_path_possible_coords(start_coords: Vector3i, goal_coords: Vector3i, adjacent_is_valid: bool = false) -> bool:
	return find_path_coords(start_coords, goal_coords, adjacent_is_valid).size() > 0

func _find_path_internal(start: GridCell, goal: GridCell, adjacent: bool) -> Array:
	var path := []
	if start == null or goal == null:
		return path
	
	var dict = Manager.get_instance("GridSystem").grid_cells
	
	# Validate start position
	#if not _is_cell_walkable(start):
		#print("Start position is not walkable")
		#return path
	
	# For non-adjacent pathfinding, goal must be walkable
	if not adjacent and not _is_cell_walkable(goal):
		print("Goal position is not walkable")
		return path
	
	# If start equals goal and goal is walkable
	if start == goal and _is_cell_walkable(goal):
		return [start]

	var targets := []
	if adjacent:
		# Find walkable neighbors of the goal
		var gk = goal.grid_coordinates
		for off in NEIGHBOR_OFFSETS:
			var nk = gk + off
			if dict.has(nk):
				var neighbor_cell = dict[nk]
				if _is_cell_walkable(neighbor_cell):
					targets.append(neighbor_cell)
		
		if targets.is_empty():
			print("No walkable neighbors found around goal")
			return path
		
		if start in targets:
			return [start]
	else:
		targets.append(goal)

	# A* Algorithm
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
		
		# Check if we've reached any target
		if current in targets:
			# Reconstruct path
			while current:
				path.insert(0, current)
				current = came_from.get(current, null)
			return path

		closed_set[current] = true
		var ckey = current.grid_coordinates

		# Check all neighbors
		for off in NEIGHBOR_OFFSETS:
			var nk = ckey + off
			if not dict.has(nk):
				continue
			
			var neighbor = dict[nk]
			
			# Skip if already processed
			if closed_set.has(neighbor):
				continue
			
			# Skip if not walkable (this was missing!)
			if not _is_cell_walkable(neighbor):
				continue
			
			# Check if this path to neighbor is better
			var tentative_g = g_score[current] + _cost(current, neighbor)
			if not g_score.has(neighbor) or tentative_g < g_score[neighbor]:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				var h = _min_heuristic(neighbor, targets)
				f_score[neighbor] = tentative_g + h
				_heap.push({"cell": neighbor, "f": f_score[neighbor]})
	
	print("No path found from ", start.grid_coordinates, " to ", goal.grid_coordinates)
	return []  # no path found

# Helper function to check if a cell is walkable
func _is_cell_walkable(cell: GridCell) -> bool:
	if cell == null:
		return false
	return cell.grid_cell_state & Enums.cellState.WALKABLE

func _min_heuristic(a: GridCell, targets: Array) -> float:
	var best = INF
	for t in targets:
		var dx = a.grid_coordinates.x - t.grid_coordinates.x
		var dz = a.grid_coordinates.z - t.grid_coordinates.z
		var dl = a.grid_coordinates.y - t.grid_coordinates.y
		best = min(best, Vector3(dx, dl, dz).length())
	return best

func _cost(a: GridCell, b: GridCell) -> float:
	var dx = a.grid_coordinates.x - b.grid_coordinates.x
	var dz = a.grid_coordinates.z - b.grid_coordinates.z
	var dl = a.grid_coordinates.y - b.grid_coordinates.y
	
	# Different costs for different movement types
	var base_cost = Vector3(dx, dl, dz).length()
	
	# Add extra cost for vertical movement
	if dl != 0:
		base_cost *= 1.2  # 20% penalty for vertical movement
	
	# Add extra cost for diagonal movement
	if abs(dx) + abs(dz) == 2:  # Diagonal movement
		base_cost *= 1.1  # 10% penalty for diagonal movement
	
	return base_cost

func try_calculate_arc_path(start_pos: GridCell, end_pos: GridCell, attempts: int = 3) -> Dictionary:
	var ret_val = {"success": false, "grid_cell_path": [], "vector3_path": []}
	
	var start = start_pos
	var end = end_pos
	var cell_size = Manager.get_instance("MeshTerrainManager").cell_size

	
	if start.grid_cell_state & Enums.cellState.OBSTRUCTED or \
	   end.grid_cell_state & Enums.cellState.OBSTRUCTED:
		print("Start or end point is obstructed.")
		return ret_val

	# Calculate the direction and distance
	var direction = end.world_position - start.world_position
	var distance = direction.length()
	
	if distance < 0.1:  # Too close
		ret_val["success"] = true
		ret_val["grid_cell_path"] = [start]
		ret_val["vector3_path"] = [start.world_position]
		return ret_val

	# Try different arc heights
	for attempt in range(attempts):
		# Calculate arc height with variation for each attempt
		var height_factor = 0.3 + (attempt * 0.2)  # Start lower, go higher
		var arc_height = distance * height_factor
		
		print("Attempt ", attempt + 1, " with arc height: ", arc_height)

		# Adaptive number of points based on distance and cell size
		var num_points = max(10, int(distance / min(cell_size.x, cell_size.y) * 2))
		
		# Reset return value for this attempt
		ret_val = {"success": false, "grid_cell_path": [], "vector3_path": []}
		var path_valid = true
		var last_grid_cell: GridCell = null
		var smooth_path = []

		for i in range(num_points + 1):
			var t = float(i) / num_points # Interpolation factor (0 to 1)

			# Calculate the current position along the straight line
			var current_pos = start.world_position.lerp(end.world_position, t)

			# Calculate the vertical offset for the arc (parabolic shape)
			var vertical_offset = -4 * arc_height * t * (t - 1) # Parabola formula

			# Apply the vertical offset to create the arc
			var arc_pos = current_pos + Vector3.UP * vertical_offset
			
			# Store the smooth path position
			smooth_path.append(arc_pos)

			# Convert world position to grid coordinates
			var get_grid_cell_result = Manager.get_instance("GridSystem").try_get_gridCell_from_world_position(arc_pos, true)  # Use nearest
			if not get_grid_cell_result["success"]:
				print("Failed to get grid cell at position: ", arc_pos)
				path_valid = false
				break
			
			var grid_cell: GridCell = get_grid_cell_result["grid_cell"]

			# More comprehensive validation
			if grid_cell.grid_cell_state & Enums.cellState.OBSTRUCTED:
				print("Obstacle detected at: ", grid_cell.grid_coordinates)
				path_valid = false
				break
			
			# For arc paths, we want AIR or WALKABLE cells
			if  grid_cell.grid_cell_state & Enums.cellState.OBSTRUCTED:
				print("Invalid cell state for arc path at: ", grid_cell.grid_coordinates, " State: ", grid_cell.grid_cell_state)
				path_valid = false
				break

			# Only add the grid cell if it's different from the last one
			if last_grid_cell == null or not _are_grid_cells_equal(last_grid_cell, grid_cell):
				ret_val["grid_cell_path"].append(grid_cell)
				last_grid_cell = grid_cell

		# If path is valid, return it with both paths
		if path_valid and ret_val["grid_cell_path"].size() > 0:
			ret_val["success"] = true
			ret_val["vector3_path"] = smooth_path
			print("Arc path found with ", ret_val["grid_cell_path"].size(), " cells")
			return ret_val

	# If all attempts failed
	print("All ", attempts, " attempts failed to find a valid arc path")
	return {"success": false, "grid_cell_path": [], "vector3_path": []}

# Helper function to compare grid cells
func _are_grid_cells_equal(cell1: GridCell, cell2: GridCell) -> bool:
	if cell1 == null or cell2 == null:
		return cell1 == cell2
	return cell1.grid_coordinates == cell2.grid_coordinates
