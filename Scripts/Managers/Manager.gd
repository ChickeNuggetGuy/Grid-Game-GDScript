@abstract
class_name Manager
extends Node

enum DataLoadTiming {
	BEFORE_EXECUTE,
	AFTER_EXECUTE,
}

@export var debug_mode := false
@export var save_on_scene_change := false
@export var wait_for_loading_completion := true

@export var data_load_timing: DataLoadTiming = DataLoadTiming.BEFORE_EXECUTE

var setup_complete := false
var execute_complete := false
var load_data: Dictionary = {}
var is_busy := false

signal setup_completed()
signal execution_completed()

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("manager")

@abstract func _get_manager_name() -> String
@abstract func save_data() -> Dictionary
@abstract func _setup() -> void
@abstract func _execute() -> void

func get_scene_transition_data() -> Dictionary:
	return save_data()

func load_data_call(data_dict: Dictionary) -> void:
	print("Load data set: " + _get_manager_name() + " count is " + str(data_dict.size()) )
	load_data = data_dict

func setup_manager_flow() -> void:
	GameManager.managers.get_or_add(_get_manager_name(), self)

	is_busy = true
	setup_complete = false

	await _setup()

	setup_complete = true
	is_busy = false
	setup_completed.emit()

	if debug_mode:
		print("%s: Setup Completed!" % _get_manager_name())

func execute_manager_flow() -> void:

	is_busy = true
	execute_complete = false

	await _execute()

	execute_complete = true
	is_busy = false
	execution_completed.emit()

	if debug_mode:
		print("%s: Execution Completed!" % _get_manager_name())
