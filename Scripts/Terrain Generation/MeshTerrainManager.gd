extends Manager
class_name MeshTerrainManager

@export var map_size: Vector2i = Vector2i(1, 1)
@export var chunk_size: int = 16
@export var cell_size: Vector2 = Vector2(1.0, 1.0)
@export var chunk_types: Array = []
@export var material: Material
@export var amplitude: float = 8.0    # Increase if things still look too flat
@export var noise_frequency: float = 1.0 / 50.0

var terrain_heights_visual =[]
var terrain_heights_physics =[]
var locked_vertices =[]

func _get_manager_name() -> String:
	return "MeshTerrainManager"

func _setup_conditions():
	return true

func get_passable_data() -> Dictionary:
	return {}

func _setup():
	map_size = GameManager.map_size
	setup_completed.emit()

func _execute_conditions() -> bool:
	return true

func _execute() -> void:
	generate_height_map()
	lock_manmade_edges()
	validate_heights_ignoring_locked(terrain_heights_physics, 2, 2)
	_anchor_visual_to_locked()
	_normalize_terrain_heights()

	for x in range(map_size.x):
		for y in range(map_size.y):
			await generate_chunk(x, y)

	execution_completed.emit()

func generate_height_map() -> void:
	# IMPORTANT: keep grid size coherent with chunk indexing
	var width =(map_size.x * chunk_size) + 1
	var height =(map_size.y * chunk_size) + 1

	terrain_heights_visual.clear()
	terrain_heights_physics.clear()
	locked_vertices.clear()

	for i in range(width):
		terrain_heights_visual.append([])
		terrain_heights_physics.append([])
		locked_vertices.append([])
		for j in range(height):
			terrain_heights_visual[i].append(Vector3.ZERO)
			terrain_heights_physics[i].append(Vector3.ZERO)
			locked_vertices[i].append(false)

	var noise =FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = randi()
	noise.frequency = noise_frequency

	for x in range(width):
		for z in range(height):
			var n =noise.get_noise_2d(x, z)  # [-1, 1]
			var y_vis =n * amplitude
			var y_phy =round(y_vis / cell_size.y) * cell_size.y

			var px =x * cell_size.x
			var pz =z * cell_size.x

			terrain_heights_visual[x][z] = Vector3(px, y_vis, pz)
			terrain_heights_physics[x][z] = Vector3(px, y_phy, pz)

	# Prepare chunk types
	var total_chunks =map_size.x * map_size.y
	chunk_types.clear()
	for i in range(total_chunks):
		chunk_types.append(null)

	for x in range(map_size.x):
		for y in range(map_size.y):
			var index =x + y * map_size.x
			var cd =ChunkData.new()
			cd.chunk_coordinates = Vector2i(x, y)
			if x == 0 and y == 0:
				cd.chunk_type = ChunkData.ChunkType.MAN_MADE
			else:
				cd.chunk_type = ChunkData.ChunkType.PROCEDURAL
			chunk_types[index] = cd

func validate_heights_ignoring_locked(
		verts, validation_passes: int, max_difference: float) -> void:
	var width =verts.size()
	if width == 0:
		return
	var height =verts[0].size()

	for pass_num in range(validation_passes):
		for y in range(height - 1):
			for x in range(width - 1):
				if locked_vertices[x][y]:
					continue

				var cell_h = [
					verts[x][y].y,
					verts[x + 1][y].y,
					verts[x][y + 1].y,
					verts[x + 1][y + 1].y
				]

				var unique_h =[]
				for h in cell_h:
					if h not in unique_h:
						unique_h.append(h)

				if unique_h.size() > 2:
					var counts ={}
					for h in cell_h:
						counts[h] = counts.get(h, 0) + 1
					var keys =counts.keys()
					keys.sort_custom(func(a, b): return counts[b] - counts[a])
					var replace =keys[0]
					var drop =keys[keys.size() - 1]
					for i in range(4):
						if cell_h[i] == drop:
							match i:
								0:
									verts[x][y].y = replace
								1:
									verts[x + 1][y].y = replace
								2:
									verts[x][y + 1].y = replace
								3:
									verts[x + 1][y + 1].y = replace
				elif unique_h.size() == 2:
					var h1 = unique_h[0]
					var h2 = unique_h[1]
					var diff = abs(h1 - h2)
					if diff > max_difference:
						var snap_target = min(h1, h2)
						var snap_source = max(h1, h2)
						for i in range(4):
							if cell_h[i] == snap_source:
								match i:
									0:
										verts[x][y].y = snap_target
									1:
										verts[x + 1][y].y = snap_target
									2:
										verts[x][y + 1].y = snap_target
									3:
										verts[x + 1][y + 1].y = snap_target

