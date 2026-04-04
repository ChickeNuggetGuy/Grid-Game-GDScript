@tool
class_name HexGridDecorator
extends Node3D

signal cell_hovered(id: int)
signal cell_selected(id: int)

#region Exports
@export_group("Grid Configuration")
@export var grid_index: GridIndex:
	set = set_grid_index
@export var collision_shape: CollisionShape3D
@export var camera_path: NodePath
@export var auto_hover = true
@export var auto_click_select = true
@export var strict_polygon_check = false

@export_group("Visuals")
@export var show_neighbor_ring = true
@export var highlight_elevation = 0.01
@export var hover_color = Color(0.2, 0.8, 1.0)
@export var selected_color = Color(1.0, 0.8, 0.2)
@export var neighbor_color = Color(0.5, 0.9, 0.6)

@export_group("Markers")
@export var show_markers = false:
	set = set_show_markers
@export var marker_scale = 0.02
@export var marker_elevation = 0.01
@export var marker_color = Color(0.95, 0.2, 0.2)

@export_group("City Visualization")
@export var show_cell_defintions = true:
	set = set_show_cell_defintions
@export var city_cell_color = Color(0.9, 0.3, 0.3, 0.7)
@export var city_cell_highlight_elevation = 0.02

@export_group("Texture Data Maps")
@export var use_texture_colors = false:
	set = set_use_texture_colors
@export var color_blend_factor = 0.7:
	set = set_color_blend_factor

## Dictionary of Map Name (String) -> Texture2D.
## Required keys for logic: "political", "cities", "visual" (optional for coloring)
@export var data_maps: Dictionary[String, Texture2D]

@export_group("Generation Settings")
@export var auto_generate_index = false
@export var frequency = 16
@export var lat_bins_override = 128
@export var lon_bins_override = 256
@export var generate_now = false:
	set = set_generate_now

@export var cells_per_surface = 3000
@export var yield_every_surfaces = 1

@export_group("Baked Data")
@export var use_baked_data: bool = true
@export var baked_data: GlobeBakedData
@export_file("*.res") var baked_data_save_path := "res://Data/globe_baked_data.res"
@export var bake_baked_data_now := false:
	set = set_bake_baked_data_now

@export_group("Map Adjustments")
## Offset for the political map UVs (0.0 to 1.0).
@export var political_map_offset: Vector2 = Vector2.ZERO
## Offset for the cities map UVs.
@export var city_map_offset: Vector2 = Vector2.ZERO
## Offset for any other texture maps used in 'visual' coloring.
@export var visual_map_offset: Vector2 = Vector2.ZERO

#region Country Cache
# Maps Cell ID -> Country ID.
# Optimized for save size (PackedInt32Array is very small in binary).
var _cell_country_indices: PackedInt32Array

# Runtime only (Do not save this). Maps Country ID -> Array of Cell IDs.
# Used for instant lookup when highlighting.
var _country_groups: Dictionary = {}

# Maps the Color string/data to a unique integer ID
var _color_to_id_map: Dictionary = {}
#endregion
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

# Cache for map images to avoid locking textures repeatedly
var _map_images: Dictionary = {}

var _cell_definition_rebuild_running = false
var _cell_definition_rebuild_pending = false
var _applying_baked_data := false

# Map specific colors to Country Codes.
# Adjust these keys to match the specific colors in your political map texture.
const COUNTRY_COLOR_MAP = {
	Color("FF0000"): "RED_COUNTRY",
	Color("00FF00"): "GRN_COUNTRY",
	Color("0000FF"): "BLU_COUNTRY",
}
#endregion

#region Lifecycle Methods

func _ready() -> void:
	_sphere = get_parent()
	if _sphere:
		_sphere_radius = _get_sphere_radius(_sphere)
		if collision_shape and collision_shape.shape:
			collision_shape.shape.radius = _sphere_radius

	_ensure_nodes()

	if hex_grid_data == null:
		hex_grid_data = HexGridData.new(self)

	if use_baked_data and baked_data != null:
		apply_baked_data(baked_data)
	else:
		if grid_index == null and auto_generate_index:
			_generate_grid()

		if grid_index and grid_index.bin_offsets.is_empty():
			grid_index.build_bins()

		if not data_maps.is_empty():
			initialize_grid_from_maps()

	_rebuild_highlights()

	if show_markers:
		_rebuild_markers()

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

			# OPTION A: Standard single cell hover
			# _draw_hover()

			# OPTION B: Country Highlight
			_highlight_country_at_cell(hovered_cell)

			emit_signal("cell_hovered", hovered_cell)

	if auto_click_select and event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var id2 = pick_cell_from_screen(event.position)
		if id2 >= 0 and id2 != selected_cell:
			select_cell(id2)

