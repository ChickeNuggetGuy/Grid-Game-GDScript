class_name TeamBaseDefinition
extends HexCellDefinition

var team_affiliation : Enums.unitTeam
func get_class_name() -> String: return "TeamBaseCellDefinition"


func get_cell_color() -> Color:return  Color.BLUE

func _init(index : int, team : Enums.unitTeam ) -> void:
	team_affiliation = team
	super._init(index)
