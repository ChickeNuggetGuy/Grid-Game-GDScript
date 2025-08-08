extends Camera3D
class_name GlobeCameraController

# A pole-safe globe camera controller for a sphere centered at `center`.
# Default controls:
#   - Left mouse: orbit (TRACKBALL or SPHERICAL mode)
#   - Right mouse: grab/pan the globe (keeps the grabbed surface point under
#     the cursor)
#   - Mouse wheel: zoom in/out (altitude above the globe surface)

@export var globe_radius: float = 100.0
@export var center: Vector3 = Vector3.ZERO

# Altitude above the surface, i.e., distance = globe_radius + altitude.
@export var altitude: float = 60.0
@export var min_altitude: float = 5.0
@export var max_altitude: float = 1500.0

# Rotation mode
enum RotationMode { TRACKBALL, SPHERICAL }
@export var rotation_mode: int = RotationMode.TRACKBALL

# Controls and sensitivities
@export var rotate_button: MouseButton = MOUSE_BUTTON_LEFT
@export var pan_button: MouseButton = MOUSE_BUTTON_RIGHT

# Sensitivities
@export var rotate_sensitivity: float = 1.0
@export var pan_sensitivity: float = 1.0  # 0..1 for smoothing during grab-pan
@export var zoom_factor_per_step: float = 1.10
@export var invert_y: bool = false

# Keep world-up to avoid roll. If disabled, roll is allowed and preserved.
@export var keep_world_up: bool = true

# Spherical mode internals (ignored in TRACKBALL)
var _yaw: float = 0.0
var _pitch: float = 0.3  # radians; clamped to near ±PI/2

# Internal state
var _cam_vec: Vector3 = Vector3(0, 0, 1)  # from center to camera position
var _up_vec: Vector3 = Vector3.UP  # only used if keep_world_up == false

var _is_rotating: bool = false
var _is_panning: bool = false

var _last_mouse_pos: Vector2 = Vector2.ZERO
var _arcball_last_v: Vector3 = Vector3.ZERO  # in camera space, unit sphere

# Pan "grab" anchor (unit normal on the sphere)
var _pan_anchor_n: Vector3 = Vector3.ZERO
const _EPS: float = 1e-5

func _ready() -> void:
	altitude = clamp(altitude, min_altitude, max_altitude)
	var dist := globe_radius + altitude
	# Default camera along +Z looking at center
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

	# Zoom in/out with wheel
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
	# Set camera position and look at center with stable 'up'.
	global_position = center + _cam_vec

	var forward := (center - global_position).normalized()
	var up_dir := Vector3.UP
	if keep_world_up:
		up_dir = _choose_nonparallel_up(forward, Vector3.UP)
	else:
		if force_reset_up:
			_up_vec = Vector3.UP
		# Ensure up is not parallel to forward
		_up_vec = _choose_nonparallel_up(forward, _up_vec)
		up_dir = _up_vec.normalized()

	look_at(center, up_dir)

# -------------------- TRACKBALL ROTATION --------------------

func _trackball_rotate(screen_pos: Vector2) -> void:
	var v2 := _screen_to_arcball(screen_pos)
	var v1 := _arcball_last_v
	_arcball_last_v = v2

	var axis_cam := v1.cross(v2)
	var dot : float = clamp(v1.dot(v2), -1.0, 1.0)
	var angle := acos(dot) * rotate_sensitivity
	if axis_cam.length() < _EPS or angle < _EPS:
		return

	# Convert axis to world space
	var axis_world := (global_transform.basis * axis_cam).normalized()
	var q := Quaternion(axis_world, angle)
	_apply_rotation(q)

func _screen_to_arcball(p: Vector2) -> Vector3:
	# Map screen to unit hemisphere in camera space
	var size := get_viewport().get_visible_rect().size
	var s := float(min(size.x, size.y))
	if s <= 0.0:
		return Vector3.ZERO

	var x := (2.0 * p.x - float(size.x)) / s
	var y := (float(size.y) - 2.0 * p.y) / s  # y up
	var r2 := x * x + y * y
	var z := 0.0
	if r2 <= 1.0:
		z = sqrt(1.0 - r2)
	else:
		# Outside sphere: project onto hyperbolic sheet (normalize)
		var inv_len := 1.0 / sqrt(r2)
		x *= inv_len
		y *= inv_len
		z = 0.0
	return Vector3(x, y, z).normalized()

# -------------------- SPHERICAL ROTATION --------------------

