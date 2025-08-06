extends Action
class_name RotateAction

var target_direction : Enums.facingDirection
var rotation_direction : String

func _init(parameters : Dictionary) -> void:
	action_name = "Rotate"
	costs = {}
	owner = parameters["unit"]
	target_grid_cell = parameters["target_grid_cell"]
	start_grid_cell = parameters["start_grid_cell"]
	
	# Calculate the actual rotation cost using the proper method
	_calculate_rotation_cost()

func _calculate_rotation_cost() -> void:
	var rotation_info = RotationHelperFunctions.get_rotation_info(
		owner.grid_position_data.direction,
		start_grid_cell,
		target_grid_cell
	)
	
	#print("Current facing: ", owner.grid_position_data.direction)
	#print("Target direction: ", rotation_info["target_direction"])
	#print("Needs rotation: ", rotation_info["needs_rotation"])
	#print("Rotation steps: ", rotation_info["rotation_steps"])
	
	if rotation_info["needs_rotation"]:
		costs["time_units"] = abs(rotation_info["rotation_steps"])  
		costs["stamina"] = abs(rotation_info["rotation_steps"])
		rotation_direction = rotation_info["turn_direction"]
		
	else:
		costs = {}
		#print("No rotation needed, cost: ", cost)

func _setup() -> void:
	#if rotation_direction == "left":
		#if owner.is_moving():
			#owner.grid_object_animator.start_locomotion_animation(owner.get_stance(),Vector2(0.5,1))
		#else:
			#owner.grid_object_animator.start_locomotion_animation(owner.get_stance(),Vector2(0,1))
	#elif rotation_direction == "right":
		#if owner.is_moving():
			#owner.grid_object_animator.start_locomotion_animation(owner.get_stance(),Vector2(0.5,-1))
		#else: 
			#owner.grid_object_animator.start_locomotion_animation(owner.get_stance(),Vector2(0,-1))

	return

func _execute() -> void:
	#print("RotateAction _execute() called, cost at start: ", cost)
	
	# Get the target direction
	var dir_dictionary = RotationHelperFunctions.get_direction_between_cells(
		owner.grid_position_data.grid_cell,
		target_grid_cell
	)
	target_direction = dir_dictionary["direction"]
	
	# Map to the "canonical" yaw (in radians) for that enum
	var canonical_yaw = RotationHelperFunctions.get_yaw_for_direction(target_direction)

	# Read your current yaw
	var start_yaw = owner.rotation.y

	# Compute the minimal signed delta in (−π, π]
	var delta = wrapf(canonical_yaw - start_yaw, -PI, PI)

	# Build the actual target yaw
	var target_yaw = start_yaw + delta
	
	#print("Executing rotation, cost: ", cost)

	# Tween *only* the Y-rotation
	var tw = owner.create_tween()
	tw.tween_property(owner, "rotation:y", target_yaw, 0.45)
	await tw.finished

func _action_complete() -> void:
	owner.grid_position_data.set_direction(target_direction, true)
