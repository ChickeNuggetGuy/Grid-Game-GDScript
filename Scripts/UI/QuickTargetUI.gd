extends UIWindow
class_name QuickTargetUI

@export var quick_target_button_holder : Control
@export var quick_target_button_holder_enemy : Control
@export var quick_target_button_scene : PackedScene
var quick_target_buttons : Array[QuickTargetButton]



func _setup():
	GameManager.managers["UnitManager"].connect("UnitSelected",UnitManager_UnitSelected)
	GameManager.managers["UnitActionManager"].connect("action_execution_finished",UnitActionManager_action_execution_finished)



func UnitActionManager_action_execution_finished(_current_action : BaseActionDefinition,
		 _execution_parameters : Dictionary):
	update_quick_target_buttons()



func UnitManager_UnitSelected(_new_unit : Unit, _old_unit : Unit):
	update_quick_target_buttons()


func update_quick_target_buttons():
	var current_unit = GameManager.managers["UnitManager"].selectedUnit
	if current_unit == null:
		return

	# Remove old buttons
	for button in quick_target_buttons:
		button.queue_free()
	quick_target_buttons.clear()

	# Get the sight area component
	var result = current_unit.try_get_grid_object_component_by_type(
        "GridObjectSightArea"
	)
	if result["success"] == false:
		return

	var sight_area: GridObjectSightArea = result["grid_object_component"]
	print("WHAT 1")

	if sight_area.seen_gridObjects.size() > 0:
		print("WHAT")
		for grid_object_team in sight_area.seen_gridObjects.keys():
			var objects: Array = sight_area.seen_gridObjects[grid_object_team]
			if objects == null or objects.is_empty():
				continue

			for grid_object in objects:
				var quick_target_button: QuickTargetButton = (
					quick_target_button_scene.instantiate()
				)
				quick_target_button.initialize(grid_object)

				# If Enums.unitTeam is a bitmask, use bitwise check
				# If it's a normal enum, use equality
				if grid_object_team == Enums.unitTeam.ENEMY:
					quick_target_button_holder_enemy.add_child(quick_target_button)
				else:
					quick_target_button_holder.add_child(quick_target_button)

				quick_target_buttons.append(quick_target_button)

func _show():
	update_quick_target_buttons()
	super._show()
