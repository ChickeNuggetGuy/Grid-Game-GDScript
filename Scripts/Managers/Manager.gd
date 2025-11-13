@abstract
class_name Manager 
extends Node

@export var debug_mode : bool = false
@export var save_on_scene_change : bool = false
var setup_complete : bool
var execute_complete : bool
#region Signals
signal setup_completed()
signal execution_completed()
#endregion


#region Initialization and Setup


func _init() -> void:
	add_to_group("manager")
# Abstract method for the manager's name.
@abstract func _get_manager_name() -> String

@abstract func save_data() -> Dictionary


func load_data_call(data_dict : Dictionary):
	for data in data_dict.keys():
		self.set(data, data_dict[data])
	
	load_data(data_dict)


@abstract func load_data(data : Dictionary)


# Orchestrates the manager's setup phase.
func setup_manager_flow():

	if _setup_conditions() == false:
		push_warning("%s: Setup conditions not met. Skipping setup." % _get_manager_name())
		return

	_setup.call_deferred()
	await setup_completed
	setup_complete = true
	print("%s: Setup Completed!" % _get_manager_name())

# Abstract method to check if setup can proceed.
@abstract func _setup_conditions() -> bool


# Concrete implementations must emit `setup_completed()` when done.
@abstract func _setup()


#endregion

#region Execution

# Orchestrates the manager's execution phase.
func execute_manager_flow():

	if not _execute_conditions():
		push_warning("%s: Execution conditions not met. Skipping execution." % _get_manager_name())
		return

	_execute.call_deferred()
	await execution_completed
	execute_complete = true

# Abstract method for concrete execution logic.
# Concrete implementations must emit `execution_completed()` when done.
@abstract func _execute()

# Abstract method to check if execution can proceed.
@abstract func _execute_conditions() -> bool

#endregion
