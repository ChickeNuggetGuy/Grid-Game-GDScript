extends UIWindow
class_name UnitsPanelUI

@export var unit_item_list: ItemList

@export var hire_new_unit_button: Button
@export var fire_unit_button: Button

func _setup() -> void:
	super._setup()

	if hire_new_unit_button \
	and not hire_new_unit_button.pressed.is_connected(hire_new_unit):
		hire_new_unit_button.pressed.connect(hire_new_unit)

	if fire_unit_button \
	and not fire_unit_button.pressed.is_connected(fire_unit):
		fire_unit_button.pressed.connect(fire_unit)


	var base_data: TeamBaseDefinition = SceneManager.get_session_value(
		"current_base",
		null
	)

	if base_data == null:
		print("Could not find current base")
		return

	var unit_data = base_data.stationed_units
	refresh_unit_list(unit_data)

func refresh_unit_list(unit_data: Array[UnitData]) -> void:
	if unit_data.is_empty():
		print("Could not find Unit Data")
		return

	unit_item_list.clear()
	for unit in unit_data:
		create_unit_element(unit)

func create_unit_element(unit: UnitData) -> void:
	unit_item_list.add_item(unit.name)

func hire_new_unit() -> void:
	var base_data: TeamBaseDefinition = SceneManager.get_session_value(
		"current_base",
		null
	)

	if base_data == null:
		return

	base_data.stationed_units.append(
		UnitData.new("New Unit", base_data.cell_index)
	)

	refresh_unit_list(base_data.stationed_units)

func fire_unit() -> void:
	var selected_items := unit_item_list.get_selected_items()

	if selected_items.is_empty():
		print("No unit selected")
		return

	var base_data: TeamBaseDefinition = SceneManager.get_session_value(
		"current_base",
		null
	)

	if base_data == null:
		print("Could not find current base")
		return

	var unit_data := base_data.stationed_units

	selected_items.sort()
	selected_items.reverse()

	for index in selected_items:
		if index >= 0 and index < unit_data.size():
			unit_data.remove_at(index)

	refresh_unit_list(unit_data)
