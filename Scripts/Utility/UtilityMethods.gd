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
