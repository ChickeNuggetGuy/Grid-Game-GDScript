extends TurnSegment
class_name CheckGameStateTurnSegment



func execute(parent_turn: TurnData) -> void:
	var unit_team_holder: UnitTeamHolder = GameManager.managers["UnitManager"].UnitTeams.get(parent_turn.team)

	if not unit_team_holder:
		printerr("CheckGameStateTurnSegment: Could not find UnitTeamHolder for team %s." % Enums.unitTeam.find_key(parent_turn.team))
		return


	if unit_team_holder.grid_objects["active"].size() < 1:
		print("All units of team " + str(parent_turn.team) + " are defeated!")
		print("End Game: " + str( await GameManager.try_load_scene_by_type(GameManager.sceneType.MAINMENU,GameManager.get_current_scene_data())))
	else:
		print("there are still:  " + str(unit_team_holder.grid_objects["active"].size()) + " units alive!")
