extends Interactable
class_name Door

@export var grid_cell_override: GridCellStateOverride
var is_open: bool

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
		
	if grid_cell_override:
		grid_cell_override.state_override = true
		# Only affect cells that have BOTH GROUND and OBSTRUCTED flags
		grid_cell_override.cell_state_filter = Enums.cellState.GROUND | Enums.cellState.OBSTRUCTED
		grid_cell_override.cell_state_override = Enums.cellState.GROUND | Enums.cellState.WALKABLE
		grid_cell_override.set_cell_overrides(true)

func close():
	if not is_open:
		return
		
	is_open = false
	if visual:
		visual.show()
		
	if grid_cell_override:
		grid_cell_override.state_override = true
		# Only affect cells that have BOTH GROUND and WALKABLE flags  
		grid_cell_override.cell_state_filter = Enums.cellState.GROUND | Enums.cellState.WALKABLE
		grid_cell_override.cell_state_override = Enums.cellState.GROUND | Enums.cellState.OBSTRUCTED
		grid_cell_override.set_cell_overrides(true)
