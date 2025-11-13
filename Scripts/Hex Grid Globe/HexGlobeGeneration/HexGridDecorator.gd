@tool
class_name HexGridDecorator
extends Node3D

signal cell_hovered(id: int)
signal cell_selected(id: int)

#region Exports

@export var grid_index: GridIndex:
	set = set_grid_index

@export var collision_shape: CollisionShape3D
@export var camera_path: NodePath
@export var auto_hover = true
@export var auto_click_select = true
@export var strict_polygon_check = false

@export var show_neighbor_ring = true
@export var highlight_elevation = 0.01
@export var hover_color = Color(0.2, 0.8, 1.0)
@export var selected_color = Color(1.0, 0.8, 0.2)
@export var neighbor_color = Color(0.5, 0.9, 0.6)

@export var show_markers = false:
	set = set_show_markers
@export var marker_scale = 0.02
@export var marker_elevation = 0.01
@export var marker_color = Color(0.95, 0.2, 0.2)

@export var show_cell_defintions = true:
	set = set_show_cell_defintions
@export var city_cell_color = Color(0.9, 0.3, 0.3, 0.7)
@export var city_cell_highlight_elevation = 0.02

@export var use_texture_colors = false:
	set = set_use_texture_colors
@export var color_blend_factor = 0.7:
	set = set_color_blend_factor

@export var auto_generate_index = false
@export var frequency = 16
@export var lat_bins_override = 128
@export var lon_bins_override = 256
@export var generate_now = false:
	set = set_generate_now

@export var assignment_chunk_size = 1000
@export var cells_per_surface = 3000
@export var yield_every_surfaces = 1
@export var use_city_cache = true
@export var cache_directory = "user://hexgrid_cache"

#endregion

#region Variables

var hovered_cell = -1
var selected_cell = -1
var hex_grid_data: HexGridData

var _hover_mesh: MeshInstance3D
var _selected_mesh: MeshInstance3D
var _neighbor_mesh: MeshInstance3D
var _markers: MultiMeshInstance3D
var _city_cells_mesh: MeshInstance3D
var _colored_cells_mesh: MeshInstance3D

var _sphere: Node3D
var _sphere_radius = 1.0

var cities_data: Dictionary = {}
var loading_thread: Thread = null
var _cities_array: Array = []
var _assign_idx = 0
var _assigning = false

var _cell_definition_rebuild_running = false
var _cell_definition_rebuild_pending = false

#endregion

#region Lifecycle Methods

func _ready() -> void:
	_sphere = get_parent()
	if _sphere:
		_sphere_radius = _get_sphere_radius(_sphere)
		if collision_shape and collision_shape.shape:
			collision_shape.shape.radius = _sphere_radius

	_ensure_nodes()

	if grid_index == null and auto_generate_index:
		_generate_grid()

	if grid_index and grid_index.bin_offsets.is_empty():
		grid_index.build_bins()

	if hex_grid_data == null:
		hex_grid_data = HexGridData.new(self)

	if grid_index != null:
		_setup_json_parse()

	_rebuild_highlights()
	if show_markers:
		_rebuild_markers()

func _process(_delta: float) -> void:
	if _assigning:
		var n = assignment_chunk_size
		var end = min(_assign_idx + n, _cities_array.size())

		for i in range(_assign_idx, end):
			var city_data = _cities_array[i]
			if not (city_data is Dictionary):
				continue
			if not city_data.has("coordinates") or not city_data.has("name"):
				continue

			var coordinates = city_data["coordinates"]
			if not (coordinates is Dictionary) \
					or not coordinates.has("lat") \
					or not coordinates.has("lon"):
				continue

			var lat: float
			var lon: float
			if coordinates["lat"] is String:
				lat = coordinates["lat"].to_float()
			else:
				lat = float(coordinates["lat"])
			if coordinates["lon"] is String:
				lon = coordinates["lon"].to_float()
			else:
				lon = float(coordinates["lon"])

			if not is_finite(lat) or not is_finite(lon):
				continue

			var index = get_cell_at_coordinates(lat, lon, true)
			if index == -1:
				continue

			var population = 0
			if city_data.has("population") and city_data["population"] != null:
				if city_data["population"] is String:
					population = city_data["population"].to_int()
				else:
					population = int(city_data["population"])

			var country_code = ""
			if city_data.has("country_code") and city_data["country_code"] != null:
				country_code = str(city_data["country_code"])

			var city_def = CityDefinition.new(
				index,
				str(city_data["name"]),
				population,
				country_code
			)
			hex_grid_data.add_cell_definition(index, city_def, self)

		_assign_idx = end

		if _assign_idx >= _cities_array.size():
			_assigning = false
			set_process(false)
			if use_city_cache:
				_save_city_cache()
			if show_cell_defintions:
				_rebuild_cell_definitions()
			if loading_thread != null:
				loading_thread.wait_to_finish()
				loading_thread = null

