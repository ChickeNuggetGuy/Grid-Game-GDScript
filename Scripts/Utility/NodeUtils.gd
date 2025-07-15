# NodeUtils.gd
class_name NodeUtils

### Recursively searches up to max_depth for a parent whose class
### (or ancestor class) matches class_name.
### Continues while \(depth < max\_depth\).
static func find_parent_by_class_name(node: Node, className: String,max_depth: int = 4) -> Node:
	var depth := 0
	var current := node.get_parent()
	while current and depth < max_depth:
		# checks inheritance chain too
		if current.is_class(className):
			return current
		current = current.get_parent()
		depth += 1
	return null
