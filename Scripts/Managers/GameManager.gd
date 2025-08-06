# GameManager.gd
extends Manager

#region Functions

func _get_manager_name() -> String:
	return "GameManager"

func _setup_conditions() -> bool:return true

func _setup():
	await get_tree().create_timer(0.1).timeout 
	setup_completed.emit()


func _execute_conditions() -> bool:return true

func _execute():
	print("GameManager: Starting _execute() - Orchestrating other managers...")
	var manager_group_name = "Managers"
	var manager_nodes = get_tree().get_nodes_in_group(manager_group_name)


	for node in manager_nodes:
		if node is Manager and node != self:
			var manager_instance: Manager = node
			await manager_instance.setup_manager_flow()
	
	
	
	for node in manager_nodes:
		if node is Manager and node != self:
			var manager_instance: Manager = node
			await manager_instance.execute_manager_flow()

	# IMPORTANT: Emit the signal from THIS instance.
	execution_completed.emit()

func _ready():
	await setup_manager_flow()

	# Once this GameManager is fully set up, proceed to orchestrate other managers.
	await execute_manager_flow()

#endregion
