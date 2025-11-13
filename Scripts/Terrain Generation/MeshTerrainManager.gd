extends Manager
class_name MeshTerrainManager

@export var map_size: Vector2i = Vector2i(1, 1)
@export var chunk_size: int = 16
@export var cell_size: Vector2 = Vector2(1.0, 1.0)
@export var chunk_types: Array = []
@export var material: Material
@export var amplitude: float = 8.0
@export var noise_frequency: float = 1.0 / 50.0
@export var edge_blend_width: int = 2
@export var raycast_start_height: float = 500.0
@export var raycast_inset: float = 0.25

@export var debug_draw_rays: bool = true
@export var debug_draw_duration: float = 3.0
@export var debug_color_hit: Color = Color(0.0, 1.0, 0.0, 1.0)
@export var debug_color_miss: Color = Color(1.0, 0.0, 0.0, 1.0)
@export var debug_color_origin: Color = Color(1.0, 1.0, 0.0, 1.0)
@export var debug_color_text: Color = Color(1.0, 1.0, 1.0, 1.0)

var terrain_heights_visual = []
var terrain_heights_physics = []
var locked_vertices = []
var terrain_y_offset: float = 0.0

func _get_manager_name() -> String:
	return "MeshTerrainManager"

func _setup_conditions():
	return true

func get_passable_data() -> Dictionary:
	return {}

func _setup():
	map_size = GameManager.map_size
	setup_completed.emit()


func save_data() -> Dictionary:
	var save_dict = {
		"filename" : get_scene_file_path(),
		"parent" : get_parent().get_path(),
	}
	return save_dict


func load_data(data : Dictionary):
	pass



func _execute_conditions() -> bool:
	return true

func _execute() -> void:
	generate_height_map()
	terrain_y_offset = _normalize_terrain_heights_and_get_offset()
	await _spawn_manmade_chunks_first()
	_lock_and_blend_manmade_edges(edge_blend_width)
	_anchor_visual_to_locked()

	for x in range(map_size.x):
		for y in range(map_size.y):
			await generate_chunk(x, y)

	execution_completed.emit()

func generate_height_map() -> void:
	var width = (map_size.x * chunk_size) + 1
	var height = (map_size.y * chunk_size) + 1

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

	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = randi()
	noise.frequency = noise_frequency

	for x in range(width):
		for z in range(height):
			var n = noise.get_noise_2d(x, z)
			var y_vis = n * amplitude
			var y_phy = round(y_vis / cell_size.y) * cell_size.y

			var px = x * cell_size.x
			var pz = z * cell_size.x

			terrain_heights_visual[x][z] = Vector3(px, y_vis, pz)
			terrain_heights_physics[x][z] = Vector3(px, y_phy, pz)

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
				cd.chunk_type = ChunkData.ChunkType.MAN_MADE
			else:
				cd.chunk_type = ChunkData.ChunkType.PROCEDURAL
			chunk_types[index] = cd

