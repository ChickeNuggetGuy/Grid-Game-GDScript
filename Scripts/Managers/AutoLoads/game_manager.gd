extends Node

var managers: Dictionary[String, Manager] = {}

var current_loading_manager_name := ""
var current_loading_phase := ""

signal managers_refreshed()
signal manager_loading_changed(manager_name: String, phase: String)

func clear_managers() -> void:
	managers.clear()
	_set_current_loading_manager("", "")

func refresh_managers_for_scene(scene_root: Node) -> Array[Manager]:
	managers.clear()

	var scene_managers: Array[Manager] = []

	if scene_root == null:
		return scene_managers

	_collect_managers_recursive(scene_root, scene_managers)

	for manager in scene_managers:
		var manager_name := manager._get_manager_name()

		if managers.has(manager_name):
			push_warning("Duplicate manager name detected: %s" % manager_name)

		managers[manager_name] = manager

	managers_refreshed.emit()
	return scene_managers

func _collect_managers_recursive(
	node: Node,
	out_array: Array[Manager]
) -> void:
	if node is Manager:
		out_array.append(node as Manager)

	for child in node.get_children():
		_collect_managers_recursive(child, out_array)

func get_manager(manager_name: String) -> Manager:
	if not managers.has(manager_name):
		return null
	return managers[manager_name]

func get_loading_label() -> String:
	if current_loading_manager_name.is_empty():
		return current_loading_phase

	if current_loading_phase.is_empty():
		return current_loading_manager_name

	return "%s %s" % [current_loading_phase, current_loading_manager_name]

func _set_current_loading_manager(manager_name: String, phase: String) -> void:
	current_loading_manager_name = manager_name
	current_loading_phase = phase
	manager_loading_changed.emit(manager_name, phase)
	SceneManager.set_loading_manager_name(manager_name, phase)

func setup_and_execute_scene_managers(
	scene_root: Node,
	data_to_load: Dictionary = {},
	loading_screen: Node = null
) -> void:
	var scene_managers := refresh_managers_for_scene(scene_root)

	print("Discovered %s managers in new scene" % scene_managers.size())

	if not data_to_load.is_empty():
		SavesManager.load_current_game_data(data_to_load)
	else:
		SavesManager.clear_pending_load_data()

	var total_steps: int = max(scene_managers.size() * 2, 1)
	var current_step := 0

	for manager in scene_managers:
		_set_current_loading_manager(manager._get_manager_name(), "Setting up")
		_update_loading_progress(
			loading_screen,
			current_step,
			total_steps,
			get_loading_label()
		)
		await get_tree().process_frame

		await manager.setup_manager_flow()

		current_step += 1
		_update_loading_progress(
			loading_screen,
			current_step,
			total_steps,
			get_loading_label()
		)

		print("%s setup finished!" % manager._get_manager_name())

	SavesManager.apply_before_execute_load_data()

	for manager in scene_managers:
		_set_current_loading_manager(manager._get_manager_name(), "Executing")
		_update_loading_progress(
			loading_screen,
			current_step,
			total_steps,
			get_loading_label()
		)
		await get_tree().process_frame

		if manager.wait_for_loading_completion:
			await manager.execute_manager_flow()
		else:
			manager.execute_manager_flow()

		current_step += 1
		_update_loading_progress(
			loading_screen,
			current_step,
			total_steps,
			get_loading_label()
		)

		SavesManager.apply_deferred_load_data(manager)

		print("%s execute finished!" % manager._get_manager_name())

	_set_current_loading_manager("", "")
	SavesManager.clear_pending_load_data()

func _update_loading_progress(
	loading_screen: Node,
	current_step: int,
	total_steps: int,
	text: String
) -> void:
	var percent_complete := float(current_step) / float(max(total_steps, 1))
	var final_value := SceneManager.LOAD_PHASE_PERCENT + (
		percent_complete * (1.0 - SceneManager.LOAD_PHASE_PERCENT)
	)

	SceneManager.set_loading_progress(final_value, text)

	if loading_screen == null:
		return

	if not loading_screen.has_method("update_progress"):
		return

	loading_screen.update_progress(final_value, text)
