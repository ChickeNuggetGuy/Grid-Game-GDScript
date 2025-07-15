class_name GameManager

extends Manager
#region Variables
@export var managers: Array[Manager]

#endregion 

#region Functions
func  _get_manager_name() -> String: return "GameManager"

func _setup_conditions(): return

func _setup():
	var manager_group
	for group in get_groups():
		if  str(group).contains("Managers"):
			manager_group = group
			
	for manager in get_tree().get_nodes_in_group(manager_group):
		if manager is Manager:
			managers.push_back(manager)
	
	print("Test")
	execute()	
	
	

func _execute_conditions() -> bool: return false

func _execute():
	print("Test")
	if managers.is_empty():
		return
	print("Test")
	for manager in managers:
		if manager is not GameManager:
			manager.setup_call()
		
	for manager in managers:
		if manager is not GameManager:
			manager.execute()


func _ready():
	setup_call()
#endregion
