extends UIWindow
class_name QuickSelectPanel

@export var quick_select_button_scene : PackedScene
@export var quick_select_holder : VBoxContainer


func _setup() -> void:
	super._setup()
	
	print("Setuo Quick Select panel")
	var unit_manager : UnitManager = GameManager.get_manager("UnitManager")
	if not unit_manager:
		print("Quick Select panel: unit manager null")
		return
	
	var player_team = unit_manager.unit_teams[Enums.unitTeam.PLAYER]
	if not player_team:
		print("Quick Select panel: player_team null")
		return
	
	for grid_object in player_team.grid_objects["active"]:
		if grid_object is Unit:
			create_quick_select_button(grid_object)


func create_quick_select_button(unit : Unit):
	
	var button : QuickSelectButton = quick_select_button_scene.instantiate()
	if not button:
		print("Quick Select panel: button null")
		return
	
	print("create_quick_select_button")
	quick_select_holder.add_child(button)
	button.set_unit(unit)
