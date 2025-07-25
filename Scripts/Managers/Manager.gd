# Manager.gd
@abstract
class_name Manager extends Node

#region Signals
signal setup_completed()
signal execution_completed()
#endregion

#region Singleton Instance

#endregion

#region Initialization and Setup

# Abstract method for the manager's name.
@abstract func _get_manager_name() -> String

func _init() -> void: add_to_group("Managers")



# Orchestrates the manager's setup phase.
func setup_manager_flow():
	print("%s: Starting setup flow..." % _get_manager_name())

	if _setup_conditions() == false:
		push_warning("%s: Setup conditions not met. Skipping setup." % _get_manager_name())
		return

	_setup.call_deferred()
	await setup_completed
	print("%s: Setup Completed!" % _get_manager_name())

# Abstract method to check if setup can proceed.
@abstract func _setup_conditions() -> bool


# Concrete implementations must emit `setup_completed()` when done.
@abstract func _setup()

#endregion

#region Execution

# Orchestrates the manager's execution phase.
func execute_manager_flow():
	print("%s: Starting execution flow..." % _get_manager_name())

	if not _execute_conditions():
		push_warning("%s: Execution conditions not met. Skipping execution." % _get_manager_name())
		return

	_execute.call_deferred()
	await execution_completed
	print("%s: Execution Completed!" % _get_manager_name())

# Abstract method for concrete execution logic.
# Concrete implementations must emit `execution_completed()` when done.
@abstract func _execute()

# Abstract method to check if execution can proceed.
@abstract func _execute_conditions() -> bool

#endregion
