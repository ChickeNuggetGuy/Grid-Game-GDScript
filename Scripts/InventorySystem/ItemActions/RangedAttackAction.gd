extends CompositeAction
class_name RangedAttackAction

var item : Item
var attack_count : int

const MAX_PROJECTILE_RANGE := 30.0
const PROJECTILE_SPEED := 20.0
const MAX_TWEEN_DURATION := 0.6
const MIN_TWEEN_DURATION := 0.05


func _init(parameters : Dictionary) -> void:
	parameters["action_name"] = "Ranged Attack"
	owner = parameters["unit"]
	costs = {"time_units" : 12 }
	target_grid_cell = parameters["target_grid_cell"]
	start_grid_cell = parameters["start_grid_cell"]
	item = parameters["item"]
	attack_count = parameters["action_definition"].attack_count
	super._init(parameters)



func _setup():
	return

func _execute() -> void:
	var from_position: Vector3 = start_grid_cell.world_position
	var owner_results = owner.try_get_grid_object_component_by_type(
		"GridObjectWorldTarget"
	)
	if owner_results["success"] == true:
		from_position = owner_results["grid_object_component"].targets[
			"fire_position"
		].global_position

	var target_position: Vector3 = target_grid_cell.world_position
	if target_grid_cell.has_grid_object():
		var results = target_grid_cell.grid_object.\
			try_get_grid_object_component_by_type("GridObjectWorldTarget")
		if results["success"] == true:
			target_position = results["grid_object_component"].targets[
				"target_position"
			].global_position

	var dir_dictionary = RotationHelperFunctions.get_direction_between_positons(
		from_position,
		target_position
	)

	if dir_dictionary["direction"] != owner.grid_position_data.direction:
		var get_action_result = owner.try_get_action_definition_by_type(
			"RotateActionDefinition"
		)
		if get_action_result["success"] == false:
			return

		var rotate_action_node: RotateActionDefinition = get_action_result[
			"action_definition"
		]
		var rotate_action = rotate_action_node.instantiate({
			"unit": owner,
			"start_grid_cell": start_grid_cell,
			"target_grid_cell": target_grid_cell
		})
		sub_actions.append(rotate_action)

	await super._execute()

	for i in range(attack_count):
		var calc = calculate_direction_with_variance(
			from_position,
			target_position,
			Vector2(5, 5),
			owner.get_tree().root.world_3d.direct_space_state,
			MAX_PROJECTILE_RANGE
		)

		var ranged_visual := CSGSphere3D.new()
		ranged_visual.radius = 0.5
		owner.get_tree().root.add_child(ranged_visual)
		ranged_visual.position = from_position

		var hit_pos: Vector3 = calc["hit_position"]
		var travel_distance: float = ranged_visual.global_position.distance_to(
			hit_pos
		)

		# Cap tween duration so long misses don't stall gameplay
		var duration: float = clamp(
			travel_distance / PROJECTILE_SPEED,
			MIN_TWEEN_DURATION,
			MAX_TWEEN_DURATION
		)

		var ranged_tween := owner.create_tween()
		ranged_tween.set_trans(Tween.TRANS_LINEAR)
		ranged_tween.set_ease(Tween.EASE_IN_OUT)
		ranged_tween.tween_property(
			ranged_visual,
			"global_position",
			hit_pos,
			duration
		)

		await ranged_tween.finished
		ranged_visual.queue_free()

		var hit_grid_object: GridObject = null
		if calc["grid_object"] != null and calc["grid_object"] != owner:
			hit_grid_object = calc["grid_object"]
		elif calc["grid_cell"] != null:
			if calc["grid_cell"].has_grid_object() and \
				calc["grid_cell"].grid_object != owner:
				hit_grid_object = calc["grid_cell"].grid_object

		if hit_grid_object != null:
			var health_stat = hit_grid_object.get_stat_by_name("Health")
			if health_stat != null:
				health_stat.try_remove_value(100)
				print(
					"damaged unit for 10 health. new health is " +
					str(health_stat.current_value)
				)

		await owner.get_tree().create_timer(0.8).timeout
	return


func calculate_direction_with_variance(
	from_position: Vector3,
	to_position: Vector3,
	variance: Vector2,
	space_state: PhysicsDirectSpaceState3D,
	max_range: float
) -> Dictionary:
	var base_direction := (to_position - from_position).normalized()

	# Convert variance from degrees to radians
	var h_variance_rad := deg_to_rad(variance.x)
	var v_variance_rad := deg_to_rad(variance.y)

	# Random horizontal (yaw) and vertical (pitch) variance
	var h_angle_variation := randf_range(-h_variance_rad, h_variance_rad)
	var horizontal_rotation := Transform3D(
		Basis(Vector3.UP, h_angle_variation),
		Vector3.ZERO
	)

	var v_angle_variation := randf_range(-v_variance_rad, v_variance_rad)
	var vertical_rotation := Transform3D(
		Basis(Vector3.RIGHT, v_angle_variation),
		Vector3.ZERO
	)

	var combined_rotation := horizontal_rotation * vertical_rotation
	var new_direction := (combined_rotation.basis * base_direction).normalized()

	# Ray only to max_range
	var ray_params := PhysicsRayQueryParameters3D.new()
	ray_params.from = from_position + Vector3(0, 0.5, 0)
	ray_params.to = ray_params.from + (new_direction * max_range)
	ray_params.collide_with_bodies = true
	ray_params.collide_with_areas = true
	_exclude_owner_and_children(ray_params, owner)
	ray_params.hit_from_inside = false

	var hit_result := space_state.intersect_ray(ray_params)

	var hit_position: Vector3
	var grid_cell: GridCell = null
	var grid_object: GridObject = null

	if not hit_result.is_empty():
		hit_position = hit_result.position

		var parent = hit_result.collider.get_parent_node_3d()
		if parent is GridObject:
			grid_object = parent as GridObject
			grid_cell = grid_object.grid_position_data.grid_cell
		else:
			var get_grid_cell_result = Manager.get_instance("GridSystem").\
				try_get_gridCell_from_world_position(hit_position)
			if get_grid_cell_result.get("success", false):
				grid_cell = get_grid_cell_result["grid_cell"]
			else:
				grid_cell = null
	else:
		# Miss: stop at max_range instead of a huge arbitrary distance
		hit_position = ray_params.from + new_direction * max_range
		var miss_cell_res = Manager.get_instance("GridSystem").\
			try_get_gridCell_from_world_position(hit_position)
		if miss_cell_res.get("success", false):
			grid_cell = miss_cell_res["grid_cell"]
		else:
			grid_cell = null

	return {
		"new_direction": new_direction,
		"hit_position": hit_position,
		"grid_cell": grid_cell,
		"hit_result": hit_result,
		"grid_object": grid_object
	}

func _action_complete():
	return
	


func _exclude_owner_and_children(
	ray_params: PhysicsRayQueryParameters3D, owner: Node
) -> void:
	var excludes: Array[RID] = []
	if owner:
		if owner is CollisionObject3D:
			excludes.append(owner.get_rid())
		for child in owner.get_children():
			if child is CollisionObject3D:
				excludes.append(child.get_rid())
	ray_params.exclude = excludes
