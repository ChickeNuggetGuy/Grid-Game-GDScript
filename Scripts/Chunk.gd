extends Node3D
class_name Chunk

@export var grass_instances_per_vertex: int = 5
var chunk_size: int = 0
var cell_size: float = 0.0
var chunk_data  # Expected to be an instance of ChunkData
var grid_coords: Vector2i

# Mesh Data
var mesh: ArrayMesh
var mesh_instance: MeshInstance3D
# var grass_multi_mesh: MultiMeshInstance3D  # Uncomment if needed

var local_vertices = []  # Local vertices (Array of Vector3)
var bounds: AABB        # Bounding box of the mesh

func initialize(chunk_index_x: int, chunk_index_y: int, chunk_size: int,
		global_vertices, cell_size: float, chunk_data) -> void:
	grid_coords = Vector2i(chunk_index_x, chunk_index_y)
	self.chunk_size = chunk_size
	self.cell_size = cell_size
	self.chunk_data = chunk_data
	chunk_data.chunk = self
	chunk_data.set_chunk_node(self)
	
	print("Initializing chunk at %s, Type: %s" % 
		[grid_coords, str(chunk_data.chunk_type)])
	
	if chunk_data.chunk_type == ChunkData.ChunkType.MAN_MADE:
		print("Skipping mesh generation for ManMade chunk.")
		return
	
	# Try to get a MeshInstance3D child named "MeshInstance"
	mesh_instance = get_node_or_null("MeshInstance")
	if not mesh_instance:
		print("MeshInstance not found, creating new MeshInstance3D.")
		mesh_instance = MeshInstance3D.new()
		add_child(mesh_instance)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	
	# Build local vertices from the global 2D array.
	local_vertices.clear()
	var start_x = chunk_index_x * chunk_size
	var start_y = chunk_index_y * chunk_size
	
	for y in range(chunk_size + 1):
		for x in range(chunk_size + 1):
			# Assuming global_vertices is a 2D array: global_vertices[x][y]
			var world_pos: Vector3 = global_vertices[start_x + x][start_y + y]
			var local_x = world_pos.x - (start_x * self.cell_size)
			var local_y = world_pos.y
			var local_z = world_pos.z - (start_y * self.cell_size)
			local_vertices.append(Vector3(local_x, local_y, local_z))
	
	print("Chunk %s initialized with %s vertices." % 
		[str(grid_coords), local_vertices.size()])

