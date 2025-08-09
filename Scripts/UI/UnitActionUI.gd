extends UIWindow
class_name UnitActionUI

#region Variables
@export var action_button_prefab : PackedScene
var action_buttons : Array = []
@export var action_button_holder : Control

@export var stat_progress_bars : Array[ProgressBar]
#endregion
#region Functions

func _setup() -> void:
	super._setup()
	UnitManager.Instance.connect("UnitSelected", unitManager_unit_selected)
	UnitActionManager.Instance.connect("action_execution_finished", UnitActionManager_action_execution_finished)
	
	var selected_unit = UnitManager.Instance.selectedUnit
	update_stat_bars(selected_unit)
	update_action_buttons(selected_unit)

func unitManager_unit_selected(selectedUnit : Unit, _old_unit : Unit):
	print("Working!")
	update_action_buttons(selectedUnit)
	update_stat_bars(selectedUnit)


func UnitActionManager_action_execution_finished(_current_action : BaseActionDefinition,
	execution_paramaters : Dictionary):
	update_stat_bars(UnitManager.Instance.selectedUnit)


func update_stat_bars(unit : Unit):
	for bar in stat_progress_bars:
		var progress_bar : StatProgressBar = bar
		
		var stat : GridObjectStat = unit.get_stat_by_name(progress_bar.stat_name)
		if stat != null:
			progress_bar.setup(unit, stat)
			progress_bar.value = stat.current_value


func update_action_buttons(unit : Unit):
	if action_button_holder.get_child_count() > 0:
		for child in action_button_holder.get_children(false):
			child.queue_free()
	
	var unit_actions = unit.get_all_action_definitions()
	if unit_actions["action_definitions"]== null or unit_actions["action_definitions"].size() == 0:
		return
	
	var unit_action_array : Array[BaseActionDefinition] = unit_actions["action_definitions"]
	unit_action_array.append_array(unit_actions["item_action_definitions"].keys())
	
	for action in unit_action_array:
		if not action.show_in_ui:
			continue
		instantiate_action_button(action)
		


func instantiate_action_button(action_node : BaseActionDefinition):
	var action_button : ActionButton = action_button_prefab.instantiate()
	action_button_holder.add_child(action_button)
	action_button.action_setup(action_node)
#endregion
