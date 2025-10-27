extends Interactable
class_name Door

@export var grid_cell_override : GridCellStateOverride
var is_open : bool


func interact():
	print("Interact")
	toggle()
	return


func toggle():
	if is_open:
		close()
	else:
		open()


func open():
	is_open = true
	visual.hide()
	grid_cell_override.cell_state_override = Enums.cellState.WALKABLE
	grid_cell_override.cell_state_filter = Enums.cellState.OBSTRUCTED
	grid_cell_override.set_cell_overrides()


func close():
	is_open = false
	visual.show()
	grid_cell_override.cell_state_override = Enums.cellState.OBSTRUCTED
	grid_cell_override.cell_state_filter = Enums.cellState.WALKABLE
	grid_cell_override.set_cell_overrides()
