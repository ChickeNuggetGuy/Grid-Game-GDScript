extends Camera3D
class_name GlobeCameraController


@export var globe_radius: float = 100.0
@export var center: Vector3 = Vector3.ZERO


@export var altitude: float = 60.0
@export var min_altitude: float = 5.0
@export var max_altitude: float = 1500.0


enum RotationMode { TRACKBALL, SPHERICAL }
@export var rotation_mode: int = RotationMode.TRACKBALL


@export var rotate_button: MouseButton = MOUSE_BUTTON_LEFT
@export var pan_button: MouseButton = MOUSE_BUTTON_RIGHT


@export var rotate_sensitivity: float = 1.0
@export var pan_sensitivity: float = 1.0  
@export var zoom_factor_per_step: float = 1.10
@export var invert_y: bool = false


@export var keep_world_up: bool = true

var _yaw: float = 0.0
var _pitch: float = 0.3 


var _cam_vec: Vector3 = Vector3(0, 0, 1) 
var _up_vec: Vector3 = Vector3.UP 

var _is_rotating: bool = false
var _is_panning: bool = false

var _last_mouse_pos: Vector2 = Vector2.ZERO
var _arcball_last_v: Vector3 = Vector3.ZERO 


var _pan_anchor_n: Vector3 = Vector3.ZERO
const _EPS: float = 1e-5

