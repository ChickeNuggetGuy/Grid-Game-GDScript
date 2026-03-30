extends RefCounted
class_name GlobePathfinder

# A* pathfinder over GridIndex hex cells (icosphere dual).
# Tweaks to prefer "diagonal" / straighter, more direct paths:
# - goal alignment bias: prefers steps that point toward the goal
# - turn penalty: discourages sharp turns (keeps path straighter)
# - tie-breaker and optional weighted heuristic to be a bit greedier
#
# Usage:
# var pf := Pathfinder.new()
# pf.set_grid_index(grid_index)
# pf.direct_bias = 0.15      # 0..~0.5 typical
# pf.turn_penalty = 0.10     # 0..~0.5 typical
# pf.heuristic_weight = 1.02 # 1.0 keeps optimality; >1 biases greedily
# var path := pf.find_path(a, b)
# path = pf.smooth_path_adjacent(path) # optional, keeps graph-valid
# var pts := pf.path_to_positions(path, sphere_radius, 0.0)

const INF := 1.0e20

var grid_index: GridIndex = null

# Cells that cannot be traversed
var _blocked: Dictionary = {}

# Optional: decide passability of a cell dynamically
# Signature: bool f(cell_id: int)
var passable_cb: Callable

# Optional: extra traversal cost for moving a->b
# Signature: float f(a_id: int, b_id: int)
var cost_cb: Callable

# Bias controls (tune to prefer more direct paths)
# - direct_bias: favors steps that align with the goal bearing (0 = off)
# - turn_penalty: discourages sharp turns vs previous step (0 = off)
# - heuristic_weight: Weighted A* (>=1). Slightly >1 makes paths greedier.
# - tie_break_eps: breaks f-score ties toward nodes closer to goal
var direct_bias: float = 0.15
var turn_penalty: float = 0.10
var heuristic_weight: float = 1.02
var tie_break_eps: float = 1e-3

# Stats from last run
var last_expanded: int = 0
var last_closed_count: int = 0
var last_path_cost: float = 0.0

func set_grid_index(gi: GridIndex) -> void:
	grid_index = gi

func clear_blocked() -> void:
	_blocked.clear()

func set_blocked_cells(blocked: Array) -> void:
	_blocked.clear()
	for id in blocked:
		_blocked[int(id)] = true

func add_blocked_cell(id: int) -> void:
	_blocked[int(id)] = true

func remove_blocked_cell(id: int) -> void:
	_blocked.erase(int(id))

func is_blocked(id: int) -> bool:
	return _blocked.has(int(id))

func is_traversable(id: int) -> bool:
	if grid_index == null:
		return false
	if id < 0 or id >= grid_index.tile_count():
		return false
	if _blocked.has(id):
		return false
	if passable_cb.is_valid():
		return bool(passable_cb.call(id))
	return true

func is_path_possible(
	start_id: int,
	goal_id: int,
	max_steps: int = -1
) -> bool:
	# Quick BFS feasibility check respecting passability/blocks.
	if grid_index == null:
		return false
	if not is_traversable(start_id) or not is_traversable(goal_id):
		return false
	if start_id == goal_id:
		return true

	var n := grid_index.tile_count()
	var visited := PackedByteArray()
	visited.resize(n)
	for i in n:
		visited[i] = 0

	var q: Array[int] = [start_id]
	visited[start_id] = 1

	var steps := 0
	while not q.is_empty():
		if max_steps >= 0 and steps > max_steps:
			return false
		var curr = q.pop_front()
		if curr == goal_id:
			return true
		var neigh := grid_index.get_cell_neighbors(curr)
		for i in neigh.size():
			var nb := neigh[i]
			if nb < 0 or nb >= n:
				continue
			if visited[nb] == 1:
				continue
			if not is_traversable(nb):
				continue
			visited[nb] = 1
			q.push_back(nb)
		steps += 1
	return false

