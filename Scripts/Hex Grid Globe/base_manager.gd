extends Manager

var bases : Dictionary[Enums.unitTeam, Array] = {}


#region Manager Functions
func _get_manager_name() -> String: return "BaseManager"


func save_data() -> Dictionary:
	return {}


func _setup_conditions() -> bool : return true


func _setup():
	setup_complete = true
	setup_completed.emit()


func _execute_conditions() -> bool : return true


func _execute(): 
	pass
#endregion