func _spherical_rotate(relative: Vector2) -> void:
	var dx := relative.x
	var dy := relative.y
	var y_invert := (-1.0 if invert_y else 1.0)

	_yaw -= dx * 0.005 * rotate_sensitivity
	_pitch -= dy * 0.005 * rotate_sensitivity * y_invert

	# Clamp pitch just short of the poles to stay pole-safe
	var limit := 0.5 * PI - 0.001
	_pitch = clamp(_pitch, -limit, limit)

	var dist := globe_radius + altitude
	var cp := cos(_pitch)
	var sp := sin(_pitch)
	var cy := cos(_yaw)
	var sy := sin(_yaw)

	# Camera vector from center to camera
	# x = sin(yaw) * cos(pitch)
	# y = sin(pitch)
	# z = cos(yaw) * cos(pitch)
	_cam_vec = Vector3(sy * cp, sp, cy * cp) * dist

	if not keep_world_up:
		_up_vec = Vector3.UP

# -------------------- PAN BY GRABBING THE GLOBE --------------------

func _pan_grab(screen_pos: Vector2) -> void:
	# Keep the originally grabbed surface point under the cursor.
	var n_cur_v: Variant = _project_mouse_to_sphere_normal(screen_pos)
	if n_cur_v == null:
		return

	var n_cur := n_cur_v as Vector3
	var q := _rotation_between(n_cur, _pan_anchor_n)

	# Optional smoothing via pan_sensitivity (0..1). 1.0 keeps exact grab.
	var s : float = clamp(pan_sensitivity, 0.01, 1.0)
	var q_smoothed := Quaternion().slerp(q, s)
	_apply_rotation(q_smoothed)

func _project_mouse_to_sphere_normal(p: Vector2) -> Variant:
	# Ray-sphere intersection. Returns surface normal (unit) or null.
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
	# Solve |ro + t*rd - c|^2 = r^2 for smallest t >= 0
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

# -------------------- COMMON ROTATION APPLY --------------------

func _apply_rotation(q: Quaternion) -> void:
	_cam_vec = q * _cam_vec
	if not keep_world_up:
		_up_vec = q * _up_vec
	else:
		# keep_world_up => do not rotate the up vector
		pass

func _choose_nonparallel_up(forward: Vector3, up_hint: Vector3) -> Vector3:
	var up := up_hint
	if abs(forward.dot(up)) > 0.999:
		# If forward nearly parallel to up, pick an alternate up
		up = Vector3.FORWARD
		if abs(forward.dot(up)) > 0.999:
			up = Vector3.RIGHT
	return up

func _rotation_between(a: Vector3, b: Vector3) -> Quaternion:
	var v := a.cross(b)
	var d : float = clamp(a.dot(b), -1.0, 1.0)
	if v.length() < _EPS:
		if d < 0.0:
			# 180-degree rotation: pick any orthogonal axis
			var axis := a.cross(
				Vector3.UP if abs(a.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
			).normalized()
			return Quaternion(axis, PI)
		else:
			return Quaternion()  # identity
	var angle := acos(d)
	return Quaternion(v.normalized(), angle)

# -------------------- LAT/LON HELPERS --------------------

# Set the camera so that the view center points to (lat, lon) on the globe.
# Latitude in degrees [-90, 90], longitude in degrees [-180, 180].
# The camera keeps current altitude unless override_altitude is provided.
func focus_lat_lon(
	lat_deg: float,
	lon_deg: float,
	override_altitude: float = -INF
) -> void:
	var lat := deg_to_rad(lat_deg)
	var lon := deg_to_rad(lon_deg)
	var n := _latlon_to_dir(lat, lon)  # unit normal from center to surface

	if is_finite(override_altitude):
		altitude = clamp(override_altitude, min_altitude, max_altitude)
	var dist := globe_radius + altitude
	_cam_vec = n * dist
	if rotation_mode == RotationMode.SPHERICAL:
		# Keep spherical angles consistent with the new orientation
		_pitch = asin(n.y)
		_yaw = atan2(n.x, n.z)
	_update_transform(true)

# Returns the lat/lon of the point at the view center (under the crosshair).
func current_lat_lon_deg() -> Vector2:
	var n := _cam_vec.normalized()
	var lat := asin(n.y)
	var lon := atan2(n.x, n.z)
	return Vector2(rad_to_deg(lat), rad_to_deg(lon))

func _latlon_to_dir(lat: float, lon: float) -> Vector3:
	# x = sin(lon) * cos(lat)
	# y = sin(lat)
	# z = cos(lon) * cos(lat)
	var cl := cos(lat)
	return Vector3(sin(lon) * cl, sin(lat), cos(lon) * cl).normalized()