func find_path(
	start_id: int,
	goal_id: int,
	max_expansions: int = -1
) -> PackedInt32Array:
	# A* over hex cells on a sphere.
	# Returns empty if no path.
	var out := PackedInt32Array()

	if grid_index == null:
		return out
	var n := grid_index.tile_count()
	if n <= 0:
		return out
	if start_id < 0 or start_id >= n:
		return out
	if goal_id < 0 or goal_id >= n:
		return out
	if not is_traversable(start_id) or not is_traversable(goal_id):
		return out
	if start_id == goal_id:
		out.push_back(start_id)
		last_path_cost = 0.0
		last_closed_count = 0
		last_expanded = 0
		return out

	var g := PackedFloat32Array()
	var f := PackedFloat32Array()
	var came := PackedInt32Array()
	var closed := PackedByteArray()

	g.resize(n)
	f.resize(n)
	came.resize(n)
	closed.resize(n)

	for i in n:
		g[i] = INF
		f[i] = INF
		came[i] = -1
		closed[i] = 0

	g[start_id] = 0.0
	var h0 := _heuristic(start_id, goal_id)
	f[start_id] = _fscore(0.0, h0)

	var open_heap: Array[int] = []
	_heap_push(open_heap, start_id, f)

	var expansions := 0
	last_closed_count = 0
	last_expanded = 0
	last_path_cost = 0.0

	while not open_heap.is_empty():
		if max_expansions >= 0 and expansions >= max_expansions:
			break

		var current := _heap_pop(open_heap, f)
		if current == -1:
			break
		if closed[current] == 1:
			continue
		closed[current] = 1
		last_closed_count += 1

		if current == goal_id:
			var path := _reconstruct_path(came, current)
			last_path_cost = _compute_path_cost(path)
			return path

		var neigh := grid_index.get_cell_neighbors(current)
		for i in neigh.size():
			var nb := neigh[i]
			if nb < 0 or nb >= n:
				continue
			if closed[nb] == 1:
				continue
			if not is_traversable(nb):
				continue

			var step_cost := _biased_edge_cost(
				current,
				nb,
				goal_id,
				came[current]
			)
			if step_cost >= INF * 0.5:
				continue

			var tentative := g[current] + step_cost
			if tentative < g[nb]:
				came[nb] = current
				g[nb] = tentative
				var hnb := _heuristic(nb, goal_id)
				f[nb] = _fscore(tentative, hnb)
				_heap_push(open_heap, nb, f)

		expansions += 1
		last_expanded = expansions

	# No path
	return out

func path_to_positions(
	path: PackedInt32Array,
	sphere_radius: float,
	elevation: float = 0.0
) -> PackedVector3Array:
	var pts := PackedVector3Array()
	if grid_index == null or path.is_empty():
		return pts
	pts.resize(path.size())
	for i in path.size():
		var id := path[i]
		var n := grid_index.get_cell_center(id).normalized()
		pts[i] = n * (sphere_radius + elevation)
	return pts

func path_length_cells(path: PackedInt32Array) -> int:
	if path.is_empty():
		return 0
	return path.size() - 1

func geodesic_length_radians(path: PackedInt32Array) -> float:
	# Sum great-circle angles along centers.
	if grid_index == null or path.size() < 2:
		return 0.0
	var total := 0.0
	for i in range(path.size() - 1):
		var a := path[i]
		var b := path[i + 1]
		total += _angle_between_unit(
			grid_index.get_cell_center(a),
			grid_index.get_cell_center(b)
		)
	return total

