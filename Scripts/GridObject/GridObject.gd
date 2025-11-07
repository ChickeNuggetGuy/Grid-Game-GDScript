class_name GridObject
extends Node3D

#region Variables
@export var grid_position_data : GridPositionData
@export var visual :  Node3D
@export var collider :  StaticBody3D

var team : Enums.unitTeam 
@export var active : bool = true
@export_category("Stats")
@export var stat_holder: Node
var stat_library: Array[GridObjectStat] = []

@export_category("Inventory")
@export var inventory_grid_types : Array[Enums.inventoryType] = []
var inventory_grids : Dictionary[Enums.inventoryType,InventoryGrid] = {}

@export_category("Animation")
@export var grid_object_animator : GridObjectAnimation


@export_category("Components")
@export var grid_object_component_holder : Node
var _grid_object_components : Array[GridObjectComponent]
#endregion


#region Signals
signal inventories_ready()
signal  gridObject_stat_changed(stat : GridObjectStat, snew_vaule : int)
@warning_ignore("unused_signal")
signal gridObject_moved(owner : Unit, new_grid_cell : GridCell)

#endregion
#region Functions

func _ready() -> void:
	collider.collision_layer =PhysicsLayersUtility.PLAYER

func _setup(gridCell : GridCell, direction : Enums.facingDirection, unit_team : Enums.unitTeam):
	
	if not grid_position_data:
		grid_position_data = GridPositionData.new()
		add_child(grid_position_data)
	grid_position_data.setup_call(self, {"grid_cell" : gridCell,"direction" :  direction})
	
	team = unit_team
	
	if stat_holder:
		stat_library.append_array(stat_holder.get_children())
	
	for stat in stat_library:
		var grid_stat : GridObjectStat = stat
		grid_stat.setup(self)
		if grid_stat.stat_name == "Health":
			grid_stat.connect("stat_value_min", grid_object_dealth)
	
	if grid_object_component_holder:
		_grid_object_components.append_array(grid_object_component_holder.get_children())
	
	for component in _grid_object_components:
		var grid_object_component : GridObjectComponent = component
		if grid_object_component is GridPositionData:
			continue
		grid_object_component.setup_call(self,{})
	
	setup_inventory_grids()


func grid_object_dealth(_parent_grid_object : GridObject):
	print("Grid Object Died, Removing from tree")
	active = false
	#self.queue_free()
	grid_position_data.set_grid_cell(null)
	self.position = Vector3(-500, -500, -500)
	return 


func setup_inventory_grids():
	for inventory_type in inventory_grid_types:
		
		var result = InventoryManager.try_get_inventory_grid(inventory_type)
		if result["success"]:
			inventory_grids[inventory_type] =  result["inventory_grid"]
	emit_signal("inventories_ready")

	

func get_stat_by_name(stat_name: String) -> GridObjectStat:
	# Assuming action_library is an Array of ActionNode objects
	for stat in stat_library:
		if stat.stat_name == stat_name: # Assuming 'n' is the property holding the name
			return stat
	
	# If the loop finishes, the action node was not found
	print("stat not found: " + stat_name)
	return null


func try_spend_stat_value(stat_name : String, amount_to_spend : int) -> Dictionary:
	var retVal: Dictionary = {"success": false, "new_value": 0}
	var stat = get_stat_by_name(stat_name)
	if stat == null:
		retVal["success"] = false
		retVal["new_value"] = -1
		return retVal
	
	if stat.try_remove_value(amount_to_spend):
		retVal["success"] = true
		retVal["new_value"] = stat.current_value
		gridObject_stat_changed.emit(stat,stat.current_value)
		return retVal
	else:
		retVal["success"] = false
		retVal["new_value"] = -1
		return retVal


func check_stat_values(stats_to_check: Dictionary) -> Dictionary:
	var result := {"success": false, "reason": "N/A"}
	var temp_costs: Dictionary = {}
	
	
	for stat_name in stats_to_check.keys():
		var cost = stats_to_check[stat_name]
		var stat = get_stat_by_name(stat_name)
		
		if stat == null:
			result["reason"] = "Stat with name: " + stat_name + " not found!"
			return result
		
		if not temp_costs.has(stat):
			temp_costs[stat] = cost
		else:
			temp_costs[stat] += cost
	
	
	for stat in temp_costs.keys():
		if stat.current_value < temp_costs[stat]:
			result["reason"] = "Not enough: " + stat.name + " value"
			return result
	
	result["success"] = true
	result["reason"] = "Yay"
	return result


func get_grid_object_components() -> Array[GridObjectComponent]:
	return _grid_object_components


func try_get_grid_object_component_by_type(type_to_find : String) -> Dictionary:
	var retval : Dictionary = {"success": false, "grid_object_component" : null}

	var target_script_path: String = ""
	# First, try to find the script path for the given type_string if it's a custom class_name
	var global_classes = ProjectSettings.get_global_class_list()
	for class_info in global_classes:
		if class_info["class"] == type_to_find:
			target_script_path = class_info["path"]
			break

	# Assuming action_library is an Array of ActionNode objects (or whatever base class they extend)
	for component in _grid_object_components:
		# 1. Check if it's a built-in engine class
		if component.is_class(type_to_find):
			retval["success"] = true
			retval["grid_object_component"] = component
			return retval

		# 2. Check if it's a custom class_name
		if target_script_path != "":
			if component.get_script() != null and component.get_script().resource_path == target_script_path:
				retval["success"] = true
				retval["grid_object_component"] = component
				return retval
	
	# If the loop finishes, the action node was not found
	print("Component not found: " + type_to_find)
	return retval


func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_B:
			if GameManager.managers["UnitManager"].Instance.selectedUnit == self:
				print(grid_position_data.grid_cell.inventory_grid.try_add_item(
					InventoryManager.Instance.get_random_item()))

#endregion
