extends Node3D
class_name GlobeHexGrid

signal cell_hovered(id: int)
signal cell_clicked(id: int, mouse_button: int)

# --------------------------- Config / Exports -----------------------------

var _subdivisions: int = 3
var _radius: float = 4.0
var _cell_opacity: float = 1.0
var _shaded_cells: bool = true

@export var _earth_texture: Texture2D = null

@export_range(0, 8, 1)
var subdivisions: int = _subdivisions:
	set(value):
		var v: int = max(0, value)
		if v == _subdivisions:
			return
		_subdivisions = v
		if is_inside_tree():
			_rebuild_all()
		else:
			call_deferred("_rebuild_all")
	get:
		return _subdivisions

@export
var radius: float = _radius:
	set(value):
		var v: float = max(0.001, value)
		if is_equal_approx(v, _radius):
			return
		_radius = v
		if is_inside_tree():
			_apply_radius_scale()
		else:
			call_deferred("_apply_radius_scale")
	get:
		return _radius

@export var camera_path: NodePath
@export var draw_cells: bool = true
@export var draw_grid: bool = true
@export var draw_hover: bool = true

@export var grid_color: Color = Color(0.15, 0.9, 0.9, 0.7)
@export var hover_color: Color = Color(1.0, 0.5, 0.1, 0.85)
@export var default_cell_color: Color = Color(0.3, 0.6, 1.0, 1.0)

@export_range(0.0, 1.0, 0.01)
var cell_opacity: float = _cell_opacity:
	set(value):
		var v : float= clamp(value, 0.0, 1.0)
		if is_equal_approx(v, _cell_opacity):
			return
		_cell_opacity = v
		if is_inside_tree():
			_refresh_cell_material_opacity_mode()
		else:
			call_deferred("_refresh_cell_material_opacity_mode")
	get:
		return _cell_opacity

@export_range(-180.0, 180.0, 1.0)
var texture_u_rotation_degrees: float = 0.0
@export var texture_flip_v: bool = false
@export var sample_bilinear: bool = true

# New: control whether cells use lit shading
@export var shaded_cells: bool = _shaded_cells:
	set(value):
		if value == _shaded_cells:
			return
		_shaded_cells = value
		if is_inside_tree():
			_recreate_cell_materials()
		else:
			call_deferred("_recreate_cell_materials")
	get:
		return _shaded_cells

# New: lift ratios (fraction of radius) for visual stacking
@export_range(0.0, 0.05, 0.0005)
var cell_lift_ratio: float = 0.0005:
	set(value):
		var v :float = clamp(value, 0.0, 0.05)
		if is_equal_approx(v, cell_lift_ratio):
			return
		cell_lift_ratio = v
		# Rebuild only cell and hover meshes (geometry changes)
		if is_inside_tree():
			_build_cell_mesh()
			_update_hover_mesh()
		else:
			call_deferred("_build_cell_mesh")
			call_deferred("_update_hover_mesh")

@export_range(0.0, 0.05, 0.0005)
var hover_lift_ratio: float = 0.005:
	set(value):
		var v :float= clamp(value, 0.0, 0.05)
		if is_equal_approx(v, hover_lift_ratio):
			return
		hover_lift_ratio = v
		if is_inside_tree():
			_update_hover_mesh()
		else:
			call_deferred("_update_hover_mesh")

# ------------------------------ Data -------------------------------------

var _verts: PackedVector3Array = PackedVector3Array()
var _faces: PackedInt32Array = PackedInt32Array()
var _nbrs: Array[PackedInt32Array] = []
var _faces_by_vert: Array[PackedInt32Array] = []
var _face_centers: PackedVector3Array = PackedVector3Array()

var _cells: Array[Cell] = []
var _hovered_id: int = -1
var _last_id: int = -1

var _cell_mi: MeshInstance3D = null
var _grid_mi: MeshInstance3D = null
var _hover_mi: MeshInstance3D = null

