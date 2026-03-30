extends RefCounted
class_name GridIndexBuilder

# Build a geodesic grid as the dual of an icosphere of frequency `freq`.
# Returns a GridIndex resource with:
# - centers: unit vectors for each cell center
# - cell_vertices: CCW spherical polygons (unit vectors)
# - neighbors: adjacency (by primal edges)
# - bins built (lat/lon)
static func generate(
	freq: int,
	lat_bins: int = 128,
	lon_bins: int = 256
) -> GridIndex:
	assert(freq >= 1)

	var ico := _icosahedron()
	var ico_v: PackedVector3Array = ico.vertices
	var ico_f: Array[Vector3i] = ico.faces

	# Subdivide icosahedron faces -> triangulated sphere ("icosphere")
	var tri_v := PackedVector3Array() # triangulation vertices (unit)
	var tri_f: Array[Vector3i] = []   # triangulation faces (vertex indices)

	# Global caches to unify shared vertices along original edges/corners
	var edge_cache: Dictionary = {}    # key "a:b:s" (canonicalized) -> int
	var corner_cache: Dictionary = {}  # key original vertex id -> int

	for fi in range(ico_f.size()):
		var f := ico_f[fi]
		var a := f.x
		var b := f.y
		var c := f.z
		var A := ico_v[a]
		var B := ico_v[b]
		var C := ico_v[c]

		# Local cache to avoid recomputing within this face
		var local_cache: Dictionary = {}

		# Create small triangles (two per small rhombus)
		for i in range(freq):
			for j in range(freq - i):
				var k := freq - i - j
				var v00 := _get_or_make_subdiv_vertex(
					a,
					b,
					c,
					A,
					B,
					C,
					freq,
					i,
					j,
					k,
					tri_v,
					edge_cache,
					corner_cache,
					local_cache
				)
				var v10 := _get_or_make_subdiv_vertex(
					a,
					b,
					c,
					A,
					B,
					C,
					freq,
					i + 1,
					j,
					k - 1,
					tri_v,
					edge_cache,
					corner_cache,
					local_cache
				)
				var v01 := _get_or_make_subdiv_vertex(
					a,
					b,
					c,
					A,
					B,
					C,
					freq,
					i,
					j + 1,
					k - 1,
					tri_v,
					edge_cache,
					corner_cache,
					local_cache
				)
				tri_f.append(Vector3i(v00, v10, v01))

				if i + j + 1 < freq:
					var v11 := _get_or_make_subdiv_vertex(
						a,
						b,
						c,
						A,
						B,
						C,
						freq,
						i + 1,
						j + 1,
						k - 2,
						tri_v,
						edge_cache,
						corner_cache,
						local_cache
					)
					tri_f.append(Vector3i(v10, v11, v01))

	# Build face directions (triangle "centers") on the unit sphere
	var face_dirs := PackedVector3Array()
	face_dirs.resize(tri_f.size())
	for fi in range(tri_f.size()):
		var t := tri_f[fi]
		var p := (tri_v[t.x] + tri_v[t.y] + tri_v[t.z]) / 3.0
		face_dirs[fi] = p.normalized()

	# Vertex -> incident faces; and vertex adjacency (neighbors)
	var v_faces: Array = []
	v_faces.resize(tri_v.size())
	for v in range(tri_v.size()):
		v_faces[v] = []

	var adj_maps: Array = [] # per-vertex Dictionary of neighbor->true
	adj_maps.resize(tri_v.size())
	for v2 in range(tri_v.size()):
		adj_maps[v2] = {}

	for fi in range(tri_f.size()):
		var t2 := tri_f[fi]
		# Incident faces
		(v_faces[t2.x] as Array).append(fi)
		(v_faces[t2.y] as Array).append(fi)
		(v_faces[t2.z] as Array).append(fi)
		# Adjacency (edges)
		(adj_maps[t2.x] as Dictionary)[t2.y] = true
		(adj_maps[t2.y] as Dictionary)[t2.x] = true
		(adj_maps[t2.y] as Dictionary)[t2.z] = true
		(adj_maps[t2.z] as Dictionary)[t2.y] = true
		(adj_maps[t2.z] as Dictionary)[t2.x] = true
		(adj_maps[t2.x] as Dictionary)[t2.z] = true

	# Dualize: each triangulation vertex -> cell
	# - center = vertex direction
	# - polygon vertices = ordered ring of adjacent face centers (CCW)
	# - neighbors = vertices connected by an edge in triangulation
	var centers := PackedVector3Array(tri_v) # already unit
	var cell_vertices: Array[PackedVector3Array] = []
	cell_vertices.resize(centers.size())

	var neighbors: Array[PackedInt32Array] = []
	neighbors.resize(centers.size())

	for vtx in range(centers.size()):
		var n := centers[vtx]

		# Order incident faces CCW around n
		var facelist: Array = v_faces[vtx]
		var ordered_face_ids := _order_face_ids_ccw(n, facelist, face_dirs)

		# Build polygon ring of face centers
		var ring_pts := Array()
		for fid in ordered_face_ids:
			ring_pts.append(face_dirs[fid])

		# Ensure ring CCW as seen from outside
		var sum_dot := 0.0
		var m := ring_pts.size()
		for i in range(m):
			var a: Vector3 = ring_pts[i]
			var b: Vector3 = ring_pts[(i + 1) % m]
			sum_dot += n.dot(a.cross(b))
		if sum_dot < 0.0:
			ring_pts.reverse()

		cell_vertices[vtx] = PackedVector3Array(ring_pts)

		# Neighbors: sort by angle for stability
		var neigh_map: Dictionary = adj_maps[vtx]
		var neigh_ids := neigh_map.keys()
		var ordered_neigh := _order_ids_by_angle_ccw(n, neigh_ids, centers)
		var nb_arr := PackedInt32Array()
		nb_arr.resize(ordered_neigh.size())
		for i in range(ordered_neigh.size()):
			nb_arr[i] = int(ordered_neigh[i])
		neighbors[vtx] = nb_arr

	var gi := GridIndex.new()
	gi.centers = centers
	gi.cell_vertices = cell_vertices
	gi.neighbors = neighbors
	gi.lat_bins = lat_bins
	gi.lon_bins = lon_bins
	gi.build_bins()
	return gi

