extends TurnSegment
class_name AIActionsTurnSegment


func execute(parent_turn : TurnData):
	var unit_team : UnitTeamHolder = Manager.get_instance("UnitManager").UnitTeams[parent_turn.team]
	
	if unit_team == null:
		push_error("Unit Team was null!")
		return
	
	
	if unit_team.gridObjects.size() < 1:
		push_error("Unit Team has no gridobjects!")
		return
	
	for  grid_object in unit_team.gridObjects:
		
		if grid_object == null:
			continue
		for i in range(0, 2):
			if grid_object is Unit and grid_object.active:
				var unit = grid_object as Unit
				
				#UnitManager.Instance.set_selected_unit(unit)
				var unit_actions = unit.get_all_action_definitions()
				var unit_action_array : Array[BaseActionDefinition] = unit_actions["action_definitions"]
				unit_action_array.append_array(unit_actions["item_action_definitions"].keys())
				
				var best_action_results = determine_best_action(unit, unit_action_array)
				
				if best_action_results["action"] is BaseItemActionDefinition:
					
					var action_item = unit_actions["item_action_definitions"].get(best_action_results["action"])

					await Manager.get_instance("UnitActionManager").try_execute_item_action(best_action_results["action"],
											unit,
											action_item,
											action_item.current_inventory_grid,
											best_action_results["best_action_result"]["grid_cell"],)
				else:
					await Manager.get_instance("UnitActionManager").try_execute_action(best_action_results["best_action_result"]["grid_cell"],
							unit,
							best_action_results["action"])


func determine_best_action(unit : Unit, action_array : Array[BaseActionDefinition]) -> Dictionary:
	var ret_value = {"action" : null, "best_action_result" : null}
	var best_action = action_array[0]
	var best_action_result = action_array[0].calculate_best_AI_action_score(unit.grid_position_data.grid_cell)
	
	for action in action_array:
		var test_action = action
		var action_best_result = test_action.calculate_best_AI_action_score(unit.grid_position_data.grid_cell)
		
		if action_best_result["action_score"] > best_action_result["action_score"]:
			best_action = test_action
			best_action_result = action_best_result
	
	ret_value["action"] = best_action
	ret_value["best_action_result"] = best_action_result
	return ret_value