var _cell_mat_opaque: ShaderMaterial = null
var _cell_mat_transparent: ShaderMaterial = null
var _grid_mat: ShaderMaterial = null
var _hover_mat: ShaderMaterial = null

# ------------------------------ Lifecycle --------------------------------

func _ready() -> void:
	if camera_path == NodePath():
		push_warning(
			"Assign a Camera3D to camera_path for mouse picking to work."
		)
	_rebuild_all()
	set_process_unhandled_input(true)

# ------------------------------- Public API ------------------------------

func get_cell_count() -> int:
	return _verts.size()

func get_hex_count() -> int:
	return max(0, get_cell_count() - 12)

func get_cell_center_world(id: int) -> Vector3:
	return global_transform.origin + _cells[id].center_unit * _radius

func get_cell_polygon_world(id: int) -> PackedVector3Array:
	var arr: PackedVector3Array = PackedVector3Array()
	var poly: PackedVector3Array = _cells[id].polygon
	arr.resize(poly.size())
	var origin: Vector3 = global_transform.origin
	for i in range(poly.size()):
		arr[i] = origin + poly[i] * _radius
	return arr

func get_cell_neighbors(id: int) -> PackedInt32Array:
	return _cells[id].neighbors

func set_cell_color(id: int, color: Color) -> void:
	if id < 0 or id >= _cells.size():
		return
	_cells[id].color = color
	_build_cell_mesh()
	_refresh_cell_material_opacity_mode()

func set_all_cells_color(color: Color) -> void:
	for i in range(_cells.size()):
		_cells[i].color = color
	_build_cell_mesh()
	_refresh_cell_material_opacity_mode()

# Returns -1 if no hit on the sphere; otherwise the cell id
func get_cell_at_mouse() -> int:
	if not is_inside_tree():
		return -1
	var cam: Camera3D = _get_camera()
	if cam == null:
		return -1
	var mp: Vector2 = get_viewport().get_mouse_position()
	var ro: Vector3 = cam.project_ray_origin(mp)
	var rd: Vector3 = cam.project_ray_normal(mp).normalized()
	var hit: HitResult = _intersect_ray_sphere(
		ro, rd, global_transform.origin, _radius
	)
	if not hit.success:
		return -1
	var p_unit: Vector3 = (hit.position - global_transform.origin).normalized()
	return _find_cell_by_direction(p_unit)

# ---------------------------- Input handling -----------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var id: int = get_cell_at_mouse()
		if id != _hovered_id:
			_hovered_id = id
			emit_signal("cell_hovered", _hovered_id)
			_update_hover_mesh()
	elif event is InputEventMouseButton and event.pressed:
		var id2: int = get_cell_at_mouse()
		if id2 != -1:
			emit_signal("cell_clicked", id2, event.button_index)

# ---------------------------- Build pipeline -----------------------------

func _rebuild_all() -> void:
	_build_icosphere(_subdivisions)
	_build_adjacency()
	_build_dual_cells()
	_ensure_draw_nodes_and_materials()
	_update_cell_colors_from_texture()
	_build_cell_mesh()
	_build_grid_mesh()
	_update_hover_mesh()
	_refresh_cell_material_opacity_mode()
	_apply_radius_scale()