#endregion

#region Baked Data

func set_bake_baked_data_now(v: bool) -> void:
	bake_baked_data_now = false
	if not v:
		return
	if baked_data_save_path.is_empty():
		push_warning("No baked_data_save_path set.")
		return
	save_baked_data(baked_data_save_path)

func build_baked_data() -> GlobeBakedData:
	var out := GlobeBakedData.new()
	out.grid_index = grid_index
	out.cell_country_indices = _cell_country_indices.duplicate()
	out.cell_definitions = _serialize_hex_grid_data()
	return out

func save_baked_data(path: String) -> void:
	if grid_index == null:
		_generate_grid()

	if grid_index and grid_index.bin_offsets.is_empty():
		grid_index.build_bins()

	if hex_grid_data == null:
		hex_grid_data = HexGridData.new(self)

	if hex_grid_data.cell_definitions.is_empty() and not data_maps.is_empty():
		initialize_grid_from_maps()

	var out := build_baked_data()
	var err := ResourceSaver.save(out, path)
	if err != OK:
		push_error("Failed to save baked globe data to: " + path)
	else:
		print("Saved baked globe data to: ", path)

func apply_baked_data(data: GlobeBakedData) -> void:
	if data == null:
		return

	_applying_baked_data = true

	grid_index = data.grid_index
	if grid_index and grid_index.bin_offsets.is_empty():
		grid_index.build_bins()

	if hex_grid_data == null:
		hex_grid_data = HexGridData.new(self)
	else:
		hex_grid_data.cell_definitions.clear()

	if not data.cell_definitions.is_empty():
		hex_grid_data.add_cell_definitions_from_data_bulk(data.cell_definitions)

	_cell_country_indices = data.cell_country_indices.duplicate()
	_rebuild_country_groups_from_indices()

	_applying_baked_data = false

func _serialize_hex_grid_data() -> Dictionary:
	var result: Dictionary = {}

	if hex_grid_data == null:
		return result

	for def_type in hex_grid_data.cell_definitions.keys():
		var defs: Array = hex_grid_data.cell_definitions[def_type]
		var arr: Array = []
		for def in defs:
			if def != null and def.has_method("serialize"):
				arr.append(def.serialize())
		result[int(def_type)] = arr

	return result

func _rebuild_country_groups_from_indices() -> void:
	_country_groups.clear()

	for i in range(_cell_country_indices.size()):
		var country_id := _cell_country_indices[i]
		if country_id < 0:
			continue

		if not _country_groups.has(country_id):
			_country_groups[country_id] = [] as Array[int]

		_country_groups[country_id].append(i)

#endregion

#region Data Map Initialization

