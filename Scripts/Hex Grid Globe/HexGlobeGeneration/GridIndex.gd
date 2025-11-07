# GridIndex.gd
class_name GridIndex
extends Resource

# Core grid data (all vectors must be unit-length in globe local space)
@export var centers: PackedVector3Array = PackedVector3Array()
# Optional: convex spherical polygons (CCW order as seen from outside)
@export var cell_vertices: Array[PackedVector3Array] = []
# Optional: neighbor indices for your pathfinding
@export var neighbors: Array[PackedInt32Array] = []

# Coarse index resolution (tune as needed)
@export var lat_bins: int = 128
@export var lon_bins: int = 256

# Built index (Compressed Sparse Row: offsets + items)
@export var bin_offsets: PackedInt32Array = PackedInt32Array()
@export var bin_items: PackedInt32Array = PackedInt32Array()

func tile_count() -> int:
	return centers.size()

# Call this after setting centers (and optionally cell_vertices/neighbors)
func build_bins() -> void:
	assert(lat_bins > 0 and lon_bins > 0)
	var n_tiles := centers.size()
	if n_tiles == 0:
		bin_offsets = PackedInt32Array()
		bin_items = PackedInt32Array()
		return

	# Step 1: count how many tiles fall in each bin
	var bin_count := lat_bins * lon_bins
	var counts := PackedInt32Array()
	counts.resize(bin_count)
	for i in range(bin_count):
		counts[i] = 0

	var latlon: Vector2
	var lat_i: int
	var lon_i: int
	var bidx: int
	for id in n_tiles:
		var c := centers[id].normalized()
		latlon = _n_to_latlon(c)
		lat_i = _lat_to_index(latlon.x)
		lon_i = _lon_to_index(latlon.y)
		bidx = lat_i * lon_bins + lon_i
		counts[bidx] += 1

	# Step 2: prefix sum -> offsets
	var offsets := PackedInt32Array()
	offsets.resize(bin_count + 1)
	offsets[0] = 0
	for i in range(bin_count):
		offsets[i + 1] = offsets[i] + counts[i]

	var total := offsets[bin_count]
	var items := PackedInt32Array()
	items.resize(total)

	# Step 3: fill items using a running write cursor per bin
	var write_pos := offsets.duplicate()
	for id in n_tiles:
		var c2 := centers[id].normalized()
		latlon = _n_to_latlon(c2)
		lat_i = _lat_to_index(latlon.x)
		lon_i = _lon_to_index(latlon.y)
		bidx = lat_i * lon_bins + lon_i
		var pos := write_pos[bidx]
		items[pos] = id
		write_pos[bidx] = pos + 1

	bin_offsets = offsets
	bin_items = items

# Pick the cell id for a unit direction n on the sphere.
# If strict_polygon_check is true and polygons are provided, validate
# the winner against its spherical polygon (and expand candidates if needed).
func pick_cell(n: Vector3, strict_polygon_check: bool = false) -> int:
	if centers.is_empty():
		return -1

	var dir := n.normalized()
	var latlon := _n_to_latlon(dir)
	var lat_i := _lat_to_index(latlon.x)
	var lon_i := _lon_to_index(latlon.y)

	# Expand search radius until we find candidates (handles sparse bins)
	var best_id := -1
	var best_dot := -1.0
	var found_any := false

	# Cap the expansion to something safe; fall back to full scan if needed.
	var max_radius := 12
	for r in range(1, max_radius + 1):
		var got_candidates := false
		for di in range(-r, r + 1):
			var bi = clamp(lat_i + di, 0, lat_bins - 1)
			for dj in range(-r, r + 1):
				var bj := _wrap_lon_index(lon_i + dj)
				var bidx = bi * lon_bins + bj
				var start := bin_offsets[bidx]
				var end := bin_offsets[bidx + 1]
				if start >= end:
					continue
				got_candidates = true
				found_any = true
				for k in range(start, end):
					var cid := bin_items[k]
					var cdir := centers[cid]  # expected unit
					var d := dir.dot(cdir)
					if d > best_dot:
						best_dot = d
						best_id = cid
		if got_candidates:
			break

	# If bins were too sparse (should be rare), do a linear fallback
	if not found_any:
		for cid in centers.size():
			var d2 := dir.dot(centers[cid])
			if d2 > best_dot:
				best_dot = d2
				best_id = cid

	if best_id < 0:
		return -1

	if strict_polygon_check and _has_polygon_for(best_id):
		if _point_in_spherical_polygon(dir, cell_vertices[best_id]):
			return best_id
		# If winner fails polygon test, try the nearest few alternatives
		# within a small expanded neighborhood.
		var alt_id := _find_valid_polygon_neighbor(dir, lat_i, lon_i, 2)
		if alt_id >= 0:
			return alt_id
		# As a last resort, return the nearest by dot
		return best_id

	return best_id

