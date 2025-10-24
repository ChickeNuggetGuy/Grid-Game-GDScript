extends Manager
class_name UnitManager
#region Variables
@export var UnitTeams : Dictionary[Enums.unitTeam, UnitTeamHolder]
@export var spawn_counts : Vector2i = Vector2(2,2)
@export var unitScene: PackedScene

@export var selectedUnit : Unit = null
#endregion

#region Signals
signal unit_selected(newUnit : Unit, oldUnit: Unit);
signal Unit_spawned(newUnit : Unit);
#endregion

#region Functions
func _get_manager_name() -> String: return "UnitManager"


func _setup_conditions(): return true


func _setup():
	
	unitScene = load("Scenes/GridObjects/Unit.tscn")
	#UnitTeams = {}
	#Register any existing Unit Teams!
	
	setup_completed.emit()
	


func _execute_conditions() -> bool: return true

func _execute():
	
	var children = get_children()
	for child in children:
		print(child.name)
		if child is UnitTeamHolder:
			var team : UnitTeamHolder = child
			
			team.setup(self)
			UnitTeams.get_or_add(team.team,)
			UnitTeams[team.team] = team
	
	
	var game_manager = GameManager
	spawn_counts = game_manager.spawn_counts
	for x in range(spawn_counts.x):
		spawn_unit(Enums.unitTeam.PLAYER)
		
	for y in range(spawn_counts.y):
		spawn_unit(Enums.unitTeam.ENEMY)
	
	
	
	set_selected_unit(UnitTeams[Enums.unitTeam.PLAYER].grid_objects["active"][0])
	execution_completed.emit()
	
	FogManager.Instance.setup()
	


func _on_exit_tree() -> void:
	return

func spawn_unit(team : Enums.unitTeam):
	
	var grid_system : GridSystem =GameManager.managers["GridSystem"]
	var result = grid_system.try_get_random_walkable_cell()
	
	if result["success"] == false || result["cell"] == null:
		print("Could not find any valid grid cell. Returning prematurely")
		return
		
	var spawneUnit : Unit = unitScene.instantiate()
	spawneUnit.position = result["cell"].world_position
	
	
	var team_holder : UnitTeamHolder = UnitTeams[team]
	
	spawneUnit._setup(result["cell"], Enums.facingDirection.NORTH, team)
	team_holder.add_grid_object(spawneUnit)
	
	Unit_spawned.emit(spawneUnit)



func set_selected_unit(gridObject: Unit):
	if selectedUnit == gridObject:
		return
	
	if not gridObject.active:
		return
	var oldUnit = selectedUnit
	selectedUnit = gridObject
	unit_selected.emit(selectedUnit, oldUnit)


func set_selected_unit_next():
	if selectedUnit == null:
		return

	var active = UnitTeams[Enums.unitTeam.PLAYER].grid_objects["active"]
	if active == null or active.size() == 0:
		return

	if active.size() == 1:
		set_selected_unit(active[0])
		return

	var currentIndex: int = active.find(selectedUnit)
	var nextIndex: int = 0
	if currentIndex != -1:
		nextIndex = (currentIndex + 1) % active.size()
	else:
		nextIndex = 0

	set_selected_unit(active[nextIndex])

func _unhandled_input(event):
	if not execute_complete: return
	if GameManager.managers["UIManager"].blocking_input:
		return
	
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_C:
			set_selected_unit_next()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if GameManager.managers["GridInputManager"].currentGridCell != null:
				var grid_object : Unit = GameManager.managers["GridInputManager"].currentGridCell.grid_object
				if grid_object != null and UnitTeams[Enums.unitTeam.PLAYER].grid_objects["active"].has(grid_object):
					set_selected_unit(grid_object)
#endregion
