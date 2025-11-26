extends Manager

enum sceneType {NONE = 0,MAINMENU, BATTLESCENE, GLOBE}

@export var scene_dictionary: Dictionary[sceneType, String]
@export var current_scene_node: Node
@export var current_scene_type: sceneType
@onready var managers_node
var managers : Dictionary[String, Manager] = {}
var map_size : Vector2i
var spawn_counts : Vector2i
var current_save_file : String
var save_directory := "/Users/malikhawkins/Godot Projects /Grid-Game-GDScript/testSaves/"


signal current_scene_changed(current_scene : Node)
signal save_games_changed()

func _init() -> void:
	add_to_group("manager")
	current_scene_type = sceneType.MAINMENU
	scene_dictionary[sceneType.MAINMENU] = "res://Scenes/GameScenes/MainMenuScene.tscn"
	scene_dictionary[sceneType.BATTLESCENE] = "res://Scenes/GameScenes/BattleScene.tscn"
	scene_dictionary[sceneType.GLOBE] = "res://Scenes/GameScenes/GlobeScene.tscn"

func _ready() -> void:
	current_scene_changed.connect(on_scene_changed)
	await get_tree().process_frame
	try_load_scene_by_type(sceneType.MAINMENU, {})

func _get_manager_name() -> String: 
	return "GameManager"

func _setup_conditions() -> bool:
	return true

func _setup():
	if managers_node == null:
		managers_node = get_tree().get_first_node_in_group("Managers")

	if current_scene_node != null:
		print("GameManager: Initial scene identified as '", current_scene_type, "'")
	else:
		push_warning("GameManager: SceneContainer is empty on startup.")
		
	setup_completed.emit()

func _execute_conditions() -> bool:
	return true

func _execute():
	var nodes : Array[Node] = get_tree().get_nodes_in_group("manager")
	
	print("Nodes length: " + str(nodes.size()))
	for node in nodes:
		if node is Manager and node != self:
			managers[node._get_manager_name()] = node
			var manager_instance: Manager = node
				
			await manager_instance.setup_manager_flow()
			print(manager_instance._get_manager_name() + " setup finished!")

	for manager_name in managers:
		var manager = managers[manager_name]
		if manager != self:
			await manager.execute_manager_flow()
			
			if load_data.has(manager._get_manager_name()):
				if manager.data_load_timing == Enums.DataLoadTiming.AFTEREXECUTE:
					print("Loading data for: " + manager._get_manager_name())
					manager.load_data_call(load_data[manager._get_manager_name()])
			print(manager._get_manager_name() + " execute finished!")

	execution_completed.emit()

func sort_manager_priority(manager_a : Manager, manager_b : Manager) -> bool:
	return manager_a.priority < manager_b.priority

func on_scene_changed(_new_scene: Node = null) -> void:
	print("on_scene_changed called")

func save_data() -> Dictionary:
	var save_dict = {
		"filename" : get_scene_file_path(),
		"parent" : get_parent().get_path(),
		"current_scene_node" : current_scene_node,
		"map_size": map_size,
		"spawn_counts" :  spawn_counts,
		"current_save_file" : current_save_file,
		"current_scene_type" : current_scene_type
	}
	return save_dict


func quit_game():
	get_tree().quit()

func change_scene(scene_type: sceneType, data_to_load: Dictionary) -> bool:
	if scene_type not in scene_dictionary:
		push_error("Scene not found in dictionary: " + str(scene_type))
		return false

	var nested_data = save_scene_change_data()
	var scene_name_key = sceneType.find_key(current_scene_type)
	var new_data = nested_data[scene_name_key]
	
	if not data_to_load.is_empty():
		for key in data_to_load:
			new_data[key] = data_to_load[key]

	var scene_path := scene_dictionary[scene_type]
	current_scene_type = scene_type

	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("Failed to change scene to: %s" % scene_path)
		return false

	await get_tree().process_frame
	
	var timeout = 60
	while get_tree().current_scene == null and timeout > 0:
		await get_tree().process_frame
		timeout -= 1

	var new_root := get_tree().current_scene
	if new_root == null:
		push_error("Timed out waiting for current_scene after change.")
		return false

	if not new_root.is_node_ready():
		await new_root.ready
	
	await get_tree().process_frame
	
	current_scene_node = new_root
	await handle_scene_change_complete(new_data)
	
	return true


func handle_scene_change_complete(data_to_load: Dictionary):
	managers.clear()
	
	var nodes: Array[Node] = get_tree().get_nodes_in_group("manager")
	print("Discovered " + str(nodes.size()) + " manager nodes")
	
	for node in nodes:
		if node is Manager and node != self:
			managers[node._get_manager_name()] = node
	
	if not data_to_load.is_empty():
		load_current_game_data(data_to_load)
		
	for manager_name in managers:
		var manager: Manager = managers[manager_name]
		await manager.setup_manager_flow()
		print(manager_name + " setup finished!")
	

	for manager_name in managers:
		var manager: Manager = managers[manager_name]
		if manager != self:
			await manager.execute_manager_flow()
			print(manager_name + " execute finished!")
	

	
	current_scene_changed.emit(current_scene_node)


