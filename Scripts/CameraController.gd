extends Camera3D
class_name CameraController

static var instance: CameraController

@export var transposer: Node3D
@export var move_speed: float = 10.0
@export var zoom_speed: float = 50.0
@export var rotation_speed: float = 2.0
@export var min_transposer_height: float = 0 

@export var phantom_cameras : Dictionary[String, PhantomCamera3D]

var current_camera : PhantomCamera3D
func _init() -> void:
	instance = self

func _ready() -> void:
	call_deferred("setup")

func setup() -> void:
	UnitManager.Instance.connect("UnitSelected", _unitmanager_unitselected)
	
	UnitActionManager.Instance.connect("action_execution_started", UnitActionManager_action_execution_started)
	UnitActionManager.Instance.connect("action_execution_finished", UnitActionManager_action_execution_finished)

func _exit_tree() -> void:
	# Optional: disconnect if you want to clean up manually
	UnitManager.Instance.disconnect("SelectedUnitChanged",Callable.create(self,
	 "_on_unit_manager_selected_unit"))

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

func _unhandled_input(event):
	if UIManager.Instance.blocking_input:
		return
	
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_F:
			quick_switch_target(UnitManager.Instance.selectedUnit)

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
	
	var main_camera  = phantom_cameras["main"]
	var zoom_dir := 0
	if Input.is_action_just_pressed("Camera_Scroll_Up"):
		zoom_dir -= 1
	if Input.is_action_just_pressed("Camera_Scroll_Down"):
		zoom_dir += 1

	if zoom_dir != 0 and (self.position.y >= transposer.position.y or zoom_dir > 0):
		# Calculate the change amount
		var change = zoom_dir * zoom_speed * delta
		
		# Apply changes with proper clamping
		main_camera.follow_offset.z = clampf(main_camera.follow_offset.z + change, 0, 20)
		main_camera.follow_offset.y = clampf(main_camera.follow_offset.y + change, transposer.position.y, 20)

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
	
