extends RefCounted
class_name CompositeAction

var name: String
var sub_actions: Array[Action] = []
var cost: int = 0
var owner: Node = null

func _init(_name: String, actions: Array[Action]) -> void:
	name = _name
	sub_actions = actions
	# compute total cost by summing each child's cost
	cost = 0
	for a in sub_actions:
		cost += a.cost

func can_execute() -> bool:
	return owner.ap >= cost

func execute() -> void:
	# reserve AP up front
	owner.ap -= cost

	# execute each sub‐action in turn
	for a in sub_actions:
		a.owner = owner
		# in Godot 4.5 you can use await instead of yield
		await a.execute()
	# when you return/complete, any awaiting caller continues
