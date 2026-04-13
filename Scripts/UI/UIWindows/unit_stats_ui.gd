extends UIWindow
class_name UnitStatsUI

@export var stat_progress_bars : Dictionary[Enums.Stat, StatProgressBar] = {}


func _show() -> void:
	var unit_manager : UnitManager = GameManager.get_manager("UnitManager")
	
	if  not unit_manager:
		push_error("unit manager not found")
		return
	
	var selected_unit = unit_manager.selected_unit
	
	if not selected_unit:
		return
	
	for stat in stat_progress_bars:
		var stat_bar : StatProgressBar = stat_progress_bars[stat]
		
		if not stat_bar:
			continue
		
		stat_bar.setup(selected_unit)