func reachable_from(
	start_id: int,
	max_steps: int = -1
) -> PackedInt32Array:
	# BFS reach set (steps = edge count).
	var out := PackedInt32Array()
	if grid_index == null:
		return out
	var n := grid_index.tile_count()
	if start_id < 0 or start_id >= n:
		return out
	if not is_traversable(start_id):
		return out

	var visited := PackedByteArray()
	visited.resize(n)
	for i in n:
		visited[i] = 0

	var dist := PackedInt32Array()
	dist.resize(n)
	for i2 in n:
		dist[i2] = -1

	var q: Array[int] = [start_id]
	visited[start_id] = 1
	dist[start_id] = 0

	while not q.is_empty():
		var curr = q.pop_front()
		out.push_back(curr)
		if max_steps >= 0 and dist[curr] >= max_steps:
			continue
		var neigh := grid_index.get_cell_neighbors(curr)
		for i in neigh.size():
			var nb := neigh[i]
			if nb < 0 or nb >= n:
				continue
			if visited[nb] == 1:
				continue
			if not is_traversable(nb):
				continue
			visited[nb] = 1
			dist[nb] = dist[curr] + 1
			q.push_back(nb)

	return out

func find_path_to_any(
	start_id: int,
	goals: PackedInt32Array,
	max_expansions: int = -1
) -> PackedInt32Array:
	# A* to nearest of multiple goals.
	var out := PackedInt32Array()
	if grid_index == null or goals.is_empty():
		return out

	var n := grid_index.tile_count()
	if start_id < 0 or start_id >= n:
		return out
	if not is_traversable(start_id):
		return out

	# Choose goal that minimizes heuristic
	var best_goal := -1
	var min_h := INF
	for i in goals.size():
		var g_id := goals[i]
		if g_id < 0 or g_id >= n:
			continue
		if not is_traversable(g_id):
			continue
		var h := _heuristic(start_id, g_id)
		if h < min_h:
			min_h = h
			best_goal = g_id

	if best_goal == -1:
		return out

	return find_path(start_id, best_goal, max_expansions)

# Optional local smoothing that keeps graph validity:
# removes middle node if A and C are direct neighbors and the turn is small.
func smooth_path_adjacent(
	path: PackedInt32Array,
	turn_keep_deg: float = 25.0
) -> PackedInt32Array:
	if grid_index == null or path.size() < 3:
		return path
	var cos_keep := cos(deg_to_rad(turn_keep_deg))
	var result: Array[int] = []
	result.append(path[0])
	var i := 1
	while i < path.size() - 1:
		var a := path[i - 1]
		var b := path[i]
		var c := path[i + 1]
		var can_skip := false

		# Only skip if A and C are direct neighbors (valid movement)
		var neigh_a := grid_index.get_cell_neighbors(a)
		var a_has_c := false
		for k in neigh_a.size():
			if neigh_a[k] == c:
				a_has_c = true
				break
		if a_has_c:
			var va := grid_index.get_cell_center(a)
			var vb := grid_index.get_cell_center(b)
			var vc := grid_index.get_cell_center(c)
			var d1 := (vb - va).normalized()
			var d2 := (vc - vb).normalized()
			var turn_cos = clamp(d1.dot(d2), -1.0, 1.0)
			if turn_cos > cos_keep:
				can_skip = true

		if can_skip:
			# skip b
			i += 1
		else:
			result.append(b)
			i += 1

	result.append(path[path.size() - 1])

	var out := PackedInt32Array()
	out.resize(result.size())
	for j in result.size():
		out[j] = result[j]
	return out

# --- Internals -------------------------------------------------------------

func _reconstruct_path(
	came: PackedInt32Array,
	cur: int
) -> PackedInt32Array:
	var rev: Array[int] = []
	var at := cur
	while at != -1:
		rev.append(at)
		at = came[at]
	rev.reverse()
	var out := PackedInt32Array()
	out.resize(rev.size())
	for i in rev.size():
		out[i] = rev[i]
	return out

func _compute_path_cost(path: PackedInt32Array) -> float:
	if grid_index == null or path.size() < 2:
		return 0.0
	var total := 0.0
	for i in range(path.size() - 1):
		total += _heuristic(path[i], path[i + 1])
	return total