func _get_managers_data(all_managers: bool) -> Dictionary:
	var data_dictionary: Dictionary = {}
	var manager_nodes = get_tree().get_nodes_in_group("manager")
	
	for node in manager_nodes:
		if not node is Manager:
			continue
		var manager: Manager = node as Manager
		
		# If we're not getting all managers, check the save_on_scene_change flag
		if not all_managers and not manager.save_on_scene_change:
			continue
		
		print("Saving data for: " + manager._get_manager_name())
		data_dictionary[manager._get_manager_name()] = manager.save_data()
		
	return data_dictionary


func save_scene_change_data() -> Dictionary:
	var manager_data = _get_managers_data(false) # false = only managers with save_on_scene_change
	
	var scene_save_data := {}
	var scene_name = sceneType.find_key(current_scene_type)
	scene_save_data[scene_name] = manager_data
	
	return scene_save_data


func try_load_scene_by_type(scene_type: sceneType, data: Dictionary) -> bool:
	return await change_scene(scene_type, data)


func _on_scene_exit():
	await get_tree().process_frame
	current_scene_node = get_tree().current_scene
	current_scene_changed.emit(current_scene_node)


func get_current_scene_data() -> Dictionary:
	var manager_data = _get_managers_data(true) # true = all managers
	
	if current_save_file == "":
		current_save_file = "new save file"
		
	var scene_save_data := {}
	var scene_name = sceneType.find_key(current_scene_type)
	scene_save_data[scene_name] = manager_data
	
	return scene_save_data


func load_current_game_data(data: Dictionary):
	if data.is_empty():
		print("No data to load")
		return
	
	load_data = data
	
	for manager_name in data:
		if managers.has(manager_name):
			var manager: Manager = managers[manager_name]
			
			manager.load_data_call(data[manager_name])
		else:
			print("Manager not found for loading data: " + manager_name)


func get_game_data_from_save(save_name : String) -> Dictionary:
	if save_name.is_empty():
		if current_save_file.is_empty():
			print("Save file name empty!")
			return {}
		else:
			save_name = current_save_file
	
	var full_path = save_directory.path_join(save_name)
	var save_file: FileAccess = FileAccess.open(full_path, FileAccess.READ)
	
	if not save_file:
		print("Error: Could not open save file: ", full_path)
		return {}
	
	var json_string = save_file.get_as_text()
	save_file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("JSON Parse Error: ", json.get_error_message())
		return {}
	
	var data = json.data
	return data

func create_save_directory():
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		var err = dir.make_dir("saves")
		if err != OK:
			print("Failed to create saves directory: ", error_string(err))
			return
	save_games_changed.emit()


func save_game_data(data_to_save: Dictionary, save_name: String, load_file : bool = false):
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
	
	var full_path = save_directory.path_join(save_name)
	var file: FileAccess = FileAccess.open(full_path, FileAccess.WRITE)
	
	if file:
		file.store_string(JSON.stringify(data_to_save, "\t")) 
		file.close()
		save_games_changed.emit()
		print("Data saved successfully to: ", full_path)
		
		if load_file:
			try_load_scene_by_type(current_scene_type,{})
		return true
	else:
		print("Error saving data to: ", full_path)
		return false


func load_game_data(save_name: String):
	var data = get_game_data_from_save(save_name)
	if data.is_empty():
		return
		
	# New loading logic for nested structure
	var scene_name = data.keys()[0]
	var manager_data = data[scene_name]
	var target_scene_type = sceneType[scene_name]
	
	await change_scene(target_scene_type, manager_data)

func delete_save_file_absolute(file_name: String):
	var path = save_directory.path_join(file_name)

	if FileAccess.file_exists(path):
		var error = DirAccess.remove_absolute(path)
		if error == OK:
			print("Successfully deleted save file: " + path)
			save_games_changed.emit()
		else:
			print("Error deleting file: ", error_string(error))
	else:
		print("Save file not found, nothing to delete: " + path)

func try_load_save_game_files() -> Dictionary:
	var save_files: Array = []
	var ret_val = {"success": false, "save_files": save_files}

	var dir = DirAccess.open(save_directory)
	if not dir:
		print("Could not access directory: ", save_directory)
		return ret_val

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			if file_name.get_extension().to_lower() == "json":
				save_files.append(file_name)
		file_name = dir.get_next()

	dir.list_dir_end()
	
	if not save_files.is_empty():
		ret_val["success"] = true

	return ret_val