# --- Helpers ---------------------------------------------------------------

static func _icosahedron() -> Dictionary:
	var t := (1.0 + sqrt(5.0)) * 0.5
	var pts := [
		Vector3(-1, t, 0),
		Vector3(1, t, 0),
		Vector3(-1, -t, 0),
		Vector3(1, -t, 0),
		Vector3(0, -1, t),
		Vector3(0, 1, t),
		Vector3(0, -1, -t),
		Vector3(0, 1, -t),
		Vector3(t, 0, -1),
		Vector3(t, 0, 1),
		Vector3(-t, 0, -1),
		Vector3(-t, 0, 1),
	]

	var verts := PackedVector3Array()
	verts.resize(pts.size())
	for i in range(pts.size()):
		verts[i] = pts[i].normalized()

	var faces :Array[Vector3i]= [
		Vector3i(0, 11, 5),
		Vector3i(0, 5, 1),
		Vector3i(0, 1, 7),
		Vector3i(0, 7, 10),
		Vector3i(0, 10, 11),
		Vector3i(1, 5, 9),
		Vector3i(5, 11, 4),
		Vector3i(11, 10, 2),
		Vector3i(10, 7, 6),
		Vector3i(7, 1, 8),
		Vector3i(3, 9, 4),
		Vector3i(3, 4, 2),
		Vector3i(3, 2, 6),
		Vector3i(3, 6, 8),
		Vector3i(3, 8, 9),
		Vector3i(4, 9, 5),
		Vector3i(2, 4, 11),
		Vector3i(6, 2, 10),
		Vector3i(8, 6, 7),
		Vector3i(9, 8, 1),
	]

	return {"vertices": verts, "faces": faces}

static func _ijk_key(i: int, j: int, k: int) -> String:
	return "%d,%d,%d" % [i, j, k]

static func _edge_key(a: int, b: int, s: int, freq: int) -> String:
	if a < b:
		return "%d:%d:%d" % [a, b, s]
	else:
		return "%d:%d:%d" % [b, a, freq - s]

static func _add_vertex(vlist: PackedVector3Array, p: Vector3) -> int:
	var idx := vlist.size()
	vlist.push_back(p)
	return idx

