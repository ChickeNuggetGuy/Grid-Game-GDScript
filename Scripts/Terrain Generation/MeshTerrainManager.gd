extends Manager
class_name MeshTerrainManager


@export var map_size: Vector2i = Vector2i(1, 1)
@export var chunk_size: int = 16
@export var cell_size: Vector2 = Vector2(1.0, 1.0)
@export var chunk_types: Array = []
@export var material : Material
@export var amplitude: float = 1.2

var terrain_heights = []
var locked_vertices = []



func get_manager_data() -> Dictionary:
	return {}



func _get_manager_name() -> String:
	return "MeshTerrainManager"

func _setup_conditions():
	return true

func _setup():
	map_size = Manager.get_instance("GameManager").passable_parameters["map_size"]
	
	
	setup_completed.emit()

func _execute_conditions() -> bool:
	return true

func _execute() -> void:
	generate_height_map()
	lock_manmade_edges()
	validate_heights_ignoring_locked(terrain_heights, 2, 2)
	_normalize_terrain_heights()
	for x in range(map_size.x):
		for y in range(map_size.y):
			await generate_chunk(x, y)
	
	execution_completed.emit()


func on_scene_changed(_new_scene: Node):
	if not Manager.get_instance("GameManager").current_scene_name == "BattleScene":
		queue_free()

func _on_exit_tree() -> void:
	return

func generate_height_map() -> void:
	var width = (map_size.x * chunk_size * 2) + 1
	var height = (map_size.y * chunk_size * 2) + 1

	terrain_heights.clear()
	locked_vertices.clear()
	for i in range(width):
		terrain_heights.append([])
		locked_vertices.append([])
		for j in range(height):
			terrain_heights[i].append(Vector3.ZERO)
			locked_vertices[i].append(false)

	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	noise.seed = randi()
	noise.frequency = 1.0 / 50.0

	for x in range(width):
		for z in range(height):
			var noise_val = noise.get_noise_2d(x, z)
			var height_val = round(noise_val * amplitude / cell_size.y) * cell_size.y
			terrain_heights[x][z] = Vector3(x * cell_size.x, height_val, z * cell_size.x)

	var total_chunks = map_size.x * map_size.y
	chunk_types.clear()
	for i in range(total_chunks):
		chunk_types.append(null)

	for x in range(map_size.x):
		for y in range(map_size.y):
			var index = x + y * map_size.x
			var cd = ChunkData.new()
			cd.chunk_coordinates = Vector2i(x, y)
			if x == 0 and y == 0:
				if debug_mode:
					print("Setting chunk to ManMade!")
				cd.chunk_type = ChunkData.ChunkType.MAN_MADE
			else:
				cd.chunk_type = ChunkData.ChunkType.PROCEDURAL
			chunk_types[index] = cd


func validate_heights_ignoring_locked(verts, validation_passes: int, max_difference: float) -> void:
	var width = verts.size()
	if width == 0:
		return
	var height = verts[0].size()
	
	for pass_num in range(validation_passes):
		for y in range(height - 1):
			for x in range(width - 1):
				if locked_vertices[x][y]:
					continue
				
				# Collect all four corner heights of the cell
				var cell_heights = [
					verts[x][y].y,
					verts[x + 1][y].y,
					verts[x][y + 1].y,
					verts[x + 1][y + 1].y
				]
				
				# Get unique heights in the cell
				var unique_heights = []
				for h in cell_heights:
					if h not in unique_heights:
						unique_heights.append(h)
				
				# If more than 2 unique heights, reduce to 2 most common
				if unique_heights.size() > 2:
					var counts = {}
					for h in cell_heights:
						counts[h] = counts.get(h, 0) + 1
					
					# Sort by frequency (most common first)
					var sorted_keys = counts.keys()
					sorted_keys.sort_custom(func(a, b): 
						return counts[b] - counts[a]
					)
					
					var replacement_height = sorted_keys[0]
					var height_to_replace = sorted_keys[sorted_keys.size() - 1]
					
					# Replace the least common height with the most common one
					for i in range(4):
						if cell_heights[i] == height_to_replace:
							match i:
								0:
									verts[x][y].y = replacement_height
								1:
									verts[x + 1][y].y = replacement_height
								2:
									verts[x][y + 1].y = replacement_height
								3:
									verts[x + 1][y + 1].y = replacement_height
				
				# Check adjacent height differences and snap if needed
				elif unique_heights.size() == 2:
					var h1 = unique_heights[0]
					var h2 = unique_heights[1]
					var diff = abs(h1 - h2)
					
					if diff > max_difference:
						# Determine which height to snap to (the "lower" one)
						var snap_target = min(h1, h2)
						var snap_source = max(h1, h2)
						
						# Snap all vertices with snap_source height to snap_target
						# (within grid constraints)
						for i in range(4):
							if cell_heights[i] == snap_source:
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
			if debug_mode:
				print("Loading new chunk node for %s, %s" % [x, y])
			var prefab_path = get_chunk_prefab_path(c_data.get_chunk_go_index())
			if debug_mode:
				print("Loading ManMade chunk from: %s" % prefab_path)
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
					chunk_node.position = Vector3((x * chunk_size) + chunk_size, 0, (y * chunk_size) / 2 + chunk_size)
					chunk_node.name = "Chunk_%s_%s" % [x, y]
				else:
					push_error("Failed to load scene from: %s" % prefab_path)
					chunk_node = Node3D.new()
					chunk_node.name = "Chunk_%s_%s" % [x, y]
					add_child(chunk_node)
		else:
			if debug_mode:
				print("Creating new chunk node for %s, %s" % [x, y])
			chunk_node = Node3D.new()
			chunk_node.name = "Chunk_%s_%s" % [x, y]
			add_child(chunk_node)
		c_data.set_chunk_node(chunk_node)
		if not chunk_node.has_node("Chunk"):
			var chunk_component = Chunk.new()
			chunk_component.name = "Chunk"
			chunk_node.add_child(chunk_component)
			c_data.chunk = chunk_component
	else:
		if debug_mode:
			print("Using existing chunk node for %s, %s" % [x, y])
		if c_data.chunk == null:
			var found_chunk = chunk_node.get_node_or_null("Chunk")
			if found_chunk:
				c_data.chunk = found_chunk
			else:
				c_data.chunk = Chunk.new()
				chunk_node.add_child(c_data.chunk)
	if c_data.chunk_type != ChunkData.ChunkType.MAN_MADE:
		chunk_node.position = Vector3(x * chunk_size * cell_size.x, 0, y * chunk_size * cell_size.x)
	if debug_mode:
		print("Initializing chunk %s, %s" % [x, y])
	c_data.chunk.initialize(x, y, chunk_size, terrain_heights, cell_size, c_data)
	if debug_mode:
		print("Initialized chunk %s, %s" % [x, y])
	if c_data.chunk_type == ChunkData.ChunkType.MAN_MADE:
		if debug_mode:
			print("Skipping mesh generation for ManMade chunk %s, %s" % [x, y])
		return
	if debug_mode:
		print("Generating mesh for chunk %s, %s" % [x, y])
		
		
	await c_data.chunk.generate(material)

