class_name  UtilityMethods
extends Node

static func get_random_value_with_condition(original_array: Array, condition_func: Callable):
	var filtered_array = []
	for element in original_array:
		if condition_func.call(element): # Check if element meets the condition
			filtered_array.append(element)

	if not filtered_array.is_empty():
		randomize() # Initialize the random number generator
		var random_index = randi() % filtered_array.size()
		return filtered_array[random_index]
	else:
		return null # No elements met the condition


static func find_children_by_type(node: Node, type: String) -> Array:
	var result = []

	for child in node.get_children():
		if child.get_class() == type or (child.get_script() != null and child.get_script().get_instance_base_type() == type):
			result.append(child)
		# Recursively check the child's children
		result += find_children_by_type(child, type)

	return result


static func load_files_from_directory(path: String) -> Array:
	var files = []
	var dir = DirAccess.open(path)
	
	if dir:
		# List files in the directory
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():  # Skip directories
				var file_path = path.path_join(file_name)
				var resource = load(file_path)
				if resource:
					files.append(resource)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("Failed to open directory: ", path)
	
	return files


static func load_files_of_type_from_directory(path: String, resource_type: String) -> Array:
	var files = []
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".res")):
				var file_path = path.path_join(file_name)
				var resource = load(file_path)
				if resource:
					# Check if it has the correct script assigned
					var script = resource.get_script()
					if script and script.get_global_name() == resource_type:
						files.append(resource)
					elif resource.is_class(resource_type):  # Fallback to original check
						files.append(resource)
					else:
						print("File: ", file_name, " Script: ", script, " Global name: ", script.get_global_name() if script else "No script")
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("Failed to open directory: ", path)
	
	return files
