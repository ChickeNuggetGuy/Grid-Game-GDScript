extends Manager

#region Variables
var selected_action : ActionNode
#endregion


#region Functions
func _get_manager_name() -> String: return "UnitActionManager"

func _setup_conditions() -> bool: return true


func _setup() -> void:
	UnitManager.connect("UnitSelected", _unitmanager_unitselected)
	setup_completed.emit()

func _exit_tree() -> void:
	# Optional: disconnect if you want to clean up manually
	UnitManager.instance.disconnect("SelectedUnitChanged", self,
	 "_on_unit_manager_selected_unit")

func _execute_conditions() -> bool: return true


func _execute() -> void: 
	execution_completed.emit()

func _set_selected_action(action : ActionNode): 
	selected_action = action
	print(selected_action.name)


func try_set_selected_action(action : ActionNode) -> bool:
	var ret_val : bool = false
	
	if action == null:
		return ret_val
	else:
		_set_selected_action(action)
		ret_val = true
	return ret_val

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var current_cell = GridInputManager.currentGridCell
			if current_cell != null:
				try_execute_selected_action(current_cell)
			else:
				print("Grid cell is null")
			
func try_execute_selected_action(current_grid_cell : GridCell):
	if selected_action != null:
		print("Execution attempted with " + selected_action.name)
		await selected_action.instantiate(UnitManager.selectedUnit,current_grid_cell ).execute()
	else:
		print("No selected action")
		
#region signal calbacks
func _unitmanager_unitselected(newUnit : GridObject, oldUnit : GridObject):
	_set_selected_action(newUnit.action_library[0])
#endregion
#endregion
