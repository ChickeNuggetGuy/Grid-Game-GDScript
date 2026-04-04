extends Node

const LOAD_PHASE_PERCENT := 0.6

var scene_dictionary: Dictionary = {}
var current_scene_node: Node = null
var current_scene_type: int = Enums.SceneType.NONE
var startup_scene_type: int = Enums.SceneType.MAINMENU

var session_data: Dictionary = {}

var current_loading_manager_name := ""
var current_loading_phase := ""
var current_loading_text := ""
var current_loading_progress := 0.0

signal current_scene_changed(current_scene: Node)
signal loading_status_changed(
	progress: float,
	text: String,
	manager_name: String,
	phase: String
)

func set_session_value(key: String, value: Variant) -> void:
	session_data[key] = value

func get_session_value(key: String, default_value: Variant = null) -> Variant:
	return session_data.get(key, default_value)

func has_session_value(key: String) -> bool:
	return session_data.has(key)

func erase_session_value(key: String) -> void:
	session_data.erase(key)

func clear_session_data() -> void:
	session_data.clear()

func _ready() -> void:
	_build_default_scene_dictionary()
	await get_tree().process_frame
	await try_load_scene_by_type(startup_scene_type, {})

func _build_default_scene_dictionary() -> void:
	scene_dictionary[Enums.SceneType.MAINMENU] = (
		"res://Scenes/GameScenes/MainMenuScene.tscn"
	)
	scene_dictionary[Enums.SceneType.BATTLESCENE] = (
		"res://Scenes/GameScenes/BattleScene.tscn"
	)
	scene_dictionary[Enums.SceneType.GLOBE] = (
		"res://Scenes/GameScenes/GlobeScene.tscn"
	)
	scene_dictionary[Enums.SceneType.LOADING] = (
		"res://Scenes/GameScenes/loading_screen.tscn"
	)
	scene_dictionary[Enums.SceneType.BASE] = (
		"res://Scenes/GameScenes/base_scene.tscn"
	)

func save_data() -> Dictionary:
	return {
		"current_scene_type": get_scene_type_name(current_scene_type),
	}

func load_from_save(data: Dictionary) -> void:
	if not data.has("current_scene_type"):
		return

	load_legacy_scene_type(data["current_scene_type"])

func load_legacy_scene_type(value: Variant) -> void:
	if value is String:
		current_scene_type = get_scene_type_from_name(value)
	elif value is int:
		current_scene_type = value

func get_scene_type_name(scene_type: int) -> String:
	match scene_type:
		Enums.SceneType.NONE:
			return "NONE"
		Enums.SceneType.MAINMENU:
			return "MAINMENU"
		Enums.SceneType.BATTLESCENE:
			return "BATTLESCENE"
		Enums.SceneType.GLOBE:
			return "GLOBE"
		Enums.SceneType.LOADING:
			return "LOADING"
		Enums.SceneType.BASE:
			return "BASE"
		_:
			return "NONE"

func get_scene_type_from_name(scene_name: String) -> int:
	match scene_name:
		"NONE":
			return Enums.SceneType.NONE
		"MAINMENU":
			return Enums.SceneType.MAINMENU
		"BATTLESCENE":
			return Enums.SceneType.BATTLESCENE
		"GLOBE":
			return Enums.SceneType.GLOBE
		"LOADING":
			return Enums.SceneType.LOADING
		"BASE":
			return Enums.SceneType.BASE
		_:
			push_error("Unknown scene type name: " + scene_name)
			return Enums.SceneType.NONE

func quit_game() -> void:
	get_tree().quit()

func get_loading_label() -> String:
	if current_loading_manager_name.is_empty():
		return current_loading_text

	if current_loading_phase.is_empty():
		return current_loading_manager_name

	return "%s %s" % [current_loading_phase, current_loading_manager_name]

