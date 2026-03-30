@tool
class_name CanSeeGridObject
extends ConditionLeaf

@export var team_filter : Enums.unitTeam

func tick(actor:Node, _blackboard:Blackboard) -> int:
	
	var grid_object : GridObject = actor as GridObject
	var sight_area_result = grid_object.try_get_grid_object_component_by_type("GridObjectSightArea")
	
	if not sight_area_result["success"]:
		return FAILURE
	
	var sight_area : GridObjectSightArea = sight_area_result["grid_object_component"]
	
	if sight_area.seen_gridObjects.is_empty():
		return FAILURE
	
	var valid_grid_object_found : bool = false
	for seen_grid_object in sight_area.seen_gridObjects:
		
		if seen_grid_object == null:
			continue
		
		if  team_filter != Enums.unitTeam.NONE and \
		seen_grid_object.team != team_filter:
			continue
		
		valid_grid_object_found = true
		return SUCCESS
	
	return FAILURE
