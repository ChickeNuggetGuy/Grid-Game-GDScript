extends UIWindow
class_name BuySellWindow


const UNIT_PURCHASE_ID: int = -999
const UNIT_BUY_PRICE: int = 500

const CRAFT_PURCHASE_ID: int = -998
const CRAFT_BUY_PRICE: int = 100000


@export var item_tree: Tree
@export var cancel_button: Button
@export var confirm_button: Button
@export var current_transaction_total_label: Label
@export var buy_button_texture: Texture2D
@export var sell_button_texture: Texture2D

var created_items: Array[ItemData] = []
var current_item_change: Dictionary[int, int] = {}
var item_lookup: Dictionary[int, ItemData] = {}

signal base_data_changed #


func _setup() -> void:
	if item_tree and not item_tree.button_clicked.is_connected(
		tree_button_clicked
	):
		item_tree.button_clicked.connect(tree_button_clicked)
	if cancel_button and not cancel_button.pressed.is_connected(
		_on_cancel
	):
		cancel_button.pressed.connect(_on_cancel)
	if confirm_button and not confirm_button.pressed.is_connected(
		_on_confirm
	):
		confirm_button.pressed.connect(_on_confirm)


func _show() -> void:
	super._show()
	construct_buy_sell_tree()


func construct_buy_sell_tree():
	current_item_change.clear()
	created_items.clear()
	item_lookup.clear()

	var inventory_manager: InventoryManager = InventoryManager
	if not inventory_manager:
		push_error("Inventory Manager is null!")
		return

	var all_items: Array[ItemData] = inventory_manager.database.get_all_items()
	for item in all_items:
		item_lookup[item.item_id] = item

	if not item_tree:
		push_error("Item Tree is null!")
		return

	item_tree.clear()
	var root := item_tree.create_item()
	
	# Fetch base data early so we can check stationed units
	var base_data: TeamBaseDefinition = SceneManager.get_session_value("current_base", null)

	for item in all_items:
		create_item_display(item, root)
		
	if base_data:
		var unit_tree_item := item_tree.create_item(root)
		unit_tree_item.set_text(0, "Hire Unit")
		unit_tree_item.set_metadata(0, UNIT_PURCHASE_ID)
		
		var current_units: int = base_data.stationed_units.size()
		unit_tree_item.set_text(1, str(current_units))
		
		var unit_change_amount: int = current_item_change.get(UNIT_PURCHASE_ID, 0)
		unit_tree_item.set_text(2, str(unit_change_amount))
		
		# Only add the buy button (column index 3)
		unit_tree_item.add_button(3, buy_button_texture, 0)
# Only add the buy button (column index 3)
		unit_tree_item.add_button(3, buy_button_texture, 0)
		
		var current_crafts: int = base_data.craft_hangers.size()
		var max_crafts: int = base_data.max_craft
		
		var craft_tree_item := item_tree.create_item(root)
		craft_tree_item.set_text(0, "Buy Craft")
		craft_tree_item.set_metadata(0, CRAFT_PURCHASE_ID)
		
		# Show current / max capacity
		craft_tree_item.set_text(1, str(current_crafts) + "/" + str(max_crafts))
		
		var craft_change_amount: int = current_item_change.get(CRAFT_PURCHASE_ID, 0)
		craft_tree_item.set_text(2, str(craft_change_amount))
		
		craft_tree_item.add_button(3, buy_button_texture, 0)

	_update_transaction_total()

func create_item_display(
	item: ItemData, parent: TreeItem
) -> TreeItem:
	if not item:
		push_error("item instance was null")
		return null

	if created_items.has(item):
		push_warning(
			"Item display already created for: "
			+ item.item_name
		)
		return null

	var tree_item := item_tree.create_item(parent)
	tree_item.set_text(0, item.item_name)
	tree_item.set_metadata(0, item.item_id)

	var item_count: int = 0
	var base_data: TeamBaseDefinition = (
		SceneManager.get_session_value("current_base", null)
	)
	if not base_data:
		push_error("Base data could not be properly loaded!")
	elif base_data.has_item(item):
		item_count = base_data.equipment.get(item.item_id, 0)

	tree_item.set_text(1, str(item_count))

	var item_change_amount: int = current_item_change.get(
		item.item_id, 0
	)
	tree_item.set_text(2, str(item_change_amount))

	tree_item.add_button(3, buy_button_texture, 0)
	tree_item.add_button(4, sell_button_texture, 1)

	created_items.append(item)

	if not item.associated_items.is_empty():
		for i in item.associated_items:
			create_item_display(i, tree_item)

	return tree_item


