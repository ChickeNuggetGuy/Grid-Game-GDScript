@abstract extends  Resource
class_name BaseActionDefinition

@export_category("Core")
var script_path : String
var action_script: Script
@export_category("Core")
@export var action_name: String
@export_category("Core")
@export var show_in_ui: bool = false
@export_category("Core")
@export var cost: int

@abstract func can_execute(parameters : Dictionary) -> Dictionary

func _init() -> void:
	if script_path == null or script_path == "":
		push_error("Script path for: " + self.action_name+ " is invalid!")
		return
	load_action_script()


func load_action_script():
		action_script = load(script_path)


func instantiate(parameters : Dictionary) -> Action:
	if action_script == null:
		load_action_script()
	var a: Action = action_script.new(parameters)
	a.action_name  = self.resource_name

	return a
