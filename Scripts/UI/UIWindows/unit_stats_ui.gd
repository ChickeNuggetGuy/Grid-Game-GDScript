extends UIWindow
class_name UnitStatsUI

@export var stat_progress_bars : Dictionary[Enums.Stat, StatProgressBar] = {}

var selected_unit : UnitData

func _show() -> void:
	
	if SceneManager.current_scene_type == Enums.SceneType.BATTLESCENE:
		var unit_manager : UnitManager = GameManager.get_manager("UnitManager")
		
		if  not unit_manager:
			push_error("unit manager not found")
			return
		
		selected_unit = unit_manager.selected_unit.data
	
	if not selected_unit:
		return
	
	for stat in stat_progress_bars:
		var stat_bar : StatProgressBar = stat_progress_bars[stat]
		
		if not stat_bar:
			continue
		
		stat_bar.setup_with_data(selected_unit)
