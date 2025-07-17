extends Node
class_name PhysicsLayer

# Define your collision layers here using bit shifts
# Layer 1 (index 0)
const DEFAULT          = 1 << 0  # Binary 0000_0001
# Layer 2 (index 1)
const TERRAIN          = 1 << 1  # Binary 0000_0010
# Layer 3 (index 2)
const PLAYER           = 1 << 2  # Binary 0000_0100
# Layer 4 (index 3)
const ENEMY            = 1 << 3  # Binary 0000_1000
# ... add more layers as needed

# Optionally, a helper function to set a single layer value
# (Though set_collision_layer_value/mask_value are clear enough)
static func get_layer_bit(layer_number: int) -> int:
	# Converts a 1-based layer number to its bitmask
	if layer_number < 1 or layer_number > 32: # Godot supports up to 32 layers
		push_error("Invalid layer number: ", layer_number)
		return 0
	return 1 << (layer_number - 1)
