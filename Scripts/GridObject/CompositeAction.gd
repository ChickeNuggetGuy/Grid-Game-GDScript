@abstract extends  Action
class_name CompositeAction

var sub_actions: Array[Action] = []


func _init(_name: String, actions: Array[Action]) -> void:
	name = _name
	sub_actions = actions
	# compute total cost by summing each child's cost
	for a in sub_actions:
		cost += a.cost


func _execute() -> void:
	# execute each sub‐action in turn
	for a in sub_actions:
		a.owner = owner
		await a.execute_call()

@abstract func _setup()