func _unhandled_input(event: InputEvent) -> void:
	if grid_index == null:
		return
	var cam = _get_camera()
	if cam == null:
		return

	if auto_hover and event is InputEventMouseMotion:
		var id = pick_cell_from_screen(event.position)
		if id != hovered_cell:
			hovered_cell = id
			_draw_hover()
			emit_signal("cell_hovered", hovered_cell)

	if auto_click_select and event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var id2 = pick_cell_from_screen(event.position)
		if id2 >= 0 and id2 != selected_cell:
			select_cell(id2)

#endregion

#region Setters

func set_grid_index(v: GridIndex) -> void:
	grid_index = v
	if grid_index and grid_index.bin_offsets.is_empty():
		grid_index.build_bins()
	if is_inside_tree():
		_rebuild_highlights()
		if show_markers:
			_rebuild_markers()

func set_show_markers(v: bool) -> void:
	show_markers = v
	if not is_inside_tree():
		return
	if show_markers:
		_rebuild_markers()
		if _markers:
			_markers.visible = true
	else:
		if _markers:
			_markers.visible = false

func set_show_cell_defintions(v: bool) -> void:
	show_cell_defintions = v
	if is_inside_tree():
		_rebuild_cell_definitions()

func set_use_texture_colors(v: bool) -> void:
	use_texture_colors = v
	if is_inside_tree():
		_rebuild_highlights()

func set_color_blend_factor(v: float) -> void:
	color_blend_factor = clamp(v, 0.0, 1.0)
	if is_inside_tree() and _colored_cells_mesh and _colored_cells_mesh.material_override:
		var mat = _colored_cells_mesh.material_override as StandardMaterial3D
		mat.albedo_color.a = color_blend_factor

func set_generate_now(v: bool) -> void:
	generate_now = false
	if v:
		_generate_grid()

#endregion

#region Grid Generation

func _generate_grid() -> void:
	if frequency < 1:
		frequency = 1
	if lat_bins_override < 1:
		lat_bins_override = 128
	if lon_bins_override < 1:
		lon_bins_override = 256

	var gi = GridIndexBuilder.generate(
		frequency,
		lat_bins_override,
		lon_bins_override
	)
	set_grid_index(gi)
	_setup_json_parse()

#endregion

#region Node Setup

func _ensure_nodes() -> void:
	_hover_mesh = $HighlightHover if has_node("HighlightHover") else null
	if _hover_mesh == null:
		_hover_mesh = MeshInstance3D.new()
		_hover_mesh.name = "HighlightHover"
		_hover_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_hover_mesh)
	_hover_mesh.material_override = _make_unshaded_line_material(hover_color)

	_selected_mesh = $HighlightSelected if has_node("HighlightSelected") else null
	if _selected_mesh == null:
		_selected_mesh = MeshInstance3D.new()
		_selected_mesh.name = "HighlightSelected"
		_selected_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_selected_mesh)
	_selected_mesh.material_override = _make_unshaded_line_material(selected_color)

	_neighbor_mesh = $HighlightNeighbors if has_node("HighlightNeighbors") else null
	if _neighbor_mesh == null:
		_neighbor_mesh = MeshInstance3D.new()
		_neighbor_mesh.name = "HighlightNeighbors"
		_neighbor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_neighbor_mesh)
	_neighbor_mesh.material_override = _make_unshaded_line_material(neighbor_color)

	_markers = $Markers if has_node("Markers") else null
	if _markers == null:
		_markers = MultiMeshInstance3D.new()
		_markers.name = "Markers"
		_markers.visible = false
		add_child(_markers)

	_city_cells_mesh = $CityCells if has_node("CityCells") else null
	if _city_cells_mesh == null:
		_city_cells_mesh = MeshInstance3D.new()
		_city_cells_mesh.name = "CityCells"
		_city_cells_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_city_cells_mesh)

	_colored_cells_mesh = $ColoredCells if has_node("ColoredCells") else null
	if _colored_cells_mesh == null:
		_colored_cells_mesh = MeshInstance3D.new()
		_colored_cells_mesh.name = "ColoredCells"
		_colored_cells_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_colored_cells_mesh)

