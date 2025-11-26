extends Node

var custom_classes = {
	"HexCellDefinition": HexCellDefinition,
	"TeamBaseDefinition": TeamBaseDefinition,
	"CityDefinition": CityDefinition,
	"MissionDefinition" : MissionDefinition
}

static func find_parent_by_class_name(node: Node, className: String, max_depth: int = 4) -> Node:
	var depth := 0
	var current := node.get_parent()
	while current and depth < max_depth:
		if current.is_class(className):
			return current
		current = current.get_parent()
		depth += 1
	return null

func create_instance_from_name(name_string: StringName):
	if custom_classes.has(name_string):
		var class_resource = custom_classes[name_string]
		if class_resource is PackedScene:
			return class_resource.instantiate()
		elif class_resource is GDScript:
			return class_resource.new()
	else:
		print("Class not found in factory: ", name_string)
		return null

# New method for deserialization with data
func create_instance_from_data(data: Dictionary) -> HexCellDefinition:
	var _class_name = data.get("class_name", "")
	
	match _class_name:
		"TeamBaseDefinition":
			return TeamBaseDefinition.deserialize(data)
		"CityDefinition":
			return CityDefinition.deserialize(data)
		_:
			print("Unknown class for deserialization: ", _class_name)
			return null


func _parse_vector3_from_string(s: String) -> Vector3:
	s = s.trim_prefix("(").trim_suffix(")")
	var parts = s.split(",")
	if parts.size() == 3:
		return Vector3(float(parts[0].strip_edges()), float(parts[1].strip_edges()), float(parts[2].strip_edges()))
	return Vector3.ZERO
