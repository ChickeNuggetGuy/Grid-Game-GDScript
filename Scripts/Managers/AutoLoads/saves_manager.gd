extends Node

const SAVES_MANAGER_KEY := "__SavesManager"
const SCENE_MANAGER_KEY := "__SceneManager"
const LEGACY_GAME_MANAGER_KEY := "GameManager"

signal save_games_changed()

var map_size: Vector2i = Vector2i.ZERO
var spawn_counts: Vector2i = Vector2i.ZERO
var current_save_file := ""
var save_directory := "user://saves"

var pending_load_data: Dictionary = {}



func _ready() -> void:
	create_save_directory()

func save_data() -> Dictionary:
	return {
		"map_size": _vector2i_to_dict(map_size),
		"spawn_counts": _vector2i_to_dict(spawn_counts),
		"current_save_file": current_save_file,
	}

func load_from_save(data: Dictionary) -> void:
	if data.has("map_size"):
		map_size = _dict_to_vector2i(data["map_size"])

	if data.has("spawn_counts"):
		spawn_counts = _dict_to_vector2i(data["spawn_counts"])

	if data.has("current_save_file"):
		current_save_file = str(data["current_save_file"])

func load_legacy_game_manager_data(data: Dictionary) -> void:
	if data.has("map_size"):
		map_size = _variant_to_vector2i(data["map_size"])

	if data.has("spawn_counts"):
		spawn_counts = _variant_to_vector2i(data["spawn_counts"])

	if data.has("current_save_file"):
		current_save_file = str(data["current_save_file"])

	if data.has("current_scene_type"):
		SceneManager.load_legacy_scene_type(data["current_scene_type"])

func clear_pending_load_data() -> void:
	pending_load_data.clear()

func load_current_game_data(data: Dictionary) -> void:
	if data.is_empty():
		print("No data to load")
		pending_load_data.clear()
		return

	pending_load_data = data.duplicate(true)
	_apply_autoload_data_from_pending()

func apply_before_execute_load_data() -> void:
	for manager_name in pending_load_data.keys():
		if not GameManager.managers.has(manager_name):
			print("Manager not found for loading data: " + str(manager_name))
			continue

		var manager: Manager = GameManager.managers[manager_name]
		if manager.data_load_timing == Manager.DataLoadTiming.BEFORE_EXECUTE:
			manager.load_data_call(pending_load_data[manager_name])

func apply_deferred_load_data(manager: Manager) -> void:
	if manager == null:
		return

	var manager_name := manager._get_manager_name()

	if not pending_load_data.has(manager_name):
		return

	if manager.data_load_timing == Manager.DataLoadTiming.AFTER_EXECUTE:
		manager.load_data_call(pending_load_data[manager_name])

func _apply_autoload_data_from_pending() -> void:
	if pending_load_data.has(SAVES_MANAGER_KEY):
		load_from_save(pending_load_data[SAVES_MANAGER_KEY])
		pending_load_data.erase(SAVES_MANAGER_KEY)

	if pending_load_data.has(SCENE_MANAGER_KEY):
		SceneManager.load_from_save(pending_load_data[SCENE_MANAGER_KEY])
		pending_load_data.erase(SCENE_MANAGER_KEY)

	if pending_load_data.has(LEGACY_GAME_MANAGER_KEY):
		load_legacy_game_manager_data(pending_load_data[LEGACY_GAME_MANAGER_KEY])
		pending_load_data.erase(LEGACY_GAME_MANAGER_KEY)

func _get_managers_data(all_managers: bool) -> Dictionary:
	var data_dictionary: Dictionary = {}
	var manager_nodes = get_tree().get_nodes_in_group("manager")

	for node in manager_nodes:
		if not node is Manager:
			continue

		var manager := node as Manager

		if not all_managers and not manager.save_on_scene_change:
			continue

		print("Saving data for: " + manager._get_manager_name())
		data_dictionary[manager._get_manager_name()] = manager.save_data()

	if all_managers:
		data_dictionary[SAVES_MANAGER_KEY] = save_data()
		data_dictionary[SCENE_MANAGER_KEY] = SceneManager.save_data()

	return data_dictionary

func save_scene_change_data(current_scene_type: int) -> Dictionary:
	var manager_data = _get_managers_data(false)

	var scene_save_data := {}
	var scene_name := SceneManager.get_scene_type_name(current_scene_type)
	scene_save_data[scene_name] = manager_data

	return scene_save_data

func build_scene_transition_data(
	current_scene_type: int,
	extra_data: Dictionary
) -> Dictionary:
	var transition_data: Dictionary = {}

	if current_scene_type != Enums.SceneType.NONE:
		var nested_data = save_scene_change_data(current_scene_type)
		var scene_name := SceneManager.get_scene_type_name(current_scene_type)

		if nested_data.has(scene_name):
			transition_data = nested_data[scene_name].duplicate(true)

	for key in extra_data:
		transition_data[key] = extra_data[key]

	return transition_data