func get_cell_center(id: int) -> Vector3:
	return centers[id]

func get_cell_vertices(id: int) -> PackedVector3Array:
	if id < 0 or id >= cell_vertices.size():
		return PackedVector3Array()
	return cell_vertices[id]

func get_cell_neighbors(id: int) -> PackedInt32Array:
	if id < 0 or id >= neighbors.size():
		return PackedInt32Array()
	return neighbors[id]

# --- Internals -------------------------------------------------------------

static func _n_to_latlon(n: Vector3) -> Vector2:
	# lat in [-PI/2, PI/2], lon in [-PI, PI)
	var lat := asin(clamp(n.y, -1.0, 1.0))
	var lon := atan2(n.z, n.x)
	return Vector2(lat, lon)

func _lat_to_index(lat: float) -> int:
	# Map [-PI/2, PI/2] -> [0, lat_bins)
	var t := (lat + PI * 0.5) / PI
	t = clamp(t, 0.0, 0.999999)
	var i := int(floor(t * float(lat_bins)))
	return clamp(i, 0, lat_bins - 1)

func _lon_to_index(lon: float) -> int:
	# Map [-PI, PI) -> [0, lon_bins)
	var t := (lon + PI) / TAU
	# wrap to [0, 1)
	while t < 0.0:
		t += 1.0
	while t >= 1.0:
		t -= 1.0
	var i := int(floor(t * float(lon_bins)))
	if i >= lon_bins:
		i = lon_bins - 1
	return i

func _wrap_lon_index(j: int) -> int:
	if lon_bins <= 0:
		return 0
	var r := j % lon_bins
	if r < 0:
		r += lon_bins
	return r

func _bin_range(bidx: int) -> Vector2i:
	var s := bin_offsets[bidx]
	var e := bin_offsets[bidx + 1]
	return Vector2i(s, e)

func _has_polygon_for(id: int) -> bool:
	return cell_vertices.size() == centers.size() and \
		id >= 0 and id < cell_vertices.size() and \
		cell_vertices[id].size() >= 3

# Try nearby bins to find the first polygon that contains dir
func _find_valid_polygon_neighbor(
	dir: Vector3, lat_i: int, lon_i: int, radius: int
) -> int:
	for di in range(-radius, radius + 1):
		var bi = clamp(lat_i + di, 0, lat_bins - 1)
		for dj in range(-radius, radius + 1):
			var bj := _wrap_lon_index(lon_i + dj)
			var bidx = bi * lon_bins + bj
			var start := bin_offsets[bidx]
			var end := bin_offsets[bidx + 1]
			for k in range(start, end):
				var cid := bin_items[k]
				if _has_polygon_for(cid) and \
						_point_in_spherical_polygon(
							dir, cell_vertices[cid]
						):
					return cid
	return -1

# Returns true if point n is inside convex spherical polygon
# defined by unit vertex loop verts (CCW as seen from outside).
static func _point_in_spherical_polygon(
	n: Vector3, verts: PackedVector3Array
) -> bool:
	var m := verts.size()
	if m < 3:
		return false
	var nn := n.normalized()
	for i in range(m):
		var a := verts[i].normalized()
		var b := verts[(i + 1) % m].normalized()
		var edge_normal := a.cross(b)  # outward for CCW loop
		if nn.dot(edge_normal) < 0.0:
			return false
	return true