#endregion

#region Cell Selection and Picking

func select_cell(id: int) -> void:
	selected_cell = id
	_draw_selected_and_neighbors()
	emit_signal("cell_selected", selected_cell)

func pick_cell_from_screen(pos: Vector2) -> int:
	var cam = _get_camera()
	if cam == null:
		return -1
	var from = cam.project_ray_origin(pos)
	var dir = cam.project_ray_normal(pos)
	var to = from + dir * 10000.0

	var space = get_world_3d().direct_space_state
	var q = PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.hit_back_faces = false
	var hit = space.intersect_ray(q)
	if hit.is_empty():
		return -1

	var p_local = _sphere.to_local(hit.position)
	var n = p_local.normalized()
	return grid_index.pick_cell(n, strict_polygon_check)

func get_cell_at_coordinates(
	latitude: float,
	longitude: float,
	use_strict_check: bool = false
) -> int:
	if grid_index == null:
		return -1
	var lat = deg_to_rad(clamp(latitude, -90.0, 90.0))
	var lon = deg_to_rad(-longitude)
	lon = wrapf(lon, -PI, PI)
	var x = cos(lat) * cos(lon)
	var y = sin(lat)
	var z = cos(lat) * sin(lon)
	var direction = Vector3(x, y, z).normalized()
	return grid_index.pick_cell(direction, use_strict_check)

#endregion

#region Highlighting and Drawing

func _draw_hover() -> void:
	if hovered_cell < 0:
		_hover_mesh.mesh = null
		return
	_hover_mesh.mesh = _build_edge_mesh([hovered_cell])

func _draw_selected_and_neighbors() -> void:
	if selected_cell < 0:
		_selected_mesh.mesh = null
		_neighbor_mesh.mesh = null
		return

	_selected_mesh.mesh = _build_edge_mesh([selected_cell])

	if show_neighbor_ring:
		var neigh = grid_index.get_cell_neighbors(selected_cell)
		if neigh.is_empty():
			_neighbor_mesh.mesh = null
		else:
			var ids: Array[int] = []
			for i in neigh.size():
				ids.append(neigh[i])
			_neighbor_mesh.mesh = _build_edge_mesh(ids)
	else:
		_neighbor_mesh.mesh = null

func _rebuild_highlights() -> void:
	_draw_hover()
	_draw_selected_and_neighbors()
	if use_texture_colors:
		_rebuild_colored_cells()
	if show_cell_defintions:
		_rebuild_cell_definitions()
	_apply_visual_scaling()

func _build_edge_mesh(ids: Array[int]) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)

	for id in ids:
		var verts = grid_index.get_cell_vertices(id)
		if verts.is_empty():
			var c = grid_index.get_cell_center(id)
			var p = c * (_sphere_radius + highlight_elevation)
			st.add_vertex(p - c * 0.02)
			st.add_vertex(p + c * 0.02)
			continue

		var m = verts.size()
		for i in range(m):
			var a = verts[i].normalized()
			var b = verts[(i + 1) % m].normalized()
			var pa = a * (_sphere_radius + highlight_elevation)
			var pb = b * (_sphere_radius + highlight_elevation)
			st.add_vertex(pa)
			st.add_vertex(pb)

	return st.commit()

func _apply_visual_scaling() -> void:
	var comps = [
		_hover_mesh,
		_selected_mesh,
		_neighbor_mesh,
		_markers,
		_city_cells_mesh,
		_colored_cells_mesh
	]
	for n in comps:
		if n:
			n.transform = Transform3D()

#endregion

#region Markers

