extends HexCellDefinition
class_name CityDefinition

var city_name: String = ""
var population: int = 0
var country_code: String = ""

func _init(index: int, _city_name: String, _population: int = 0, _country_code: String = "") -> void:
	city_name = _city_name
	population = _population
	country_code = _country_code
	super._init(index)

func get_class_name() -> String: return "CityDefinition"


func get_cell_color() -> Color:return  Color.YELLOW