func initialize_grid_from_maps() -> void:
	if grid_index == null or grid_index.tile_count() == 0:
		return

	print("Initializing Grid Data...")
	_prepare_map_images()

	# Reset Caches
	_cell_country_indices.resize(grid_index.tile_count())
	_cell_country_indices.fill(-1)
	_country_groups.clear()
	_color_to_id_map.clear()

	var next_country_id = 0
	var country_map_img: Image = _map_images.get("political")

	# Pre-calculate sampling data
	var cell_count = grid_index.tile_count()

	# --- PASS 1: POLITICAL DATA ---
	for i in range(cell_count):
		var center = grid_index.get_cell_center(i)
		var uv = _get_uv_from_position(center)

		if country_map_img:
			var poli_uv = uv + political_map_offset
			var color = _sample_image_uv(country_map_img, poli_uv)

			var rounded_color = Color(
				snapped(color.r, 1.0 / 255.0),
				snapped(color.g, 1.0 / 255.0),
				snapped(color.b, 1.0 / 255.0),
				1.0
			)

			if rounded_color.a > 0.1 and rounded_color != Color.BLACK:
				var color_key = rounded_color.to_html()

				if not _color_to_id_map.has(color_key):
					_color_to_id_map[color_key] = next_country_id
					_country_groups[next_country_id] = [] as Array[int]
					next_country_id += 1

				var c_id = _color_to_id_map[color_key]
				_cell_country_indices[i] = c_id
				_country_groups[c_id].append(i)

	# --- PASS 2: CITY DATA ---
	hex_grid_data.cell_definitions.clear()

	var city_definitions_to_add = {}
	var city_map_img: Image = _map_images.get("cities")

	for i in range(cell_count):
		var center = grid_index.get_cell_center(i)
		var uv = _get_uv_from_position(center)

		var country_code = "UNK"

		if country_map_img:
			var poli_uv = uv + political_map_offset
			country_code = _process_political_map(poli_uv, country_map_img)

		if city_map_img:
			var city_uv = uv + city_map_offset
			var city_def = _process_city_map(
				i,
				city_uv,
				city_map_img,
				country_code
			)
			if city_def:
				var def_type = city_def.get_class_name()
				if not city_definitions_to_add.has(def_type):
					city_definitions_to_add[def_type] = []
				city_definitions_to_add[def_type].append(city_def)

	for def_type in city_definitions_to_add.keys():
		for city_def in city_definitions_to_add[def_type]:
			hex_grid_data.add_cell_definition(
				city_def.cell_index,
				city_def.definition_type,
				city_def,
				null
			)

	request_definitions_rebuild()
	print("Grid Data initialization complete.")

func _prepare_map_images() -> void:
	_map_images.clear()
	for key in data_maps.keys():
		var texture = data_maps[key]
		if texture is Texture2D:
			var img = texture.get_image()
			if img:
				if img.is_compressed():
					var err = img.decompress()
					if err != OK:
						push_warning("Failed to decompress map image: " + key)
						continue

				_map_images[key] = img
			else:
				push_warning("Could not get image from texture: " + key)

func _process_city_map(
	cell_index: int,
	uv: Vector2,
	img: Image,
	country_code: String
) -> CityDefinition:
	var color = _sample_image_uv(img, uv)

	if color.r > 0.05:
		var population = int(color.r * 10000000)
		var city_name = "City_" + str(cell_index)

		var city_def = CityDefinition.new(
			cell_index,
			city_name,
			population,
			country_code
		)
		return city_def

	return null

func _highlight_country_at_cell(cell_id: int) -> void:
	if cell_id < 0 or cell_id >= _cell_country_indices.size():
		_neighbor_mesh.mesh = null
		return

	var country_id = _cell_country_indices[cell_id]

	if country_id == -1:
		_neighbor_mesh.mesh = null
		return

	var cells_to_highlight = _country_groups[country_id]
	_neighbor_mesh.mesh = _build_edge_mesh(cells_to_highlight)

func _process_political_map(uv: Vector2, img: Image) -> String:
	var color = _sample_image_uv(img, uv)

	var rounded_color = Color(
		snapped(color.r, 1.0 / 255.0),
		snapped(color.g, 1.0 / 255.0),
		snapped(color.b, 1.0 / 255.0),
		1.0
	)

	if COUNTRY_COLOR_MAP.has(rounded_color):
		return COUNTRY_COLOR_MAP[rounded_color]

	return "UNK"

func _sample_image_uv(img: Image, uv: Vector2) -> Color:
	var w = img.get_width()
	var h = img.get_height()

	var u = fmod(uv.x, 1.0)
	var v = fmod(uv.y, 1.0)
	if u < 0:
		u += 1.0
	if v < 0:
		v += 1.0

	var x = int(u * w)
	var y = int(v * h)

	x = clampi(x, 0, w - 1)
	y = clampi(y, 0, h - 1)

	return img.get_pixel(x, y)