func _rebuild_markers() -> void:
	if grid_index == null or grid_index.tile_count() == 0:
		if _markers:
			_markers.visible = false
			_markers.multimesh = null
		return

	var marker_mesh = SphereMesh.new()
	marker_mesh.radius = marker_scale
	marker_mesh.height = marker_scale * 2.0
	marker_mesh.rings = 8
	marker_mesh.radial_segments = 12

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = marker_mesh
	mm.instance_count = grid_index.tile_count()

	_markers.multimesh = mm
	_markers.visible = show_markers

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_markers.material_override = mat

	for i in range(mm.instance_count):
		var c = grid_index.get_cell_center(i).normalized()
		var pos = c * (_sphere_radius + marker_elevation)
		var xf = Transform3D(Basis(), pos)
		mm.set_instance_transform(i, xf)
		mm.set_instance_color(i, marker_color)

	_apply_visual_scaling()

	if show_cell_defintions:
		_rebuild_cell_definitions()
	_rebuild_colored_cells()

#endregion

#region City Cells and Definitions

func request_definitions_rebuild() -> void:
	if not show_cell_defintions:
		return
	if _cell_definition_rebuild_running:
		_cell_definition_rebuild_pending = true
		return
	_rebuild_cell_definitions()

func _rebuild_cell_definitions() -> void:
	if not show_cell_defintions or hex_grid_data == null or hex_grid_data.cell_definitions.is_empty():
		_city_cells_mesh.mesh = null
		return
	if _cell_definition_rebuild_running:
		_cell_definition_rebuild_pending = true
		return
	_cell_definition_rebuild_running = true
	call_deferred("_rebuild_cell_definitions_async")

func _rebuild_cell_definitions_async() -> void:
	var mesh = ArrayMesh.new()
	var defined_cells: Array = hex_grid_data.get_defined_cell_indices()
	defined_cells.sort()

	var total_cells = defined_cells.size()
	if total_cells == 0:
		_city_cells_mesh.mesh = null
		_cell_definition_rebuild_running = false
		return

	var surfaces_built = 0
	var idx = 0
	while idx < total_cells:
		var end_idx = min(idx + cells_per_surface, total_cells)
		var sub_vertices = PackedVector3Array()
		var sub_indices = PackedInt32Array()
		var sub_colors = PackedColorArray()

		var vertex_offset = 0
		for i in range(idx, end_idx):
			var cell_index: int = int(defined_cells[i])
			var poly = grid_index.get_cell_vertices(cell_index)
			if poly.size() < 3:
				continue

			var defs: Array = hex_grid_data.get_cell_definitions(cell_index)
			var cell_color = Color.WHITE
			if not defs.is_empty():
				var d: HexCellDefinition = defs[0]
				cell_color = d.get_cell_color()

			var center = grid_index.get_cell_center(cell_index)
			var elevated = _sphere_radius + city_cell_highlight_elevation

			sub_vertices.append(center * elevated)
			sub_colors.append(cell_color)
			for vtx in poly:
				sub_vertices.append(vtx.normalized() * elevated)
				sub_colors.append(cell_color)

			var m = poly.size()
			for t in range(m):
				sub_indices.append(vertex_offset + 0)
				sub_indices.append(vertex_offset + t + 1)
				sub_indices.append(vertex_offset + ((t + 1) % m) + 1)
			vertex_offset = sub_vertices.size()

		if sub_vertices.size() > 0:
			var arrays = []
			arrays.resize(ArrayMesh.ARRAY_MAX)
			arrays[ArrayMesh.ARRAY_VERTEX] = sub_vertices
			arrays[ArrayMesh.ARRAY_INDEX] = sub_indices
			arrays[ArrayMesh.ARRAY_COLOR] = sub_colors
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			surfaces_built += 1

		idx = end_idx

		if yield_every_surfaces > 0 and (surfaces_built % yield_every_surfaces) == 0:
			await get_tree().process_frame

	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_city_cells_mesh.material_override = mat
	_city_cells_mesh.mesh = mesh
	_apply_visual_scaling()

	_cell_definition_rebuild_running = false
	if _cell_definition_rebuild_pending:
		_cell_definition_rebuild_pending = false
		_rebuild_cell_definitions()

