extends Manager

#region Variables
@export var UnitTeams : Dictionary[Enums.unit_team, UnitTeam]
@export var spawnCounts : Vector2i = Vector2(2,2)
@export var unitScene: PackedScene
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
		if child is UnitTeam:
			var team : UnitTeam = child
			
			UnitTeams.get_or_add(team.team,)
			UnitTeams[team.team] = child
	setup_completed.emit()
	
# Assuming Enums.unit_team is defined like:
# enum unit_team { ALPHA, BETA, GAMMA }

	for key in Enums.unit_team.keys():
		if key != "None": 
			var gridObjects: Array[GridObject] = []  # Replace GridObject with your actual class
			var unitTeam : UnitTeam = UnitTeam.new(gridObjects, Enums.unit_team[key])
			# Here, key is a string ("ALPHA"), so we use it to set the name.
			unitTeam.name = key + " Team"  
			add_child(unitTeam)
			# You can choose to use the key string as the dictionary key:
			UnitTeams[Enums.unit_team[key]] = unitTeam



func _execute_conditions() -> bool: return true

func _execute():
	for x in range(spawnCounts.x):
		spawn_unit(Enums.unit_team.Player)
		
	for y in range(spawnCounts.y):
		spawn_unit(Enums.unit_team.Enemy)


func spawn_unit(team : Enums.unit_team):
	var result = GridSystem.try_get_randomGrid_cell()
	
	if result["success"] == false || result["cell"] == null:
		print("Could not find any valid grid cell. Returning prematurely")
		return
		
	var spawneUnit : GridObject = unitScene.instantiate()
	spawneUnit.position = result["cell"].gridCoordinates.worldCenter
	UnitTeams[team].gridObjects.append(spawneUnit)
	UnitTeams[team].add_child(spawneUnit)
	
#endregion
