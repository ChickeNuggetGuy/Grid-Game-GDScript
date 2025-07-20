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

static func get_direction_between_cells(from_cell : GridCell, to_cell : GridCell) -> Enums.facingDirection:
	if from_cell == null or to_cell == null:
		return Enums.facingDirection.NONE

	var dx = to_cell.gridCoordinates.x - from_cell.gridCoordinates.x
	var dz = -(to_cell.gridCoordinates.z - from_cell.gridCoordinates.z)  # flip so +dz = North
	var sx = int(sign(dx))
	var sz = int(sign(dz))

	if sx == 0 and sz == 0:
		return Enums.facingDirection.NONE
	elif sx > 0 and sz == 0:
		return Enums.facingDirection.EAST
	elif sx < 0 and sz == 0:
		return Enums.facingDirection.WEST
	elif sx == 0 and sz > 0:
		return Enums.facingDirection.NORTH
	elif sx == 0 and sz < 0:
		return Enums.facingDirection.SOUTH
	elif sx > 0 and sz > 0:
		return Enums.facingDirection.NORTHEAST
	elif sx > 0 and sz < 0:
		return Enums.facingDirection.SOUTHEAST
	elif sx < 0 and sz > 0:
		return Enums.facingDirection.NORTHWEST
	else:
		return Enums.facingDirection.SOUTHWEST

static func get_yaw_for_direction(dir: int) -> float:
	return YAW_MAP.get(dir, 0.0)