#endregion

#region Colored Cells (Texture-based)

func _rebuild_colored_cells() -> void:
	if not use_texture_colors or grid_index == null:
		_colored_cells_mesh.mesh = null
		return

	var sphere_globe = _sphere as SphereGlobe
	if sphere_globe == null or sphere_globe.globe_texture == null:
		_colored_cells_mesh.mesh = null
		return

	var vertices_array = PackedVector3Array()
	var indices_array = PackedInt32Array()
	var colors_array = PackedColorArray()
	var vertex_count = 0

	var cell_count = grid_index.tile_count()
	for cell_index in range(cell_count):
		var vertices = grid_index.get_cell_vertices(cell_index)
		if vertices.size() < 3:
			continue

		var center = grid_index.get_cell_center(cell_index)
		var texture_color = _get_texture_color_from_position(center, sphere_globe)

		var vertex_offset = vertex_count
		_add_colored_polygon_arrays(
			vertices,
			cell_index,
			texture_color,
			vertices_array,
			indices_array,
			colors_array,
			vertex_offset
		)
		vertex_count = vertices_array.size()

	if vertices_array.size() > 0:
		var mesh = ArrayMesh.new()
		var arrays = []
		arrays.resize(ArrayMesh.ARRAY_MAX)
		arrays[ArrayMesh.ARRAY_VERTEX] = vertices_array
		arrays[ArrayMesh.ARRAY_INDEX] = indices_array
		arrays[ArrayMesh.ARRAY_COLOR] = colors_array

		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

		var mat = StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 1.0, 1.0, color_blend_factor)
		_colored_cells_mesh.material_override = mat

		_colored_cells_mesh.mesh = mesh
		_apply_visual_scaling()
	else:
		_colored_cells_mesh.mesh = null

func _get_texture_color_from_position(pos: Vector3, sphere_globe: SphereGlobe) -> Color:
	var n = pos.normalized()
	var lat1 = asin(clamp(n.y, -1.0, 1.0))
	var lon2 = atan2(-n.z, n.x)
	var latitude = rad_to_deg(lat1)
	var longitude = rad_to_deg(lon2)
	return sphere_globe.get_color_at_coordinates(latitude, longitude)

func _add_colored_polygon_arrays(
	vertices: PackedVector3Array,
	cell_index: int,
	color: Color,
	vertices_array: PackedVector3Array,
	indices_array: PackedInt32Array,
	colors_array: PackedColorArray,
	vertex_offset: int
) -> void:
	if vertices.size() < 3:
		return

	var center = grid_index.get_cell_center(cell_index)
	var elevated_position = _sphere_radius + 0.001
	var center_point = center * elevated_position
	vertices_array.append(center_point)
	colors_array.append(color)

	for vertex in vertices:
		var elevated_vertex = vertex.normalized() * elevated_position
		vertices_array.append(elevated_vertex)
		colors_array.append(color)

	for i in range(vertices.size()):
		indices_array.append(vertex_offset + 0)
		indices_array.append(vertex_offset + i + 1)
		indices_array.append(vertex_offset + ((i + 1) % vertices.size()) + 1)

#endregion

#region JSON Loading and Caching

func _setup_json_parse() -> void:
	if use_city_cache and _try_load_city_cache():
		print("Loaded city assignments from cache.")
		if show_cell_defintions:
			_rebuild_cell_definitions()
		return

	if loading_thread != null and loading_thread.is_alive():
		return
	loading_thread = Thread.new()
	loading_thread.start(
		_load_cities_thread_func.bind(
			"res://RawData/cities_filtered.json"
		)
	)
	print("Started loading cities in a background thread...")

