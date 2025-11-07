extends Manager

enum sceneType {MAINMENU, BATTLESCENE, GLOBE}

@export var scene_dictionary: Dictionary[sceneType, String]


@export var current_scene_node: Node
@export var current_scene_type: sceneType
@onready var managers_node
var managers : Dictionary[String, Manager] = {}
var map_size : Vector2i
var spawn_counts : Vector2i

signal current_scene_changed(current_scene : Node)


func _init() -> void:
	current_scene_type = sceneType.MAINMENU
	scene_dictionary[sceneType.MAINMENU] = "res://Scenes/GameScenes/MainMenuScene.tscn"
	scene_dictionary[sceneType.BATTLESCENE] = "res://Scenes/GameScenes/BattleScene.tscn"
	scene_dictionary[sceneType.GLOBE] = "res://Scenes/GameScenes/GlobeScene.tscn"




#region Manager Lifecycle
func _get_manager_name() -> String: 
	return "GameManager"


func _setup_conditions() -> bool:
	return true


func _setup():
	
	#if passable_parameters.size() > 0:
		#print("test : " + str(passable_parameters["current_scene_type"]))
		#current_scene_node = passable_parameters["current_scene_node"]
		#current_scene_type = passable_parameters["current_scene_type"]
		##scene_dictionary = passable_parameters["scene_directory"] as Dictionary[sceneType, String]
	if managers_node == null:
		managers_node = get_tree().get_first_node_in_group("Managers")

	if current_scene_node != null:
		#current_scene_name = scene_dictionary.find_key(initial_path)# if scene_dictionary.find_key(initial_path) != null else ""
		print(
			"GameManager: Initial scene identified as '",
			current_scene_type,
			"'"
		)
	else:
		push_warning("GameManager: SceneContainer is empty on startup.")
		
	
	setup_completed.emit()


func _execute_conditions() -> bool:
	return true


func _execute():
	var nodes : Array[Node] = get_tree().get_first_node_in_group("Managers").get_children()
	
	print("Nodes length: " + str(nodes.size()))
	for node in nodes:
		if node is Manager and node != self:
			managers[node.name] = node
			var manager_instance: Manager = node
			await manager_instance.setup_manager_flow()
			print(manager_instance.name + " setup finished!")

	for manmager in managers.values():
		if manmager != self:
			await manmager.execute_manager_flow()
			print(manmager.name + " execute finished!")

	execution_completed.emit()

func sort_manager_priority(manager_a : Manager, manager_b : Manager) -> bool:
	return manager_a.priority <  manager_b.priority


func on_scene_changed(new_scene: Node = null) -> void:
	print("on_scene_changed called")
	var ns := new_scene
	if ns == null:
		ns = get_tree().current_scene
	if ns == null:
		push_warning("on_scene_changed: current_scene is still null; retrying next frame.")
		call_deferred("on_scene_changed") # will re-fetch from the tree
		return

	managers.clear()
	managers_node = get_tree().get_first_node_in_group("Managers") # remove the '%'
	print("current_scene_name ", ns.name)
	
	await setup_manager_flow()
	await execute_manager_flow()


func get_passable_data() -> Dictionary:
	var data : Dictionary = {}
	
	data["scene_dictionary"] = scene_dictionary
	data["map_size"] = Vector2(2,2)
	data["spawn_counts"] = Vector2(1,1)
	return data


func set_passable_data(data : Dictionary):
	scene_dictionary = data["scene_dictionary"]
	map_size = data["map_size"]
	spawn_counts = data["spawn_counts"]


#endregion

#region Execution

#endregion


#region Scene Management
func change_scene(scene_type: sceneType) -> bool:
	if scene_type not in scene_dictionary:
		push_error("Scene not found in dictionary: " + str(scene_type))
		return false

	var scene_path := scene_dictionary[scene_type]
	current_scene_type = scene_type

	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("Failed to change scene to: %s" % scene_path)
		return false

	# Wait for scene change to complete
	await get_tree().process_frame
	
	# More robust waiting for current_scene
	var timeout = 60
	while get_tree().current_scene == null and timeout > 0:
		await get_tree().process_frame
		timeout -= 1

	var new_root := get_tree().current_scene
	if new_root == null:
		push_error("Timed out waiting for current_scene after change.")
		return false

	# Wait for the scene to be completely ready
	if not new_root.is_node_ready():
		await new_root.ready
	
	# Additional safety wait
	await get_tree().process_frame
	
	current_scene_node = new_root
	current_scene_changed.emit(new_root)
	
	return true

func _ready() -> void:
	current_scene_changed.connect(on_scene_changed)
	await get_tree().process_frame
	try_load_scene_by_type(sceneType.MAINMENU)


# The 'try_load' functions are now wrappers around the new 'change_scene'.
func try_load_scene_by_type(scene_type: sceneType) -> bool:
	return await change_scene(scene_type)

#
#func try_load_scene_by_path(scene_path: String) -> bool:
	#var scene_name = scene_dictionary.find_key(scene_path)
	#if scene_name == null:
		#push_error("Scene path '%s' not found in dictionary." % scene_path)
		#return false
	#return change_scene(scene_name)


func _on_scene_exit():
	# This runs after the old scene is freed but before the new one is ready
	await get_tree().process_frame  # Wait one frame for new scene to be ready
	current_scene_node = get_tree().current_scene
	current_scene_changed.emit(current_scene_node)
#endregion
