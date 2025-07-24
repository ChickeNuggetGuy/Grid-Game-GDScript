extends UIWindow
class_name UnitActionUI

#region Variables
@export var action_button_prefab : PackedScene
var action_buttons : Array = []
@export var action_button_holder : Control

@export var stat_progress_bars : Array[ProgressBar]
#endregion
#region Functions

func _ready() -> void:
	super._ready()
	print("EEEEE")
	UnitManager.connect("UnitSelected", unitManager_unit_selected)



func unitManager_unit_selected(selectedUnit : GridObject, old_unit : GridObject):
	print("Working!")
	update_action_buttons(selectedUnit)
	update_stat_bars(selectedUnit)
	



func update_stat_bars(gridObject : GridObject):
	for bar in stat_progress_bars:
		var progress_bar : StatProgressBar = bar
		
		var stat : GridObjectStat = gridObject.get_stat_by_name(progress_bar.stat_name)
		if stat != null:
			progress_bar.setup(gridObject, stat)
			progress_bar.value = stat.current_value
func update_action_buttons(gridObject : GridObject):
	if action_button_holder.get_child_count() > 0:
		for child in action_button_holder.get_children(false):
			child.queue_free()
	
	if gridObject.action_library == null or gridObject.action_library.size() == 0:
		return
	
	for action in gridObject.action_library:
		var action_node = action
		instantiate_action_button(action_node)
		


func instantiate_action_button(action_node : ActionNode):
	var action_button : ActionButton = action_button_prefab.instantiate()
	action_button_holder.add_child(action_button)
	action_button.action_setup(action_node)
#endregion
