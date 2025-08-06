extends CompositeAction
class_name RangedAttackAction

var item : Item
var attack_count : int

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
	
	var dir_dictionary = RotationHelperFunctions.get_direction_between_cells(
		start_grid_cell,
		target_grid_cell
	)
	
	if dir_dictionary["direction"] != owner.grid_position_data.direction:
		var get_action_result = owner.try_get_action_definition_by_type("RotateActionDefinition")
		
		if get_action_result["success"] == false:
			return
	
		var rotate_action_node : RotateActionDefinition = get_action_result["action_definition"]
		var rotate_action = rotate_action_node.instantiate({"unit" : owner,"start_grid_cell" : start_grid_cell,"target_grid_cell" : target_grid_cell})
		sub_actions.append(rotate_action)
	
	await super._execute()
	
	for  i in range(attack_count):
		var calculation_results  = calculate_direction_with_variance( Vector2i(5,5), owner.get_tree().root.world_3d.direct_space_state)
		
		var ranged_visual = CSGSphere3D.new()
		ranged_visual.radius = 0.5
		owner.get_tree().root.add_child(ranged_visual)
		ranged_visual.position =  start_grid_cell.world_position + Vector3(0, 0.5, 0)

		var ranged_tween = owner.create_tween()
		ranged_tween.tween_property(ranged_visual, "position", calculation_results["hit_position"], 0.2)
		await ranged_tween.finished
		
		ranged_visual.queue_free() 
		if calculation_results["grid_cell"] != null:
			if calculation_results["grid_cell"].hasGridObject() and calculation_results["grid_cell"] != owner:
				print("TEST")
				var health_stat = calculation_results["grid_cell"] .grid_object.get_stat_by_name("Health")  
				if health_stat != null:
					health_stat.try_remove_value(100)
					print("damaged unit for 10 health. new health is " + str(health_stat.current_value))
		
		await owner.get_tree().create_timer(0.8).timeout
	return


func calculate_direction_with_variance(
	variance: Vector2,
	space_state: PhysicsDirectSpaceState3D
) -> Dictionary:
	# Calculate base direction vector
	var base_direction := (target_grid_cell.world_position + Vector3(0, 0.5, 0) - start_grid_cell.world_position + Vector3(0, 0.5, 0)).normalized()
	
	# Convert variance from degrees to radians
	var h_variance_rad := deg_to_rad(variance.x)
	var v_variance_rad := deg_to_rad(variance.y)
	
	# Apply random horizontal variance (yaw rotation around Y axis)
	var h_angle_variation := randf_range(-h_variance_rad, h_variance_rad)
	var horizontal_rotation := Transform3D(
		Basis(Vector3.UP, h_angle_variation),
		Vector3.ZERO
	)
	
	# Apply random vertical variance (pitch rotation around X axis)
	var v_angle_variation := randf_range(-v_variance_rad, v_variance_rad)
	var vertical_rotation := Transform3D(
		Basis(Vector3.RIGHT, v_angle_variation),
		Vector3.ZERO
	)
	
	# Combine rotations (order matters - apply horizontal first)
	var combined_rotation := horizontal_rotation * vertical_rotation
	
	# Apply the rotation to get the new direction
	var new_direction := (combined_rotation.basis * base_direction).normalized()
	
	# Perform raycast to find hit position
	var ray_params := PhysicsRayQueryParameters3D.new()
	ray_params.from =  start_grid_cell.world_position + Vector3(0, 0.5, 0)
	ray_params.to = ray_params.from  + (new_direction * 1000 ) # Arbitrary long distance
	ray_params.collide_with_bodies = true
	ray_params.collide_with_areas = true
	
	var hit_result := space_state.intersect_ray(ray_params)
	
	var hit_position: Vector3
	var grid_cell: GridCell
	
	if not hit_result.is_empty():
		
		DebugDraw3D.draw_line(start_grid_cell.world_position + Vector3(0, 0.5, 0) ,hit_result.position,Color.GREEN,4 )
		# Hit something
		hit_position = hit_result.position
		# Convert to grid coordinates (assuming integer grid positions)
		var get_grid_cell_result = GridSystem.try_get_gridCell_from_world_position(hit_position)
		
		if get_grid_cell_result["success"]:
			grid_cell = get_grid_cell_result["grid_cell"]
		else:
			grid_cell = null
		
	else:
		DebugDraw3D.draw_ray(start_grid_cell.world_position + Vector3(0, 0.5, 0) ,new_direction, 100,Color.RED,4 )
		# No hit - set to maximum distance point
		hit_position = ray_params.from  + new_direction * 1000
		var get_grid_cell_result = GridSystem.try_get_gridCell_from_world_position(hit_position)
		
		if get_grid_cell_result["success"]:
			grid_cell = get_grid_cell_result["grid_cell"]
		else:
			grid_cell = null
	
	# Return results
	return {
		"new_direction": new_direction,
		"hit_position": hit_position,
		"grid_cell": grid_cell,
		"hit_result": hit_result
	}

func _action_complete():
	return
	
