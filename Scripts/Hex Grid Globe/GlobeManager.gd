extends Manager
class_name GlobeManager

@export var hex_globe_Decorator : HexGridDecorator
@export var hex_grid_data : HexGridData
@export var funds : int = 400000
var build_base_mode : bool  = false


var start_cell_index = -1
var end_cell_index = -1

#region signals
signal funds_changed(current_funds : int)
#endregion
#region Functions

func get_cell_definitions(cell_def_filter: String) -> Array[int]:
	if hex_grid_data == null or not hex_grid_data.cell_definitions:
		return []

	var valid_cells: Array[int] = []

	for cell_index in hex_grid_data.cell_definitions.keys():
		var definitions = hex_grid_data.get_cell_definitions(cell_index)
		if definitions == null:
			continue

		for cell_definition in definitions:
			if cell_definition != null and cell_definition.get_class_name() == cell_def_filter:
				valid_cells.append(cell_index)

	return valid_cells

func try_place_base():
	var index = hex_globe_Decorator.hovered_cell
	var new_base : TeamBaseDefinition = TeamBaseDefinition.new(index, Enums.unitTeam.PLAYER)
	hex_grid_data.add_cell_definition(index,new_base, hex_globe_Decorator)
	
	build_base_mode = false
	print("Added City: test: " + str(hex_grid_data.get_cell_definitions(index).size()))
	try_spend_funds(400000)
	


func try_spend_funds(amount_to_spend : int) -> bool:
	if funds < amount_to_spend:
		return false
	
	funds -= amount_to_spend
	funds_changed.emit(funds)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and event is InputEventKey:
		var key_event : InputEventKey = event

	elif event.is_pressed() and event is InputEventMouse:
		var mouse_event : InputEventMouseButton = event
		var index = hex_globe_Decorator.hovered_cell
		
		if build_base_mode:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				try_place_base()
		else:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				start_cell_index = index
				
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				end_cell_index = index
			elif mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
				if start_cell_index != -1 and end_cell_index != -1:
					var pf : GlobePathfinder = GlobePathfinder.new()
					pf.set_grid_index(hex_globe_Decorator.grid_index)
					var path := pf.find_path(start_cell_index, end_cell_index)
					path = pf.smooth_path_adjacent(path)
					if not path.is_empty():
						for i in path:
							var new_city : CityDefinition = CityDefinition.new(index,"TEST")
							hex_grid_data.add_cell_definition(i,new_city, hex_globe_Decorator)
					hex_globe_Decorator._rebuild_city_cells()
			
		

#func _process(delta: float) -> void:
	#if Input.is_physical_key_pressed(KEY_B):
		#try_place_base()


#region Manager Functions
func _get_manager_name() -> String: return "GlobeManager"


func _setup_conditions() -> bool: return true


func _setup():
	hex_grid_data = hex_globe_Decorator.hex_grid_data
	setup_completed.emit()
	setup_complete = true
	return


func _execute_conditions() -> bool: return true


func _execute():
	execution_completed.emit()
	execute_complete = true
	return

#endregion
#endregion
