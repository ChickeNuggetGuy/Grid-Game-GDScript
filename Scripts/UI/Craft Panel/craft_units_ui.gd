extends UIWindow
class_name CraftUnitsUI

@export var base_units_list: ItemList
@export var craft_units_list: ItemList
@export var assign_button: Button
@export var unassign_button: Button

var current_base: TeamBaseDefinition
var current_craft: Craft

signal contents_changed

func _setup() -> void:
	super._setup()
	if assign_button: assign_button.pressed.connect(_on_assign_pressed)
	if unassign_button: unassign_button.pressed.connect(_on_unassign_pressed)

func open_for_craft(base: TeamBaseDefinition, craft: Craft) -> void:
	current_base = base
	current_craft = craft
	refresh_lists()
	show_call() # Assuming UIWindow has a method to show itself

func refresh_lists() -> void:
	if not current_base or not current_craft: return
	
	base_units_list.clear()
	for i in range(current_base.stationed_units.size()):
		var unit = current_base.stationed_units[i]
		base_units_list.add_item(unit.name)
		base_units_list.set_item_metadata(base_units_list.get_item_count() - 1, i)
		
	craft_units_list.clear()
	for i in range(current_craft.units_on_board.size()):
		var unit = current_craft.units_on_board[i]
		craft_units_list.add_item(unit.name)
		craft_units_list.set_item_metadata(craft_units_list.get_item_count() - 1, i)

func _on_assign_pressed() -> void:
	var selected = base_units_list.get_selected_items()
	if selected.is_empty(): return
	
	# Reverse loop to avoid index shifting when popping from the array
	selected.reverse()
	var changed = false
	for list_index in selected:
		var unit_index = base_units_list.get_item_metadata(list_index)
		var unit = current_base.stationed_units[unit_index]
		if current_craft.try_add_unit_to_craft(unit, current_base):
			changed = true
			
	if changed:
		_persist_and_refresh()

func _on_unassign_pressed() -> void:
	var selected = craft_units_list.get_selected_items()
	if selected.is_empty(): return
	
	selected.reverse()
	var changed = false
	for list_index in selected:
		var unit_index = craft_units_list.get_item_metadata(list_index)
		var unit = current_craft.units_on_board[unit_index]
		if current_craft.try_remove_unit_from_craft(unit, current_base):
			changed = true
			
	if changed:
		_persist_and_refresh()

func _persist_and_refresh() -> void:
	SceneManager.set_session_value("current_base", current_base)
	SceneManager.commit_definition_to_globe_state(current_base)
	refresh_lists()
	contents_changed.emit()