## Converts 3D Position on sphere to UV coordinates (Equirectangular)
func _get_uv_from_position(pos: Vector3) -> Vector2:
	var n = pos.normalized()
	var u = 0.5 - (atan2(n.z, n.x) / TAU)
	var v = 0.5 - (asin(n.y) / PI)
	return Vector2(u, v)

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

		if not _applying_baked_data and not data_maps.is_empty():
			initialize_grid_from_maps()

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
		_rebuild_colored_cells()

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

	if not data_maps.is_empty():
		initialize_grid_from_maps()

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
	_selected_mesh.material_override = _make_unshaded_line_material(
		selected_color
	)

	_neighbor_mesh = $HighlightNeighbors \
		if has_node("HighlightNeighbors") else null
	if _neighbor_mesh == null:
		_neighbor_mesh = MeshInstance3D.new()
		_neighbor_mesh.name = "HighlightNeighbors"
		_neighbor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_neighbor_mesh)
	_neighbor_mesh.material_override = _make_unshaded_line_material(
		neighbor_color
	)

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

	_apply_visual_scaling()

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
	if not show_cell_defintions \
			or hex_grid_data == null \
			or hex_grid_data.cell_definitions.is_empty():
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

		if yield_every_surfaces > 0 \
				and (surfaces_built % yield_every_surfaces) == 0:
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

	if _map_images.is_empty():
		_prepare_map_images()

	var map_keys = _map_images.keys()
	map_keys.sort()

	if map_keys.is_empty():
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
		var uv = _get_uv_from_position(center)

		var final_color = Color(0, 0, 0, 0)

		for key in map_keys:
			var img: Image = _map_images[key]

			var current_uv = uv
			if key == "political":
				current_uv += political_map_offset
			elif key == "cities":
				current_uv += city_map_offset
			else:
				current_uv += visual_map_offset

			var layer_color = _sample_image_uv(img, current_uv)

			if final_color.a == 0:
				final_color = layer_color
			else:
				final_color = final_color.lerp(layer_color, layer_color.a)

		final_color.a *= color_blend_factor

		if final_color.a > 0.01:
			var vertex_offset = vertex_count
			_add_colored_polygon_arrays(
				vertices,
				cell_index,
				final_color,
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
		mat.albedo_color = Color.WHITE

		_colored_cells_mesh.material_override = mat
		_colored_cells_mesh.mesh = mesh
		_apply_visual_scaling()
	else:
		_colored_cells_mesh.mesh = null

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

#region Helper Functions

func get_cell_world_position(
	cell_index: int,
	elevation_offset: float = 0.0
) -> Vector3:
	if grid_index == null \
			or cell_index < 0 \
			or cell_index >= grid_index.tile_count():
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

	var lon_wrapped = lon_max < lon_min

	for cell_id in range(grid_index.tile_count()):
		var center = grid_index.get_cell_center(cell_id)
		var latlon = _n_to_latlon(center)
		var lat_deg = rad_to_deg(latlon.x)
		var lon_deg = rad_to_deg(latlon.y)

		if lat_deg < lat_min or lat_deg > lat_max:
			continue

		if lon_wrapped:
			if lon_deg < lon_min and lon_deg > lon_max:
				continue
		else:
			if lon_deg < lon_min or lon_deg > lon_max:
				continue

		result.append(cell_id)

	return result

func get_cells_in_radius(center_cell: int, radius: int) -> Array[int]:
	if grid_index == null \
			or center_cell < 0 \
			or center_cell >= grid_index.tile_count():
		return []

	if radius <= 0:
		return [center_cell]

	var result: Array[int] = []
	var visited = {}
	var queue: Array[Dictionary] = []

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

func get_random_cell() -> int:
	if grid_index == null or grid_index.tile_count() == 0:
		return -1
	return randi() % grid_index.tile_count()

func get_random_cells(count: int) -> Array[int]:
	if grid_index == null or grid_index.tile_count() == 0:
		return []

	var result: Array[int] = []
	var tile_count = grid_index.tile_count()

	if count >= tile_count:
		for i in range(tile_count):
			result.append(i)
		return result

	var selected = {}
	while result.size() < count:
		var cell = randi() % tile_count
		if not selected.has(cell):
			selected[cell] = true
			result.append(cell)

	return result

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

func _n_to_latlon(n: Vector3) -> Vector2:
	var normalized_n = n.normalized()
	var lat = asin(clamp(normalized_n.y, -1.0, 1.0))
	var lon = atan2(normalized_n.z, normalized_n.x)
	return Vector2(lat, lon)

#endregion
