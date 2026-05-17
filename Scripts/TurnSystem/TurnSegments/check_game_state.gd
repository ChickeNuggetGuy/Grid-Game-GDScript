extends TurnSegment
class_name CheckGameStateTurnSegment



func execute(parent_turn: TurnData) -> void:
	var unit_team_holder: UnitTeamHolder = GameManager.managers["UnitManager"].unit_teams.get(parent_turn.team)

	if not unit_team_holder:
		printerr("CheckGameStateTurnSegment: Could not find UnitTeamHolder for team %s." % Enums.unitTeam.find_key(parent_turn.team))
		return


	if unit_team_holder.grid_objects["active"].size() < 1:
		print("All units of team " + str(parent_turn.team) + " are defeated!")

		GameManager.managers["TurnManager"].cancel_current_turn()
		if SavesManager.current_save_file != "":
			var globe_data: Dictionary = SceneManager.get_session_value(
				"globe_state",
				{}
			)
			print(globe_data)
			var mission_def : MissionDefinition =MissionDefinition.deserialize(SceneManager.get_session_value("current_mission"))
			if mission_def:
				mission_def.mission_status = (
					Enums.MissionStatus.SUCCESFUL
					if unit_team_holder.team != Enums.unitTeam.PLAYER
					else Enums.MissionStatus.FAIlED
				)
				# Write updated mission back into the globe state
				_update_mission_in_globe_data(globe_data, mission_def)
				SceneManager.set_session_value("current_mission", mission_def.serialize())
				SceneManager.set_session_value("globe_state", globe_data)
			await SceneManager.request_load_scene_by_type(Enums.SceneType.GLOBE,
			globe_data)
		else:
			

			await SceneManager.change_scene(
				Enums.SceneType.MAINMENU,
				{}
			)
		print("End Game: ")
	
	else:
		print("there are still:  " + str(unit_team_holder.grid_objects["active"].size()) + " units alive!")


func _update_mission_in_globe_data(globe_data: Dictionary, mission_def: MissionDefinition) -> void:
	var gm_data = globe_data.get("GlobeManager", {})
	var cell_defs = gm_data.get("cell_definitions", {})
	if not cell_defs.has(Enums.HexCellDefinitionType.MISSION):
		return
	var missions: Array = cell_defs[Enums.HexCellDefinitionType.MISSION]
	for i in range(missions.size()):
		if missions[i].get("cell_index") == mission_def.cell_index:
			missions[i] = mission_def.serialize()
			return
