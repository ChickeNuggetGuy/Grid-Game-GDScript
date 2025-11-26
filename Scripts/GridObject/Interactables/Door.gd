extends Interactable
class_name Door

@export var grid_cell_override: GridCellStateOverride
var is_open: bool = false

const BLOCKS_SIGHT_LAYER := PhysicsLayer.OBSTACLE

func _ready() -> void:
	_set_blocks_sight(not is_open)

func interact():
	toggle()

func toggle():
	if is_open:
		close()
	else:
		open()

func open():
	if is_open:
		return

	is_open = true
	if visual:
		visual.hide()

	_set_blocks_sight(false)

	if grid_cell_override:
		grid_cell_override.process_mode  = Node.PROCESS_MODE_INHERIT
		grid_cell_override.state_override = true
		grid_cell_override.cell_state_filter = (
			Enums.cellState.GROUND | Enums.cellState.OBSTRUCTED
		)
		grid_cell_override.cell_state_override = (
			Enums.cellState.GROUND | Enums.cellState.WALKABLE
		)
		grid_cell_override.set_cell_overrides(true)

func close():
	if not is_open:
		return

	is_open = false
	if visual:
		visual.show()

	_set_blocks_sight(true)

	if grid_cell_override:
		grid_cell_override.process_mode = Node.PROCESS_MODE_DISABLED
		grid_cell_override.state_override = true
		grid_cell_override.cell_state_filter = (
			Enums.cellState.GROUND | Enums.cellState.WALKABLE
		)
		grid_cell_override.cell_state_override = (
			Enums.cellState.GROUND | Enums.cellState.OBSTRUCTED
		)
		grid_cell_override.set_cell_overrides(true)

func _set_blocks_sight(enabled: bool) -> void:
	if collider == null:
		printerr("Collider is null")
		return

	var layer := collider.collision_layer
	if enabled:
		layer |= BLOCKS_SIGHT_LAYER
	else:
		layer &= ~BLOCKS_SIGHT_LAYER

	 #Using set_deferred helps avoid “changed during physics step” warnings.
	collider.set_deferred("collision_layer", layer)