func _build_icosphere(s: int) -> void:
	_verts = PackedVector3Array()
	_faces = PackedInt32Array()

	var t: float = (1.0 + sqrt(5.0)) / 2.0
	var base: Array[Vector3] = [
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
		Vector3(-t, 0, 1)
	]
	var faces: Array[PackedInt32Array] = [
		PackedInt32Array([0, 11, 5]),
		PackedInt32Array([0, 5, 1]),
		PackedInt32Array([0, 1, 7]),
		PackedInt32Array([0, 7, 10]),
		PackedInt32Array([0, 10, 11]),
		PackedInt32Array([1, 5, 9]),
		PackedInt32Array([5, 11, 4]),
		PackedInt32Array([11, 10, 2]),
		PackedInt32Array([10, 7, 6]),
		PackedInt32Array([7, 1, 8]),
		PackedInt32Array([3, 9, 4]),
		PackedInt32Array([3, 4, 2]),
		PackedInt32Array([3, 2, 6]),
		PackedInt32Array([3, 6, 8]),
		PackedInt32Array([3, 8, 9]),
		PackedInt32Array([4, 9, 5]),
		PackedInt32Array([2, 4, 11]),
		PackedInt32Array([6, 2, 10]),
		PackedInt32Array([8, 6, 7]),
		PackedInt32Array([9, 8, 1])
	]

	_verts.resize(base.size())
	for i in range(base.size()):
		_verts[i] = base[i].normalized()

	var tri: PackedInt32Array = PackedInt32Array()
	tri.resize(faces.size() * 3)
	var ti: int = 0
	for f in faces:
		tri[ti] = f[0]
		tri[ti + 1] = f[1]
		tri[ti + 2] = f[2]
		ti += 3
	_faces = tri

	for _i in range(s):
		_subdivide_once()

func _subdivide_once() -> void:
	var new_faces: PackedInt32Array = PackedInt32Array()
	new_faces.resize(_faces.size() * 4)
	var write: int = 0
	var mid_cache: Dictionary = {}

	for i in range(0, _faces.size(), 3):
		var a: int = _faces[i]
		var b: int = _faces[i + 1]
		var c: int = _faces[i + 2]

		var ab: int = _midpoint_index(a, b, mid_cache)
		var bc: int = _midpoint_index(b, c, mid_cache)
		var ca: int = _midpoint_index(c, a, mid_cache)

		new_faces[write] = a
		new_faces[write + 1] = ab
		new_faces[write + 2] = ca
		write += 3
		new_faces[write] = b
		new_faces[write + 1] = bc
		new_faces[write + 2] = ab
		write += 3
		new_faces[write] = c
		new_faces[write + 1] = ca
		new_faces[write + 2] = bc
		write += 3
		new_faces[write] = ab
		new_faces[write + 1] = bc
		new_faces[write + 2] = ca
		write += 3
	_faces = new_faces

func _midpoint_index(a: int, b: int, cache: Dictionary) -> int:
	var x: int = a
	var y: int = b
	if x > y:
		var t: int = x
		x = y
		y = t
	var key: int = int((int(x) << 32) | int(y))
	if cache.has(key):
		return int(cache[key])
	var p: Vector3 = (_verts[a] + _verts[b]).normalized()
	var idx: int = _verts.size()
	_verts.append(p)
	cache[key] = idx
	return idx

func _build_adjacency() -> void:
	var vcount: int = _verts.size()
	_nbrs.clear()
	_nbrs.resize(vcount)
	_faces_by_vert.clear()
	_faces_by_vert.resize(vcount)
	for i in range(vcount):
		_nbrs[i] = PackedInt32Array()
		_faces_by_vert[i] = PackedInt32Array()

	var edge_set: Dictionary = {}
	for f_idx in range(0, _faces.size(), 3):
		var i0: int = _faces[f_idx]
		var i1: int = _faces[f_idx + 1]
		var i2: int = _faces[f_idx + 2]

		var arr0: PackedInt32Array = _faces_by_vert[i0]
		arr0.append(f_idx / 3)
		_faces_by_vert[i0] = arr0

		var arr1: PackedInt32Array = _faces_by_vert[i1]
		arr1.append(f_idx / 3)
		_faces_by_vert[i1] = arr1

		var arr2: PackedInt32Array = _faces_by_vert[i2]
		arr2.append(f_idx / 3)
		_faces_by_vert[i2] = arr2

		_add_edge(i0, i1, edge_set)
		_add_edge(i1, i2, edge_set)
		_add_edge(i2, i0, edge_set)

	var fcount: int = _faces.size() / 3
	_face_centers = PackedVector3Array()
	_face_centers.resize(fcount)
	for fi in range(0, _faces.size(), 3):
		var a: Vector3 = _verts[_faces[fi]]
		var b: Vector3 = _verts[_faces[fi + 1]]
		var c: Vector3 = _verts[_faces[fi + 2]]
		_face_centers[fi / 3] = (a + b + c).normalized()

