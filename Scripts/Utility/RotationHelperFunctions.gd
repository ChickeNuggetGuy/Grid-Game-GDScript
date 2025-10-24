# RotationHelperFunctions.gd
extends RefCounted
class_name RotationHelperFunctions


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

# --- START: MODIFIED/NEW CODE ---

# Private helper function to handle the core logic and prevent duplication.
# This is where we apply the fix for floating-point inaccuracy.
static func _get_direction_from_vector(delta: Vector2) -> Dictionary:
	var result = {
		"direction": Enums.facingDirection.NONE,
		"rotation_steps": 0
	}

	# Epsilon is a small tolerance to treat near-zero values as zero
	const EPSILON = 0.001

	var sx = 0
	if delta.x > EPSILON:
		sx = 1
	elif delta.x < -EPSILON:
		sx = -1
	
	var sz = 0
	if delta.y > EPSILON:
		sz = 1
	elif delta.y < -EPSILON:
		sz = -1

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
		_: # Fallback
			result.direction = Enums.facingDirection.NONE
			result.rotation_steps = 0
	
	return result


static func get_direction_between_cells(from_cell: GridCell, to_cell: GridCell) -> Dictionary:
	if from_cell == null or to_cell == null:
		return { "direction": Enums.facingDirection.NONE, "rotation_steps": 0 }

	var dx = to_cell.grid_coordinates.x - from_cell.grid_coordinates.x
	var dz = -(to_cell.grid_coordinates.z - from_cell.grid_coordinates.z)  # flip so +dz = North
	
	return _get_direction_from_vector(Vector2(dx, dz))


static func get_direction_between_positons(from_pos: Vector3, to_pos: Vector3) -> Dictionary:
	var dx = to_pos.x - from_pos.x
	var dz = -(to_pos.z - from_pos.z)  # flip so +dz = North

	return _get_direction_from_vector(Vector2(dx, dz))

# --- END: MODIFIED/NEW CODE ---


static func get_yaw_for_direction(dir: int) -> float:
	return YAW_MAP.get(dir, 0.0)


# Add this helper function to RotationHelperFunctions
static func get_direction_index(direction: int) -> int:
	# Convert facing direction to index (0-7)
	# Assuming Enums.facingDirection starts at 1
	return direction - 1

static func get_rotation_info(
	current_facing: int,
	from_cell: GridCell,
	to_cell: GridCell
) -> Dictionary:
	var result := {
		"needs_rotation": false,
		"rotation_steps": 0,
		"target_direction": Enums.facingDirection.NONE,
		"turn_direction": "none" # "left" | "right" | "none"
	}

	var direction_info = get_direction_between_cells(from_cell, to_cell)
	var target_direction = direction_info.direction

	if target_direction == Enums.facingDirection.NONE:
		return result

	result.target_direction = target_direction

	if current_facing == target_direction:
		return result

	var current_index = get_direction_index(current_facing)
	var target_index = get_direction_index(target_direction)

	# Minimal signed rotation in 8-direction space
	var diff = (target_index - current_index + 8) % 8
	if diff > 4:
		diff -= 8 # choose the shorter counter-clockwise path

	# diff sign encodes direction
	if diff > 0:
		result.turn_direction = "right" # clockwise
	elif diff < 0:
		result.turn_direction = "left" # counter-clockwise
	else:
		result.turn_direction = "none"

	result.rotation_steps = abs(diff)
	result.needs_rotation = result.rotation_steps > 0

	return result
