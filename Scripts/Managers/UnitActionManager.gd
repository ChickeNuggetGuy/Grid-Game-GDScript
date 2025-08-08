extends Manager
class_name UnitActionManager
#region Variables
static var Instance : UnitActionManager

var selected_action: BaseActionDefinition
var is_busy: bool = false
@export var is_busy_timer := 0.0
@export var is_busy_timer_max := 5.0
#endregion

#region Signals
signal selected_action_changed(new_selected_action: BaseActionDefinition)
signal is_busy_value_changed(current_value: bool)
signal action_execution_started(current_action_definition: BaseActionDefinition, execution_parameters: Dictionary)
signal action_execution_finished(current_action_definition: BaseActionDefinition, execution_parameters: Dictionary)
#endregion

#region Setup

func _init() -> void:
	Instance = self




func _get_manager_name() -> String:
	return "UnitActionManager"

func _setup_conditions() -> bool:
	return true

func _setup() -> void:
	# Example: connect to UnitManager if needed
	# UnitManager.connect("UnitSelected", _unitmanager_unitselected)
	setup_completed.emit()

func _exit_tree() -> void:
	if UnitManager.Instance.is_connected("SelectedUnitChanged", Callable(self, "_on_unit_manager_selected_unit")):
		UnitManager.Instance.disconnect("SelectedUnitChanged",Callable(self, "_on_unit_manager_selected_unit"))

func _execute_conditions() -> bool:
	return true

func _execute() -> void:
	execution_completed.emit()
#endregion

#region Selected Action Management
func _set_selected_action(action: BaseActionDefinition) -> void:
	selected_action = action
	selected_action_changed.emit(selected_action)
	if action:
		print_debug("Selected action set to: %s" % action.action_name)
	else:
		print_debug("Selected action cleared.")

func try_set_selected_action(action: BaseActionDefinition) -> bool:
	if action == null:
		return false
	_set_selected_action(action)
	return true
#endregion

#region Process & Busy State
func _process(delta: float) -> void:
	if is_busy:
		is_busy_timer += delta
		if is_busy_timer >= is_busy_timer_max:
			set_is_busy(false)

func set_is_busy(value: bool) -> void:
	if is_busy == value:
		return
	is_busy = value
	if value:
		is_busy_timer = 0.0
	print_debug("is_busy changed to: %s" % str(is_busy))
	is_busy_value_changed.emit(is_busy)
#endregion

#region Input Handling
func _unhandled_input(event) -> void:
	if is_busy or UIManager.Instance.blocking_input:
		return

	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_handle_left_click()
			MOUSE_BUTTON_RIGHT:
				_handle_right_click()

func _handle_left_click() -> void:
	var current_cell = GridInputManager.Instance.currentGridCell
	if current_cell:
		try_execute_selected_action(current_cell)
	else:
		print_debug("Left click ignored: No grid cell selected.")

func _handle_right_click() -> void:
	var selected_unit = UnitManager.Instance.selectedUnit
	if not selected_unit:
		return

	var current_cell = GridInputManager.Instance.currentGridCell
	if not current_cell:
		return

	var get_action_result = selected_unit.try_get_action_definition_by_type("RotateActionDefinition")
	if not get_action_result.get("success", false):
		return

	try_execute_action(current_cell, selected_unit, get_action_result["action_definition"])
#endregion

#region Action Execution
func try_execute_selected_action(grid_cell: GridCell) -> void:
	var selected_unit: Unit = UnitManager.Instance.selectedUnit
	if not selected_unit or not selected_action:
		return
	try_execute_action(grid_cell, selected_unit, selected_action)

func try_execute_action(grid_cell: GridCell, unit: Unit, action_to_execute: BaseActionDefinition) -> void:
	if not unit or not action_to_execute:
		print_debug("Action execution failed: Missing unit or action.")
		return

	var params = {
		"unit": unit,
		"start_grid_cell": unit.grid_position_data.grid_cell,
		"target_grid_cell": grid_cell
	}
	await _execute_action_internal(action_to_execute, params)

func try_execute_item_action(action_to_execute: BaseItemActionDefinition, item: Item, starting_inventory: InventoryGrid) -> Dictionary:
	UIManager.Instance.hide_non_persitent_windows()
	UIManager.Instance.try_block_input(null)
	set_is_busy(true)

	var ret_val = {"success": false, "Reasoning": "N/A"}
	var selected_unit = UnitManager.Instance.selectedUnit
	var current_grid_cell = await GridInputManager.Instance.grid_cell_selected

	if not current_grid_cell:
		ret_val["Reasoning"] = "Current grid cell is null!"
		print_debug(ret_val["Reasoning"])
		set_is_busy(false)
		return ret_val

	if not selected_unit:
		ret_val["Reasoning"] = "Selected unit is null!"
		print_debug(ret_val["Reasoning"])
		set_is_busy(false)
		return ret_val

	if not action_to_execute:
		ret_val["Reasoning"] = "Action definition is null!"
		print_debug(ret_val["Reasoning"])
		set_is_busy(false)
		return ret_val

	if not item:
		ret_val["Reasoning"] = "Item is null!"
		print_debug(ret_val["Reasoning"])
		set_is_busy(false)
		return ret_val

	var params = {
		"unit": selected_unit,
		"start_grid_cell": selected_unit.grid_position_data.grid_cell,
		"target_grid_cell": current_grid_cell,
		"item": item,
		"action_definition": action_to_execute,
		"starting_inventory": starting_inventory
	}
	await _execute_action_internal(action_to_execute, params)
	UIManager.Instance.unblock_input()
	return ret_val

# Core unified execution method
func _execute_action_internal(action_def: BaseActionDefinition, params: Dictionary) -> void:
	var result = action_def.can_execute(params)
	if not result.get("success", false):
		print_debug("Failed to execute action: %s" % str(result.get("reason", "Unknown reason")))
		set_is_busy(false)
		return

	print_debug("Executing action: %s, using %s Time units!" %
		[action_def.action_name, str(result.get("costs", "?"))])

	set_is_busy(true)
	action_execution_started.emit(action_def, params)

	# Async safety
	action_def.instantiate(params).execute_call()
	if not is_instance_valid(self):
		return

	action_execution_finished.emit(action_def, params)
	set_is_busy(false)
#endregion
