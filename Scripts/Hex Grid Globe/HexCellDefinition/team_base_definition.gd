class_name TeamBaseDefinition
extends HexCellDefinition

var team_affiliation: Enums.unitTeam
var craft_hangers: Array[Craft]
var stationed_units: Array[UnitData]

func get_class_name() -> String:
	return "TeamBaseDefinition"

func get_cell_color() -> Color:
	return Color.BLUE

func _init(
	index: int = -1,
	team: Enums.unitTeam = Enums.unitTeam.PLAYER
) -> void:
	definition_type = Enums.HexCellDefinitionType.BASE
	team_affiliation = team
	stationed_units = []
	super._init(index)

	if stationed_units.is_empty():
		stationed_units.append(UnitData.new("Unit 1", index))

func serialize() -> Dictionary:
	var units_data: Array = []

	for unit in stationed_units:
		if unit != null:
			units_data.append(unit.serialize())

	return {
		"class_name": get_class_name(),
		"cell_index": cell_index,
		"team_affiliation": int(team_affiliation),
		"stationed_units": units_data
	}

static func deserialize(data: Dictionary) -> TeamBaseDefinition:
	var instance := TeamBaseDefinition.new(
		int(data.get("cell_index", -1)),
		int(data.get("team_affiliation", Enums.unitTeam.PLAYER))
	)

	instance.stationed_units.clear()

	var units_data: Array = data.get("stationed_units", [])
	for unit_data in units_data:
		if unit_data is Dictionary:
			instance.stationed_units.append(UnitData.deserialize(unit_data))

	return instance