static func _get_or_make_edge_point(
	u_idx: int,
	v_idx: int,
	U: Vector3,
	V: Vector3,
	s: int,
	freq: int,
	tri_v: PackedVector3Array,
	edge_cache: Dictionary,
	corner_cache: Dictionary
) -> int:
	if s == 0:
		if corner_cache.has(u_idx):
			return int(corner_cache[u_idx])
		var iu := _add_vertex(tri_v, U)
		corner_cache[u_idx] = iu
		return iu
	if s == freq:
		if corner_cache.has(v_idx):
			return int(corner_cache[v_idx])
		var iv := _add_vertex(tri_v, V)
		corner_cache[v_idx] = iv
		return iv

	var key := _edge_key(u_idx, v_idx, s, freq)
	if edge_cache.has(key):
		return int(edge_cache[key])

	var t := float(s) / float(freq)
	var p := (U * (1.0 - t) + V * t).normalized()
	var idx := _add_vertex(tri_v, p)
	edge_cache[key] = idx
	return idx

static func _get_or_make_subdiv_vertex(
	a: int,
	b: int,
	c: int,
	A: Vector3,
	B: Vector3,
	C: Vector3,
	freq: int,
	i: int,
	j: int,
	k: int,
	tri_v: PackedVector3Array,
	edge_cache: Dictionary,
	corner_cache: Dictionary,
	local_cache: Dictionary
) -> int:
	var key := _ijk_key(i, j, k)
	if local_cache.has(key):
		return int(local_cache[key])

	var idx := -1
	if k == 0:
		idx = _get_or_make_edge_point(
			a, b, A, B, j, freq, tri_v, edge_cache, corner_cache
		)
	elif i == 0:
		idx = _get_or_make_edge_point(
			b, c, B, C, k, freq, tri_v, edge_cache, corner_cache
		)
	elif j == 0:
		idx = _get_or_make_edge_point(
			c, a, C, A, i, freq, tri_v, edge_cache, corner_cache
		)
	else:
		var p := (A * float(i) + B * float(j) + C * float(k)) / float(freq)
		idx = _add_vertex(tri_v, p.normalized())

	local_cache[key] = idx
	return idx

static func _make_tangent_basis(n: Vector3) -> Array:
	var up := Vector3(0, 1, 0)
	var t1 := n.cross(up)
	if t1.length_squared() < 1e-10:
		t1 = n.cross(Vector3(1, 0, 0))
	t1 = t1.normalized()
	var t2 := n.cross(t1).normalized()
	return [t1, t2]

static func _angle_about(
	n: Vector3,
	t1: Vector3,
	t2: Vector3,
	p: Vector3
) -> float:
	var v := (p - n * n.dot(p))
	var x := v.dot(t1)
	var y := v.dot(t2)
	return atan2(y, x)

static func _order_face_ids_ccw(
	n: Vector3,
	face_ids: Array,
	face_dirs: PackedVector3Array
) -> Array:
	if face_ids.is_empty():
		return face_ids.duplicate()
	var tb := _make_tangent_basis(n)
	var t1: Vector3 = tb[0]
	var t2: Vector3 = tb[1]
	var pairs := []
	for id in face_ids:
		var p: Vector3 = face_dirs[int(id)]
		var ang := _angle_about(n, t1, t2, p)
		pairs.append(Vector2(ang, float(id)))
	pairs.sort()
	var ordered := []
	ordered.resize(pairs.size())
	for i in range(pairs.size()):
		ordered[i] = int((pairs[i] as Vector2).y)
	return ordered

static func _order_ids_by_angle_ccw(
	n: Vector3,
	ids: Array,
	dirs: PackedVector3Array
) -> Array:
	if ids.is_empty():
		return ids.duplicate()
	var tb := _make_tangent_basis(n)
	var t1: Vector3 = tb[0]
	var t2: Vector3 = tb[1]
	var pairs := []
	for id in ids:
		var p: Vector3 = dirs[int(id)]
		var ang := _angle_about(n, t1, t2, p)
		pairs.append(Vector2(ang, float(id)))
	pairs.sort()
	var ordered := []
	ordered.resize(pairs.size())
	for i in range(pairs.size()):
		ordered[i] = int((pairs[i] as Vector2).y)
	return ordered
