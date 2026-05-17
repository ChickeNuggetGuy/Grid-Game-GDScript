extends Manager
class_name UnitManager
#region Variables
@export var unit_teams : Dictionary[Enums.unitTeam, UnitTeamHolder]
@export var spawn_counts : Vector2i = Vector2(2,2)
@export var unitScene: PackedScene

@export var selected_unit : Unit = null
#endregion

#region Signals
signal unit_selected(newUnit : Unit, oldUnit: Unit);
signal Unit_spawned(newUnit : Unit);
#endregion

#region Functions

func _get_manager_name() -> String: return "UnitManager"


func _setup_conditions(): return true


func _setup():
	
	unitScene = load("Scenes/GridObjects/Unit.tscn")

	var children = get_children()
	var is_loading = load_data and load_data.size() > 0

	for child in children:
		if child is UnitTeamHolder:
			var team_holder: UnitTeamHolder = child
			var team_data = {}
			if is_loading and load_data.has("unit_teams"):
				var team_id_str = str(team_holder.team)
				if load_data["unit_teams"].has(team_id_str):
					team_data = load_data["unit_teams"][team_id_str]

			if not unit_teams.has(team_holder.team):
				unit_teams[team_holder.team] = team_holder
			await team_holder.setup(self, team_data)


func save_data() -> Dictionary:
	var save_dict = {
		"filename" : get_scene_file_path(),
		"parent" : get_parent().get_path(),
		"unit_teams" : {}
	}
	
	for team in  unit_teams.keys():
		var team_holder : UnitTeamHolder = unit_teams[team]
		save_dict["unit_teams"][team] = team_holder.save_data()

	return save_dict


func _execute_conditions() -> bool: return true


func _execute():
	#var children = get_children()
	var is_loading = load_data and load_data.size() > 0
#
	#for child in children:
		#if child is UnitTeamHolder:
			#var team_holder: UnitTeamHolder = child
			#var team_data = {}
			#if is_loading and load_data.has("unit_teams"):
				#var team_id_str = str(team_holder.team)
				#if load_data["unit_teams"].has(team_id_str):
					#team_data = load_data["unit_teams"][team_id_str]
#
			#if not unit_teams.has(team_holder.team):
				#unit_teams[team_holder.team] = team_holder
			#await team_holder.setup(self, team_data)

	if not is_loading:
		var craft_data: Dictionary = SceneManager.get_session_value("current_craft")

		# ── Wait for the player to finish assigning equipment ──
		var finalized_units: Array[UnitData] = await _await_equipment_window(craft_data)

		for unit_data in finalized_units:
			if unit_data == null:
				push_error("Null UnitData from equipment window")
				continue
			await spawn_unit(Enums.unitTeam.PLAYER, unit_data)

		for y in range(spawn_counts.y):
			await spawn_unit(Enums.unitTeam.ENEMY, null)

	if unit_teams.has(Enums.unitTeam.PLAYER) \
		and unit_teams[Enums.unitTeam.PLAYER].grid_objects["active"].size() > 0:
		set_selected_unit(unit_teams[Enums.unitTeam.PLAYER].grid_objects["active"][0])

	execute_complete = true


func _await_equipment_window(craft_data: Dictionary) -> Array[UnitData]:
	var ui_manager: UIManager  = GameManager.get_manager("UIManager")
	var equip_win: StartingEquipmentWindow = null
	
	# However your UIManager exposes windows — adjust this lookup as needed.
	# Example using the UIWindow group:
	for w in get_tree().get_nodes_in_group("UIWindow"):
		if w is StartingEquipmentWindow:
			equip_win = w
			break

	if equip_win == null:
		push_error("StartingEquipmentWindow not found in scene. Skipping equipment phase.")
		# Fallback: just deserialize straight from craft_data.
		var fallback: Array[UnitData] = []
		for data in craft_data.get("units_on_board", []):
			var ud := UnitData.deserialize(data)
			if ud: fallback.append(ud)
		return fallback

	equip_win.open_for_craft(craft_data)
	var result = await equip_win.mission_equipment_confirmed
	# signal emits (units: Array, ground: InventoryGrid)
	var finalized: Array[UnitData] = []
	for u in result[0]:
		finalized.append(u)
	return finalized

func grid_system_grid_updated():
	for team_holder in unit_teams.values():
		team_holder.update_team_visibility()


func _on_exit_tree() -> void:
	return