func set_loading_manager_name(manager_name: String, phase: String = "") -> void:
	current_loading_manager_name = manager_name
	current_loading_phase = phase

	if manager_name.is_empty():
		if phase.is_empty():
			current_loading_text = "Loading"
		else:
			current_loading_text = phase
	else:
		if phase.is_empty():
			current_loading_text = manager_name
		else:
			current_loading_text = "%s %s" % [phase, manager_name]

	loading_status_changed.emit(
		current_loading_progress,
		current_loading_text,
		current_loading_manager_name,
		current_loading_phase
	)

func set_loading_progress(progress: float, text: String = "") -> void:
	current_loading_progress = progress

	if not text.is_empty():
		current_loading_text = text

	loading_status_changed.emit(
		current_loading_progress,
		current_loading_text,
		current_loading_manager_name,
		current_loading_phase
	)

func request_load_scene_by_type(scene_type: int, data: Dictionary) -> bool:
	return await change_scene(scene_type, data)

func try_load_scene_by_type(scene_type: int, data: Dictionary) -> bool:
	return await change_scene(scene_type, data)

func change_scene(
	target_scene_type: Enums.SceneType,
	data_to_load: Dictionary
) -> bool:
	if not scene_dictionary.has(target_scene_type):
		push_error("Scene not found: " + str(target_scene_type))
		return false

	set_loading_manager_name("", "Preparing scene")
	set_loading_progress(0.0, "Preparing scene")

	var merged_load_data := SavesManager.build_scene_transition_data(
		current_scene_type,
		data_to_load
	)

	var loading_scene_path = scene_dictionary.get(Enums.SceneType.LOADING, "")
	if loading_scene_path.is_empty():
		push_error("Loading scene path is not configured.")
		return false

	var change_result := get_tree().change_scene_to_file(loading_scene_path)
	if change_result != OK:
		push_error("Failed to load loading scene: " + error_string(change_result))
		return false

	await get_tree().process_frame
	await get_tree().process_frame

	var loading_screen_node := get_tree().current_scene
	var target_scene_path = scene_dictionary[target_scene_type]

	var loader_status := ResourceLoader.load_threaded_request(target_scene_path)
	if loader_status != OK:
		push_error(
			"Failed to start threaded load for: %s" % target_scene_path
		)
		return false

	var progress_array := []
	var load_status := ResourceLoader.THREAD_LOAD_IN_PROGRESS

	while load_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		load_status = ResourceLoader.load_threaded_get_status(
			target_scene_path,
			progress_array
		)

		var raw_progress := 0.0
		if progress_array.size() > 0:
			raw_progress = float(progress_array[0])

		var actual_progress := raw_progress * LOAD_PHASE_PERCENT
		set_loading_manager_name("", "Loading scene resource")
		set_loading_progress(actual_progress, "Loading scene resource")

		if loading_screen_node != null and loading_screen_node.has_method(
			"update_progress"
		):
			loading_screen_node.update_progress(
				actual_progress,
				current_loading_text
			)

		await get_tree().process_frame

	if load_status != ResourceLoader.THREAD_LOAD_LOADED:
		push_error("Threaded scene load failed for: " + target_scene_path)
		return false

	var packed_scene := ResourceLoader.load_threaded_get(target_scene_path)
	if packed_scene == null or not packed_scene is PackedScene:
		push_error("Loaded resource is not a PackedScene: " + target_scene_path)
		return false

	var new_scene_instance := (packed_scene as PackedScene).instantiate()
	get_tree().root.add_child(new_scene_instance)

	await GameManager.setup_and_execute_scene_managers(
		new_scene_instance,
		merged_load_data,
		loading_screen_node
	)

	get_tree().current_scene = new_scene_instance
	current_scene_node = new_scene_instance
	current_scene_type = target_scene_type

	set_loading_manager_name("", "Done")
	set_loading_progress(1.0, "Done")

	if loading_screen_node != null:
		loading_screen_node.queue_free()

	current_scene_changed.emit(new_scene_instance)
	return true
