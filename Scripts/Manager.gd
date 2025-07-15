@abstract 
class_name Manager
extends Node

#region Variables
var isSetup: bool = false
var isExecuted: bool = false

static var _instances := {}
#endregion

#region Functions

func _ready() -> void:
	var s := get_script() as Script
	if _instances.has(s):
		push_error("%s: duplicate manager!" % s.resource_path)
	_instances[s] = self

# renamed to avoid colliding with Object.wget()
static func get_manager(script_res: Script) -> Manager:
	return _instances.get(script_res, null) as Manager	

@abstract func _get_manager_name() -> String


func setup_call():
	if(isSetup):
		return;
	else:
		_setup();
		isSetup = true;
		return;
	

@abstract func _setup_conditions()
@abstract func _setup()

func execute():
	print(name + " Executed!")
	_execute()
	isExecuted = true


@abstract func _execute()
@abstract func _execute_conditions() -> bool


#endregion
