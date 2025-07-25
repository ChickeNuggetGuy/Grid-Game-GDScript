extends Manager

#region Variables
var selected_action : ActionNode

var is_busy : bool = false
#endregion

#region signals

signal is_busy_value_changed(current_value: bool)
signal action_execution_started(current_action: ActionNode)
signal action_execution_finished(current_action: ActionNode)
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


func try_set_selected_action(action : ActionNode) -> bool:
	var ret_val : bool = false
	
	if action == null:
		return ret_val
	else:
		_set_selected_action(action)
		ret_val = true
	return ret_val

func _unhandled_input(event):
	if is_busy:
		return
	
	if UiManager.blocking_input:
		return
	
	if event is InputEventMouseButton:
		
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			print("Execution attempted with " )
			var current_cell = GridInputManager.currentGridCell
			
			if current_cell != null:

				try_execute_selected_action(current_cell)
			else:
				print("Grid cell is null")
			
func try_execute_selected_action(current_grid_cell : GridCell):
	
	var selected_unit : GridObject = UnitManager.selectedUnit
	
	if selected_unit == null:
		return
		
	if selected_action != null:
		var result = selected_action.can_execute(selected_unit, selected_unit.grid_position_data.grid_cell,current_grid_cell)
		if result["can_execute"]:
			print("Executing action, using " + str(result["cost"]) + " Time units!")
			set_is_busy(true)
			action_execution_started.emit(selected_action)
			await selected_action.instantiate(UnitManager.selectedUnit,selected_unit.grid_position_data.grid_cell,current_grid_cell ).execute_call()
			action_execution_finished.emit(selected_action)
			set_is_busy(false)
		else:
			print("Failed to execute action: " + result["reason"])
	else:
		print("No selected action")
		
#region signal calbacks
func _unitmanager_unitselected(newUnit : GridObject, oldUnit : GridObject):
	_set_selected_action(newUnit.action_library[0])
#endregion

func set_is_busy(value : bool):
	if is_busy == value:
		return
	else:
		is_busy = value
		print("is busy changed to:" + str(is_busy))
		is_busy_value_changed.emit(is_busy)

#endregion