func generate(color: Color) -> void:
	if chunk_data.chunk_type == ChunkData.ChunkType.MAN_MADE:
		return
	
	mesh = ArrayMesh.new()
	# Use typed arrays for vertices, indices, and UVs.
	var mesh_verts: PackedVector3Array = PackedVector3Array()
	var tris: PackedInt32Array = PackedInt32Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	
	# Build the two triangles per cell in local space.
	# local_vertices is indexed as: index = y*(chunk_size+1) + x
	for y in range(chunk_size):
		for x in range(chunk_size):
			var bottom_left_index = y * (chunk_size + 1) + x
			var bottom_right_index = y * (chunk_size + 1) + (x + 1)
			var top_left_index = (y + 1) * (chunk_size + 1) + x
			var top_right_index = (y + 1) * (chunk_size + 1) + (x + 1)
			
			var bottom_left: Vector3 = local_vertices[bottom_left_index]
			var bottom_right: Vector3 = local_vertices[bottom_right_index]
			var top_left: Vector3 = local_vertices[top_left_index]
			var top_right: Vector3 = local_vertices[top_right_index]
			
			# First triangle: bottomLeft, bottomRight, topLeft
			var v0 = mesh_verts.size()
			mesh_verts.append(bottom_left)
			mesh_verts.append(bottom_right)
			mesh_verts.append(top_left)
			tris.append(v0)
			tris.append(v0 + 1)
			tris.append(v0 + 2)
			
			# Second triangle: bottomRight, topRight, topLeft
			var v1 = mesh_verts.size()
			mesh_verts.append(bottom_right)
			mesh_verts.append(top_right)
			mesh_verts.append(top_left)
			tris.append(v1)
			tris.append(v1 + 1)
			tris.append(v1 + 2)
			
			# UV coordinates (normalized 0..1 in chunk space)
			uvs.append(Vector2(x / float(chunk_size), y / float(chunk_size)))          # bottomLeft
			uvs.append(Vector2((x + 1) / float(chunk_size), y / float(chunk_size)))      # bottomRight
			uvs.append(Vector2(x / float(chunk_size), (y + 1) / float(chunk_size)))      # topLeft
			
			uvs.append(Vector2((x + 1) / float(chunk_size), y / float(chunk_size)))      # bottomRight
			uvs.append(Vector2((x + 1) / float(chunk_size), (y + 1) / float(chunk_size)))  # topRight
			uvs.append(Vector2(x / float(chunk_size), (y + 1) / float(chunk_size)))      # topLeft
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = mesh_verts
	arrays[Mesh.ARRAY_INDEX] = tris
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	CalculateSmoothNormals(mesh)
	mesh_instance.mesh = mesh
	
	var new_material = StandardMaterial3D.new()
	new_material.albedo_color = color
	new_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	new_material.cull_mode = BaseMaterial3D.CULL_BACK
	mesh_instance.material_override = new_material
	
	mesh_instance.create_trimesh_collision()
	if mesh_instance.get_child_count() > 0:
		var body = mesh_instance.get_child(0)
		if body is StaticBody3D:
			body.set_collision_layer_value(2, true)
			body.set_collision_mask_value(2, true)
	
	bounds = mesh.get_aabb()
	add_to_group("Mouse")

static func CalculateSmoothNormals(mesh: ArrayMesh) -> void:
	var arrays = mesh.surface_get_arrays(0)
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
		var edge1 = vertices[i1] - vertices[i0]
		var edge2 = vertices[i2] - vertices[i0]
		var face_normal = edge2.cross(edge1)
		if face_normal.length_squared() < 0.0001:
			continue  # Skip degenerate triangle
		normals[i0] += face_normal
		normals[i1] += face_normal
		normals[i2] += face_normal
	
	# Normalize normals
	for i in range(normals.size()):
		if normals[i].length_squared() > 0.0001:
			normals[i] = normals[i].normalized()
		else:
			normals[i] = Vector3.UP
	
	arrays[Mesh.ARRAY_NORMAL] = normals
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

static func RecalculateMeshNormalsInPlace(mesh_instance: MeshInstance3D) -> void:
	var mesh = mesh_instance.mesh as ArrayMesh
	if mesh == null:
		return
	var arrays = mesh.surface_get_arrays(0)
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
		var edge1 = vertices[i1] - vertices[i0]
		var edge2 = vertices[i2] - vertices[i0]
		var face_normal = edge1.cross(edge2)
		var area = face_normal.length()
		if area < 0.0001:
			continue
		face_normal /= area  # Normalize and weight by area
		normals[i0] += face_normal
		normals[i1] += face_normal
		normals[i2] += face_normal
	for i in range(normals.size()):
		if normals[i].length_squared() > 0.0001:
			normals[i] = normals[i].normalized()
		else:
			normals[i] = Vector3.UP
	arrays[Mesh.ARRAY_NORMAL] = normals
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

static func CalculateFlatNormals(mesh: ArrayMesh) -> void:
	var arrays = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normals = PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(0, indices.size(), 3):
		var i0 = indices[i]
		var i1 = indices[i + 1]
		var i2 = indices[i + 2]
		var v0 = vertices[i0]
		var v1 = vertices[i1]
		var v2 = vertices[i2]
		var face_normal = (v1 - v0).cross(v2 - v0)
		if face_normal.length_squared() < 0.0001:
			face_normal = Vector3.UP
		else:
			face_normal = face_normal.normalized()
		normals[i0] = face_normal
		normals[i1] = face_normal
		normals[i2] = face_normal
	arrays[Mesh.ARRAY_NORMAL] = normals
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