func lock_manmade_edges() -> void:
	var total_width = map_size.x * chunk_size + 1
	var total_height = map_size.y * chunk_size + 1
	for y in range(total_height):
		for x in range(total_width):
			var is_vertical_boundary = (x % chunk_size == 0 and x != 0)
			var is_horizontal_boundary = (y % chunk_size == 0 and y != 0)
			if not is_vertical_boundary and not is_horizontal_boundary:
				continue
			var current_chunk = get_chunk_from_vertex_index(x, y)
			if current_chunk == null:
				continue
			if is_vertical_boundary:
				var left_x = x - 1
				var left_chunk = get_chunk_from_vertex_index(left_x, y)
				if left_chunk:
					var boundary_between = ((current_chunk.chunk_type ==
						ChunkData.ChunkType.MAN_MADE and left_chunk.chunk_type == ChunkData.ChunkType.PROCEDURAL) or
						(current_chunk.chunk_type == ChunkData.ChunkType.PROCEDURAL and left_chunk.chunk_type == ChunkData.ChunkType.MAN_MADE))
					if boundary_between:
						#var manmade_chunk_data = left_chunk if left_chunk.chunk_type == ChunkData.ChunkType.MAN_MADE else current_chunk
						var manmade_height = 1.0
						var v = terrain_heights[x][y]
						v.y = manmade_height
						terrain_heights[x][y] = v
						locked_vertices[x][y] = true
			if is_horizontal_boundary:
				var below_y = y - 1
				var below_chunk = get_chunk_from_vertex_index(x, below_y)
				if below_chunk:
					var boundary_between = ((current_chunk.chunk_type ==
						ChunkData.ChunkType.MAN_MADE and below_chunk.chunk_type == ChunkData.ChunkType.PROCEDURAL) or
						(current_chunk.chunk_type == ChunkData.ChunkType.PROCEDURAL and below_chunk.chunk_type == ChunkData.ChunkType.MAN_MADE))
					if boundary_between:
						var manmade_chunk_data = below_chunk if below_chunk.chunk_type == ChunkData.ChunkType.MAN_MADE else current_chunk
						var manmade_height = get_manmade_chunk_height(x, y, manmade_chunk_data)
						var v = terrain_heights[x][y]
						v.y = manmade_height
						terrain_heights[x][y] = v
						locked_vertices[x][y] = true

func get_manmade_chunk_height(global_x: int, global_y: int, _manmade_chunk_data) -> float:
	var world = get_viewport().get_world_3d()
	var space_state = world.direct_space_state
	var origin = Vector3(global_x * cell_size.x, 500.0, global_y * cell_size.x)
	var to = origin + Vector3.DOWN * 1000.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
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
	var chunk_x : int = vertex_x / chunk_size
	@warning_ignore("integer_division")
	var chunk_y  : int = vertex_y / chunk_size
	if chunk_x < 0 or chunk_x >= map_size.x:
		return null
	if chunk_y < 0 or chunk_y >= map_size.y:
		return null
	return get_chunk_data(chunk_x, chunk_y)

func get_chunk_data(x: int, y: int):
	var index = x + y * map_size.x
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
	return Vector3(map_size.x * chunk_size,
		 map_size.y * chunk_size,
		 map_size.x * chunk_size)

func _normalize_terrain_heights() -> void:
	var min_y = INF
	for col in terrain_heights:
		for v in col:
			if v.y < min_y:
				min_y = v.y
	for x in range(terrain_heights.size()):
		for z in range(terrain_heights[x].size()):
			var v = terrain_heights[x][z]
			v.y -= min_y
			terrain_heights[x][z] = v