func spawn_unit(team : Enums.unitTeam, unit_data : UnitData, grid_cell : GridCell = null, direction : Enums.facingDirection = Enums.facingDirection.NORTH):
	
	
	if grid_cell == null:
		var grid_system : GridSystem = GameManager.managers["GridSystem"]
		var result = grid_system.try_get_random_walkable_cell(team if team == Enums.unitTeam.PLAYER else Enums.unitTeam.ANY)
		
		if result["success"] == false || result["grid_cell"] == null:
			print("Could not find any valid grid cell. Returning prematurely")
			return
		elif result["success"] == true && result["grid_cell"] != null:
			grid_cell = result["grid_cell"]
		else:
			return
	
	
	if unit_data == null:
		unit_data = UnitData.generate_random_unit()
	

	var spawneUnit : Unit = unitScene.instantiate()
	spawneUnit.position = grid_cell.world_position
	spawneUnit.data = unit_data
	
	
	
	var team_holder : UnitTeamHolder = unit_teams[team]
	
	var data = {"grid_cell" : grid_cell,"direction" : direction,"team": team}
	await team_holder.add_grid_object(spawneUnit, data, true, false)
	
	if unit_data and team == Enums.unitTeam.PLAYER:
		await _apply_equipped_items_to_unit(spawneUnit, unit_data)

	Unit_spawned.emit(spawneUnit)


func _apply_equipped_items_to_unit(unit: Unit, unit_data: UnitData) -> void:
	var inv_mgr: InventoryManager = InventoryManager

	# Wait for inventories_ready if grids haven't been built yet.
	if unit.inventory_grids.is_empty():
		await unit.inventories_ready

	for inv_type in unit_data.equipped_items.keys():
		if not unit.inventory_grids.has(inv_type):
			# Unit doesn't have that slot — either skip or push_warning.
			push_warning("Unit has no inventory slot for type " + Enums.inventoryType.find_key(inv_type))
			continue

		var grid: InventoryGrid = unit.inventory_grids[inv_type]
		for entry in unit_data.equipped_items[inv_type]:
			if not (entry is Vector2i):
				continue
			var res = inv_mgr.try_get_inventory_item(entry.x)
			if not res["success"]:
				continue
			for i in entry.y:
				var item_copy: ItemData = res["inventory_item"].duplicate(true)
				if not grid.try_add_item(item_copy):
					push_warning("Could not fit item %d into slot %s" % [entry.x, str(inv_type)])

func set_selected_unit(gridObject: Unit):
	if selected_unit == gridObject:
		return
	
	if not gridObject.active:
		return
	var oldUnit = selected_unit
	selected_unit = gridObject
	unit_selected.emit(selected_unit, oldUnit)
	
	var unit_action_manager :  UnitActionManager  = GameManager.get_manager("UnitActionManager")
	
	if unit_action_manager and selected_unit.default_main_action:
		unit_action_manager._set_selected_action(selected_unit.default_main_action)


func set_selected_unit_next():
	if selected_unit == null:
		return

	var active = unit_teams[Enums.unitTeam.PLAYER].grid_objects["active"]
	if active == null or active.size() == 0:
		return

	if active.size() == 1:
		set_selected_unit(active[0])
		return

	var currentIndex: int = active.find(selected_unit)
	var nextIndex: int = 0
	if currentIndex != -1:
		nextIndex = (currentIndex + 1) % active.size()
	else:
		nextIndex = 0

	set_selected_unit(active[nextIndex])


func _process(_delta: float) -> void:
	if not execute_complete or selected_unit == null:
		return

	var grid_system : GridSystem = GameManager.managers["GridSystem"]
	var unit_cell = selected_unit.grid_position_data.grid_cell
	if unit_cell == null:
		return
	
	var cells_in_range = grid_system.try_get_neighbors_in_radius(unit_cell, 10, Enums.cellState.WALKABLE)

	if not cells_in_range["success"]:
		print("Failed")
		return

	if debug_mode:
		for cell in cells_in_range["grid_cells"]:
			grid_system.visualize_cell(cell.grid_coordinates)


func _unhandled_input(event):
	if not execute_complete: return
	if GameManager.managers["UIManager"].blocking_input:
		return
	
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_C:
			set_selected_unit_next()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if GameManager.managers["GridInputManager"].current_grid_cell != null:
				var grid_object : GridObject = GameManager.managers["GridInputManager"].current_grid_cell.grid_object
				if grid_object != null and unit_teams[Enums.unitTeam.PLAYER].grid_objects["active"].has(grid_object):
					set_selected_unit(grid_object)
#endregion
