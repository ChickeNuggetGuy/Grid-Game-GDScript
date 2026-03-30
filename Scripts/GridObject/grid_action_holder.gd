extends Node

var ap: int = 10
var action_queue: Array[Action] = []

func queue_action(a: Action) -> void:
	#a.owner = self
	if not a.can_execute():
		push_error("Not enough AP for %s" % a.name)
		return
	action_queue.append(a)

func _process(_dt):
	if action_queue.size() and not is_executing:
		_execute_next()

var is_executing := false

func _execute_next() -> void:
	is_executing = true
	var a = action_queue.pop_front()
	# start the coroutine
	call_deferred("_run_action", a)

func _run_action(a: Action) -> void:
	await a.execute()
	is_executing = false