func _load_cities_thread_func(filepath: String) -> void:
	var file = FileAccess.open(filepath, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()

		var json_result = JSON.parse_string(content)
		if json_result != null:
			if json_result is Dictionary and json_result.has("cities"):
				var arr: Array = json_result["cities"]
				call_deferred("_begin_city_assignment_from_array", arr)
			elif json_result is Array:
				call_deferred("_begin_city_assignment_from_array", json_result)
			else:
				push_warning("Unexpected JSON root. Expected { cities: [...] } or [ ... ].")
		else:
			push_warning("Error parsing JSON: Invalid JSON format")
	else:
		push_warning("Error opening file: " + filepath)

func _begin_city_assignment_from_array(arr: Array) -> void:
	_cities_array = arr.duplicate()
	_assign_idx = 0
	_assigning = true
	set_process(true)
	print("Will assign %d cities in chunks..." % _cities_array.size())

func _grid_signature() -> String:
	if grid_index == null:
		return "no_grid"
	return "tiles_%d_lat_%d_lon_%d" % [
		grid_index.tile_count(),
		grid_index.lat_bins,
		grid_index.lon_bins
	]

func _cache_path() -> String:
	var sig = _grid_signature()
	return "%s/cities_%s.json" % [cache_directory, sig]

func _ensure_cache_dir() -> void:
	var err = DirAccess.make_dir_recursive_absolute(cache_directory)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("Failed to ensure cache dir: %s" % cache_directory)

func _try_load_city_cache() -> bool:
	_ensure_cache_dir()
	var path = _cache_path()
	if not FileAccess.file_exists(path):
		return false
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var txt = f.get_as_text()
	f.close()
	var data = JSON.parse_string(txt)
	if data == null or not (data is Dictionary):
		return false
	if not data.has("signature") or data["signature"] != _grid_signature():
		return false
	if not data.has("cities") or not (data["cities"] is Array):
		return false

	hex_grid_data.clear()
	for item in data["cities"]:
		if not (item is Dictionary):
			continue
		if not item.has("index") or not item.has("name"):
			continue
		var idx = int(item["index"])
		var pop = int(item.get("population", 0))
		var cc = str(item.get("country_code", ""))
		var city_def = CityDefinition.new(idx, str(item["name"]), pop, cc)
		hex_grid_data.add_cell_definition(idx, city_def, self)

	return true

func _save_city_cache() -> void:
	_ensure_cache_dir()
	var path = _cache_path()
	var out = {
		"signature": _grid_signature(),
		"cities": []
	}
	for cell_index in hex_grid_data.cell_definitions.keys():
		var defs: Array = hex_grid_data.get_cell_definitions(cell_index)
		for d in defs:
			if d is CityDefinition:
				var cd: CityDefinition = d
				out["cities"].append({
					"index": int(cell_index),
					"name": cd.city_name,
					"population": cd.population,
					"country_code": cd.country_code
				})
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out))
		f.close()
	else:
		push_warning("Failed to write city cache to: %s" % path)

#endregion

#region Helper Functions
func get_cell_world_position(cell_index: int, elevation_offset: float = 0.0) -> Vector3:
	if grid_index == null or cell_index < 0 or cell_index >= grid_index.tile_count():
		return Vector3.ZERO
	
	var center = grid_index.get_cell_center(cell_index).normalized()
	return center * (_sphere_radius + elevation_offset)



func _get_sphere_radius(sphere_node: Node) -> float:
	if sphere_node.has_method("_get_sphere_radius"):
		return sphere_node._get_sphere_radius()
	elif sphere_node is MeshInstance3D and sphere_node.mesh is SphereMesh:
		var mesh = sphere_node.mesh as SphereMesh
		return mesh.radius * sphere_node.scale.x
	elif sphere_node is CollisionShape3D and sphere_node.shape is SphereShape3D:
		var shape = sphere_node.shape as SphereShape3D
		return shape.radius * sphere_node.scale.x
	if sphere_node is Node3D:
		return sphere_node.scale.x
	return 1.0

func _get_camera() -> Camera3D:
	if camera_path != NodePath():
		var node = get_node_or_null(camera_path)
		if node and node is Camera3D:
			return node
	return get_viewport().get_camera_3d()

func _n_to_latlon(n: Vector3) -> Vector2:
	var normalized_n = n.normalized()
	var lat = asin(clamp(normalized_n.y, -1.0, 1.0))
	var lon = atan2(normalized_n.z, normalized_n.x)
	return Vector2(lat, lon)

