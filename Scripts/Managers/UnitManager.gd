extends Manager

#region Variables
@export var UnitTeams : Dictionary[Enums.unitTeam, UnitTeamHolder]
@export var spawnCounts : Vector2i = Vector2(2,2)
@export var unitScene: PackedScene

@export var selectedUnit : GridObject = null
#endregion

#region Signals
signal UnitSelected(newUnit : GridObject, oldUnit: GridObject);
#endregion

#region Functions
func _get_manager_name() -> String: return "UnitManager"


func _setup_conditions(): return true


func _setup():
	
	unitScene = load("Scenes/GridObjects/Unit.tscn")
	UnitTeams = {}
	#Register any existing Unit Teams!
	var children = get_children()
	for child in children:
		if child is UnitTeamHolder:
			var team : UnitTeamHolder = child
			
			UnitTeams.get_or_add(team.team,)
			UnitTeams[team.team] = child
	setup_completed.emit()
	
# Assuming Enums.unit_team is defined like:
# enum unit_team { ALPHA, BETA, GAMMA }

	for key in Enums.unitTeam.keys():
		if key != "None": 
			var gridObjects: Array[GridObject] = []  # Replace GridObject with your actual class
			var unitTeam : UnitTeamHolder = UnitTeamHolder.new(gridObjects, Enums.unitTeam[key])
			# Here, key is a string ("ALPHA"), so we use it to set the name.
			unitTeam.name = key + " Team"  
			add_child(unitTeam)
			# You can choose to use the key string as the dictionary key:
			UnitTeams[Enums.unitTeam[key]] = unitTeam


func _execute_conditions() -> bool: return true

func _execute():
	for x in range(spawnCounts.x):
		spawn_unit(Enums.unitTeam.PLAYER)
		
	for y in range(spawnCounts.y):
		spawn_unit(Enums.unitTeam.ENEMY)
	
	set_selected_unit(UnitTeams[Enums.unitTeam.PLAYER].gridObjects[0])
	execution_completed.emit()


func spawn_unit(team : Enums.unitTeam):
	var result = GridSystem.try_get_random_walkable_cell()
	
	if result["success"] == false || result["cell"] == null:
		print("Could not find any valid grid cell. Returning prematurely")
		return
		
	var spawneUnit : GridObject = unitScene.instantiate()
	spawneUnit.position = result["cell"].world_position
	UnitTeams[team].gridObjects.append(spawneUnit)
	UnitTeams[team].add_child(spawneUnit)
	
	spawneUnit._setup(result["cell"], Enums.facingDirection.NORTH)


func set_selected_unit(gridObject: GridObject):
	if selectedUnit == gridObject:
		return
	var oldUnit = selectedUnit
	selectedUnit = gridObject
	UnitSelected.emit(selectedUnit, oldUnit)


func set_selected_unit_next():
	if selectedUnit == null:
		set_selected_unit(UnitTeams[Enums.unitTeam.PLAYER].gridObjects[0])
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
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_C:
			set_selected_unit_next()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if GridInputManager.currentGridCell != null:
				var grid_object : GridObject = GridInputManager.currentGridCell.grid_object
				if grid_object != null and UnitTeams[Enums.unitTeam.PLAYER].gridObjects.has(grid_object):
					set_selected_unit(grid_object)
#endregion
