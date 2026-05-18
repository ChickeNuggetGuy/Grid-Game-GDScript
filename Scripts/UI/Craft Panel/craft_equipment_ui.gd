extends UIWindow
class_name CraftEquipmentUI

@export var equipment_tree: Tree
@export var add_button_texture: Texture2D
@export var remove_button_texture: Texture2D

var current_base: TeamBaseDefinition
var current_craft: Craft

signal contents_changed

func _setup() -> void:
	super._setup()
	if equipment_tree:
		equipment_tree.columns = 5
		equipment_tree.hide_root = true
		equipment_tree.set_column_title(0, "Item")
		equipment_tree.set_column_title(1, "In Base")
		equipment_tree.set_column_title(2, "In Craft")
		equipment_tree.button_clicked.connect(_on_tree_button_clicked)

func open_for_craft(base: TeamBaseDefinition, craft: Craft) -> void:
	current_base = base
	current_craft = craft
	refresh_tree()
	show_call()

func refresh_tree() -> void:
	if not current_base or not current_craft or not equipment_tree: return
	
	equipment_tree.clear()
	var root := equipment_tree.create_item()
	
	# Combine unique item IDs from both base and craft to list all relevant items
	var all_item_ids = []
	for id in current_base.equipment.keys():
		if not all_item_ids.has(id): all_item_ids.append(id)
	for id in current_craft.items.keys():
		if not all_item_ids.has(id): all_item_ids.append(id)
		
	for item_id in all_item_ids:
		var result = InventoryManager.try_get_inventory_item(item_id)
		if not result["success"]: continue
		var item_data: ItemData = result["inventory_item"]
		
		var tree_item := equipment_tree.create_item(root)
		tree_item.set_metadata(0, item_data) # Store item data for button clicks
		
		var base_count = current_base.equipment.get(item_id, 0)
		var craft_count = current_craft.items.get(item_id, 0)
		
		tree_item.set_text(0, item_data.item_name)
		tree_item.set_text(1, str(base_count))
		tree_item.set_text(2, str(craft_count))
		
		tree_item.add_button(3, add_button_texture, 0)
		tree_item.add_button(4, remove_button_texture, 1)

func _on_tree_button_clicked(item: TreeItem, column: int, id: int, _mouse_button_index: int) -> void:
	var item_data: ItemData = item.get_metadata(0)
	if not item_data: return
	
	var changed = false
	
	if column == 4 and id == 1: # (+) Button Clicked
		if current_craft.try_add_item_to_craft(item_data, current_base):
			changed = true
			
	elif column == 3 and id == 0: # (-) Button Clicked
		if current_craft.try_remove_item_from_craft(item_data, current_base):
			changed = true
			
	if changed:
		_persist_and_refresh()

func _persist_and_refresh() -> void:
	SceneManager.set_session_value("current_base", current_base)
	SceneManager.commit_definition_to_globe_state(current_base)
	refresh_tree()
	contents_changed.emit()