func _add_edge(i: int, j: int, edge_set: Dictionary) -> void:
	var a: int = i
	var b: int = j
	if a > b:
		var t: int = a
		a = b
		b = t
	var key: int = int((int(a) << 32) | int(b))
	if edge_set.has(key):
		return
	edge_set[key] = true

	var ai: PackedInt32Array = _nbrs[i]
	ai.append(j)
	_nbrs[i] = ai

	var aj: PackedInt32Array = _nbrs[j]
	aj.append(i)
	_nbrs[j] = aj

func _build_dual_cells() -> void:
	_cells.clear()
	_cells.resize(_verts.size())

	for vid in range(_verts.size()):
		var cell: Cell = Cell.new()
		cell.id = vid
		cell.center_unit = _verts[vid]
		cell.neighbors = _nbrs[vid]
		var ordered_faces: PackedInt32Array = _order_faces_around_vertex(vid)

		var poly: PackedVector3Array = PackedVector3Array()
		poly.resize(ordered_faces.size())
		for i in range(ordered_faces.size()):
			poly[i] = _face_centers[ordered_faces[i]]
		cell.polygon = poly
		cell.is_pentagon = poly.size() == 5
		cell.color = default_cell_color
		_cells[vid] = cell

func _order_faces_around_vertex(vid: int) -> PackedInt32Array:
	var faces: PackedInt32Array = _faces_by_vert[vid]
	if faces.size() <= 2:
		return faces

	var n: Vector3 = _verts[vid]
	var axis_x: Vector3
	if abs(n.y) < 0.99:
		axis_x = Vector3(0, 1, 0).cross(n).normalized()
	else:
		axis_x = Vector3(1, 0, 0).cross(n).normalized()
	var axis_y: Vector3 = n.cross(axis_x).normalized()

	var pairs: Array[Vector2] = []
	pairs.resize(faces.size())
	for i in range(faces.size()):
		var fc: Vector3 = _face_centers[faces[i]]
		var w: Vector3 = (fc - n * n.dot(fc)).normalized()
		var ang: float = atan2(w.dot(axis_y), w.dot(axis_x))
		pairs[i] = Vector2(ang, float(faces[i]))

	pairs.sort()

	var out: PackedInt32Array = PackedInt32Array()
	out.resize(pairs.size())
	for i in range(pairs.size()):
		out[i] = int(round(pairs[i].y))
	return out

# ------------------------------ Picking ----------------------------------

func _find_cell_by_direction(dir_unit: Vector3) -> int:
	var id: int = -1
	if _last_id >= 0 and _last_id < _verts.size():
		id = _last_id
	else:
		var best_d: float = -1.0
		for i in range(_verts.size()):
			var d: float = dir_unit.dot(_verts[i])
			if d > best_d:
				best_d = d
				id = i
		_last_id = id
		return id

	var improved: bool = true
	var iter: int = 0
	while improved and iter < 64:
		improved = false
		var best_id: int = id
		var best_dot: float = dir_unit.dot(_verts[id])
		for nb in _nbrs[id]:
			var d: float = dir_unit.dot(_verts[nb])
			if d > best_dot:
				best_dot = d
				best_id = nb
		if best_id != id:
			id = best_id
			improved = true
		iter += 1
	_last_id = id
	return id

static func _intersect_ray_sphere(
	ro: Vector3,
	rd: Vector3,
	center: Vector3,
	r: float
) -> HitResult:
	var res: HitResult = HitResult.new()
	var oc: Vector3 = ro - center
	var a: float = rd.dot(rd)
	var b: float = 2.0 * oc.dot(rd)
	var c: float = oc.dot(oc) - r * r
	var disc: float = b * b - 4.0 * a * c
	if disc < 0.0:
		return res
	var sqrt_disc: float = sqrt(disc)
	var t0: float = (-b - sqrt_disc) / (2.0 * a)
	var t1: float = (-b + sqrt_disc) / (2.0 * a)
	var t: float = t0 if t0 > 0.0 else t1
	if t <= 0.0:
		return res
	res.success = true
	res.position = ro + rd * t
	return res

