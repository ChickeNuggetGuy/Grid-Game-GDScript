# Pathfinder.gd
extends Node

# neighbor offsets in (dx, dz, dlayer), including vertical moves
const NEIGHBOR_OFFSETS := [
	Vector3i( 1,  0,  0), Vector3i(-1,  0,  0),
	Vector3i( 0,  1,  0), Vector3i( 0, -1,  0),
	Vector3i( 1,  1,  0), Vector3i( 1, -1,  0),
	Vector3i(-1,  1,  0), Vector3i(-1, -1,  0),
	Vector3i( 0,  0,  1), Vector3i( 0,  0, -1)
]

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
	var path = []
	if start == null or goal == null:
		return path
	var dict = GridSystem.grid_cells
	if not adjacent and not goal.walkable:
		return path
	if start == goal and goal.walkable:
		return [start]

	var valid_targets = []
	if adjacent:
		var gk = Vector3i(goal.x, goal.z, goal.layer)
		for off in NEIGHBOR_OFFSETS:
			var nk = gk + off
			if dict.has(nk) and dict[nk].walkable:
				valid_targets.append(dict[nk])
		if valid_targets.empty():
			return path
		if start in valid_targets:
			return [start]
	else:
		valid_targets.append(goal)

	var open_list = []
	var closed_set = {}
	open_list.append({
		"cell": start,
		"parent": null,
		"cost": 0.0,
		"f": _min_heuristic(start, valid_targets)
	})

	var target_record = null
	while open_list.size() > 0:
		var current = open_list[0]
		for r in open_list:
			if r.f < current.f:
				current = r
		if current.cell in valid_targets:
			target_record = current
			break
		open_list.erase(current)
		closed_set[current.cell] = true

		var ccell = current.cell
		var ckey = Vector3i(ccell.gridCoordinates.x, ccell.gridCoordinates.y, ccell.gridCoordinates.z)
		for off in NEIGHBOR_OFFSETS:
			var nk = ckey + off
			if not dict.has(nk):
				continue
			var nb = dict[nk]
			if closed_set.has(nb):
				continue
			var g = current.cost + _cost(ccell, nb)
			var existing = null
			for r2 in open_list:
				if r2.cell == nb:
					existing = r2
					break
			if existing == null:
				open_list.append({
					"cell": nb,
					"parent": current,
					"cost": g,
					"f": g + _min_heuristic(nb, valid_targets)
				})
			elif g < existing.cost:
				existing.parent = current
				existing.cost = g
				existing.f = g + _min_heuristic(nb, valid_targets)
	if target_record == null:
		return []
	var rec = target_record
	while rec:
		path.insert(0, rec.cell)
		rec = rec.parent
	return path

func _min_heuristic(a: GridCell, targets: Array) -> float:
	var best = INF
	for t in targets:
		var h = _heuristic(a, t)
		if h < best:
			best = h
	return best

func _heuristic(a: GridCell, b: GridCell) -> float:
	var dx = a.gridCoordinates.x - b.gridCoordinates.x
	var dz = a.gridCoordinates.z - b.gridCoordinates.z
	var dl = a.gridCoordinates.y - b.gridCoordinates.y
	return Vector3(dx, dl, dz).length()

func _cost(a: GridCell, b: GridCell) -> float:
	var dx = a.gridCoordinates.x - b.gridCoordinates.x
	var dz = a.gridCoordinates.z - b.gridCoordinates.z
	var dl = a.gridCoordinates.y - b.gridCoordinates.y
	return Vector3(dx, dl, dz).length()
