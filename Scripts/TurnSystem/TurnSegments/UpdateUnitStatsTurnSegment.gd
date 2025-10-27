extends TurnSegment
class_name UpdateUnitStatsTurnSegment
func execute(parent_turn : TurnData):
	
	if not parent_turn is TeamTurnData:
		return
	
	var team_turn : TeamTurnData = parent_turn as TeamTurnData
	if team_turn.team_holder == null: 
		return
	for grid_object in team_turn.team_holder.grid_objects["active"]:
		for stat in grid_object.stat_library:
			stat.current_turn_changed()
