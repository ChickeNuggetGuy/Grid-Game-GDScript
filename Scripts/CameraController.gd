extends Manager
class_name CameraController

@export var camera_3d : Camera3D
@export var transposer: Node3D
@export var move_speed: float = 10.0
@export var zoom_speed: float = 50.0
@export var rotation_speed: float = 2.0
@export var min_transposer_height: float = 0 


@export var orbit_yaw_speed_deg: float = 120.0
@export var orbit_pitch_speed_deg: float = 90.0
@export var orbit_min_pitch_deg: float = -5.0
@export var orbit_max_pitch_deg: float = 60.0
@export var orbit_min_distance: float = 3.0
@export var orbit_max_distance: float = 20.0
@export var tilt_step_deg: float = 3.0

var orbit_yaw_deg: float = 0.0
var orbit_pitch_deg: float = 25.0
var orbit_distance: float = 8.0


@export var phantom_cameras : Dictionary[String, PhantomCamera3D]



var current_camera : PhantomCamera3D


func save_data() -> Dictionary:
	var save_dict = {
		"filename" : get_scene_file_path(),
		"parent" : get_parent().get_path(),
	}
	return save_dict


func load_data(data : Dictionary):
	pass

func get_manager_data() -> Dictionary:
	return {}

func _get_manager_name() -> String: return "CameraController"


func _setup_conditions() -> bool: return true


func _setup():
	GameManager.managers["UnitManager"].unit_selected.connect(
		_unitmanager_unitselected
	)

	if phantom_cameras.has("main"):
		var pcam: PhantomCamera3D = phantom_cameras["main"]
		pcam.follow_target = transposer
		pcam.look_at_target = null
		pcam.set_spring_length(orbit_distance)
		pcam.set_third_person_rotation_degrees(
			Vector3(orbit_pitch_deg, orbit_yaw_deg, 0.0)
		)

	execute_complete = true
	setup_completed.emit()
	return


func _execute_conditions() -> bool: return true


func _execute():
	execute_complete = true
	execution_completed.emit()
	pass


func _unitmanager_unitselected(newUnit : GridObject, _oldUnit : GridObject):
	print("_unitmanager_unitselected")
	quick_switch_target(newUnit)

func quick_switch_target(target: Node3D) -> void:
	print("quick_switch_target")
	if target != null:
		transposer.global_position = target.global_position

func _physics_process(delta: float) -> void:

	_transposer_movement(delta)
	_camera_zoom(delta)
	_transform_rotation(delta)
	_transposer_height(delta)

func _unhandled_input(event):
	if not execute_complete: return
	if GameManager.managers["UIManager"] != null and GameManager.managers["UIManager"].blocking_input:
		return
	
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_F:
			quick_switch_target(GameManager.managers["UnitManager"].selectedUnit)

func _transposer_movement(delta: float) -> void:
	var move_dir := Vector3.ZERO

	var yaw_rad := deg_to_rad(orbit_yaw_deg)
	var forward := -Vector3.FORWARD.rotated(Vector3.UP, yaw_rad)
	var right := Vector3.RIGHT.rotated(Vector3.UP, yaw_rad)

	if Input.is_action_pressed("Camera_Right"):
		move_dir += right
	if Input.is_action_pressed("Camera_Left"):
		move_dir -= right
	if Input.is_action_pressed("Camera_Up"):
		move_dir -= forward
	if Input.is_action_pressed("Camera_Down"):
		move_dir += forward

	if move_dir != Vector3.ZERO:
		transposer.position += move_dir.normalized() * move_speed * delta

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
	if not phantom_cameras.has("main"):
		return

	var dir := 0.0
	if Input.is_action_just_pressed("Camera_Scroll_Up"):
		dir -= 1.0
	if Input.is_action_just_pressed("Camera_Scroll_Down"):
		dir += 1.0

	if dir != 0.0:
		orbit_distance = clampf(
			orbit_distance + dir * zoom_speed * delta,
			orbit_min_distance,
			orbit_max_distance
		)
		phantom_cameras["main"].set_spring_length(orbit_distance)


func _transform_rotation(delta: float) -> void:
	var yaw_dir := 0.0
	if Input.is_action_pressed("Camera_Rotate_Right"):
		yaw_dir += 1.0
	if Input.is_action_pressed("Camera_Rotate_Left"):
		yaw_dir -= 1.0

	# Wheel is impulse: use just_pressed for tilt
	var tilt_impulse := 0.0
	if Input.is_action_just_pressed("Camera_Tilt_Up"):
		tilt_impulse += 1.0
	if Input.is_action_just_pressed("Camera_Tilt_Down"):
		tilt_impulse -= 1.0

	if yaw_dir != 0.0:
		orbit_yaw_deg = wrapf(
			orbit_yaw_deg + yaw_dir * orbit_yaw_speed_deg * delta, 0.0, 360.0
		)

	if tilt_impulse != 0.0:
		orbit_pitch_deg = clampf(
			orbit_pitch_deg + tilt_impulse * tilt_step_deg,
			orbit_min_pitch_deg,
			orbit_max_pitch_deg
		)

	if phantom_cameras.has("main") and (yaw_dir != 0.0 or tilt_impulse != 0.0):
		phantom_cameras["main"].set_third_person_rotation_degrees(
			Vector3(orbit_pitch_deg, orbit_yaw_deg, 0.0)
		)


func UnitActionManager_action_execution_started(action_started : BaseActionDefinition, execution_parameters : Dictionary):
	
	if action_started is RangedAttackActionDefinition:
		switch_active_camera("ranged_camera", execution_parameters["unit"], execution_parameters["target_grid_cell"].world_position)


func UnitActionManager_action_execution_finished(action_finished : BaseActionDefinition, execution_parameters : Dictionary):
	
	if action_finished is RangedAttackActionDefinition:
		switch_active_camera("main",execution_parameters["unit"], execution_parameters["target_grid_cell"].world_position)


func switch_active_camera(camera_key,unit : Unit, target_position : Vector3):
	
	if not phantom_cameras.has(camera_key):
		return
	
	if current_camera == phantom_cameras[camera_key]:
		return
	
	if camera_key == "main" :
		current_camera.priority = 0
		current_camera = phantom_cameras[camera_key]
		
		phantom_cameras[camera_key].follow_target = transposer
		phantom_cameras[camera_key].look_at_target = transposer
	else:
		
		var phantom_camera = phantom_cameras[camera_key]
		
		var result = unit.try_get_grid_object_component_by_type("GridObjectWorldTarget")
		
		if result["success"] == false:
			return

		var target_component : GridObjectWorldTarget = result["grid_object_component"]
		var camera_position = target_component.targets["action_camera_position"]
		
		var look_at_node = Node3D.new()
		get_tree().root.add_child(look_at_node)
		look_at_node.global_position = target_position
		phantom_camera.look_at_target = look_at_node
		phantom_camera.follow_offset = Vector3(0,0,0)
		phantom_camera.follow_target = camera_position
		
		
		phantom_cameras[camera_key].priority = 10
		current_camera = phantom_cameras[camera_key]