func _get_camera() -> Camera3D:
	if camera_path == NodePath():
		return null
	var n: Node = get_node_or_null(camera_path)
	if n == null:
		return null
	if n is Camera3D:
		return n as Camera3D
	return null

# ------------------------------ Drawing ----------------------------------

func _ensure_draw_nodes_and_materials() -> void:
	if _cell_mi == null:
		_cell_mi = MeshInstance3D.new()
		add_child(_cell_mi)
		if Engine.is_editor_hint():
			_cell_mi.owner = get_tree().edited_scene_root
	if _grid_mi == null:
		_grid_mi = MeshInstance3D.new()
		add_child(_grid_mi)
		if Engine.is_editor_hint():
			_grid_mi.owner = get_tree().edited_scene_root
	if _hover_mi == null:
		_hover_mi = MeshInstance3D.new()
		add_child(_hover_mi)
		if Engine.is_editor_hint():
			_hover_mi.owner = get_tree().edited_scene_root

	# Create cell materials (opaque + transparent variants)
	if _cell_mat_opaque == null or _cell_mat_transparent == null:
		_recreate_cell_materials()

	# Grid material (unshaded vertex color)
	if _grid_mat == null:
		_grid_mat = ShaderMaterial.new()
		_grid_mat.shader = _make_vertex_color_unshaded_shader()
		_grid_mi.material_override = _grid_mat

	# Hover material (overlay)
	if _hover_mat == null:
		_hover_mat = ShaderMaterial.new()
		_hover_mat.shader = _make_hover_overlay_shader()
		_hover_mi.material_override = _hover_mat

	_refresh_cell_material_opacity_mode()

func _recreate_cell_materials() -> void:
	_cell_mat_opaque = ShaderMaterial.new()
	_cell_mat_opaque.shader = _make_cell_shader(false, _shaded_cells)
	_cell_mat_opaque.set("shader_parameter/u_opacity", _cell_opacity)

	_cell_mat_transparent = ShaderMaterial.new()
	_cell_mat_transparent.shader = _make_cell_shader(true, _shaded_cells)
	_cell_mat_transparent.set("shader_parameter/u_opacity", _cell_opacity)

	# Set one now; final selection happens in _refresh_cell_material_opacity_mode
	_cell_mi.material_override = _cell_mat_opaque

func _make_cell_shader(transparent: bool, shaded: bool) -> Shader:
	var code := ""
	code += "shader_type spatial;\n"
	var rm := "cull_disabled"
	if transparent:
		rm += ", blend_mix, depth_draw_alpha_prepass"
	if not shaded:
		rm += ", unshaded"
	code += "render_mode %s;\n" % rm
	code += "uniform float u_opacity = 1.0;\n"
	code += "void fragment() {\n"
	code += "    ALBEDO = COLOR.rgb;\n"
	if transparent:
		code += "    ALPHA = COLOR.a * u_opacity;\n"
	code += "}\n"
	var sh := Shader.new()
	sh.code = code
	return sh

func _make_vertex_color_unshaded_shader() -> Shader:
	var code := ""
	code += "shader_type spatial;\n"
	code += "render_mode unshaded, cull_disabled;\n"
	code += "void fragment() {\n"
	code += "    ALBEDO = COLOR.rgb;\n"
	code += "    ALPHA = COLOR.a;\n"
	code += "}\n"
	var sh := Shader.new()
	sh.code = code
	return sh

func _make_hover_overlay_shader() -> Shader:
	var code := ""
	code += "shader_type spatial;\n"
	code += "render_mode unshaded, cull_disabled, blend_add, "
	code += "depth_draw_never;\n"
	code += "void fragment() {\n"
	code += "    ALBEDO = COLOR.rgb;\n"
	code += "    ALPHA = COLOR.a;\n"
	code += "}\n"
	var sh := Shader.new()
	sh.code = code
	return sh

