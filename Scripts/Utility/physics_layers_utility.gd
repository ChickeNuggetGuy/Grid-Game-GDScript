extends Node
class_name PhysicsLayer

# Matches Godot's 32 collision layers
const DEFAULT    = 1 << 0   # Layer 1
const TERRAIN    = 1 << 1   # Layer 2
const GRIDOBJECT = 1 << 2   # Layer 3
const ENEMY      = 1 << 3   # Layer 4
const OBSTACLE   = 1 << 4   # Layer 5

# Utility method to get a layer mask from its 1-based number
static func get_layer_bit(layer_number: int) -> int:
	if layer_number < 1 or layer_number > 32:
		push_error("Layer number must be between 1 and 32, got: ", layer_number)
		return 0
	return 1 << (layer_number - 1)
