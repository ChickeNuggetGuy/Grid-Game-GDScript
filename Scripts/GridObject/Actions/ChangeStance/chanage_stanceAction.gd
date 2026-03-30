extends Action


func _setup() -> void:
	return


func _execute() -> void:
	owner.toggle_stance(Enums.UnitStance.CROUCHED)
	return


func _action_complete():
	return
