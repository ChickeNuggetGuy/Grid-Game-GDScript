class_name TeamBaseDefinition
extends HexCellDefinition

var base_name : String = "New Base"
var team_affiliation: Enums.unitTeam
var craft_hangers: Array[Craft]
var stationed_units: Array[UnitData]
var equipment : Array[ItemData]

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

	craft_hangers = []
	stationed_units = []
	equipment = []

	super._init(index)

	if stationed_units.is_empty():
		stationed_units.append(UnitData.new("Unit 1", index))

func serialize() -> Dictionary:
	var units_data: Array = []
	for unit in stationed_units:
		if unit != null:
			units_data.append(unit.serialize())
			
	var craft_data: Array = []
	for craft in craft_hangers:
		if craft != null:
			craft_data.append(craft.serialize())

	return {
		"class_name": get_class_name(),
		"cell_index": cell_index,
		"team_affiliation": int(team_affiliation),
		"stationed_units": units_data,
		"craft_hangers" : craft_data,
		"equipment" : equipment,
		"base_name" : base_name
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
			
	
	instance.craft_hangers.clear()
	
	var craft_data: Array = data.get("craft_hangers", [])
	for craft in craft_data:
		if craft is Dictionary:
			instance.craft_hangers.append(Craft.deserialize(craft))
	
	instance.base_name = data.get("base_name")
	instance.equipment = []
	return instance
