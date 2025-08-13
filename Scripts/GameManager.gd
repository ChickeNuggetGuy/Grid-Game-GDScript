extends Manager
class_name GameManager


@export var scene_dictionary: Dictionary[String, String]


@export var current_scene_node: Node
@export var current_scene_name: String

signal current_scene_changed(current_scene : Node)


func	_ready() -> void:
	super._ready()
	
	await setup_manager_flow()
	await execute_manager_flow()
	#try_load_scene_by_name("MainMenuScene")

func _on_exit_tree() -> void:
	return


#region Manager Lifecycle
func _get_manager_name() -> String: 
	return "GameManager"


func _setup_conditions() -> bool:
	return true


func _setup():
	

	if passable_parameters.size() > 0:
		print("test : " +  passable_parameters["current_scene_name"])
		current_scene_node = passable_parameters["current_scene_node"]
		current_scene_name = passable_parameters["current_scene_name"]
	# On game start, identify the initial scene already inside the container.
	if current_scene_node != null:
		#current_scene_name = scene_dictionary.find_key(initial_path)# if scene_dictionary.find_key(initial_path) != null else ""
		print(
			"GameManager: Initial scene identified as '",
			current_scene_name,
			"'"
		)
	else:
		push_warning("GameManager: SceneContainer is empty on startup.")
		
	
	setup_completed.emit()


func _execute_conditions() -> bool:
	return true


func _execute():
	var nodes : Array[Node] = get_children()
	
	print(nodes.size())
	for node in nodes:
		if node is Manager and node != self:
			var manager_instance: Manager = node
			await manager_instance.setup_manager_flow()
			print(manager_instance.name + " setup finished!")

	for node in nodes:
		if node is Manager and node != self:
			var manager_instance: Manager = node
			await manager_instance.execute_manager_flow()
			print(manager_instance.name + " execute finished!")

	execution_completed.emit()

func sort_manager_priority(manager_a : Manager, manager_b : Manager) -> bool:
	return manager_a.priority <  manager_b.priority


func on_scene_changed(new_scen: Node):
	call_deferred("execute_manager_flow")
	print( "current_scene_name " + current_scene_name)
#endregion


#region Scene Management
func change_scene(scene_name: String) -> bool:
	if not scene_dictionary.has(scene_name):
		push_error("Scene name '%s' not found in dictionary." % scene_name)
		return false

	var scene_path = scene_dictionary[scene_name]

	if current_scene_node != null and current_scene_node.scene_file_path == scene_path:
		push_warning("Attempted to load the same scene.")
		return true

	var next_scene_resource = load(scene_path)
	if next_scene_resource == null:
		push_error("Failed to load scene from path: %s" % scene_path)
		return false

	# Update parameters before scene change
	passable_parameters["current_scene_name"] = scene_name
	
	# Change scene
	if is_instance_valid(current_scene_node):
		current_scene_node.queue_free()
	
	current_scene_name = scene_name
	current_scene_node = next_scene_resource.instantiate()
	get_tree().root.add_child(current_scene_node)
	
	# Update node reference after instantiation
	passable_parameters["current_scene_node"] = current_scene_node
	
	print("Changed scene to: '%s'" % current_scene_name)
	current_scene_changed.emit(current_scene_node)
	return true


# The 'try_load' functions are now wrappers around the new 'change_scene'.
func try_load_scene_by_name(scene_name: String) -> bool:
	return change_scene(scene_name)


func try_load_scene_by_path(scene_path: String) -> bool:
	var scene_name = scene_dictionary.find_key(scene_path)
	if scene_name == null:
		push_error("Scene path '%s' not found in dictionary." % scene_path)
		return false
	return change_scene(scene_name)
#endregion
