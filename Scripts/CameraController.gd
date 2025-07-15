extends Camera3D
class_name CameraController

static var instance: CameraController

@export var transposer: Node3D
@export var look_at_offset: Vector3 = Vector3.ZERO
@export var move_speed: float = 10.0
@export var zoom_speed: float = 50.0
@export var rotation_speed: float = 2.0

func _ready() -> void:
	instance = self
	#call_deferred("setup")

#func setup() -> void:
	#UnitManager.instance.connect(
		#"SelectedUnitChanged",
		#self,
		#"_on_unit_manager_selected_unit"
	#)

func _exit_tree() -> void:
	# Optional: disconnect if you want to clean up manually
	# UnitManager.instance.disconnect("SelectedUnitChanged", self,
	# "_on_unit_manager_selected_unit")
	pass

func look_at_transposer() -> void:
	look_at(transposer.position + look_at_offset, Vector3.UP)

func quick_switch_target(target: Node3D) -> void:
	if target:
		transposer.position = target.position

#func _process(delta: float) -> void:
	#if Input.is_key_pressed(Key.F):
		#quick_switch_target(UnitManager.instance.selected_unit)

func _physics_process(delta: float) -> void:
	look_at_transposer()
	_transposer_movement(delta)
	_camera_zoom(delta)
	_transform_rotation(delta)

func _transposer_movement(delta: float) -> void:
	var move_dir := Vector3.ZERO
	if Input.is_action_pressed("Camera_Right"):
		move_dir += transposer.basis.x * delta
	if Input.is_action_pressed("Camera_Left"):
		move_dir -= transposer.basis.x * delta
	if Input.is_action_pressed("Camera_Up"):
		move_dir -= transposer.basis.z * delta
	if Input.is_action_pressed("Camera_Down"):
		move_dir += transposer.basis.z * delta

	transposer.position += move_dir * move_speed

func _camera_zoom(delta: float) -> void:
	var zoom_dir := 0
	if Input.is_action_just_pressed("Camera_Scroll_Up"):
		zoom_dir -= 1
	if Input.is_action_just_pressed("Camera_Scroll_Down"):
		zoom_dir += 1

	if zoom_dir != 0:
		position.y += zoom_dir * zoom_speed * delta

func _transform_rotation(delta: float) -> void:
	var rot_dir := 0
	if Input.is_action_pressed("Camera_Rotate_Right"):
		rot_dir -= 1
	if Input.is_action_pressed("Camera_Rotate_Left"):
		rot_dir += 1

	if rot_dir != 0:
		transposer.rotate_y(delta * rot_dir * rotation_speed)

#func _on_unit_manager_selected_unit() -> void:
	#quick_switch_target(UnitManager.instance.selected_unit)
