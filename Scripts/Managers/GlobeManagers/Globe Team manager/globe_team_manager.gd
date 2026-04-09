extends Manager
class_name GlobeTeamManager


@export var teams_in_play : Array[Enums.unitTeam]
var teams_holders : Dictionary[Enums.unitTeam, GlobeTeamHolder]


func _get_manager_name() -> String:
	return "GlobeTeamManager"

func _setup() -> void:
	pass


func _execute() -> void:
	if load_data.is_empty():
		for child in get_children():
			child.queue_free()
		
		for team in teams_in_play:
			var globe_team_holder : GlobeTeamHolder = GlobeTeamHolder.new(team,
			600000, [])
			add_child(globe_team_holder)
			teams_holders[team] = globe_team_holder
		


func get_team_holder(team_enum : Enums.unitTeam) -> GlobeTeamHolder:
	return teams_holders.get(team_enum, null) as GlobeTeamHolder


#region Save/Load Functions

func save_data() -> Dictionary:
	var team_data: Dictionary = {}
	
	for globe_team in teams_holders:
		var team: GlobeTeamHolder = teams_holders[globe_team]
		if team:
			team_data[str(globe_team)] = team.serialize()
	
	return team_data


func load_data_call(data_dict: Dictionary) -> void:
	load_data = data_dict
	
	if data_dict.is_empty():
		push_error("Team data was null")
		return
	
	teams_holders.clear()
	
	for child in get_children():
		child.queue_free()
	
	for team in teams_in_play:
		var team_data: Dictionary = data_dict.get(str(team), {})
		
		if not team_data.is_empty():
			var team_holder: GlobeTeamHolder = GlobeTeamHolder.deserialize(
				team_data
			)
			
			if team_holder:
				add_child(team_holder)
				teams_holders[team] = team_holder
				print("added team as child")
			else:
				push_error("Team holder was null")
		else:
			push_error("Team data was null for team: " + str(team))
#endregion
