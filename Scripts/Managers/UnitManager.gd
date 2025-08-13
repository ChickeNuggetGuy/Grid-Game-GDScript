extends Manager
class_name UnitManager
#region Variables
@export var UnitTeams : Dictionary[Enums.unitTeam, UnitTeamHolder]
@export var spawn_counts : Vector2i = Vector2(2,2)
@export var unitScene: PackedScene

@export var selectedUnit : Unit = null
#endregion

#region Signals
signal UnitSelected(newUnit : Unit, oldUnit: Unit);
#endregion

#region Functions
func _get_manager_name() -> String: return "UnitManager"


func _setup_conditions(): return true


func get_manager_data() -> Dictionary:
	var ret_value = {}
	return ret_value



func _setup():
	
	unitScene = load("Scenes/GridObjects/Unit.tscn")
	#UnitTeams = {}
	#Register any existing Unit Teams!
	var children = get_children()
	for child in children:
		print(child.name)
		if child is UnitTeamHolder:
			var team : UnitTeamHolder = child
			
			UnitTeams.get_or_add(team.team,)
			UnitTeams[team.team] = team
	setup_completed.emit()
	


func _execute_conditions() -> bool: return true

func _execute():
	
	spawn_counts = Manager.get_instance("GameManager").passable_parameters["spawn_counts"]
	for x in range(spawn_counts.x):
		spawn_unit(Enums.unitTeam.PLAYER)
		
	for y in range(spawn_counts.y):
		spawn_unit(Enums.unitTeam.ENEMY)
	
	set_selected_unit(UnitTeams[Enums.unitTeam.PLAYER].gridObjects[0])
	execution_completed.emit()



func on_scene_changed(_new_scene: Node):
	if not Manager.get_instance("GameManager").current_scene_name == "BattleScene":
		queue_free()

func _on_exit_tree() -> void:
	return

func spawn_unit(team : Enums.unitTeam):
	var result = Manager.get_instance("GridSystem").try_get_random_walkable_cell()
	
	if result["success"] == false || result["cell"] == null:
		print("Could not find any valid grid cell. Returning prematurely")
		return
		
	var spawneUnit : Unit = unitScene.instantiate()
	spawneUnit.position = result["cell"].world_position
	
	var team_holder : UnitTeamHolder = UnitTeams[team]
	team_holder.gridObjects.append(spawneUnit)
	team_holder.add_child(spawneUnit)
	
	spawneUnit._setup(result["cell"], Enums.facingDirection.NORTH, team)


func set_selected_unit(gridObject: Unit):
	if selectedUnit == gridObject:
		return
	
	if not gridObject.active:
		return
	var oldUnit = selectedUnit
	selectedUnit = gridObject
	UnitSelected.emit(selectedUnit, oldUnit)


func set_selected_unit_next():
	if selectedUnit == null:
		return
	else:
		var currentIndex : int = UnitTeams[Enums.unitTeam.PLAYER].gridObjects.find(selectedUnit)
		var nextIndex = 0
		if currentIndex != -1:
				if currentIndex + 1 < UnitTeams[Enums.unitTeam.PLAYER].gridObjects.size():
					nextIndex = currentIndex + 1
				else:
					nextIndex = 0
		else:
			nextIndex = 0
		
		set_selected_unit(UnitTeams[Enums.unitTeam.PLAYER].gridObjects[nextIndex])


func _unhandled_input(event):
	if Manager.get_instance("UIManager").blocking_input:
		return
	
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_C:
			set_selected_unit_next()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if Manager.get_instance("GridInputManager").currentGridCell != null:
				var grid_object : Unit = Manager.get_instance("GridInputManager").currentGridCell.grid_object
				if grid_object != null and UnitTeams[Enums.unitTeam.PLAYER].gridObjects.has(grid_object):
					set_selected_unit(grid_object)
#endregion