func _ready() -> void:
	min_altitude =1
	altitude = clamp(altitude, min_altitude, max_altitude)
	var dist := globe_radius + altitude
	
	_cam_vec = Vector3(0.0, 0.0, dist)
	_up_vec = Vector3.UP
	_update_transform(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		_handle_mouse_button(mb)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_handle_mouse_motion(mm)

func _handle_mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index == rotate_button:
		if mb.pressed:
			_is_rotating = true
			_last_mouse_pos = mb.position
			if rotation_mode == RotationMode.TRACKBALL:
				_arcball_last_v = _screen_to_arcball(mb.position)
		else:
			_is_rotating = false

	elif mb.button_index == pan_button:
		if mb.pressed:
			_is_panning = true
			_last_mouse_pos = mb.position
			var n: Variant = _project_mouse_to_sphere_normal(mb.position)
			if n != null:
				_pan_anchor_n = n as Vector3
		else:
			_is_panning = false

	if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
		_zoom(1.0 / zoom_factor_per_step)
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
		_zoom(zoom_factor_per_step)

func _handle_mouse_motion(mm: InputEventMouseMotion) -> void:
	if not (_is_rotating or _is_panning):
		return

	if _is_rotating:
		if rotation_mode == RotationMode.TRACKBALL:
			_trackball_rotate(mm.position)
		else:
			_spherical_rotate(mm.relative)

	if _is_panning:
		_pan_grab(mm.position)

	_last_mouse_pos = mm.position
	_update_transform(false)

func _zoom(mult: float) -> void:
	var d := globe_radius + altitude
	d *= mult
	var new_alt : float = clamp(d - globe_radius, min_altitude, max_altitude)
	altitude = new_alt
	var dist := globe_radius + altitude
	_cam_vec = _cam_vec.normalized() * dist
	_update_transform(false)

func _update_transform(force_reset_up: bool) -> void:
	global_position = center + _cam_vec

	var forward := (center - global_position).normalized()
	var up_dir := Vector3.UP
	if keep_world_up:
		up_dir = _choose_nonparallel_up(forward, Vector3.UP)
	else:
		if force_reset_up:
			_up_vec = Vector3.UP
		_up_vec = _choose_nonparallel_up(forward, _up_vec)
		up_dir = _up_vec.normalized()

	look_at(center, up_dir)


func _trackball_rotate(screen_pos: Vector2) -> void:
	var v2 := _screen_to_arcball(screen_pos)
	var v1 := _arcball_last_v
	_arcball_last_v = v2

	var axis_cam := v1.cross(v2)
	var dot : float = clamp(v1.dot(v2), -1.0, 1.0)
	var angle := acos(dot) * rotate_sensitivity
	if axis_cam.length() < _EPS or angle < _EPS:
		return

	var axis_world := (global_transform.basis * axis_cam).normalized()
	var q := Quaternion(axis_world, angle)
	_apply_rotation(q)

func _screen_to_arcball(p: Vector2) -> Vector3:
	var viewport_size := get_viewport().get_visible_rect().size
	var s := float(min(viewport_size.x, viewport_size.y))
	if s <= 0.0:
		return Vector3.ZERO

	var x := (2.0 * p.x - float(viewport_size.x)) / s
	var y := (float(viewport_size.y) - 2.0 * p.y) / s 
	var r2 := x * x + y * y
	var z := 0.0
	if r2 <= 1.0:
		z = sqrt(1.0 - r2)
	else:
		var inv_len := 1.0 / sqrt(r2)
		x *= inv_len
		y *= inv_len
		z = 0.0
	return Vector3(x, y, z).normalized()


func _spherical_rotate(relative: Vector2) -> void:
	var dx := relative.x
	var dy := relative.y
	var y_invert := (-1.0 if invert_y else 1.0)

	_yaw -= dx * 0.005 * rotate_sensitivity
	_pitch -= dy * 0.005 * rotate_sensitivity * y_invert

	var limit := 0.5 * PI - 0.001
	_pitch = clamp(_pitch, -limit, limit)

	var dist := globe_radius + altitude
	var cp := cos(_pitch)
	var sp := sin(_pitch)
	var cy := cos(_yaw)
	var sy := sin(_yaw)

	_cam_vec = Vector3(sy * cp, sp, cy * cp) * dist

	if not keep_world_up:
		_up_vec = Vector3.UP

func _pan_grab(screen_pos: Vector2) -> void:
	var n_cur_v: Variant = _project_mouse_to_sphere_normal(screen_pos)
	if n_cur_v == null:
		return

	var n_cur := n_cur_v as Vector3
	var q := _rotation_between(n_cur, _pan_anchor_n)

	var s : float = clamp(pan_sensitivity, 0.01, 1.0)
	var q_smoothed := Quaternion().slerp(q, s)
	_apply_rotation(q_smoothed)

func _project_mouse_to_sphere_normal(p: Vector2) -> Variant:
	var ro := project_ray_origin(p)
	var rd := project_ray_normal(p).normalized()
	var hit: Variant = _ray_sphere_hit(ro, rd, center, globe_radius)
	if hit == null:
		return null
	return ((hit as Vector3) - center).normalized()

func _ray_sphere_hit(
	ro: Vector3,
	rd: Vector3,
	c: Vector3,
	r: float
) -> Variant:
	var oc := ro - c
	var b := 2.0 * oc.dot(rd)
	var cval := oc.dot(oc) - r * r
	var disc := b * b - 4.0 * cval
	if disc < 0.0:
		return null
	var sqrt_d := sqrt(disc)
	var t1 := (-b - sqrt_d) * 0.5
	var t2 := (-b + sqrt_d) * 0.5
	var t := 0.0
	if t1 >= 0.0:
		t = t1
	elif t2 >= 0.0:
		t = t2
	else:
		return null
	return ro + rd * t



func _apply_rotation(q: Quaternion) -> void:
	_cam_vec = q * _cam_vec
	if not keep_world_up:
		_up_vec = q * _up_vec
	else:
		pass

func _choose_nonparallel_up(forward: Vector3, up_hint: Vector3) -> Vector3:
	var up := up_hint
	if abs(forward.dot(up)) > 0.999:
		up = Vector3.FORWARD
		if abs(forward.dot(up)) > 0.999:
			up = Vector3.RIGHT
	return up

func _rotation_between(a: Vector3, b: Vector3) -> Quaternion:
	var v := a.cross(b)
	var d : float = clamp(a.dot(b), -1.0, 1.0)
	if v.length() < _EPS:
		if d < 0.0:
			var axis := a.cross(
				Vector3.UP if abs(a.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
			).normalized()
			return Quaternion(axis, PI)
		else:
			return Quaternion()
	var angle := acos(d)
	return Quaternion(v.normalized(), angle)


func focus_lat_lon(
	lat_deg: float,
	lon_deg: float,
	override_altitude: float = -INF
) -> void:
	var lat := deg_to_rad(lat_deg)
	var lon := deg_to_rad(lon_deg)
	var n := _latlon_to_dir(lat, lon) 

	if is_finite(override_altitude):
		altitude = clamp(override_altitude, min_altitude, max_altitude)
	var dist := globe_radius + altitude
	_cam_vec = n * dist
	if rotation_mode == RotationMode.SPHERICAL:
		_pitch = asin(n.y)
		_yaw = atan2(n.x, n.z)
	_update_transform(true)

func current_lat_lon_deg() -> Vector2:
	var n := _cam_vec.normalized()
	var lat := asin(n.y)
	var lon := atan2(n.x, n.z)
	return Vector2(rad_to_deg(lat), rad_to_deg(lon))

func _latlon_to_dir(lat: float, lon: float) -> Vector3:
	var cl := cos(lat)
	return Vector3(sin(lon) * cl, sin(lat), cos(lon) * cl).normalized()
