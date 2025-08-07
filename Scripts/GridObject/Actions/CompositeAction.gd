@abstract extends  Action
class_name CompositeAction

var sub_actions: Array[Action] = []


func _init(parameters : Dictionary) -> void:
	super._init(parameters)
	action_name = parameters["action_name"]
	if parameters.has("actions"):
		sub_actions =  parameters["actions"]
	else:
		sub_actions = []
	super._init(parameters)


func _execute() -> void:
	# execute each sub‐action in turn
	for a in sub_actions:
		a.owner = owner
		await a.execute_call()

@abstract func _setup()