func _refresh_cell_material_opacity_mode() -> void:
	if _cell_mi == null:
		return
	var use_transparent := _cell_opacity < 0.999 or _any_cell_has_alpha_lt1()
	_cell_mi.material_override = (
		_cell_mat_transparent if use_transparent else _cell_mat_opaque
	)
	if _cell_mat_opaque != null:
		_cell_mat_opaque.set("shader_parameter/u_opacity", _cell_opacity)
	if _cell_mat_transparent != null:
		_cell_mat_transparent.set("shader_parameter/u_opacity", _cell_opacity)

func _any_cell_has_alpha_lt1() -> bool:
	for i in range(_cells.size()):
		if _cells[i].color.a < 0.999:
			return true
	return false

func _apply_radius_scale() -> void:
	# Geometry is authored at unit radius; scale the node instead of rebuilding.
	scale = Vector3.ONE * _radius

func _update_draws() -> void:
	if draw_grid:
		_build_grid_mesh()
	else:
		if _grid_mi != null:
			_grid_mi.mesh = null
	_update_hover_mesh()

func _build_grid_mesh() -> void:
	if not draw_grid or _grid_mi == null:
		if _grid_mi != null:
			_grid_mi.mesh = null
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.set_color(grid_color)

	var edge_to_faces: Dictionary = {}
	for fi in range(0, _faces.size(), 3):
		var a: int = _faces[fi]
		var b: int = _faces[fi + 1]
		var c: int = _faces[fi + 2]
		_acc_edge(edge_to_faces, a, b, fi / 3)
		_acc_edge(edge_to_faces, b, c, fi / 3)
		_acc_edge(edge_to_faces, c, a, fi / 3)

	var keys: Array = edge_to_faces.keys()
	for k in keys:
		var arr: PackedInt32Array = edge_to_faces[k]
		if arr.size() != 2:
			continue
		# Author at unit radius; node scale applies 'radius'
		var p0: Vector3 = _face_centers[arr[0]]
		var p1: Vector3 = _face_centers[arr[1]]
		st.add_vertex(p0)
		st.add_vertex(p1)

	st.index()
	_grid_mi.mesh = st.commit()

func _acc_edge(dict: Dictionary, i: int, j: int, fidx: int) -> void:
	var a: int = i
	var b: int = j
	if a > b:
		var t: int = a
		a = b
		b = t
	var key: int = int((int(a) << 32) | int(b))
	if not dict.has(key):
		dict[key] = PackedInt32Array()
	var arr: PackedInt32Array = dict[key]
	if arr.size() < 2:
		arr.append(fidx)
		dict[key] = arr

func _build_cell_mesh() -> void:
	if not draw_cells or _cell_mi == null or _cells.size() == 0:
		if _cell_mi != null:
			_cell_mi.mesh = null
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for ci in range(_cells.size()):
		var cell: Cell = _cells[ci]
		var col: Color = cell.color
		var cdir: Vector3 = cell.center_unit
		var c0: Vector3 = cdir * (1.0 + cell_lift_ratio)

		var poly: PackedVector3Array = cell.polygon
		if poly.size() < 3:
			continue

		for i in range(poly.size()):
			var j: int = (i + 1) % poly.size()
			var adir: Vector3 = poly[i]
			var bdir: Vector3 = poly[j]
			var a: Vector3 = adir * (1.0 + cell_lift_ratio)
			var b: Vector3 = bdir * (1.0 + cell_lift_ratio)

			# Center vertex
			st.set_color(col)
			st.set_normal(cdir) # sphere normal
			st.add_vertex(c0)

			# Edge A
			st.set_color(col)
			st.set_normal(adir)
			st.add_vertex(a)

			# Edge B
			st.set_color(col)
			st.set_normal(bdir)
			st.add_vertex(b)

	st.index()
	_cell_mi.mesh = st.commit()

