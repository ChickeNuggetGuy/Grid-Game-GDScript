extends TurnData
class_name TeamTurnData

@export var team : Enums.unitTeam
var team_holder : UnitTeamHolder


func _setup():
	var unit_manager : UnitManager = GameManager.managers["UnitManager"]
	team_holder = unit_manager.UnitTeams[team]
	
	
func _execute():
	print("Executing Team Turn: " + Enums.unitTeam.find_key(team))
	
	var active_units = team_holder.grid_objects["active"]
	
	for unit in active_units:
		var time_unit_stat = unit.get_stat_by_name("time_units")
		if time_unit_stat:
			time_unit_stat.set_to_max()
	
	if team == Enums.unitTeam.PLAYER:
		var unit_manager : UnitManager = GameManager.managers["UnitManager"]
		if unit_manager.selectedUnit == null:
			unit_manager.set_selected_unit_next()
	
	
	team_holder.update_team_visibility()
	


func save_data() -> Dictionary:
	var save_dict = {
		"team" : team,
		"team_holder" : team_holder.save_data()
	}
	return save_dict


func load_data(data : Dictionary):
	team = data["team"]
	# team_holder is resolved in _setup()