static func _make_unshaded_line_material(color: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

#endregion

#region New Helper Functions

## Returns all cells within a latitude/longitude bounding box.
## lat_min, lat_max: Latitude range in degrees (-90 to 90)
## lon_min, lon_max: Longitude range in degrees (-180 to 180)
func get_cells_in_area(
	lat_min: float, 
	lat_max: float, 
	lon_min: float, 
	lon_max: float
) -> Array[int]:
	if grid_index == null:
		return []
	
	var result: Array[int] = []
	lat_min = clamp(lat_min, -90.0, 90.0)
	lat_max = clamp(lat_max, -90.0, 90.0)
	
	# Handle longitude wrapping
	var lon_wrapped = lon_max < lon_min
	
	for cell_id in range(grid_index.tile_count()):
		var center = grid_index.get_cell_center(cell_id)
		var latlon = _n_to_latlon(center)
		var lat_deg = rad_to_deg(latlon.x)
		var lon_deg = rad_to_deg(latlon.y)
		
		# Check latitude
		if lat_deg < lat_min or lat_deg > lat_max:
			continue
		
		# Check longitude (handle wrapping around 180/-180)
		if lon_wrapped:
			if lon_deg < lon_min and lon_deg > lon_max:
				continue
		else:
			if lon_deg < lon_min or lon_deg > lon_max:
				continue
		
		result.append(cell_id)
	
	return result

## Returns all cells within N steps from a center cell using BFS.
## center_cell: The starting cell index
## radius: Number of neighbor steps (1 = immediate neighbors, 2 = neighbors + their neighbors, etc.)
func get_cells_in_radius(center_cell: int, radius: int) -> Array[int]:
	if grid_index == null or center_cell < 0 or center_cell >= grid_index.tile_count():
		return []
	
	if radius <= 0:
		return [center_cell]
	
	var result: Array[int] = []
	var visited = {}
	var queue: Array[Dictionary] = []
	
	# Start with center cell at distance 0
	queue.append({"cell": center_cell, "dist": 0})
	visited[center_cell] = true
	result.append(center_cell)
	
	var queue_idx = 0
	while queue_idx < queue.size():
		var current = queue[queue_idx]
		queue_idx += 1
		
		var cell_id = current["cell"]
		var dist = current["dist"]
		
		if dist >= radius:
			continue
		
		var neighbors = grid_index.get_cell_neighbors(cell_id)
		for neighbor_id in neighbors:
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				result.append(neighbor_id)
				queue.append({"cell": neighbor_id, "dist": dist + 1})
	
	return result

## Returns a random valid cell index from the grid.
func get_random_cell() -> int:
	if grid_index == null or grid_index.tile_count() == 0:
		return -1
	return randi() % grid_index.tile_count()

## Returns multiple random cells (without duplicates if possible).
## count: Number of random cells to return
func get_random_cells(count: int) -> Array[int]:
	if grid_index == null or grid_index.tile_count() == 0:
		return []
	
	var result: Array[int] = []
	var tile_count = grid_index.tile_count()
	
	# If asking for more cells than exist, return all
	if count >= tile_count:
		for i in range(tile_count):
			result.append(i)
		return result
	
	# Use a set to avoid duplicates
	var selected = {}
	while result.size() < count:
		var cell = randi() % tile_count
		if not selected.has(cell):
			selected[cell] = true
			result.append(cell)
	
	return result

## Returns the distance (in cell steps) between two cells using BFS.
## Returns -1 if no path exists (shouldn't happen on a sphere).
func get_cell_distance(from_cell: int, to_cell: int) -> int:
	if grid_index == null:
		return -1
	if from_cell == to_cell:
		return 0
	if from_cell < 0 or from_cell >= grid_index.tile_count():
		return -1
	if to_cell < 0 or to_cell >= grid_index.tile_count():
		return -1
	
	var visited = {}
	var queue: Array[Dictionary] = []
	
	queue.append({"cell": from_cell, "dist": 0})
	visited[from_cell] = true
	
	var queue_idx = 0
	while queue_idx < queue.size():
		var current = queue[queue_idx]
		queue_idx += 1
		
		var cell_id = current["cell"]
		var dist = current["dist"]
		
		var neighbors = grid_index.get_cell_neighbors(cell_id)
		for neighbor_id in neighbors:
			if neighbor_id == to_cell:
				return dist + 1
			
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				queue.append({"cell": neighbor_id, "dist": dist + 1})
	
	return -1

#endregion
