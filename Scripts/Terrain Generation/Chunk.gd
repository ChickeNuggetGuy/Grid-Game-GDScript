# Chunk.gd
extends Node3D
class_name Chunk

@export var grass_instances_per_vertex: int = 5

var chunk_size: int = 0
var cell_size: Vector2 = Vector2(1, 0.5)
var chunk_data
var grid_coords: Vector2i

var mesh: ArrayMesh
var mesh_instance: MeshInstance3D
var original_material

var local_vertices_visual: Array = []
var local_vertices_physics: Array = []

var bounds: AABB
var local_normals: PackedVector3Array = []
func initialize(
		chunk_index_x: int,
		chunk_index_y: int,
		chnk_sizing: int,
		global_visual_vertices,
		global_physics_vertices,
		cell_chnk_sizing: Vector2,
		data) -> void:
	grid_coords = Vector2i(chunk_index_x, chunk_index_y)
	self.chunk_size = chnk_sizing
	self.cell_size = cell_chnk_sizing
	self.chunk_data = data
	chunk_data.chunk = self
	chunk_data.set_chunk_node(self)

	if chunk_data.chunk_type == ChunkData.ChunkType.MAN_MADE:
		print("Skipping mesh generation for ManMade chunk.")
		return

	var start_x = chunk_index_x * chunk_size
	var start_z = chunk_index_y * chunk_size

	# Cache or create the MeshInstance child
	mesh_instance = get_node_or_null("MeshInstance")
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance"
		add_child(mesh_instance)

	# Ensure the instance participates in lighting and is on default layer 1
	mesh_instance.visible = true
	mesh_instance.layers = 1
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

	local_vertices_visual.clear()
	local_vertices_physics.clear()

	# Fill local vertex arrays in a grid-coherent order (matches _vi)
	for z in range(chunk_size + 1):
		for x in range(chunk_size + 1):
			var wv_vis: Vector3 = global_visual_vertices[start_x + x][start_z + z]
			var wv_phy: Vector3 = global_physics_vertices[start_x + x][start_z + z]

			var lx = wv_vis.x - (start_x * self.cell_size.x)
			var lz = wv_vis.z - (start_z * self.cell_size.x)

			local_vertices_visual.append(Vector3(lx, wv_vis.y, lz))
			local_vertices_physics.append(Vector3(lx, wv_phy.y, lz))

	# Store what we need to compute seam-free normals later
	set_meta("gv", global_visual_vertices)         # reference to global visual grid
	set_meta("gw", global_visual_vertices.size())  # total width in verts
	set_meta("gh", global_visual_vertices[0].size())  # total height in verts
	set_meta("sx", start_x)  # this chunk's start x in the global grid
	set_meta("sz", start_z)  # this chunk's start z in the global grid

