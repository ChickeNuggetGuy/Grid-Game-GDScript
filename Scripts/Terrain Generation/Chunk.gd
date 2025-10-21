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

	mesh_instance = get_node_or_null("MeshInstance")
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance"
		add_child(mesh_instance)

	# Ensure the instance participates in lighting and is on default layer 1
	mesh_instance.visible = true
	mesh_instance.layers = 1
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED  # dynamic lights only

	local_vertices_visual.clear()
	local_vertices_physics.clear()

	var start_x := chunk_index_x * chunk_size
	var start_z := chunk_index_y * chunk_size

	for z in range(chunk_size + 1):
		for x in range(chunk_size + 1):
			var wv_vis: Vector3 = global_visual_vertices[start_x + x][start_z + z]
			var wv_phy: Vector3 = global_physics_vertices[start_x + x][start_z + z]

			var lx := wv_vis.x - (start_x * self.cell_size.x)
			var lz := wv_vis.z - (start_z * self.cell_size.x)

			local_vertices_visual.append(Vector3(lx, wv_vis.y, lz))
			local_vertices_physics.append(Vector3(lx, wv_phy.y, lz))

func generate(material: Material) -> void:
	if chunk_data.chunk_type == ChunkData.ChunkType.MAN_MADE:
		return

	# Ensure we have a lit 3D material. If a wrong type or null is passed, create a StandardMaterial3D.
	var use_material: Material = material
	if use_material == null or !(use_material is BaseMaterial3D or use_material is ShaderMaterial):
		var std := StandardMaterial3D.new()
		std.albedo_color = Color(0.5, 0.8, 0.5)
		std.roughness = 1.0
		std.metallic = 0.0
		std.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL  # make sure it's lit
		std.flags_unshaded = false
		use_material = std
	else:
		# If it's a BaseMaterial3D, ensure it is not unshaded
		if use_material is BaseMaterial3D:
			var bm := use_material as BaseMaterial3D
			bm.flags_unshaded = false
			bm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	original_material = use_material
	mesh = ArrayMesh.new()

	var mesh_verts := PackedVector3Array()
	var tris := PackedInt32Array()
	var uvs := PackedVector2Array()

	for z in range(chunk_size):
		for x in range(chunk_size):
			var bl := _vi(x, z)
			var br := _vi(x + 1, z)
			var tl := _vi(x, z + 1)
			var tr := _vi(x + 1, z + 1)

			var v_bl: Vector3 = local_vertices_visual[bl]
			var v_br: Vector3 = local_vertices_visual[br]
			var v_tl: Vector3 = local_vertices_visual[tl]
			var v_tr: Vector3 = local_vertices_visual[tr]

			var v0 := mesh_verts.size()
			mesh_verts.append(v_bl)
			mesh_verts.append(v_br)
			mesh_verts.append(v_tl)
			tris.append_array([v0, v0 + 1, v0 + 2])

			var v1 := mesh_verts.size()
			mesh_verts.append(v_br)
			mesh_verts.append(v_tr)
			mesh_verts.append(v_tl)
			tris.append_array([v1, v1 + 1, v1 + 2])

			uvs.append(Vector2(x / float(chunk_size), z / float(chunk_size)))
			uvs.append(Vector2((x + 1) / float(chunk_size), z / float(chunk_size)))
			uvs.append(Vector2(x / float(chunk_size), (z + 1) / float(chunk_size)))

			uvs.append(Vector2((x + 1) / float(chunk_size), z / float(chunk_size)))
			uvs.append(Vector2((x + 1) / float(chunk_size), (z + 1) / float(chunk_size)))
			uvs.append(Vector2(x / float(chunk_size), (z + 1) / float(chunk_size)))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = mesh_verts
	arrays[Mesh.ARRAY_INDEX] = tris
	arrays[Mesh.ARRAY_TEX_UV] = uvs

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	CalculateSmoothNormals(mesh)

	# Assign the material to the mesh surface (avoid material_override so lights/GI behave normally)
	mesh.surface_set_material(0, original_material)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = null

	_build_physics_collision()

	bounds = mesh.get_aabb()
	if not is_in_group("Mouse"):
		add_to_group("Mouse")

func _build_physics_collision() -> void:
	var old := get_node_or_null("CollisionBody")
	if old:
		old.queue_free()

	var faces := PackedVector3Array()
	faces.resize(chunk_size * chunk_size * 2 * 3)
	var fi := 0

	for z in range(chunk_size):
		for x in range(chunk_size):
			var bl := _vi(x, z)
			var br := _vi(x + 1, z)
			var tl := _vi(x, z + 1)
			var tr := _vi(x + 1, z + 1)

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

	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(faces)

	var body := StaticBody3D.new()
	body.name = "CollisionBody"
	add_child(body)

	var shape := CollisionShape3D.new()
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
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for i in range(normals.size()):
		normals[i] = Vector3.ZERO

	for i in range(0, indices.size(), 3):
		var i0 := indices[i]
		var i1 := indices[i + 1]
		var i2 := indices[i + 2]
		var v0 := vertices[i0]
		var v1 := vertices[i1]
		var v2 := vertices[i2]
		var face_n := (v1 - v0).cross(v2 - v0)
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