func _fscore(g_cost: float, h_cost: float) -> float:
	return g_cost + heuristic_weight * h_cost + tie_break_eps * h_cost

func _heuristic(a_id: int, b_id: int) -> float:
	# Great-circle angle between centers (admissible).
	var a := grid_index.get_cell_center(a_id)
	var b := grid_index.get_cell_center(b_id)
	return _angle_between_unit(a, b)

func _biased_edge_cost(
	curr_id: int,
	nb_id: int,
	goal_id: int,
	parent_id: int
) -> float:
	var base := _heuristic(curr_id, nb_id)
	var cost := base

	if cost_cb.is_valid():
		var extra := float(cost_cb.call(curr_id, nb_id))
		if extra > 0.0:
			cost += extra

	if direct_bias <= 0.0 and turn_penalty <= 0.0:
		return cost

	var n := grid_index.get_cell_center(curr_id).normalized()
	var nb := grid_index.get_cell_center(nb_id).normalized()

	if direct_bias > 0.0:
		var g := grid_index.get_cell_center(goal_id).normalized()
		var tg := _tangent_dir_at(n, g)
		var ts := _tangent_dir_at(n, nb)
		if tg != Vector3.ZERO and ts != Vector3.ZERO:
			var align = clamp(ts.dot(tg), -1.0, 1.0) # 1 = perfect toward goal
			cost += direct_bias * base * (1.0 - align)

	if turn_penalty > 0.0 and parent_id != -1:
		var p := grid_index.get_cell_center(parent_id).normalized()
		var in_tan := _tangent_dir_at(n, p)   # pointing back toward parent
		var out_tan := _tangent_dir_at(n, nb) # pointing to neighbor
		if in_tan != Vector3.ZERO and out_tan != Vector3.ZERO:
			var align2 = clamp(out_tan.dot(-in_tan), -1.0, 1.0)
			cost += turn_penalty * base * (1.0 - align2)

	return cost

static func _tangent_dir_at(n: Vector3, toward: Vector3) -> Vector3:
	# Tangent direction at point n pointing toward 'toward' along the sphere.
	var t := toward - n * n.dot(toward)
	var ls := t.length_squared()
	if ls < 1e-12:
		return Vector3.ZERO
	return t / sqrt(ls)

static func _angle_between_unit(a: Vector3, b: Vector3) -> float:
	var d = clamp(a.normalized().dot(b.normalized()), -1.0, 1.0)
	return acos(d)

# --- Binary min-heap over node ids, keyed by f-score -----------------------

static func _heap_push(
	heap: Array[int],
	node: int,
	f_score: PackedFloat32Array
) -> void:
	heap.append(node)
	_sift_up(heap, heap.size() - 1, f_score)

static func _heap_pop(
	heap: Array[int],
	f_score: PackedFloat32Array
) -> int:
	if heap.is_empty():
		return -1
	var root := heap[0]
	var last = heap.pop_back()
	if heap.size() > 0:
		heap[0] = last
		_sift_down(heap, 0, f_score)
	return root

static func _sift_up(
	heap: Array[int],
	idx: int,
	f_score: PackedFloat32Array
) -> void:
	var i := idx
	while i > 0:
		var p := (i - 1) >> 1
		if f_score[heap[i]] < f_score[heap[p]]:
			var tmp := heap[i]
			heap[i] = heap[p]
			heap[p] = tmp
			i = p
		else:
			break

static func _sift_down(
	heap: Array[int],
	idx: int,
	f_score: PackedFloat32Array
) -> void:
	var i := idx
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var s := i
		if l < heap.size() and f_score[heap[l]] < f_score[heap[s]]:
			s = l
		if r < heap.size() and f_score[heap[r]] < f_score[heap[s]]:
			s = r
		if s != i:
			var tmp := heap[i]
			heap[i] = heap[s]
			heap[s] = tmp
			i = s
		else:
			break