func generate_chunk(x: int, y: int) -> void:
	if x < 0 or x >= map_size.x or y < 0 or y >= map_size.y:
		push_error("Chunk coordinates out of range: %s, %s" % [x, y])
		return
	var c_data = get_chunk_data(x, y)
	if c_data == null:
		push_error("Null chunk data at %s, %s" % [x, y])
		return
	var chunk_node = c_data.get_chunk_node()
	if chunk_node == null:
		if c_data.chunk_type == ChunkData.ChunkType.MAN_MADE:
			var prefab_path = get_chunk_prefab_path(c_data.get_chunk_go_index())
			if not ResourceLoader.exists(prefab_path):
				push_error("Chunk prefab not found: %s" % prefab_path)
				c_data.chunk_type = ChunkData.ChunkType.PROCEDURAL
				chunk_node = Node3D.new()
				chunk_node.name = "Chunk_%s_%s" % [x, y]
				add_child(chunk_node)
			else:
				var chunk_scene = load(prefab_path)
				if chunk_scene:
					chunk_node = chunk_scene.instantiate()
					@warning_ignore("integer_division")
					chunk_node.position = Vector3(
						(x * chunk_size) + chunk_size,
						0,
						(y * chunk_size) / 2 + chunk_size
					)
					chunk_node.name = "Chunk_%s_%s" % [x, y]
				else:
					push_error("Failed to load scene: %s" % prefab_path)
					chunk_node = Node3D.new()
					chunk_node.name = "Chunk_%s_%s" % [x, y]
					add_child(chunk_node)
		else:
			chunk_node = Node3D.new()
			chunk_node.name = "Chunk_%s_%s" % [x, y]
			add_child(chunk_node)
		c_data.set_chunk_node(chunk_node)
		if not chunk_node.has_node("Chunk"):
			var comp = Chunk.new()
			comp.name = "Chunk"
			chunk_node.add_child(comp)
			c_data.chunk = comp
	else:
		if c_data.chunk == null:
			var found = chunk_node.get_node_or_null("Chunk")
			if found:
				c_data.chunk = found
			else:
				c_data.chunk = Chunk.new()
				chunk_node.add_child(c_data.chunk)

	if c_data.chunk_type != ChunkData.ChunkType.MAN_MADE:
		chunk_node.position = Vector3(
			x * chunk_size * cell_size.x,
			0,
			y * chunk_size * cell_size.x
		)

	c_data.chunk.initialize(
		x,
		y,
		chunk_size,
		terrain_heights_visual,
		terrain_heights_physics,
		cell_size,
		c_data
	)

	if c_data.chunk_type == ChunkData.ChunkType.MAN_MADE:
		return

	await c_data.chunk.generate(material)

func lock_manmade_edges() -> void:
	var total_width =(map_size.x * chunk_size) + 1
	var total_height =(map_size.y * chunk_size) + 1
	for y in range(total_height):
		for x in range(total_width):
			var is_v =(x % chunk_size == 0 and x != 0)
			var is_h =(y % chunk_size == 0 and y != 0)
			if not is_v and not is_h:
				continue
			var current_chunk = get_chunk_from_vertex_index(x, y)
			if current_chunk == null:
				continue
			if is_v:
				var left_x =x - 1
				var left_chunk = get_chunk_from_vertex_index(left_x, y)
				if left_chunk:
					var boundary_between =(
						(current_chunk.chunk_type == ChunkData.ChunkType.MAN_MADE
						and left_chunk.chunk_type
						== ChunkData.ChunkType.PROCEDURAL)
						or
						(current_chunk.chunk_type
						== ChunkData.ChunkType.PROCEDURAL
						and left_chunk.chunk_type
						== ChunkData.ChunkType.MAN_MADE)
					)
					if boundary_between:
						var manmade_height =1.0
						var v = terrain_heights_physics[x][y]
						v.y = manmade_height
						terrain_heights_physics[x][y] = v
						locked_vertices[x][y] = true
			if is_h:
				var below_y =y - 1
				var below_chunk = get_chunk_from_vertex_index(x, below_y)
				if below_chunk:
					var boundary_between =(
						(current_chunk.chunk_type == ChunkData.ChunkType.MAN_MADE
						and below_chunk.chunk_type
						== ChunkData.ChunkType.PROCEDURAL)
						or
						(current_chunk.chunk_type
						== ChunkData.ChunkType.PROCEDURAL
						and below_chunk.chunk_type
						== ChunkData.ChunkType.MAN_MADE)
					)
					if boundary_between:
						var manmade_chunk_data = (
							below_chunk if below_chunk.chunk_type
							== ChunkData.ChunkType.MAN_MADE
							else current_chunk
						)
						var manmade_height = get_manmade_chunk_height(
							x,
							y,
							manmade_chunk_data
						)
						var v2 = terrain_heights_physics[x][y]
						v2.y = manmade_height
						terrain_heights_physics[x][y] = v2
						locked_vertices[x][y] = true