func _spawn_manmade_chunks_first() -> void:
	for x in range(map_size.x):
		for y in range(map_size.y):
			var c = get_chunk_data(x, y)
			if c and c.chunk_type == ChunkData.ChunkType.MAN_MADE:
				await generate_chunk(x, y)
	await get_tree().physics_frame

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
					chunk_node.position = Vector3(
						x * chunk_size * cell_size.x,
						terrain_y_offset,
						y * chunk_size * cell_size.x
					)
					chunk_node.name = "Chunk_%s_%s" % [x, y]
					add_child(chunk_node)
				else:
					push_error("Failed to load scene: %s" % prefab_path)
					chunk_node = Node3D.new()
					chunk_node.name = "Chunk_%s_%s" % [x, y]
					add_child(chunk_node)
		else:
			chunk_node = Node3D.new()
			chunk_node.name = "Chunk_%s_%s" % [x, y]
			chunk_node.position = Vector3(
				x * chunk_size * cell_size.x,
				terrain_y_offset,
				y * chunk_size * cell_size.x
			)
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
		chunk_node.position = Vector3(
			x * chunk_size * cell_size.x,
			terrain_y_offset,
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

func _lock_and_blend_manmade_edges(blend_width: int) -> void:
	var total_width = (map_size.x * chunk_size) + 1
	var total_height = (map_size.y * chunk_size) + 1
	var q = cell_size.y

	for grid_z in range(total_height):
		for grid_x in range(total_width):
			var is_v = (grid_x % chunk_size == 0 and grid_x > 0)
			var is_h = (grid_z % chunk_size == 0 and grid_z > 0)
			if not is_v and not is_h:
				continue

			var current_chunk = get_chunk_from_vertex_index(grid_x, grid_z)
			if current_chunk == null:
				continue

			if is_v:
				var left_chunk = get_chunk_from_vertex_index(grid_x - 1, grid_z)
				if left_chunk and current_chunk.chunk_type != left_chunk.chunk_type:
					var manmade_is_left = (left_chunk.chunk_type == ChunkData.ChunkType.MAN_MADE)
					var inset_dir = Vector2(-1, 0) if manmade_is_left else Vector2(1, 0)
					var seam_y = _sample_manmade_height_at_vertex(grid_x, grid_z, inset_dir)

					locked_vertices[grid_x][grid_z] = true
					terrain_heights_visual[grid_x][grid_z].y = seam_y
					terrain_heights_physics[grid_x][grid_z].y = round(seam_y / q) * q

					var blend_dir = 1 if manmade_is_left else -1
					for k in range(1, blend_width + 1):
						var bx = grid_x + blend_dir * k
						if bx < 0 or bx >= total_width or locked_vertices[bx][grid_z]:
							break
						var t = 1.0 - float(k) / float(blend_width + 1)
						var orig_y = terrain_heights_visual[bx][grid_z].y
						var new_y = lerp(orig_y, seam_y, t)
						terrain_heights_visual[bx][grid_z].y = new_y
						terrain_heights_physics[bx][grid_z].y = round(new_y / q) * q

			if is_h:
				var below_chunk = get_chunk_from_vertex_index(grid_x, grid_z - 1)
				if below_chunk and current_chunk.chunk_type != below_chunk.chunk_type:
					var manmade_is_below = (below_chunk.chunk_type == ChunkData.ChunkType.MAN_MADE)
					var inset_dir = Vector2(0, -1) if manmade_is_below else Vector2(0, 1)
					var seam_y = _sample_manmade_height_at_vertex(grid_x, grid_z, inset_dir)

					locked_vertices[grid_x][grid_z] = true
					terrain_heights_visual[grid_x][grid_z].y = seam_y
					terrain_heights_physics[grid_x][grid_z].y = round(seam_y / q) * q

					var blend_dir = 1 if manmade_is_below else -1
					for k in range(1, blend_width + 1):
						var bz = grid_z + blend_dir * k
						if bz < 0 or bz >= total_height or locked_vertices[grid_x][bz]:
							break
						var t = 1.0 - float(k) / float(blend_width + 1)
						var orig_y = terrain_heights_visual[grid_x][bz].y
						var new_y = lerp(orig_y, seam_y, t)
						terrain_heights_visual[grid_x][bz].y = new_y
						terrain_heights_physics[grid_x][bz].y = round(new_y / q) * q

func _sample_manmade_height_at_vertex(grid_x: int, grid_z: int, inset_dir: Vector2 = Vector2.ZERO) -> float:
	var inset = clamp(raycast_inset, 0.0, cell_size.x * 0.49)
	var world_x = (grid_x * cell_size.x) + inset_dir.x * inset
	var world_z = (grid_z * cell_size.x) + inset_dir.y * inset

	var origin = Vector3(world_x, raycast_start_height, world_z)
	var to = Vector3(world_x, -raycast_start_height, world_z)

	var world = get_viewport().get_world_3d()
	var space_state = world.direct_space_state

	var query = PhysicsRayQueryParameters3D.new()
	query.from = origin
	query.to = to
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.hit_back_faces = true

	var result = space_state.intersect_ray(query)

	if debug_draw_rays:
		_dd_draw_ray(origin, to, result)

	if result and result.has("position"):
		return float(result.position.y) - terrain_y_offset

	return terrain_heights_physics[grid_x][grid_z].y

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

				var cell_h = [
					verts[x][y].y,
					verts[x + 1][y].y,
					verts[x][y + 1].y,
					verts[x + 1][y + 1].y
				]

				var unique_h = []
				for h in cell_h:
					if h not in unique_h:
						unique_h.append(h)

				if unique_h.size() > 2:
					var counts = {}
					for h in cell_h:
						counts[h] = counts.get(h, 0) + 1
					var keys = counts.keys()
					keys.sort_custom(func(a, b): return counts[b] - counts[a])
					var replace = keys[0]
					var drop = keys[keys.size() - 1]
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

func get_manmade_chunk_height(global_x: int, global_y: int, _unused) -> float:
	return _sample_manmade_height_at_vertex(global_x, global_y, Vector2.ZERO)

func get_chunk_from_vertex_index(vertex_x: int, vertex_y: int):
	var vx = clampi(vertex_x, 0, map_size.x * chunk_size)
	var vy = clampi(vertex_y, 0, map_size.y * chunk_size)
	@warning_ignore("integer_division")
	var chunk_x: int = vx / chunk_size
	@warning_ignore("integer_division")
	var chunk_y: int = vy / chunk_size
	chunk_x = clampi(chunk_x, 0, map_size.x - 1)
	chunk_y = clampi(chunk_y, 0, map_size.y - 1)
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
	return Vector3(
		map_size.x * chunk_size,
		map_size.y * chunk_size,
		map_size.x * chunk_size
	)

func _anchor_visual_to_locked() -> void:
	var w = terrain_heights_visual.size()
	if w == 0:
		return
	var h = terrain_heights_visual[0].size()
	for x in range(w):
		for z in range(h):
			if locked_vertices[x][z]:
				terrain_heights_visual[x][z].y = terrain_heights_physics[x][z].y

func _normalize_terrain_heights_and_get_offset() -> float:
	var min_y = INF
	for col in terrain_heights_visual:
		for v in col:
			if v.y < min_y:
				min_y = v.y
	for col in terrain_heights_physics:
		for v in col:
			if v.y < min_y:
				min_y = v.y

	if min_y == INF:
		return 0.0

	for x in range(terrain_heights_visual.size()):
		for z in range(terrain_heights_visual[x].size()):
			terrain_heights_visual[x][z].y -= min_y

	for x in range(terrain_heights_physics.size()):
		for z in range(terrain_heights_physics[x].size()):
			terrain_heights_physics[x][z].y -= min_y

	return -min_y

func _dd():
	return get_node_or_null("/root/DebugDraw3D")

func _dd_draw_ray(from_world: Vector3, to_world: Vector3, hit: Dictionary) -> void:
	var dd = _dd()
	if dd == null:
		return

	if hit and hit.has("position"):
		var hit_pos: Vector3 = hit.position
		_dd_line(dd, from_world, hit_pos, debug_color_hit, debug_draw_duration)
		_dd_sphere(dd, hit_pos, cell_size.x * 0.15, debug_color_hit, debug_draw_duration)
		_dd_point(dd, from_world, debug_color_origin, debug_draw_duration)
		_dd_text(dd, hit_pos + Vector3.UP * 0.2, "y=" + str(snapped(hit_pos.y, 0.001)), debug_color_text, debug_draw_duration)
	else:
		_dd_line(dd, from_world, to_world, debug_color_miss, debug_draw_duration)
		_dd_point(dd, from_world, debug_color_origin, debug_draw_duration)

func _dd_line(dd, a: Vector3, b: Vector3, color: Color, dur: float) -> void:
	if dd.has_method("draw_line"):
		dd.draw_line(a, b, color, dur)
	elif dd.has_method("line"):
		dd.line(a, b, color, dur)

func _dd_sphere(dd, p: Vector3, r: float, color: Color, dur: float) -> void:
	if dd.has_method("draw_sphere"):
		dd.draw_sphere(p, r, color, dur)
	elif dd.has_method("sphere"):
		dd.sphere(p, r, color, dur)
	elif dd.has_method("draw_wire_sphere"):
		dd.draw_wire_sphere(p, r, color, dur)

func _dd_point(dd, p: Vector3, color: Color, dur: float) -> void:
	if dd.has_method("draw_point"):
		dd.draw_point(p, color, dur)
	elif dd.has_method("point"):
		dd.point(p, color, dur)
	else:
		_dd_sphere(dd, p, cell_size.x * 0.05, color, dur)

func _dd_text(dd, p: Vector3, text: String, color: Color, dur: float) -> void:
	if dd.has_method("draw_text"):
		dd.draw_text(p, text, color, dur)
	elif dd.has_method("text"):
		dd.text(p, text, color, dur)