func tree_button_clicked(
	item: TreeItem,
	column: int,
	id: int,
	mouse_button_index: int,
):
	var item_id: int = item.get_metadata(0)

	if not current_item_change.has(item_id):
		current_item_change[item_id] = 0

	if id == 0: # Buy Button
		if item_id == CRAFT_PURCHASE_ID:
			var base_data: TeamBaseDefinition = SceneManager.get_session_value("current_base", null)
			if base_data:
				var current_crafts: int = base_data.craft_hangers.size()
				var current_queued: int = current_item_change[item_id]
				if current_crafts + current_queued < base_data.max_craft:
					current_item_change[item_id] += 1
				else:
					print("No available hangar space!")
		else:
			current_item_change[item_id] += 1
			
	elif id == 1: # Sell Button
		# Prevent "selling" units and craft
		if item_id == UNIT_PURCHASE_ID or item_id == CRAFT_PURCHASE_ID:
			if current_item_change[item_id] > 0:
				current_item_change[item_id] -= 1
		else:
			current_item_change[item_id] -= 1

	item.set_text(2, str(current_item_change[item_id]))
	_update_transaction_total()

func _calculate_transaction_total() -> int:
	var total: int = 0
	for item_id in current_item_change:
		var change: int = current_item_change[item_id]
		if change == 0:
			continue
			
		if item_id == UNIT_PURCHASE_ID:
			total -= UNIT_BUY_PRICE * change
			continue
			
		if item_id == CRAFT_PURCHASE_ID:
			total -= CRAFT_BUY_PRICE * change
			continue
			
		var item_data: ItemData = item_lookup.get(item_id, null)
		if not item_data:
			continue
		if change > 0:
			# Buying costs money (negative funds change)
			total -= item_data.buy_price * change
		else:
			# Selling gains money (positive funds change)
			total += item_data.sell_price * abs(change)
	return total


func _update_transaction_total() -> void:
	if not current_transaction_total_label:
		return
	var total: int = _calculate_transaction_total()
	var current_funds: int = _get_current_funds()
	var sign_str: String = "+" if total >= 0 else ""
	current_transaction_total_label.text = (
		"Funds: "
		+ str(current_funds)
		+ " ("
		+ sign_str
		+ str(total)
		+ ") = "
		+ str(current_funds + total)
	)


func _get_current_funds() -> int:
	var data = SceneManager.session_data.get("globe_state", {})
	var team_manager = data.get("GlobeTeamManager", {})
	var team_1 = team_manager.get("1", {})
	return team_1.get("_current_funds", 0)


func _set_current_funds(value: int) -> void:
	var data = SceneManager.session_data.get("globe_state", {})
	var team_manager = data.get("GlobeTeamManager", {})
	var team_1 = team_manager.get("1", {})
	team_1["_current_funds"] = value
	team_manager["1"] = team_1
	data["GlobeTeamManager"] = team_manager
	SceneManager.set_session_value("globe_state", data)


func _on_cancel() -> void:
	current_item_change.clear()
	toggle()


func _on_confirm() -> void:
	var base_data: TeamBaseDefinition = (
		SceneManager.get_session_value("current_base", null)
	)
	if not base_data:
		push_error("No base data!")
		return

	var total: int = _calculate_transaction_total()
	var current_funds: int = _get_current_funds()

	if current_funds + total < 0:
		push_warning("Not enough funds for this transaction!")
		return

	# Apply inventory changes
	for item_id in current_item_change:
		var change: int = current_item_change[item_id]
		if change == 0:
			continue
			
		if item_id == UNIT_PURCHASE_ID:
			if change > 0:
				for i in range(change):
					base_data.stationed_units.append(
						UnitData.generate_random_unit("New Recruit", base_data.cell_index)
					)
			continue
			
		if item_id == CRAFT_PURCHASE_ID:
			if change > 0:
				for i in range(change):
					var new_craft_name = "New Craft %d" % (base_data.craft_hangers.size() + 1)
					base_data.craft_hangers.append(
						Craft.new(new_craft_name, base_data.cell_index, [])
					)
			continue
			
		# Handle standard items
		var item_data: ItemData = item_lookup.get(item_id, null)
		if not item_data:
			push_error("Unknown item id: " + str(item_id))
			continue
		if change > 0:
			base_data.add_item(item_data, change)
		elif change < 0:
			base_data.remove_item(item_data, abs(change))
	
	SceneManager.set_session_value("current_base", base_data)
	SceneManager.commit_definition_to_globe_state(base_data)
	
	# Apply funds change
	_set_current_funds(current_funds + total)

	current_item_change.clear()
	base_data_changed.emit()
	toggle()
