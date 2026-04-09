@tool
class_name Item 
extends Resource

@export var item_name: String
@export_multiline var description: String
@export var icon: Texture2D

var parent_grid_object: GridObject
var current_inventory_grid : InventoryGrid
var current_invenrtory_coords : Vector2i

@export var grid_shape: GridShape

@export var item_components : Array[ItemComponent]  = []

@export var action_blueprints : Array[BaseActionDefinition]
@export var item_costs : Dictionary[Enums.Stat, int] = {}
@export var extra_values : Dictionary [String, Variant] = {}


func _init():
	resource_local_to_scene = true
	grid_shape = null 


func _post_initialize():
	_ensure_shape_exists_and_matches()


func _setup():
	if action_blueprints.size() != 0:
		
		for action in action_blueprints:
			print("Item_Setup")
			var item_action : BaseItemActionDefinition = action
			item_action.parent_item = self
			print("Item_Setup" + item_action.parent_item.item_name)
			
	if not item_components.is_empty():
		for item_component in item_components:
			item_component.setup_call(self)


func _ensure_shape_exists_and_matches(): # No arguments needed now
	if grid_shape == null:
		# Create new grid_shape with default dimensions (3,3 from GridShape's @export defaults)
		grid_shape = GridShape.new()
		# Initialize all cells to true if that's the default for new items
		for y in range(grid_shape.grid_height): # Use grid_shape.grid_height
			for x in range(grid_shape.grid_width): # Use grid_shape.grid_width
				grid_shape.set_grid_shape_cell(x, y,0, true)
		if Engine.is_editor_hint():
			notify_property_list_changed() # Notify Item changed
	# No explicit resizing here; GridShape's own setters handle it.


func _duplicate() -> Resource:
	var new_item = Item.new()

	new_item.item_name = item_name
	new_item.description = description
	new_item.icon = icon
	new_item.parent_grid_object = parent_grid_object
	
	if grid_shape != null:
		new_item.grid_shape = grid_shape.duplicate(true)
	else:
		new_item.grid_shape = null

	new_item.action_blueprints.resize(action_blueprints.size())
	for i in range(action_blueprints.size()):
		var blueprint = action_blueprints[i]
		if blueprint != null and blueprint is Resource:
			new_item.action_blueprints[i] = blueprint.duplicate(true)
		else:
			new_item.action_blueprints[i] = blueprint
	
	return new_item


func get_context_items() -> Dictionary[String,Callable]:
	var ret_value :  Dictionary[String,Callable] = {}
	
	for action in action_blueprints:
		ret_value[action.action_name] = (Callable.create(self,"set_item_action").bind(action))
	
	return ret_value


func set_item_action(action_def : BaseItemActionDefinition):
	action_def.parent_item = self
	action_def.starting_inventory = self.current_inventory_grid
	GameManager.managers["UnitActionManager"].try_set_selected_action(action_def)

func try_get_item_component(component_type : String) -> Dictionary:
	var ret_val = {"success": false,"reason": "", "component" : null}
	
	if item_components.is_empty():
		ret_val["reason"] = "item components list is empty"
		return ret_val
	
	
	var found_component : ItemComponent = null
	for component in item_components:
		if component.get_class_name().to_lower() == component_type.to_lower():
			found_component = component
		break
	
	if found_component != null:
		ret_val["success"] =  true
		ret_val["component"] = found_component
	else:
		ret_val["success"] =  false
		ret_val["reason"] = "component could not be found"
		ret_val["component"] = null
	
	return ret_val
	
