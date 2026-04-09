extends UIWindow
class_name CraftPanelUI

const UNITS_TAB_INDEX := 0
const EQUIPMENT_TAB_INDEX := 1

@export var craft_tree: Tree

@export var add_button: Button
@export var remove_button: Button
@export var sell_craft_button: Button

@export var tab_container: TabContainer
@export var units_item_list: ItemList
@export var equipment_item_list: ItemList

@export var buy_craft_button: Button

@export_group("Rename Window")
@export var rename_craft_button: Button
@export var rename_window : UIWindow
@export var text_edit : TextEdit
@export var confirm_button : Button


func _setup() -> void:
	super._setup()

	if not craft_tree:
		push_error("Craft Tree not assigned")
		return
	if not units_item_list:
		push_error("Unit Item List not assigned")
		return
	if not equipment_item_list:
		push_error("Equipment Item List not assigned")
		return

	craft_tree.columns = 1
	craft_tree.hide_root = true
	craft_tree.select_mode = Tree.SELECT_MULTI

	units_item_list.select_mode = ItemList.SELECT_MULTI
	equipment_item_list.select_mode = ItemList.SELECT_MULTI

	if not add_button:
		push_error("Add button not assigned!")
		return
	elif not add_button.pressed.is_connected(add_button_pressed):
		add_button.pressed.connect(add_button_pressed)

	if not remove_button:
		push_error("Remove button not assigned!")
		return
	elif not remove_button.pressed.is_connected(remove_button_pressed):
		remove_button.pressed.connect(remove_button_pressed)

	if not sell_craft_button:
		push_error("Sell craft button not assigned!")
		return
	elif not sell_craft_button.pressed.is_connected(
		sell_craft_button_pressed
	):
		sell_craft_button.pressed.connect(sell_craft_button_pressed)

	if not buy_craft_button:
		push_error("Buy craft button not assigned!")
		return
	elif not buy_craft_button.pressed.is_connected(
		buy_craft_button_pressed
	):
		buy_craft_button.pressed.connect(buy_craft_button_pressed)
		
		
	if not rename_craft_button:
		push_error("rename button not assigned!")
		return
	elif not rename_craft_button.pressed.is_connected(
		rename_craft_pressed
	):
		rename_craft_button.pressed.connect(rename_craft_pressed)
		
		
	if not confirm_button:
		push_error("confirm button not assigned!")
		return
	elif not confirm_button.pressed.is_connected(
		comfirm_rename_pressed
	):
		confirm_button.pressed.connect(comfirm_rename_pressed)

	_update_button_states()


func _show() -> void:
	refresh_item_lists()
	super._show()


func _process(_delta: float) -> void:
	if not is_shown:
		return
	_update_button_states()


func _get_current_base() -> TeamBaseDefinition:
	return SceneManager.get_session_value("current_base", null)


func refresh_item_lists() -> void:
	var base_data := _get_current_base()

	if base_data == null:
		if craft_tree:
			craft_tree.clear()
		if units_item_list:
			units_item_list.clear()
		if equipment_item_list:
			equipment_item_list.clear()

		_update_button_states()
		return

	construct_craft_tree(base_data.craft_hangers)
	construct_units_item_list(base_data.stationed_units)
	construct_equipment_item_list(base_data.equipment)
	_update_button_states()


#region Tree and Item List Construction
func construct_craft_tree(all_craft: Array[Craft]) -> void:
	if not craft_tree:
		push_error("Craft Tree is null!")
		return

	craft_tree.clear()
	var root := craft_tree.create_item()

	for i in range(all_craft.size()):
		var craft := all_craft[i]
		if not craft:
			push_error("Craft instance was null")
			continue

		var craft_item := craft_tree.create_item(root)
		craft_item.set_text(0, craft.craft_name)
		craft_item.set_metadata(
			0,
			{
				"type": "craft",
				"craft_index": i
			}
		)

		for j in range(craft.units_on_board.size()):
			var unit := craft.units_on_board[j]
			if not unit:
				push_error("Unit on craft was null")
				continue

			var unit_item := craft_tree.create_item(craft_item)
			unit_item.set_text(0, "Unit: " + unit.name)
			unit_item.set_metadata(
				0,
				{
					"type": "craft_unit",
					"craft_index": i,
					"unit_index": j
				}
			)

		for item in craft.items.keys():
			var item_count: int = craft.items[item]
			for k in range(item_count):
				var item_entry := craft_tree.create_item(craft_item)
				item_entry.set_text(0, "Item: " + item.item_name)
				item_entry.set_metadata(
					0,
					{
						"type": "craft_item",
						"craft_index": i,
						"item_ref": item
					}
				)


