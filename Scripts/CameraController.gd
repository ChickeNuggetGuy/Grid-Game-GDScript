extends PhantomCamera3D
class_name CameraController

static var instance: CameraController

@export var transposer: Node3D
@export var move_speed: float = 10.0
@export var zoom_speed: float = 50.0
@export var rotation_speed: float = 2.0
@export var min_transposer_height: float = 0 

func _init() -> void:
	instance = self

func _ready() -> void:
	call_deferred("setup")

func setup() -> void:
	UnitManager.connect("UnitSelected", _unitmanager_unitselected)

func _exit_tree() -> void:
	# Optional: disconnect if you want to clean up manually
	UnitManager.instance.disconnect("SelectedUnitChanged", self,
	 "_on_unit_manager_selected_unit")

func _unitmanager_unitselected(newUnit : GridObject, _oldUnit : GridObject):
	quick_switch_target(newUnit)

func quick_switch_target(target: Node3D) -> void:
	if target:
		transposer.position = target.position

func _physics_process(delta: float) -> void:
	#if UiManager.blocking_input:
		#return
	#look_at_transposer()
	_transposer_movement(delta)
	_camera_zoom(delta)
	#_transform_rotation(delta)
	_transposer_height(delta)

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

func _transposer_height(delta: float) -> void:
	var spaceState = get_tree().root.world_3d.direct_space_state
	
	# Cast ray from above the transposer to detect ground
	var rayStart: Vector3 = transposer.position + Vector3.UP * 10.0
	var rayLength = 100

	var rqDown = PhysicsRayQueryParameters3D.new()
	rqDown.from = rayStart
	rqDown.to = rayStart + (Vector3.DOWN * rayLength)
	rqDown.collide_with_bodies = true
	rqDown.collide_with_areas = false
	rqDown.collision_mask = PhysicsLayersUtility.TERRAIN

	var rDown = spaceState.intersect_ray(rqDown)

	if rDown:
		var target_y_position = rDown.position.y 
		var current_y_position = transposer.position.y
		# Move directly toward target with smoothing, but respect minimum height
		var desired_height = max(target_y_position, min_transposer_height)
		transposer.position.y = lerp(current_y_position, desired_height, min(delta * 5.0, 1.0))
	else:
		# Cast ray upward to check if transposer is under terrain
		var rqUp = PhysicsRayQueryParameters3D.new()
		rqUp.from = transposer.position
		rqUp.to = transposer.position + (Vector3.UP * rayLength)
		rqUp.collide_with_bodies = true
		rqUp.collide_with_areas = false
		rqUp.collision_mask = PhysicsLayersUtility.TERRAIN

		var rUp = spaceState.intersect_ray(rqUp)
		
		if rUp:
			# If upward raycast hits terrain, move transposer up quickly
			transposer.position.y += delta * 20.0
		else:
			# Gradually move down but never below minimum height
			var new_y = transposer.position.y - delta * 2.0
			transposer.position.y = max(new_y, min_transposer_height)

func _camera_zoom(delta: float) -> void:
	var zoom_dir := 0
	if Input.is_action_just_pressed("Camera_Scroll_Up"):
		zoom_dir -= 1
	if Input.is_action_just_pressed("Camera_Scroll_Down"):
		zoom_dir += 1

	if zoom_dir != 0 and (self.position.y >= transposer.position.y or zoom_dir > 0):
		# Calculate the change amount
		var change = zoom_dir * zoom_speed * delta
		
		# Apply changes with proper clamping
		follow_offset.z = clampf(follow_offset.z + change, 0, 20)
		follow_offset.y = clampf(follow_offset.y + change, transposer.position.y, 20)

func _transform_rotation(delta: float) -> void:
	var rot_dir := 0
	if Input.is_action_pressed("Camera_Rotate_Right"):
		rot_dir += 1
	if Input.is_action_pressed("Camera_Rotate_Left"):
		rot_dir -= 1

	if rot_dir != 0:
		transposer.rotate_y(delta * rot_dir * rotation_speed)

#func _on_unit_manager_selected_unit() -> void:
	#quick_switch_target(UnitManager.instance.selected_unit)
