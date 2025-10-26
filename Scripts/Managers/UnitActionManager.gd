extends Manager
class_name UnitActionManager
#region Variables

var selected_action: BaseActionDefinition
var current_action : Action
var action_params : Dictionary
var is_busy: bool = false
@export var is_busy_timer := 0.0
@export var is_busy_timer_max := 5.0
#endregion

#region Signals
signal selected_action_changed(new_selected_action: BaseActionDefinition)
signal is_busy_value_changed(current_value: bool)
signal action_execution_started(current_action_definition: BaseActionDefinition, execution_parameters: Dictionary)

signal action_execution_finished(current_action_definition: BaseActionDefinition, execution_parameters: Dictionary)
signal any_action_execution_finished(current_action_definition: BaseActionDefinition, execution_parameters: Dictionary)


signal action_execution_canceled(current_action_: Action )
signal any_action_execution_canceled(current_action_: Action)

#endregion

#region Setup

func _get_manager_name() -> String:
	return "UnitActionManager"

func _setup_conditions() -> bool:
	return true

func _setup() -> void:
	setup_completed.emit()

func _on_exit_tree() -> void:
	if GameManager.managers["UnitManager"].is_connected("SelectedUnitChanged", Callable(self, "_on_unit_manager_selected_unit")):
		GameManager.managers["UnitManager"].disconnect("SelectedUnitChanged",Callable(self, "_on_unit_manager_selected_unit"))

func _execute_conditions() -> bool:
	return true

func _execute() -> void:
	execution_completed.emit()
#endregion

#region Selected Action Management
func _set_selected_action(action: BaseActionDefinition) -> void:

	if action and action != selected_action:
		print("Selected action set to: %s" % action.action_name)
	elif not action:
		print("Selected action cleared.")
	
	if action != selected_action and action_params and not action_params.is_empty():
		print("Action changed, clearing pending double-click params.")
		if selected_action and selected_action.double_click_activation:
			selected_action.double_click_clear(action_params)
		action_params.clear()
	
	selected_action = action
	selected_action_changed.emit(selected_action)

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
			set_is_busy(false, null)

func set_is_busy(value: bool, action : Action) -> void:
	if is_busy == value:
		return
		
	is_busy = value
	if value:
		is_busy_timer = 0.0
	print("is_busy changed to: %s" % str(is_busy))
	is_busy_value_changed.emit(is_busy)
	current_action = action
#endregion

#region Input Handling
func _unhandled_input(event) -> void:
	if not execute_complete: return
	
	if GameManager.managers["UIManager"].blocking_input:
		return
	
	if is_busy:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT \
		and selected_action.get_can_cancel_action():
			#Attempt to cancel action
			current_action.request_cancel_action = true
			print("Cancel action")
		else: return
		
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_handle_left_click()
			MOUSE_BUTTON_RIGHT:
				_handle_right_click()

func _handle_left_click() -> void:
	var current_cell = GameManager.managers["GridInputManager"].currentGridCell
	if current_cell:
		try_execute_selected_action(current_cell)
	else:
		print("Left click ignored: No grid cell selected.")

func _handle_right_click() -> void:
	var selected_unit = GameManager.managers["UnitManager"].selectedUnit
	if not selected_unit:
		return

	var current_cell = GameManager.managers["GridInputManager"].currentGridCell
	if not current_cell:
		return

	var get_action_result = selected_unit.try_get_action_definition_by_type("RotateActionDefinition")
	if not get_action_result.get("success", false):
		return

	try_execute_action(current_cell, selected_unit, get_action_result["action_definition"])
#endregion

#region Action Execution
func try_execute_selected_action(grid_cell: GridCell) -> void:
	var selected_unit: Unit = GameManager.managers["UnitManager"].selectedUnit
	if not selected_unit or not selected_action:
		return
	try_execute_action(grid_cell, selected_unit, selected_action)


func try_execute_action(grid_cell: GridCell, unit: Unit, action_to_execute: BaseActionDefinition) -> void:
	if not unit or not action_to_execute:
		print("Action execution failed: Missing unit or action.")
		return
	
	var params = {
		"unit": unit,
		"start_grid_cell": unit.grid_position_data.grid_cell,
		"target_grid_cell": grid_cell,
		"action_definition": action_to_execute,
	}
	
			
			

	await _execute_action_internal(action_to_execute, params)


#func try_execute_item_action(action_to_execute: BaseItemActionDefinition,
		#unit : Unit,
		#item: Item,
		#starting_inventory: InventoryGrid,
		#target_grid_cell : GridCell = null) -> Dictionary:
	#GameManager.managers["UIManager"].hide_non_persitent_windows()
	#GameManager.managers["UIManager"].try_block_input(null)
	#set_is_busy(true)
#
	#var ret_val = {"success": false, "Reasoning": "N/A"}
#
#
	#if not target_grid_cell:
		#target_grid_cell = GameManager.managers["GridInputManager"].currentGridCell
		##ret_val["Reasoning"] = "Current grid cell is null!"
		##print(ret_val["Reasoning"])
		##set_is_busy(false)
		#return ret_val
#
	#if not unit:
		#ret_val["Reasoning"] = "Selected unit is null!"
		#print(ret_val["Reasoning"])
		#set_is_busy(false)
		#return ret_val
#
	#if not action_to_execute:
		#ret_val["Reasoning"] = "Action definition is null!"
		#print(ret_val["Reasoning"])
		#set_is_busy(false)
		#return ret_val
#
	#if not item:
		#ret_val["Reasoning"] = "Item is null!"
		#print(ret_val["Reasoning"])
		#set_is_busy(false)
		#return ret_val
#
	#var params = {
		#"unit": unit,
		#"start_grid_cell": unit.grid_position_data.grid_cell,
		#"target_grid_cell": target_grid_cell,
		#"item": item,
		#"action_definition": action_to_execute,
		#"starting_inventory": starting_inventory
	#}
	#await _execute_action_internal(action_to_execute, params)
	#GameManager.managers["UIManager"].unblock_input()
	#return ret_val


func _execute_action_internal(action_def: BaseActionDefinition, params: Dictionary) -> void:
	var result = action_def.can_execute(params)
	
	if not result.get("success", false):
		print("Failed to execute action: " + result.get("reason", "Unknown reason"))
		set_is_busy(false, null)
		return

	if result.get("extra_parameters", null) != null and result["extra_parameters"].size() > 0:
		for param_key in result["extra_parameters"].keys():
			params[param_key] = result["extra_parameters"][param_key]

	if action_def.double_click_activation:
		var is_first_click := action_params.is_empty()
		var is_same_target := not is_first_click and action_params == params

		if not is_same_target:
			
			if not is_first_click:
				print("Double click target changed.")
				action_def.double_click_clear(action_params)
			
			print("Double click action: first click on new target.")
			action_params = params
			action_def.double_click_call(action_params)
			return 
		
		
		print("Double click action: executing action")
	
	
	print("Executing action: %s, using %s Time units!" %
		[action_def.action_name, str(result.get("costs", "?"))])

	
	action_execution_started.emit(action_def, params)

	var action :Action = action_def.instantiate(params)
	set_is_busy(true, action)
	await action.execute_call()
	if not is_instance_valid(self):
		return
		
	any_action_execution_finished.emit(action_def, params)
	action_execution_finished.emit(action_def, params)
	action_params.clear()
	set_is_busy(false, null)


func cancel_current_action():
	if current_action == null:
		print("Current action is null!")
		return
	
	
	any_action_execution_canceled.emit(current_action)
	action_execution_canceled.emit(current_action)
	action_params.clear()
	set_is_busy(false, null)
#endregion
