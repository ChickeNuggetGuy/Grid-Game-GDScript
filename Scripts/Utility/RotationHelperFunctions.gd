# RotationHelperFunctions.gd
extends RefCounted
class_name RotationHelperFunctions


# ← no `static` here, just `const`
const YAW_MAP: Dictionary = {
	Enums.facingDirection.NORTH:     0.0,
	Enums.facingDirection.NORTHEAST: -PI/4,
	Enums.facingDirection.EAST:      -PI/2,
	Enums.facingDirection.SOUTHEAST: -3*PI/4,
	Enums.facingDirection.SOUTH:      PI,
	Enums.facingDirection.SOUTHWEST:  3*PI/4,
	Enums.facingDirection.WEST:       PI/2,
	Enums.facingDirection.NORTHWEST:  PI/4,
}

static func get_direction_between_cells(from_cell: GridCell, to_cell: GridCell) -> Dictionary:
	var result = {
		"direction": Enums.facingDirection.NONE,
		"rotation_steps": 0
	}

	if from_cell == null or to_cell == null:
		return result

	var dx = to_cell.gridCoordinates.x - from_cell.gridCoordinates.x
	var dz = -(to_cell.gridCoordinates.z - from_cell.gridCoordinates.z)  # flip so +dz = North
	var sx = sign(dx) # sign() in GDScript returns -1, 0, or 1
	var sz = sign(dz)

	# Determine direction and rotation steps
	match [sx, sz]:
		[0, 0]: # Same cell or invalid
			result.direction = Enums.facingDirection.NONE
			result.rotation_steps = 0
		[0, 1]: # North
			result.direction = Enums.facingDirection.NORTH
			result.rotation_steps = 0
		[1, 1]: # Northeast
			result.direction = Enums.facingDirection.NORTHEAST
			result.rotation_steps = 1
		[1, 0]: # East
			result.direction = Enums.facingDirection.EAST
			result.rotation_steps = 2
		[1, -1]: # Southeast
			result.direction = Enums.facingDirection.SOUTHEAST
			result.rotation_steps = 3
		[0, -1]: # South
			result.direction = Enums.facingDirection.SOUTH
			result.rotation_steps = 4
		[-1, -1]: # Southwest
			result.direction = Enums.facingDirection.SOUTHWEST
			result.rotation_steps = 5
		[-1, 0]: # West
			result.direction = Enums.facingDirection.WEST
			result.rotation_steps = 6
		[-1, 1]: # Northwest
			result.direction = Enums.facingDirection.NORTHWEST
			result.rotation_steps = 7
		_: # Fallback for any unexpected case (shouldn't happen with sign values)
			result.direction = Enums.facingDirection.NONE
			result.rotation_steps = 0

	return result
static func get_yaw_for_direction(dir: int) -> float:
	return YAW_MAP.get(dir, 0.0)


# Add this helper function to RotationHelperFunctions
static func get_direction_index(direction: int) -> int:
	# Convert facing direction to index (0-7)
	# Assuming Enums.facingDirection starts at 1
	return direction - 1

static func get_rotation_info(current_facing: int, from_cell: GridCell, to_cell: GridCell) -> Dictionary:
	var result = {
		"needs_rotation": false,
		"rotation_steps": 0,
		"target_direction": Enums.facingDirection.NONE
	}

	var direction_info = get_direction_between_cells(from_cell, to_cell)
	var target_direction = direction_info.direction

	if target_direction == Enums.facingDirection.NONE:
		return result

	result.target_direction = target_direction

	if current_facing == target_direction:
		return result

	# Calculate minimal rotation steps
	var current_index = get_direction_index(current_facing)
	var target_index = get_direction_index(target_direction)
	
	# Calculate minimal rotation (can rotate clockwise or counter-clockwise)
	var diff = (target_index - current_index + 8) % 8
	if diff > 4:
		diff -= 8  # Prefer counter-clockwise if it's fewer steps
	
	result.rotation_steps = abs(diff)  # Return absolute value for cost calculation
	result.needs_rotation = true

	return result