func construct_units_item_list(all_units: Array[UnitData]) -> void:
	if not units_item_list:
		push_error("Unit Item List is null!")
		return

	units_item_list.clear()

	for i in range(all_units.size()):
		var unit := all_units[i]
		if not unit:
			push_error("Unit instance was null")
			continue

		units_item_list.add_item(unit.name)
		var row := units_item_list.get_item_count() - 1
		units_item_list.set_item_metadata(
			row,
			{
				"type": "base_unit",
				"unit_index": i
			}
		)


func construct_equipment_item_list(all_equipment: Array[Item]) -> void:
	if not equipment_item_list:
		push_error("Equipment Item List is null!")
		return

	equipment_item_list.clear()

	for i in range(all_equipment.size()):
		var equipment := all_equipment[i]
		if not equipment:
			push_error("Equipment instance was null")
			continue

		equipment_item_list.add_item(equipment.item_name)
		var row := equipment_item_list.get_item_count() - 1
		equipment_item_list.set_item_metadata(
			row,
			{
				"type": "base_item",
				"item_index": i
			}
		)
#endregion


#region Selection Helpers
func _get_selected_tree_items() -> Array[TreeItem]:
	var selected: Array[TreeItem] = []

	if not craft_tree:
		return selected

	var root := craft_tree.get_root()
	if root == null:
		return selected

	_collect_selected_tree_items(root.get_first_child(), selected)
	return selected


func _collect_selected_tree_items(
	item: TreeItem,
	out_selected: Array[TreeItem]
) -> void:
	var current := item

	while current != null:
		if current.is_selected(0):
			out_selected.append(current)

		var child := current.get_first_child()
		if child != null:
			_collect_selected_tree_items(child, out_selected)

		current = current.get_next()


func _get_selected_target_craft_indices() -> Array[int]:
	var indices: Array[int] = []

	for tree_item in _get_selected_tree_items():
		var meta = tree_item.get_metadata(0)
		if not (meta is Dictionary):
			continue

		var craft_index := int(meta.get("craft_index", -1))
		if craft_index >= 0 and not indices.has(craft_index):
			indices.append(craft_index)

	return indices


func _get_selected_sell_craft_indices() -> Array[int]:
	var indices: Array[int] = []

	for tree_item in _get_selected_tree_items():
		var meta = tree_item.get_metadata(0)
		if not (meta is Dictionary):
			continue

		if String(meta.get("type", "")) != "craft":
			continue

		var craft_index := int(meta.get("craft_index", -1))
		if craft_index >= 0 and not indices.has(craft_index):
			indices.append(craft_index)

	return indices


func _get_single_selected_craft(base_data: TeamBaseDefinition) -> Craft:
	var indices := _get_selected_target_craft_indices()
	if indices.size() != 1:
		return null

	var craft_index := indices[0]
	if craft_index < 0 or craft_index >= base_data.craft_hangers.size():
		return null

	return base_data.craft_hangers[craft_index]


func _has_selected_removable_entries() -> bool:
	for tree_item in _get_selected_tree_items():
		var meta = tree_item.get_metadata(0)
		if not (meta is Dictionary):
			continue

		var entry_type := String(meta.get("type", ""))
		if entry_type == "craft_unit" or entry_type == "craft_item":
			return true

	return false


func _get_active_add_selection_count() -> int:
	if not tab_container:
		return 0

	match tab_container.current_tab:
		UNITS_TAB_INDEX:
			return units_item_list.get_selected_items().size()
		EQUIPMENT_TAB_INDEX:
			return equipment_item_list.get_selected_items().size()
		_:
			return 0
#endregion


#region Button State Logic
func _update_button_states() -> void:
	var base_data := _get_current_base()
	var has_base := base_data != null

	if buy_craft_button:
		buy_craft_button.disabled = not has_base

	if not has_base:
		if add_button:
			add_button.disabled = true
		if remove_button:
			remove_button.disabled = true
		if sell_craft_button:
			sell_craft_button.disabled = true
		return

	var single_craft_selected := _get_selected_target_craft_indices().size() == 1
	var has_add_selection := _get_active_add_selection_count() > 0
	var has_removable_selection := _has_selected_removable_entries()
	var has_sell_selection := _get_selected_sell_craft_indices().size() > 0

	if add_button:
		add_button.disabled = not (
			single_craft_selected and has_add_selection
		)

	if remove_button:
		remove_button.disabled = not has_removable_selection

	if sell_craft_button:
		sell_craft_button.disabled = not has_sell_selection
	
	if rename_craft_button:
		rename_craft_button.disabled = not (single_craft_selected)
#endregion


func add_button_pressed() -> void:
	var base_data := _get_current_base()
	if base_data == null:
		return

	var selected_craft := _get_single_selected_craft(base_data)
	if selected_craft == null:
		print("Select exactly one craft to add to.")
		return

	match tab_container.current_tab:
		UNITS_TAB_INDEX:
			_add_selected_units_to_craft(base_data, selected_craft)
		EQUIPMENT_TAB_INDEX:
			_add_selected_equipment_to_craft(base_data, selected_craft)


