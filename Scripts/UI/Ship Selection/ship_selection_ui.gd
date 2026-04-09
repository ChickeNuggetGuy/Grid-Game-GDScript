extends UIWindow
class_name ShipSelectionUI

@export var craft_tree: Tree
@export var select_ship_button: Button


func _setup() -> void:
	super._setup()

	if craft_tree:
		craft_tree.columns = 1
		craft_tree.hide_root = true
		craft_tree.select_mode = Tree.SELECT_SINGLE

		if not craft_tree.item_selected.is_connected(_on_tree_selection_changed):
			craft_tree.item_selected.connect(_on_tree_selection_changed)

		if not craft_tree.nothing_selected.is_connected(_on_tree_selection_changed):
			craft_tree.nothing_selected.connect(_on_tree_selection_changed)

	if select_ship_button and not select_ship_button.pressed.is_connected(
		select_ship_button_pressed
	):
		select_ship_button.pressed.connect(select_ship_button_pressed)

	_update_button_states()


func _show() -> void:
	super._show()
	retrieve_player_craft()
	_update_button_states()


func _on_tree_selection_changed() -> void:
	_update_button_states()


func _update_button_states() -> void:
	var selected_meta := _get_selected_craft_meta()

	if select_ship_button:
		select_ship_button.disabled = selected_meta.is_empty()


func _get_selected_craft_meta() -> Dictionary:
	if not craft_tree:
		return {}

	var selected_item := craft_tree.get_selected()
	if selected_item == null:
		return {}

	var meta = selected_item.get_metadata(0)
	if not (meta is Dictionary):
		return {}

	if String(meta.get("type", "")) != "craft":
		return {}

	return meta


#region Tree Construction
func retrieve_player_craft() -> void:
	var globe_team_manager: GlobeTeamManager = GameManager.get_manager(
		"GlobeTeamManager"
	)
	if not globe_team_manager:
		return

	var globe_manager: GlobeManager = GameManager.get_manager("GlobeManager")
	if not globe_manager:
		print("Globe manager not found!")
		return

	var player_team: GlobeTeamHolder = globe_team_manager.get_team_holder(
		Enums.unitTeam.PLAYER
	)
	if not player_team:
		print("Player team not found")
		return

	var all_craft: Dictionary = {}

	for base_index in player_team.base_indicies:
		var defs := globe_manager.hex_grid_data.get_cell_definitions(base_index)
		if defs.is_empty():
			continue

		var base: TeamBaseDefinition = null
		for def in defs:
			if def is TeamBaseDefinition:
				base = def
				break

		if not base:
			print("Base was null")
			continue

		all_craft[base] = base.craft_hangers

	construct_craft_tree(all_craft)


func construct_craft_tree(all_base_craft: Dictionary) -> void:
	if not craft_tree:
		return

	craft_tree.clear()
	var root := craft_tree.create_item()

	for base in all_base_craft.keys():
		var base_item := craft_tree.create_item(root)
		base_item.set_text(0, base.base_name)
		base_item.set_metadata(
			0,
			{
				"type": "base",
				"cell_index": base.cell_index
			}
		)

		for j in range(base.craft_hangers.size()):
			var craft: Craft = base.craft_hangers[j]
			if not craft:
				push_error("Craft was null")
				continue

			var craft_item: TreeItem = craft_tree.create_item(base_item)
			craft_item.set_text(0, craft.craft_name)
			craft_item.set_metadata(
				0,
				{
					"type": "craft",
					"cell_index": base.cell_index,
					"craft_index": j
				}
			)
#endregion


func select_ship_button_pressed() -> void:
	var selected_meta := _get_selected_craft_meta()
	if selected_meta.is_empty():
		return

	var globe_mission_manager: GlobeMissionManager = GameManager.get_manager(
		"GlobeMissionManager"
	)
	if not globe_mission_manager:
		return

	var base_index := int(selected_meta.get("cell_index", -1))
	var craft_index := int(selected_meta.get("craft_index", -1))

	if not globe_mission_manager.arm_craft_for_mission(base_index, craft_index):
		return

	print("Craft selected. Click a mission on the globe.")
	hide_call()