func _update_hover_mesh() -> void:
	if _hover_mi == null:
		return
	if (not draw_hover) or (_hovered_id == -1):
		_hover_mi.mesh = null
		return

	var cell: Cell = _cells[_hovered_id]
	var poly: PackedVector3Array = cell.polygon
	if poly.size() < 3:
		_hover_mi.mesh = null
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(hover_color)

	var c0: Vector3 = cell.center_unit * (1.0 + hover_lift_ratio)
	for i in range(poly.size()):
		var j: int = (i + 1) % poly.size()
		var a: Vector3 = poly[i] * (1.0 + hover_lift_ratio)
		var b: Vector3 = poly[j] * (1.0 + hover_lift_ratio)
		st.add_vertex(c0)
		st.add_vertex(a)
		st.add_vertex(b)

	st.index()
	_hover_mi.mesh = st.commit()

# -------------------------- Texture projection ---------------------------

func _update_cell_colors_from_texture() -> void:
	if _cells.size() == 0:
		return

	if _earth_texture == null:
		# Fallback gradient by latitude
		for i in range(_cells.size()):
			var d: Vector3 = _cells[i].center_unit
			var t: float = (d.y * 0.5) + 0.5
			_cells[i].color = default_cell_color.lerp(
				Color(0.1, 0.8, 0.2), clamp(t, 0.0, 1.0)
			)
		return

	var img: Image = _earth_texture.get_image()
	if img == null or img.is_empty():
		push_warning("earth_texture has no image data.")
		for i in range(_cells.size()):
			_cells[i].color = default_cell_color
		return

	if img.is_compressed():
		var err: int = img.decompress()
		if err != OK:
			push_warning("Failed to decompress earth_texture; using defaults.")
			for i in range(_cells.size()):
				_cells[i].color = default_cell_color
			return
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)

	var yaw: float = deg_to_rad(texture_u_rotation_degrees)
	for i in range(_cells.size()):
		var dir: Vector3 = _cells[i].center_unit
		var uv: Vector2 = _dir_to_uv(dir, yaw, texture_flip_v)
		var col: Color = (
			_sample_image_bilinear(img, uv.x, uv.y)
			if sample_bilinear
			else _sample_image_nearest(img, uv.x, uv.y)
		)
		col.a = 1.0
		_cells[i].color = col

func _dir_to_uv(d: Vector3, yaw: float, flip_v: bool) -> Vector2:
	var lon: float = atan2(d.x, d.z) + yaw
	var u: float = 0.5 + lon / TAU
	u = u - floor(u)
	var v: float = 0.5 - asin(clamp(d.y, -1.0, 1.0)) / PI
	if flip_v:
		v = 1.0 - v
	v = clamp(v, 0.0, 1.0)
	return Vector2(u, v)

func _sample_image_nearest(img: Image, u: float, v: float) -> Color:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var x: int = int(round(u * float(w - 1)))
	var y: int = int(round(v * float(h - 1)))
	x = int(posmod(x, w))
	y = clamp(y, 0, h - 1)
	return img.get_pixel(x, y)

func _sample_image_bilinear(img: Image, u: float, v: float) -> Color:
	var w: int = img.get_width()
	var h: int = img.get_height()

	var fx: float = u * float(w) - 0.5
	var fy: float = v * float(h) - 0.5

	var x0: int = int(floor(fx))
	var y0: int = int(floor(fy))
	var x1: int = x0 + 1
	var y1: int = y0 + 1

	var tx: float = fx - float(x0)
	var ty: float = fy - float(y0)

	x0 = int(posmod(x0, w))
	x1 = int(posmod(x1, w))
	y0 = clamp(y0, 0, h - 1)
	y1 = clamp(y1, 0, h - 1)

	var c00: Color = img.get_pixel(x0, y0)
	var c10: Color = img.get_pixel(x1, y0)
	var c01: Color = img.get_pixel(x0, y1)
	var c11: Color = img.get_pixel(x1, y1)

	var cx0: Color = c00.lerp(c10, tx)
	var cx1: Color = c01.lerp(c11, tx)
	return cx0.lerp(cx1, ty)
