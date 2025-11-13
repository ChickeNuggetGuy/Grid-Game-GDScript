class_name TeamBaseDefinition
extends HexCellDefinition

var team_affiliation : Enums.unitTeam

func get_class_name() -> String: 
	return "TeamBaseDefinition" 

func get_cell_color() -> Color:
	return Color.BLUE

func _init(index : int = -1, team : Enums.unitTeam = Enums.unitTeam.PLAYER) -> void:
	team_affiliation = team
	super._init(index)

func serialize() -> Dictionary:
	return {
		"class_name": get_class_name(),
		"cell_index": cell_index,
		"team_affiliation": team_affiliation
	}

static func deserialize(data: Dictionary) -> TeamBaseDefinition:
	var instance = TeamBaseDefinition.new(
		data.get("cell_index", -1),
		data.get("team_affiliation", Enums.unitTeam.PLAYER)
	)
	return instance
