extends TurnSegment
class_name CheckGameStateTurnSegment

@export var team: Enums.unitTeam


func execute(parent_turn: TurnData) -> void:
	var unit_team_holder: UnitTeamHolder = Manager.get_instance("UnitManager").UnitTeams.get(team)

	if not unit_team_holder:
		printerr("CheckGameStateTurnSegment: Could not find UnitTeamHolder for team %s." % Enums.unitTeam.find_key(team))
		return

	var is_any_unit_active = unit_team_holder.grid_objects["active"].size() > 0

	if not is_any_unit_active:
		print("All units of team " + str(team) + " are defeated!")
		Manager.get_instance("GameManager").try_load_scene_by_name("MainMenuScene")
