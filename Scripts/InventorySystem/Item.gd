@tool
class_name Item extends Resource

@export var item_name: String
@export_multiline var description: String
@export var icon: Texture2D

var parent_grid_object: GridObject
var current_inventory_grid : InventoryGrid

@export var shape: GridShape

@export var action_blueprints : Array[BaseActionDefinition]
@export var extra_values : Dictionary [String, Variant] = {}

# REMOVE THESE - dimensions are now solely in GridShape
# var _grid_width: int = 3
# var _grid_height: int = 3
# @export var grid_width: int: ...
# @export var grid_height: int: ...

func _init():
	resource_local_to_scene = true
	shape = null 


func _post_initialize():
	# Ensure shape is created and initialized based on its *own* loaded dimensions.
	_ensure_shape_exists_and_matches()


func _setup():
	if action_blueprints.size() != 0:
		
		for action in action_blueprints:
			print("Item_Setup")
			var item_action : BaseItemActionDefinition = action
			item_action.parent_item = self
			print("Item_Setup" + item_action.parent_item.item_name)

func _ensure_shape_exists_and_matches(): # No arguments needed now
	if shape == null:
		# Create new shape with default dimensions (3,3 from GridShape's @export defaults)
		shape = GridShape.new()
		# Initialize all cells to true if that's the default for new items
		for y in range(shape.grid_height): # Use shape.grid_height
			for x in range(shape.grid_width): # Use shape.grid_width
				shape.set_grid_shape_cell(x, y, true)
		if Engine.is_editor_hint():
			notify_property_list_changed() # Notify Item changed
	# No explicit resizing here; GridShape's own setters handle it.


func _duplicate() -> Resource:
	var new_item = Item.new()

	new_item.item_name = item_name
	new_item.description = description
	new_item.icon = icon
	new_item.parent_grid_object = parent_grid_object
	
	if shape != null:
		new_item.shape = shape.duplicate(true)
	else:
		new_item.shape = null

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
	action_def.extra_parameters["item"] = self
	action_def.extra_parameters["starting_inventory"] = self.current_inventory_grid
	GameManager.managers["UnitActionManager"].try_set_selected_action(action_def)
