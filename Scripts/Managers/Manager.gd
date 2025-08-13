@abstract
class_name Manager extends Node

static var Instances: Dictionary = {}
@export var debug_mode : bool = false
@export var passable_parameters : Dictionary = {}
#var _runtime_parameters : Dictionary = {}
#region Signals
signal setup_completed()
signal execution_completed()
#endregion


#region Initialization and Setup

# Abstract method for the manager's name.
@abstract func _get_manager_name() -> String

func _init() -> void:
	var manager_type = _get_manager_name()
	
	if Instances.has(manager_type) and Instances[manager_type] != self:
		print("Manager: %s transferring parameters" % manager_type)
		var old_parameters = Instances[manager_type].passable_parameters.duplicate(true)
		Instances[manager_type].queue_free()
		Instances[manager_type] = self
		passable_parameters = old_parameters
	else:
		print("Manager: %s first instance created" % manager_type)
		Instances[manager_type] = self

func _ready() -> void:
	add_to_group("Managers")

# Add a helper method to get instance of specific manager type
static func get_instance(manager_type: String) -> Manager:
	return Instances.get(manager_type)

# Orchestrates the manager's setup phase.
func setup_manager_flow():

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

	if not _execute_conditions():
		push_warning("%s: Execution conditions not met. Skipping execution." % _get_manager_name())
		return

	_execute.call_deferred()
	await execution_completed

# Abstract method for concrete execution logic.
# Concrete implementations must emit `execution_completed()` when done.
@abstract func _execute()

# Abstract method to check if execution can proceed.
@abstract func _execute_conditions() -> bool

#endregion
