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


func _execute() -> bool:
	# execute each sub‐action in turn
	if request_cancel_action:
		return false
		
	for a in sub_actions:
		if request_cancel_action:
			return false
		a.owner = owner
		await a.execute_call()
		print(a.action_name + " is being executed")
	
	return true
@abstract func _setup()
