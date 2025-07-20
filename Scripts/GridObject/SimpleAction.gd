extends RefCounted
class_name SimpleAction

var name: String
var cost: int
var owner: Node = null
var action_fn: Callable

# _fn is expected to be something like Callable.new(self, "my_async_method", arg1, arg2)
func _init(_name: String, _cost: int, _fn: Callable) -> void:
	name = _name
	cost = _cost
	action_fn = _fn

func can_execute() -> bool:
	return owner.ap >= cost
# note the `async` keyword here

func execute() -> void:
	if not can_execute():
		push_error("Not enough AP for %s" % name)
		return

	# reserve the AP up‐front
	owner.ap -= cost

	# call the bound method; if it's an async func, this will yield until it's done
	await action_fn.call()