func get_manmade_chunk_height(
		global_x: int, global_y: int, _manmade_chunk_data) -> float:
	var world = get_viewport().get_world_3d()
	var space_state = world.direct_space_state
	var origin = Vector3(
		global_x * cell_size.x,
		500.0,
		global_y * cell_size.x
	)
	var to = origin + Vector3.DOWN * 1000.0
	var query =PhysicsRayQueryParameters3D.new()
	query.from = origin
	query.to = to
	query.collide_with_bodies = true
	query.collide_with_areas = true
	var result = space_state.intersect_ray(query)
	if result:
		return result.position.y
	return 0.0

func get_chunk_from_vertex_index(vertex_x: int, vertex_y: int):
	if vertex_x < 0:
		vertex_x = 0
	elif vertex_x >= map_size.x * chunk_size:
		vertex_x = map_size.x * chunk_size - 1
	if vertex_y < 0:
		vertex_y = 0
	elif vertex_y >= map_size.y * chunk_size:
		vertex_y = map_size.y * chunk_size - 1
	@warning_ignore("integer_division")
	var chunk_x: int = vertex_x / chunk_size
	@warning_ignore("integer_division")
	var chunk_y: int = vertex_y / chunk_size
	if chunk_x < 0 or chunk_x >= map_size.x:
		return null
	if chunk_y < 0 or chunk_y >= map_size.y:
		return null
	return get_chunk_data(chunk_x, chunk_y)

func get_chunk_data(x: int, y: int):
	var index =x + y * map_size.x
	if index < 0 or index >= chunk_types.size():
		return null
	return chunk_types[index]

func get_chunk_prefab_path(chunk_id: String) -> String:
	return "res://Scenes/Chunks/%s.tscn" % chunk_id

func get_map_size() -> Vector2i:
	return map_size

func get_chunk_size() -> int:
	return chunk_size

func get_cell_size() -> Vector2:
	return cell_size

func get_map_cell_size() -> Vector3:
	return Vector3(
		map_size.x * chunk_size,
		map_size.y * chunk_size,
		map_size.x * chunk_size
	)

func _anchor_visual_to_locked() -> void:
	# Ensure visual mesh matches physics at locked vertices (manmade borders)
	var w =terrain_heights_visual.size()
	if w == 0:
		return
	var h =terrain_heights_visual[0].size()
	for x in range(w):
		for z in range(h):
			if locked_vertices[x][z]:
				var v_vis =terrain_heights_visual[x][z]
				v_vis.y = terrain_heights_physics[x][z].y
				terrain_heights_visual[x][z] = v_vis

func _normalize_terrain_heights() -> void:
	var min_y =INF
	for col in terrain_heights_visual:
		for v in col:
			if v.y < min_y:
				min_y = v.y
	for col in terrain_heights_physics:
		for v in col:
			if v.y < min_y:
				min_y = v.y

	for x in range(terrain_heights_visual.size()):
		for z in range(terrain_heights_visual[x].size()):
			var v1 =terrain_heights_visual[x][z]
			v1.y -= min_y
			terrain_heights_visual[x][z] = v1

	for x in range(terrain_heights_physics.size()):
		for z in range(terrain_heights_physics[x].size()):
			var v2 =terrain_heights_physics[x][z]
			v2.y -= min_y
			terrain_heights_physics[x][z] = v2