func _add_selected_units_to_craft(
	base_data: TeamBaseDefinition,
	selected_craft: Craft
) -> void:
	var selected_units: Array[UnitData] = []

	for row in units_item_list.get_selected_items():
		var meta = units_item_list.get_item_metadata(row)
		if not (meta is Dictionary):
			continue

		var unit_index := int(meta.get("unit_index", -1))
		if unit_index < 0 or unit_index >= base_data.stationed_units.size():
			continue

		var selected_unit := base_data.stationed_units[unit_index]
		if selected_unit:
			selected_units.append(selected_unit)

	var changed := false

	for unit in selected_units:
		if selected_craft.try_add_unit_to_craft(unit, base_data):
			changed = true

	if changed:
		refresh_item_lists()


func _add_selected_equipment_to_craft(
	base_data: TeamBaseDefinition,
	selected_craft: Craft
) -> void:
	var selected_items: Array[Item] = []

	for row in equipment_item_list.get_selected_items():
		var meta = equipment_item_list.get_item_metadata(row)
		if not (meta is Dictionary):
			continue

		var item_index := int(meta.get("item_index", -1))
		if item_index < 0 or item_index >= base_data.equipment.size():
			continue

		var selected_item := base_data.equipment[item_index]
		if selected_item:
			selected_items.append(selected_item)

	var changed := false

	for item in selected_items:
		if selected_craft.try_add_item_to_craft(item, base_data):
			changed = true

	if changed:
		refresh_item_lists()


func remove_button_pressed() -> void:
	var base_data := _get_current_base()
	if base_data == null:
		return

	var unit_removals: Array[Dictionary] = []
	var item_removals: Array[Dictionary] = []

	for tree_item in _get_selected_tree_items():
		var meta = tree_item.get_metadata(0)
		if not (meta is Dictionary):
			continue

		var entry_type := String(meta.get("type", ""))
		var craft_index := int(meta.get("craft_index", -1))

		if craft_index < 0 or craft_index >= base_data.craft_hangers.size():
			continue

		var selected_craft := base_data.craft_hangers[craft_index]
		if not selected_craft:
			continue

		match entry_type:
			"craft_unit":
				var unit_index := int(meta.get("unit_index", -1))
				if (
					unit_index >= 0
					and unit_index < selected_craft.units_on_board.size()
				):
					var unit := selected_craft.units_on_board[unit_index]
					if unit:
						unit_removals.append(
							{
								"craft": selected_craft,
								"unit": unit
							}
						)

			"craft_item":
				var item_ref: Item = meta.get("item_ref", null)
				if item_ref:
					item_removals.append(
						{
							"craft": selected_craft,
							"item": item_ref
						}
					)

			_:
				continue

	var changed := false

	for removal in unit_removals:
		var craft: Craft = removal.get("craft", null)
		var unit: UnitData = removal.get("unit", null)

		if craft and unit and craft.try_remove_unit_from_craft(unit, base_data):
			changed = true

	for removal in item_removals:
		var craft: Craft = removal.get("craft", null)
		var item: Item = removal.get("item", null)

		if craft and item and craft.try_remove_item_from_craft(item, base_data):
			changed = true

	if changed:
		refresh_item_lists()


func sell_craft_button_pressed() -> void:
	var base_data := _get_current_base()
	if base_data == null:
		return

	var selected_indices := _get_selected_sell_craft_indices()
	if selected_indices.is_empty():
		return

	selected_indices.sort()
	selected_indices.reverse()

	for craft_index in selected_indices:
		if craft_index < 0 or craft_index >= base_data.craft_hangers.size():
			continue

		var craft := base_data.craft_hangers[craft_index]
		if craft:
			craft.return_all_contents_to_base(base_data)

			if craft.is_inside_tree():
				craft.queue_free()

		base_data.craft_hangers.pop_at(craft_index)

	refresh_item_lists()


func buy_craft_button_pressed() -> void:
	var base_data := _get_current_base()
	if base_data == null:
		return

	base_data.craft_hangers.append(
		Craft.new(
			"New Craft %d" % (base_data.craft_hangers.size() + 1),
			base_data.cell_index,
			[]
		)
	)

	refresh_item_lists()

func rename_craft_pressed():
	text_edit.text = _get_single_selected_craft(_get_current_base()).craft_name
	rename_window.show_call()

func comfirm_rename_pressed():
	if text_edit.text.is_empty():
		return
		
	var craft =  _get_single_selected_craft(_get_current_base())
	
	craft.craft_name = text_edit.text
	rename_window.hide_call()
	construct_craft_tree(_get_current_base().craft_hangers)
	pass
