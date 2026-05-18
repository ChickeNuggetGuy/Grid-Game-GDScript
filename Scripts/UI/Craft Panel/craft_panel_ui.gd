extends UIWindow
class_name CraftPanelUI

@export var craft_list: ItemList

@export var buy_craft_button: Button
@export var sell_craft_button: Button
@export var edit_units_button: Button
@export var edit_equipment_button: Button

@export_group("Sub Windows")
@export var craft_units_window: CraftUnitsUI
@export var craft_equipment_window: CraftEquipmentUI

@export_group("Rename Window")
@export var rename_craft_button: Button
@export var rename_window: UIWindow
@export var text_edit: TextEdit
@export var confirm_button: Button

signal base_data_changed

func _setup() -> void:
	super._setup()

	if craft_list:
		craft_list.item_selected.connect(_on_craft_selected)
		craft_list.empty_clicked.connect(_on_list_empty_clicked)

	if buy_craft_button: buy_craft_button.pressed.connect(buy_craft_button_pressed)
	if sell_craft_button: sell_craft_button.pressed.connect(sell_craft_button_pressed)
	
	if edit_units_button: edit_units_button.pressed.connect(edit_units_pressed)
	if edit_equipment_button: edit_equipment_button.pressed.connect(edit_equipment_pressed)
	
	if rename_craft_button: rename_craft_button.pressed.connect(rename_craft_pressed)
	if confirm_button: confirm_button.pressed.connect(confirm_rename_pressed)
	
	# Connect sub-window signals so the main UI knows when contents changed
	if craft_units_window: craft_units_window.contents_changed.connect(_on_contents_changed)
	if craft_equipment_window: craft_equipment_window.contents_changed.connect(_on_contents_changed)

	_update_button_states()


func _process(_delta: float) -> void:
	if not is_shown: 
		return
	_update_button_states()


func _show() -> void:
	refresh_item_lists()
	super._show()

func _get_current_base() -> TeamBaseDefinition:
	return SceneManager.get_session_value("current_base", null)

func refresh_item_lists() -> void:
	var base_data := _get_current_base()
	if craft_list:
		craft_list.clear()

	if base_data == null:
		_update_button_states()
		return

	for i in range(base_data.craft_hangers.size()):
		var craft := base_data.craft_hangers[i]
		if not craft: continue
		
		var display_text = "%s (Units: %d, Items: %d)" % [
			craft.craft_name, 
			craft.units_on_board.size(), 
			_get_total_items(craft)
		]
		craft_list.add_item(display_text)
		craft_list.set_item_metadata(craft_list.get_item_count() - 1, i)

	_update_button_states()

func _get_total_items(craft: Craft) -> int:
	var total = 0
	for count in craft.items.values(): total += count
	return total

func _get_selected_craft() -> Craft:
	var selected = craft_list.get_selected_items()
	if selected.is_empty(): return null
	
	var base_data = _get_current_base()
	var index = craft_list.get_item_metadata(selected[0])
	return base_data.craft_hangers[index]

func _on_craft_selected(_index: int) -> void:
	_update_button_states()

func _on_list_empty_clicked(_pos: Vector2, _mouse_button_index: int) -> void:
	craft_list.deselect_all()
	_update_button_states()

func _update_button_states() -> void:
	var base_data := _get_current_base()
	var has_base := base_data != null
	var has_selection := craft_list != null and craft_list.get_selected_items().size() > 0

	if buy_craft_button: buy_craft_button.disabled = not has_base
	if sell_craft_button: sell_craft_button.disabled = not has_selection
	if rename_craft_button: rename_craft_button.disabled = not has_selection
	if edit_units_button: edit_units_button.disabled = not has_selection
	if edit_equipment_button: edit_equipment_button.disabled = not has_selection

# --- Button Actions ---

func edit_units_pressed() -> void:
	var craft = _get_selected_craft()
	if craft and craft_units_window:
		craft_units_window.open_for_craft(_get_current_base(), craft)

func edit_equipment_pressed() -> void:
	var craft = _get_selected_craft()
	if craft and craft_equipment_window:
		craft_equipment_window.open_for_craft(_get_current_base(), craft)

func buy_craft_button_pressed() -> void:
	var base_data := _get_current_base()
	base_data.craft_hangers.append(
		Craft.new("New Craft %d" % (base_data.craft_hangers.size() + 1), base_data.cell_index, [])
	)
	_persist_base_data(base_data)
	refresh_item_lists()

func sell_craft_button_pressed() -> void:
	var base_data := _get_current_base()
	var selected = craft_list.get_selected_items()
	if selected.is_empty(): return
	
	var index = craft_list.get_item_metadata(selected[0])
	var craft = base_data.craft_hangers[index]
	craft.return_all_contents_to_base(base_data)
	if craft.is_inside_tree(): craft.queue_free()
	base_data.craft_hangers.pop_at(index)
	
	_persist_base_data(base_data)
	refresh_item_lists()

func rename_craft_pressed() -> void:
	text_edit.text = _get_selected_craft().craft_name
	rename_window.show_call()

func confirm_rename_pressed() -> void:
	if text_edit.text.is_empty(): return
	_get_selected_craft().craft_name = text_edit.text
	_persist_base_data(_get_current_base())
	rename_window.hide_call()
	refresh_item_lists()

func _on_contents_changed() -> void:
	# Refreshes the craft list text to update item/unit counts
	refresh_item_lists() 
	base_data_changed.emit()

func _persist_base_data(base_data: TeamBaseDefinition) -> void:
	if base_data == null: return
	SceneManager.set_session_value("current_base", base_data)
	SceneManager.commit_definition_to_globe_state(base_data)
	base_data_changed.emit()
