extends Action

func _init(target : GridCell) -> void:
	name = "Move"
	cost = 1
	target_grid_cell = target

func execute() -> void:
	owner.ap -= cost

	# 1) pick one of the 8 enums (None if same cell)
	var dir_enum = RotationHelperFunctions.get_direction_between_cells(
		owner.grid_position_data.grid_cell,
		target_grid_cell
	)

	# 2) map to the “canonical” yaw (in radians) for that enum
	var canonical_yaw = RotationHelperFunctions.get_yaw_for_direction(dir_enum)

	# 3) read your current yaw
	var start_yaw = owner.rotation.y

	# 4) compute the minimal signed delta in (−π, π]
	var delta = wrapf(canonical_yaw - start_yaw, -PI, PI)

	# 5) build the actual target yaw
	var target_yaw = start_yaw + delta

	# 6) tween *only* the Y‐rotation
	var tw = owner.create_tween()
	tw.tween_property(owner, "rotation:y", target_yaw, 0.2)
	await tw.finished
	
	var path = Pathfinder.find_path(
	owner.grid_position_data.grid_cell,
	target_grid_cell
	)
	print("PATH:", path, "size=", path.size())
	#var path : Array[GridCell] = Pathfinder.find_path(owner.grid_position_data.grid_cell, target_grid_cell)
	
	for cell in path:
		var move_tween = owner.create_tween()
		move_tween.tween_property(owner, "position", cell.worldPosition, 1)
		await move_tween.finished
