# GameManager.gd
extends Manager

#region Functions

func _get_manager_name() -> String:
	return "GameManager"

func _setup_conditions() -> bool:return true

func _setup():
	print("GameManager: Starting its own _setup()...")
	# All actual setup tasks for GameManager would go here.
	# Example: Loading configuration files, setting up singleton sub-systems, etc.
	await get_tree().create_timer(0.1).timeout # Small delay to simulate work

	print("GameManager: Own _setup() complete.")
	# IMPORTANT: Emit the signal from THIS instance.
	# 'self.setup_completed.emit()' is more explicit and safer here.
	setup_completed.emit()


func _execute_conditions() -> bool:return true

func _execute():
	print("GameManager: Starting _execute() - Orchestrating other managers...")
	var manager_group_name = "Managers"
	var manager_nodes = get_tree().get_nodes_in_group(manager_group_name)

	# --- Orchestrate Setup of Sub-Managers ---
	print("GameManager: Orchestrating sub-manager setups...")
	for node in manager_nodes:
		if node is Manager and node != self:
			var manager_instance: Manager = node
			print("  GameManager: Calling setup_manager_flow() on %s" % manager_instance._get_manager_name())
			await manager_instance.setup_manager_flow()
			print("  GameManager: %s setup complete." % manager_instance._get_manager_name())

	print("GameManager: All sub-managers setup complete.")

	# --- Orchestrate Execution of Sub-Managers ---
	print("GameManager: Orchestrating sub-manager executions...")
	for node in manager_nodes:
		if node is Manager and node != self:
			var manager_instance: Manager = node
			print("  GameManager: Calling execute_manager_flow() on %s" % manager_instance._get_manager_name())
			await manager_instance.execute_manager_flow()
			print("  GameManager: %s execution complete." % manager_instance._get_manager_name())

	print("GameManager: All sub-managers execution complete.")
	# IMPORTANT: Emit the signal from THIS instance.
	execution_completed.emit()

func _ready():
	# Perform the initial setup flow for *this GameManager instance*.
	# Await its completion before proceeding.
	# The setup_manager_flow() call itself contains an 'await setup_completed'
	# that is waiting for the signal emitted by this GameManager's _setup() method.
	await setup_manager_flow()
	print("GameManager: Own setup flow completed in _ready().")

	# Once this GameManager is fully set up, proceed to orchestrate other managers.
	await execute_manager_flow()
	print("GameManager: All manager flows orchestrated.")

#endregion
