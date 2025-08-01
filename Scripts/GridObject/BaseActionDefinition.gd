@abstract extends  Resource
class_name BaseActionDefinition

@export_category("Core")
@export_file_path() var script_path : String = ""
var action_script: Script
@export_category("Core")
@export var name: String
@export_category("Core")
@export var cost: int

@abstract func can_execute(parameters : Dictionary) -> Dictionary

func _init() -> void:
	load_action_script


func load_action_script():
		action_script = load(script_path)


func instantiate(parameters : Dictionary) -> Action:
	if action_script == null:
		load_action_script()
	var a: Action = action_script.new(parameters)
	a.name  = self.resource_name

	return a
