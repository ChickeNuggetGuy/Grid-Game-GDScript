extends GridObject
class_name Unit

@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
@export var _stance : Enums.UnitStance = (Enums.UnitStance.NORMAL | Enums.UnitStance.STATIONARY)
@export var _action_library: Array[BaseActionDefinition] = []
var action_queue : Array[Action]

#region Stance Functions
const POSTURE_MASK := Enums.UnitStance.NORMAL | Enums.UnitStance.CROUCHED
const MOTION_MASK := Enums.UnitStance.STATIONARY | Enums.UnitStance.MOVING


func _setup(gridCell : GridCell, direction : Enums.facingDirection, unit_team : Enums.unitTeam):
	
	super._setup(gridCell,direction, unit_team)
	inventory_grids[Enums.inventoryType.RIGHTHAND].try_add_item(InventoryManager.get_random_item())

func set_stance(flag: int) -> void:
	# Ensure flag is one of the posture flags
	assert((flag & POSTURE_MASK) != 0 and (flag & ~POSTURE_MASK) == 0)
	@warning_ignore("int_as_enum_without_cast")
	_stance = (_stance & ~POSTURE_MASK) | flag


func set_motion(flag: int) -> void:
	# Ensure flag is one of the motion flags
	assert((flag & MOTION_MASK) != 0 and (flag & ~MOTION_MASK) == 0)
	@warning_ignore("int_as_enum_without_cast")
	_stance = (_stance & ~MOTION_MASK) | flag


func toggle_stance(state):
	_stance = _stance ^ state
	
func get_stance() -> Enums.UnitStance:
	return _stance


func is_crouched() -> bool:
	return (_stance & Enums.UnitStance.CROUCHED) != 0


func is_moving() -> bool:
	return (_stance & Enums.UnitStance.MOVING) != 0
#endregion

func get_action_node_by_index(i: int) -> BaseActionDefinition:
	var a = _action_library[i]
	if a == null:
		print("Action not found at index")
		return null
	else:
		return a


func try_get_action_definition_by_type(type_to_find: String) -> Dictionary:
	var retval : Dictionary = {"success": false, "action_definition" : null}

	var target_script_path: String = ""
	# First, try to find the script path for the given type_string if it's a custom class_name
	var global_classes = ProjectSettings.get_global_class_list()
	for class_info in global_classes:
		if class_info["class"] == type_to_find:
			target_script_path = class_info["path"]
			break

	# Assuming action_library is an Array of ActionNode objects (or whatever base class they extend)
	for action_def in _action_library:
		# 1. Check if it's a built-in engine class
		if action_def.is_class(type_to_find):
			retval["success"] = true
			retval["action_definition"] = action_def
			return retval

		# 2. Check if it's a custom class_name
		if target_script_path != "":
			if action_def.get_script() != null and action_def.get_script().resource_path == target_script_path:
				retval["success"] = true
				retval["action_definition"] = action_def
				return retval
	
	# If the loop finishes, the action node was not found
	print("Action not found: " + type_to_find)
	return retval


func get_all_action_definitions() -> Dictionary:
	
	var ret_values = {"action_definitions": [], 
			"item_action_definitions" : {}}
	ret_values["action_definitions"] = _action_library
	
	for  key in inventory_grids.keys():
		var inventory_grid : InventoryGrid = inventory_grids[key] as InventoryGrid
		if inventory_grid.equipment_inventory == true and inventory_grid.item_count != 0:
			var items = inventory_grid.try_get_item_array()
			
			if items.size() != 0:
				for item in items:
					var typed_item = item as Item
					
					for definition in typed_item.action_blueprints:
						ret_values["item_action_definitions"][definition] = typed_item
			
	
	return ret_values
	