func get_current_scene_data(current_scene_type: int) -> Dictionary:
	var manager_data = _get_managers_data(true)

	if current_save_file == "":
		current_save_file = "new save file"

	var scene_save_data := {}
	var scene_name := SceneManager.get_scene_type_name(current_scene_type)
	scene_save_data[scene_name] = manager_data

	return scene_save_data

func get_game_data_from_save(save_name: String) -> Dictionary:
	if save_name.is_empty():
		if current_save_file.is_empty():
			print("Save file name empty!")
			return {}
		save_name = current_save_file

	if not save_name.ends_with(".json"):
		save_name += ".json"

	var full_path = save_directory.path_join(save_name)
	var save_file := FileAccess.open(full_path, FileAccess.READ)

	if not save_file:
		print("Error: Could not open save file: ", full_path)
		return {}

	var json_string := save_file.get_as_text()
	save_file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)

	if parse_result != OK:
		print("JSON Parse Error: ", json.get_error_message())
		return {}

	return json.data

func create_save_directory() -> void:
	var absolute_path := ProjectSettings.globalize_path(save_directory)

	if DirAccess.dir_exists_absolute(absolute_path):
		return

	var err := DirAccess.make_dir_recursive_absolute(absolute_path)
	if err != OK and err != ERR_ALREADY_EXISTS:
		print("Failed to create saves directory: ", error_string(err))

func save_game_data(
	data_to_save: Dictionary,
	save_name: String,
	load_file: bool = false
) -> bool:
	if save_name.is_empty():
		print("Error: Save name cannot be empty")
		return false

	if not save_name.ends_with(".json"):
		save_name += ".json"

	var invalid_chars = ["<", ">", ":", "\"", "/", "\\", "|", "?", "*"]
	for invalid_char in invalid_chars:
		if save_name.contains(invalid_char):
			print("Error: Invalid character in filename: ", invalid_char)
			return false

	create_save_directory()

	var full_path = save_directory.path_join(save_name)
	print("Saving to: ", ProjectSettings.globalize_path(full_path))

	var file := FileAccess.open(full_path, FileAccess.WRITE)

	if not file:
		print("Error saving data to: ", full_path)
		return false

	file.store_string(JSON.stringify(data_to_save, "\t"))
	file.close()

	current_save_file = save_name
	save_games_changed.emit()

	print("Data saved successfully to: ", full_path)

	if load_file:
		await SceneManager.try_load_scene_by_type(
			SceneManager.current_scene_type,
			{}
		)

	return true

func load_game_data(save_name: String) -> void:
	var data = get_game_data_from_save(save_name)
	if data.is_empty():
		return

	if not save_name.ends_with(".json"):
		save_name += ".json"

	current_save_file = save_name

	var scene_keys := data.keys()
	if scene_keys.is_empty():
		print("Save file has no scene data")
		return

	var scene_name := str(scene_keys[0])
	var manager_data: Dictionary = data[scene_name]
	var target_scene_type := SceneManager.get_scene_type_from_name(scene_name)

	await SceneManager.change_scene(target_scene_type, manager_data)

func delete_save_file_absolute(file_name: String) -> void:
	if not file_name.ends_with(".json"):
		file_name += ".json"

	var path := save_directory.path_join(file_name)

	if FileAccess.file_exists(path):
		var error := DirAccess.remove_absolute(path)
		if error == OK:
			print("Successfully deleted save file: " + path)
			save_games_changed.emit()
		else:
			print("Error deleting file: ", error_string(error))
	else:
		print("Save file not found, nothing to delete: " + path)

func try_load_save_game_files() -> Dictionary:
	create_save_directory()

	var save_files: Array[String] = []
	var ret_val := {
		"success": false,
		"save_files": save_files,
	}

	var absolute_path := ProjectSettings.globalize_path(save_directory)
	print("Scanning save directory: ", absolute_path)

	var dir := DirAccess.open(save_directory)
	if dir == null:
		push_warning("Could not access directory: " + absolute_path)
		return ret_val

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			if file_name.get_extension().to_lower() == "json":
				save_files.append(file_name)

		file_name = dir.get_next()

	dir.list_dir_end()

	save_files.sort()

	ret_val["success"] = true
	ret_val["save_files"] = save_files
	return ret_val

func create_new_game(
	save_name: String,
	start_scene_type: int,
	initial_data: Dictionary = {}
) -> bool:
	if save_name.is_empty():
		push_warning("Cannot create new game with empty save name.")
		return false

	if not save_name.ends_with(".json"):
		save_name += ".json"

	current_save_file = save_name
	clear_pending_load_data()

	var changed_scene := await SceneManager.change_scene(
		start_scene_type,
		initial_data
	)

	if not changed_scene:
		push_warning("Failed to create new game: scene change failed.")
		return false

	var data_to_save := get_current_scene_data(SceneManager.current_scene_type)
	return await save_game_data(data_to_save, save_name, false)



func _vector2i_to_dict(value: Vector2i) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y,
	}

func _dict_to_vector2i(value: Dictionary) -> Vector2i:
	return Vector2i(
		int(value.get("x", 0)),
		int(value.get("y", 0))
	)

func _variant_to_vector2i(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value

	if value is Dictionary:
		return _dict_to_vector2i(value)

	return Vector2i.ZERO