func generate(material: Material) -> void:
	if chunk_data.chunk_type == ChunkData.ChunkType.MAN_MADE:
		return

	# Ensure we have a lit 3D material. If a wrong type or null is passed, create a StandardMaterial3D.
	var use_material: Material = material
	if use_material == null or !(use_material is BaseMaterial3D or use_material is ShaderMaterial):
		var std = StandardMaterial3D.new()
		std.albedo_color = Color(0.5, 0.8, 0.5)
		std.roughness = 1.0
		std.metallic = 0.0
		std.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		std.flags_unshaded = false
		use_material = std
	else:
		if use_material is BaseMaterial3D:
			var bm = use_material as BaseMaterial3D
			bm.flags_unshaded = false
			bm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	original_material = use_material
	mesh = ArrayMesh.new()

	# Build an indexed mesh with shared vertices
	var vert_count = (chunk_size + 1) * (chunk_size + 1)

	var mesh_verts = PackedVector3Array()
	mesh_verts.resize(vert_count)
	for i in range(vert_count):
		mesh_verts[i] = local_vertices_visual[i]

	# Per-vertex UVs (one per shared vertex)
	var uvs = PackedVector2Array()
	uvs.resize(vert_count)
	for z in range(chunk_size + 1):
		for x in range(chunk_size + 1):
			var idx = _vi(x, z)
			uvs[idx] = Vector2(
				x / float(chunk_size),
				z / float(chunk_size)
			)

	# Per-vertex normals computed from the GLOBAL height grid
	# This removes seams between chunks
	var gv = get_meta("gv")
	var gw: int = int(get_meta("gw"))
	var gh: int = int(get_meta("gh"))
	var sx: int = int(get_meta("sx"))
	var sz: int = int(get_meta("sz"))

	var cx = self.cell_size.x  # horizontal spacing in world units

	local_normals = PackedVector3Array()
	local_normals.resize(vert_count)

	for z in range(chunk_size + 1):
		for x in range(chunk_size + 1):
			var gx = sx + x
			var gz = sz + z

			var gl = max(gx - 1, 0)
			var gr = min(gx + 1, gw - 1)
			var gd = max(gz - 1, 0)
			var gu = min(gz + 1, gh - 1)

			var yL = gv[gl][gz].y
			var yR = gv[gr][gz].y
			var yD = gv[gx][gd].y
			var yU = gv[gx][gu].y

			# Build slope vectors and cross them. Use sz x sx to get +Y on flat ground.
			var sx_vec = Vector3(2.0 * cx, yR - yL, 0.0)
			var sz_vec = Vector3(0.0, yU - yD, 2.0 * cx)
			var n = sz_vec.cross(sx_vec)

			var idx = _vi(x, z)
			if n.length_squared() < 1e-6:
				local_normals[idx] = Vector3.UP
			else:
				local_normals[idx] = n.normalized()

	# Indices for two triangles per cell
	var tris = PackedInt32Array()
	tris.resize(chunk_size * chunk_size * 6)
	var ti = 0
	for z in range(chunk_size):
		for x in range(chunk_size):
			var bl = _vi(x, z)
			var br = _vi(x + 1, z)
			var tl = _vi(x, z + 1)
			var tr = _vi(x + 1, z + 1)

			tris[ti] = bl
			tris[ti + 1] = br
			tris[ti + 2] = tl
			ti += 3

			tris[ti] = br
			tris[ti + 1] = tr
			tris[ti + 2] = tl
			ti += 3

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = mesh_verts
	arrays[Mesh.ARRAY_NORMAL] = local_normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = tris

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Assign the material to the mesh surface (avoid material_override so lights/GI behave normally)
	mesh.surface_set_material(0, original_material)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = null

	_build_physics_collision()

	bounds = mesh.get_aabb()
	if not is_in_group("Mouse"):
		add_to_group("Mouse")

func _build_physics_collision() -> void:
	var old = get_node_or_null("CollisionBody")
	if old:
		old.queue_free()

	var faces = PackedVector3Array()
	faces.resize(chunk_size * chunk_size * 2 * 3)
	var fi = 0

	for z in range(chunk_size):
		for x in range(chunk_size):
			var bl = _vi(x, z)
			var br = _vi(x + 1, z)
			var tl = _vi(x, z + 1)
			var tr = _vi(x + 1, z + 1)

			var p_bl: Vector3 = local_vertices_physics[bl]
			var p_br: Vector3 = local_vertices_physics[br]
			var p_tl: Vector3 = local_vertices_physics[tl]
			var p_tr: Vector3 = local_vertices_physics[tr]

			faces[fi] = p_bl
			faces[fi + 1] = p_br
			faces[fi + 2] = p_tl
			fi += 3

			faces[fi] = p_br
			faces[fi + 1] = p_tr
			faces[fi + 2] = p_tl
			fi += 3

	var concave = ConcavePolygonShape3D.new()
	concave.set_faces(faces)

	var body = StaticBody3D.new()
	body.name = "CollisionBody"
	add_child(body)

	var shape = CollisionShape3D.new()
	shape.shape = concave
	body.add_child(shape)

	body.set_collision_layer_value(PhysicsLayersUtility.TERRAIN, true)
	body.set_collision_mask_value(PhysicsLayersUtility.TERRAIN, true)

func _vi(x: int, z: int) -> int:
	return z * (chunk_size + 1) + x

static func CalculateSmoothNormals(array_mesh: ArrayMesh) -> void:
	var arrays = array_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normals = PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(normals.size()):
		normals[i] = Vector3.ZERO

	for i in range(0, indices.size(), 3):
		var i0 = indices[i]
		var i1 = indices[i + 1]
		var i2 = indices[i + 2]
		var v0 = vertices[i0]
		var v1 = vertices[i1]
		var v2 = vertices[i2]
		var face_n = (v1 - v0).cross(v2 - v0)
		if face_n.length_squared() < 0.0001:
			continue
		normals[i0] += face_n
		normals[i1] += face_n
		normals[i2] += face_n

	for i in range(normals.size()):
		if normals[i].length_squared() > 0.0001:
			normals[i] = normals[i].normalized()
		else:
			normals[i] = Vector3.UP

	arrays[Mesh.ARRAY_NORMAL] = normals
	array_mesh.clear_surfaces()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
